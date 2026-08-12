# Backend testing

## Automated gate

Run on Arch Linux with `rust`, `pkgconf`, and `vte4` installed:

```sh
cargo fmt --all -- --check
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo build --locked --release
```

The protocol tests cover malformed envelopes, unknown action fields, desktop ID
argument injection, output path traversal, numeric bounds, and the distinction
between safe, confirmation, and dangerous actions.

## Manual integration matrix

```sh
voidlinectl health
voidlinectl capabilities
voidlinectl state network
quickshell -p "$HOME/.config/quickshell/void" ipc --any-display call network scan
voidlinectl --dry-run --json wifi false
voidlinectl --dry-run --json session reboot
stat -c '%a %U %F' "$XDG_RUNTIME_DIR/voidline" \
  "$XDG_RUNTIME_DIR/voidline/backend.sock"
```

Expected results:

- backend starts on demand;
- runtime directory/socket are user-owned `0700`/`0600`;
- invalid arguments fail without launching a child;
- protected/dangerous actions return `confirmation_required`;
- cancelling or allowing a token to expire performs no action;
- Network Settings, Action Center, and `voidlinectl state network` show the same
  active network/backend;
- killing `voidlined` causes systemd recovery without crashing Quickshell;
- disabling Lyra leaves no model loaded and eventually stops its provider.

Terminal QA must include Unicode, long-running processes, resize, selection,
copy/paste, font scaling, shell exit, and forced window close. It must be run as
an ordinary user under Wayland.
