#!/usr/bin/env bash
# crtsh-enum.sh — enumerate subdomains for a domain via crt.sh (Certificate Transparency).
# Usage: ./crtsh-enum.sh example.com [output.txt]
#   Default output: <domain>-hosts.txt (unique, sorted, one host per line).
# Method: public crt.sh JSON API, serial requests with pauses and retries.
# crt.sh rate-limits aggressively — do NOT parallelize this script.
set -euo pipefail

DOMAIN="${1:-}"
OUT="${2:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain> [output.txt]" >&2
  echo "Example: $0 example.com" >&2
  exit 1
fi
OUT="${OUT:-${DOMAIN}-hosts.txt}"

# Strip any leading/trailing whitespace and a trailing dot.
DOMAIN="$(echo "$DOMAIN" | tr -d '[:space:]' | sed 's/\.$//')"

CRTSH_URL="https://crt.sh/?q=%25.${DOMAIN}&output=json"

echo "[*] Querying crt.sh for *.${DOMAIN} (serial, with retries)..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# crt.sh often 429s or times out on the first try: up to 3 attempts,
# 10+ seconds between attempts, longer timeout each time.
attempt=1
ok=0
while [[ $attempt -le 3 ]]; do
  echo "[*] Attempt ${attempt}/3 ..."
  if curl -sS --max-time 60 -A "bug-bounty-recon-kit/1.0 (passive CT lookup)" \
      "$CRTSH_URL" -o "$TMP"; then
    # A valid answer is a JSON array; an error page is not.
    if head -c 1 "$TMP" | grep -q '\['; then
      ok=1
      break
    fi
    echo "[!] crt.sh returned a non-JSON response, retrying..." >&2
  else
    echo "[!] curl failed, retrying..." >&2
  fi
  attempt=$((attempt + 1))
  sleep $((attempt * 10))
done

if [[ $ok -ne 1 ]]; then
  echo "[!] crt.sh did not return usable data after 3 attempts. Try again later." >&2
  exit 1
fi

# Extract hostnames: prefer jq, fall back to plain grep/sed.
if command -v jq >/dev/null 2>&1; then
  jq -r '.[].name_value' "$TMP" 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^\*\.//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -F ".${DOMAIN}" \
    | grep -v ' ' \
    | sort -u > "$OUT"
else
  grep -o '"name_value": *"[^"]*"' "$TMP" \
    | sed -e 's/"name_value": *"//' -e 's/"$//' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^\*\.//' \
    | grep -F ".${DOMAIN}" \
    | grep -v ' ' \
    | sort -u > "$OUT"
fi

# Always include the apex domain itself.
echo "$DOMAIN" >> "$OUT"
sort -u -o "$OUT" "$OUT"

COUNT="$(wc -l < "$OUT")"
echo "[+] ${COUNT} unique hosts written to ${OUT}"
