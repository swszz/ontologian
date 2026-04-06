---
name: migrate
description: Use when the user runs /ontologian:migrate or wants to split a domain's single ontology.yaml into separate object_types.yaml, link_types.yaml, and action_types.yaml files.
---

# Ontologian — Migrate

## Overview

Split a domain's single `ontology.yaml` into three separate files: `object_types.yaml`, `link_types.yaml`, and `action_types.yaml`.
Domains that already have a `paths` field are already migrated and are excluded from the target list.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and **exit immediately**.

### Step 2: Read `_index.yaml`

Use the Read tool to read `.ontology/domains/_index.yaml`.

Store the `domains` array in memory.

If the `domains` array is empty, output the following and **exit immediately**:

```
No domains registered.
```

**Filter migratable domains:**

Extract only items with a `path` field from the `domains` array. (Items with a `paths` field are already migrated → exclude.)

If no migratable domains remain, output the following and **exit immediately**:

```
No migratable domains found. All domains are already migrated.
```

Store the filtered list as `migratable_domains` in memory.

### Step 3: Select a target domain

Display the `migratable_domains` list with numbers:

```
Select a domain to split:

  1. <domain_name_1> — <description_1>  (path: <path_1>)
  2. <domain_name_2> — <description_2>  (path: <path_2>)
  ...

Enter a number:
```

Omit the `— <description>` part for domains with no `description` field.

Wait for user input and store the selected domain as `target_domain` in memory.

If an invalid number is entered, re-prompt:

```
Please enter a valid number (1–<N>):
```

### Step 4: Read ontology.yaml

Use the Read tool to read `.ontology/domains/<target_domain.path>`.

Example: `.ontology/domains/ecommerce/ontology.yaml`

Extract and store in memory:

- `domain`: domain name
- `version`: version number (default `1` if absent)
- `object_types`: array (empty array if absent)
- `link_types`: array (empty array if absent)
- `action_types`: array (empty array if absent)

Derive `target_dir` by removing the filename from `<target_domain.path>`.
Example: `path = ecommerce/ontology.yaml` → `target_dir = ecommerce`

### Step 5: Output migration preview

```
[<domain_name>] Migration Preview

Files to be created:
  • .ontology/domains/<target_dir>/object_types.yaml  (<N> Object Types)
  • .ontology/domains/<target_dir>/link_types.yaml    (<N> Link Types)
  • .ontology/domains/<target_dir>/action_types.yaml  (<N> Action Types)

_index.yaml change:
  - path: <target_domain.path>
  + paths:
      object_types: <target_dir>/object_types.yaml
      link_types: <target_dir>/link_types.yaml
      action_types: <target_dir>/action_types.yaml

Proceed? (y/n)
```

`<N>` is the count of items in each array. Output `0` for empty arrays.

- `n` → output and **exit**:
  ```
  Cancelled.
  ```
- `y` → proceed to Step 6.

### Step 6: Create split files

#### 6-A: Create object_types.yaml

Use the Write tool to create `.ontology/domains/<target_dir>/object_types.yaml`.

If `object_types` is not empty:
```yaml
domain: <domain_name>
version: <version>
object_types:
  # existing object_types content verbatim
```

If `object_types` is empty:
```yaml
domain: <domain_name>
version: <version>
object_types: []
```

#### 6-B: Create link_types.yaml

Use the Write tool to create `.ontology/domains/<target_dir>/link_types.yaml`.

If `link_types` is not empty:
```yaml
domain: <domain_name>
version: <version>
link_types:
  # existing link_types content verbatim
```

If `link_types` is empty:
```yaml
domain: <domain_name>
version: <version>
link_types: []
```

#### 6-C: Create action_types.yaml

Use the Write tool to create `.ontology/domains/<target_dir>/action_types.yaml`.

If `action_types` is not empty:
```yaml
domain: <domain_name>
version: <version>
action_types:
  # existing action_types content verbatim
```

If `action_types` is empty:
```yaml
domain: <domain_name>
version: <version>
action_types: []
```

### Step 6-D: Integrity check before index update

Before modifying `_index.yaml`, verify all three split files were successfully written.

Use Glob to check each of the three files:
- `.ontology/domains/<target_dir>/object_types.yaml`
- `.ontology/domains/<target_dir>/link_types.yaml`
- `.ontology/domains/<target_dir>/action_types.yaml`

If any file is missing, output the following and **exit immediately** (do NOT proceed to Step 7):
```
✗ Migration aborted — one or more split files were not written successfully.

  Missing files:
    • .ontology/domains/<target_dir>/<missing_file>  ← not found

  The original .ontology/domains/<target_domain.path> has not been modified.
  The _index.yaml has not been modified.
  Run /ontologian:migrate again to retry from scratch.
```

Only proceed to Step 7 if all three files exist.

### Step 7: Update `_index.yaml`

Re-read `.ontology/domains/_index.yaml` with the Read tool.

Use the Edit tool to replace the domain entry's `path` field with a `paths` block.

**Before (`old_string` — the path line only):**
```yaml
  path: <target_domain.path>
```

**After (`new_string`):**
```yaml
  paths:
    object_types: <target_dir>/object_types.yaml
    link_types: <target_dir>/link_types.yaml
    action_types: <target_dir>/action_types.yaml
  last_modified: <today_date>
```

Use today's date in `YYYY-MM-DD` format for `<today_date>`.

Leave all other fields (`description`, `name`, etc.) unchanged.

### Step 8: Write migration log

Use the Write tool to create `.ontology/migrations/YYYY-MM-DD-split-<domain_name>.log`.

Use today's date in `YYYY-MM-DD` format in the filename.
Example: `.ontology/migrations/2026-03-30-split-ecommerce.log`

Log file content:

```
date: <today_date>
domain: <domain_name>
action: split ontology.yaml into separate type files

source:
  file: .ontology/domains/<target_domain.path>

created:
  - .ontology/domains/<target_dir>/object_types.yaml  (<N> object_types)
  - .ontology/domains/<target_dir>/link_types.yaml    (<N> link_types)
  - .ontology/domains/<target_dir>/action_types.yaml  (<N> action_types)

index_updated: .ontology/domains/_index.yaml
  path -> paths (object_types, link_types, action_types)
```

### Step 9: Archive original file

Prompt the user to delete the original `ontology.yaml`:

```
✓ [<domain_name>] Migration complete

Files created:
  • .ontology/domains/<target_dir>/object_types.yaml
  • .ontology/domains/<target_dir>/link_types.yaml
  • .ontology/domains/<target_dir>/action_types.yaml

_index.yaml updated (path → paths)
Log: .ontology/migrations/<log_filename>

The original file still exists:
  .ontology/domains/<target_domain.path>

Delete it now? (y/n — recommended: y)
```

- `y` → Use Bash to run: `rm ".ontology/domains/<target_domain.path>"`
  Then output: `[✓] Original file deleted.`
- `n` → Output:
  ```
  [i] Original file kept. Run /ontologian:validate to detect stale files.
      Delete manually when ready: rm .ontology/domains/<target_domain.path>
  ```

### Step 10: Global sync check

Glob `.ontology/config.yaml` → if missing, skip. If present, Read and check `global_sync` and `global_path`.

- `ask` → `"Sync to global store (<global_path>) as well? (y/n)"` → y=proceed, n=skip
- `auto` → proceed immediately
- `off` or config.yaml missing → skip

**Proceed**: Write-copy `object_types.yaml`, `link_types.yaml`, and `action_types.yaml` to `<global_path>/domains/<domain_name>/`. Also overwrite `_index.yaml` at `<global_path>/domains/`.

---

## Common Mistakes

- **Not excluding already-migrated domains** → Domains with a `paths` field must be excluded in Step 2.
- **Wrong `target_dir` extraction** → `path: ecommerce/ontology.yaml` → `target_dir = ecommerce`. Handle nested paths correctly (e.g. `shop/v2/ontology.yaml` → `shop/v2`).
- **Losing original type array content** → Copy the source array items verbatim into the split files.
- **Losing other fields when replacing in `_index.yaml`** → Replace only the `path` line. Leave `description`, `name`, and other fields unchanged.
- **Including `last_modified` in `old_string`** → The date value may not match. Use only the `path` line (`  path: <value>`) as the match target.
- **Wrong indentation in `old_string`** → Must exactly match 2-space indentation.
- **Auto-deleting the original file** → Never delete the original `ontology.yaml`. Only inform the user and let them delete it manually.
