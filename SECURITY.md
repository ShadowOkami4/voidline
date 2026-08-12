# Security policy

Voidline `0.3.0dev` is a development release and does not yet have a stable
security-support window.

Please do not publish passwords, tokens, private file contents, Wi-Fi secrets,
or working privilege-escalation details in a public issue. Use GitHub's private
vulnerability reporting for `ShadowOkami4/voidline` when available. Otherwise,
open a minimal issue asking the maintainer for a private reporting channel.

Include the affected version, component, required privileges, impact, and safe
reproduction outline. Remove credentials and personal paths from logs.

Voidline's security boundaries are documented in
[`backend/README.md`](backend/README.md) and
[`backend/ARCHITECTURE.md`](backend/ARCHITECTURE.md). The user backend and Lyra
must remain unprivileged; model output is never an executable command; and
privileged helpers must expose only narrow validated operations.
