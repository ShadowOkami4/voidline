# Security audit — backend migration milestone

## Fixed in this milestone

- Added a typed protocol with unknown-field rejection and bounded frames.
- Removed raw command, executable, environment, and unrestricted path fields
  from the action protocol.
- Added range/identifier/handle validation and regression tests for argument
  injection and path traversal.
- Added same-UID Unix peer checks, `0700` runtime directories, `0600` sockets,
  connection limits, request rate limits, request timeouts, and child cleanup.
- Added one-use expiring confirmation tokens. Power-off, reboot, and logout
  cannot execute through a normal unconfirmed request.
- Audit logs contain action identifiers and outcomes, not arguments, prompts,
  credentials, clipboard contents, or file paths.
- Wi-Fi passphrases remain on stdin and in the short-lived iwd D-Bus agent; they
  are not command-line arguments or backend audit fields.
- Removed the duplicate always-enabled Ollama unit. Lyra starts on demand,
  unloads models, and schedules an idle provider stop.
- Desktop-entry IDs are validated before `gtk-launch`; the backend never parses
  an application's `Exec` line itself.
- Standalone Lyra and the Rust terminal run as the session user.

## Deliberately not implemented yet

- No privileged backend or broad Polkit rule exists. Package updates and
  system-wide configuration must wait for separate narrow helpers.
- Arbitrary local paths are not accepted. File and wallpaper operations require
  a future server-issued resource-handle registry.
- Plugins/providers cannot be loaded from arbitrary paths.
- Online Lyra tools are not enabled. Internet policy exists, but no online tool
  may run until source display, untrusted-content isolation, and per-request
  approval are enforced by the backend.

## Remaining high-priority work

1. Move all remaining QML-owned system calls behind typed module APIs.
2. Add server-pushed state events and remove duplicate UI polling.
3. Implement narrowly scoped Polkit helpers for updates and system settings,
   with action-specific policies and no stringly typed command bridge.
4. Add resource handles backed by canonical paths, owner checks, symlink-safe
   opens, allowed roots, expiry, and revocation.
5. Fuzz protocol framing/deserialization and add live D-Bus mock tests.
6. Review every helper that writes configuration for atomic writes, symlink
   rejection, ownership, permissions, rollback, and concurrency.
7. Split Lyra planning from action authorization completely; the model remains
   an untrusted proposer and never receives confirmation tokens.

This document is an audit record, not a claim that the complete desktop is
security-finished.
