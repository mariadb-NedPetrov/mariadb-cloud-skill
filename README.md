# MariaDB Cloud Skill

An [agent skill](#what-is-an-agent-skill) for **MariaDB Cloud (formerly SkySQL)** — MariaDB's
managed, serverless MariaDB/MySQL DBaaS on AWS, GCP, and Azure. It teaches an AI coding agent
what is *different* in the managed cloud so it stops giving self-managed advice that silently
fails on a managed instance.

The engine on MariaDB Cloud is ordinary MariaDB, so this skill is intentionally narrow: it is
the **cloud layer**. It covers the privilege model, API/Terraform-driven provisioning and
scaling, serverless behavior, the connection model, and the MariaDB Cloud MCP server + SkyAI
agents — and otherwise hands engine questions off to the
[community MariaDB skills](#relationship-to-the-community-mariadb-skills).

## What is an agent skill?

A **skill** is a packaged set of instructions — a `SKILL.md` plus optional `references/`,
`scripts/`, and `assets/` — that an AI coding agent (Claude Code, Claude Desktop, OpenAI Codex,
and other tools that follow the [Agent Skills](https://agentskills.io) format) loads to gain
focused, reliable expertise in a domain. Once installed, the agent pulls the skill in
automatically when your request matches it; you don't have to invoke it by hand. Think of it as
giving the model a small, authoritative manual it consults instead of guessing from training
data.

## What this skill covers

| Capability | What the agent learns |
| --- | --- |
| **Privilege model** | The exact grant set a tenant gets, why `SUPER` / `CONNECTION ADMIN` are denied, `secure_file_priv`, and how to correctly answer "permission denied" / "change this variable" — by resizing or applying a config object, not `SET GLOBAL`. |
| **Provisioning & scaling** | Create / scale / start-stop / storage / config-object / upgrade / IP-allowlist / credential flows via the **provisioning API and Terraform provider** — there is no SSH, no `my.cnf`, no manual restart. |
| **Serverless** | Serverless architecture, scale-to-zero, the always-on proxy, autoscale, and the dynamic-region / narrower-region-coverage rules that trip up self-managed assumptions. |
| **Connection model** | TLS-on-by-default, the `fqdn` shape, ports, IP allowlist, credential rotation, and how the managed MaxScale routing layer affects connections. |
| **MCP & SkyAI** | The MariaDB Cloud MCP server (`skysqlinc/skysql-mcp`) — its tools, install/auth, SkyAI agents, and how it differs from the connection-based community `mariadb-mcp` server. |

The core value is the table the agent internalizes from `SKILL.md`: a side-by-side of the
self-managed habit (e.g. `SET GLOBAL innodb_buffer_pool_size`, "edit `my.cnf` and restart",
"configure `wsrep_*`", "SSH in to scale") versus what is actually correct on MariaDB Cloud.

## Relationship to the community MariaDB skills

This skill is a **companion to**, not a replacement for, the community MariaDB skills at
[MariaDB/skills](https://github.com/MariaDB/skills) — but the two play different roles:

- For **pure engine behavior** — SQL dialect, vectors, query optimization, replication
  mechanics, system-versioned tables, migration — the community skills are the base, and this
  skill defers to them rather than restating them.
- For anything **managed-environment specific** — what is configurable, the privilege set, how
  you provision and scale, how HA is set up, the connection/TLS model — **this skill overrides
  them.** On MariaDB Cloud, a tenant is a database/user administrator, not a server
  administrator: configuration that a self-managed skill would do with `SET GLOBAL`, `my.cnf`,
  `SUPER`, or a manual restart is *blocked*, and must instead go through the API, Terraform, or
  a config object. Where the community guidance and the managed reality conflict, the managed
  reality (this skill) wins.

The pattern throughout is **engine truth (community skill) + cloud overlay (here)**, where the
overlay takes precedence on every dimension the platform manages. Install the engine skills it
builds on with:

```bash
npx skills add mariadb/skills          # all of them, or one at a time:
npx skills add mariadb/skills/mariadb-replication-and-ha
npx skills add mariadb/skills/mariadb-query-optimization
npx skills add mariadb/skills/mariadb-vector
npx skills add mariadb/skills/mariadb-mcp
```

## Installation

### Recommended: `scripts/install.sh` (one-shot, no manual copy)

The upstream `npx skills add` CLI currently installs only `SKILL.md` and drops the
`references/` folder that the skill relies on. The bundled installer takes care of both
`SKILL.md` and `references/`, and writes to the on-disk path each agent expects.

```bash
git clone https://github.com/mariadb-JagsR/mariadb-cloud-skill.git
cd mariadb-cloud-skill

# install for every supported agent (Claude + Cursor/Codex/Windsurf/Devin/...)
scripts/install.sh

# or target a subset:
scripts/install.sh claude       # ~/.claude/skills/mariadb-cloud
scripts/install.sh agents       # ~/.agents/skills/mariadb-cloud
```

Restart Claude Desktop after installing for `claude` — the skill appears under
**Customize → Skills**. Claude Code, Cursor, Codex, Windsurf, and Devin pick the skill up
on the next session without a restart.

### Which path does each tool read?

| Tool                            | Skill root                     | Notes                                    |
| ------------------------------- | ------------------------------ | ---------------------------------------- |
| Claude Desktop / Claude Code    | `~/.claude/skills/`            | Global; restart Claude Desktop.          |
| Cursor, Codex, Windsurf, Devin, Cline, Gemini CLI, Warp, Amp | `~/.agents/skills/` (home) or `<project>/.agents/skills/` (project) | Project path wins when set. |

`scripts/install.sh` writes to `~/.claude/skills/` and `~/.agents/skills/` respectively; use
`CLAUDE_SKILLS_DIR` / `AGENTS_SKILLS_DIR` env vars to override, or point them at a project
`.agents/skills/` directory to install locally.

### Alternative: `npx skills add` (CLI, interactive)

```bash
npx skills add mariadb-JagsR/mariadb-cloud-skill
```

Then copy the `references/` folder manually — the CLI installs only `SKILL.md`:

```bash
git clone https://github.com/mariadb-JagsR/mariadb-cloud-skill.git /tmp/mariadb-cloud-skill
cp -r /tmp/mariadb-cloud-skill/references ~/.agents/skills/mariadb-cloud/
# for Claude:
mkdir -p ~/.claude/skills
cp -r /tmp/mariadb-cloud-skill ~/.claude/skills/mariadb-cloud
```

### Non-interactive install (for scripting)

The `skills` CLI opens an interactive picker by default. To install headlessly for a
specific set of agents, pass `--skill`, `--agent`, and `-y`:

```bash
# this skill, for Claude Code + Devin only, no prompts:
npx -y skills add mariadb-JagsR/mariadb-cloud-skill \
  --skill '*' --agent claude-code --agent devin -y

# all community engine skills, for Claude Code + Devin only:
npx -y skills add mariadb/skills \
  --skill '*' --agent claude-code --agent devin -y

# every skill for every detected agent (shorthand):
npx -y skills add mariadb-JagsR/mariadb-cloud-skill --all
```

For the best results, pair it with the community engine skills:
`npx skills add mariadb/skills` (or the non-interactive variant above).

## Usage

Once installed, the agent loads the skill automatically whenever your request involves MariaDB
Cloud / SkySQL or would otherwise produce self-managed advice that fails on a managed instance.
No explicit invocation needed. For example:

- *"My `SET GLOBAL innodb_buffer_pool_size` is denied on my SkySQL instance — how do I give it
  more memory?"* → the agent explains you resize the instance via the API, and the buffer pool
  scales with it.
- *"Provision a Galera-backed MariaDB on GCP and scale it to 8 cores."* → the agent uses the
  provisioning API / Terraform with the correct topology and size enums.
- *"Set up an AI agent that can spin up a free serverless MariaDB and run SQL against it."* →
  the agent reaches for the `skysql-mcp` server and SkyAI agents.

## Skill structure

```
SKILL.md                      # always-loaded briefing: the cloud delta + composition map
references/
  privileges.md               # grant set, SUPER/CONNECTION ADMIN boundary (verified live)
  provisioning-api.md         # create/scale/config/upgrade via API + Terraform; topologies
  serverless.md               # serverless architecture, scale-to-zero, dynamic regions
  connection.md               # TLS, fqdn, ports, allowlist, managed MaxScale
  mcp-server.md               # skysql-mcp tools + SkyAI agents; vs community mariadb-mcp
scripts/
  install.sh                  # copy SKILL.md + references/ into ~/.claude and/or ~/.agents
```

`SKILL.md` is always loaded; the agent reads only the `references/` file that matches the task.
The layout follows the [Agent Skills](https://agentskills.io) specification.

## Grounding

Content is grounded in the MariaDB Cloud OpenAPI spec
([apidocs.skysql.com](https://apidocs.skysql.com/openapi.json)), the MariaDB Cloud docs
([docs.skysql.com](https://docs.skysql.com)), the MCP server source
([skysqlinc/skysql-mcp](https://github.com/skysqlinc/skysql-mcp)), and verification against a
live instance (privilege set and locked-variable behavior). Items that are tier/topology
dependent or could drift (config-object-settable variables, the Terraform registry path) are
flagged in-place rather than asserted.

## License

[MIT](LICENSE)
