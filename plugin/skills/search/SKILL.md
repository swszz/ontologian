---
name: ontologian-search
description: Use when the user runs /ontologian-search or wants to search for a keyword across all ontology domains (object types, link types, action types).
---

# Ontologian — Search

## Overview

Search the entire ontology by keyword. Perform a case-insensitive search across Object Types, Link Types, and Action Types in all domains, and output results grouped by domain.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and exit.

---

### Step 2: Parse keyword and filters

Parse the keyword and filter options from the arguments.

- `--type=object|link|action` → search only the specified type
- `--domain=<name>` → search only the specified domain
- Remaining text → keyword

Example: `/ontologian-search User --type=object --domain=ecommerce`

If no arguments are given, prompt:
```
Enter a search keyword:
```

Store the keyword, type filter, and domain filter, then proceed to Step 3.

---

### Step 3: Read _index.yaml and load domain files

Read `.ontology/domains/_index.yaml`. If the `domains` array is empty, output `"No domains registered."` and exit.

If a `--domain` filter is set, process only that domain. Iterate over the `domains` array and Read each file.

All domains use the `directory` format:
- Glob and read `.ontology/domains/<directory>/objects/*.yaml` for object type matches
- Glob and read `.ontology/domains/<directory>/links/*.yaml` for link type matches
- Glob and read `.ontology/domains/<directory>/actions/*.yaml` for action type matches

Store type data in memory per domain. On read failure, log the error for that domain and continue.

---

### Step 4: Keyword search

Iterate over stored data per domain and search for the keyword case-insensitively.
If a `--type` filter is set, search only that type's array.

Search targets:

| Type | Fields searched |
|------|----------------|
| Object Type | `name`, `description`, `properties[].name` |
| Link Type | `name`, `description`, `from`, `to` |
| Action Type | `name`, `description`, `target`, `parameters[].name`, `trigger_condition.field`, `trigger_condition.from`, `trigger_condition.to` |

Collect matching items grouped by domain.

---

### Step 5: Output results

#### No results

```
No results found for '<keyword>'.
```

#### Results found

Output grouped by domain. Summarize key fields per item with a type label.

**Output format:**

```
## Search Results: "<keyword>"

### Domain: <domain_name>
[Object Type] <name>
  Description: <description>
  Properties: <prop1_name> (<type>[, PK][, computed]), <prop2_name> (<type>), ...

[Link Type] <name>
  <from> → <to> (<cardinality>)
  Description: <description>

[Action Type] <name>
  Description: <description>
  Target: <target> / Trigger: <trigger>

### Domain: <domain_name2>
...

Total: <N> result(s) (Object: <N>, Link: <N>, Action: <N>)

(Some domains failed to load: <name1>, <name2>)  ← only shown if any domain failed
```

**Result rendering (directory-format domains):**
Use the multi-line grouped format. For each matched result, render the entity name as a markdown file link within the type header line:

- Object Type: `[Object Type] [<name>](.ontology/domains/<directory>/objects/<name>.yaml)`
- Link Type: `[Link Type] [<name>](.ontology/domains/<directory>/links/<name>.yaml)`
- Action Type: `[Action Type] [<name>](.ontology/domains/<directory>/actions/<name>.yaml)`

The description, properties, and other detail lines below the header remain as plain text. Apply this format only to directory-format domains.

**Field output rules:**
- Omit the Description line if the item has no `description`.
- Summarize Object Type `properties` on one line. Mark `primary: true` as `PK` and `computed: true` as `computed` in parentheses. Omit if no properties.
- If a Link Type has no `cardinality`, show only the arrow (`→`).
- If an Action Type has no `trigger`, show only the target.
- Omit a type's section entirely if there are no matching items for that type.

---

## Example output

```
## Search Results: "User"

### Domain: ecommerce
[Object Type] User
  Description: Service user
  Properties: user_id (string, PK), email (string), churn_score (float, computed)

[Link Type] places
  User → Order (one_to_many)
  Description: A user places an order

Total: 2 result(s) (Object: 1, Link: 1, Action: 0)
```

---

## Common Mistakes

- **Case-sensitive search** → Keyword matching must always be case-insensitive.
- **Stopping on domain load failure** → If one domain fails to load, continue with the rest. Show a warning at the bottom: `(Some domains failed to load: <name>)`.
- **Missing total count** → Always output the total and per-type counts at the end of results.
