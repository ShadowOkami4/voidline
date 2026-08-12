#!/bin/sh
set -eu

# Installer-facing model preset helper. Lyra's runtime provider interface lives
# in ai-provider.sh; this script only supports hardware-tier setup workflows.

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
presets_file=$script_directory/../ai-model-presets.json

memory_gib() {
    awk '/^MemTotal:/ { print int($2 / 1048576); exit }' /proc/meminfo
}

recommended_preset() {
    memory=$(memory_gib)
    if command -v jq >/dev/null 2>&1 && [ -r "$presets_file" ]; then
        jq -r --argjson memory "$memory" '
            .presets[0] as $fallback
            | [.presets[] | select(.minimumRamGiB <= $memory)]
            | if length > 0 then last else $fallback end
            | [.id, .model] | @tsv
        ' "$presets_file"
        return
    fi
    if [ "$memory" -ge 64 ]; then
        printf '%s\t%s\n' workstation qwen3.5:27b
    elif [ "$memory" -ge 32 ]; then
        printf '%s\t%s\n' advanced qwen3.5:9b
    elif [ "$memory" -ge 12 ]; then
        printf '%s\t%s\n' balanced qwen3.5:4b
    else
        printf '%s\t%s\n' compact qwen3.5:2b
    fi
}

capabilities() {
    recommendation=$(recommended_preset)
    printf 'tier|%s\n' "$(printf '%s' "$recommendation" | cut -f1)"
    printf 'recommended|%s\n' "$(printf '%s' "$recommendation" | cut -f2)"

    if ! command -v ollama >/dev/null 2>&1; then
        printf '%s\n' 'backend|none' 'ready|0'
        return
    fi

    printf '%s\n' 'backend|ollama'
    if models=$(ollama list 2>/dev/null); then
        printf '%s\n' 'ready|1'
        printf '%s\n' "$models" | awk 'NR > 1 && NF > 0 { print "model|" $1 }'
    else
        printf '%s\n' 'ready|0'
    fi
}

presets() {
    command -v jq >/dev/null 2>&1 || exit 127
    jq -r '.presets[] | [
        .id, .label, .model, (.minimumRamGiB | tostring),
        (.downloadGiB | tostring), .description
    ] | @tsv' "$presets_file"
}

model_for_preset() {
    preset=${1:-}
    command -v jq >/dev/null 2>&1 || exit 127
    model=$(jq -r --arg preset "$preset" '
        .presets[] | select(.id == $preset) | .model
    ' "$presets_file")
    [ -n "$model" ] && [ "$model" != null ] || exit 2
    printf '%s\n' "$model"
}

case "${1:-}" in
    capabilities)
        capabilities
        ;;
    presets)
        presets
        ;;
    recommend)
        recommended_preset
        ;;
    pull-preset)
        shift
        ollama pull "$(model_for_preset "${1:-}")"
        ;;
    *)
        exit 2
        ;;
esac
