#!/bin/sh
set -eu

repository=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=$(tr -d '\r\n' <"$repository/VERSION")
tag=v$version
output=${1:-"$repository/dist"}

git -C "$repository" rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1 || {
    printf 'Tag %s does not exist. Commit and tag the validated release first.\n' "$tag" >&2
    exit 66
}
command -v zstd >/dev/null 2>&1 || {
    printf '%s\n' 'zstd is required to build release archives.' >&2
    exit 69
}

install -d -m 755 "$output"
temporary=$(mktemp -d)
trap 'rm -R -- "$temporary"' EXIT HUP INT TERM
prefix=voidline-$version/

git -C "$repository" archive --format=tar --prefix="$prefix" "$tag" \
    >"$temporary/voidline-$version.tar"
gzip -n -9 -c "$temporary/voidline-$version.tar" \
    >"$output/voidline-$version-source.tar.gz"
zstd -q -19 -f "$temporary/voidline-$version.tar" \
    -o "$output/voidline-$version-source.tar.zst"

(
    cd "$output"
    sha256sum "voidline-$version-source.tar.gz" \
        "voidline-$version-source.tar.zst" >SHA256SUMS
)
printf 'Created release archives and SHA256SUMS in %s.\n' "$output"
