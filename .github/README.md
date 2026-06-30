# Infrastructure CI/CD Setup

Reusable GitHub Actions pipelines for Cloudflare infrastructure (Workers, Pages, R2, DNS, WAF). Pipelines run from this repo; Terraform code is cloned at runtime from the central IaC repo using a GitHub App — no personal tokens required.

---

## Quick Start

### 1. Install the Valoriz GitHub App

The GitHub App handles all CI/CD authentication — cloning the IaC repo and writing secrets/variables to this repo.

1. Open the install link provided by the Valoriz DevOps team (e.g. `https://github.com/apps/streakjs-iac-bot`)
2. Click **Install** and select your account or organisation
3. Choose **Only select repositories** → select your repo
4. Click **Install** to confirm

   ![GitHub App install screen](./github-app-install.png)

   > After installation, go to **Settings → GitHub Apps** on your repo to confirm `streakjs-iac-bot` appears in the list.

### 2. Generate Cloudflare API Token and R2 Credentials

Run the `create-cf-token.sh` script to generate a Cloudflare API token and S3-compatible R2 credentials locally (for more detailed info about this, visit the [Cloudflare API token](#cloudflare-api-token) section):

```bash
CF_BOOTSTRAP_TOKEN=<bootstrap token> CF_ACCOUNT_ID=<account id> ./create-cf-token.sh
```

Once you run this, you will get the `CF_API_TOKEN` as well as the AWS Access Key ID and Secret Access Key for R2 locally.

You can use these credentials to manually upload your local `out` folder build to R2 using the AWS CLI:

```bash
export AWS_ACCESS_KEY_ID="<your-access-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-secret-access-key>"
aws s3 sync ./out s3://<your-bucket-name> --endpoint-url https://<account-id>.r2.cloudflarestorage.com
```

### 3. Add repository variable and secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Name | Type | Value | Source |
|---|---|---|---|
| `GH_APP_CLIENT_ID` | **Variable** | App Client ID (alphanumeric, e.g. `Iv23lixxxxxxxx`) | Provided by Valoriz DevOps |
| `GH_APP_PRIVATE_KEY` | **Secret** | Full `.pem` private key contents | Provided by Valoriz DevOps | 
| `CF_API_TOKEN` | **Secret** | Cloudflare API token | Run generate_cf-token-url.sh having selected permissions and generate token

### 4. Update the configuration JSON

Open `.github/iac-config.json` and fill in the values for your project. Top-level fields are shared defaults; fields under `environments.<env>` override them per environment.

See the [Config field reference](#config-field-reference) below for all available fields.

### 5. Run Onboard and Create workflows

1. **Onboard** — go to `Actions → IAC Onboard Repo → Run workflow`, select the target environment. Repeat for each environment (`dev`, `qa`, `prod`). Re-run onboard anytime the config changes.
2. **Create** — go to `Actions → IAC Cloudflare Create → Run workflow`, select the same environment.

### 6. Manual steps after first apply

These cannot be automated due to Cloudflare provider or API limitations:

| Step | Where | Why |
|---|---|---|
| Enable **Smart Placement** | Dashboard → Workers & Pages → your worker → Settings → General → Placement → set to **Smart** | Terraform provider v5 bug — `placement` object causes a multipart metadata error on upload |
| Verify **Bot Fight Mode** | Dashboard → Security → Bots | Confirm `fight_mode` is active — no visual confirmation in Terraform output |
| Wait for **Pages custom domain** | Dashboard → Workers & Pages → Pages project → Custom domains | Moves from *Verifying* → *Active* automatically once DNS propagates (1–5 min) |

---

## Cloudflare API token

> Use the **account-level** token page so the token is owned by the account, not an individual user.

### Automated (recommended)

`create-cf-token.sh` creates the token directly via the Cloudflare API — scoped explicitly to *Entire Account* and *All zones* — instead of relying on the dashboard's permission pre-fill, which can silently drop or mis-scope permissions depending on the account's plan/entitlements.

1. In the client's Cloudflare dashboard, create a one-time **bootstrap token** with permission **Account API Tokens: Edit**, resource *Entire Account*. This is only used to create the real token below; discard it afterward (or keep it if you'll repeat this for other tokens on the same account).
2. Find the **Account ID** (Cloudflare dashboard → right sidebar of any domain overview page, or `cloudflare.account_id` in `.github/iac-config.json` if already set).
3. Run:

   ```bash
   CF_BOOTSTRAP_TOKEN=<bootstrap token> CF_ACCOUNT_ID=<account id> ./create-cf-token.sh
   ```

4. The script prints the new token value once, plus the derived R2 S3-compatible credentials (Access Key ID + Secret Access Key) — the same values the dashboard shows after manually creating a token with R2 permissions. Store the token as the `CF_API_TOKEN` repository secret immediately — Cloudflare won't show it again.

If any permission group isn't available on the target account, the script fails loudly and lists what's missing along with everything that *is* available — it won't create a token with permissions silently missing.

### Manual fallback

1. You can either open the pre-filled token creation link below, or manually visit the Cloudflare UI to create a custom token:

   **[→ Create Cloudflare API token (all permissions pre-selected)](https://dash.cloudflare.com/?to=/:account/api-tokens&permissionGroupKeys=%5B%7B%22key%22%3A%22account_settings%22%2C%22type%22%3A%22read%22%7D%2C%7B%22key%22%3A%22workers_scripts%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22workers_r2_storage%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22pages%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22waf%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22zone_settings%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22firewall_services%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22dns%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22config_settings%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22zone%22%2C%22type%22%3A%22read%22%7D%2C%7B%22key%22%3A%22page_rules%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22bot_management%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22dynamic_url_redirects%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22cache_settings%22%2C%22type%22%3A%22edit%22%7D%2C%7B%22key%22%3A%22transform_rules%22%2C%22type%22%3A%22edit%22%7D%5D&name=Valoriz%20IaC)**

   If using the link, it opens the Cloudflare dashboard with all required permissions pre-selected and the token named `Valoriz IaC`.

2. Verify the permissions shown in the dashboard match this screenshot before saving (if creating manually, check that the below permissions are selected):

   ![Cloudflare Token Permissions](./cloudflare-token-permissions.png)

3. Click **Create Token** and store the value as the `CF_API_TOKEN` repository secret.

   Note: on accounts with limited plan entitlements, the dashboard may silently omit or mis-scope some permissions (see [create-cf-token.sh](./create-cf-token.sh) above for a flow that fails loudly instead).

<details>
<summary>Full permission list</summary>

**Policy 1 — Account** (resource: *Entire Account*)

| Category | Permission | Access |
|---|---|---|
| Account Settings | Account Settings | Read |
| Workers Scripts | Workers Scripts | Edit |
| Workers R2 Storage | Workers R2 Storage | Edit |
| Cloudflare Pages | Cloudflare Pages | Edit |

**Policy 2 — Zone** (resource: *All zones*)

| Category | Permission | Access |
|---|---|---|
| Zone WAF | Zone WAF | Edit |
| Zone Settings | Zone Settings | Edit |
| Firewall Services | Firewall Services | Edit |
| DNS | DNS | Edit |
| Config Settings | Config Settings | Edit |
| Zone | Zone | Read |
| Page Rules | Page Rules | Edit |
| Bot Management | Bot Management | Edit |
| Dynamic URL Redirects | Dynamic URL Redirects | Edit |
| Cache Settings | Cache Settings | Edit |
| Cache Purge | Cache Purge | Purge |
| Zone Transform Rules | Zone Transform Rules | Edit |

</details>

---

## Multi-environment setup (`cloudflare.manage_zone_resources`)

Each environment is fully independent — `cloudflare.account_id`, custom domains, and zone IDs can all differ per environment. The `cloudflare` block holds account/zone-wide settings (it's only needed for environments that have at least one `"platform": "cloudflare"` application); per-application fields like Worker/Pages names and custom domains live in each environment's `applications` array. The two common deployment patterns are:

---

**Pattern A — Each environment on its own Cloudflare account and domain (most common)**

Dev, QA, and Prod each have their own Cloudflare account and domain. All environments set `cloudflare.manage_zone_resources = true` (the default).

```json
{
  "environments": {
    "dev": {
      "cloudflare": { "account_id": "dev-account-id", "manage_zone_resources": "true" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-dev-client", "worker_custom_domains": [{ "hostname": "www.dev-client.com", "zone_id": "zone-dev" }] }
      ]
    },
    "qa": {
      "cloudflare": { "account_id": "qa-account-id", "manage_zone_resources": "false" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-qa-client", "worker_custom_domains": [{ "hostname": "qa.qa-client.com", "zone_id": "zone-qa" }] }
      ]
    },
    "prod": {
      "cloudflare": { "account_id": "prod-account-id", "manage_zone_resources": "true" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-prod-client", "worker_custom_domains": [{ "hostname": "www.prod-client.com", "zone_id": "zone-prod" }] }
      ]
    }
  }
}
```

Each pipeline applies full zone-level security independently. No coordination needed between environments.

---

**Pattern B — Multiple environments sharing the same Cloudflare account and zone**

Cloudflare enforces **one custom ruleset per phase per zone**. When `stg.abc.com` and `www.abc.com` are on the same zone, only one environment can manage zone-level rulesets. Set `cloudflare.manage_zone_resources = false` for non-prod environments — prod owns the zone.

```json
{
  "environments": {
    "dev": {
      "cloudflare": { "account_id": "shared-account-id", "manage_zone_resources": "false" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-dev", "worker_custom_domains": [{ "hostname": "dev.abc.com", "zone_id": "zone-abc" }] }
      ]
    },
    "qa": {
      "cloudflare": { "account_id": "shared-account-id", "manage_zone_resources": "false" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-qa", "worker_custom_domains": [{ "hostname": "stg.abc.com", "zone_id": "zone-abc" }] }
      ]
    },
    "prod": {
      "cloudflare": { "account_id": "shared-account-id", "manage_zone_resources": "true" },
      "applications": [
        { "type": "worker", "platform": "cloudflare", "name": "web-app",
          "worker_name": "web-prod", "worker_custom_domains": [{ "hostname": "www.abc.com", "zone_id": "zone-abc" }] }
      ]
    }
  }
}
```

> Zone security set by prod (WAF, rate limiting, HTTPS, bot protection) applies to the **entire zone** — `dev.abc.com` and `stg.abc.com` inherit it automatically.

---

When `cloudflare.manage_zone_resources = false`, these are skipped — everything else is still created:

| Skipped | Always created |
|---|---|
| All `cloudflare_zone_setting` resources | Worker script(s), R2 bucket(s) |
| WAF, rate limiting, HSTS rulesets | Worker custom domain record(s) |
| Bot Fight Mode, AI bot protection | Pages project(s) + Pages domain(s) |
| DMARC DNS record | Apex → www DNS record + redirect ruleset |
| Per-hostname config + cache rulesets | CNAME/A DNS records |

> Zone-level security/perf resources (WAF, rate limiting, DMARC, HSTS, bot management) are scoped to the **first** worker-type application's first custom domain only — if an environment has multiple Workers spanning different zones (e.g. a web app and an email-routing worker on different domains), only the first one's zone gets these protections.

## Config field reference

`.github/iac-config.json` drives the onboarding. Top-level fields are shared defaults; `environments.<env>` fields override them per environment — including nested objects like `cloudflare` and `extra_variables`, which deep-merge key by key rather than fully replacing the root-level value.

| Field | Scope | Required | Description |
|---|---|---|---|
| `project_name` | shared / per-env | Yes | Terraform state slug |
| `cloudflare.account_id` | shared / **per-env recommended** | Conditional | Cloudflare account ID — required only if the environment has at least one `"platform": "cloudflare"` application. Set per-environment when dev/qa/prod use different Cloudflare accounts |
| `cloudflare.worker_compatibility_date` | shared recommended | No | Workers compatibility date |
| `cloudflare.r2_bucket_location` | shared / per-env | No | R2 location hint, lowercase (e.g. `apac`, `enam`, `wnam`, `weur`, `eeur`, `oc`) — default: `apac` |
| `cloudflare.manage_zone_resources` | per-env | No | Set to `false` for `dev` and any env sharing a Cloudflare zone — prevents duplicate ruleset conflicts. Set to `true` for `qa` and `prod` |
| `cloudflare.security_contact` | shared / per-env | No | Contact for `/.well-known/security.txt` (e.g. `mailto:security@example.com`). Leave empty to disable |
| `cloudflare.dmarc_policy` | shared / per-env | No | DMARC policy: `reject`, `quarantine`, or `none`. Omit to skip DMARC record |
| `cloudflare.dmarc_rua` | shared / per-env | No | Email for DMARC aggregate reports. Leave empty to omit |
| `applications` | per-env | No | Array of applications to provision for this environment — see below |
| `extra_variables` | shared / per-env | No | Key-value object of additional GitHub Environment variables (e.g. `{"SANITY_DATA_SET": "development"}`). Version-controlled, set automatically during onboarding, fully removed during offboard. Secrets cannot be set here. Root-level value acts as a shared default that per-env values override key by key |
| `extra_secret_vars` | shared / per-env | No | Array of secret *names* (never values) that a non-Terraform pipeline needs — e.g. a Sanity Studio deploy workflow. Onboarding creates a placeholder secret per name; fill in the real value afterward. See [§ Extra pipeline secrets](#extra-pipeline-secrets-extra_secret_vars) |

### Application fields (each entry in `applications[]`)

| Field | Applies to | Required | Description |
|---|---|---|---|
| `type` | all | Yes | `worker` or `pages` |
| `platform` | all | Yes | Deploy target. Only `"cloudflare"` is currently provisioned — any other value fails onboarding with a clear error rather than being silently ignored |
| `name` | all | Yes | Unique label for this application within the environment (e.g. `web-streakjs`, `cms-sanity`) — used only for config readability, not sent to Cloudflare |
| `worker_name` | `type: worker` | Yes | The actual Worker script name in Cloudflare |
| `worker_script_path` | `type: worker` | Yes | Path to the Worker script, relative to repo root (e.g. `iac/cloudflare/scripts/web-streakjs-cf-worker.js`). No implicit default — every worker must declare it explicitly |
| `r2_bucket_name` | `type: worker` | No | R2 bucket name to create and bind to this Worker. Omit to skip R2 for this Worker |
| `worker_custom_domains` | `type: worker` | No | Array of `{hostname, zone_id}` |
| `pages_name` | `type: pages` | Yes | The actual Pages project name in Cloudflare |
| `pages_prod_branch` | `type: pages` | No | Pages production branch (default: `main`) |
| `pages_custom_domain` | `type: pages` | No | Object `{hostname, zone_id}` for the Pages custom domain |
| `secret_vars` | `type: worker` | No | Array of secret names to bind onto this Worker. Any name is allowed — values come from the `WORKER_SECRETS` GitHub Environment secret, never from this file |
| `env_vars` | `type: worker` | No | Object of arbitrary plain-text bindings specific to this Worker (e.g. `{"RESEND_FROM_ADDRESS": "no-reply@example.com"}`) |

### Worker secrets (`secret_vars`)

`iac-config.json` can never hold secret values — only secret *names*, via `secret_vars` on a worker application. The actual values live in **one** GitHub Environment secret, `WORKER_SECRETS`, holding a JSON object of `{"NAME": "value", ...}` pairs. A worker opts into a value by listing its key name in `secret_vars`; **any name is allowed**, with no fixed allowlist — add a brand new secret name without touching this repo at all.

Set or update it directly — no onboarding step required:

```bash
gh secret set WORKER_SECRETS --env <env> --body '{
  "GOOGLE_SCRIPT_URL": "https://script.google.com/macros/s/.../exec",
  "MY_CUSTOM_API_KEY": "..."
}'
```

Re-running this completely replaces the previous value, so include every key you still want to keep, not just the one you're adding or changing. Three names are used by the example email workers in this template, but they're not special — just keys like any other:

| Secret name | Used by | Purpose |
|---|---|---|
| `GOOGLE_SCRIPT_URL` | `email-googleapps-cf-worker.js` | Deployed Google Apps Script Web App exec URL |
| `RESEND_API_KEY` | `email-resend-cf-worker.js` | Resend API key |
| `EMAIL_API_KEY` | `email-googleapps-cf-worker.js`, `email-resend-cf-worker.js` | Shared key callers must present in the `X-API-Key` header — protects the email-sending endpoint from being called by anyone who finds the URL |

Before applying, `iac-cf-create.yml`/`iac-cf-destroy.yml` fail loudly if a worker's `secret_vars` references a key that's missing or empty in `WORKER_SECRETS` — this stops Terraform from silently overwriting a real value already deployed to Cloudflare with a blank one.

### Extra pipeline secrets (`extra_secret_vars`)

Some pipelines aren't Terraform at all — e.g. a separate workflow that builds and deploys a Sanity Studio CMS to Cloudflare Pages via `wrangler-action`. They still need credentials, but they're hand-written workflows, not generated from `iac-config.json`. `extra_secret_vars` is an array of secret *names* (never values), version-controlled here, the same shape as a worker's `secret_vars`:

```jsonc
"extra_secret_vars": ["SANITY_AUTH_TOKEN"]
```

Unlike `secret_vars` on a worker, onboarding **does** act on this list: it creates one environment-scoped GitHub secret per name, each with a placeholder value (`REPLACE_ME_<NAME>`), so they show up individually in **Settings → Environments → `<env>` → Environment secrets** right after onboarding. Go fill in the real value for each one before the pipeline that needs it runs — `gh secret set <NAME> --env <env> --body '<real-value>'`, or edit it directly in the GitHub UI. Re-running onboarding never overwrites a value you've already filled in — it only creates secrets that don't exist yet.

This works because `extra_secret_vars` is consumed by a project-specific pipeline you write yourself (e.g. `cd-cf-cms.yml`), which references each secret by a literal name you already chose — `${{ secrets.SANITY_AUTH_TOKEN }}` — unlike `WORKER_SECRETS`, where the *consuming* workflow (`iac-cf-create.yml`/`iac-cf-destroy.yml`) is shared and generic across every project, so it can't hardcode any project's specific secret names.

If the other pipeline can reuse an existing secret instead — e.g. `secrets.CF_API_TOKEN`, already set for Terraform — there's no need to list it in `extra_secret_vars` at all (it already exists); just reference `secrets.CF_API_TOKEN` directly in that pipeline's workflow YAML.

---

## Workflow operations reference

### Onboard (once per environment, re-run on config changes)

1. Commit `.github/iac-config.json` to the repo.
2. Go to **Actions → IAC Onboard Repo → Run workflow** → select environment.
3. The workflow clones the IaC repo, reads the config, creates the GitHub Environment, and sets all secrets and variables automatically.

### Apply (Create)

- **Actions → IAC Cloudflare Create → Run workflow** → select environment.

### Destroy

- **Actions → IAC Cloudflare Destroy → Run workflow** → select environment → type `destroy` to confirm.

### Offboard (remove environment config)

- **Actions → IAC Offboard Repo → Run workflow** → select environment.
- Deletes all variables and secrets from the GitHub Environment.
- Enable **delete_environment** to also remove the GitHub Environment itself.

---

## GitHub variables and secrets set by onboard

Most Cloudflare configuration (account ID, workers, Pages projects, R2/zone/DMARC settings) is **not** stored as a GitHub variable at all — `iac-cf-create.yml`/`iac-cf-destroy.yml` read `iac-config.json` directly on every run via `iac/cloudflare/scripts/read-iac-config.sh`. This means editing `iac-config.json` and re-running Create takes effect immediately; there's no separate copy of this config in GitHub that re-running onboard would need to refresh. Only real secrets, plus a few values shared org-wide or consumed by something other than this repo's own Terraform, are written to GitHub.

The table below follows `onboard-client.sh`'s actual execution order, step by step:

| # | Variable / Secret | Level | Source |
|---|---|---|---|
| 1 | `TF_STATE_RESOURCE_GROUP` | Repository variable | IaC defaults — set once, shared across all environments |
| 2 | `TF_STATE_STORAGE_ACCOUNT` | Repository variable | IaC defaults — set once, shared across all environments |
| 3 | `TF_STATE_CONTAINER` | Repository variable | IaC defaults — set once, shared across all environments |
| 4 | `TF_STATE_SAS_TOKEN` | Repository secret | IaC defaults — set once, shared across all environments |
| 5 | `CF_API_TOKEN` | Environment secret | Only written when `cf_api_token` is actually typed into the dispatch UI that run. If left blank, onboard falls back to the pre-stored `CF_API_TOKEN` repo secret *without* copying it down to the environment — `iac-cf-create.yml`/`iac-cf-destroy.yml` fall back to that same repo secret themselves at apply time (skipped entirely if no `platform: cloudflare` application) |
| 6 | Any keys in `extra_variables` | Environment variable | `extra_variables` from config (root + per-env deep-merged) — read by other workflows (e.g. the app's own build pipeline), not Terraform |
| 7 | Any names in `extra_secret_vars` | Environment secret | One placeholder secret (`REPLACE_ME_<NAME>`) created per name — skipped if a secret with that name already exists at repo or environment level. Fill in the real value afterward; see [§ Extra pipeline secrets](#extra-pipeline-secrets-extra_secret_vars) |

`WORKER_SECRETS` is **not** in this table because onboarding never touches it — developers set that one JSON-object secret directly (`gh secret set WORKER_SECRETS --env <env> --body '{...}'`) whenever a worker needs a new or rotated secret, with no onboarding re-run required. See [§ Worker secrets](#worker-secrets-secret_vars).

The Terraform state blob key (`streakjs-clients/<project_name>/<environment>.terraform.tfstate`) comes straight from `iac-config.json`'s `project_name` field at apply time — there's no `TF_STATE_PROJECT` GitHub variable.

`cloudflare.account_id`, the `applications[]` reshaped into `CF_WORKERS`/`CF_PAGES_PROJECTS`, and the rest of `cloudflare.*` (r2_bucket_location, worker_compatibility_date, manage_zone_resources, security_contact, dmarc_policy, dmarc_rua) are all resolved fresh from `iac-config.json` by `iac-cf-create.yml`/`iac-cf-destroy.yml` themselves — see [§ Config field reference](#config-field-reference) for the JSON shape.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Generate token` step fails with 404 | GitHub App is not installed on this repository — install it via the app install link |
| `Generate token` step fails with 401 | `GH_APP_CLIENT_ID` or `GH_APP_PRIVATE_KEY` is missing or incorrect |
| Onboard fails writing secrets (403) | App is installed but missing Secrets/Variables/Environments write permissions — reinstall with correct permissions |
| `Config file not found` in onboard | Commit `.github/iac-config.json` to the default branch before running |
| `Environment 'X' not found` | Add the environment block to `iac-config.json` |
| Secrets not available in create/destroy | Re-run onboard — secrets must be set under the environment, not just at repo level (Settings → Environments → `<env>`, not Settings → Secrets and variables → Actions) |
| `403` on Terraform backend | `TF_STATE_SAS_TOKEN` expired or has insufficient permissions (needs List + Read + Write + Delete) |
| Pages created unexpectedly | An `applications` entry with `type: pages` is set in config when it should not be — remove it for that environment |
| `Authentication error (10000)` on Cloudflare | `CF_API_TOKEN` missing a permission — verify against the [full permission list](#cloudflare-api-token) |
| Worker(s) reference secret_vars with no value set | A worker's `secret_vars` lists a key (e.g. `RESEND_API_KEY`) that's missing or empty in the `WORKER_SECRETS` GitHub Environment secret — `gh secret set WORKER_SECRETS --env <env> --body '{...}'` with that key included before re-running |
| Create/Destroy uses stale config | Not possible — `CF_WORKERS`, `CF_PAGES_PROJECTS`, `cloudflare.*`, and `project_name` are read straight from `iac-config.json` on every run, no re-onboard needed after editing the file |
| Onboard fails with "Unsupported platform" | An `applications` entry has `"platform"` set to something other than `"cloudflare"` — only `cloudflare` is currently provisioned |
