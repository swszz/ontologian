---
name: ontologian:validate
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

If a `properties` array exists, validate each property:

| Field | Rule |
|-------|------|
| `name` | Required |
| `type` | Required. Allowed values: `string`, `int`, `float`, `boolean`, `date`, `datetime`. `integer` is accepted as an alias for `int` (not an error). |
| `description` | Optional. If absent, emit a warning (not an error): `[ObjectType.property] No description. Adding one helps preserve field intent.` |
| `computed` | Optional. If `true`, check for `expression`. If absent, emit a warning: `Computed property '<name>' has no expression.` |

#### Link Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required |
| `from` | Required |
| `to` | Required |
| `cardinality` | Required. Allowed values: `one_to_one`, `one_to_many`, `many_to_many`, `many_to_one` |

#### Action Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required |
| `description` | Required. Error if absent or empty string. |
| `trigger` | Required. Allowed values: `object_created`, `object_updated`, `object_deleted`, `manual` |
| `target` | Required |

**`trigger_condition` validation (optional field):**

If `trigger_condition` exists:
- Only allowed when `trigger` is `object_updated`. If another trigger value is present, add an error:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition: not allowed when trigger is '<trigger_value>'. Only valid with object_updated.
  ```
- Required sub-fields: `field`, `from`, and `to` must all be present. If any is missing, add an error:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition.<field_name>: required field missing. (field, from, to are all required)
  ```

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
