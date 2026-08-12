# Lyra AI architecture and resource requirements

Lyra is the product name for Voidline's optional local assistant. It is a name,
not an acronym. Branding, Quickshell interfaces, action broker, resource manager,
and inference provider remain separate so any of them can be replaced
independently.

This document is the implementation contract for both **Ask Lyra** in the App
Center and the optional standalone assistant application. A capability described
as required here must not be represented by a working-looking control until its
backend is implemented. Unsupported fields stay hidden or are explicitly marked
unavailable.

## Non-negotiable boundaries

- AI is an optional package. Without its feature manifest, no AI UI, provider
  probe, model download, user service, or background resource is allowed.
- Inference runs outside Quickshell in a separate, restartable user service.
- Quickshell talks to a stable local assistant API, never directly to a specific
  inference engine.
- Models cannot execute shell text. System operations pass through the existing
  allow-listed, typed action broker and its confirmation and Polkit levels.
- Network access remains disabled, ask-per-use, session-only, or persistently
  allowed according to the user's explicit policy.
- Resource monitoring is event-driven or active only while an AI surface is open
  or a generation is running. High-frequency background polling is forbidden.

## Performance and resource telemetry

The service API must expose one versioned telemetry object shared by both UIs.
It contains, where the selected provider can report it:

- selected model, model role, quantization, on-disk size, and loaded size;
- configured context window and current context use;
- input, output, and conversation-total token counts;
- generation speed in tokens per second and measured time to first token;
- process and system CPU usage and RAM usage;
- GPU usage and GPU or unified-memory use;
- effective execution device: CPU, GPU, or hybrid;
- GPU-offloaded layers and layers resident in system memory;
- loaded, loading, generating, unloading, unloaded, and error states.

Ask Lyra shows only a compact status row: model, execution device, loaded state,
current token usage, and live generation speed. Details, graphs, history, and
tuning controls belong in the standalone application. Missing measurements must
display as unavailable rather than as zero.

Token and timing metrics must come from provider responses or the service's
monotonic request timing. System statistics must not be sampled faster than once
per second while visible and should fall back to a much slower health interval or
stop entirely while hidden and idle.

## Compatibility estimator and warnings

Before a model is downloaded or loaded, the resource manager creates an estimate
for model weights, context/KV cache, inference buffers, provider overhead, and the
desktop reserve. The estimate must identify its uncertainty and compare against
currently available RAM and dedicated or unified GPU memory.

A confirmation warning is required when the model or chosen settings may:

- exceed safe GPU or unified-memory capacity;
- consume an unsafe share of RAM or leave too little for the desktop;
- make the selected context window impractical;
- cause sustained swapping or extremely slow generation;
- compete materially with a running game or other GPU-heavy application.

The dialog shows estimated RAM, GPU/unified-memory use, remaining desktop reserve,
and at least one safer recommendation. Advanced users may continue after explicit
confirmation; the estimator must not silently reject every configuration that
does not fit completely in VRAM.

## Hardware planner and hybrid inference

Automatic mode is the default. Its plan includes:

- backend and accelerator;
- GPU layer count or equivalent offload budget;
- desktop RAM and GPU-memory reserves;
- context-window limit and batch size;
- CPU thread limit;
- memory-mapping policy;
- warm-model and idle-unload policy.

Hybrid CPU/GPU execution is a first-class configuration. A model that needs about
12 GiB on a system with 32 GiB RAM and a 4 GiB GPU should receive a conservative
partial-offload plan when the backend supports it, not an all-or-nothing GPU plan.

For integrated GPUs, GPU memory is not added to system RAM as if it were separate.
The planner detects unified memory and accounts for reserved graphics memory,
compositor use, display count and resolution, other GPU processes, current memory
pressure, and a configurable operating-system reserve. It must never target nearly
all reported shared memory.

The user-facing presets are:

- **Automatic** — hardware- and workload-aware planning; default.
- **Low resource usage** — larger reserves, small context, short warm period.
- **Balanced** — responsive local assistance without starving the desktop.
- **Maximum performance** — higher offload and longer residency with warnings.
- **Custom** — explicit limits with validation and recovery defaults.

## Model recommendations and roles

Recommendations use detected RAM, dedicated or unified GPU memory, CPU architecture
and cores, supported accelerator, measured or estimated throughput, quantization,
model and context size, intended role, and current heavy workloads. The UI explains
the decisive factors instead of merely labelling one model recommended.

Offer several task-oriented choices when compatible models are available:

- fast and lightweight;
- balanced;
- best local quality;
- advanced reasoning;
- coding;
- vision, only with a supported provider and hardware path.

Usable latency, stability, and desktop headroom take precedence over the largest
model that can technically load.

The provider configuration maps logical roles to models: command, reasoning,
coding, embedding/search, vision, and full assistant. A small command model may
serve App Center actions while the standalone application uses a larger reasoning
model. Only the active role is loaded unless the configured memory budget safely
allows another warm model. Inactive roles unload according to their own timeout.

## Dynamic resource adjustment

The service reacts to generation lifecycle, memory-pressure events, AI-window
visibility, and known heavy applications. Subject to provider support, it may:

- reduce GPU offload while a game is running;
- constrain a new conversation's context under memory pressure;
- pause admission of new work or unload an idle model under critical pressure;
- warm the fast command model when Ask Lyra opens;
- use a larger role-specific model only for an explicitly complex request.

An active generation is never silently migrated in a way that corrupts its
context. Any restart or fallback is reported to the user. Dynamic changes are
logged in the action/performance history and can be disabled in Custom mode.

## Provider contract and backend decision

The provider adapter must support, directly or through the assistant service:

- streaming and cancellation;
- hybrid CPU/GPU inference and tunable offload;
- Vulkan or another appropriate Arch Linux accelerator;
- quantized models, context and batch control;
- multiple role-based models without loading all of them;
- schema-constrained structured output or validated tool calls;
- model load, unload, health, and resource reporting;
- reliable subprocess/service supervision and a stable local API.

The existing Ollama adapter remains provisional. It may remain the default only
after repeatable cold-start, warm-start, token-rate, first-token, cancellation,
memory, hybrid-offload, and crash-recovery measurements on representative Arch
hardware. If it cannot expose or control the required scheduling and telemetry,
replace it behind the same provider contract with a suitable llama.cpp-based or
other local engine. Backend availability alone is not a selection criterion.

Benchmark results must record hardware, driver/backend, model digest and
quantization, context, batch, thread and offload settings, display configuration,
idle memory, peak memory, first-token latency, token rate, and failure behavior.

## Separate user service

The inference host is a systemd user service or socket-activated equivalent. It:

- exists and starts only when the optional AI package is installed and enabled;
- starts on demand where the provider permits it;
- unloads models and may stop after configurable inactivity;
- restarts safely after crashes with bounded backoff;
- publishes health, lifecycle, performance, and compatibility information;
- accepts cancellation without blocking the Quickshell UI;
- rejects clients other than the current user and never listens on a public
  interface by default.

The UI must distinguish service stopped, starting, ready, model loading,
generating, cancelling, degraded, and failed states. It must never claim that an
action or generation succeeded merely because the request was submitted.

## User controls

The assistant settings provide:

- enable/disable and internet-access policy;
- preferred and automatically recommended model;
- performance preset;
- CPU-thread, GPU-offload, RAM, GPU/unified-memory, context, and batch limits;
- model unload timeout and background-service behavior;
- downloaded-model list, role mapping, download/remove, and cache cleanup;
- stop and restart service actions;
- compatibility estimates and the reason for each recommendation.

Automatic safe values are always available as a recovery action. Raw offload,
batch, memory-mapping, provider, and diagnostic controls stay behind AI Advanced
Mode or Developer Mode. Removing models, clearing caches, overriding unsafe
estimates, and restarting active work require appropriate confirmation.

## Delivery stages

1. Define the versioned provider, telemetry, policy, and lifecycle schemas.
2. Add service supervision, cancellation, metrics, and safe on-demand lifecycle.
3. Implement hardware detection, unified-memory accounting, estimates, and presets.
4. Benchmark Ollama and at least one viable alternative on representative Arch
   hardware; record the provider decision.
5. Add the compact Ask Lyra telemetry row and standalone performance dashboard.
6. Add role-based models, pressure-aware adjustment, model management, and advanced
   controls without weakening the action-security boundary.
