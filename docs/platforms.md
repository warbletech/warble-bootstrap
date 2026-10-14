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
| GitLab | An existing install some repos already mirror to | Required CI. New work uses GitHub Actions |

## Dex issuer

Set one issuer. The Starling EX chart refuses to install when the UI is enabled and `dex.config.issuer` differs from `ui.dex.issuerUrl`. The portal reads `DEX_ISSUER` and calls `/auth`, `/token`, and `/userinfo` on that host.

GitLab can be a Dex connector for a GitLab you already run. That connector is not GitLab CI.

## Clone the org

```bash
./scripts/clone-warbletech.sh --list
```

The script groups repositories into `enterprise/`, `oss/`, `products/`, and `internal/` under `~/warble-enterprise`.
