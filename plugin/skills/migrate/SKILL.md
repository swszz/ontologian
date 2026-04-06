---
name: ontologian-migrate
description: Use when the user runs /ontologian-migrate to upgrade a domain from the old single-file or per-type format to the new per-entity format (one file per Object Type, Link Type, and Action Type).
---

# Ontologian — Migrate

## Overview

Migrate an ontology domain from the legacy single-file format (`path`) or per-type format (`paths`) to the new per-entity format (`directory`):

- Old `path` format: `.ontology/domains/<domain>/ontology.yaml` (all types in one file)
- Old `paths` format: `.ontology/domains/<domain>/object_types.yaml`, `link_types.yaml`, `action_types.yaml`
- New `directory` format: `.ontology/domains/<domain>/objects/<Name>.yaml`, `links/<name>.yaml`, `actions/<name>.yaml`

Domains already using the `directory` format are skipped.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and **exit immediately**.

### Step 2: Read `_index.yaml`

Read `.ontology/domains/_index.yaml`. If the `domains` array is empty, output:

```
No domains registered. Nothing to migrate.
```

And exit.

### Step 3: Select a domain

Display the list of domains that are eligible for migration (those with `path` or `paths` — **not** those with `directory`):

```
Select a domain to migrate:

  1. <domain_name> — <description> [path format]
  2. <domain_name> — <description> [paths format]
  ...
  A. Migrate all eligible domains

Enter a number (or A):
```

If no eligible domains exist, output:

```
All domains are already using the per-entity format. Nothing to migrate.
```

And exit.

Wait for user input. Store the selected domain(s) as `targets`.

### Step 4: Read source data

For each target domain:

**If `path` field present** (single file):
Read `.ontology/domains/<path>`. Extract:
- `object_types` array (default `[]`)
- `link_types` array (default `[]`)
- `action_types` array (default `[]`)
- `description`, `domain_owner`, `stability`, `semantic_version` (for reference)

**If `paths` field present** (per-type files):
Read `.ontology/domains/<paths.object_types>`, `.ontology/domains/<paths.link_types>`, `.ontology/domains/<paths.action_types>`.
Extract the corresponding arrays from each file.

Store as `source_data[domain_name] = { object_types, link_types, action_types }`.

### Step 5: Preview migration

Show what will be created for each target domain:

```
Migration preview — <domain_name>:

  Objects  (<n>):  objects/<Name>.yaml  × <n>
  Links    (<n>):  links/<name>.yaml    × <n>
  Actions  (<n>):  actions/<name>.yaml  × <n>

  _index.yaml: `path`/`paths` → `directory: <domain_name>`
```

Then ask:

```
Proceed? (y / n)
```

- `n` → Output `Cancelled.` and exit.
- `y` → Proceed to Step 6.

### Step 6: Write per-entity files

For each target domain, process in order: Object Types → Link Types → Action Types.

#### 6-A: Object Types

For each item in `object_types`:

Use the Write tool to create `.ontology/domains/<domain_name>/objects/<Name>.yaml`:

```yaml
name: <Name>
description: "<description>"  # only if present
properties:
  - name: <property_name>
    type: <type>
    description: "<description>"  # only if present
    primary: true                  # only when true
    computed: true                 # only when true
    expression: "<expr>"           # only when computed=true and present
```

Omit `description` at any level if not present. Omit `primary`/`computed` unless `true`.

#### 6-B: Link Types

For each item in `link_types`:

Use the Write tool to create `.ontology/domains/<domain_name>/links/<name>.yaml`:

```yaml
name: <name>
from: <ObjectType>
to: <ObjectType>
cardinality: <cardinality>
description: "<description>"  # only if present
```

#### 6-C: Action Types

For each item in `action_types`:

Use the Write tool to create `.ontology/domains/<domain_name>/actions/<name>.yaml`:

```yaml
name: <name>
description: "<description>"  # only if present
target: <ObjectType>
trigger: <trigger>
trigger_condition:             # only when present
  field: <field>
  from: <value>                # only if present
  to: <value>                  # only if present
parameters:                    # only when at least one parameter
  - name: <param>
    type: <type>
    required: false            # only when false; omit when true
```

### Step 7: Update `_index.yaml`

For each migrated domain, use the Edit tool to:

1. Remove the `path: ...` or `paths:` block from the domain entry in `_index.yaml`.
2. Add `directory: <domain_name>` in its place.
3. Update `last_modified` to today's date.

The updated entry format:
```yaml
  - name: <domain_name>
    description: "<description>"
    domain_owner: "<owner>"
    stability: <stability>
    semantic_version: "<version>"
    directory: <domain_name>
    last_modified: <today_date>
```

### Step 8: Offer to delete old files

```
Migration complete. Delete old source files? (y/n)

  Files to delete:
  - .ontology/domains/<old_path>   (e.g. ecommerce/ontology.yaml)
    or
  - .ontology/domains/<paths.object_types>
  - .ontology/domains/<paths.link_types>
  - .ontology/domains/<paths.action_types>
```

- `y` → Use the Bash tool to delete the old files: `rm <file_path>`
- `n` → Skip deletion. The old files remain alongside the new structure.

### Step 9: Completion message

```
✓ Migration complete — <domain_name>

  Created:
    objects/  <n> files
    links/    <n> files
    actions/  <n> files

  _index.yaml updated: directory: <domain_name>

[i] Run /ontologian-validate to verify the migrated domain.
```

If multiple domains were migrated, show one block per domain.

---

## Common Mistakes

- **Migrating a `directory`-format domain** → Skip domains that already have a `directory` field. Only migrate `path` or `paths` domains.
- **Forgetting to update `_index.yaml`** → Always replace `path`/`paths` with `directory` after writing files.
- **Writing wrapper keys in per-entity files** → Each file contains the entity definition directly (no `object_types:` wrapper). The file IS the entity.
- **Keeping `primary: false` or `computed: false`** → Omit these fields when false. Only include when `true`.
