//! Versioned local protocol shared by Voidline clients and the user backend.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fmt;

pub const PROTOCOL_VERSION: u16 = 1;
pub const MAX_REQUEST_BYTES: usize = 64 * 1024;
pub const MAX_TEXT_ARGUMENT_BYTES: usize = 256;
pub const MAX_PATH_ARGUMENT_BYTES: usize = 4096;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct RequestEnvelope {
    pub version: u16,
    pub id: u64,
    #[serde(default)]
    pub dry_run: bool,
    pub request: Request,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(
    deny_unknown_fields,
    tag = "type",
    content = "payload",
    rename_all = "snake_case"
)]
pub enum Request {
    Health,
    Capabilities,
    GetState {
        module: StateModule,
    },
    RegisterResource {
        path: String,
        purpose: ResourcePurpose,
    },
    Execute {
        action: Action,
    },
    Confirm {
        token: String,
    },
    Cancel {
        token: String,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ResourcePurpose {
    Open,
    Wallpaper,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum StateModule {
    Shell,
    Appearance,
    Network,
    Bluetooth,
    Audio,
    Displays,
    Devices,
    Notifications,
    Tray,
    Power,
    Updates,
    Lyra,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(
    deny_unknown_fields,
    tag = "id",
    content = "arguments",
    rename_all = "snake_case"
)]
pub enum Action {
    OpenApplication {
        desktop_id: String,
    },
    OpenGame {
        app_id: u32,
    },
    Search {
        query: String,
        kind: SearchKind,
        location: SearchLocation,
    },
    OnlineLookup {
        kind: OnlineLookupKind,
        query: String,
    },
    OpenResource {
        handle: String,
        mode: OpenMode,
    },
    OpenPanel {
        panel: Panel,
        operation: PanelOperation,
    },
    OpenSettings {
        page: SettingsPage,
    },
    SetWallpaper {
        resource_handle: String,
        monitor: Option<String>,
    },
    SetAppearance {
        setting: AppearanceSetting,
    },
    SetVolume {
        percent: u8,
        muted: Option<bool>,
    },
    SetBrightness {
        percent: u8,
    },
    SetWifi {
        enabled: bool,
    },
    SetBluetooth {
        enabled: bool,
    },
    Media {
        command: MediaCommand,
    },
    SetPowerMode {
        mode: PowerMode,
    },
    Workspace {
        command: WorkspaceCommand,
    },
    Screenshot {
        mode: ScreenshotMode,
        output: Option<String>,
    },
    ScreenRecording {
        operation: RecordingOperation,
        output: Option<String>,
    },
    SetDoNotDisturb {
        enabled: bool,
    },
    ColorPicker,
    ToggleKeepAwake,
    Clipboard {
        operation: ClipboardOperation,
    },
    QueryInformation {
        topic: InformationTopic,
    },
    Lock,
    Session {
        action: SessionAction,
    },
}

impl Action {
    pub fn id(&self) -> &'static str {
        match self {
            Self::OpenApplication { .. } => "open_application",
            Self::OpenGame { .. } => "open_game",
            Self::Search { .. } => "search",
            Self::OnlineLookup { .. } => "online_lookup",
            Self::OpenResource { .. } => "open_resource",
            Self::OpenPanel { .. } => "open_panel",
            Self::OpenSettings { .. } => "open_settings",
            Self::SetWallpaper { .. } => "set_wallpaper",
            Self::SetAppearance { .. } => "set_appearance",
            Self::SetVolume { .. } => "set_volume",
            Self::SetBrightness { .. } => "set_brightness",
            Self::SetWifi { .. } => "set_wifi",
            Self::SetBluetooth { .. } => "set_bluetooth",
            Self::Media { .. } => "media",
            Self::SetPowerMode { .. } => "set_power_mode",
            Self::Workspace { .. } => "workspace",
            Self::Screenshot { .. } => "screenshot",
            Self::ScreenRecording { .. } => "screen_recording",
            Self::SetDoNotDisturb { .. } => "set_do_not_disturb",
            Self::ColorPicker => "color_picker",
            Self::ToggleKeepAwake => "toggle_keep_awake",
            Self::Clipboard { .. } => "clipboard",
            Self::QueryInformation { .. } => "query_information",
            Self::Lock => "lock",
            Self::Session { .. } => "session",
        }
    }

    pub fn permission(&self) -> PermissionLevel {
        match self {
            Self::OpenApplication { .. }
            | Self::OpenGame { .. }
            | Self::Search { .. }
            | Self::OpenResource { .. }
            | Self::OpenPanel { .. }
            | Self::OpenSettings { .. }
            | Self::SetAppearance { .. }
            | Self::SetVolume { .. }
            | Self::SetBrightness { .. }
            | Self::Media { .. }
            | Self::SetPowerMode { .. }
            | Self::Workspace { .. }
            | Self::SetDoNotDisturb { .. }
            | Self::ColorPicker
            | Self::ToggleKeepAwake
            | Self::Lock
            | Self::QueryInformation { .. } => PermissionLevel::Safe,
            Self::OnlineLookup { .. } => PermissionLevel::Confirmation,
            Self::Clipboard {
                operation: ClipboardOperation::OpenHistory | ClipboardOperation::OpenSymbols,
            } => PermissionLevel::Safe,
            Self::Clipboard {
                operation: ClipboardOperation::ClearHistory,
            } => PermissionLevel::Confirmation,
            Self::SetWallpaper { .. }
            | Self::SetWifi { .. }
            | Self::SetBluetooth { .. }
            | Self::Screenshot { .. }
            | Self::ScreenRecording { .. }
            | Self::Session {
                action: SessionAction::Suspend,
            } => PermissionLevel::Confirmation,
            Self::Session {
                action: SessionAction::Logout | SessionAction::Reboot | SessionAction::Poweroff,
            } => PermissionLevel::Dangerous,
        }
    }

    pub fn timeout_ms(&self) -> u64 {
        match self {
            Self::OnlineLookup { .. } => 20_000,
            Self::Screenshot { .. } | Self::ScreenRecording { .. } => 30_000,
            Self::Session { .. } => 20_000,
            _ => 8_000,
        }
    }

    pub fn description_key(&self) -> &'static str {
        match self {
            Self::OpenApplication { .. } => "backend.actions.openApplication",
            Self::OpenGame { .. } => "backend.actions.openGame",
            Self::Search { .. } => "backend.actions.search",
            Self::OnlineLookup { .. } => "backend.actions.onlineLookup",
            Self::OpenResource { .. } => "backend.actions.openResource",
            Self::OpenPanel { .. } => "backend.actions.openPanel",
            Self::OpenSettings { .. } => "backend.actions.openSettings",
            Self::SetWallpaper { .. } => "backend.actions.setWallpaper",
            Self::SetAppearance { .. } => "backend.actions.setAppearance",
            Self::SetVolume { .. } => "backend.actions.setVolume",
            Self::SetBrightness { .. } => "backend.actions.setBrightness",
            Self::SetWifi { .. } => "backend.actions.setWifi",
            Self::SetBluetooth { .. } => "backend.actions.setBluetooth",
            Self::Media { .. } => "backend.actions.media",
            Self::SetPowerMode { .. } => "backend.actions.setPowerMode",
            Self::Workspace { .. } => "backend.actions.workspace",
            Self::Screenshot { .. } => "backend.actions.screenshot",
            Self::ScreenRecording { .. } => "backend.actions.screenRecording",
            Self::SetDoNotDisturb { .. } => "backend.actions.setDoNotDisturb",
            Self::ColorPicker => "backend.actions.colorPicker",
            Self::ToggleKeepAwake => "backend.actions.toggleKeepAwake",
            Self::Clipboard { .. } => "backend.actions.clipboard",
            Self::QueryInformation { .. } => "backend.actions.queryInformation",
            Self::Lock => "backend.actions.lock",
            Self::Session { .. } => "backend.actions.session",
        }
    }

    pub fn validate(&self) -> Result<(), ValidationError> {
        match self {
            Self::OpenApplication { desktop_id } => validate_identifier(desktop_id, "desktop_id"),
            Self::Search { query, .. } => validate_text(query, "query", false),
            Self::OnlineLookup { query, .. } => validate_text(query, "query", false),
            Self::OpenResource { handle, .. } => validate_handle(handle),
            Self::SetWallpaper {
                resource_handle,
                monitor,
            } => {
                validate_handle(resource_handle)?;
                if let Some(value) = monitor {
                    validate_identifier(value, "monitor")?;
                }
                Ok(())
            }
            Self::SetVolume { percent, .. } | Self::SetBrightness { percent } => {
                if *percent <= 100 {
                    Ok(())
                } else {
                    Err(ValidationError::OutOfRange("percent"))
                }
            }
            Self::Workspace { command } => command.validate(),
            Self::Screenshot { output, .. } | Self::ScreenRecording { output, .. } => {
                if let Some(value) = output {
                    validate_identifier(value, "output")?;
                }
                Ok(())
            }
            _ => Ok(()),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum OnlineLookupKind {
    Search,
    Weather,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PermissionLevel {
    Safe,
    Confirmation,
    Privileged,
    Dangerous,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SearchKind {
    Applications,
    Games,
    Files,
    FileContents,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SearchLocation {
    Home,
    Desktop,
    Documents,
    Downloads,
    Music,
    Pictures,
    Videos,
    Projects,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum OpenMode {
    Open,
    Reveal,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum Panel {
    ControlCenter,
    Launcher,
    Overview,
    Power,
    Music,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PanelOperation {
    Open,
    Close,
    Toggle,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SettingsPage {
    Home,
    Connections,
    Audio,
    Devices,
    Notifications,
    Display,
    Appearance,
    Lock,
    Security,
    Accessibility,
    Assistant,
    Updates,
    System,
    Developer,
}

impl fmt::Display for SettingsPage {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}", format!("{self:?}").to_ascii_lowercase())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "name", content = "value", rename_all = "snake_case")]
pub enum AppearanceSetting {
    ColorMode(ColorMode),
    MagicColors(bool),
    BarPosition(BarPosition),
    BarStyle(BarStyle),
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ColorMode {
    Light,
    Dark,
    Automatic,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BarPosition {
    Top,
    Bottom,
    Left,
    Right,
}

/// Bar presentation. `Frame` keeps the connected bar and screen frame with
/// attached panels; the other styles float and detach their panels.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BarStyle {
    Frame,
    Islands,
    Floating,
    Minimal,
    Taskbar,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MediaCommand {
    PlayPause,
    Play,
    Pause,
    Next,
    Previous,
    Stop,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PowerMode {
    Saver,
    Balanced,
    Performance,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "operation", content = "value", rename_all = "snake_case")]
pub enum WorkspaceCommand {
    Switch(u8),
    MoveWindow(u8),
    ToggleSpecial(String),
}

impl WorkspaceCommand {
    fn validate(&self) -> Result<(), ValidationError> {
        match self {
            Self::Switch(index) | Self::MoveWindow(index) if (1..=99).contains(index) => Ok(()),
            Self::Switch(_) | Self::MoveWindow(_) => Err(ValidationError::OutOfRange("workspace")),
            Self::ToggleSpecial(name) => validate_identifier(name, "workspace"),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ScreenshotMode {
    Region,
    Window,
    Screen,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RecordingOperation {
    Start,
    Stop,
    Toggle,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ClipboardOperation {
    OpenHistory,
    OpenSymbols,
    ClearHistory,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum InformationTopic {
    System,
    Network,
    Bluetooth,
    Battery,
    Storage,
    Audio,
    Displays,
    Tray,
    Lyra,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SessionAction {
    Suspend,
    Logout,
    Reboot,
    Poweroff,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ResponseEnvelope {
    pub version: u16,
    pub id: u64,
    pub status: ResponseStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub payload: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorObject>,
}

impl ResponseEnvelope {
    pub fn ok(id: u64, payload: impl Serialize) -> Self {
        Self {
            version: PROTOCOL_VERSION,
            id,
            status: ResponseStatus::Ok,
            payload: serde_json::to_value(payload).ok(),
            error: None,
        }
    }

    pub fn error(id: u64, code: ErrorCode, message: impl Into<String>) -> Self {
        Self {
            version: PROTOCOL_VERSION,
            id,
            status: ResponseStatus::Error,
            payload: None,
            error: Some(ErrorObject {
                code,
                message: message.into(),
            }),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ResponseStatus {
    Ok,
    ConfirmationRequired,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Confirmation {
    pub token: String,
    pub action_id: String,
    pub permission: PermissionLevel,
    pub description_key: String,
    pub expires_in_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct ErrorObject {
    pub code: ErrorCode,
    pub message: String,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    InvalidProtocol,
    InvalidRequest,
    InvalidArgument,
    PermissionDenied,
    ConfirmationExpired,
    Busy,
    Timeout,
    Unsupported,
    BackendUnavailable,
    ActionFailed,
    RateLimited,
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum ValidationError {
    #[error("{0} is empty or too long")]
    InvalidLength(&'static str),
    #[error("{0} contains unsupported characters")]
    InvalidCharacters(&'static str),
    #[error("{0} is outside the allowed range")]
    OutOfRange(&'static str),
}

fn validate_text(
    value: &str,
    field: &'static str,
    allow_empty: bool,
) -> Result<(), ValidationError> {
    if (!allow_empty && value.is_empty()) || value.len() > MAX_TEXT_ARGUMENT_BYTES {
        return Err(ValidationError::InvalidLength(field));
    }
    if value.chars().any(|character| {
        character == '\0' || (character.is_control() && !character.is_whitespace())
    }) {
        return Err(ValidationError::InvalidCharacters(field));
    }
    Ok(())
}

fn validate_identifier(value: &str, field: &'static str) -> Result<(), ValidationError> {
    if value.is_empty() || value.len() > 180 {
        return Err(ValidationError::InvalidLength(field));
    }
    if !value
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || "._:-@".contains(character))
    {
        return Err(ValidationError::InvalidCharacters(field));
    }
    Ok(())
}

fn validate_handle(value: &str) -> Result<(), ValidationError> {
    if value.len() < 16 || value.len() > 96 {
        return Err(ValidationError::InvalidLength("resource_handle"));
    }
    if !value
        .chars()
        .all(|character| character.is_ascii_alphanumeric() || character == '-')
    {
        return Err(ValidationError::InvalidCharacters("resource_handle"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bar_style_round_trips_and_rejects_unknown_styles() {
        let setting = AppearanceSetting::BarStyle(BarStyle::Islands);
        let json = serde_json::to_string(&setting).unwrap();
        assert_eq!(json, r#"{"name":"bar_style","value":"islands"}"#);
        assert_eq!(
            serde_json::from_str::<AppearanceSetting>(&json).unwrap(),
            setting
        );
        assert!(
            serde_json::from_str::<AppearanceSetting>(r#"{"name":"bar_style","value":"dock"}"#)
                .is_err()
        );
    }

    #[test]
    fn rejects_unknown_request_fields() {
        let input = r#"{"version":1,"id":7,"request":{"type":"health"},"command":"rm -rf /"}"#;
        assert!(serde_json::from_str::<RequestEnvelope>(input).is_err());
    }

    #[test]
    fn rejects_unknown_action_arguments() {
        let request = r#"{
            "version": 1,
            "id": 7,
            "request": {
                "type": "execute",
                "payload": {
                    "action": {
                        "id": "set_volume",
                        "arguments": {"percent": 25, "muted": false, "command": "sh"}
                    }
                }
            }
        }"#;
        assert!(serde_json::from_str::<RequestEnvelope>(request).is_err());
    }

    #[test]
    fn rejects_argument_injection_in_desktop_id() {
        let action = Action::OpenApplication {
            desktop_id: "org.example.App;sh".into(),
        };
        assert_eq!(
            action.validate(),
            Err(ValidationError::InvalidCharacters("desktop_id"))
        );
    }

    #[test]
    fn clamps_protocol_with_typed_percent_validation() {
        let action = Action::SetVolume {
            percent: 101,
            muted: None,
        };
        assert_eq!(
            action.validate(),
            Err(ValidationError::OutOfRange("percent"))
        );
    }

    #[test]
    fn dangerous_actions_never_become_safe() {
        assert_eq!(
            Action::Session {
                action: SessionAction::Poweroff
            }
            .permission(),
            PermissionLevel::Dangerous
        );
        assert_eq!(Action::Lock.permission(), PermissionLevel::Safe);
        assert_eq!(
            Action::Session {
                action: SessionAction::Suspend
            }
            .permission(),
            PermissionLevel::Confirmation
        );
    }

    #[test]
    fn reversible_and_sensitive_actions_have_distinct_policies() {
        assert_eq!(
            Action::SetBrightness { percent: 50 }.permission(),
            PermissionLevel::Safe
        );
        assert_eq!(
            Action::SetWifi { enabled: false }.permission(),
            PermissionLevel::Confirmation
        );
        assert_eq!(
            Action::Screenshot {
                mode: ScreenshotMode::Region,
                output: None,
            }
            .permission(),
            PermissionLevel::Confirmation
        );
        assert_eq!(
            Action::OnlineLookup {
                kind: OnlineLookupKind::Search,
                query: "Arch Linux documentation".into(),
            }
            .permission(),
            PermissionLevel::Confirmation
        );
    }

    #[test]
    fn output_names_cannot_traverse_directories() {
        let action = Action::Screenshot {
            mode: ScreenshotMode::Region,
            output: Some("../../private".into()),
        };
        assert_eq!(
            action.validate(),
            Err(ValidationError::InvalidCharacters("output"))
        );
    }
}
