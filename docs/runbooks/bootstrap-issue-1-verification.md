# Bootstrap verification notes (Issue #1)

Repo-side checks for multi-platform cloning and the infrastructure
target matrix. This does not clone the org onto a developer machine
and does not change DNS or the cluster.

## Verified in-repo

- `scripts/clone-warbletech.sh --list` returns the current GitHub org
  list (52 repositories when checked on 7 Nov 2026) and places
  `warble-idp-portal`, `warble-saas-marketplace`, and
  `warble-founders-gtm` in `internal/`.
- Those three names are now pinned in `group_for`, so they stay in
  `internal/` even if visibility later changes.
- `scripts/clone-warbletech.ps1` is a Windows PowerShell counterpart
  (`-List`, `-Clean`, `-Dest`, `-Force`). It lists and indexes the same
  way; cloning is sequential.
- `docs/platforms.md` no longer has a broken `app.warblecloud.com`
  label (a BEL character had eaten the leading "a"). The new
  infrastructure target matrix matches the three sibling repos.

## Public DNS (Cloudflare DoH, 7 Nov 2026, Asia/Calcutta)

| Domain | Result |
| --- | --- |
| `app.warblecloud.com` | `35.190.63.216` (matches marketplace / runbook ingress IP) |
| `warblecloud.com` | Cloudflare anycast `104.21.78.137`, `172.67.222.105` |
| `idp.warblecloud.com` | No public A record |
| `dex.warblecloud.com` | No public A record |

## Not run

- A full `clone-warbletech.sh` of every org repository.
- Creating or changing Cloudflare DNS records.
- Any cluster apply or deploy.

## Open questions for @warble-tech

1. Sibling runbooks want DNS-only A records for `idp.warblecloud.com`
   and `dex.warblecloud.com` pointing at `35.190.63.216`. Should those
   records be created (a live DNS change)?
2. Is `internal/` the right layout group for the three Section 1 repos,
   or should `warble-founders-gtm` sit under `products/` with the other
   satellite sites?
