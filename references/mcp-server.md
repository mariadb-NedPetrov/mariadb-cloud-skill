# The MariaDB Cloud MCP Server (skysql-mcp)

*Source: https://github.com/skysqlinc/skysql-mcp (server source read directly).*

This is the MCP server for **managing MariaDB Cloud itself and talking to its SkyAI agents**.
It is different from the community `mariadb-mcp` server — see the distinction below; getting
this right is the main reason this reference exists.

## skysql-mcp vs the community mariadb-mcp — don't conflate them

| | **skysql-mcp** (this skill) | **mariadb-mcp** (community `MariaDB/mcp`) |
| --- | --- | --- |
| Level | Control plane — the MariaDB Cloud platform | Connection — a MariaDB you already have |
| Auth | `SKYSQL_API_KEY` (a cloud API key) | `DB_HOST`/`DB_USER`/`DB_PASSWORD`/`DB_NAME` |
| Provisions DBs? | **Yes** — launch/delete serverless instances | No |
| Talks to SkyAI agents? | **Yes** | No |
| Runs SQL? | Yes (`execute_sql`, full statements) | Yes (read-only by default via `MCP_READ_ONLY`) |
| Vector tools? | No (agents use a platform-side vector store) | Yes (create/insert/search vector stores) |

They're **complementary**, not competing. An agent can use skysql-mcp to *launch and manage*
a database and its SkyAI agents, and the community mariadb-mcp to do read-only schema
introspection / vector search against a connection. For the community server, defer to the
`mariadb-mcp` skill (`npx skills add mariadb/skills/mariadb-mcp`).

## Tools (exact, from source)

| Tool | What it does |
| --- | --- |
| `list_agents()` | List SkyAI agents (`GET /copilot/v1/agent/`); caches them. |
| `launch_serverless_db(name, region="eastus", provider="azure")` | Launch a serverless instance (`POST /provisioning/v1/services`, topology `serverless-standalone`). Lowercases `name`. |
| `delete_db(service_id)` | Delete a service. |
| `ask_agent(agent_id, question)` | Ask a SkyAI agent (`POST /copilot/v1/chat/`); returns analysis + generated SQL + errors. Adds `datasource_id` for DBA-type agents. |
| `get_db_credentials(service_id)` | Return host/port/user/password for a service. |
| `update_ip_allowlist(service_id)` | Add the caller's current public IP to the service allowlist. |
| `list_services()` | List services with status/provider/region/version/fqdn/port. |
| `execute_sql(service_id, sql_query)` | Open a direct TLS PyMySQL connection (using the service's credentials) and run the query. |

Prompts: `launch_db_prompt`, `delete_db_prompt` (always confirm deletion), `ask_agent_prompt`.

### Behaviors worth flagging (so advice ages well)

- **Defaults drift.** The published `launch_serverless_db` defaults to `provider="azure"`,
  `region="eastus"` and sends topology `serverless-standalone`. But the serverless region is
  really **dynamic / capacity-driven** and serverless covers fewer regions than provisioned
  (see `serverless.md`); the topology enum from the API is the source of truth. Treat the
  tool's literals as fallbacks, not guarantees — pass an explicit region when it matters.
- **`execute_sql` is not read-only.** Unlike the community server's `MCP_READ_ONLY` default,
  this runs whatever SQL you pass, over a direct connection using the service's default
  credentials (which it fetches per call). Fine for dev/demo; for anything sensitive, create
  a scoped user (you have `CREATE USER`) and be deliberate about what the agent can run.
- **It's a control-plane key.** `SKYSQL_API_KEY` can launch and delete services. Scope and
  store it like the cloud credential it is.

## Install & connect

Prereqs: Python 3.10+, a MariaDB Cloud API key (free tier works —
sign up at https://app.skysql.com).

```bash
git clone https://github.com/skysqlinc/skysql-mcp.git
cd skysql-mcp
chmod +x install.sh && ./install.sh
echo "SKYSQL_API_KEY=<your_key>" > .env
```

Cursor (`~/.cursor/mcp.json` — HTTP mode on `http://localhost:8000/mcp`):

```json
{ "mcpServers": { "skysql-mcp-server": {
    "url": "http://localhost:8000/mcp",
    "env": { "SKYSQL_API_KEY": "<your-skysql-api-key>" } } } }
```

Also installable via Smithery (`@skysqlinc/skysql-mcp`). Test the tools interactively with
`npx @wong2/mcp-cli uv run python src/mcp-server/server.py`.

## SkyAI agents (the AI layer)

SkyAI agents are AI agents hosted on the platform (Developer Copilot, DBA Copilot, and custom
agents) that turn natural language into SQL and answers, grounded in a platform-side vector
store for accuracy. They're reachable two ways:

- **Via this MCP server** — `list_agents` then `ask_agent`.
- **Via REST** — `POST /copilot/v1/chat` with `{prompt, agent_id, session_id?, config?}`;
  `config.table_filter` applies row-level WHERE scoping; the Session API
  (`/copilot/v1/session`) maintains multi-turn context.

Agents can also be pointed at **external** databases (on-prem, RDS, GCP Cloud SQL), so "add
AI to the database you already have" is a valid path that doesn't require migrating into
MariaDB Cloud — relevant when composing with `mysql-to-mariadb` / `oracle-to-mariadb`.

### Composition with mariadb-vector

The community `mariadb-vector` skill is the source of truth for `VECTOR` columns, indexes,
and RAG SQL. SkyAI agents reuse that same native vector capability inside the platform for
grounding — so the engine knowledge transfers directly; this server just exposes the agents
over MCP.

## Sources
- Server: https://github.com/skysqlinc/skysql-mcp
- SkyAI / Copilot API: https://apidocs.skysql.com/openapi.json (`/copilot/v1/*`), https://docs.skysql.com
- Community: `mariadb-mcp`, `mariadb-vector` (https://github.com/MariaDB/skills)
