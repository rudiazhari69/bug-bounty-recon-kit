#!/usr/bin/env bash
# akamai-headers.sh — reusable curl wrapper with full browser headers.
# Usage: source this file, then call curl_browser <curl-args> <url>.
#   source ./scripts/akamai-headers.sh
#   curl_browser -s https://example.com/ -o page.html
# Why: many sites sit behind bot protection (e.g. Akamai) that blocks plain
# curl with a 403, while a request carrying HTTP/2 + a modern Chrome
# user-agent + sec-ch-ua / sec-fetch headers is served normally.
# This only makes your requests LOOK like a browser — it does not bypass
# authentication, and it must only be used against in-scope targets.
#
# For XHR/API requests, use curl_api instead: it swaps the fetch metadata
# (sec-fetch-dest: empty, sec-fetch-mode: cors, Accept: application/json).
#   source ./scripts/akamai-headers.sh
#   curl_api -s "https://example.com/api/v2/basesites?fields=FULL"

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'

curl_browser() {
  curl --http2 --compressed --max-time 25 \
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

curl_api() {
  curl --http2 --compressed --max-time 25 \
    -H "User-Agent: $UA" \
    -H "Accept: application/json" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H 'sec-ch-ua: "Google Chrome";v="141", "Not-A.Brand";v="8", "Chromium";v="141"' \
    -H "sec-ch-ua-mobile: ?0" \
    -H 'sec-ch-ua-platform: "Windows"' \
    -H "sec-fetch-dest: empty" \
    -H "sec-fetch-mode: cors" \
    -H "sec-fetch-site: same-origin" \
    "$@"
}

# Demo (runs only when executed directly, not when sourced):
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <url>   (or: source $0 && curl_browser <url>)" >&2
    echo "Example: $0 https://example.com/" >&2
    exit 1
  fi
  curl_browser -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s (%{size_download} bytes)\n" "$1"
fi
