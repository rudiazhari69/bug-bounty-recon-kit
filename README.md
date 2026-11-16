# bug-bounty-recon-kit

A small, dependency-light starter kit for **passive** bug-bounty reconnaissance.
It maps a target's public attack surface — subdomains, live hosts, JavaScript
endpoints, and archived URLs — using only public data sources and single,
polite HTTP requests. No scanning, no brute force, no exploitation.

The workflow mirrors a proven manual recon loop:

```
subdomain enum  →  live-host check  →  JS endpoint extraction  →  Wayback URL harvest
   crt.sh              curl                    grep                      CDX API
```

## What is in the kit

| File | What it does |
| --- | --- |
| `scripts/crtsh-enum.sh` | Enumerate subdomains from crt.sh (Certificate Transparency logs) |
| `scripts/livecheck.sh` | Check which hosts answer over HTTP(S) and record status codes |
| `scripts/js-endpoints.sh` | Fetch JS bundles and extract candidate API paths |
| `scripts/wayback-urls.sh` | Harvest known URLs for a domain from the Wayback Machine |
| `scripts/akamai-headers.sh` | Reusable `curl` wrapper with full browser headers for bot-protected sites |
| `docs/recon-checklist.md` | Step-by-step passive recon checklist |

## Prerequisites

- `bash` 4+
- `curl`
- `jq` (optional — used when available, every script has a plain-text fallback)
- `grep`, `sort`, `sed` (standard Unix tools)

No Python, no Go, no API keys, no accounts.

## Quick start

```bash
# 1. Enumerate subdomains (Certificate Transparency, public data)
./scripts/crtsh-enum.sh example.com
# → example.com-hosts.txt

# 2. Check which hosts are actually alive (one polite request per host)
./scripts/livecheck.sh example.com-hosts.txt
# → example.com-livecheck.txt

# 3. Extract API endpoints from the site's JavaScript bundles
./scripts/js-endpoints.sh https://example.com/static/main.js
# → js-endpoints.txt

# 4. Harvest archived URLs (things the current site no longer links to)
./scripts/wayback-urls.sh example.com
# → example.com-wayback.txt
```

Then work through `docs/recon-checklist.md` and write up what you found
**before** doing any active testing.

## Politeness rules (read this first)

- **Max 5 requests/second to any target** — the scripts run at ~1–2 req/s by
  default (serial requests + sleeps). Do not remove the sleeps to go faster.
- **One root request per host** in the live-check. A 404/400/403/503 still
  means the host is *alive* (DNS + TCP + HTTP all worked) — only the root
  path does not serve content.
- **Respect `robots.txt`, rate limits, and the program's rules.** If a host
  answers 429 or starts blocking you, stop and back off.
- **crt.sh rate-limits aggressively.** `crtsh-enum.sh` makes serial requests
  with long pauses and retries. Be patient; do not parallelize it.
- **The Wayback CDX API caps results** (commonly around 20,000 rows per
  query). If output looks truncated at a round number, re-run per year —
  see `scripts/wayback-urls.sh`.

## Scope & legal warning

**Only test targets you are authorized to test.**

- This kit is for use inside a bug-bounty program scope, or against systems
  you own / have written permission to test. Read the program's scope and
  rules in full before running anything — including these passive scripts.
- Passive recon still sends requests to the target. Out-of-scope hosts,
  third-party services, and redirect targets are **not** fair game: if a
  redirect points outside the program scope, do not follow it.
- Never use this kit for brute force, credential stuffing, denial of
  service, unauthorized access, or any active exploitation. That is not
  recon, and it will get your bounty account banned (or worse).
- You are responsible for how you use these scripts. The authors accept no
  liability for misuse.

## How the pieces fit together

1. **Subdomain enum** — crt.sh lists every certificate ever issued for a
   domain, which reveals subdomains the site never links to. Deduplicate,
   strip wildcard prefixes, and you have a host list.
2. **Live-host check** — most enumerated hosts are dead, parked, or
   internal-only. One request each tells you which 60%-ish actually answer,
   and *how* they answer (200 content, 404 gateway, 403 gated, redirect…).
   Interesting hosts are usually the ones that answer with content, or the
   ones that are uniformly gated (a gated API is still a live API).
3. **JS endpoint extraction** — modern front-ends ship their whole API map
   in JavaScript bundles: user/address/order/payment paths, OAuth endpoints,
   config endpoints. Grep the bundles and you get the API surface without
   touching the API itself.
4. **Wayback harvest** — the archive remembers endpoints the current bundle
   no longer contains: old API versions, removed features, forgotten admin
   paths. Cross-check archived paths against the live bundle.

After these four steps, **stop and review**. Write down the interesting
hosts and endpoints, check them against the program scope, and only then
decide what (if anything) to test actively — with your own accounts, inside
the rules.

## Contributing

Issues and pull requests are welcome. Keep additions passive, generic, and
dependency-light, and never include real target hostnames or credentials.

## License

MIT — see [LICENSE](LICENSE).
