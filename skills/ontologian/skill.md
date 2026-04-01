---
name: ontologian
description: Use when the user runs /ontologian or wants to see the overall status of the ontology repository — domain list, type counts, last modified dates, and available commands.
---

# Ontologian — Overview

## Overview

Display a summary table and available commands for the project's ontology repository.

## Steps

### Step 1: Check `.ontology/` exists

Glob `.ontology/config.yaml` → if missing, output the following and **exit immediately**:

```
The ontology repository is not initialized.
To get started, run `/ontologian:add` or `/ontologian:analyze` (includes auto-initialization).

Available commands:
  /ontologian:add       — Add a new type
  /ontologian:analyze   — Derive ontology from business requirements
  /ontologian:search    — Search by keyword
  /ontologian:validate  — Validate integrity
  /ontologian:sync      — Sync to global store
  /ontologian:migrate   — Split domain file into per-type files
  /ontologian:visualize — Render relationship diagram
```

### Step 2: Read config.yaml

Use the Read tool to read `.ontology/config.yaml` and extract:

- `version`
- `global_sync` (default: `ask`)
- `global_path` (default: `~/.ontologian`)

### Step 3: Read `_index.yaml`

Use the Read tool to read `.ontology/domains/_index.yaml`.

If the file is missing or the `domains` list is empty, output:

```
No domains registered.
Run `/ontologian:add` to add a domain.
```

Then skip to Step 5 (command list).

### Step 4: Read each domain's ontology files

Iterate over the `domains` array in `_index.yaml` and aggregate type counts per domain.

**Determining migration status:**

- If the `path` field is present → pre-migration: Read the single file at `.ontology/domains/<path>`.
- If the `paths` field is present → post-migration: Read `paths.object_types`, `paths.link_types`, and `paths.action_types` separately. Resolve each to `.ontology/domains/<paths.X>` (e.g. if `paths.object_types` is `user/object_types.yaml`, read `.ontology/domains/user/object_types.yaml`).

**Aggregate per domain:**

| Field | How to count |
|-------|-------------|
| `object_count` | Number of items in `object_types` array |
| `link_count` | Number of items in `link_types` array |
| `action_count` | Number of items in `action_types` array |
| `last_modified` | Value from `_index.yaml` for that domain |

If a domain file cannot be read, show `(read error)` in that row and skip it.

### Step 5: Output results

Output in the following format using Unicode box characters:

```
## Ontologian — Repository Status

Config:
  Global sync: <global_sync>   ※ ask=prompt on change / auto=sync automatically / off=disabled
  Global path: <global_path>

Domains:
┌────────────────┬──────────┬──────────┬──────────┬──────────────────┐
│ Domain         │ Objects  │ Links    │ Actions  │ Last Modified    │
├────────────────┼──────────┼──────────┼──────────┼──────────────────┤
│ <name>         │ <n>      │ <n>      │ <n>      │ <date>           │
└────────────────┴──────────┴──────────┴──────────┴──────────────────┘

Total domains: <N> | Object Types: <N> | Link Types: <N> | Action Types: <N>
Details: /ontologian:visualize | Validate all: /ontologian:validate

Available commands:
  /ontologian:add       — Add a new type
  /ontologian:analyze   — Derive ontology from business requirements
  /ontologian:search    — Search by keyword
  /ontologian:validate  — Validate integrity
  /ontologian:sync      — Sync to global store
  /ontologian:migrate   — Split domain file into per-type files
  /ontologian:visualize — Render relationship diagram
```

**Table rendering rules:**

- Add one row per domain. Close the table with `└─…─┘` after the last row.
- Column widths are fixed as shown above (truncate with `…` if content is too long).
- The totals line is output outside the table as a separate line.

## Common Mistakes

- **Domain file read error** → Double-check the path/paths branching logic in Step 4. Post-migration domains require reading three separate files.
- **Missing array key** → If `object_types` is absent, treat the count as 0.
- **Totals inside the table** → Totals must be output **outside** the table as a separate line.
