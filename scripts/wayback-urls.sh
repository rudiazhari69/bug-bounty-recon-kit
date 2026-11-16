#!/usr/bin/env bash
# wayback-urls.sh — harvest known URLs for a domain from the Wayback Machine.
# Usage: ./wayback-urls.sh example.com [output.txt] [from-year] [to-year]
#   Default output: <domain>-wayback.txt (unique, sorted, one URL per line).
#   Optional year range (default: all years). Use it when the result looks
#   truncated — the CDX API commonly caps a single query at ~20,000 rows,
#   so re-run per year to get the full archive.
#   Example: ./wayback-urls.sh example.com "" 2023 2024
# Method: public CDX API (web.archive.org). No target requests at all —
# this only queries the archive, never the target itself.
set -euo pipefail

DOMAIN="${1:-}"
OUT="${2:-}"
FROM="${3:-}"
TO="${4:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain> [output.txt] [from-year] [to-year]" >&2
  echo "Example: $0 example.com" >&2
  exit 1
fi
OUT="${OUT:-${DOMAIN}-wayback.txt}"
DOMAIN="$(echo "$DOMAIN" | tr -d '[:space:]' | sed 's/\.$//')"

# CDX query: all subdomains, original URLs only, collapse duplicates.
CDX="https://web.archive.org/cdx/search/cdx?url=*.${DOMAIN}/*&output=text&fl=original&collapse=urlkey"
[[ -n "$FROM" ]] && CDX="${CDX}&from=${FROM}"
[[ -n "$TO" ]] && CDX="${CDX}&to=${TO}"

echo "[*] Querying Wayback CDX for *.${DOMAIN} ..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

attempt=1
ok=0
while [[ $attempt -le 3 ]]; do
  if curl -sS --max-time 120 -A "bug-bounty-recon-kit/1.0 (Wayback CDX lookup)" \
      "$CDX" -o "$TMP"; then
    ok=1
    break
  fi
  echo "[!] CDX request failed, retrying in 10s (attempt ${attempt}/3)..." >&2
  attempt=$((attempt + 1))
  sleep 10
done

if [[ $ok -ne 1 ]]; then
  echo "[!] Wayback CDX did not answer after 3 attempts. Try again later." >&2
  exit 1
fi

# Keep only real URLs, drop empty lines, deduplicate.
grep -E '^https?://' "$TMP" | sort -u > "$OUT"

COUNT="$(wc -l < "$OUT")"
echo "[+] ${COUNT} unique archived URLs written to ${OUT}"
if [[ "$COUNT" -eq 20000 ]]; then
  echo "[!] Exactly 20,000 rows — the CDX result was probably truncated." >&2
  echo "    Re-run per year, e.g.: $0 ${DOMAIN} \"\" 2023 2023" >&2
fi
