# Voidline architecture audit

This file records the implementation state observed during the August 2026
shell audit. `Complete` means that the visible control has a real backend and
an error path; it does not mean that every Linux hardware combination has been
certified. Unsupported capabilities must remain hidden or visibly disabled.

## Runtime and ownership

| Area | State | Backend and remaining boundary |
| --- | --- | --- |
| Session startup | Complete | `voidline-shell.service` owns Quickshell, restarts on failure, and is started by Hyprland. |
| Shell crash recovery | Complete | systemd restarts the process with a bounded start limit. Developer diagnostics exposes logs. |
| Polkit | Partial | The custom Quickshell agent and dialog work for supported requests. Package updates still depend on the system Polkit stack and must never cache passwords. |
| Notifications | Complete | Quickshell owns the notification daemon, popup lifecycle, history, DND and cleanup. |
| Status notifier tray | Complete | StatusNotifierItem icons, menus, attention state, tooltips and compact overflow are implemented. Native application-owned menus remain application surfaces. |
| Clipboard | Complete | `wl-paste --watch cliphist` is event driven. Clipboard and symbols share the App Center surface. |
| Idle and lock | Complete | `hypridle`, Quickshell lock UI and shared SDDM profile/wallpaper caches are wired. |
| Login screen | Complete for the current theme | SDDM runs independently from Quickshell and reads atomically exported cache files. Installation remains a privileged installer step. |

## Services and resource behavior

| Service | State | Audit result |
| --- | --- | --- |
| Connectivity | Partial | One serialized adapter and private runtime state channel are shared by Settings and the Action Center. NetworkManager is preferred, with iwd/systemd-networkd fallback for lightweight installs. Wi-Fi scan, password prompts, hidden/open/saved connections, retry, disconnect, forget, Ethernet state, and hotspot state are implemented. VPN, proxy and DNS editing remain future work and are not exposed as fake controls. |
| Bluetooth | Substantial | Discovery, paired/available/connected state, connect/disconnect, pair, trust/block, rename and remove are backed by BlueZ. Hardware-specific pairing agents and every vendor battery/profile extension still require broader device testing. |
| Audio | Substantial | PipeWire/WirePlumber device, stream, level, port and profile controls are real and polling is active only while audio UI is visible. Player queue editing is hidden because the current Quickshell MPRIS API has no TrackList surface. |
| Displays | Substantial | Hyprland modes, scale, transform, position, VRR and mirroring use optimistic state, validation and compositor confirmation. Advanced manual modes have a timed rollback and safe reset. HDR/color-depth support remains capability gated. |
| Brightness | Complete for detected backends | Internal backlight uses `brightnessctl`; unsupported displays are disabled. DDC/CI is capability gated and needs hardware-specific certification. |
| Devices | Partial | USB, storage, input, camera, controller, tablet, printer/scanner and Bluetooth discovery are real. Several device-specific configuration actions depend on CUPS/SANE/udev tools and remain hidden when unavailable. |
| Updates | Partial | Repository/AUR discovery, review, confirmation and Polkit execution exist. A production-grade libalpm transaction UI with rich replacement/conflict recovery is still required before calling this a complete software center. |
| Accessibility | Partial | Shell motion, contrast, scale, transparency and supported Hyprland input options are wired. Screen-reader, full on-screen-keyboard and desktop-wide assistive technology integration require external services. |
| Security | Partial | Firewall, Secure Boot, encryption and session facts are detected. Controls that cannot be changed safely are informational instead of inert. A full permissions broker is outside the shell today. |
| Wallpaper/profile | Complete | Per-monitor selection, palette, SDDM wallpaper cache and shared rounded profile image cache are atomic. Public SDDM metadata no longer contains the private source path. |

## Lyra optional package boundary

Lyra is hidden unless `~/.local/share/voidline/features/ai.json` exists. Without
that feature manifest, the App Center item and AI settings are absent, provider
probes do not run, no model is loaded, and no assistant background resources
are consumed.

The shell talks only to `ai-provider.sh`; provider branding is not embedded
in the UI architecture. The shipped adapter uses local Ollama. The selected
model, context, keep-alive and history are configuration data rather than QML
constants. A normal standalone window is available through `voidline-lyra`.
Basic provider telemetry, token/timing metrics, model load state, on-demand
startup, explicit stop/restart controls, and an inactivity stop timer are wired.
The compatibility estimator, complete unified-memory accounting, task-specific
model roles, dynamic pressure response, detailed graphs, and benchmark gate are
specified in `AI_ARCHITECTURE.md`; those advanced capabilities must not be
described as complete until their delivery stages are implemented and verified.

Action flow:

1. Deterministic intents resolve common requests without a model round-trip.
2. Ambiguous action requests may enter the local JSON planner.
3. Planner output is untrusted and validated against the fixed action schema.
4. No schema entry accepts an arbitrary command or executable path.
5. Reversible UI/open/search actions may run immediately.
6. State-changing actions require confirmation; session actions are dangerous.
7. Privileged work remains in dedicated backends and Polkit.
8. Dispatch and failure state is recorded in the standalone action history.

Online search and weather use explicit backend tools rather than provider-side
network access. They obey disabled, ask, session and persistent modes, report
their source, and return data to the conversation without granting downloaded
content any authority to invoke local actions. The inference provider itself
remains bound to the local session.

## UI architecture

Geometry is owned by `core/Metrics.qml`; motion is owned by `core/Motion.qml`.
Panels, bar groups, settings components, menus and dialogs should not introduce
new literal radii, panel widths or animation durations. Connected panels retain
direction-aware concave geometry. The right-bar power rule opens and triggers
from the left without removing the connection extensions.

The Settings app and optional assistant are normal windows. Shell panels remain
layer-shell surfaces attached to their originating bar section.

## Known debt kept visible by development checks

`scripts/audit-runtime.sh` reports persistent timers, command construction,
temporary files and incomplete markers. `scripts/check-i18n.sh` compares all
three catalogs, reports missing/unused keys, and lists remaining potential QML
and script literals. Catalog integrity is enforced now; complete removal of
legacy hardcoded UI text is still active migration work and must not be
described as finished while that report is non-zero.

Still missing from desktop-environment completeness:

- a graphical default-app/MIME association editor;
- automatic removable-media policy and autorun UI;
- advanced VPN, proxy and DNS profile management;
- a mature package transaction/recovery engine;
- full assistive-technology integration;
- richer online-source ranking, citation history and per-domain controls;
- currency conversion backed by an explicitly allowed data provider;
- exhaustive real-hardware certification across printers, scanners, DDC/CI,
  HDR, Bluetooth pairing variants and unusual EDID failures.

These are intentionally documented instead of represented by controls that do
nothing.
