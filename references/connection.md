# Connecting to MariaDB Cloud

*Source: the API service object + MariaDB Cloud docs.*

Connecting to a managed instance differs from a local server in a few specific ways. The
engine/client protocol is identical — these are the cloud wrappers around it.

## Endpoint, port, TLS

- **Host (`fqdn`):** from the service object, shaped like `<id>.<group>.db1.skysql.com`
  (e.g. `dbxxxxxxxx.sysp0000.db1.skysql.com`). Don't guess it — read it from
  `GET /provisioning/v1/services/{id}`.
- **Port:** read from `endpoints[].ports` on the service object; don't hardcode 3306.
- **TLS:** connections are TLS by default (`ssl_enabled: true`). Keep it on. If a connection
  fails, the cause is almost always the **IP allowlist**, credentials, or the wrong endpoint
  — fix those rather than disabling TLS.

## IP allowlist (the usual "can't connect" cause)

A new service won't accept your client until your IP is allowlisted:

```bash
export SKYSQL_CLIENT_IP=$(curl -sS checkip.amazonaws.com)
curl -sS --request POST \
  --header "X-API-Key: $API_KEY" --header "Content-type: application/json" \
  --data "{ \"ip_address\": \"${SKYSQL_CLIENT_IP}/32\" }" \
  "https://api.skysql.com/provisioning/v1/services/${SERVICE_ID}/security/allowlist"
```

The allowlist takes IPv4 addresses and netblocks. `GET` it to review, `DELETE` to remove.

## Credentials — bootstrap, then rotate

`GET /provisioning/v1/services/{id}/security/credentials` returns a **default** user/password
meant to bootstrap access, not to be a permanent production credential. Because the tenant
user holds `CREATE USER` + `GRANT OPTION` (see `privileges.md`), create your own least-
privilege application users with a MariaDB client and stop using the default.

## The routing layer is managed MaxScale

For replicated/HA topologies, MariaDB Cloud puts a **managed MaxScale** (and, for serverless,
the always-on multi-tenant proxy) in front. You don't install, license, or configure it —
the platform does. What this means for application code:

- You connect to the service endpoint; read/write routing and failover happen behind it.
- The community `mariadb-replication-and-ha` skill describes MaxScale's behavior (read-write
  split, GTID-based failover) — on Cloud that behavior is provided for you; don't tell users
  to stand up their own MaxScale.
- Application-visible failover semantics from that skill still hold (e.g. don't assume a
  connection survives every failover without retry logic).

## Quick connect example

```bash
mariadb --host "$FQDN" --port "$PORT" --user "$USER" --password \
        --ssl   # TLS on; verify against the service's CA per docs
```

## Sources
- API: https://apidocs.skysql.com/openapi.json  (service object, `/security/allowlist`, `/security/credentials`)
- Docs: https://docs.skysql.com
- Community: `mariadb-replication-and-ha` (https://github.com/MariaDB/skills)
