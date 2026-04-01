---
name: ontologian:add
description: Use when the user runs /ontologian:add or wants to add a new Object Type, Link Type, or Action Type to an ontology domain.
---

# Ontologian — Add Type

## Overview

Interactively add a new Object Type, Link Type, or Action Type to the ontology.
**Ask only one question at a time. Never bundle multiple questions together.**

---

## Steps

### Step 1: Initialization check

Glob `.ontology/config.yaml`:
- **If missing**: `"The ontology repository is not initialized. Initialize it now? (y/n)"` → `n`=exit, `y`=Write the following two files and continue:
  - `.ontology/config.yaml`: `version: 1 / global_sync: ask / global_path: ~/.ontologian`
  - `.ontology/domains/_index.yaml`: `domains: []`
- **If present**: Read it and store `global_sync`, `global_path` (defaults: `ask`, `~/.ontologian`)

### Step 2: Read _index.yaml

Use the Read tool to load the domain list:

```
Read: .ontology/domains/_index.yaml
```

Store the `domains` array in memory. Continue even if the array is empty.

### Step 3: Select a domain

Display the current domain list and the option to create a new one.

**If domains exist:**
```
Which domain would you like to add to?

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  N. Create new domain

Enter a number:
```

**If no domains exist:**
```
No domains registered. Enter a name for the new domain:
```

Wait for user input.

- **Number selection** (existing domain): Store that domain's `name` and `path`/`paths` fields in memory. Proceed to Step 4.
- **"N" or new domain text**: Prompt for a domain name (lowercase letters, hyphens, and underscores allowed), then:

  ```
  Enter a description for the domain (optional, press Enter to skip):
  ```

  Store as `new_domain = { name, description }`. Proceed to Step 4.

### Step 4: Select a type

```
What type would you like to add?

  1. Object Type  — A business entity (e.g. User, Product)
  2. Link Type    — A relationship between entities (e.g. places, contains)
  3. Action Type  — A triggerable operation (e.g. send_welcome_email)

Enter a number:
```

Store the selection (`object` / `link` / `action`) in memory and proceed to the corresponding step.

---

### Step 5-A: Collect Object Type information

Ask the following questions **one at a time** in order.

1. **Name and description** (PascalCase):
   ```
   Enter the Object Type name and description.
   (Format: "Name, Description"  e.g. "Product, A sellable item"  /  Name only: "Product")
   ```

   If the name is not PascalCase (first letter uppercase, only letters/digits, no spaces/underscores/hyphens), re-prompt immediately:
   ```
   The name must be PascalCase (e.g. Product). Please try again:
   ```
   Repeat until a valid value is entered.

2. **Collect properties** (repeat the following prompt):

   ```
   Enter a property name (press Enter when done):
   ```

   When a name is entered, ask in order:

   ```
   Select a type:
     1. string
     2. int
     3. float
     4. boolean
     5. date
     6. datetime
   Enter a number:
   ```

   ```
   Set as primary key? (y/n, default n):
   ```

   ```
   Is this a computed property? (y/n, default n):
   ```

   - Only include `computed: true` when the user answers `y`.
   - If `computed: true`, ask for the expression:
     ```
     Enter the computation expression (e.g. "gross_amount - fee", press Enter to skip):
     ```
     Store the value in the `expression` field if provided.

   Then ask for a description:
   ```
   Enter a description for this field (meaning, allowed values, context, etc. — press Enter to skip):
   ```
   If provided, store in the property's `description` field. If empty, omit the field.

   - After collecting at least one property, an empty Enter on the name prompt ends collection.

Store the collected data as a `new_entry` object:
```yaml
name: <PascalCase name>
description: "<description>"      # only if provided
properties:
  - name: <property_name>
    type: <type>
    description: "<description>"  # only if provided
    primary: true                  # only when primary=true
    computed: true                 # only when computed=true
    expression: "<expr>"           # only when computed=true and expression provided
```

---

### Step 5-B: Collect Link Type information

Ask the following questions **one at a time** in order.

If this is an existing domain, show the known Object Type names from that domain before Step 6 as a reference (skip if it's a new domain).

1. **Name** (lowercase, underscores allowed):
   ```
   Enter a Link Type name (use a verb form, e.g. places, contains):
   ```

   If not lowercase with underscores (digits allowed, no uppercase/spaces/hyphens), re-prompt:
   ```
   The name must be lowercase with underscores only (e.g. places, has_order). Please try again:
   ```
   Repeat until valid.

2. **from** (source Object Type):
   ```
   Enter the from Object Type (e.g. User):
   ```

3. **to** (target Object Type):
   ```
   Enter the to Object Type (e.g. Order):
   ```

4. **cardinality**:
   ```
   Select a cardinality:
     1. one_to_one
     2. one_to_many
     3. many_to_many
     4. many_to_one
   Enter a number:
   ※ many_to_one can also be expressed as a reversed one_to_many
   ```

5. **Description**:
   ```
   Enter a description (optional, press Enter to skip):
   ```

Store as `new_entry`:
```yaml
name: <name>
from: <ObjectType>
to: <ObjectType>
cardinality: <cardinality>
description: "<description>"      # only if provided
```

---

### Step 5-C: Collect Action Type information

Ask the following questions **one at a time** in order.

1. **Name** (snake_case):
   ```
   Enter an Action Type name (snake_case, e.g. send_welcome_email):
   ```

   If not snake_case (lowercase and underscores only, digits allowed, no uppercase/spaces/hyphens), re-prompt:
   ```
   The name must be snake_case (e.g. send_email). Please try again:
   ```
   Repeat until valid.

2. **Description**:
   ```
   Enter a description (optional, press Enter to skip):
   ```

3. **target** (target Object Type):
   ```
   Enter the target Object Type (e.g. User):
   ```

4. **trigger**:
   ```
   Select a trigger condition:
     1. object_created
     2. object_updated
     3. object_deleted
     4. manual
   Enter a number:
   ```

   If `object_updated` is selected, ask for trigger_condition:
   ```
   Which field change should trigger this action? (e.g. status, press Enter to skip):
   ```
   If a field is entered:
   ```
   Value before the change (from, e.g. calculated, press Enter to skip):
   ```
   ```
   Value after the change (to, e.g. approved, press Enter to skip):
   ```
   If any of field, from, or to is provided, store as `trigger_condition: {field, from, to}`.

5. **Collect parameters** (repeat the following prompt):

   ```
   Add a parameter? (y/n):
   ```

   If `y`, ask in order:

   ```
   Enter a parameter name:
   ```

   ```
   Select a type:
     1. string
     2. int
     3. float
     4. boolean
     5. date
     6. datetime
   Enter a number:
   ```

   ```
   Is this parameter required? (y/n, default y):
   ```

   Store the parameter and repeat. Stop when the user answers `n`.

Store as `new_entry`:
```yaml
name: <snake_case name>
description: "<description>"      # only if provided
target: <ObjectType>
trigger: <trigger>
trigger_condition:                 # only when trigger=object_updated and at least one value provided
  field: <field_name>
  from: <value>
  to: <value>
parameters:                        # only when at least one parameter exists
  - name: <param_name>
    type: <type>
    required: true                 # omit when true (it's the default); include only when false
```

---

### Step 6: Preview and confirm

Output the collected `new_entry` in YAML diff format. Include the domain name and type kind in a comment.

**Object Type example:**
```yaml
# To be added (domain: ecommerce, object_types)
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
      description: "Product status. Allowed values: active, inactive, discontinued"
```

**Link Type example:**
```yaml
# To be added (domain: ecommerce, link_types)
- name: contains
  from: Order
  to: Product
  cardinality: one_to_many
  description: "An order contains products"
```

**Action Type example:**
```yaml
# To be added (domain: ecommerce, action_types)
- name: send_welcome_email
  description: "Send a welcome email to a newly registered user"
  target: User
  trigger: object_created
  parameters:
    - name: email_template
      type: string
```

Then prompt:

```
Proceed with adding the above? (y / n / edit)
```

- **`n`** → Output and exit:
  ```
  Cancelled.
  ```
- **`edit`** → List the editable fields with numbers:
  ```
  Select a field to edit:
    1. <field_1> (current: <value_1>)
    2. <field_2> (current: <value_2>)
    ...
  Enter a number:
  ```
  For example, for an Object Type:
  ```
  Select a field to edit:
    1. name (current: User)
    2. description (current: Service user)
    3. properties
  Enter a number:
  ```
  Re-prompt only the selected field, then return to Step 6.
- **`y`** → Proceed to Step 7.

---

### Step 7: Update YAML

#### 7-A: New domain

**Create ontology.yaml**: Use the Write tool to create `.ontology/domains/<domain_name>/ontology.yaml`.

```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types: []
link_types: []
action_types: []
```

Include `new_entry` immediately in the appropriate type array. For example, if adding an Object Type:

```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types:
  - name: <name>
    ...
link_types: []
action_types: []
```

**Update _index.yaml**: Read the current `_index.yaml`, then use the Edit tool to append a new entry to `domains: []` or to the end of the existing array.

Entry format:
```yaml
  - name: <domain_name>
    description: "<domain_description>"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>   # YYYY-MM-DD
```

If `domains: []`, replace with:
```yaml
domains:
  - name: <domain_name>
    description: "<domain_description>"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>
```

#### 7-B: Existing domain — pre-migration (`path` field present)

Target file: `.ontology/domains/<path>` (e.g. `.ontology/domains/ecommerce/ontology.yaml`)

Read the file, then use the Edit tool to append `new_entry` to the appropriate type array.

- **Object Type** → append to `object_types`
- **Link Type** → append to `link_types`
- **Action Type** → append to `action_types`

If the array is `[]` (empty): use Edit to replace that line:

```
old: "object_types: []"
new:
object_types:
  - name: <name>
    ...
```

If the array has existing items: use Edit to insert the new YAML block after the last item (just before the next top-level key).

Update the domain's `last_modified` in `_index.yaml` to today's date (Edit tool).

#### 7-C: Existing domain — post-migration (`paths` field present)

Determine the target file by type:

| Type | Field | Example path |
|------|-------|-------------|
| Object Type | `paths.object_types` | `.ontology/domains/ecommerce/object_types.yaml` |
| Link Type | `paths.link_types` | `.ontology/domains/ecommerce/link_types.yaml` |
| Action Type | `paths.action_types` | `.ontology/domains/ecommerce/action_types.yaml` |

Resolve the actual path as `.ontology/domains/<paths.<type>_types>`.

Read the file and append `new_entry` to the array (Edit tool). Apply the same empty-array / existing-items logic as 7-B.

Update the domain's `last_modified` in `_index.yaml` (Edit tool).

---

### Step 8: Global sync check

- `ask` → `"Sync to global store (<global_path>) as well? (y/n)"` → y=proceed, n=skip
- `auto` → proceed immediately
- `off` → skip

**Proceed**: Write-copy the modified domain file(s) + `_index.yaml` to `<global_path>/domains/`.
- Pre-migration: `<global_path>/domains/<domain_name>/ontology.yaml`
- Post-migration: the modified type file (one file)
- Always overwrite `<global_path>/domains/_index.yaml`

---

### Step 9: Completion message

```
✓ [<domain_name>] Added <entry_name> (<type_label>) → .ontology/domains/<domain_name>/ontology.yaml
```

`<type_label>` mapping:
- Object Type → `Object Type`
- Link Type → `Link Type`
- Action Type → `Action Type`

Output the path of the file that was actually modified (for post-migration domains, use the specific type file path).

---

## Common Mistakes

- **Asking multiple questions at once** → Always ask one question at a time and wait for a response.
- **Including `computed: false` or `primary: false`** → Omit the field entirely when the value is false. Only include it when `true`.
- **Forgetting to update `last_modified` in `_index.yaml`** → Always update it after modifying any YAML file.
- **Wrong path format for new domains** → The `path` value in `_index.yaml` must be `<domain_name>/ontology.yaml` (no leading `domains/`).
- **Skipping name format validation** → Object Type=PascalCase, Action Type=snake_case, Link Type=lowercase+underscores. Re-prompt until a valid value is entered.
