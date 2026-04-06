---
name: sync
description: Use when the user runs /ontologian:sync or wants to manually sync local .ontology/ to the global ~/.ontologian/ directory.
---

# Ontologian — Sync

## Overview

Manually sync the local `.ontology/` directory to the global `~/.ontologian/` store.
Show a preview before syncing and wait for user confirmation before copying files.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/config.yaml` → if missing, output `"Ontology is not initialized. (.ontology/config.yaml not found)"` and **exit immediately**.

### Step 2: Read config.yaml

Use the Read tool to read `.ontology/config.yaml`:

```
Read: .ontology/config.yaml
```

Store the following values in memory:

- `global_path`: default `~/.ontologian` if absent
- `global_sync`: store for reference (this skill always runs manually, so the value does not affect execution)

### Step 3: Read _index.yaml

Use the Read tool to read `.ontology/domains/_index.yaml`:

```
Read: .ontology/domains/_index.yaml
```

If the `domains` array is absent or empty, output the following and **exit immediately**:

```
No domains to sync. (domains array is empty)
```

Collect the file list from each domain entry. For each entry, determine migration status:

- If `path` is present → 1 file: `<path>` (e.g. `ecommerce/ontology.yaml`)
- If `paths` is present → add `paths.object_types`, `paths.link_types`, and `paths.action_types` to the list (e.g. `ecommerce/object_types.yaml`). Skip any missing keys.

Store the collected file list as the `sync_files` array in memory.
Also include `_index.yaml` itself as a sync target.

### Step 4: Output sync preview

Build the preview from the `sync_files` array.
Show local paths as `.ontology/domains/<file>` and global paths as `<global_path>/domains/<file>`.
Show `_index.yaml` as: `.ontology/domains/_index.yaml` → `<global_path>/domains/_index.yaml`.

```
## Sync Preview
Local → Global (<global_path>)
  ecommerce/ontology.yaml     → <global_path>/domains/ecommerce/ontology.yaml
  ecommerce/object_types.yaml → <global_path>/domains/ecommerce/object_types.yaml
  ecommerce/link_types.yaml   → <global_path>/domains/ecommerce/link_types.yaml
  ecommerce/action_types.yaml → <global_path>/domains/ecommerce/action_types.yaml
  domains/_index.yaml         → <global_path>/domains/_index.yaml
Total: N file(s)

Proceed? (y/n)
```

`N` is the number of domain files + 1 (for `_index.yaml`).

Wait for user input.

- **`n`** → output and exit:
  ```
  Cancelled.
  ```
- **`y`** → proceed to Step 5.

### Step 5: Check and create global config.yaml

Use the Glob tool to check whether `<global_path>/config.yaml` exists:

```
Glob: pattern="<global_path>/config.yaml"
```

If not found, use the Write tool to create it with:

```yaml
version: 1
```

If it already exists, skip.

### Step 5b: Create global directory structure

Before copying any files, ensure all required directories exist in two stages:

**Stage 1 — Create the domains root:**
```
mkdir -p <global_path>/domains
```
If this fails (e.g. permission error), output the following and **exit immediately**:
```
✗ Sync failed: cannot create directory <global_path>/domains
  Check write permissions on <global_path> and retry.
```

**Stage 2 — Create per-domain directories:**
For each domain name in the `domains` array of `_index.yaml`:
```
mkdir -p <global_path>/domains/<domain_name>
```
If any per-domain mkdir fails, output and **exit immediately**:
```
✗ Sync failed: cannot create directory <global_path>/domains/<domain_name>
  All directories must be confirmed before writing files.
```

Only proceed to Step 6 after all directories are confirmed.

### Step 6: Copy domain files

Iterate over the `sync_files` array and copy each file.

For each file:

1. Use the Read tool to read the local file: `.ontology/domains/<file>`
2. Use the Write tool to write to the global path: `<global_path>/domains/<file>`

If a read or write fails, add the filename to the warnings list and **continue with the next file**:

```
⚠ Copy failed: <file>
```

Do not stop copying remaining files on failure.

### Step 7: Copy _index.yaml

Use the Read tool to read `.ontology/domains/_index.yaml`.
Use the Write tool to write to `<global_path>/domains/_index.yaml`.

If it fails, add to the warnings list and continue:

```
⚠ Copy failed: domains/_index.yaml
```

### Step 8: Output completion message

Calculate the number of successfully copied files (`N` = total target files − failed files).

**No warnings:**

```
✓ Sync complete: N file(s) → <global_path>
```

**One or more warnings:** output the warning list first, then the completion message:

```
⚠ Copy failed: <file1>
⚠ Copy failed: <file2>

✓ Sync complete: N file(s) → <global_path>  (M failed)
```

`M` is the number of failed files.

---

## Common Mistakes

- **Omitting `_index.yaml`** → `_index.yaml` must always be included in the sync target alongside domain files.
- **Wrong default for `global_path`** → Use `~/.ontologian` if the field is absent from `config.yaml`.
- **Stopping on individual file failure** → Log a warning for each failed file and continue with the rest.
- **Wrong total file count in preview** → Total N = number of domain files + 1 (for `_index.yaml`).
- **Overwriting global config.yaml** → Only create it if it does not already exist. Always Glob first.
