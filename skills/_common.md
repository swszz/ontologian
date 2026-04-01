---
name: _common
description: Shared patterns used by all ontologian skills. Not invoked directly. Each skill.md embeds an inline summary and references this file when detailed procedures are needed.
---

# Ontologian — Shared Pattern Reference

Each skill's inline summary is sufficient for execution. This file is a reference for detailed procedures when needed.

---

## Preamble A: Initialization Check (Read-only skills)

> Used in: ontologian, search, validate, migrate, visualize

**Inline summary (embed in each skill in this form):**
```
Glob `.ontology/domains/_index.yaml` → if missing, output "Ontology is not initialized." and exit.
Otherwise, proceed to the next step.
```

**Sync skill variant (config.yaml check):**
```
Glob `.ontology/config.yaml` → if missing, output "Ontology is not initialized." and exit.
Otherwise, Read it and store global_path (default: ~/.ontologian).
```

---

## Preamble B: Initialization Check + Auto-init (Write skills)

> Used in: add, analyze

**Inline summary (embed in each skill in this form):**
```
Glob `.ontology/config.yaml`:
- If missing: "The ontology repository is not initialized. Initialize it now? (y/n)"
  → n=exit, y=Write the following two files, then continue:
    .ontology/config.yaml: { version: 1, global_sync: ask, global_path: ~/.ontologian }
    .ontology/domains/_index.yaml: { domains: [] }
- If present: Read it and store global_sync, global_path (defaults: ask, ~/.ontologian)
```

---

## Pattern: Reading Domain Files (path/paths)

> Used in: ontologian, add, analyze, search, validate, visualize, sync

**Inline summary (embed in each skill in this form):**
```
Branch on path/paths:
- If path is present: Read .ontology/domains/<path> → extract object_types, link_types, action_types
- If paths is present: Read .ontology/domains/<paths.object_types>, <paths.link_types>, <paths.action_types> separately
Treat missing array keys as empty arrays. On read failure, log the error and skip that domain.
```

---

## Subroutine: Domain Selection Menu

> Used in: add Step 3, analyze Step 7

**Inline summary:**
```
Display existing domain list with numbers + "N. Create new domain"
→ If no domains exist: "Enter a name for the new domain:"
→ On new domain selection: prompt for name → prompt for description (optional, press Enter to skip)
```

**Full output format:**
```
Which domain would you like to add to?

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  N. Create new domain

Enter a number:
```

---

## Subroutine: Global Sync Check

> Used in: add Step 8, analyze Step 10, migrate Step 10

**Inline summary (embed in each skill in this form):**
```
Based on global_sync:
- ask → "Sync to global store (<global_path>) as well? (y/n)" — y=proceed, n=skip
- auto → proceed immediately
- off → skip
Action: Write-copy the modified domain file(s) + _index.yaml to <global_path>/domains/
```

**Details:**
- Pre-migration domain: Write `<global_path>/domains/<domain_name>/ontology.yaml`
- Post-migration domain: Write the modified type file(s)
- Always overwrite `<global_path>/domains/_index.yaml` with the latest content

---

## Common Rules

Rules that apply to all skills — deduplicated from individual skill Common Mistakes sections.

1. **path vs. paths confusion**: `path` (singular) = pre-migration single file; `paths` (plural) = post-migration three separate type files. Always check the exact field name.
2. **Empty array (`[]`) handling**: When `object_types: []` is present, appending items directly will break the YAML. Always replace with proper array form:
   ```
   old: "object_types: []"
   new: "object_types:\n  - name: ..."
   ```
3. **Updating last_modified**: After modifying any YAML file, always update the corresponding domain's `last_modified` in `_index.yaml` to today's date (YYYY-MM-DD).
4. **Omitting empty description**: If there is no description, omit the field entirely rather than writing `description: ""`. This applies at both the type level and the property level.
5. **Omitting false fields**: Do not write `primary: false` or `computed: false`. Only include these fields when their value is `true`.
6. **Property description**: Each property may optionally include a `description`. For fields with a defined set of allowed values, use the format `"Allowed values: A, B, C"`. Omit the field if there is nothing meaningful to say.

**Object Type property schema (complete):**
```yaml
properties:
  - name: <snake_case>
    type: string|int|float|boolean|date|datetime
    description: "<field meaning, allowed values, business context>"  # optional (omit if absent)
    primary: true       # only when primary=true
    computed: true      # only when computed=true
    expression: "<expr>"  # only when computed=true and expression is known
```
