# Voidline shared backend

This directory is the first migration milestone from panel-owned process calls
to one unprivileged desktop backend.

## Process boundary

- `voidlined` is a per-user service. It listens only on
  `$XDG_RUNTIME_DIR/voidline/backend.sock`.
- `voidlinectl` is the supported command-line client and protocol exerciser.
- `voidline-protocol` owns the versioned, strictly deserialized request and
  response types shared by every Rust client.
- `voidline-terminal` is an unprivileged GTK4/VTE Wayland terminal. It does not
  have a privileged mode and does not implement shell parsing itself.
- Quickshell remains the presentation process. During migration, backend
  operations use its narrowly named IPC handlers for panel and singleton state.

The runtime directory is `0700`, the socket is `0600`, and every accepted Unix
connection must have the service user's peer UID. The backend clears child
environments and invokes only fixed executable paths with argument arrays. It
never accepts a shell command, executable path, environment map, or unrestricted
configuration path from a client.

## Permission levels

- `safe`: reversible actions such as search, volume, brightness, media, panel
  navigation, appearance, workspace switching, DND, and locking.
- `confirmation`: capture/recording, Wi-Fi or Bluetooth radio changes,
  wallpaper changes, clipboard clearing, and suspend.
- `privileged`: reserved for narrow Polkit helpers; none is implemented in this
  milestone.
- `dangerous`: logout, reboot, and power-off.

Confirmation tokens are random, single-use, expire after 60 seconds, and store
the already validated typed action server-side.

## Module migration status

State adapters currently exist for shell/appearance, NetworkManager with iwd
fallback, Bluetooth, PipeWire, displays, notifications, power, and Lyra service
health. Device discovery, tray state, updates, a resource-handle registry, and
event subscriptions are the next migrations. Capabilities explicitly mark
unfinished modules instead of exposing controls that silently do nothing.

The intended module split is:

1. platform adapters (`hyprland`, `network`, `bluetooth`, `audio`, `display`),
2. desktop services (`wallpaper`, `notification`, `tray`, `power`, `updates`),
3. policy services (`authentication`, `permissions`, `lyra_tools`), and
4. clients (Quickshell, Settings, Lyra, terminal helpers, `voidlinectl`).

Adapters will publish state-change events over the same local authenticated
transport. Polling must remain bounded and active only while a feature needs it.

## Lyra provider boundary

Quickshell talks to `ai-provider.sh`, not to Ollama-specific UI code. The adapter
exposes provider identity, exact model metadata, load/offload state, generation
metrics, and runtime resource data. The provider is a separate on-demand user
service and has an idle-stop timer. `lyra-action.sh` maps a finite set of tool
names onto `voidlinectl`; model output is never evaluated by a shell.

Ollama remains the measured local provider for this milestone. On the Ryzen
7840HS/Radeon 780M test laptop, the `qwen3.5:4b` package resolves to a 4.7B
Q4_K_M model. CPU-only inference produced about 29 tokens/s with a 2.43-second
first token. After enabling Ollama's Vulkan/iGPU path and restarting the stale
provider process, all 34 layers were offloaded and a warm request produced 49.1
tokens/s with a 676 ms first token at a 4096-token context. Radeon 780M memory
is treated as unified system memory rather than independent VRAM. The provider
API remains independent so llama.cpp or another engine can replace Ollama only
after an equal on-device benchmark.
