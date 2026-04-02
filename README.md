# Ontologian

**A Claude Code plugin for structured knowledge management based on Palantir Ontology concepts.**

Ontologian brings Object Types, Link Types, and Action Types into your Claude Code workflow — letting you define, navigate, and validate your domain knowledge as structured YAML directly inside your project.

---

## Installation

### Step 1 — Register the marketplace

```bash
curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash
```

This adds Ontologian's GitHub repo as a known marketplace source in `~/.claude/settings.json`.

### Step 2 — Install the plugin

Run inside Claude Code:

```
/plugin install ontologian@ontologian
```

### Update

```
/plugin update ontologian
```

---

## Commands

| Command | Description |
|---|---|
| `/ontologian:consult` | **Start a Palantir-grade ontology consulting session** — guided discovery, design, construction, and governance documentation |
| `/ontologian` | Show domain list and status summary |
| `/ontologian:add` | Interactively add a new type to a domain |
| `/ontologian:analyze` | Derive ontology structure from free-form requirements |
| `/ontologian:search <keyword>` | Search across all domains |
| `/ontologian:validate` | Check YAML schema and referential integrity |
| `/ontologian:sync` | Sync local `.ontology/` to the global store |
| `/ontologian:migrate` | Split a domain's single file into per-type files |
| `/ontologian:visualize` | Render an ASCII relationship diagram |

### Consulting Agent

The plugin includes an `ontology-consultant` agent that activates in two ways:

- **Proactively** — when you describe business requirements, system design, or domain entities, the agent automatically offers to model them as an ontology
- **Explicitly** — run `/ontologian:consult` to start a full consulting session immediately

The consulting session covers 5 phases:

| Phase | What happens |
|---|---|
| **Discovery** | 5-axis structured interview: entities, relationships, processes, boundaries, governance |
| **Modeling** | Autonomous candidate derivation using the same rules as `/ontologian:analyze` |
| **Design** | Palantir enrichment patterns: object enrichment, state machine audit, semantic naming review, governance metadata |
| **Construction** | Writes all domain files in dependency order, runs automatic validation |
| **Delivery** | Renders ASCII diagrams for all domains, generates `.ontology/CONSULT_REPORT.md` |

---

## How It Works

After installation, a `.ontology/` directory is created in your project:

```
<project-root>/
└── .ontology/
    ├── config.yaml          # Plugin config (sync mode, global path)
    ├── domains/
    │   ├── _index.yaml      # Domain registry
    │   └── <domain-name>/
    │       └── ontology.yaml
    └── migrations/
```

### Domain file structure

```yaml
domain: ecommerce
version: 1
description: "E-commerce domain"

object_types:
  - name: Product
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

link_types:
  - name: places
    from: User
    to: Order
    cardinality: one_to_many
    description: "User places an order"

action_types:
  - name: send_welcome_email
    description: "Send welcome email to newly registered users"
    target: User
    trigger: object_created
    parameters:
      - name: email_template
        type: string
```

### `config.yaml` options

| Field | Values | Default | Description |
|---|---|---|---|
| `global_sync` | `ask` / `auto` / `off` | `ask` | Whether to sync changes to the global store |
| `global_path` | any path | `~/.ontologian` | Path to the global ontology store |

---

## Type Reference

### Object Type

Represents a business entity (equivalent to a database table or domain model class).

| Field | Required | Description |
|---|---|---|
| `name` | Yes | PascalCase identifier |
| `description` | Yes | Human-readable explanation |
| `properties` | No | List of typed attributes |

**Property fields:**

| Field | Required | Description |
|---|---|---|
| `name` | Yes | snake_case identifier |
| `type` | Yes | `string` / `int` / `float` / `boolean` / `date` / `datetime` |
| `description` | No | Field meaning, allowed values, business context |
| `primary` | No | Set `true` for primary key (omit if false) |
| `computed` | No | Set `true` for computed field (omit if false) |
| `expression` | No | Computation expression (only when `computed: true`) |

### Link Type

Represents a directional relationship between two Object Types.

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Verb form in lowercase (e.g. `places`, `contains`) |
| `from` | Yes | Source Object Type |
| `to` | Yes | Target Object Type |
| `cardinality` | Yes | `one_to_one` / `one_to_many` / `many_to_many` / `many_to_one` |
| `description` | No | Relationship meaning |

### Action Type

Represents a triggerable operation on an Object Type.

| Field | Required | Description |
|---|---|---|
| `name` | Yes | snake_case verb (e.g. `send_welcome_email`) |
| `description` | Yes | What this action does |
| `target` | Yes | Target Object Type |
| `trigger` | Yes | `object_created` / `object_updated` / `object_deleted` / `manual` |
| `trigger_condition` | No | Field-level condition (only with `object_updated`) |
| `parameters` | No | List of typed input parameters |

---

## Global Store

The global store at `~/.ontologian/` (configurable) mirrors your local `.ontology/` directory and enables reuse of domain definitions across multiple projects.

Sync behavior is controlled by `global_sync` in `config.yaml`:
- `ask` — prompts before each sync
- `auto` — syncs automatically after every change
- `off` — disables syncing

---

## License

MIT
