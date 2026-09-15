Portkey AI Gateway is a lightweight, open-source proxy that routes requests to 250+ LLMs through a single OpenAI-compatible API.

## Features

- Unified API for 250+ providers (OpenAI, Anthropic, Gemini, and more)
- Smart routing with automatic failover and load balancing
- Response caching to cut costs and latency
- Rate limiting, retries, and request timeouts
- Full observability with logs, analytics, and cost tracking
- Drop-in replacement for the OpenAI SDK — just change the base URL

## Setup

1. Open the dashboard at `http://<host>:8787/public/` (the root `/` only shows a banner).
2. Add your provider API keys (OpenAI, Anthropic, Gemini, etc.) in the dashboard.
3. Point any OpenAI-compatible client at `http://<host>:8787/v1`.

### Example (curl)

```bash
curl http://<host>:8787/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Example (Python)

```python
from openai import OpenAI
client = OpenAI(base_url="http://<host>:8787/v1", api_key="your-provider-key")
```

If the app is exposed via a subdomain, you can also reach it at `https://<subdomain>/v1`.