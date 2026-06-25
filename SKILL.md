---
name: mariadb-cloud
description: >
  Guidance for MariaDB Cloud (formerly SkySQL) — MariaDB's managed, serverless
  MariaDB/MySQL DBaaS on AWS, GCP, and Azure. Use this skill whenever the user mentions
  MariaDB Cloud, SkySQL, a managed or cloud-hosted MariaDB, the MariaDB Cloud / SkySQL API
  (api.skysql.com), serverless MariaDB, the MariaDB Cloud MCP server (skysql-mcp), or SkyAI
  agents. ALSO use it — even when the user never says "cloud" — whenever an answer would
  otherwise tell a managed-MariaDB user to SET GLOBAL a server variable, edit my.cnf, use
  SUPER, restart the server, or enable Performance Schema at startup, because on MariaDB
  Cloud those operations are blocked and must go through the API, Terraform, or a config
  object instead. This skill covers ONLY what is different in the managed cloud; the engine
  is ordinary MariaDB, so engine-level questions (SQL, vectors, query tuning, replication,
  migration) build on the standard MariaDB community skills, which this skill depends on
  and points to rather than duplicating.
---

# MariaDB Cloud (SkySQL)

*Last updated: 2026-06-25*

MariaDB Cloud is MariaDB's managed, serverless DBaaS, available on AWS, GCP, and Azure.
**SkySQL is its former name** — the two are the same product, and the API host is still
`api.skysql.com`. Treat "SkySQL" and "MariaDB Cloud" as synonyms.

> **Default context:** The engine is unmodified MariaDB (InnoDB preserved, full
> MySQL/MariaDB compatibility). Assume a recent **11.8 LTS** server unless the service's
> `version` says otherwise — query `/provisioning/v1/versions` for what a given service
> actually runs. Everything true of self-managed MariaDB at that version is true here,
> **except** the managed-cloud differences this skill documents.

## This skill depends on the community MariaDB skills

This skill is deliberately narrow: it is the **cloud layer**. For the engine itself —
SQL dialect, vectors, query optimization, replication mechanics, system-versioned tables,
migration — defer to the community MariaDB skills, which are the source of truth for engine
behavior and are kept current independently:

```
npx skills add mariadb/skills          # all of them, or one at a time:
npx skills add mariadb/skills/mariadb-replication-and-ha
npx skills add mariadb/skills/mariadb-query-optimization
npx skills add mariadb/skills/mariadb-vector
npx skills add mariadb/skills/mariadb-features
npx skills add mariadb/skills/mariadb-mcp
# also: mysql-to-mariadb, oracle-to-mariadb, mariadb-system-versioned-tables
```

The pattern throughout this skill is **engine truth (community skill) + cloud overlay
(here)**. Where they meet, this skill says what *changes* in the managed environment and
otherwise hands off. It does not restate engine behavior.

## The one principle that drives everything

On MariaDB Cloud you are a fully-empowered **database and user administrator**, but not a
**server administrator**. You can create schemas, users, roles, routines, triggers, and
events freely with SQL. You cannot change server-level configuration, the buffer pool,
connection limits, replication topology, or the host OS — those are managed by the platform
and changed through the **provisioning API, the Terraform provider, or a config object**,
never through SQL on the instance.

Internalize this one line and almost every cloud-specific mistake disappears.

## What LLMs get wrong on MariaDB Cloud

| What you might say (self-managed habit) | What's correct on MariaDB Cloud |
| --- | --- |
| `SET GLOBAL innodb_buffer_pool_size = …` to add memory | Denied — needs `SUPER`, which no tenant has. **Resize the instance** (larger `size`) via the API; the buffer pool scales with size. See `references/privileges.md`. |
| `SET GLOBAL max_connections = …` | Denied — needs `CONNECTION ADMIN`. Scale the instance or apply a **config object** via the API. |
| "Edit `my.cnf` and restart the server" | No shell, no file access, no manual restart. Configuration is an **API-managed config object** applied to the service. |
| "Enable Performance Schema at startup (it can't be turned on at runtime)" | True on the engine — but on Cloud you can't edit startup config by hand. It's an **API config-object change + platform-managed restart**. Session-level tuning (`optimizer_switch`, optimizer hints, `histogram_size`) still works without SUPER. |
| "Install the Galera library / configure `wsrep_*` / set `gtid_domain_id`" | You don't hand-configure HA. **Pick a topology at provision time** (`galera`, `es-replica`, `standalone`, …); the platform manages the cluster, wsrep provider, SST, and failover. App-level Galera constraints still apply (see below). |
| "Provision/scale by SSHing into the box" | There is no SSH. Provision, scale, start/stop, storage, upgrades, and config are all **API / Terraform** driven. See `references/provisioning-api.md`. |
| "Pass any version string / topology name" | Versions, topologies, sizes, and regions are **enums from the API**. Use the `name` from `/provisioning/v1/versions`, not a display string. |
| "Serverless launches in `eastus` by default" | The serverless default region is **dynamic** (chosen by current capacity/quota), and serverless covers **fewer regions** than provisioned. Specify a region or query `/regions`. See `references/serverless.md`. |
| "Just disable SSL if the connection fails" | TLS is expected and on by default. Fix the cause (IP allowlist, credentials, endpoint) — don't disable TLS. See `references/connection.md`. |
| Treating the API-issued default credentials as permanent | They're **bootstrap** credentials meant to be rotated — create your own users (you have `CREATE USER` + `GRANT OPTION`). |

## When to read which reference

Read the reference that matches the task; don't load them all by default.

- **`references/privileges.md`** — the exact grant set, what's denied and why (`SUPER` /
  `CONNECTION ADMIN`), `secure_file_priv`, and how to answer "permission denied" / "change
  this variable" questions. Read for any privilege, `SET GLOBAL`, or server-admin question.
- **`references/provisioning-api.md`** — create / scale / start-stop / storage / config
  object / upgrade / allowlist / credentials; the live service object shape; Terraform.
  Read for any "how do I launch / resize / configure / automate" question.
- **`references/serverless.md`** — serverless architecture, scale-to-zero, the always-on
  proxy, autoscale options, and the dynamic-region / narrower-region-coverage rules.
- **`references/connection.md`** — TLS, the `fqdn` shape, ports, IP allowlist, credential
  rotation, and how the managed MaxScale routing layer affects connections.
- **`references/mcp-server.md`** — the MariaDB Cloud MCP server (`skysqlinc/skysql-mcp`):
  its tools, install/auth, SkyAI agents, and how it differs from the community
  `mariadb-mcp` server. Read whenever an AI agent should launch a free serverless DB, run
  SQL, or talk to SkyAI agents.

## How this composes with the community skills (quick map)

- **Replication/HA** (`mariadb-replication-and-ha`): Galera/GTID/semi-sync mechanics are
  the engine truth there; on Cloud you select a topology at provision time and the platform
  runs it. App constraints (every Galera table needs a PK, AUTO_INCREMENT gaps, no
  `LOCK TABLES`) still apply — surface them. See `references/provisioning-api.md` (topologies).
- **Query optimization** (`mariadb-query-optimization`): EXPLAIN/histograms/hints unchanged;
  the one cloud delta is that startup-only knobs (Performance Schema) go through the config
  object, not `my.cnf`. See `references/privileges.md`.
- **Vectors** (`mariadb-vector`): identical SQL; just ensure a `version` ≥ 11.7 is
  provisioned (you can't swap the binary yourself). SkyAI agents reuse a vector store inside
  the platform — see `references/mcp-server.md`.
- **MCP** (`mariadb-mcp`): that skill documents the *connection-based* `MariaDB/mcp` server
  for a DB you already have; this skill's `references/mcp-server.md` documents the
  *control-plane* `skysql-mcp` that provisions and manages the cloud. They're complementary.
- **Migration** (`mysql-to-mariadb`, `oracle-to-mariadb`): use those for the conversion; the
  target gets provisioned via the API, and SkyAI agents can also sit on existing external
  databases (RDS, Cloud SQL) without migration.

## Sources

- MariaDB Cloud / SkySQL API (OpenAPI): https://apidocs.skysql.com/openapi.json
- MariaDB Cloud docs: https://docs.skysql.com
- MariaDB Cloud MCP server: https://github.com/skysqlinc/skysql-mcp
- Community MariaDB skills: https://github.com/MariaDB/skills
