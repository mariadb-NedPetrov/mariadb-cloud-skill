# Provisioning, Scaling & Configuration via the API

*Source of truth: https://apidocs.skysql.com/openapi.json (host `api.skysql.com`).*

On MariaDB Cloud, every lifecycle action — create, scale, start/stop, storage, configure,
upgrade, secure — is an **API or Terraform** operation, not SQL on the box. This is the
counterpart to `privileges.md`: when a setting can't be changed with `SET GLOBAL`, it's
changed here.

## Authentication

Generate an API key at `https://cloud.mariadb.com/user-profile/api-keys`, then send it as a
header (verified against the live API and the MCP server source):

```bash
export API_KEY=...    # do not commit
curl -sS 'https://api.skysql.com/provisioning/v1/services' \
  --header "X-API-Key: $API_KEY"
```

Multi-org accounts: add `--header "X-MDB-Org: $ORG_ID"` to act in a non-default org.

## The offering catalog — values are enums, not free text

Don't invent version strings, topology names, sizes, or regions. Read them from the API:

| Endpoint | Returns |
| --- | --- |
| `GET /provisioning/v1/topologies?service_type=transactional` | valid topologies (e.g. `standalone`/`sa`, `es-single`, `es-replica`, `galera`, …) |
| `GET /provisioning/v1/providers` | `aws`, `gcp`, `azure` + volume/IOPS bounds |
| `GET /provisioning/v1/regions?provider=aws` | available regions (provisioned set) |
| `GET /provisioning/v1/sizes?topology=…&provider=…&architecture=…` | node sizes (e.g. `sky-2x8`) |
| `GET /provisioning/v1/versions?topology=…` | versions — **use the `name` field to create**, not `version`/`display_name` |
| `GET /provisioning/v1/tiers` | tiers (e.g. `foundation`, `power`, `powerplus`) and supported topologies |

## Create a service

```bash
curl -sS --request POST 'https://api.skysql.com/provisioning/v1/services' \
  --header "X-API-Key: $API_KEY" --header "Content-Type: application/json" \
  --data-raw '{
    "service_type": "transactional",
    "topology": "standalone",
    "provider": "aws",
    "region": "us-east-2",
    "name": "my-first-service",
    "architecture": "amd64",
    "nodes": 1,
    "size": "sky-2x8",
    "storage": 100,
    "ssl_enabled": true,
    "version": "<name from /versions>",
    "volume_type": "gp3"
  }'
```

Creation is **asynchronous** (`202 Accepted`). Poll `GET /provisioning/v1/services/{id}`
until `status` is `ready` (or `failed`). For private connectivity, add
`"endpoint_mechanism": "privateconnect"` and `"endpoint_allowed_accounts": ["<acct/project id>"]`.

## The live service object shape

`GET /provisioning/v1/services` returns objects shaped like (real fields):

```
id, name, region, provider, tier, topology, version, architecture, size, nodes,
ssl_enabled, nosql_enabled, fqdn, status, created_on (epoch), updated_on (epoch),
created_by, updated_by, endpoints:[ { name:"primary", ports:[ … ] } ]
```

`fqdn` looks like `<id>.<group>.db1.skysql.com`. Use `endpoints[].ports` for the port; don't
hardcode it. See `connection.md`.

## Lifecycle operations

| Action | Call |
| --- | --- |
| Start / stop | `POST /services/{id}/start`, `POST /services/{id}/stop`  (the older `/power` endpoint is deprecated) |
| Resize compute | `POST /services/{id}/size`  — this is how you add CPU/RAM (and buffer pool), NOT `SET GLOBAL` |
| Change node count | `POST /services/{id}/nodes` |
| Storage size / IOPS | `PATCH /services/{id}/storage`  (IOPS is AWS-only; older `/storage/size`, `/storage/iops` are deprecated) |
| Serverless autoscale | `PUT /services/{id}/scale_options`  — see `serverless.md` |
| Apply config | `POST /services/{id}/config`  / remove with `DELETE`  — the managed substitute for editing `my.cnf` |
| DB version upgrade | `POST /services/{id}/upgrade/database` |
| Default credentials | `GET /services/{id}/security/credentials`  (bootstrap creds — rotate them) |
| IP allowlist | `GET/POST/PUT/DELETE /services/{id}/security/allowlist` |
| SSL toggle | `PATCH /services/{id}/security/ssl`  (keep on) |
| Delete | `DELETE /services/{id}` |

Config changes are a **config object** applied to the service; the platform reconfigures and
restarts as needed. This is the mechanism behind "I can't `SET GLOBAL` that" — supported
tunables are exposed through this object (which ones is tier/topology dependent; check the
current API/docs rather than assuming).

## Composition: topologies map to the replication/HA skill

The community `mariadb-replication-and-ha` skill explains Galera, GTID, semi-sync, and the
**application constraints that don't change in the cloud**. On MariaDB Cloud you don't
configure any of that by hand — you choose a topology at create time and the platform manages
the cluster, the Galera wsrep provider, SST, and failover (the routing layer is managed
MaxScale — see `connection.md`). What still applies to *your* code on a Galera topology, per
that skill: every table needs a primary key, `AUTO_INCREMENT` values have gaps, and
`LOCK TABLES` / `GET_LOCK()` aren't supported — use transactions and explicit
`SELECT … FOR UPDATE`. Read that skill for the engine detail; provision the topology here.

## Terraform

MariaDB Cloud is also drivable via a Terraform provider for repeatable, version-controlled
provisioning — the IaC equivalent of the calls above. Confirm the exact provider name and
registry path from the current MariaDB Cloud docs before wiring it into a module (don't
assume a registry address).

## Sources
- API: https://apidocs.skysql.com/openapi.json
- Docs: https://docs.skysql.com
- Community: `mariadb-replication-and-ha` (https://github.com/MariaDB/skills)
