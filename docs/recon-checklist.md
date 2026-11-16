# Passive Recon Checklist

Work through this in order. **Stop after step 7 and review before any
active testing.** Every step here is passive: public data sources and at
most one polite request per host.

## 0. Scope first — before anything else

- [ ] Read the program's scope page in full (in-scope assets, tiers,
      out-of-scope list, rules on automation and rate limits).
- [ ] Write down the exact in-scope domains. Anything not on that list is
      out of bounds — including hosts you discover later.
- [ ] Note the rate limit (if none is stated, stay under **5 req/s**).
- [ ] Note what is explicitly out of scope (common: brute force, DoS,
      self-XSS, missing security headers, pre-auth account takeover,
      subdomain takeover without proof).

## 1. Subdomain enumeration

- [ ] Run `./scripts/crtsh-enum.sh example.com` → `example.com-hosts.txt`.
- [ ] Deduplicate and strip wildcard prefixes (the script does this).
- [ ] Sanity-check the list: remove hosts outside the in-scope domains.
- [ ] Count the hosts. A few hundred is normal for a large program.

## 2. Live-host check

- [ ] Run `./scripts/livecheck.sh example.com-hosts.txt`.
- [ ] Sort the results by status code. Remember:
  - `200` — live with content at root. Read these first.
  - `301` / `302` / `307` — redirect. Check the `Location`: if it points
    **outside** the program scope, do not follow it.
  - `400` / `403` / `404` / `503` — still **alive** (DNS + TCP + HTTP
    worked). A uniformly gated set of hosts (e.g. an API family all
    answering 403) is a live API surface, not a dead end.
  - `000` — unreachable from your network. Usually dead/parked, not
    "blocked" (a block normally answers 403, not silence).
- [ ] Make a shortlist of interesting hosts: storefronts, `api`, `app`,
      `pay`, `order`, `checkout`, `account`, `member`, queue systems,
      third-party gateways, and any dev/UAT host that answers.
- [ ] Note any host that answers slowly (>5 s) — record it, do not chase
      timing (DoS testing is out of scope).

## 3. Tech fingerprint (passive only)

- [ ] For each shortlisted host, note the response headers (`Server`,
      `X-Powered-By`, CDN headers) and the page title.
- [ ] Identify the stack (e.g. e-commerce platform, SPA framework, CMS).
      One shared codebase across brands = one bug class can apply
      everywhere; prove it once, on one asset.
- [ ] Save one sample HTML page per distinct stack for reference.

## 4. JavaScript endpoints

- [ ] Find the main JS bundles (check the HTML `<script src>` tags of the
      shortlisted hosts).
- [ ] Run `./scripts/js-endpoints.sh <bundle-url>...` → candidate paths.
- [ ] Group the paths: users/addresses, carts, orders, payments, coupons,
      OAuth, config, file upload. The user/order/payment group is usually
      the richest surface.
- [ ] Verify the API base URL the bundle actually uses — framework defaults
      (e.g. `/occ/v2/`) are often overridden at runtime (e.g. `/api/v2/`).
      One wrong prefix wastes a whole phase.
- [ ] Note any config endpoint that returns the full front-end config —
      it maps every backend, including chat/AI widgets.

## 5. Archived URLs

- [ ] Run `./scripts/wayback-urls.sh example.com` → archived URLs.
- [ ] If the output hits exactly 20,000 rows, re-run per year.
- [ ] Diff archived paths against the live JS endpoints: paths in the
      archive but not in the current bundle are removed features — sometimes
      still live.
- [ ] Check `/.well-known/` paths in the archive (`security.txt`,
      `openid-configuration`) — cheap passive information.

## 6. Interesting hosts — second pass

- [ ] Re-check the shortlist against the JS + archive findings: which hosts
      serve the API, which serve media, which are queues/gateways.
- [ ] Look for uniform patterns: same status code + same body size across
      a host family usually means one shared service.
- [ ] Write a one-line note per interesting host: what it is, why it
      matters, what would prove it.

## 7. STOP — review before active testing

- [ ] Re-read the scope. Confirm every host/endpoint on your shortlist is
      in scope.
- [ ] Write hypotheses as "claim + evidence needed" (e.g. "endpoint X
      might allow user A to read user B's order — needs own account vs
      second account test").
- [ ] Confirm you have the accounts the test needs (usually your own
      account, sometimes a second account — some programs require a
      program-issued email for this).
- [ ] **Only now** plan active testing — inside the rules, with your own
      data, at polite rates. Anything that needs another user's data, a
      bypass, or hammering the target is a stop-and-ask moment, not a
      try-it moment.

## What NOT to do during recon

- Do not run vulnerability scanners or fuzzers (active, noisy, usually
  against program rules).
- Do not brute-force directories, subdomains, or credentials.
- Do not follow redirects to out-of-scope domains.
- Do not test with anyone else's account, order, receipt, or token.
- Do not record secrets, tokens, or credentials you happen to see — note
  only that they exist, where, and what they would grant.
