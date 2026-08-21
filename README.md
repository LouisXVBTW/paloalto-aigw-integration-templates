# Palo Alto AI Gateway (AIGW) — integration templates

## What the AIGW is

The Palo Alto **AI Gateway (AIGW)** is a single endpoint that sits between your
app and the upstream LLM provider (AWS Bedrock, Anthropic, Google Vertex AI, ...).

```
your app  ─────►  AIGW endpoint  ─────►  provider (Bedrock / Anthropic / Vertex)
          request                routes to
```

Instead of pointing your code at a provider and holding that provider's
credentials, you point it at the AIGW and hold **one** AIGW key. The gateway
decides which upstream to call based on a **provider slug** you send with each
request. This gives a central place for auth, routing, and inspection of AI
traffic.

## What you need to configure

Two values get you started — ask your AIGW administrator for both:

| Value | What it is | How you send it |
|-------|-----------|-----------------|
| **Endpoint** | The AIGW base URL to reach out to | as the request URL — `https://aigw.portkey.ai` |
| **API key** | Authenticates you to the gateway | header `x-portkey-api-key: <YOUR_API_KEY>` |
| **Provider slug** | Which upstream provider to route to | header `x-portkey-provider: <YOUR_PROVIDER_SLUG>` |

> A **model ID** also goes in the request body (`"model": ...`). Its exact format
> depends on the provider your slug points to — get the right one from your admin.

Throughout the snippets below, replace the placeholders:

- `YOUR_API_KEY` — your AIGW / Portkey key
- `YOUR_PROVIDER_SLUG` — e.g. `@example-bedrock`
- `YOUR_MODEL_ID` — e.g. `us.anthropic.claude-opus-4-5-20251101-v1:0`

## Quick start

### curl

```bash
curl https://aigw.portkey.ai/v1/chat/completions \
  -H "content-type: application/json" \
  -H "x-portkey-api-key: YOUR_API_KEY" \
  -H "x-portkey-provider: YOUR_PROVIDER_SLUG" \
  -d '{
    "model": "YOUR_MODEL_ID",
    "messages": [{"role": "user", "content": "Hello from the AIGW."}]
  }'
```

### Python (`requests`)

```python
import requests

resp = requests.post(
    "https://aigw.portkey.ai/v1/chat/completions",
    headers={
        "content-type": "application/json",
        "x-portkey-api-key": "YOUR_API_KEY",
        "x-portkey-provider": "YOUR_PROVIDER_SLUG",
    },
    json={
        "model": "YOUR_MODEL_ID",
        "messages": [{"role": "user", "content": "Hello from the AIGW."}],
    },
)

resp.raise_for_status()
print(resp.json()["choices"][0]["message"]["content"])
```

## Custom metadata (log filtering & attribution)

Attach a JSON object with the **`x-portkey-metadata`** header and every request is
tagged with those fields in the gateway logs. You can then **filter and group logs
by any of those keys** — which team/app/environment made a call, per-user usage,
which requests were test traffic, and so on. This is the main way to make AIGW
traffic attributable and searchable after the fact.

- Send the header value as a **JSON string** (serialize the object).
- `_user` is a special key the gateway understands for per-user analytics; the
  rest are free-form keys you choose (e.g. `app`, `env`, `team`, `test`).
- Combine it with a distinct `x-portkey-api-key` per team to attribute cost and
  usage cleanly.

### Example

Just add the `x-portkey-metadata` header to any request:

```bash
curl https://aigw.portkey.ai/v1/chat/completions \
  -H "content-type: application/json" \
  -H "x-portkey-api-key: YOUR_API_KEY" \
  -H "x-portkey-provider: YOUR_PROVIDER_SLUG" \
  -H 'x-portkey-metadata: {"_user":"alice","app":"order-assistant","env":"pov"}' \
  -d '{
    "model": "YOUR_MODEL_ID",
    "messages": [{"role": "user", "content": "Hello from the AIGW."}]
  }'
```

Then open the gateway logs and filter by `_user`, `app`, or `env` to see requests
grouped by whichever dimension you tagged.

## Integrations

- **[Claude integration →](integrations/claude.md)** — Claude Desktop and Claude
  Code, step by step.
- **[n8n integration →](integrations/n8n.md)** — n8n's OpenAI node → AIGW →
  Bedrock, using a routing config attached to the API key.

_More clients will be added over time._
