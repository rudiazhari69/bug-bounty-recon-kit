#!/usr/bin/env bash
# livecheck.sh — check which hosts answer over HTTP(S), one polite request each.
# Usage: ./livecheck.sh hosts.txt [output.txt]
#   Default output: <hosts-basename>-livecheck.txt
# Output format: host | code | bytes | time_total | Location
#   code 000 = unreachable from here (DNS/TCP/timeout, not necessarily down).
#   Any other code (200/301/302/400/403/404/503/...) means the host is ALIVE —
#   only its root path does not serve content.
# Pace: serial, ~1-2 req/s (12s timeout + 0.5s sleep). Resumable: hosts
# already present in the output file are skipped.
set -euo pipefail

HOSTS_FILE="${1:-}"
OUT="${2:-}"

if [[ -z "$HOSTS_FILE" || ! -f "$HOSTS_FILE" ]]; then
  echo "Usage: $0 <hosts.txt> [output.txt]" >&2
  echo "Example: $0 example.com-hosts.txt" >&2
  exit 1
fi
BASE="$(basename "$HOSTS_FILE" .txt)"
OUT="${OUT:-${BASE}-livecheck.txt}"
touch "$OUT"

# Browser headers (same set as scripts/akamai-headers.sh, inlined so this
# script also works standalone). Plain curl gets blocked by many bot filters.
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
curl_browser() {
  curl --http2 --compressed --max-time 12 \
    -H "User-Agent: $UA" \
    -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H 'sec-ch-ua: "Google Chrome";v="141", "Not-A.Brand";v="8", "Chromium";v="141"' \
    -H "sec-ch-ua-mobile: ?0" \
    -H 'sec-ch-ua-platform: "Windows"' \
    -H "sec-fetch-dest: document" \
    -H "sec-fetch-mode: navigate" \
    -H "sec-fetch-site: none" \
    -H "sec-fetch-user: ?1" \
    -H "upgrade-insecure-requests: 1" \
    "$@"
}

check_one() {
  local host="$1"
  grep -q "^${host} |" "$OUT" && return 0

  local raw code size tm loc
  raw="$(curl_browser -s -D - -o /dev/null \
    -w "CODE:%{http_code} SIZE:%{size_download} TIME:%{time_total}" \
    "https://${host}/" 2>/dev/null || true)"
  code="$(echo "$raw" | grep -o 'CODE:[0-9]*' | tail -1 | cut -d: -f2)"
  size="$(echo "$raw" | grep -o 'SIZE:[0-9]*' | tail -1 | cut -d: -f2)"
  tm="$(echo "$raw" | grep -o 'TIME:[0-9.]*' | tail -1 | cut -d: -f2)"
  loc="$(echo "$raw" | grep -i '^location:' | tail -1 | sed 's/^[Ll]ocation: *//;s/\r//')"
  [[ -z "$code" ]] && code="000"
  [[ -z "$size" ]] && size="0"
  [[ -z "$tm" ]] && tm="0"
  [[ -z "$loc" ]] && loc="-"
  echo "${host} | ${code} | ${size} | ${tm} | ${loc}" >> "$OUT"
  sleep 0.5
}

TOTAL="$(grep -c . "$HOSTS_FILE" || true)"
echo "[*] Live-checking ${TOTAL} hosts (serial, ~1-2 req/s) → ${OUT}"
n=0
while IFS= read -r host || [[ -n "$host" ]]; do
  host="$(echo "$host" | tr -d '[:space:]')"
  [[ -z "$host" ]] && continue
  check_one "$host"
  n=$((n + 1))
  if (( n % 50 == 0 )); then
    echo "[*] ${n}/${TOTAL} done..."
  fi
done < "$HOSTS_FILE"

echo "[+] Done. Results in ${OUT}"
echo "    Alive (any HTTP code): $(grep -vc ' | 000 |' "$OUT" || true)"
echo "    Unreachable (000):     $(grep -c ' | 000 |' "$OUT" || true)"
