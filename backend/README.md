# Voidline shared backend

This workspace begins the migration from process-heavy QML service logic to one
unprivileged, typed backend shared by Quickshell, Settings, Lyra, the terminal,
and `voidlinectl`.

The current milestone deliberately implements only operations whose validation
and result checking are complete. Missing modules return `unsupported`; they do
not expose controls that appear to work.

## Security boundary

- `voidlined` runs as the logged-in user and listens only on
  `$XDG_RUNTIME_DIR/voidline/backend.sock`.
- The runtime directory is mode `0700`, the socket is mode `0600`, and every
  accepted connection must have the same peer UID.
- Requests are newline-delimited JSON, limited to 64 KiB, versioned, and decoded
  with unknown-field rejection.
- Actions are Rust enums with bounded arguments. There is no action containing a
  shell command, executable path, environment map, or unrestricted privileged
  file path.
- State-changing and dangerous actions return a short-lived, one-use
  confirmation token before execution.
- Privileged operations remain separate and will use narrowly scoped Polkit
  helpers; the user backend never runs as root.
- The packaged Wi-Fi secret helper accepts only `reveal <ssid>`, is installed
  root-owned under `/usr/lib/voidline`, and is authorized by one matching
  Polkit action. It cannot execute commands or read arbitrary paths.
- Audit logs contain action identifiers and outcomes, never prompts, passwords,
  clipboard contents, file contents, or model output.

## NetworkManager activation worker

`voidline-network` is a short-lived, unprivileged libnm client used by the
shared Quickshell network service. It selects an access point by interface and
BSSID, creates new profiles in memory, activates them through NetworkManager,
and persists a profile only after activation succeeds. Failed temporary
profiles are removed.

Wi-Fi credentials are accepted only as one line on the worker's standard input.
The caller closes that private pipe and clears its input control immediately.
Credentials are never accepted as command-line arguments, written to temporary
files, or included in worker output. The worker emits only a small state/error
protocol and wipes its credential buffer as soon as NetworkManager has accepted
the activation request.

## Development

```sh
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo audit
```

The GTK/VTE terminal crate additionally needs the Arch packages `gtk4`, `vte4`,
and `pkgconf`.
