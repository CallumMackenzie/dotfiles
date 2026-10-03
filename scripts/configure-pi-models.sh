#!/usr/bin/env bash
set -euo pipefail
settings="$1"
defaults="$2"
mkdir -p "$(dirname "$settings")"
umask 077
tmp="$(mktemp "${settings}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
if [[ -f "$settings" ]]; then
  jq -s '.[0] * .[1]' "$settings" "$defaults" > "$tmp"
else
  jq . "$defaults" > "$tmp"
fi
chmod 600 "$tmp"
mv -f "$tmp" "$settings"
