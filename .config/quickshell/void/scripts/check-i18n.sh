#!/bin/sh
set -eu

shell_dir=${1:-"$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"}
catalog_dir=$shell_dir/i18n
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/voidline-i18n.XXXXXX")
trap 'rm -rf -- "$tmp_dir"' EXIT HUP INT TERM

for tool in jq rg sort comm; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'i18n-check: missing development tool: %s\n' "$tool" >&2
        exit 2
    }
done

flatten_catalog() {
    jq -r 'paths(scalars) | map(tostring) | join(".")' "$1" | sort -u
}

flatten_catalog "$catalog_dir/en-US.json" >"$tmp_dir/reference"
status=0

for locale in de-DE pl-PL; do
    flatten_catalog "$catalog_dir/$locale.json" >"$tmp_dir/$locale"
    # Polish legitimately has additional few/many plural forms. Missing
    # English leaf keys are still errors; extra localized leaves are reported.
    comm -23 "$tmp_dir/reference" "$tmp_dir/$locale" >"$tmp_dir/missing-$locale"
    if [ -s "$tmp_dir/missing-$locale" ]; then
        printf '\nMissing keys in %s:\n' "$locale" >&2
        sed 's/^/  /' "$tmp_dir/missing-$locale" >&2
        status=1
    fi
    comm -13 "$tmp_dir/reference" "$tmp_dir/$locale" >"$tmp_dir/extra-$locale"
    if [ -s "$tmp_dir/extra-$locale" ]; then
        printf '\nLocale-only keys in %s (review plural forms):\n' "$locale"
        sed 's/^/  /' "$tmp_dir/extra-$locale"
    fi
done

rg -o --no-filename 'I18n\.(tr|plural)\("[^"]+"' "$shell_dir" \
    --glob '*.qml' --glob '*.js' \
    | sed -E 's/^I18n\.(tr|plural)\("//; s/"$//' \
    | sort -u >"$tmp_dir/used"

: >"$tmp_dir/missing-used"
while IFS= read -r key; do
    # Plural calls reference the object (for example `items`) while jq emits
    # its scalar leaves (`items.one` and `items.other`). Treat either form as
    # a valid catalog hit.
    if ! grep -Fqx -- "$key" "$tmp_dir/reference" \
            && ! grep -Fq -- "$key." "$tmp_dir/reference"; then
        printf '%s\n' "$key" >>"$tmp_dir/missing-used"
    fi
done <"$tmp_dir/used"
if [ -s "$tmp_dir/missing-used" ]; then
    printf '\nReferenced keys missing from en-US:\n' >&2
    sed 's/^/  /' "$tmp_dir/missing-used" >&2
    status=1
fi

cp "$tmp_dir/used" "$tmp_dir/expanded-used"
while IFS= read -r key; do
    grep -F -- "$key." "$tmp_dir/reference" >>"$tmp_dir/expanded-used" || true
done <"$tmp_dir/used"
sort -u -o "$tmp_dir/expanded-used" "$tmp_dir/expanded-used"
comm -13 "$tmp_dir/expanded-used" "$tmp_dir/reference" >"$tmp_dir/unused"
printf '\nUnused English catalog leaves: %s\n' "$(wc -l <"$tmp_dir/unused" | tr -d ' ')"
sed -n '1,40s/^/  /p' "$tmp_dir/unused"

# This deliberately reports rather than silently allow-listing debt. Material
# icon identifiers are filtered when they are a single lower_snake_case token.
rg -n '\b(text|title|subtitle|description|placeholderText|accessibleName|toolTipText|label):[[:space:]]*"[A-Za-z]' \
    "$shell_dir" --glob '*.qml' \
    | rg -v ':\s*text:\s*"[a-z0-9_]+"\s*$' \
    >"$tmp_dir/qml-literals" || true

printf '\nPotential untranslated QML strings: %s\n' "$(wc -l <"$tmp_dir/qml-literals" | tr -d ' ')"
sed -n '1,80s/^/  /p' "$tmp_dir/qml-literals"

rg -n "(printf|echo)[^#]*['\"][A-Za-z][^'\"]*[[:space:]][^'\"]*['\"]" \
    "$shell_dir/scripts" --glob '*.sh' \
    >"$tmp_dir/script-literals" || true
printf '\nPotential user-facing shell-script strings: %s\n' "$(wc -l <"$tmp_dir/script-literals" | tr -d ' ')"
sed -n '1,60s/^/  /p' "$tmp_dir/script-literals"

if [ "$status" -eq 0 ]; then
    printf '\nCatalog integrity: OK\n'
else
    printf '\nCatalog integrity: FAILED\n' >&2
fi
exit "$status"
