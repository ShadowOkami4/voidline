use anyhow::{Context, Result, anyhow, bail};
use nix::unistd::Uid;
use serde_json::{Value, json};
use std::env;
use std::ffi::{OsStr, OsString};
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::process::Output;
use std::time::Duration;
use tokio::fs;
use tokio::process::Command;
use tokio::time::{sleep, timeout};
use voidline_protocol::{
    Action, AppearanceSetting, ClipboardOperation, ErrorCode, InformationTopic, MediaCommand,
    OnlineLookupKind, OpenMode, Panel, PanelOperation, RecordingOperation, SearchKind,
    SessionAction, StateModule, WorkspaceCommand,
};

pub const IMPLEMENTED_ACTIONS: &[&str] = &[
    "open_application",
    "open_game",
    "search",
    "online_lookup",
    "open_resource",
    "open_panel",
    "open_settings",
    "set_wallpaper",
    "set_appearance",
    "set_volume",
    "set_brightness",
    "set_wifi",
    "set_bluetooth",
    "media",
    "set_power_mode",
    "workspace",
    "screenshot",
    "screen_recording",
    "set_do_not_disturb",
    "color_picker",
    "toggle_keep_awake",
    "clipboard",
    "query_information",
    "lock",
    "session",
];

#[derive(Debug, thiserror::Error)]
pub enum ExecutionError {
    #[error("the requested operation is not implemented")]
    Unsupported,
    #[error("required component is unavailable: {0}")]
    Unavailable(String),
    #[error("operation timed out")]
    Timeout,
    #[error("operation failed: {0}")]
    Failed(String),
}

impl ExecutionError {
    pub fn code(&self) -> ErrorCode {
        match self {
            Self::Unsupported => ErrorCode::Unsupported,
            Self::Unavailable(_) => ErrorCode::BackendUnavailable,
            Self::Timeout => ErrorCode::Timeout,
            Self::Failed(_) => ErrorCode::ActionFailed,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BackendPaths {
    pub home_dir: PathBuf,
    pub runtime_dir: PathBuf,
    pub state_dir: PathBuf,
    pub socket_path: PathBuf,
    pub shell_root: PathBuf,
}

impl BackendPaths {
    pub fn discover() -> Result<Self> {
        let uid = Uid::effective().as_raw();
        let home = absolute_env_path("HOME")?;
        let runtime_root = absolute_env_path("XDG_RUNTIME_DIR")?;
        let runtime_metadata =
            std::fs::symlink_metadata(&runtime_root).context("XDG_RUNTIME_DIR does not exist")?;
        if !runtime_metadata.is_dir() || runtime_metadata.uid() != uid {
            bail!("XDG_RUNTIME_DIR is not a directory owned by the current user");
        }
        if runtime_metadata.mode() & 0o077 != 0 {
            bail!("XDG_RUNTIME_DIR permissions are not private");
        }
        let state_root = env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/state"));
        if !state_root.is_absolute() {
            bail!("XDG_STATE_HOME must be absolute");
        }
        let config_root = env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".config"));
        let data_root = env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share"));
        let runtime_dir = runtime_root.join("voidline");
        let state_dir = state_root.join("voidline");
        let user_shell_root = config_root.join("quickshell/void");
        let user_packaged_shell_root = data_root.join("voidline/quickshell");
        let packaged_shell_root = PathBuf::from("/usr/share/voidline/quickshell");
        let configured_shell_root = env::var_os("VOIDLINE_SHELL_ROOT").map(PathBuf::from);
        let shell_root = if let Some(configured) = configured_shell_root {
            if !configured.is_absolute() || !configured.join("shell.qml").is_file() {
                bail!("VOIDLINE_SHELL_ROOT must identify an absolute Voidline shell directory");
            }
            configured
        } else if user_shell_root.join("shell.qml").is_file() {
            user_shell_root
        } else if user_packaged_shell_root.join("shell.qml").is_file() {
            user_packaged_shell_root
        } else if packaged_shell_root.join("shell.qml").is_file() {
            packaged_shell_root
        } else {
            config_root.join("quickshell/void")
        };
        Ok(Self {
            home_dir: home,
            socket_path: runtime_dir.join("backend.sock"),
            runtime_dir,
            state_dir,
            shell_root,
        })
    }

    pub async fn prepare(&self) -> Result<()> {
        create_private_directory(&self.runtime_dir).await?;
        create_private_directory(&self.state_dir).await?;
        Ok(())
    }
}

async fn create_private_directory(path: &Path) -> Result<()> {
    fs::create_dir_all(path).await?;
    let metadata = fs::symlink_metadata(path).await?;
    if metadata.file_type().is_symlink()
        || !metadata.is_dir()
        || metadata.uid() != Uid::effective().as_raw()
    {
        bail!("private backend directory failed ownership checks");
    }
    fs::set_permissions(path, std::fs::Permissions::from_mode(0o700)).await?;
    Ok(())
}

fn absolute_env_path(name: &str) -> Result<PathBuf> {
    let value = env::var_os(name).ok_or_else(|| anyhow!("{name} is not set"))?;
    let path = PathBuf::from(value);
    if !path.is_absolute() {
        bail!("{name} must be absolute");
    }
    Ok(path)
}

pub struct Executor {
    paths: BackendPaths,
}

impl Executor {
    pub fn new(paths: BackendPaths) -> Self {
        Self { paths }
    }

    pub fn paths(&self) -> &BackendPaths {
        &self.paths
    }

    pub fn supports(&self, action: &Action) -> bool {
        IMPLEMENTED_ACTIONS.contains(&action.id())
    }

    pub async fn state(&self, module: StateModule) -> Result<Value, ExecutionError> {
        let result = match module {
            StateModule::Shell | StateModule::Appearance => {
                self.quickshell_ipc(&["appearance", "status"]).await
            }
            StateModule::Network => self.script("network-control.sh", &["state"]).await,
            StateModule::Bluetooth => {
                self.run("/usr/bin/bluetoothctl", &["show"], Duration::from_secs(5))
                    .await
            }
            StateModule::Audio => {
                self.run(
                    "/usr/bin/wpctl",
                    &["get-volume", "@DEFAULT_AUDIO_SINK@"],
                    Duration::from_secs(5),
                )
                .await
            }
            StateModule::Displays => {
                self.run(
                    "/usr/bin/hyprctl",
                    &["monitors", "-j"],
                    Duration::from_secs(5),
                )
                .await
            }
            StateModule::Notifications => self.quickshell_ipc(&["notifications", "status"]).await,
            StateModule::Power => {
                self.run("/usr/bin/upower", &["-d"], Duration::from_secs(8))
                    .await
            }
            StateModule::Lyra => {
                self.run(
                    "/usr/bin/systemctl",
                    &["--user", "is-active", "voidline-ai.service"],
                    Duration::from_secs(5),
                )
                .await
            }
            StateModule::Devices | StateModule::Tray | StateModule::Updates => {
                return Err(ExecutionError::Unsupported);
            }
        }?;
        Ok(json!({
            "module": module,
            "output": bounded_output(&result.stdout),
        }))
    }

    pub async fn execute(
        &self,
        action: &Action,
        resource_path: Option<&Path>,
    ) -> Result<Value, ExecutionError> {
        let output = match action {
            Action::OpenApplication { desktop_id } => {
                self.run_os(
                    "/usr/bin/gtk-launch",
                    &[OsString::from(desktop_id)],
                    Duration::from_secs(8),
                )
                .await?
            }
            Action::OpenGame { app_id } => {
                self.run(
                    "/usr/bin/steam",
                    &["-applaunch", &app_id.to_string()],
                    Duration::from_secs(8),
                )
                .await?
            }
            Action::Search {
                query,
                kind,
                location,
            } => {
                let (page, view, mode) = match kind {
                    SearchKind::Applications => ("apps", "", "name"),
                    SearchKind::Games => ("games", "", "name"),
                    SearchKind::Files => ("files", "all", "name"),
                    SearchKind::FileContents => ("files", "all", "content"),
                };
                let location = format!("{location:?}").to_ascii_lowercase();
                self.quickshell_ipc(&[
                    "launcher",
                    "openSearch",
                    page,
                    query,
                    view,
                    mode,
                    &location,
                    "",
                ])
                .await?
            }
            Action::OnlineLookup { kind, query } => {
                return self.online_lookup(*kind, query).await;
            }
            Action::OpenResource { mode, .. } => {
                let path = resource_path.ok_or_else(|| {
                    ExecutionError::Failed("validated resource path is missing".into())
                })?;
                let target = match mode {
                    OpenMode::Open => path,
                    OpenMode::Reveal => path.parent().unwrap_or(path),
                };
                self.run_os(
                    "/usr/bin/xdg-open",
                    &[target.as_os_str().to_os_string()],
                    Duration::from_secs(8),
                )
                .await?
            }
            Action::SetWallpaper { monitor, .. } => {
                let path = resource_path.ok_or_else(|| {
                    ExecutionError::Failed("validated wallpaper path is missing".into())
                })?;
                let path = path.to_string_lossy();
                self.quickshell_ipc(&[
                    "appearance",
                    "setWallpaper",
                    &path,
                    monitor.as_deref().unwrap_or(""),
                ])
                .await?
            }
            Action::OpenPanel { panel, operation } => {
                let target = match panel {
                    Panel::ControlCenter => "controlCenter",
                    Panel::Launcher => "launcher",
                    Panel::Overview => "overview",
                    Panel::Power => "powerMenu",
                    Panel::Music => "media",
                };
                let method = match operation {
                    PanelOperation::Open => "open",
                    PanelOperation::Close => "close",
                    PanelOperation::Toggle => "toggle",
                };
                if *panel == Panel::ControlCenter && *operation == PanelOperation::Open {
                    self.quickshell_ipc(&[target, method, ""]).await?
                } else {
                    self.quickshell_ipc(&[target, method]).await?
                }
            }
            Action::OpenSettings { page } => {
                let page = page.to_string();
                self.quickshell_ipc(&["settings", "openPage", &page])
                    .await?
            }
            Action::SetAppearance { setting } => match setting {
                AppearanceSetting::ColorMode(mode) => {
                    let mode = format!("{mode:?}").to_ascii_lowercase();
                    self.quickshell_ipc(&["appearance", "setColorMode", &mode])
                        .await?
                }
                AppearanceSetting::MagicColors(enabled) => {
                    self.quickshell_ipc(&[
                        "appearance",
                        "setMagicColors",
                        if *enabled { "true" } else { "false" },
                    ])
                    .await?
                }
                AppearanceSetting::BarPosition(position) => {
                    let position = format!("{position:?}").to_ascii_lowercase();
                    self.quickshell_ipc(&["appearance", "setBarPosition", &position])
                        .await?
                }
                AppearanceSetting::BarStyle(style) => {
                    let style = format!("{style:?}").to_ascii_lowercase();
                    self.quickshell_ipc(&["appearance", "setBarStyle", &style])
                        .await?
                }
            },
            Action::SetVolume { percent, muted } => {
                let percent_arg = format!("{percent}%");
                let mut result = self
                    .run(
                        "/usr/bin/wpctl",
                        &["set-volume", "@DEFAULT_AUDIO_SINK@", &percent_arg],
                        Duration::from_secs(5),
                    )
                    .await?;
                if let Some(value) = muted {
                    result = self
                        .run(
                            "/usr/bin/wpctl",
                            &[
                                "set-mute",
                                "@DEFAULT_AUDIO_SINK@",
                                if *value { "1" } else { "0" },
                            ],
                            Duration::from_secs(5),
                        )
                        .await?;
                }
                result
            }
            Action::SetBrightness { percent } => {
                let device = self.internal_backlight().await?;
                let percent = percent.to_string();
                self.script(
                    "brightness-service.sh",
                    &["set-internal", &device, &percent],
                )
                .await?
            }
            Action::SetWifi { enabled } => {
                let output = self
                    .run(
                        "/usr/bin/rfkill",
                        &[if *enabled { "unblock" } else { "block" }, "wifi"],
                        Duration::from_secs(5),
                    )
                    .await?;
                self.confirm_wifi_state(*enabled).await?;
                // rfkill events update the QML service as well. The explicit
                // refresh removes the small visual delay when the shell is
                // available, but Wi-Fi control remains valid without a shell.
                let _ = self.quickshell_ipc(&["network", "refresh"]).await;
                output
            }
            Action::SetBluetooth { enabled } => {
                self.quickshell_ipc(&[
                    "network",
                    "setBluetooth",
                    if *enabled { "true" } else { "false" },
                ])
                .await?
            }
            Action::Media { command } => {
                let command = match command {
                    MediaCommand::PlayPause => "play-pause",
                    MediaCommand::Play => "play",
                    MediaCommand::Pause => "pause",
                    MediaCommand::Next => "next",
                    MediaCommand::Previous => "previous",
                    MediaCommand::Stop => "stop",
                };
                self.run("/usr/bin/playerctl", &[command], Duration::from_secs(5))
                    .await?
            }
            Action::SetPowerMode { mode } => {
                let mode = format!("{mode:?}").to_ascii_lowercase();
                self.quickshell_ipc(&["power", "setProfile", &mode]).await?
            }
            Action::Workspace { command } => {
                let (operation, value) = match command {
                    WorkspaceCommand::Switch(index) => ("workspace", index.to_string()),
                    WorkspaceCommand::MoveWindow(index) => ("movetoworkspace", index.to_string()),
                    WorkspaceCommand::ToggleSpecial(name) => {
                        ("togglespecialworkspace", name.clone())
                    }
                };
                self.run(
                    "/usr/bin/hyprctl",
                    &["dispatch", operation, &value],
                    Duration::from_secs(5),
                )
                .await?
            }
            Action::Screenshot { mode, output } => {
                let mode = format!("{mode:?}").to_ascii_lowercase();
                self.script("screenshot.sh", &[&mode, output.as_deref().unwrap_or("")])
                    .await?
            }
            Action::ScreenRecording { operation, output } => {
                let method = match operation {
                    RecordingOperation::Start => "start",
                    RecordingOperation::Stop => "stop",
                    RecordingOperation::Toggle => "toggle",
                };
                if *operation == RecordingOperation::Stop {
                    self.quickshell_ipc(&["screenRecording", method]).await?
                } else {
                    self.quickshell_ipc(&[
                        "screenRecording",
                        method,
                        output.as_deref().unwrap_or(""),
                    ])
                    .await?
                }
            }
            Action::SetDoNotDisturb { enabled } => {
                self.quickshell_ipc(&[
                    "notifications",
                    "setDnd",
                    if *enabled { "true" } else { "false" },
                ])
                .await?
            }
            Action::ColorPicker => self.quickshell_ipc(&["systemActions", "pickColor"]).await?,
            Action::ToggleKeepAwake => {
                self.quickshell_ipc(&["systemActions", "toggleKeepAwake"])
                    .await?
            }
            Action::Clipboard { operation } => match operation {
                ClipboardOperation::OpenHistory => {
                    self.quickshell_ipc(&["launcher", "openPageOn", "clipboard", ""])
                        .await?
                }
                ClipboardOperation::OpenSymbols => {
                    self.quickshell_ipc(&["launcher", "openViewOn", "clipboard", "symbols", ""])
                        .await?
                }
                ClipboardOperation::ClearHistory => {
                    self.run("/usr/bin/cliphist", &["wipe"], Duration::from_secs(8))
                        .await?
                }
            },
            Action::QueryInformation { topic } => {
                return self.state(topic_module(*topic)).await;
            }
            Action::Lock => self.script("session-action.sh", &["lock"]).await?,
            Action::Session { action } => {
                let action = match action {
                    SessionAction::Suspend => "suspend",
                    SessionAction::Logout => "logout",
                    SessionAction::Reboot => "reboot",
                    SessionAction::Poweroff => "poweroff",
                };
                self.script("session-action.sh", &[action]).await?
            }
        };
        Ok(json!({
            "action_id": action.id(),
            "state": "succeeded",
            "output": bounded_output(&output.stdout),
        }))
    }

    async fn internal_backlight(&self) -> Result<String, ExecutionError> {
        let mut entries = fs::read_dir("/sys/class/backlight")
            .await
            .map_err(|_| ExecutionError::Unavailable("internal backlight".into()))?;
        while let Some(entry) = entries
            .next_entry()
            .await
            .map_err(|error| ExecutionError::Failed(error.to_string()))?
        {
            let name = entry.file_name().to_string_lossy().to_string();
            if !name.is_empty()
                && name.chars().all(|character| {
                    character.is_ascii_alphanumeric() || "._:-".contains(character)
                })
            {
                return Ok(name);
            }
        }
        Err(ExecutionError::Unavailable("internal backlight".into()))
    }

    async fn online_lookup(
        &self,
        kind: OnlineLookupKind,
        query: &str,
    ) -> Result<Value, ExecutionError> {
        match kind {
            OnlineLookupKind::Search => self.online_search(query).await,
            OnlineLookupKind::Weather => self.online_weather(query).await,
        }
    }

    async fn online_search(&self, query: &str) -> Result<Value, ExecutionError> {
        let duck = self
            .curl_json(
                "https://api.duckduckgo.com/",
                &[
                    ("q", query),
                    ("format", "json"),
                    ("no_html", "1"),
                    ("skip_disambig", "1"),
                ],
            )
            .await?;
        let wikipedia = self
            .curl_json(
                "https://en.wikipedia.org/w/api.php",
                &[
                    ("action", "query"),
                    ("list", "search"),
                    ("srsearch", query),
                    ("srlimit", "5"),
                    ("utf8", "1"),
                    ("format", "json"),
                ],
            )
            .await?;

        let mut lines = Vec::new();
        let heading = duck
            .get("Heading")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .unwrap_or(query);
        if let Some(abstract_text) = duck
            .get("AbstractText")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
        {
            lines.push(format!(
                "## {heading}\n\n{}",
                clamp_text(abstract_text, 900)
            ));
            if let Some(url) = duck.get("AbstractURL").and_then(Value::as_str) {
                if url.starts_with("https://") {
                    lines.push(format!("Source: {url}"));
                }
            }
        }

        let mut sources = Vec::new();
        if let Some(results) = wikipedia.pointer("/query/search").and_then(Value::as_array) {
            for result in results.iter().take(5) {
                let title = result
                    .get("title")
                    .and_then(Value::as_str)
                    .unwrap_or("Wikipedia result");
                let page_id = result.get("pageid").and_then(Value::as_u64).unwrap_or(0);
                if page_id == 0 {
                    continue;
                }
                let url = format!("https://en.wikipedia.org/?curid={page_id}");
                sources.push(json!({ "title": title, "url": url }));
                lines.push(format!("- [{title}]({url})"));
            }
        }
        if lines.is_empty() {
            return Err(ExecutionError::Failed(
                "the online lookup returned no usable results".into(),
            ));
        }
        Ok(json!({
            "action_id": "online_lookup",
            "state": "succeeded",
            "tool": "web_search",
            "query": query,
            "output": lines.join("\n\n"),
            "sources": sources,
        }))
    }

    async fn online_weather(&self, location: &str) -> Result<Value, ExecutionError> {
        let geocoding = self
            .curl_json(
                "https://geocoding-api.open-meteo.com/v1/search",
                &[
                    ("name", location),
                    ("count", "1"),
                    ("language", "en"),
                    ("format", "json"),
                ],
            )
            .await?;
        let place = geocoding
            .get("results")
            .and_then(Value::as_array)
            .and_then(|results| results.first())
            .ok_or_else(|| ExecutionError::Failed("location was not found".into()))?;
        let latitude = place
            .get("latitude")
            .and_then(Value::as_f64)
            .ok_or_else(|| ExecutionError::Failed("weather location has no latitude".into()))?;
        let longitude = place
            .get("longitude")
            .and_then(Value::as_f64)
            .ok_or_else(|| ExecutionError::Failed("weather location has no longitude".into()))?;
        let latitude_text = latitude.to_string();
        let longitude_text = longitude.to_string();
        let forecast = self
            .curl_json(
                "https://api.open-meteo.com/v1/forecast",
                &[
                    ("latitude", &latitude_text),
                    ("longitude", &longitude_text),
                    ("current", "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m"),
                    ("daily", "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
                    ("timezone", "auto"),
                    ("forecast_days", "5"),
                ],
            )
            .await?;
        let current = forecast.get("current").ok_or_else(|| {
            ExecutionError::Failed("weather service returned no current conditions".into())
        })?;
        let temperature = current
            .get("temperature_2m")
            .and_then(Value::as_f64)
            .unwrap_or(0.0);
        let feels_like = current
            .get("apparent_temperature")
            .and_then(Value::as_f64)
            .unwrap_or(temperature);
        let humidity = current
            .get("relative_humidity_2m")
            .and_then(Value::as_f64)
            .unwrap_or(0.0);
        let wind = current
            .get("wind_speed_10m")
            .and_then(Value::as_f64)
            .unwrap_or(0.0);
        let code = current
            .get("weather_code")
            .and_then(Value::as_i64)
            .unwrap_or(-1);
        let place_name = place
            .get("name")
            .and_then(Value::as_str)
            .unwrap_or(location);
        let country = place.get("country").and_then(Value::as_str).unwrap_or("");
        let display_location = if country.is_empty() {
            place_name.to_string()
        } else {
            format!("{place_name}, {country}")
        };
        let output = format!(
            "## {display_location}\n\n**{temperature:.1} °C · {}**\n\nFeels like {feels_like:.1} °C · Humidity {humidity:.0}% · Wind {wind:.1} km/h\n\nUpdated: {}\n\nSource: https://open-meteo.com/",
            weather_label(code),
            current.get("time").and_then(Value::as_str).unwrap_or("now")
        );
        Ok(json!({
            "action_id": "online_lookup",
            "state": "succeeded",
            "tool": "weather",
            "query": location,
            "output": output,
            "weather": {
                "location": display_location,
                "temperature_c": temperature,
                "feels_like_c": feels_like,
                "humidity_percent": humidity,
                "wind_kmh": wind,
                "weather_code": code,
                "condition": weather_label(code),
                "updated": current.get("time").cloned().unwrap_or(Value::Null),
                "daily": forecast.get("daily").cloned().unwrap_or(Value::Null)
            },
            "sources": [{ "title": "Open-Meteo", "url": "https://open-meteo.com/" }],
        }))
    }

    async fn curl_json(
        &self,
        url: &str,
        parameters: &[(&str, &str)],
    ) -> Result<Value, ExecutionError> {
        let mut arguments = vec![
            OsString::from("--fail-with-body"),
            OsString::from("--silent"),
            OsString::from("--show-error"),
            OsString::from("--location"),
            OsString::from("--max-time"),
            OsString::from("15"),
            OsString::from("--max-filesize"),
            OsString::from("2097152"),
            OsString::from("--get"),
        ];
        for (name, value) in parameters {
            arguments.push(OsString::from("--data-urlencode"));
            arguments.push(OsString::from(format!("{name}={value}")));
        }
        arguments.push(OsString::from(url));
        let output = self
            .run_os("/usr/bin/curl", &arguments, Duration::from_secs(18))
            .await?;
        serde_json::from_slice(&output.stdout)
            .map_err(|_| ExecutionError::Failed("online service returned invalid JSON".into()))
    }

    async fn quickshell_ipc(&self, arguments: &[&str]) -> Result<Output, ExecutionError> {
        let mut args = vec![
            OsString::from("-p"),
            self.paths.shell_root.as_os_str().to_os_string(),
            OsString::from("ipc"),
            // The backend belongs to the user session, not to one compositor
            // output. This also keeps CLI calls working from SSH and TTYs that
            // do not inherit WAYLAND_DISPLAY.
            OsString::from("--any-display"),
            OsString::from("call"),
        ];
        args.extend(arguments.iter().map(OsString::from));
        self.run_os("/usr/bin/quickshell", &args, Duration::from_secs(8))
            .await
    }

    async fn confirm_wifi_state(&self, expected: bool) -> Result<(), ExecutionError> {
        // The Quickshell IPC acknowledges the requested change before
        // NetworkManager/rfkill necessarily publish it. USB and firmware-backed
        // radios can take several seconds, especially while enabling, so keep
        // the confirmation bounded but do not report a false failure after the
        // UI has already accepted the operation.
        for _ in 0..40 {
            if let Ok(output) = self
                .run(
                    "/usr/bin/env",
                    &["LC_ALL=C", "/usr/bin/nmcli", "radio", "wifi"],
                    Duration::from_secs(3),
                )
                .await
            {
                if let Some(actual) = parse_nmcli_wifi_enabled(&output.stdout) {
                    if actual == expected {
                        return Ok(());
                    }
                    sleep(Duration::from_millis(125)).await;
                    continue;
                }
            }
            let output = self
                .run("/usr/bin/rfkill", &["--json"], Duration::from_secs(3))
                .await?;
            match parse_wifi_enabled(&output.stdout)? {
                Some(actual) if actual == expected => return Ok(()),
                Some(_) => sleep(Duration::from_millis(125)).await,
                None => {
                    return Err(ExecutionError::Unavailable("Wi-Fi adapter".into()));
                }
            }
        }
        Err(ExecutionError::Failed(
            "Wi-Fi radio did not reach the requested state".into(),
        ))
    }

    async fn script(&self, name: &str, arguments: &[&str]) -> Result<Output, ExecutionError> {
        let path = self.paths.shell_root.join("scripts").join(name);
        if !path.starts_with(self.paths.shell_root.join("scripts")) {
            return Err(ExecutionError::Failed(
                "invalid internal script path".into(),
            ));
        }
        let mut args = vec![path.into_os_string()];
        args.extend(arguments.iter().map(OsString::from));
        self.run_os("/usr/bin/sh", &args, Duration::from_secs(30))
            .await
    }

    async fn run(
        &self,
        program: &str,
        arguments: &[&str],
        duration: Duration,
    ) -> Result<Output, ExecutionError> {
        let args: Vec<OsString> = arguments.iter().map(OsString::from).collect();
        self.run_os(program, &args, duration).await
    }

    async fn run_os(
        &self,
        program: &str,
        arguments: &[OsString],
        duration: Duration,
    ) -> Result<Output, ExecutionError> {
        if fs::metadata(program).await.is_err() {
            return Err(ExecutionError::Unavailable(program.to_string()));
        }
        let mut command = Command::new(program);
        command.args(arguments).kill_on_drop(true).env_clear();
        command.env("PATH", "/usr/local/bin:/usr/bin");
        for name in [
            "HOME",
            "XDG_RUNTIME_DIR",
            "XDG_CONFIG_HOME",
            "XDG_STATE_HOME",
            "WAYLAND_DISPLAY",
            "HYPRLAND_INSTANCE_SIGNATURE",
            "LANG",
            "LC_ALL",
        ] {
            if let Some(value) = env::var_os(name) {
                command.env(name, value);
            }
        }
        let output = timeout(duration, command.output())
            .await
            .map_err(|_| ExecutionError::Timeout)?
            .map_err(|error| ExecutionError::Failed(error.to_string()))?;
        if !output.status.success() {
            let detail = bounded_output(&output.stderr);
            return Err(ExecutionError::Failed(if detail.is_empty() {
                format!(
                    "{} exited with {}",
                    Path::new(program)
                        .file_name()
                        .and_then(OsStr::to_str)
                        .unwrap_or(program),
                    output.status
                )
            } else {
                detail
            }));
        }
        Ok(output)
    }
}

fn topic_module(topic: InformationTopic) -> StateModule {
    match topic {
        InformationTopic::System => StateModule::Shell,
        InformationTopic::Network => StateModule::Network,
        InformationTopic::Bluetooth => StateModule::Bluetooth,
        InformationTopic::Battery => StateModule::Power,
        InformationTopic::Storage => StateModule::Devices,
        InformationTopic::Audio => StateModule::Audio,
        InformationTopic::Displays => StateModule::Displays,
        InformationTopic::Tray => StateModule::Tray,
        InformationTopic::Lyra => StateModule::Lyra,
    }
}

fn bounded_output(bytes: &[u8]) -> String {
    const LIMIT: usize = 32 * 1024;
    let start = bytes.len().saturating_sub(LIMIT);
    String::from_utf8_lossy(&bytes[start..]).trim().to_string()
}

fn parse_nmcli_wifi_enabled(bytes: &[u8]) -> Option<bool> {
    match String::from_utf8_lossy(bytes).trim() {
        "enabled" => Some(true),
        "disabled" => Some(false),
        _ => None,
    }
}

fn parse_wifi_enabled(bytes: &[u8]) -> Result<Option<bool>, ExecutionError> {
    let payload: Value = serde_json::from_slice(bytes)
        .map_err(|_| ExecutionError::Failed("rfkill returned invalid JSON".into()))?;
    let devices = payload
        .get("rfkilldevices")
        .and_then(Value::as_array)
        .ok_or_else(|| ExecutionError::Failed("rfkill response is missing devices".into()))?;
    let mut found = false;
    let mut blocked = false;
    for device in devices {
        if device.get("type").and_then(Value::as_str) != Some("wlan") {
            continue;
        }
        found = true;
        blocked |= device.get("soft").and_then(Value::as_str) == Some("blocked")
            || device.get("hard").and_then(Value::as_str) == Some("blocked");
    }
    Ok(found.then_some(!blocked))
}

fn clamp_text(value: &str, limit: usize) -> String {
    value.chars().take(limit).collect()
}

fn weather_label(code: i64) -> &'static str {
    match code {
        0 => "Clear sky",
        1 | 2 => "Partly cloudy",
        3 => "Overcast",
        45 | 48 => "Fog",
        51 | 53 | 55 | 56 | 57 => "Drizzle",
        61 | 63 | 65 | 66 | 67 => "Rain",
        71 | 73 | 75 | 77 => "Snow",
        80..=82 => "Rain showers",
        85 | 86 => "Snow showers",
        95 | 96 | 99 => "Thunderstorm",
        _ => "Conditions unavailable",
    }
}

#[cfg(test)]
mod tests {
    use super::{parse_nmcli_wifi_enabled, parse_wifi_enabled};

    #[test]
    fn parses_locale_stable_networkmanager_radio_state() {
        assert_eq!(parse_nmcli_wifi_enabled(b"enabled\n"), Some(true));
        assert_eq!(parse_nmcli_wifi_enabled(b"disabled\n"), Some(false));
        assert_eq!(parse_nmcli_wifi_enabled(b"unavailable\n"), None);
    }

    #[test]
    fn parses_enabled_wifi_radio() {
        let input = br#"{"rfkilldevices":[{"type":"wlan","soft":"unblocked","hard":"unblocked"}]}"#;
        assert_eq!(parse_wifi_enabled(input).unwrap(), Some(true));
    }

    #[test]
    fn treats_any_blocked_wifi_radio_as_disabled() {
        let input = br#"{"rfkilldevices":[
            {"type":"wlan","soft":"unblocked","hard":"unblocked"},
            {"type":"wlan","soft":"blocked","hard":"unblocked"}
        ]}"#;
        assert_eq!(parse_wifi_enabled(input).unwrap(), Some(false));
    }

    #[test]
    fn reports_missing_wifi_adapter() {
        let input =
            br#"{"rfkilldevices":[{"type":"bluetooth","soft":"unblocked","hard":"unblocked"}]}"#;
        assert_eq!(parse_wifi_enabled(input).unwrap(), None);
    }
}
