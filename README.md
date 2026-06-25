# mariadb-cloud skill

An agent skill for **MariaDB Cloud (formerly SkySQL)** — the managed, serverless
MariaDB/MySQL DBaaS. It covers what's *different* in the managed cloud (privilege model,
API/Terraform-driven provisioning and scaling, serverless behavior, connection model, and
the MariaDB Cloud MCP server + SkyAI agents).

It is a **companion to**, not a replacement for, the community MariaDB skills at
https://github.com/MariaDB/skills. Those remain the source of truth for the engine itself
(SQL, vectors, query optimization, replication, migration); this skill builds the cloud
layer on top and points to them.

## Install

```bash
# via the skills installer
npx skills add mariadb-JagsR/mariadb-cloud-skill

# or directly
git clone https://github.com/mariadb-JagsR/mariadb-cloud-skill.git
cp -r mariadb-cloud-skill ~/.claude/skills/mariadb-cloud

# the community skills it builds on
npx skills add mariadb/skills
```

For Claude Code/Desktop the path is `~/.claude/skills/mariadb-cloud/`; for OpenAI Codex,
`~/.agents/skills/mariadb-cloud/`.

## Layout

```
SKILL.md                      # always-loaded briefing: the cloud delta + composition map
references/
  privileges.md               # grant set, SUPER/CONNECTION ADMIN boundary (verified live)
  provisioning-api.md         # create/scale/config/upgrade via API + Terraform; topologies
  serverless.md               # serverless architecture, scale-to-zero, dynamic regions
  connection.md               # TLS, fqdn, ports, allowlist, managed MaxScale
  mcp-server.md               # skysql-mcp tools + SkyAI agents; vs community mariadb-mcp
```

## Grounding

Content is grounded in the MariaDB Cloud OpenAPI spec
(https://apidocs.skysql.com/openapi.json), the MariaDB Cloud docs (https://docs.skysql.com),
the MCP server source (https://github.com/skysqlinc/skysql-mcp), and verification against a
live instance (privilege set and locked-variable behavior). Items that are tier/topology
dependent or could drift (config-object-settable variables, the Terraform registry path) are
flagged in-place rather than asserted.
