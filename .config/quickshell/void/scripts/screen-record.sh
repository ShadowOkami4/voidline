#!/bin/sh
set -eu

video_root="${XDG_VIDEOS_DIR:-${HOME}/Videos}"
recording_dir="${video_root}/Screencasts"
mkdir -p "${recording_dir}"
recording_path="${recording_dir}/voidline-$(date +%Y%m%d-%H%M%S)-$$.mp4"
output_name=${1:-}

printf 'path|%s\n' "${recording_path}"
if [ -n "${output_name}" ]; then
    exec wf-recorder -o "${output_name}" -a -f "${recording_path}"
fi
exec wf-recorder -a -f "${recording_path}"
