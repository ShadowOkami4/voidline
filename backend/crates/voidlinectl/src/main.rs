use anyhow::{Context, Result, anyhow, bail};
use clap::{ArgAction, CommandFactory, Parser, Subcommand, ValueEnum};
use clap_complete::{Shell, generate};
use serde_json::Value;
use std::env;
use std::io::{self, IsTerminal, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixStream;
use tokio::process::Command as TokioCommand;
use tokio::time::sleep;
use voidline_protocol::{
    Action, AppearanceSetting, BarPosition, ClipboardOperation, Confirmation, InformationTopic,
    MAX_REQUEST_BYTES, MediaCommand, OnlineLookupKind, PROTOCOL_VERSION, Panel, PanelOperation,
    PowerMode, RecordingOperation, Request, RequestEnvelope, ResourcePurpose, ResponseEnvelope,
    ResponseStatus, ScreenshotMode, SearchKind, SearchLocation, SessionAction, SettingsPage,
    StateModule, WorkspaceCommand,
};

#[derive(Parser)]
#[command(
    name = "voidlinectl",
    version = "0.3.0dev",
    about = "Control the Voidline desktop through its validated user backend"
)]
struct Cli {
    /// Emit the complete response envelope as JSON.
    #[arg(long, global = true)]
    json: bool,
    /// Validate and describe an action without executing it.
    #[arg(long, global = true)]
    dry_run: bool,
    /// Explicitly approve a confirmation prompt. Never use this from an AI tool.
    #[arg(long, global = true)]
    yes: bool,
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Health,
    Status {
        #[arg(value_enum)]
        module: Option<ModuleArg>,
    },
    Capabilities,
    State {
        module: ModuleArg,
    },
    OpenApp {
        desktop_id: String,
    },
    OpenGame {
        app_id: u32,
    },
    Search {
        query: String,
        #[arg(long, value_enum, default_value_t = SearchKindArg::Applications)]
        kind: SearchKindArg,
        #[arg(long, value_enum, default_value_t = SearchLocationArg::Home)]
        location: SearchLocationArg,
    },
    Online {
        #[command(subcommand)]
        command: OnlineCli,
    },
    Panel {
        #[command(subcommand)]
        command: PanelCli,
    },
    Settings {
        #[command(subcommand)]
        command: SettingsCli,
    },
    Wallpaper {
        #[command(subcommand)]
        command: WallpaperCli,
    },
    Appearance {
        #[command(subcommand)]
        command: AppearanceCommand,
    },
    Volume {
        percent: u8,
        #[arg(long)]
        muted: Option<bool>,
    },
    Brightness {
        percent: u8,
    },
    Wifi {
        #[arg(action = ArgAction::Set)]
        enabled: bool,
    },
    Bluetooth {
        #[arg(action = ArgAction::Set)]
        enabled: bool,
    },
    PowerMode {
        mode: PowerModeArg,
    },
    Media {
        command: MediaArg,
    },
    Workspace {
        #[command(subcommand)]
        command: WorkspaceCli,
    },
    Screenshot {
        #[arg(value_enum, default_value_t = ScreenshotArg::Region)]
        mode: ScreenshotArg,
        #[arg(long)]
        output: Option<String>,
    },
    Record {
        #[arg(value_enum)]
        operation: RecordingArg,
        #[arg(long)]
        output: Option<String>,
    },
    Dnd {
        #[arg(action = ArgAction::Set)]
        enabled: bool,
    },
    ColorPicker,
    KeepAwake,
    Clipboard {
        operation: ClipboardArg,
    },
    Info {
        topic: InformationArg,
    },
    Lock,
    Session {
        action: SessionArg,
    },
    Confirm {
        token: String,
    },
    Cancel {
        token: String,
    },
    Completions {
        shell: Shell,
    },
}

#[derive(Subcommand)]
enum AppearanceCommand {
    Bar {
        position: BarPositionArg,
    },
    Colors {
        mode: ColorModeArg,
    },
    MagicColors {
        #[arg(action = ArgAction::Set)]
        enabled: bool,
    },
}

#[derive(Subcommand)]
enum PanelCli {
    Open { panel: PanelArg },
    Close { panel: PanelArg },
    Toggle { panel: PanelArg },
}

#[derive(Subcommand)]
enum SettingsCli {
    Open { page: SettingsPageArg },
}

#[derive(Subcommand)]
enum WallpaperCli {
    Set {
        path: PathBuf,
        #[arg(long)]
        monitor: Option<String>,
    },
}

#[derive(Subcommand)]
enum OnlineCli {
    Search { query: String },
    Weather { location: String },
}

#[derive(Subcommand)]
enum WorkspaceCli {
    Switch { index: u8 },
    MoveWindow { index: u8 },
    ToggleSpecial { name: String },
}

macro_rules! value_enum_map {
    ($name:ident => $target:ident { $($variant:ident),+ $(,)? }) => {
        #[derive(Clone, Copy, Debug, ValueEnum)]
        enum $name { $($variant),+ }
        impl From<$name> for $target {
            fn from(value: $name) -> Self {
                match value { $($name::$variant => $target::$variant),+ }
            }
        }
    };
}

value_enum_map!(BarPositionArg => BarPosition { Top, Bottom, Left, Right });
value_enum_map!(SearchKindArg => SearchKind { Applications, Games, Files, FileContents });
value_enum_map!(SearchLocationArg => SearchLocation { Home, Desktop, Documents, Downloads, Music, Pictures, Videos, Projects });
value_enum_map!(ScreenshotArg => ScreenshotMode { Region, Window, Screen });
value_enum_map!(RecordingArg => RecordingOperation { Start, Stop, Toggle });
value_enum_map!(MediaArg => MediaCommand { PlayPause, Play, Pause, Next, Previous, Stop });
value_enum_map!(PowerModeArg => PowerMode { Saver, Balanced, Performance });
value_enum_map!(SessionArg => SessionAction { Suspend, Logout, Reboot, Poweroff });
value_enum_map!(InformationArg => InformationTopic { System, Network, Bluetooth, Battery, Storage, Audio, Displays, Tray, Lyra });
value_enum_map!(SettingsPageArg => SettingsPage { Home, Connections, Audio, Devices, Notifications, Display, Appearance, Lock, Security, Accessibility, Assistant, Updates, System, Developer });
value_enum_map!(ModuleArg => StateModule { Shell, Appearance, Network, Bluetooth, Audio, Displays, Devices, Notifications, Tray, Power, Updates, Lyra });

#[derive(Clone, Copy, Debug, ValueEnum)]
enum ClipboardArg {
    History,
    Symbols,
    Clear,
}

#[derive(Clone, Copy, Debug, ValueEnum)]
enum ColorModeArg {
    Light,
    Dark,
    Automatic,
}

#[derive(Clone, Copy, Debug, ValueEnum)]
enum PanelArg {
    #[value(name = "action-center", alias = "control-center")]
    ActionCenter,
    Launcher,
    Overview,
    Power,
    Music,
}

impl From<PanelArg> for Panel {
    fn from(value: PanelArg) -> Self {
        match value {
            PanelArg::ActionCenter => Panel::ControlCenter,
            PanelArg::Launcher => Panel::Launcher,
            PanelArg::Overview => Panel::Overview,
            PanelArg::Power => Panel::Power,
            PanelArg::Music => Panel::Music,
        }
    }
}

async fn request_for(command: Commands) -> Result<Option<Request>> {
    let request = match command {
        Commands::Health => Request::Health,
        Commands::Status { module } => Request::GetState {
            module: module.map(Into::into).unwrap_or(StateModule::Shell),
        },
        Commands::Capabilities => Request::Capabilities,
        Commands::State { module } => Request::GetState {
            module: module.into(),
        },
        Commands::OpenApp { desktop_id } => execute(Action::OpenApplication { desktop_id }),
        Commands::OpenGame { app_id } => execute(Action::OpenGame { app_id }),
        Commands::Search {
            query,
            kind,
            location,
        } => execute(Action::Search {
            query,
            kind: kind.into(),
            location: location.into(),
        }),
        Commands::Online { command } => match command {
            OnlineCli::Search { query } => execute(Action::OnlineLookup {
                kind: OnlineLookupKind::Search,
                query,
            }),
            OnlineCli::Weather { location } => execute(Action::OnlineLookup {
                kind: OnlineLookupKind::Weather,
                query: location,
            }),
        },
        Commands::Panel { command } => {
            let (panel, operation) = match command {
                PanelCli::Open { panel } => (panel, PanelOperation::Open),
                PanelCli::Close { panel } => (panel, PanelOperation::Close),
                PanelCli::Toggle { panel } => (panel, PanelOperation::Toggle),
            };
            execute(Action::OpenPanel {
                panel: panel.into(),
                operation,
            })
        }
        Commands::Settings { command } => match command {
            SettingsCli::Open { page } => execute(Action::OpenSettings { page: page.into() }),
        },
        Commands::Wallpaper { command } => match command {
            WallpaperCli::Set { path, monitor } => {
                let absolute = if path.is_absolute() {
                    path
                } else {
                    env::current_dir()
                        .context("unable to resolve the current directory")?
                        .join(path)
                };
                let response = send(
                    Request::RegisterResource {
                        path: absolute.to_string_lossy().into_owned(),
                        purpose: ResourcePurpose::Wallpaper,
                    },
                    false,
                )
                .await?;
                if response.status != ResponseStatus::Ok {
                    if let Some(error) = response.error {
                        bail!("{}", error.message);
                    }
                    bail!("backend rejected the wallpaper resource");
                }
                let handle = response
                    .payload
                    .as_ref()
                    .and_then(|payload| payload.get("handle"))
                    .and_then(Value::as_str)
                    .ok_or_else(|| anyhow!("backend did not return a resource handle"))?;
                execute(Action::SetWallpaper {
                    resource_handle: handle.to_string(),
                    monitor,
                })
            }
        },
        Commands::Appearance { command } => execute(Action::SetAppearance {
            setting: match command {
                AppearanceCommand::Bar { position } => {
                    AppearanceSetting::BarPosition(position.into())
                }
                AppearanceCommand::Colors { mode } => AppearanceSetting::ColorMode(match mode {
                    ColorModeArg::Light => voidline_protocol::ColorMode::Light,
                    ColorModeArg::Dark => voidline_protocol::ColorMode::Dark,
                    ColorModeArg::Automatic => voidline_protocol::ColorMode::Automatic,
                }),
                AppearanceCommand::MagicColors { enabled } => {
                    AppearanceSetting::MagicColors(enabled)
                }
            },
        }),
        Commands::Volume { percent, muted } => execute(Action::SetVolume { percent, muted }),
        Commands::Brightness { percent } => execute(Action::SetBrightness { percent }),
        Commands::Wifi { enabled } => execute(Action::SetWifi { enabled }),
        Commands::Bluetooth { enabled } => execute(Action::SetBluetooth { enabled }),
        Commands::PowerMode { mode } => execute(Action::SetPowerMode { mode: mode.into() }),
        Commands::Media { command } => execute(Action::Media {
            command: command.into(),
        }),
        Commands::Workspace { command } => execute(Action::Workspace {
            command: match command {
                WorkspaceCli::Switch { index } => WorkspaceCommand::Switch(index),
                WorkspaceCli::MoveWindow { index } => WorkspaceCommand::MoveWindow(index),
                WorkspaceCli::ToggleSpecial { name } => WorkspaceCommand::ToggleSpecial(name),
            },
        }),
        Commands::Screenshot { mode, output } => execute(Action::Screenshot {
            mode: mode.into(),
            output,
        }),
        Commands::Record { operation, output } => execute(Action::ScreenRecording {
            operation: operation.into(),
            output,
        }),
        Commands::Dnd { enabled } => execute(Action::SetDoNotDisturb { enabled }),
        Commands::ColorPicker => execute(Action::ColorPicker),
        Commands::KeepAwake => execute(Action::ToggleKeepAwake),
        Commands::Clipboard { operation } => execute(Action::Clipboard {
            operation: match operation {
                ClipboardArg::History => ClipboardOperation::OpenHistory,
                ClipboardArg::Symbols => ClipboardOperation::OpenSymbols,
                ClipboardArg::Clear => ClipboardOperation::ClearHistory,
            },
        }),
        Commands::Info { topic } => execute(Action::QueryInformation {
            topic: topic.into(),
        }),
        Commands::Lock => execute(Action::Lock),
        Commands::Session { action } => execute(Action::Session {
            action: action.into(),
        }),
        Commands::Confirm { token } => Request::Confirm { token },
        Commands::Cancel { token } => Request::Cancel { token },
        Commands::Completions { .. } => return Ok(None),
    };
    Ok(Some(request))
}

fn execute(action: Action) -> Request {
    Request::Execute { action }
}

fn socket_path() -> Result<PathBuf> {
    let root =
        env::var_os("XDG_RUNTIME_DIR").ok_or_else(|| anyhow!("XDG_RUNTIME_DIR is not set"))?;
    let root = PathBuf::from(root);
    if !root.is_absolute() {
        bail!("XDG_RUNTIME_DIR must be absolute");
    }
    Ok(root.join("voidline/backend.sock"))
}

async fn connect_backend() -> Result<UnixStream> {
    let path = socket_path()?;
    if let Ok(stream) = UnixStream::connect(&path).await {
        return Ok(stream);
    }
    let status = TokioCommand::new("/usr/bin/systemctl")
        .args(["--user", "start", "voidline-backend.service"])
        .status()
        .await
        .context("failed to request backend startup")?;
    if !status.success() {
        bail!("voidline-backend.service could not be started");
    }
    for _ in 0..30 {
        if let Ok(stream) = UnixStream::connect(&path).await {
            return Ok(stream);
        }
        sleep(Duration::from_millis(50)).await;
    }
    bail!("Voidline backend did not create its socket")
}

async fn send(request: Request, dry_run: bool) -> Result<ResponseEnvelope> {
    let id = SystemTime::now().duration_since(UNIX_EPOCH)?.as_micros() as u64;
    let envelope = RequestEnvelope {
        version: PROTOCOL_VERSION,
        id,
        dry_run,
        request,
    };
    let mut stream = connect_backend().await?;
    let mut bytes = serde_json::to_vec(&envelope)?;
    bytes.push(b'\n');
    stream.write_all(&bytes).await?;
    stream.shutdown().await?;

    let mut response = Vec::with_capacity(4096);
    stream
        .take((MAX_REQUEST_BYTES + 1) as u64)
        .read_to_end(&mut response)
        .await?;
    if response.len() > MAX_REQUEST_BYTES {
        bail!("backend response exceeded the protocol limit");
    }
    serde_json::from_slice(&response).context("backend returned malformed JSON")
}

fn print_response(response: &ResponseEnvelope, json_output: bool) -> Result<()> {
    if json_output {
        println!("{}", serde_json::to_string_pretty(response)?);
        return Ok(());
    }
    if let Some(error) = &response.error {
        eprintln!("{:?}: {}", error.code, error.message);
        return Ok(());
    }
    if let Some(payload) = &response.payload {
        if let Some(output) = payload.get("output").and_then(Value::as_str) {
            if !output.is_empty() {
                println!("{output}");
            }
        } else {
            println!("{}", serde_json::to_string_pretty(payload)?);
        }
    }
    Ok(())
}

fn confirmation_from(response: &ResponseEnvelope) -> Result<Confirmation> {
    let payload = response
        .payload
        .clone()
        .ok_or_else(|| anyhow!("confirmation payload is missing"))?;
    serde_json::from_value(payload).context("confirmation payload is invalid")
}

fn prompt_confirmation(confirmation: &Confirmation) -> Result<bool> {
    eprintln!(
        "Confirmation required: {} ({:?})",
        confirmation.description_key, confirmation.permission
    );
    eprint!("Continue? [y/N] ");
    io::stderr().flush()?;
    let mut answer = String::new();
    io::stdin().read_line(&mut answer)?;
    Ok(matches!(
        answer.trim().to_ascii_lowercase().as_str(),
        "y" | "yes"
    ))
}

async fn run(cli: Cli) -> Result<u8> {
    if let Commands::Completions { shell } = &cli.command {
        let mut command = Cli::command();
        let name = command.get_name().to_string();
        generate(*shell, &mut command, name, &mut io::stdout());
        return Ok(0);
    }
    let request = request_for(cli.command)
        .await?
        .expect("completion was handled above");
    let mut response = send(request, cli.dry_run).await?;
    if response.status == ResponseStatus::ConfirmationRequired {
        let confirmation = confirmation_from(&response)?;
        let approved =
            cli.yes || (io::stdin().is_terminal() && prompt_confirmation(&confirmation)?);
        if approved {
            response = send(
                Request::Confirm {
                    token: confirmation.token,
                },
                false,
            )
            .await?;
        } else {
            print_response(&response, cli.json)?;
            return Ok(10);
        }
    }
    let exit = if response.status == ResponseStatus::Ok {
        0
    } else {
        1
    };
    print_response(&response, cli.json)?;
    Ok(exit)
}

#[tokio::main]
async fn main() -> ExitCode {
    let cli = Cli::parse();
    match run(cli).await {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("voidlinectl: {error:#}");
            ExitCode::from(69)
        }
    }
}
