---
name: validate
description: Use when the user runs /ontologian:validate or wants to check ontology YAML schema correctness and referential integrity across all domains.
---

# Ontologian — Validate

## Overview

Validate the YAML schema and referential integrity across all domains.
Output a pass message when no errors are found, or a detailed list of errors by domain, type, and field.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and **exit immediately**.

### Step 2: Read `_index.yaml`

Use the Read tool to read `.ontology/domains/_index.yaml`.

If the `domains` array is empty or the file is missing:

```
No domains registered. Nothing to validate.
```

Output and exit.

### Step 3: Read domain files

Iterate over the `domains` array in `_index.yaml` and read each domain's type data.

**Determining migration status:**

- If `path` is present → Read the single file at `.ontology/domains/<path>`. Extract `object_types`, `link_types`, `action_types` arrays.
- If `paths` is present → Compose paths as `.ontology/domains/<paths.X>` for each of `paths.object_types`, `paths.link_types`, and `paths.action_types`. Read each file separately and extract the corresponding array.

If a domain file cannot be read, add the following to the error list and skip validation for that domain:

```
[<domain_name>] Cannot read file: <file_path>
```

For each domain, store in memory:

```
domain_data[domain_name] = {
  object_types: [...],   # empty array if absent
  link_types: [...],     # empty array if absent
  action_types: [...]    # empty array if absent
}
```

### Step 4: Schema validation

Iterate over all type items in each domain and check required fields and allowed values. Add violations to the `errors` list.

#### Object Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required. Error if absent. |
| `description` | Required. Error if absent or empty string. |

**Implementation-artifact name check:**

After validating `name` is present, check if the name ends with any of these suffixes (case-insensitive):
`DTO`, `Entity`, `Repository`, `Manager`, `Service`, `Handler`, `Base`, `Abstract`, `Util`, `Helper`, `Factory`, `Controller`

If matched, add a MAJOR warning:
```
⚠ [<domain_name>] Object Type '<name>'
  → name: '<name>' contains an implementation artifact suffix ('<suffix>').
    Object Type names must represent real-world entities, not code constructs.
    Rename to the entity it represents (e.g. OrderDTO → Order, UserManager → remove).
```

If a `properties` array exists, validate each property:

| Field | Rule |
|-------|------|
| `name` | Required |
| `type` | Required. Allowed values: `string`, `int`, `float`, `boolean`, `date`, `datetime`. `integer` is accepted as an alias for `int` (not an error). |
| `description` | Optional. If absent, emit a warning (not an error): `[ObjectType.property] No description. Adding one helps preserve field intent.` |
| `computed` | Optional. If `true`, check for `expression`. If absent, emit a warning: `Computed property '<name>' has no expression.` |

**Property type heuristic checks (add as MAJOR warnings):**

After validating required fields, apply these name-pattern checks:

| Property name pattern | Expected type | Warning if type is |
|----------------------|---------------|--------------------|
| ends with `_at`, `_date`, `_time`, `_on` | `date` or `datetime` | `string`, `int`, `float`, `boolean` |
| starts with `is_`, `has_`, `can_`, `was_` | `boolean` | `string`, `int`, `float` |
| ends with `_count`, `_qty`, `_quantity`, `_amount`, `_total`, `_price`, `_cost`, `_fee` | `int` or `float` | `string`, `boolean` |

Warning format:
```
⚠ [<domain_name>] Object Type '<name>' > property '<prop_name>'
  → type: '<prop_name>' suggests <expected_type> but is declared as '<actual_type>'.
    Change to <expected_type> if this field holds a real <date/boolean/numeric> value.
```

**Enum documentation check (status-pattern fields — add as MAJOR warnings):**

For each property where:
- `type` is `string` AND
- `name` exactly matches any of: `status`, `state`, `type`, `kind`, `mode`, `stage`, `phase`, `category`, `level`
  OR `name` ends with `_status`, `_state`, `_type` (case-insensitive, e.g. `order_status`, `account_type`)

Check if `description` contains the substring `"Allowed values:"`. If not, add a MAJOR warning:
```
⚠ [<domain_name>] Object Type '<name>' > property '<prop_name>'
  → description: status-pattern field missing allowed values documentation.
    Add 'Allowed values: X, Y, Z' to the description (e.g. "Allowed values: pending, active, cancelled").
```

#### Link Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required |
| `from` | Required |
| `to` | Required |
| `cardinality` | Required. Allowed values: `one_to_one`, `one_to_many`, `many_to_many`, `many_to_one` |

**Link Type missing `description` (SUGGESTION):**

If a Link Type has no `description` field (absent or empty string), add a SUGGESTION warning:
```
⚠ [<domain_name>] Link Type '<name>'
  → description: not set. Adding a description clarifies the relationship's intent and directionality.
    Example: "A User places an Order" or "An Order contains one or more Products"
```

**`many_to_many` cardinality advisory (SUGGESTION):**

If `cardinality` is `many_to_many`, add a SUGGESTION warning:
```
⚠ [<domain_name>] Link Type '<name>' (<from> → <to>)
  → cardinality: many_to_many links often indicate a missing intermediate Object Type.
    If the relationship has its own attributes (e.g. created_at, status) or instances need
    to be queried independently, consider introducing an intermediate Object Type.
    Example: User --[enrolls]--> Course → User --[initiates]--> Enrollment --[covers]--> Course
    If this is a simple tag/classification relationship with no relationship-level attributes, many_to_many is acceptable.
```

#### Action Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required |
| `description` | Required. Error if absent or empty string. |
| `trigger` | Required. Allowed values: `object_created`, `object_updated`, `object_deleted`, `manual` |
| `target` | Required |

**`manual` trigger with no parameters (MAJOR warning):**

If `trigger` is `manual` and `parameters` is absent or an empty array, add a MAJOR warning:
```
⚠ [<domain_name>] Action Type '<name>'
  → trigger: manual actions should declare at least one parameter to document required inputs.
    If this action truly takes no inputs, add parameters: [] explicitly with a comment in description.
    Example parameters: approval_reason (string), override_flag (boolean)
```

**`object_updated` without `trigger_condition` check:**

If `trigger` is `object_updated` and no `trigger_condition` block is present, add a MAJOR warning:
```
⚠ [<domain_name>] Action Type '<name>'
  → trigger: object_updated without trigger_condition fires on every property change.
    Add a trigger_condition.field to specify which field change should trigger this action.
    If all-property firing is intentional (e.g. audit logging), add trigger_condition: { field: "*" } to document intent.
```

**`trigger_condition` validation (optional field):**

If `trigger_condition` exists:
- Only allowed when `trigger` is `object_updated`. If another trigger value is present, add an error:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition: not allowed when trigger is '<trigger_value>'. Only valid with object_updated.
  ```
- `field` is required. If absent, add an error:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition.field: required field missing.
  ```
- `from` and `to` are optional. Having only `field` is valid — it means "fire on any change to this field".
  If `from` is provided but `field` is absent, the error above covers it. Never require `from`/`to`.

If a `parameters` array exists, validate each parameter:

| Field | Rule |
|-------|------|
| `name` | Required |
| `type` | Required. Allowed values: `string`, `int`, `float`, `boolean`, `date`, `datetime` |

**Parameter with no `name`**: Record as a schema error and skip further validation for that parameter.

**Error message format:**

```
[<domain_name>] <Type Kind> '<name>'
  → <field>: <error description>
```

Examples:

```
[ecommerce] Object Type 'Product'
  → description: required field missing.

[ecommerce] Object Type 'Product' > property 'price'
  → type: invalid value 'number'. (Allowed: string, int, float, boolean, date, datetime)

[ecommerce] Link Type 'places'
  → cardinality: invalid value 'one_to_few'. (Allowed: one_to_one, one_to_many, many_to_many, many_to_one)

[ecommerce] Action Type 'send_welcome_email'
  → trigger: invalid value 'on_create'. (Allowed: object_created, object_updated, object_deleted, manual)

[ecommerce] Action Type 'send_email' > parameter 'index 0': name field missing
```

Warning examples:

```
⚠ [ecommerce] Object Type 'Product' > property 'price': No description. Adding one helps preserve field intent.
⚠ [ecommerce] Object Type 'User' > property 'status': No description. Adding one helps preserve field intent.
```

### Step 5: Referential integrity validation

For each domain, first collect the list of Object Type names (`object_names`) within that domain.

**Cross-domain reference policy:** `from`, `to`, and `target` fields may only reference Object Types within the same domain. References to types in other domains are treated as errors.

#### Link Type reference validation

Check whether each Link Type's `from` and `to` values exist in `object_names` for the same domain.

If not found, add an error:

```
[<domain_name>] Link Type '<link_name>'
  → from: '<value>' does not exist as an Object Type.

[<domain_name>] Link Type '<link_name>'
  → to: '<value>' does not exist as an Object Type.
```

#### Action Type reference validation

Check whether each Action Type's `target` value exists in `object_names` for the same domain.

If not found, add an error:

```
[<domain_name>] Action Type '<action_name>'
  → target: '<value>' does not exist as an Object Type.
```

If `trigger_condition` exists and `field` is set, verify that the `field` exists as a property of the `target` Object Type.

If not found, add an error:

```
[<domain_name>] Action Type '<action_name>'
  → trigger_condition.field: '<field_value>' does not exist as a property of target '<target_name>'.
```

### Step 5b: Governance metadata validation

For each domain entry in `_index.yaml`, check for governance metadata:

| Field | Severity if missing | Warning text |
|-------|--------------------|--------------------------------------------|
| `domain_owner` | MAJOR | `Domain '<name>' has no domain_owner. Add domain_owner: <team-name> to the _index.yaml entry.` |
| `stability` | MAJOR | `Domain '<name>' has no stability. Add stability: stable\|experimental\|deprecated to the _index.yaml entry.` |
| `semantic_version` | MINOR | `Domain '<name>' has no semantic_version. Add semantic_version: 1.0.0 to the _index.yaml entry.` |

Allowed values for `stability`: `stable`, `experimental`, `deprecated`. If set to another value, add an error:
```
[<domain_name>] _index.yaml
  → stability: invalid value '<value>'. Allowed: stable, experimental, deprecated.
```

Emit all governance metadata issues as warnings (⚠), not errors. Include them in the warnings list.

### Step 5a: Stale-file check after migration

For each domain entry in `_index.yaml` that uses a `paths` field (post-migration domain):
- Derive the expected legacy path: replace the `paths.object_types` value's filename with `ontology.yaml`.
  Example: `paths.object_types = ecommerce/object_types.yaml` → legacy path = `ecommerce/ontology.yaml`
- Use Glob to check if `.ontology/domains/<legacy_path>` exists.
- If it does, add a MINOR warning:
  ```
  ⚠ [<domain_name>] Stale pre-migration file detected:
    .ontology/domains/<legacy_path>
    This file is no longer used (domain is now reading from paths.*).
    Delete it to prevent confusion:
      rm .ontology/domains/<legacy_path>
    Or run /ontologian:migrate and choose to delete it interactively.
  ```

### Step 5-C: Circular trigger detection

After collecting all action types across all domains, perform a single-hop circular trigger check:

Build a list of all `object_created` actions: `{ domain, action_name, target }`.

For each pair of `object_created` actions (A, B) in the **same domain** where A ≠ B:
- If `A.target == B.target`, these two actions both fire when the same Object Type is created.
- This is a potential infinite loop if either action creates another instance of the same type as its side effect.
- Add a MAJOR warning for each such pair:
  ```
  ⚠ [<domain_name>] Action Types '<A.action_name>' and '<B.action_name>'
    → Both use trigger: object_created with the same target '<target>'.
      If either action creates a new '<target>' instance, this will cause an infinite trigger loop.
      Review each action's side effects to confirm no '<target>' instance is created as a result.
      If intentional, document this explicitly in both actions' descriptions.
  ```

**Verification:** Two actions in the same domain both with `trigger: object_created` and `target: User` → both are flagged in the same warning.

### Step 6: Duplicate name validation

Within each domain, check for duplicate names within each type category:

- Duplicates in `object_types[].name`
- Duplicates in `link_types[].name`
- Duplicates in `action_types[].name`

If duplicates found, add an error:

```
[<domain_name>] Duplicate Object Type name: '<name>'
[<domain_name>] Duplicate Link Type name: '<name>'
[<domain_name>] Duplicate Action Type name: '<name>'
```

### Step 7: Output results

**No errors and no warnings:**

```
✓ All domains passed validation (<N> domains, <N> Objects, <N> Links, <N> Actions)
[i] Tip: Run /ontologian:visualize to render relationship diagrams, or /ontologian:sync to push to the global store.
```

**No errors but warnings exist:**

```
✓ Validation passed — <W> recommendation(s)

⚠ <warning1>
⚠ <warning2>
...
```

`N` is the total count across all domains.

**One or more errors:**

```
✗ Validation failed — <N> error(s) found

<error1>

<error2>

...
```

If warnings also exist, append them after the error list:

```
⚠ Recommendations (<W>)
⚠ <warning1>
⚠ <warning2>
...
```

Output errors in the order they were collected. Add a blank line between each error item.

---

## Common Mistakes

- **Missing array key** → If `object_types`, `link_types`, or `action_types` is absent, treat it as an empty array.
- **Skipping referential validation for items with no name** → Items missing a `name` field should be recorded as schema errors and excluded from referential checks.
- **Error count mismatch** → The `N error(s) found` header must exactly match the number of items in the `errors` list.
- **Wrong totals in pass message** → Objects/Links/Actions counts must be summed across all domains (not per-domain).
- **Mixing warnings and errors** → Missing property descriptions are `warnings`, not `errors`. Do not include them in the error count.
