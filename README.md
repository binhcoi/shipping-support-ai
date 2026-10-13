# Shipping Support AI

A personal project for learning LLM integration in backend applications, using a
fictional shipping-support assistant as the example application.

The learning goals cover model APIs, prompts and context, tool calling,
embeddings, retrieval-augmented generation (RAG), controlled workflows, and
evaluation. Rails and PostgreSQL provide the application layer for exploring how
language models interact with persistent data and business logic.

## Project overview

The planned assistant will interpret shipping questions, retrieve authorized
shipment and tracking information through backend tools, and retrieve relevant
policy passages through RAG. It will generate responses grounded in that data
and propose support requests when appropriate. State-changing actions will
require explicit confirmation and execute through Rails business logic.

Shipment records and policy documents will be fictional. The design keeps
authorization, data integrity, and action execution in the backend while using
the model for interpretation, tool selection, and response generation.

## Milestones

| Milestone | Scope | Status |
| --- | --- | --- |
| 0. Rails foundation | API setup, PostgreSQL, persistence, and automated tests | In progress |
| 1. LLM integration | Ollama chat, conversations, prompts, context, timeouts, and inference metrics | Planned |
| 2. Tool calling | Structured arguments, authorized data lookup, tool execution, and result handling | Planned |
| 3. Embeddings and RAG | Policy documents, chunking, embeddings, pgvector retrieval, and source references | Planned |
| 4. Controlled workflows | Confirmation, deterministic actions, transactions, idempotency, and auditing | Planned |
| 5. Evaluation and hardening | Representative evaluations, prompt injection, malformed output, retries, rate limits, and model comparisons | Planned |

## Current status

The Rails foundation includes a JSON health endpoint, Shipment persistence with
model validations and database constraints, and automated tests. LLM integration
has not started.

Current stack: Ruby 3.3.7, Rails 7.2.4 (API-only), and PostgreSQL 17. Ollama,
pgvector retrieval, and Redis/Sidekiq are planned.

## Configuration and setup

Build the Rails container using `Dockerfile.dev` and connect it to PostgreSQL.
Provide connection settings through your deployment configuration, such as
Compose's `environment`, an `env_file`, or externally injected variables.

| Variable | Purpose |
| --- | --- |
| `PGHOST` | PostgreSQL hostname reachable from the Rails container |
| `PGPORT` | PostgreSQL port, normally `5432` |
| `PGUSER` | Database role |
| `PGPASSWORD` | Database role's password |
| `PGSSLMODE` | Optional TLS mode required by the database server |

For example, a Rails service with inline connection settings:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    environment:
      RAILS_ENV: development
      PGHOST: database-host
      PGPORT: "5432"
      PGUSER: application-role
      PGPASSWORD: your-database-password
    ports:
      - "3000:3000"
```

The connection values are placeholders; adapt them to your deployment.

- **PostgreSQL in the same Compose stack:** set `PGHOST` to the database service's
  network name. Configure its `POSTGRES_USER` and `POSTGRES_PASSWORD` to match
  Rails' `PGUSER` and `PGPASSWORD`, and wait for database readiness before
  starting Rails.
- **Existing PostgreSQL server:** set the connection variables to that server's
  details. The Rails service can still run through Compose; its startup does not
  need a bundled PostgreSQL service.

The current database configuration uses `shipping_support_ai_development` and
`shipping_support_ai_test`. The role needs permission to create and migrate
these databases, or they must be provisioned with the appropriate ownership
before startup.

The container entrypoint prepares the database and applies pending migrations.
Publish container port 3000 to access the application. LLM services are not
required at the current milestone.

## Running the application

Start your configured Compose stack:

```bash
docker compose up --build -d
```

With the port mapping above, the application is available at
`http://localhost:3000`. Check that it is running:

```bash
curl -i http://localhost:3000/health
```

The endpoint returns HTTP 200 with
`{"status":"ok","service":"shipping_support_ai"}`.
