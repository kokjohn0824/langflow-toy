TL;DR (cleanest path)
	•	Use uv to create an isolated Python env.
	•	Install Langflow as an app dependency.
	•	Start Langflow via its CLI.
	•	Treat flows as exported artifacts (JSON) checked into git.

No Docker, no LangChain boilerplate, minimal moving parts.

⸻

0. Preconditions
	•	Python 3.10–3.12 (Langflow tracks these cleanly)
	•	uv installed

curl -LsSf https://astral.sh/uv/install.sh | sh


⸻

1. Create a minimal uv project

mkdir langflow-toy
cd langflow-toy

uv init

This creates:

langflow-toy/
├── pyproject.toml
└── .python-version   (if pyenv present)

Why: uv init gives you a clean, PEP-517/518–compliant project without virtualenv noise.

⸻

2. Pin Python + add Langflow

Explicitly pin Python for reproducibility:

uv python pin 3.11

Install Langflow:

uv add langflow

This:
	•	Resolves + locks deps (uv.lock)
	•	Avoids pip entirely
	•	Gives you a deterministic environment

⸻

3. Run Langflow (dev mode)

uv run langflow run

Defaults:
	•	UI: http://127.0.0.1:7860
	•	API base: http://127.0.0.1:7860/api

At this point:
	•	You can create flows in the UI
	•	Everything runs inside the uv-managed environment

⸻

4. Minimal project layout (recommended)

After first run, structure it like this:

langflow-toy/
├── pyproject.toml
├── uv.lock
├── flows/
│   ├── hello-chat.json
│   └── rag-toy.json
├── scripts/
│   └── run.sh
└── README.md

scripts/run.sh

#!/usr/bin/env bash
set -e

export LANGFLOW_PORT=7860
export LANGFLOW_HOST=127.0.0.1

uv run langflow run

Rule: flows are artifacts → always export to flows/ and commit to git.

⸻

5. Create the simplest possible toy flow (UI)

In the Langflow UI:
	1.	New Flow
	2.	Nodes:
	•	Chat Input
	•	Prompt
	•	Chat Model (OpenAI / local model)
	•	Chat Output
	3.	Connect linearly
	4.	Save → Export JSON
	5.	Put it in flows/hello-chat.json

This is your L0 deterministic pipeline.

⸻

6. Run the flow via API (like n8n HTTP node)

After importing the flow back into Langflow UI, note the FLOW_ID.

curl -X POST \
  "http://127.0.0.1:7860/api/v1/run/$FLOW_ID?stream=false" \
  -H "Content-Type: application/json" \
  -H "x-api-key: dev" \
  -d '{
    "input_value": "hello from uv + langflow",
    "input_type": "chat",
    "output_type": "chat"
  }'

This is exactly how you later integrate with:
	•	n8n (HTTP Request node)
	•	custom Spring Boot / Go services
	•	agent orchestrators

⸻

7. Environment variables (models / keys)

Do not hardcode secrets in flows.

export OPENAI_API_KEY=sk-xxxx

Langflow auto-picks common env vars.

⸻

8. Pros / Cons / Risks

Pros
	•	Zero Docker overhead for exploration.
	•	uv lockfile = reproducible, fast installs.
	•	Langflow treated as an app, not a library soup.
	•	Flows are versionable artifacts, not UI-only state.

Cons
	•	Langflow runtime still mutable via UI if you’re careless.
	•	Not ideal for multi-user / prod without auth hardening.

Risks / Caveats
	•	Version drift: always commit uv.lock.
	•	Flow drift: enforce “export → git → import” discipline.
	•	Agent nodes can execute tools—lock down env + network early.

⸻

Opinionated next step (only if you go beyond toy)
	•	Freeze Langflow version:

uv add "langflow==<exact-version>"


	•	Add a Makefile:
	•	make dev
	•	make export-flows
	•	Put Langflow behind n8n, not the other way around.

If you want, next I can:
	•	Give you a Makefile + pre-commit setup for flow diffing
	•	Show how to run Langflow headless (API-only mode)
	•	Or map this toy directly into your log/RAG/agent use case
