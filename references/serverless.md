# MariaDB Cloud Serverless

*Source: https://docs.skysql.com/Serverless/Architecture/ and the API.*

Serverless is a MariaDB Cloud deployment mode that scales compute automatically (including
to zero when idle) while keeping the application connected. There is a **forever-free
developer serverless tier** (no credit card).

## How it works (and why it matters for advice)

The engine is unmodified MariaDB — "don't change what works." Serverless behavior comes from
cloud-native orchestration around it, not engine forks:

- **Multi-tenant always-on proxy** — maintains the application's connection even when the
  underlying database scales to zero. Apps don't see the scale event as a disconnect.
- **Pre-fabricated pools** — ready databases are kept warm per region, so launch is
  near-instant (checkout + resize rather than cold provision).
- **Autoscaling** — vertical and horizontal scaling driven by load; idle → scale to zero.

Practical consequence: don't design around "the server restarts on idle" or tell users to
disable idling to avoid disconnects — the proxy handles continuity. First query after idle
may incur a brief warm-up.

## Region rules (a common mistake)

- The serverless **default region is dynamic** — chosen by where MariaDB Cloud currently has
  capacity/quota. Do **not** state a fixed default (e.g. "eastus"); a tool's hardcoded
  default is only a fallback.
- Serverless supports **fewer regions than provisioned** services. Don't assume a region
  that exists for provisioned topologies is available for serverless.
- A user **can** specify a region explicitly at launch; otherwise expect the platform to
  choose. Query `GET /provisioning/v1/regions` and check serverless eligibility rather than
  assuming.

## Autoscale options

Serverless scaling bounds are set via `PUT /provisioning/v1/services/{id}/scale_options`
(rather than `SET GLOBAL` on the instance). Use it to configure the autoscale envelope; read
the service object to see current state.

## Composition with the community skills

- **Vectors** (`mariadb-vector`): serverless instances are ordinary MariaDB ≥ the
  provisioned `version`. For native `VECTOR` support ensure version ≥ 11.7 (you can't swap
  the binary — pick the version at create or do an API version upgrade). The SQL is identical
  to that skill; only provisioning differs.
- **Query optimization** (`mariadb-query-optimization`): session-level tuning works normally;
  server/startup knobs go through the config object (see `privileges.md`). On a scale-to-zero
  instance, warm-up effects can show up in first-query latency measurements — account for
  that before concluding a query is "slow."

## Sources
- Serverless architecture: https://docs.skysql.com/Serverless/Architecture/
- API: https://apidocs.skysql.com/openapi.json  (`/scale_options`, `/regions`)
