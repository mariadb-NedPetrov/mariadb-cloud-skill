# Privileges & Server Configuration on MariaDB Cloud

*Verified against a live MariaDB Cloud instance, including exact error text.*

This is the most important cloud-specific topic and the one where self-managed habits most
often produce wrong answers.

## The mental model

On MariaDB Cloud the default user is a full **database / schema / user administrator** but
**not a server administrator**. The platform withholds exactly the privileges that would let
a tenant change server-level configuration or reach the host — because those would break the
managed control plane and multi-tenant isolation.

- **You CAN (via SQL):** create/alter/drop schemas, tables, views, routines, triggers,
  events; DML; create users and roles and grant them (you hold `GRANT OPTION`); run
  `RELOAD`/`FLUSH`; monitor replication.
- **You CANNOT (via SQL):** set GLOBAL variables that require `SUPER` or `CONNECTION ADMIN`,
  resize the buffer pool, raise connection limits, read/write arbitrary files, restart, or
  edit configuration. Those go through the **API / Terraform / config object** — see
  `provisioning-api.md`.

## The actual grant set

`SHOW GRANTS` for the default user on a live instance (formatted for readability):

```
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, RELOAD, PROCESS, INDEX, ALTER,
      SHOW DATABASES, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, REPLICATION SLAVE,
      BINLOG MONITOR, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, CREATE USER,
      EVENT, TRIGGER, SET USER, FEDERATED ADMIN, SLAVE MONITOR
ON *.* TO `<user>`@`%` ... WITH GRANT OPTION
```

Present: `CREATE USER` + `GRANT OPTION` (build your own users/roles), `RELOAD`, `PROCESS`,
`BINLOG MONITOR` / `SLAVE MONITOR` / `REPLICATION SLAVE`, `FEDERATED ADMIN`, `SET USER`.

**Absent (intentionally): `SUPER` and `CONNECTION ADMIN`.** This is the root cause of most
"why was I denied" questions.

## What LLMs get wrong

| What you might say | What's correct |
| --- | --- |
| "Ask an admin to grant you `SUPER`." | No tenant is granted `SUPER` on MariaDB Cloud. The operation must be done a different way (resize / config object / API). |
| "`SET GLOBAL innodb_buffer_pool_size = …`" | `ERROR 1227 … you need … the SUPER privilege`. The buffer pool scales with instance size — **resize** via `POST /provisioning/v1/services/{id}/size`. |
| "`SET GLOBAL max_connections = …`" | `ERROR 1227 … you need … the CONNECTION ADMIN privilege`. Scale the instance or apply a config object via the API. |
| "Edit `my.cnf` / restart to change a setting." | No shell or file access. Apply a **config object** to the service; the platform reconfigures and restarts as needed. |
| "You can't read globals either, then." | You can freely *read* globals (`SELECT @@global.…`); you just can't *write* the protected ones. |
| "`LOAD DATA INFILE` from anywhere on the server." | `secure_file_priv = /tmp/` — server-side file I/O is sandboxed. Prefer client-side `LOAD DATA LOCAL INFILE` or a normal import path. |

## Verified specifics

```sql
-- Reads are fine:
SELECT @@global.read_only, @@global.log_bin, @@global.innodb_buffer_pool_size;
-- 0, 1, 67108864   (64 MiB on a small instance — scales with size)

-- Protected writes are denied (exact text):
SET GLOBAL innodb_buffer_pool_size = 1073741824;
-- ERROR 1227 (42000): Access denied; you need (at least one of) the SUPER privilege(s)

SET GLOBAL max_connections = 200;
-- ERROR 1227 (42000): Access denied; you need (at least one of) the CONNECTION ADMIN privilege(s)

-- Filesystem is fenced:
SHOW VARIABLES LIKE 'secure_file_priv';   -- /tmp/
```

## Composition: query optimization on Cloud

The community `mariadb-query-optimization` skill is the source of truth for EXPLAIN, indexes,
histograms, and optimizer flags — all of which work unchanged here. The single cloud delta:
that skill (correctly) says **Performance Schema is off by default and cannot be enabled at
runtime — set it in `my.cnf` and restart.** On MariaDB Cloud you can't edit `my.cnf` or
restart by hand, so enabling Performance Schema is an **API config-object change + a
platform-managed restart**, not a manual edit. Everything session-scoped still works without
`SUPER`:

```sql
-- These need no SUPER and work normally on Cloud:
SET SESSION optimizer_switch = 'derived_merge=off';
SET SESSION histogram_size = 100;            -- then ANALYZE TABLE …
SELECT /*+ JOIN_ORDER(o, c) */ …;            -- 12.x optimizer hints
```

## How to answer common questions

- **"Give the database more memory / a bigger buffer pool."** Resize to a larger `size` via
  the API. The buffer pool scales with the instance; you cannot set it directly.
- **"Raise max_connections."** Needs `CONNECTION ADMIN` (not granted). Scale the instance, or
  apply a supported config object via the API. Never advise `SET GLOBAL`.
- **"I need SUPER for X."** No tenant gets it. If X is a server setting → API/Terraform/config
  object. If X is a database operation → you likely already have the privilege (the grant set
  is broad, including `CREATE USER` and `GRANT OPTION`).
- **"Edit my.cnf / restart."** Not available. Configuration is an API-managed object.

> Open item: the precise set of server variables exposed as user-settable via the config
> object (vs fully locked) is tier/topology dependent — confirm against the current API/docs
> rather than assuming a specific variable is settable.

## Sources
- API: https://apidocs.skysql.com/openapi.json  (`/provisioning/v1/services/{id}/config`, `/size`)
- Community: `mariadb-query-optimization` (https://github.com/MariaDB/skills)
