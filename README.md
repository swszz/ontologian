# Ontologian

**A Claude Code plugin for structured knowledge management based on Palantir Ontology concepts.**

Ontologian brings Object Types, Link Types, and Action Types into your Claude Code workflow — letting you define, navigate, and validate your domain knowledge as structured files directly inside your project.

---

## Installation

### Step 1 — Register the marketplace

```bash
curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash
```

Adds Ontologian's GitHub repo as a known marketplace source in `~/.claude/settings.json`.

**Requires:** `jq` or `python3`.

### Step 2 — Install commands & agent

Run inside Claude Code:

```
/plugin install ontologian@ontologian
```

Installs 8 slash commands and the `ontology-consultant` proactive agent.

### Update

```
/plugin update ontologian@ontologian
```

---

## Commands

| Command | Description |
|---|---|
| `/ontologian` | Show domain list, type counts, and command guide |
| `/ontologian-add` | Interactively add a single type to a domain |
| `/ontologian-analyze` | Paste requirements text → auto-derive Object, Link, Action types |
| `/ontologian-consult` | Full guided session with 5-axis discovery interview |
| `/ontologian-search <keyword>` | Search across all domains (`--type object\|link\|action`, `--domain <name>`) |
| `/ontologian-validate` | Check schema correctness and referential integrity |
| `/ontologian-sync` | Sync local `ontology/` to the global store |
| `/ontologian-visualize` | Render an ASCII relationship diagram |

### Where to start?

| Situation | Command |
|---|---|
| Have requirements text ready | `/ontologian-analyze` — fastest path |
| Adding one type to an existing domain | `/ontologian-add` |
| New domain, starting from scratch | `/ontologian-consult` — most thorough |

---

## Consulting Agent

The plugin includes an `ontology-consultant` agent that activates in two ways:

- **Proactively** — when you describe business requirements or domain entities, the agent offers to model them as an ontology
- **Explicitly** — run `/ontologian-consult` to start a full consulting session

The consulting session covers 6 phases:

| Phase | What happens |
|---|---|
| **Scope** | Confirm the domain scope; load existing ontology state |
| **Discovery** | 5-axis structured interview: entities, relationships, processes, boundaries, governance |
| **Modeling** | Autonomous candidate derivation (Object, Link, Action types); semantic entity audit; cross-domain reference audit |
| **Design** | Palantir enrichment patterns: Object Enrichment, State Machine Audit (runs after Enrichment), Semantic Naming Review, Governance Metadata |
| **Construction** | Writes all domain files in dependency order; runs automatic validation |
| **Delivery** | Renders ASCII diagrams; generates `ontology/CONSULT_REPORT.md`; optional global sync |

---

## Examples

```
/ontologian-consult
"We run a logistics platform. Shipments are assigned to Drivers, pass through Hubs, and each leg is tracked as a RouteSegment."

/ontologian-analyze
"Users sign up and place Orders. Each Order has multiple OrderItems linked to a Product. When an Order is confirmed, we send a confirmation email."

/ontologian-add
"Add a new Object Type called Invoice to the billing domain — has invoice_id, issued_at, total_amount, and status (draft, sent, paid, overdue)."

/ontologian-search order --type action
/ontologian-validate
/ontologian-visualize
/ontologian-sync
```

---

## Plugin Structure

```
ontologian/
├── .claude-plugin/
│   └── marketplace.json         # Marketplace manifest (repo root only)
├── plugin/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   ├── add/SKILL.md
│   │   ├── analyze/SKILL.md
│   │   ├── consult/SKILL.md
│   │   ├── search/SKILL.md
│   │   ├── status/SKILL.md
│   │   ├── sync/SKILL.md
│   │   ├── validate/SKILL.md
│   │   └── visualize/SKILL.md
│   ├── agents/
│   │   └── ontology-consultant.md
│   └── hooks/
│       ├── hooks.json
│       └── session-start
├── setup.sh
└── README.md
```

---

## How It Works

The `ontology/` directory is created **lazily** — it does not exist until you run your first write command (`/ontologian-add` or `/ontologian-analyze`). Read-only commands require the directory to already exist.

```
<project-root>/
└── ontology/
    ├── config.yaml              # Plugin config (sync mode, global path)
    └── domains/
        ├── _index.yaml          # Domain registry
        └── <domain-name>/
            ├── objects/
            │   └── <ObjectTypeName>.md
            ├── links/
            │   └── <link_name>.md
            └── actions/
                └── <action_name>.md
```

### Domain file format

Each entity lives in its own file. The file content is YAML frontmatter only — no wrapper keys.

**`objects/Product.md`**
```markdown
---
name: Product
description: "A sellable item"
properties:
  - name: product_id
    type: string
    primary: true
  - name: price
    type: float
    description: "Sale price in KRW"
  - name: status
    type: string
    description: "Allowed values: active, inactive, discontinued"
---
```

**`links/places.md`**
```markdown
---
name: places
from: "[[ontology/domains/ecommerce/objects/User|User]]"
to: "[[ontology/domains/ecommerce/objects/Order|Order]]"
cardinality: one_to_many
description: "A user places one or more orders"
---
```

**`actions/send_welcome_email.md`**
```markdown
---
name: send_welcome_email
description: "Send a welcome email to a newly registered user"
target: "[[ontology/domains/ecommerce/objects/User|User]]"
trigger: object_created
parameters:
  - name: email_template
    type: string
---
```

**`_index.yaml`** (domain registry)
```yaml
domains:
  - name: ecommerce
    description: "E-commerce domain"
    domain_owner: "platform-team"
    stability: stable
    semantic_version: "1.0.0"
    directory: ecommerce
    last_modified: 2026-04-07
```

### `config.yaml` options

| Field | Values | Default | Description |
|---|---|---|---|
| `global_sync` | `ask` / `auto` / `off` | `ask` | Whether to sync changes to the global store |
| `global_path` | any path | `~/.ontologian` | Path to the global ontology store |

---

## Type Reference

### Object Type

| Field | Required | Description |
|---|---|---|
| `name` | Yes | PascalCase |
| `description` | Yes | What real-world entity this represents |
| `properties` | No | List of typed attributes |

**Property fields:**

| Field | Required | Description |
|---|---|---|
| `name` | Yes | snake_case |
| `type` | Yes | `string` / `int` / `float` / `boolean` / `date` / `datetime` |
| `description` | No | Field meaning; use `"Allowed values: X, Y, Z"` for status-pattern fields |
| `primary` | No | `true` for primary key (omit otherwise) |
| `computed` | No | `true` for computed field (omit otherwise) |
| `expression` | No | Computation expression (only when `computed: true`) |

### Link Type

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Present-tense active verb in snake_case (e.g. `places`, `contains`) |
| `from` | Yes | Source Object Type (Obsidian wiki link) |
| `to` | Yes | Target Object Type (Obsidian wiki link) |
| `cardinality` | Yes | `one_to_one` / `one_to_many` / `many_to_many` / `many_to_one` |
| `description` | Recommended | Relationship intent — omitting causes a validation WARNING |

Cross-domain links require `dependency_direction` to be declared in `_index.yaml` and a `description` explaining why direct linking is preferred over a reference ID.

### Action Type

| Field | Required | Description |
|---|---|---|
| `name` | Yes | snake_case verb (e.g. `send_welcome_email`) |
| `description` | Yes | What this action does |
| `target` | Yes | Target Object Type (Obsidian wiki link) |
| `trigger` | Yes | `object_created` / `object_updated` / `object_deleted` / `manual` |
| `trigger_condition` | No | Field-level condition (only with `object_updated`) |
| `parameters` | No | Input parameters — required for `manual` triggers |

**`trigger_condition` fields:**

| Field | Description |
|---|---|
| `field` | Property name to watch (must exist on `target`) |
| `from` | Value before change (optional) |
| `to` | Value after change (optional) |

---

## Validation

`/ontologian-validate` reports findings in three levels:

| Level | Meaning | Examples |
|---|---|---|
| `ERROR` | Must fix — invalid schema or broken reference | Missing required field, unknown Object Type reference, duplicate name |
| `WARNING` | Should fix — governance or design issue | Missing `domain_owner`, no primary key, missing Link `description`, `manual` trigger with no parameters |
| `HINT` | Consider — best practice suggestion | Missing property description, `many_to_many` without intermediate Object, no `semantic_version` |

Run after every significant change. `/ontologian-consult` and `/ontologian-analyze` run validation automatically before writing files.

---

## Global Store

The global store at `~/.ontologian/` (configurable via `global_path`) mirrors your local `ontology/` directory, enabling reuse across multiple projects. Sync is one-way: local → global.

Sync behavior is controlled by `global_sync` in `config.yaml`:

| Value | Behavior |
|---|---|
| `ask` | Prompts before each sync |
| `auto` | Syncs automatically after every write |
| `off` | Disabled |

---

## License

MIT
