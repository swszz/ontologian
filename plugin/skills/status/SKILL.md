---
name: ontologian-status
description: Use when the user runs /ontologian or wants to see the overall status of the ontology repository — domain list, type counts, last modified dates, and available commands.
---

# Ontologian — Overview

## Overview

Display a summary table and available commands for the project's ontology repository.

## Steps

### Step 1: Check `ontology/` exists

Glob `ontology/config.yaml` → if missing, output the following and **exit immediately**:

```
The ontology repository is not initialized.
To get started, run `/ontologian-add` or `/ontologian-analyze` (includes auto-initialization).

Available commands:
  /ontologian-add       — Add a new type
  /ontologian-analyze   — Derive ontology from business requirements
  /ontologian-consult   — Start a guided ontology consulting session
  /ontologian-search    — Search by keyword
  /ontologian-validate  — Validate integrity
  /ontologian-sync      — Sync to global store
  /ontologian-visualize — Render relationship diagram
```

### Step 2: Read config.yaml

Use the Read tool to read `ontology/config.yaml` and extract:

- `version`
- `global_sync` (default: `ask`)
- `global_path` (default: `~/.ontologian`)

### Step 3: Read `_index.yaml`

Use the Read tool to read `ontology/domains/_index.yaml`.

If the file is missing or the `domains` list is empty, output:

```
No domains registered.
Run `/ontologian-add` to add a domain.
```

Then skip to Step 5 (command list).

If a domain name was provided as an argument (e.g. `/ontologian ecommerce`):
- Store it as `domain_filter`.
- In Step 4, process only the domain whose `name` matches `domain_filter`.
- If not found in the `domains` array, output the following and exit:
  ```
  Domain '<name>' not found. Registered domains: <comma-separated list>
  ```

### Step 4: Read each domain's ontology files

Iterate over the `domains` array in `_index.yaml` and aggregate type counts per domain.

All domains use the `directory` format. Glob `.yaml` files in `ontology/domains/<directory>/objects/`, `ontology/domains/<directory>/links/`, and `ontology/domains/<directory>/actions/` to get counts.

**Aggregate per domain:**

| Field | How to count |
|-------|-------------|
| `object_count` | Number of `.yaml` files returned by glob in `ontology/domains/<directory>/objects/` |
| `link_count` | Number of `.yaml` files returned by glob in `ontology/domains/<directory>/links/` |
| `action_count` | Number of `.yaml` files returned by glob in `ontology/domains/<directory>/actions/` |
| `last_modified` | Value from `_index.yaml` for that domain |

If a domain file cannot be read, show `(read error)` in that row and skip it.

For `directory`-format domains: if the `objects/`, `links/`, or `actions/` subdirectory is missing, treat that count as 0.

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
Details: /ontologian-visualize | Validate all: /ontologian-validate

Available commands:
  /ontologian-add       — Add a new type
  /ontologian-analyze   — Derive ontology from business requirements
  /ontologian-consult   — Start a guided ontology consulting session
  /ontologian-search    — Search by keyword
  /ontologian-validate  — Validate integrity
  /ontologian-sync      — Sync to global store
  /ontologian-visualize — Render relationship diagram
```

**File link rendering (directory-format domains only):**
For domains using the `directory` format, render the domain name in the table as a markdown link:
`[<name>](ontology/domains/<directory>/)`

After the domains table and totals line, scan all properties across all domains:

For each property where the name matches `.*_id$` or `.*_ref$` (case-insensitive), output one line per match:
```
Possible cross-domain reference: <domain>.<ObjectType>.<property_name>
```

For `directory`-format domains, render the ObjectType as a file link:
```
Possible cross-domain reference: <domain>.[<ObjectType>](ontology/domains/<directory>/objects/<ObjectType>.yaml).<property_name>
```


If any such properties are found, precede the list with:
```
[i] Cross-domain reference candidates (properties ending in _id or _ref):
```

If none are found, omit this section entirely.

**Table rendering rules:**

- Add one row per domain. Close the table with `└─…─┘` after the last row.
- Column widths are fixed as shown above (truncate with `…` if content is too long).
- The totals line is output outside the table as a separate line.

## Common Mistakes

- **Domain file read error** → Double-check the directory glob paths in Step 4. Each subdirectory (`objects/`, `links/`, `actions/`) is read separately.
- **Missing subdirectory** → If `objects/`, `links/`, or `actions/` is absent, treat that count as 0.
- **Totals inside the table** → Totals must be output **outside** the table as a separate line.
