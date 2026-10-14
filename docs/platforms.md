# Where things run

This repo clones the org and records where each platform runs. It does not create a cloud account.

| Platform | What it is for | What it is not |
| --- | --- | --- |
| This repository | Org clone script and this map | A cluster or a product runtime |
| [warble-harness](https://github.com/warbletech/warble-harness) on Rancher Desktop or k3s | Local Reflexion and Avirka loop | A customer cluster |
| GitHub Actions | CI for warbletech repositories | A second required gate |
| Railway | Community site warbleoss.org and the read-only MCP at mcp.warbleoss.org | The enterprise sign-in |
| Cloudflare Pages | Public landing pages from warble-future | The application |
| RunPod | GPU bursts when credits are already on the account | A standing GPU pool |
| Dex | Sign-in. The issuer URL is set at install time and must match the UI | A hosted identity product on this repo |
| Stripe | Payment only when a secret key and a price id are set outside this repo | A price list. This repo does not charge a card |
| GitLab CE on our own cluster | Internal git and the runner named warble-frakma | Required CI, and not a GitLab.com Premium seat. The cost note is below |

## Dex issuer

Set one issuer. The Starling EX chart refuses to install when the UI is enabled and `dex.config.issuer` differs from `ui.dex.issuerUrl`. The portal reads `DEX_ISSUER` and calls `/auth`, `/token`, and `/userinfo` on that host.

GitLab can be a Dex connector for a GitLab you already run. That connector is not GitLab CI.

## CI and package cost

List prices as of 14 October 2026. [GitHub pricing](https://github.com/pricing), [Actions billing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions), [GitLab pricing](https://about.gitlab.com/pricing/). This is not an invoice.

| Host | Seats | CI minutes | Package storage |
|---|---|---|---|
| GitHub Free for an org | $0 | 2,000 a month on private repos, then $0.006 a minute for a 2-core Linux runner. Public standard runners are free. | 500 MB, then $0.25 per GB-month |
| GitHub Team | $4 per user each month | 3,000 a month, then the same $0.006 | 2 GB, then $0.25 per GB-month |
| GitLab.com Free | $0 | 400 a month, then $10 per 1,000 minutes | 10 GiB including git data, then $0.50 per GiB-month on paid plans |
| GitLab.com Premium | $29 per user each month, billed annually | 10,000 a month, then $10 per 1,000 minutes | 500 GiB |
| GitLab CE on a cluster we already run | $0 license | No minute meter. Jobs use nodes already paid for. | Disk growth is about $0.10 per GiB-month |

For five people, 3,000 private Linux minutes, and 10 GB of packages, GitHub Team is about $22 a month. GitLab.com Premium is $145 a month. Self-hosted CE adds no license. The clear increment on a cluster that already runs is the data disk and the load balancer, on the order of $20 a month, not a second cluster. A dedicated e2-standard-2 for GitLab alone is about $49 a month in us-central1 before disk and the forwarding rule. The longer note for our install is `gitlab/EDITION.md` in warble-docs.

## Clone the org

```bash
./scripts/clone-warbletech.sh --list
```

The script groups repositories into `enterprise/`, `oss/`, `products/`, and `internal/` under `~/warble-enterprise`.
