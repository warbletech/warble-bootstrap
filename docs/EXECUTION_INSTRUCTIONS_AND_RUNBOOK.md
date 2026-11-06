# Warble Cloud (`warblecloud.com`) — Detailed Execution Instructions & Operator Runbook

**Organization:** [`https://github.com/warbletech`](https://github.com/warbletech)  
**Entities:** `warblecloud, LLC` (Delaware) · `Chirpstack LLP` (India Engineering)  
**Live GKE Cluster:** `warble-byok` (`us-central1-a`, GCP Project `green-device-505513-k4`)  
**Canonical Secrets Store:** GCP Secret Manager (`warble-tech` project)  
**Companion Document:** [`WARBLECLOUD_MASTER_BLUEPRINT.md`](./WARBLECLOUD_MASTER_BLUEPRINT.md)

---

## 1. Current Production Cluster & Service Status (`warble-byok`)

| Component | Namespace | Status | Details |
| :--- | :--- | :--- | :--- |
| **`warble-saas-marketplace`** | `warble-saas` | **Running (`1/1`)** | Serving `https://app.warblecloud.com` (`35.190.63.216`). `/api/healthz` reports `"stripeLive": true` (12 SKUs + `STRIPE_WEBHOOK_SECRET` wired) and `"dex": true`. |
| **`warble-dex`** | `warble-saas` | **Running (`1/1`)** | Single-issuer OIDC (`https://dex.warblecloud.com`) wired to Google Workspace (`@warblecloud.com`) via `secret/dex-google` and `secret/dex-oidc`. |
| **`warble-idp-portal`** | `warble-idp` | **Manifests Applied** | Namespace, ServiceAccount, ClusterRole (`warble-idp-fleet-reader`), Deployment, Service, and Ingress (`idp.warblecloud.com`) applied on `warble-byok`. |
| **`starling-operator`** | `warble-system` | **Running (`1/1`)** | Reconciling workload resources in `warble-system`. |
| **`reflexion-engine` / `warble-agent`** | `warblecloud-ai` | **Running (`1/1`)** | Backed by `reflexion-postgres`, `reflexion-redis`, and `qdrant`. |

---

## 2. Step-by-Step Instructions for `@warble-tech` (Section 4 — Immediate Next Steps)

### Step 4.2b — Rotate Cloudflare API Token & Enable Turnstile + DNS (`warble-saas-marketplace#3` & `#11`)

> **Why this is needed:** The token previously stored in GCP Secret Manager (`cloudflare-api-token` in project `warble-tech`) was revoked during the token rotation in `warble-docs#18`.

1. **Create a scoped Cloudflare API Token** in the [Cloudflare Dashboard → My Profile → API Tokens](https://dash.cloudflare.com/profile/api-tokens):
   - **Account Permissions:**
     - `Account : Turnstile : Edit` (Account ID: `4143aef1e73fd3966507d465562a60d5`)
   - **Zone Permissions (Zone `warblecloud.com`, ID `7ea68c34ad85b1fad3650818d4148859`):**
     - `Zone : Bot Management : Edit`
     - `Zone : Zone Settings : Edit`
     - `Zone : DNS : Edit`
2. **Store the new token in GCP Secret Manager (`warble-tech`):**
   ```powershell
   $token = Read-Host -Prompt "Paste new Cloudflare API Token"
   $tmp = [System.IO.Path]::GetTempFileName()
   [System.IO.File]::WriteAllText($tmp, $token.Trim())
   gcloud secrets versions add cloudflare-api-token --project=warble-tech --data-file=$tmp
   Remove-Item $tmp -Force
   ```
3. **Apply Cloudflare Bot Fight Mode, AI Controls, and Turnstile Widget:**
   ```powershell
   cd C:\warble-101\warble-saas-marketplace
   node scripts/apply-cloudflare-security.js
   .\scripts\create-turnstile-secret.ps1
   ```
4. **Bind DNS `A` Records for `dex.warblecloud.com` and `idp.warblecloud.com`:**
   ```powershell
   node scripts/apply-warble-dex.js --apply
   ```
   Also ensure an `A` record exists in Cloudflare DNS for `idp.warblecloud.com` → `35.190.63.216` (DNS-only / grey cloud while ManagedCertificate provisions).
5. **Verify Live Turnstile & Security Status:**
   ```powershell
   curl.exe -s https://app.warblecloud.com/api/healthz
   curl.exe -s https://app.warblecloud.com/api/security
   ```
   Confirm `"turnstile": true`, `"stripeLive": true`, and `"dex": true`, then close [`warble-saas-marketplace#3`](https://github.com/warbletech/warble-saas-marketplace/issues/3) and [`warble-saas-marketplace#11`](https://github.com/warbletech/warble-saas-marketplace/issues/11).

---

### Step 4.2c — Attach Skydo USD ACH Payout Bank on Live Stripe (`warble-saas-marketplace#4`)

> **Why this is needed:** The restricted live Stripe key (`rk_live_...FlSX`) currently lacks `connected_account_read` / external account write permissions on account `acct_1TM8yFFDGTlawLTJ`.

#### Option A — Via Stripe Dashboard (Recommended, 2 Minutes)
1. Open [Stripe Dashboard → Settings → Business → Bank accounts and currencies](https://dashboard.stripe.com/settings/payouts).
2. Add a USD Bank Account using the values in `C:\warble-101\warble-saas-marketplace\.env-skydo`:
   - **Account Holder Name:** Must match the verified Stripe legal entity (`warblecloud, LLC` or `CHIRPSTACK LLP`)
   - **Routing Number (ACH):** `026073150` (Community Federal Savings Bank / Skydo)
   - **Account Number:** `****2429` (from `.env-skydo`)
   - **Currency / Country:** `USD` / `US`

#### Option B — Via CLI Script (`add-stripe-payout-bank.js`)
1. Open [Stripe API Keys](https://dashboard.stripe.com/apikeys) and edit restricted key `mk_1TNSE6FDGTlawLTJSo50YDPU` to enable **Account (`connected_account_read` & write)** permissions (or pass a standard `sk_live_...` key).
2. Run:
   ```powershell
   cd C:\warble-101\warble-saas-marketplace
   node scripts/add-stripe-payout-bank.js --apply
   ```
3. Once attached, close [`warble-saas-marketplace#4`](https://github.com/warbletech/warble-saas-marketplace/issues/4).

---

### Step 4.1 — Complete `idp.warblecloud.com` Production Rollout & Latest Marketplace Image (`warble-idp-portal#2`)

1. **Build & Push Latest `warble-saas-marketplace` Image (with 3-Month Financing & Self-Healing Simulator):**
   ```powershell
   cd C:\warble-101\warble-saas-marketplace
   $tag = (git rev-parse --short HEAD).Trim()
   gcloud builds submit --project=green-device-505513-k4 --substitutions=_TAG=$tag
   .\scripts\switch-image.ps1 -Tag $tag
   ```
2. **Build & Publish `warble-idp-portal` Image & Verify Pod Scheduling on `warble-byok`:**
   ```powershell
   cd C:\warble-101\warble-idp-portal
   kubectl get pods -n warble-idp
   kubectl describe pod -n warble-idp -l app=warble-idp-portal
   ```
   - If pods in `warble-idp` are `Pending` due to node CPU/pod capacity on `warble-byok`, scale replicas from `2` to `1` (`kubectl scale deploy/warble-idp-portal -n warble-idp --replicas=1`).
   - Verify `https://idp.warblecloud.com/api/healthz` returns `200 OK`, then close [`warble-idp-portal#2`](https://github.com/warbletech/warble-idp-portal/issues/2).

---

### Step 4.3 & 4.4 — GTM Launch (`Show HN` & LinkedIn Series) & Five-Domain Cutover (`warble-founders-gtm#2` & `#3`)

1. **Pre-Flight Check:**
   - Open [`warble-founders-gtm/promotions/FOUNDERS_OFFICE_LAUNCH_PLAYBOOK.md`](https://github.com/warbletech/warble-founders-gtm/blob/main/promotions/FOUNDERS_OFFICE_LAUNCH_PLAYBOOK.md).
   - Run the neutral voice & brand guardrail linter:
     ```powershell
     cd C:\warble-101\warble-marketing\apps\lead-gen
     npm run lint:voice
     ```
2. **Publish `Show HN` Launch Post:**
   - Submit to `https://news.ycombinator.com/submit` using the title and body in Section 1 of `FOUNDERS_OFFICE_LAUNCH_PLAYBOOK.md`:
     - **Title:** `Show HN: Starling EX – Apache-2.0 Kubernetes Operator and MCP Server for Agentic Ops`
3. **Schedule the 5-Part LinkedIn Founders Office Series:**
   - Schedule Posts 1–5 (Manifesto, Starling EX v0.5.0/v0.4.1, FRAKMA MLOps stack, Reflexion AI Shadow Mode, and Murmuration Advisory) across 10 business days.
4. **Verify Five-Domain Ecosystem Routing (`warble-founders-gtm#3`):**
   - Confirm live routing for `warbleoss.org`, `warblecloud.xyz`, `warblecloud.com` / `app.warblecloud.com`, `warblecloud.ai`, and `warblelabs.io`.

---

## 3. Step-by-Step Instructions for `@yaksha-warble` → Distribute to `@akshat-warble` (Sections 1, 2, and 3)

### Section 1 — Core Micro-Repositories

#### 1A. `warbletech/warble-idp-portal` ([Issue #1](https://github.com/warbletech/warble-idp-portal/issues/1))
```powershell
cd C:\warble-101\warble-idp-portal
npm test
npm start
```
- **Tasks for `@akshat-warble`:**
  1. Verify `/api/healthz`, `/api/catalog`, and `/api/deploy/*` in `src/server.js` generate valid manifests for `starling-ex` (`v0.5.0`), `starling-ex-community` (`v0.4.1`), `reflexion-ai`, and `frakma-oss`.
  2. Test `scripts/deploy-fleet.ps1 -Profile all -Domain warblecloud.com -DryRun` and `deploy/argocd/app-of-apps.yaml`.
  3. Confirm single-issuer Dex OIDC (`https://dex.warblecloud.com`) in `deploy/idp-portal/k8s-manifests.yaml` and UI styling in `public/index.html`.

#### 1B. `warbletech/warble-saas-marketplace` ([Issue #10](https://github.com/warbletech/warble-saas-marketplace/issues/10), [#6](https://github.com/warbletech/warble-saas-marketplace/issues/6), [#7](https://github.com/warbletech/warble-saas-marketplace/issues/7))
```powershell
cd C:\warble-101\warble-saas-marketplace
npm test
```
- **Tasks for `@akshat-warble`:**
  1. Verify Stripe Subscription checkout (`mode=subscription`: `warble-cloud-team`, `frakma-x-starter`, `frakma-x-growth`) and 3-month financing SKUs (`murmuration-growth-3mo`, `murmuration-scale-3mo`, `frakma-x-starter-ramp`, `frakma-x-growth-ramp`).
  2. Verify Murmuration fixed-price checkout (`/pay.html?sku=murmuration-niche|growth|scale`) and intake endpoints (`/api/murmuration/questionnaire`, `/api/murmuration/signup`).
  3. Verify MCP credit metering (`POST /api/mcp/consume-credits`, `$1 = 50 credits`), Customer Billing Portal (`POST /api/billing/portal`), Procurement packet (`/api/procurement/packet`), and the Self-Healing Regime simulator (`#7`).

#### 1C. `warbletech/warble-founders-gtm` ([Issue #1](https://github.com/warbletech/warble-founders-gtm/issues/1))
```powershell
cd C:\warble-101\warble-founders-gtm
.\pitches\export-marp-decks.ps1
```
- **Tasks for `@akshat-warble`:**
  1. Validate `calculator/index.html` GPU waste (27% Flexera baseline) and MTTR outage ($2M/hr New Relic baseline) calculations and CTA links to `app.warblecloud.com/pay.html`.
  2. Review `battlecards/COMPETITIVE_BATTLECARDS.md` (Datadog, incident.io/PagerDuty, Hyperscalers, AI Wrappers).
  3. Confirm Marp pitch deck exports (`pitches/exports/*.pptx`, `*.pdf`, `*.html`) and `.github/workflows/gtm-validate.yml`.

---

### Section 2 — Kubernetes Operators & Runtime Infrastructure

#### 2A. `warbletech/starling-ex` ([Issue #64](https://github.com/warbletech/starling-ex/issues/64) & Operator Issues [#59](https://github.com/warbletech/starling-ex/issues/59)–[#63](https://github.com/warbletech/starling-ex/issues/63))
```powershell
cd C:\warble-101\starling-ex
go test ./...
```
- **Tasks for `@akshat-warble`:**
  1. **Issue #59:** Honor `WATCH_NAMESPACE` and scope `corev1.Secret` cache informer in `cmd/main.go`.
  2. **Issue #60:** Wire `corev1.Secret` Watches in `StarlingAPIKeyReconciler` and `StarlingAlertChannelReconciler` for live Secret rotation.
  3. **Issue #61:** Implement coalesced status usage counter flusher (`lastUsedTime`, `deniedCount`, MCP credit metering) on `StarlingAPIKey`.
  4. **Issue #62:** Enforce Shadow-Mode kill switch and OPA policy pre-check on `/mcp` write tools.
  5. **Issue #63:** Implement Prometheus Alertmanager receiver (`/webhook/alertmanager`) matching `StarlingAlertRule` CRDs.
  6. Also resolve `ImagePullBackOff` on `starling-ex-operator` in namespace `warble-system` on `warble-byok` by verifying the GHCR image pull secret.

#### 2B. `warbletech/starling-ex-community` ([Issue #3](https://github.com/warbletech/starling-ex-community/issues/3))
```powershell
cd C:\warble-101\starling-ex-community
```
- **Tasks for `@akshat-warble`:**
  1. Validate the Apache-2.0 operator Helm chart and 1-click bash installer (`install.sh`).
  2. Verify the Next.js 15 read-only admin UI with single-issuer Dex OIDC (`dex.config.issuer == ui.dex.issuerUrl`).
  3. Test stateless JWT license verification (`starling-ex.frakma.io`).

---

### Section 3 — Strategy, Documentation & Growth Pipeline

#### 3A. `warbletech/warble-docs` ([Issue #20](https://github.com/warbletech/warble-docs/issues/20), [#9](https://github.com/warbletech/warble-docs/issues/9), [#10](https://github.com/warbletech/warble-docs/issues/10), [#12](https://github.com/warbletech/warble-docs/issues/12), [#18](https://github.com/warbletech/warble-docs/issues/18))
```powershell
cd C:\warble-101\warble-docs
npm install
npm run docs:build
```
- **Tasks for `@akshat-warble`:**
  1. Verify VitePress build for `docs.warblecloud.ai` and ADRs 0001–0006.
  2. Complete `#12` (plain-language docs home), `#9` & `#10` (link legal customer agreements on each product surface), and verify git history cleanup for `#18`.
  *(Note: `#19` is already completed and closed in commit `e050f8e`.)*

#### 3B. `warbletech/warble-marketing` ([Issue #67](https://github.com/warbletech/warble-marketing/issues/67) & Issues [#61](https://github.com/warbletech/warble-marketing/issues/61)–[#66](https://github.com/warbletech/warble-marketing/issues/66))
```powershell
cd C:\warble-101\warble-marketing\apps\lead-gen
npm test
npm run lint:voice
```
- **Tasks for `@akshat-warble`:**
  1. Validate the 4-agent lead-generation pipeline (`discover` → `enrich` → `qualify` → `draft`) and SQLite/HubSpot CRM sync.
  2. Verify Multi-Domain Theme Tokens (`themes-multi-domain.css`, `#61`) and the 5 domain surfaces (`warbleoss.org` `#62`, `warblecloud.xyz` `#63`, `warblecloud.ai` `#64`, `warblelabs.io` `#65`, and Voice Studio `#66`).

#### 3C. `warbletech/warble-bootstrap` ([Issue #1](https://github.com/warbletech/warble-bootstrap/issues/1))
```bash
cd /c/warble-101/warble-bootstrap
./scripts/clone-warbletech.sh --list
```
- **Tasks for `@akshat-warble`:**
  1. Verify `scripts/clone-warbletech.sh --list` includes all new `warbletech` repositories (`warble-idp-portal`, `warble-saas-marketplace`, `warble-founders-gtm`) under the appropriate layout group.
  2. Keep `docs/platforms.md` synchronized with live cluster ingress IPs and domain bindings.
