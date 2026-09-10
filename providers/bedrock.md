# Amazon Bedrock — provider setup

> ✅ **Confirmed working** — AIGW → Amazon Bedrock, verified end-to-end with live
> model responses.

How to provision **Amazon Bedrock** as an upstream provider in the AIGW. Like the
[Vertex guide](vertex.md), this sets up what the gateway routes *to*, in two halves:

1. **AWS side** — create a credential Bedrock accepts (an **AWS access key**).
2. **AIGW side** — add the Bedrock integration and paste that credential in.

Once done, the provider gets a **slug**, and any client can target it exactly like
the other providers.

```
AIGW  ──(AWS access key)──►  Amazon Bedrock  (your AWS account)
```

Placeholders used below:

- `YOUR_AWS_ACCESS_KEY_ID` / `YOUR_AWS_SECRET_ACCESS_KEY` — an IAM access key pair
  from Part A
- `YOUR_AWS_REGION` — the Bedrock region, e.g. `us-east-1`
- `YOUR_API_KEY` / `YOUR_PROVIDER_SLUG` / `YOUR_MODEL_ID` — the gateway values from
  the [main README](../README.md#what-you-need-to-configure)

> 📸 The `images/bedrock-*.png` referenced below are placeholders — capture them from
> your own SCM/AIGW console when you run through this.

## How Bedrock differs

| | |
|---|---|
| **Auth** | AWS credentials — an IAM **access key** (ID + secret) is the simplest; an assumed role, service role, or Bedrock API key also work. See [Auth types](#auth-types). |
| **Model namespacing** | Bedrock uses model IDs / **inference-profile IDs**; cross-region profiles carry a region prefix (e.g. `us.`). See [Model naming](#model-naming). |
| **Region** | The region is part of the config and must offer the model you call. |
| **Model access** | Each model must be **granted in the account's Bedrock Model access** first, or calls `403` with `aws-marketplace:Subscribe`. |

## Prerequisites

- An **AWS account** with Bedrock available in your region.
- An **IAM identity with Bedrock permissions** and an **access key** for it — or the
  rights to create one (Part A).
- **`aws` CLI** configured (only for the CLI path — the console path needs no CLI).
- Access to **Strata Cloud Manager → AI Security → AI Gateway** to add the provider.

---

## Part A — AWS: create the access key

You need two things: an **IAM access key** with Bedrock permissions, and **model
access** for the models you'll call.

### Step 1 — An IAM identity with Bedrock permissions

Use an existing IAM user, or create one. It needs a policy allowing Bedrock invoke —
attach this (console: **IAM → Policies**, or inline on the user):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream"
    ],
    "Resource": "*"
  }]
}
```

### Step 2 — Create an access key

Console: **IAM → Users → _your user_ → Security credentials → Create access key**.
Copy the **Access Key ID** and **Secret Access Key** — the secret is shown **once**.

CLI (or run [`bedrock-provider-setup.example.sh`](bedrock-provider-setup.example.sh),
which does Steps 1–2):

```bash
aws iam create-access-key --user-name YOUR_IAM_USER
```

> ⚠️ The secret access key is shown once. Store it securely, never commit it. Rotate
> by creating a new key and deleting the old one.

### Step 3 — Enable model access

In the Amazon **Bedrock console → Model access**, enable each model you want and
accept its agreement. Without this, calls `403` with `aws-marketplace:Subscribe`.

> After enabling, the account can take a few minutes to settle — a call may briefly
> return *"Model use case details… try again in 15 minutes."* That's propagation,
> **not** a bad credential; wait and retry.

---

## Part B — AIGW: add the Bedrock provider

**Strata Cloud Manager → AI Security → AI Gateway → Integrations → Add integration
→ Amazon Bedrock.**

![Add the Amazon Bedrock integration](images/bedrock-integration-form.png)

### Step 1 — Basic details

| Field | Value |
|-------|-------|
| Name | Any label, e.g. `bedrock-prod` |
| Short Description | _(optional)_ |
| Slug | Autofills from the name → becomes `YOUR_PROVIDER_SLUG` (e.g. `@bedrock-prod`) |

### Step 2 — Auth type + connection

Set **AWS Auth Type = AWS Access Key** and fill in:

| Field | Value |
|-------|-------|
| AWS Auth Type | **AWS Access Key** |
| AWS Access Key Id | `YOUR_AWS_ACCESS_KEY_ID` |
| AWS Secret Access Key | `YOUR_AWS_SECRET_ACCESS_KEY` |
| AWS Region | `YOUR_AWS_REGION` (e.g. `us-east-1`) |

![AWS Auth Type = AWS Access Key](images/bedrock-auth-type.png)

> Three other auth types are offered — **AWS Assumed Role**, **AWS Service Role**,
> and **API Key**. See [Auth types](#auth-types).

### Step 3 — Save and note the slug

Save the integration. It appears in the list with its **slug** — that's
`YOUR_PROVIDER_SLUG`, which clients send as `x-portkey-provider`.

![Saved Bedrock provider with its slug](images/bedrock-provider-saved.png)

---

## Model naming

**Every provider names its models differently, and which IDs you can call depends on
what's enabled in your account.** Don't copy a model ID from this guide — **check
what you currently have enabled** and use that exact value as `YOUR_MODEL_ID`.

- **Where to check (Bedrock):** the Amazon **Bedrock console → Model access** lists
  the models granted to your account, with their IDs.
- **Bedrock's convention:** models are addressed by **model ID** or **inference-
  profile ID**. Cross-region inference profiles carry a **region prefix** (e.g.
  `us.` / `eu.`) — use the exact ID shown in the console.

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

Bedrock integrations accept four credential styles. This guide uses the first:

| Auth type | What it is | Use when |
|-----------|-----------|----------|
| **AWS Access Key** ⭐ | An IAM access key ID + secret | The default — easiest for most. Any IAM identity with Bedrock access. |
| **AWS Assumed Role** | The gateway assumes an IAM role you nominate (role ARN) | Keyless cross-account access with no long-lived secret. |
| **AWS Service Role** | A role attached to the gateway's own service identity | Gateway deployments that already run with an AWS role. |
| **API Key** | A Bedrock API key (an `ABSK…` bearer token) | You prefer Amazon's native Bedrock API keys. |

---

## Troubleshooting

- **`403 … aws-marketplace:Subscribe`** — the model isn't enabled in the account's
  **Bedrock Model access** (Part A, Step 3). Enable it and retry.
- **`403 AccessDenied … bedrock:InvokeModel`** — the access key's IAM identity is
  missing the invoke policy (Part A, Step 1).
- **`"Model use case details… try again in 15 minutes"`** — the account is still
  settling after a model-access change; wait ~15 min.
- **Model-not-found / wrong-region** — the model isn't offered in `YOUR_AWS_REGION`,
  or the ID is off. Cross-region inference profiles need the region prefix (e.g.
  `us.`); copy the exact ID from **Model access**.
- **Auth errors** — the access key is wrong, disabled, or rotated; create a new one
  and re-paste both the ID and secret.

---

## Next

Point a client at this provider using its slug:

- **[Claude integration →](../integrations/claude.md)**
- **[n8n integration →](../integrations/n8n.md)**
