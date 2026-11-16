#!/usr/bin/env bash
# js-endpoints.sh — fetch JavaScript bundles and extract candidate API paths.
# Usage: ./js-endpoints.sh <bundle-url-or-file>... [> output]
#   Accepts one or more JS bundle URLs (https://...) and/or local .js files.
#   Output: unique sorted list of candidate paths, one per line.
#   Example: ./js-endpoints.sh https://example.com/static/main.js > js-endpoints.txt
# Method: plain grep over bundle text — no parser, no heavy dependencies.
# The output is CANDIDATES, not confirmed endpoints: verify each one against
# the program scope before requesting it.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <bundle-url-or-file>... " >&2
  echo "Example: $0 https://example.com/static/main.js" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

n=0
for src in "$@"; do
  n=$((n + 1))
  dest="${TMPDIR}/bundle-${n}.js"
  if [[ "$src" =~ ^https?:// ]]; then
    echo "[*] Downloading ${src}" >&2
    # Polite fetch: browser headers, 30s timeout.
    if ! curl -sS --http2 --compressed --max-time 30 \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36" \
        -H "Accept: */*" \
        "$src" -o "$dest" 2>/dev/null; then
      echo "[!] Failed to download ${src}, skipping." >&2
      continue
    fi
  elif [[ -f "$src" ]]; then
    cp "$src" "$dest"
  else
    echo "[!] Not a URL or a file: ${src}, skipping." >&2
    continue
  fi
done

# 1) Quoted absolute paths: "/api/v2/users", '/oauth/token', `/cms/pages`
# 2) API-ish fragments: api/v2/..., /v1/..., /v2/... inside longer strings
# 3) Template-literal paths with ${...} placeholders are kept as-is.
{
  grep -rhoE '["'"'"'`]/[A-Za-z0-9_/${}.-]{2,}' "${TMPDIR}"/bundle-*.js 2>/dev/null \
    | sed -e 's/^["'"'"'`]//' || true
  grep -rhoE '["'"'"'`][A-Za-z0-9_.-]*/api/[A-Za-z0-9_/$.{}-]{1,}' "${TMPDIR}"/bundle-*.js 2>/dev/null \
    | sed -e 's/^["'"'"'`]//' -e 's|^[^/]*/|/|' || true
} | sed \
    -e 's/[?&].*$//' \
    -e 's/[,;:]$//' \
    -e 's/\.\.$//' \
  | grep -E '^/(api|v[0-9]+|oauth|auth|users|account|orders?|carts?|products?|checkout|payment|admin|config|graphql)' \
  | sort -u
