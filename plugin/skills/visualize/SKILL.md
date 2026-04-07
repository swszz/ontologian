---
name: ontologian-visualize
description: Use when the user runs /ontologian-visualize or wants to see a visual ASCII diagram of an ontology domain's Object Types, relationships, and actions.
---

# Ontologian — Visualize

## Overview

Render a domain's ontology as an ASCII text diagram.
Display Object Types, Relationships (Link Types), and Actions (Action Types) in a structured layout.

---

## Steps

### Step 1: Initialization check

Glob `ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and **exit immediately**.

### Step 2: Read `_index.yaml`

Use the Read tool to read `ontology/domains/_index.yaml`.

If the `domains` array is empty:

```
No domains registered. Nothing to visualize.
```

Output and exit.

### Step 3: Select a domain

**If a domain name was provided as an argument** (e.g. `/ontologian-visualize ecommerce`):
- Look it up in the `domains` array.
- If found, select it directly and proceed to Step 4. Do not prompt the user.
- If not found, output an error and exit:
  ```
  Domain '<name>' not found. Available domains: <comma-separated list>
  ```

Otherwise, branch based on the number of items in the `domains` array.

**If there is exactly 1 domain:** Select it automatically and proceed to Step 4. Do not prompt the user.

**If there are 2 or more domains:** Display the domain list with an `all` option and prompt:

```
Select a domain to visualize:

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  all. All domains

Enter a number or 'all':
```

- **Number selection**: Process that single domain in Step 4.
- **`all`**: Process every domain in order. Repeat Steps 4–5 for each domain and output a separator between domains.

  Separator format:
  ```
  ════════════════════
  ```

### Step 4: Read domain file

All domains use the `directory` format:

- Glob `ontology/domains/<directory>/objects/*.yaml` → Read each → collect object names and properties
- Glob `ontology/domains/<directory>/links/*.yaml` → Read each → collect link definitions (name, from, to, cardinality)
- Glob `ontology/domains/<directory>/actions/*.yaml` → Read each → collect action definitions

If a file cannot be read, output the following and skip that domain:

```
[<domain_name>] Cannot read file: <file_path>
```

Store the read data in memory:

```
object_types: [...],   # empty array if absent
link_types: [...],     # empty array if absent
action_types: [...]    # empty array if absent
```

### Step 5: Render

Output in the following format. Always output every section even if it has no data.

**File link rendering (directory-format domains):**
Object Type labels in the diagram use file link format:
[<ObjectType>](ontology/domains/<directory>/objects/<ObjectType>.yaml)

#### 5-A: Object Types box

```
┌─────────────────────────────────────┐
│ DOMAIN: <domain_name>               │
├─────────────────────────────────────┤
│ OBJECT TYPES                        │
│                                     │
│  [<ObjectType1>]                    │
│   ├─ <prop_name>: <type> (<flags>)  │
│   └─ <prop_name>: <type>            │
│                                     │
│  [<ObjectType2>]                    │
│   └─ <prop_name>: <type>            │
└─────────────────────────────────────┘
```

**Box width rules:**
- Inner content max width + 4 (including left and right `│ ` padding)
- Minimum width: 39 characters (including box borders)

**Flag notation:**
- `primary: true` → append `(PK)`
- `computed: true` with no `expression` → append `(computed)`
- `computed: true` with `expression` → append `(computed: <expression>)`
- Both `primary: true` and `computed: true` → append `(PK, computed)`
- No flags → omit parentheses

**Tree characters:**
- Last property: `└─`
- Non-last property: `├─`
- Insert a blank line (`│                                     │`) between Object Types.
- Object Types with no properties show only the name.

**If no Object Types:**
```
│ OBJECT TYPES                        │
│  (none)                             │
```

#### 5-B: Relationships section

Output after a blank line following the box.

```
RELATIONSHIPS

  [<from>] ──(<link_name>, <cardinality>)──▶ [<to>]
```

**Cardinality notation:**

| YAML value | Display |
|------------|---------|
| `one_to_one` | `1:1` |
| `one_to_many` | `1:N` |
| `many_to_many` | `N:M` |
| `many_to_one` | `N:1` |

**If no Link Types:**
```
RELATIONSHIPS

  (none)
```

#### 5-C: Actions section

Output after a blank line.

```
ACTIONS

  <action_name>
   └─ trigger: <trigger> → [<target>]
```

If `trigger_condition` is present, render based on which sub-fields are set:

- If both `from` and `to` are present:
  ```
    <action_name>
     └─ trigger: object_updated (<field>: <from>→<to>) → [<target>]
  ```
- If only `from` is present (no `to`):
  ```
    <action_name>
     └─ trigger: object_updated (<field>: <from>→any) → [<target>]
  ```
- If only `to` is present (no `from`):
  ```
    <action_name>
     └─ trigger: object_updated (<field>: any→<to>) → [<target>]
  ```
- If only `field` is present (no `from`, no `to`):
  ```
    <action_name>
     └─ trigger: object_updated (<field>: any change) → [<target>]
  ```

Add a blank line between multiple Actions.

**If no Action Types:**
```
ACTIONS

  (none)
```

---

## Example output

```
┌─────────────────────────────────────┐
│ DOMAIN: ecommerce                   │
├─────────────────────────────────────┤
│ OBJECT TYPES                        │
│                                     │
│  [User]                             │
│   ├─ user_id: string (PK)           │
│   ├─ email: string                  │
│   └─ churn_score: float (computed)  │
│                                     │
│  [Order]                            │
│   └─ order_id: string (PK)          │
└─────────────────────────────────────┘

RELATIONSHIPS

  [User] ──(places, 1:N)──▶ [Order]

ACTIONS

  send_welcome_email
   └─ trigger: object_created → [User]
```

When `all` is selected:

```
┌─────────────────────────────────────┐
│ DOMAIN: ecommerce                   │
...
└─────────────────────────────────────┘

RELATIONSHIPS
...

ACTIONS
...

════════════════════

┌─────────────────────────────────────┐
│ DOMAIN: logistics                   │
...
```

---

## Common Mistakes

- **Showing selection menu for a single domain** → Auto-select when only one domain exists.
- **Flag condition confusion** → Only apply flag notation when `primary: true` or `computed: true`. Omit when absent or false.
- **Inconsistent box width** → The top (`┌─...─┐`), separator (`├─...─┤`), and bottom (`└─...─┘`) lines must always have the same length.
- **Missing separator when using `all`** → Always output `════════════════════` between domains.
- **Outputting raw cardinality values** → Never output the raw YAML value (e.g. `one_to_many`). Always apply the conversion table.
