# Google Vertex AI — provider setup

> ✅ **Confirmed working** — AIGW → Google Vertex AI, verified end-to-end with live
> model responses.

How to provision **Google Vertex AI** as an upstream provider in the AIGW. Unlike
the [client integrations](../README.md#integrations) (which point an app *at* the
gateway), this guide sets up what the gateway routes *to*. It has two halves:

1. **GCP side** — create a credential Vertex will accept (a service account).
2. **AIGW side** — add the Vertex integration and paste that credential in.

Once done, the provider gets a **slug**, and any client can target it exactly like
the other providers.

```
AIGW  ──(service-account credential)──►  Vertex AI  (your GCP project)
```

Placeholders used below:

- `YOUR_GCP_PROJECT_ID` — the GCP project that hosts Vertex, e.g. `example-vertex-project`
- `YOUR_VERTEX_REGION` — the Vertex location, e.g. `global`
- `YOUR_API_KEY` / `YOUR_PROVIDER_SLUG` / `YOUR_MODEL_ID` — the gateway values from
  the [main README](../README.md#what-you-need-to-configure)

> 📸 The `images/vertex-*.png` referenced below are placeholders — capture them from
> your own SCM/AIGW console when you run through this.

## How Vertex differs from a bearer-token provider

| | |
|---|---|
| **Auth** | A GCP **service-account JSON key** (or Project+Region / Workload Identity), not a single bearer token. |
| **Model namespacing** | Each provider names models differently — Vertex addresses Claude under an `anthropic.` prefix and Gemini by plain name. See [Model naming](#model-naming). |
| **Region** | Location matters. Claude models are served on **`global`**. |
| **Partner models** | Claude (a partner model) must be **enabled per-model** in Vertex **Model Garden** before it can be called. Gemini needs no enablement. |

## Prerequisites

- A **GCP project** with billing, where Vertex AI is available.
- IAM rights on it to **enable services**, **create a service account + key**, and
  **set IAM policy** (Owner/Editor, or the granular equivalents).
- **`gcloud`** installed and authenticated (`gcloud auth login`).
- Access to **Strata Cloud Manager → AI Security → AI Gateway** to add the provider.

---

## Part A — GCP: create the Vertex credential

You can run these four steps as a script instead — see
[`vertex-provider-setup.example.sh`](vertex-provider-setup.example.sh)
(`PROJECT_ID=YOUR_GCP_PROJECT_ID ./vertex-provider-setup.example.sh`). The manual
steps:

### Step 1 — Enable the Vertex AI API

```bash
gcloud services enable aiplatform.googleapis.com --project=YOUR_GCP_PROJECT_ID
```

### Step 2 — Create a service account

```bash
gcloud iam service-accounts create aigw-vertex \
  --display-name="AIGW Vertex" \
  --project=YOUR_GCP_PROJECT_ID
```

This creates `aigw-vertex@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com`.

### Step 3 — Grant the Vertex user role

```bash
gcloud projects add-iam-policy-binding YOUR_GCP_PROJECT_ID \
  --member="serviceAccount:aigw-vertex@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"
```

`roles/aiplatform.user` is the least-privilege role for **calling** models. Use
`roles/aiplatform.admin` only if the gateway must also manage Vertex resources
(normally it shouldn't).

### Step 4 — Create the key file

```bash
gcloud iam service-accounts keys create vertex-sa.json \
  --iam-account=aigw-vertex@YOUR_GCP_PROJECT_ID.iam.gserviceaccount.com
chmod 600 vertex-sa.json
```

`vertex-sa.json` is what you upload to the AIGW in Part B.

> ⚠️ Treat it like a password — `chmod 600`, never commit it. IAM can take **~60s**
> to propagate; a first call may `403` briefly, then clear.

> ⚠️ If your org enforces `constraints/iam.managed.disableServiceAccountKeyCreation`,
> Step 4 fails. Use the **Project ID + Region** or **Workload Identity Federation**
> auth type instead — see [Auth types](#auth-types).

### Step 5 — (Claude only) enable the models in Model Garden

Claude models are off by default. In the Cloud console, open **Vertex AI → Model
Garden**, find each Anthropic model you want and **Enable** it for
`YOUR_GCP_PROJECT_ID`. A model you haven't enabled returns `404`. Gemini models need
no enablement.

---

## Part B — AIGW: add the Vertex provider

**Strata Cloud Manager → AI Security → AI Gateway → Integrations → Add integration
→ Vertex AI.**

![Add the Vertex AI integration](images/vertex-integration-form.png)

### Step 1 — Basic details

| Field | Value |
|-------|-------|
| Name | Any label, e.g. `vertex-prod` |
| Short Description | _(optional)_ |
| Slug | Autofills from the name → becomes `YOUR_PROVIDER_SLUG` (e.g. `@vertex-prod`) |

### Step 2 — Auth type + connection

Set **Vertex Auth Type = Service Account File** and fill in:

| Field | Value |
|-------|-------|
| Vertex Auth Type | **Service Account File** |
| Service Account JSON | Upload / paste `vertex-sa.json` from Part A |
| Vertex Project ID | `YOUR_GCP_PROJECT_ID` |
| Vertex Region | `YOUR_VERTEX_REGION` (e.g. `global`) |
| Map metadata to Vertex labels | _(optional)_ off unless you want request metadata mirrored to Vertex labels |

![Vertex Auth Type = Service Account File](images/vertex-auth-type.png)

> Two other auth types are offered — **Project ID and Region** (keyless; uses the
> gateway host's ambient credentials) and **Workload Identity Federation**
> (keyless federation). See [Auth types](#auth-types) for when to use each.

### Step 3 — Save and note the slug

Save the integration. It appears in the list with its **slug** — that's
`YOUR_PROVIDER_SLUG`, which clients send as `x-portkey-provider`.

![Saved Vertex provider with its slug](images/vertex-provider-saved.png)

---

## Model naming

**Every provider names its models differently, and which IDs you can call depends on
what's enabled in your account.** Don't copy a model ID from this guide — **check
what you currently have enabled** and use that exact value as `YOUR_MODEL_ID`.

- **Where to check (Vertex):** the Cloud console under **Vertex AI → Model Garden**
  shows what's available/enabled for your project. Claude partner models must be
  enabled first (Part A, Step 5).
- **Vertex's convention:** Claude is addressed under an `anthropic.` prefix
  (e.g. `anthropic.<claude-model>`); Gemini uses its plain name. Omitting the
  `anthropic.` prefix routes to Vertex's Google publisher and `404`s.

Send whichever ID you picked in the request body as `"model": "YOUR_MODEL_ID"`.

---

## Verify

Once the provider is saved, test it through the gateway using a model ID you've
enabled (see [Model naming](#model-naming)):

```bash
curl https://aigw.portkey.ai/v1/chat/completions \
  -H "content-type: application/json" \
  -H "x-portkey-api-key: YOUR_API_KEY" \
  -H "x-portkey-provider: YOUR_PROVIDER_SLUG" \
  -d '{
    "model": "YOUR_MODEL_ID",
    "messages": [{"role": "user", "content": "Hello from the AIGW."}],
    "max_tokens": 200
  }'
```

A working call returns a normal chat completion. If it errors, see
[Troubleshooting](#troubleshooting).

---

## Auth types

Vertex integrations accept three credential styles. This guide uses the first:

| Auth type | What it is | Use when |
|-----------|-----------|----------|
| **Service Account File** ⭐ | Upload a GCP SA JSON key | The default. Portable, works regardless of where the gateway runs. |
| **Project ID and Region** | No key; uses the gateway host's ambient GCP credentials (ADC) | The gateway runs on GCP (or a host with ADC) as an identity that already has `aiplatform.user`. |
| **Workload Identity Federation** | Keyless federation from an external identity | SA key creation is blocked by org policy, or you want no long-lived keys. |

---

## Troubleshooting

- **`404 … publishers/google/models/claude-… not found`** — missing the
  **`anthropic.`** prefix on a Claude model. Use `anthropic.<claude-model>`.
- **`404 … not found or your project does not have access`** — the model isn't
  enabled in **Model Garden** for the project (Part A, Step 5), or the name/region
  is wrong. Claude lives on `global`.
- **`400 … Organization Policy constraint constraints/vertexai.allowedModels`** —
  an org allowlist blocks that model; an org admin must add it.
- **`429 RESOURCE_EXHAUSTED`** — the model is enabled but has **no quota**; request
  a quota increase for the base model.
- **`403 … aiplatform.endpoints.predict denied` right after setup** — IAM hasn't
  propagated yet; wait ~60s and retry.
- **Can't create the key (Step 4)** — `disableServiceAccountKeyCreation` org
  policy; switch to **Project ID + Region** or **Workload Identity Federation**.

---

## Next

Point a client at this provider using its slug:

- **[Claude integration →](../integrations/claude.md)**
- **[n8n integration →](../integrations/n8n.md)**
