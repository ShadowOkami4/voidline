mod executor;

use anyhow::{Context, Result, bail};
use executor::{BackendPaths, ExecutionError, Executor};
use nix::sys::stat::{Mode, umask};
use nix::unistd::Uid;
use serde::Serialize;
use serde_json::json;
use std::collections::HashMap;
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::fs::{self, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::{Mutex, Semaphore};
use tokio::time::timeout;
use tracing::{error, info, warn};
use uuid::Uuid;
use voidline_protocol::{
    Action, Confirmation, ErrorCode, MAX_PATH_ARGUMENT_BYTES, MAX_REQUEST_BYTES, PROTOCOL_VERSION,
    PermissionLevel, Request, RequestEnvelope, ResourcePurpose, ResponseEnvelope, ResponseStatus,
    StateModule,
};

const CONFIRMATION_LIFETIME: Duration = Duration::from_secs(60);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(5);
const MAX_CONNECTIONS: usize = 16;
const MAX_REQUESTS_PER_MINUTE: u32 = 120;
const RESOURCE_LIFETIME: Duration = Duration::from_secs(300);

#[derive(Debug)]
struct PendingAction {
    action: Action,
    expires: Instant,
}

#[derive(Debug)]
struct RateWindow {
    started: Instant,
    count: u32,
}

#[derive(Debug)]
struct RegisteredResource {
    path: PathBuf,
    purpose: ResourcePurpose,
    expires: Instant,
}

struct Backend {
    uid: u32,
    executor: Executor,
    pending: Mutex<HashMap<String, PendingAction>>,
    resources: Mutex<HashMap<String, RegisteredResource>>,
    rates: Mutex<HashMap<i32, RateWindow>>,
    audit_path: PathBuf,
}

#[derive(Serialize)]
struct AuditRecord<'a> {
    timestamp_unix_ms: u128,
    peer_uid: u32,
    peer_pid: i32,
    action_id: &'a str,
    permission: PermissionLevel,
    outcome: &'a str,
}

#[derive(Serialize)]
struct HealthPayload<'a> {
    service: &'a str,
    version: &'a str,
    protocol: u16,
    uid: u32,
}

#[derive(Serialize)]
struct CapabilityPayload {
    protocol: u16,
    modules: Vec<ModuleCapability>,
    action_ids: Vec<&'static str>,
}

#[derive(Serialize)]
struct ModuleCapability {
    module: StateModule,
    implemented: bool,
    event_driven: bool,
}

impl Backend {
    fn new(paths: BackendPaths) -> Self {
        let audit_path = paths.state_dir.join("backend-audit.jsonl");
        Self {
            uid: Uid::effective().as_raw(),
            executor: Executor::new(paths),
            pending: Mutex::new(HashMap::new()),
            resources: Mutex::new(HashMap::new()),
            rates: Mutex::new(HashMap::new()),
            audit_path,
        }
    }

    async fn allow_request(&self, pid: i32) -> bool {
        let mut rates = self.rates.lock().await;
        let now = Instant::now();
        rates.retain(|_, window| now.duration_since(window.started) < Duration::from_secs(120));
        let window = rates.entry(pid).or_insert(RateWindow {
            started: now,
            count: 0,
        });
        if now.duration_since(window.started) >= Duration::from_secs(60) {
            window.started = now;
            window.count = 0;
        }
        if window.count >= MAX_REQUESTS_PER_MINUTE {
            return false;
        }
        window.count += 1;
        true
    }

    async fn handle(
        &self,
        request: RequestEnvelope,
        peer_uid: u32,
        peer_pid: i32,
    ) -> ResponseEnvelope {
        if request.version != PROTOCOL_VERSION {
            return ResponseEnvelope::error(
                request.id,
                ErrorCode::InvalidProtocol,
                format!(
                    "protocol {} is unsupported; expected {PROTOCOL_VERSION}",
                    request.version
                ),
            );
        }
        if !self.allow_request(peer_pid).await {
            return ResponseEnvelope::error(
                request.id,
                ErrorCode::RateLimited,
                "request limit exceeded",
            );
        }

        match request.request {
            Request::Health => ResponseEnvelope::ok(
                request.id,
                HealthPayload {
                    service: "voidlined",
                    version: "0.3.0dev",
                    protocol: PROTOCOL_VERSION,
                    uid: self.uid,
                },
            ),
            Request::Capabilities => ResponseEnvelope::ok(request.id, capabilities()),
            Request::GetState { module } => match self.executor.state(module).await {
                Ok(payload) => ResponseEnvelope::ok(request.id, payload),
                Err(error) => execution_error(request.id, error),
            },
            Request::RegisterResource { path, purpose } => {
                match self.register_resource(&path, purpose).await {
                    Ok(payload) => ResponseEnvelope::ok(request.id, payload),
                    Err(error) => execution_error(request.id, error),
                }
            }
            Request::Execute { action } => {
                if let Err(error) = action.validate() {
                    return ResponseEnvelope::error(
                        request.id,
                        ErrorCode::InvalidArgument,
                        error.to_string(),
                    );
                }
                if request.dry_run {
                    return ResponseEnvelope::ok(
                        request.id,
                        json!({
                            "action_id": action.id(),
                            "permission": action.permission(),
                            "description_key": action.description_key(),
                            "timeout_ms": action.timeout_ms(),
                            "would_execute": self.executor.supports(&action),
                        }),
                    );
                }
                if !self.executor.supports(&action) {
                    return ResponseEnvelope::error(
                        request.id,
                        ErrorCode::Unsupported,
                        format!(
                            "action {} is not implemented by this backend milestone",
                            action.id()
                        ),
                    );
                }
                if action.permission() != PermissionLevel::Safe {
                    return self.request_confirmation(request.id, action).await;
                }
                self.execute(request.id, action, peer_uid, peer_pid).await
            }
            Request::Confirm { token } => {
                let pending = self.pending.lock().await.remove(&token);
                match pending {
                    Some(pending) if pending.expires >= Instant::now() => {
                        self.execute(request.id, pending.action, peer_uid, peer_pid)
                            .await
                    }
                    Some(_) | None => ResponseEnvelope::error(
                        request.id,
                        ErrorCode::ConfirmationExpired,
                        "confirmation token is missing, expired, or already used",
                    ),
                }
            }
            Request::Cancel { token } => {
                let removed = self.pending.lock().await.remove(&token).is_some();
                ResponseEnvelope::ok(request.id, json!({ "cancelled": removed }))
            }
        }
    }

    async fn request_confirmation(&self, id: u64, action: Action) -> ResponseEnvelope {
        let token = Uuid::new_v4().simple().to_string();
        let confirmation = Confirmation {
            token: token.clone(),
            action_id: action.id().to_string(),
            permission: action.permission(),
            description_key: action.description_key().to_string(),
            expires_in_seconds: CONFIRMATION_LIFETIME.as_secs(),
        };
        let mut pending = self.pending.lock().await;
        pending.retain(|_, item| item.expires >= Instant::now());
        pending.insert(
            token,
            PendingAction {
                action,
                expires: Instant::now() + CONFIRMATION_LIFETIME,
            },
        );
        ResponseEnvelope {
            version: PROTOCOL_VERSION,
            id,
            status: ResponseStatus::ConfirmationRequired,
            payload: serde_json::to_value(confirmation).ok(),
            error: None,
        }
    }

    async fn execute(
        &self,
        id: u64,
        action: Action,
        peer_uid: u32,
        peer_pid: i32,
    ) -> ResponseEnvelope {
        let action_id = action.id();
        let permission = action.permission();
        let resource_path = match self.take_resource_for_action(&action).await {
            Ok(path) => path,
            Err(error) => return execution_error(id, error),
        };
        let result = self
            .executor
            .execute(&action, resource_path.as_deref())
            .await;
        let outcome = if result.is_ok() {
            "succeeded"
        } else {
            "failed"
        };
        if let Err(error) = self
            .audit(peer_uid, peer_pid, action_id, permission, outcome)
            .await
        {
            warn!(%error, "failed to append backend audit record");
        }
        match result {
            Ok(payload) => ResponseEnvelope::ok(id, payload),
            Err(error) => execution_error(id, error),
        }
    }

    async fn register_resource(
        &self,
        raw_path: &str,
        purpose: ResourcePurpose,
    ) -> Result<serde_json::Value, ExecutionError> {
        if raw_path.is_empty() || raw_path.len() > MAX_PATH_ARGUMENT_BYTES {
            return Err(ExecutionError::Failed(
                "resource path has an invalid length".into(),
            ));
        }
        let requested = PathBuf::from(raw_path);
        if !requested.is_absolute() {
            return Err(ExecutionError::Failed(
                "resource path must be absolute".into(),
            ));
        }
        let canonical = fs::canonicalize(&requested)
            .await
            .map_err(|_| ExecutionError::Unavailable("resource path".into()))?;
        if !canonical.starts_with(&self.executor.paths().home_dir) {
            return Err(ExecutionError::Failed(
                "resource path is outside the user's home directory".into(),
            ));
        }
        let metadata = fs::symlink_metadata(&canonical)
            .await
            .map_err(|error| ExecutionError::Failed(error.to_string()))?;
        if metadata.uid() != self.uid {
            return Err(ExecutionError::Failed(
                "resource is not owned by the current user".into(),
            ));
        }
        if purpose == ResourcePurpose::Wallpaper {
            if !metadata.is_file() || !is_supported_wallpaper(&canonical) {
                return Err(ExecutionError::Failed(
                    "wallpaper must be a PNG, JPEG, WebP, or AVIF image".into(),
                ));
            }
        } else if !metadata.is_file() && !metadata.is_dir() {
            return Err(ExecutionError::Failed(
                "resource must be a regular file or directory".into(),
            ));
        }

        let handle = Uuid::new_v4().simple().to_string();
        let mut resources = self.resources.lock().await;
        resources.retain(|_, item| item.expires >= Instant::now());
        resources.insert(
            handle.clone(),
            RegisteredResource {
                path: canonical,
                purpose,
                expires: Instant::now() + RESOURCE_LIFETIME,
            },
        );
        Ok(json!({
            "handle": handle,
            "expires_in_seconds": RESOURCE_LIFETIME.as_secs(),
        }))
    }

    async fn take_resource_for_action(
        &self,
        action: &Action,
    ) -> Result<Option<PathBuf>, ExecutionError> {
        let requested = match action {
            Action::OpenResource { handle, .. } => Some((handle, ResourcePurpose::Open)),
            Action::SetWallpaper {
                resource_handle, ..
            } => Some((resource_handle, ResourcePurpose::Wallpaper)),
            _ => None,
        };
        let Some((handle, purpose)) = requested else {
            return Ok(None);
        };
        let mut resources = self.resources.lock().await;
        let resource = resources.remove(handle).ok_or_else(|| {
            ExecutionError::Failed("resource handle is missing or expired".into())
        })?;
        if resource.expires < Instant::now() || resource.purpose != purpose {
            return Err(ExecutionError::Failed(
                "resource handle is missing, expired, or has the wrong purpose".into(),
            ));
        }
        Ok(Some(resource.path))
    }

    async fn audit(
        &self,
        peer_uid: u32,
        peer_pid: i32,
        action_id: &str,
        permission: PermissionLevel,
        outcome: &str,
    ) -> Result<()> {
        let record = AuditRecord {
            timestamp_unix_ms: SystemTime::now().duration_since(UNIX_EPOCH)?.as_millis(),
            peer_uid,
            peer_pid,
            action_id,
            permission,
            outcome,
        };
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .mode(0o600)
            .open(&self.audit_path)
            .await?;
        let mut line = serde_json::to_vec(&record)?;
        line.push(b'\n');
        file.write_all(&line).await?;
        Ok(())
    }
}

fn is_supported_wallpaper(path: &Path) -> bool {
    matches!(
        path.extension()
            .and_then(|value| value.to_str())
            .map(|value| value.to_ascii_lowercase())
            .as_deref(),
        Some("png" | "jpg" | "jpeg" | "webp" | "avif")
    )
}

fn execution_error(id: u64, error: ExecutionError) -> ResponseEnvelope {
    ResponseEnvelope::error(id, error.code(), error.to_string())
}

fn capabilities() -> CapabilityPayload {
    CapabilityPayload {
        protocol: PROTOCOL_VERSION,
        modules: vec![
            module(StateModule::Shell, true),
            module(StateModule::Appearance, true),
            module(StateModule::Network, true),
            module(StateModule::Bluetooth, true),
            module(StateModule::Audio, true),
            module(StateModule::Displays, true),
            module(StateModule::Devices, false),
            module(StateModule::Notifications, true),
            module(StateModule::Tray, false),
            module(StateModule::Power, true),
            module(StateModule::Updates, false),
            module(StateModule::Lyra, true),
        ],
        action_ids: executor::IMPLEMENTED_ACTIONS.to_vec(),
    }
}

fn module(module: StateModule, implemented: bool) -> ModuleCapability {
    ModuleCapability {
        module,
        implemented,
        event_driven: false,
    }
}

async fn read_frame(stream: &mut UnixStream) -> Result<Vec<u8>> {
    let mut frame = Vec::with_capacity(4096);
    let mut chunk = [0_u8; 4096];
    loop {
        let count = timeout(REQUEST_TIMEOUT, stream.read(&mut chunk))
            .await
            .context("request read timed out")??;
        if count == 0 {
            bail!("client closed before sending a complete request");
        }
        if let Some(newline) = chunk[..count].iter().position(|byte| *byte == b'\n') {
            frame.extend_from_slice(&chunk[..newline]);
            break;
        }
        frame.extend_from_slice(&chunk[..count]);
        if frame.len() > MAX_REQUEST_BYTES {
            bail!("request exceeds {MAX_REQUEST_BYTES} bytes");
        }
    }
    if frame.is_empty() || frame.len() > MAX_REQUEST_BYTES {
        bail!("request frame is empty or oversized");
    }
    Ok(frame)
}

async fn handle_connection(mut stream: UnixStream, backend: Arc<Backend>) -> Result<()> {
    let credentials = stream
        .peer_cred()
        .context("unable to read Unix peer credentials")?;
    let peer_uid = credentials.uid();
    let peer_pid = credentials.pid().unwrap_or(0);
    if peer_uid != backend.uid {
        let response = ResponseEnvelope::error(
            0,
            ErrorCode::PermissionDenied,
            "peer UID does not own this session",
        );
        stream.write_all(&serde_json::to_vec(&response)?).await?;
        stream.write_all(b"\n").await?;
        bail!("rejected peer UID {peer_uid}");
    }

    let frame = match read_frame(&mut stream).await {
        Ok(frame) => frame,
        Err(error) => {
            let response = ResponseEnvelope::error(0, ErrorCode::InvalidRequest, error.to_string());
            stream.write_all(&serde_json::to_vec(&response)?).await?;
            stream.write_all(b"\n").await?;
            return Ok(());
        }
    };
    let request = match serde_json::from_slice::<RequestEnvelope>(&frame) {
        Ok(request) => request,
        Err(error) => {
            let response = ResponseEnvelope::error(0, ErrorCode::InvalidRequest, error.to_string());
            stream.write_all(&serde_json::to_vec(&response)?).await?;
            stream.write_all(b"\n").await?;
            return Ok(());
        }
    };
    let response = backend.handle(request, peer_uid, peer_pid).await;
    stream.write_all(&serde_json::to_vec(&response)?).await?;
    stream.write_all(b"\n").await?;
    stream.shutdown().await?;
    Ok(())
}

async fn prepare_listener(path: &Path, uid: u32) -> Result<UnixListener> {
    if let Ok(metadata) = fs::symlink_metadata(path).await {
        if metadata.file_type().is_symlink()
            || !metadata.file_type().is_socket()
            || metadata.uid() != uid
        {
            bail!("refusing to replace an unexpected backend socket path");
        }
        if UnixStream::connect(path).await.is_ok() {
            bail!("another voidlined instance is already accepting connections");
        }
        fs::remove_file(path)
            .await
            .context("unable to remove stale backend socket")?;
    }

    let previous = umask(Mode::from_bits_truncate(0o077));
    let listener = UnixListener::bind(path).context("unable to bind backend Unix socket")?;
    umask(previous);
    fs::set_permissions(path, std::fs::Permissions::from_mode(0o600)).await?;
    Ok(listener)
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_target(false)
        .compact()
        .init();

    let paths = BackendPaths::discover()?;
    paths.prepare().await?;
    let listener = prepare_listener(&paths.socket_path, Uid::effective().as_raw()).await?;
    let backend = Arc::new(Backend::new(paths));
    let connections = Arc::new(Semaphore::new(MAX_CONNECTIONS));
    info!("Voidline backend ready");

    loop {
        tokio::select! {
            accepted = listener.accept() => {
                let (stream, _) = accepted?;
                let permit = match Arc::clone(&connections).try_acquire_owned() {
                    Ok(permit) => permit,
                    Err(_) => {
                        warn!("connection limit reached");
                        continue;
                    }
                };
                let backend = Arc::clone(&backend);
                tokio::spawn(async move {
                    let _permit = permit;
                    if let Err(error) = handle_connection(stream, backend).await {
                        warn!(%error, "backend client request failed");
                    }
                });
            }
            signal = tokio::signal::ctrl_c() => {
                signal?;
                info!("Voidline backend stopping");
                break;
            }
        }
    }
    if let Err(error) = fs::remove_file(&backend.executor.paths().socket_path).await {
        if error.kind() != std::io::ErrorKind::NotFound {
            error!(%error, "failed to remove backend socket");
        }
    }
    Ok(())
}
