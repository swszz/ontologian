---
name: ontologian-validate
description: Use when the user runs /ontologian-validate or wants to check ontology YAML schema correctness and referential integrity across all domains.
---

# Ontologian — Validate

## Overview

Validate the YAML schema and referential integrity across all domains.
Output a pass message when no errors are found, or a detailed list of errors by domain, type, and field.

---

## Steps

### Step 1: Initialization check

Glob `ontology/domains/_index.yaml` → if missing, output `"Ontology is not initialized."` and **exit immediately**.

### Step 1-B: Parse arguments

If arguments were provided, parse them to set an optional domain filter:

- If a domain name is provided (e.g. `/ontologian-validate ecommerce`), store it as `domain_filter`.
- In Steps 3–6, skip any domain whose `name` does not match `domain_filter`.
- If no arguments are provided, validate all domains (no filter applied).

---

### Step 2: Read `_index.yaml`

Use the Read tool to read `ontology/domains/_index.yaml`.

If the `domains` array is empty or the file is missing:

```
No domains registered. Nothing to validate.
```

Output and exit.

### Step 3: Read domain files

Iterate over the `domains` array in `_index.yaml` and read each domain's type data.

All domains use the `directory` format:
- Glob `ontology/domains/<directory>/objects/*.md` → read each → collect into `object_types[]`
- Glob `ontology/domains/<directory>/links/*.md` → read each → collect into `link_types[]`
- Glob `ontology/domains/<directory>/actions/*.md` → read each → collect into `action_types[]`
Each file is a single entity definition with no wrapper key.

If a domain file cannot be read, add the following to the error list and skip validation for that domain:

```
[<domain_name>] Cannot read file: <file_path>
```

For `directory`-format domains: if a subdirectory is missing or empty, treat the corresponding array as `[]`.

For each domain, store in memory:

```
domain_data[domain_name] = {
  object_types: [...],   # empty array if absent
  link_types: [...],     # empty array if absent
  action_types: [...]    # empty array if absent
}
```

### Step 3-B: Markdown file parsing rule

Each entity file is a `.md` file with YAML frontmatter. Parse only the frontmatter (content between the first and second `---` delimiters) as YAML.

**Wiki link field extraction:** The `from`, `to`, and `target` fields may contain either a plain Object Type name or a full-path Obsidian wiki link:
- Plain: `from: Shipment`
- Wiki link: `from: "[[ontology/domains/logistics/objects/Shipment|Shipment]]"`

When reading these fields, extract the Object Type name as follows:
- If the value matches `[[<path>|<Name>]]` → use `<Name>` as the type name, `<path>` as the file path
- If the value matches `[[<Name>]]` → use `<Name>` as both
- If the value is a plain string → use it directly

Store both the extracted name and the full wiki link string (if present) for use in validation steps.

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

If matched, add a WARNING:
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
| `description` | Optional. If absent, emit a **[HINT]**: `[ObjectType.property] No description. Adding one helps preserve field intent.` |
| `computed` | Optional. If `true`, check for `expression`. If absent, emit a **[HINT]**: `Computed property '<name>' has no expression.` |

**Property type heuristic checks (add as WARNINGs):**

After validating required fields, apply these name-pattern checks:

| Property name pattern | Expected type | Warning if type is |
|----------------------|---------------|--------------------|
| ends with `_at`, `_date`, `_time`, `_on` | `date` or `datetime` | `string`, `int`, `float`, `boolean` |
| starts with `is_`, `has_`, `can_`, `was_` | `boolean` | `string`, `int`, `float` |
| ends with `_count`, `_qty`, `_quantity`, `_amount`, `_total`, `_price`, `_cost`, `_fee` | `int` or `float` | `string`, `boolean` |

Warning format:
```
⚠ [<domain_name>] Object Type '<name>' > property '<prop_name>'
  → type: '<actual_type>' — name pattern suggests <expected_type> but is declared as '<actual_type>'.
    Change to <expected_type> if this field holds a real <date/boolean/numeric> value.
```

**Enum documentation check (status-pattern fields — add as WARNINGs):**

For each property where:
- `type` is `string` AND
- `name` exactly matches any of: `status`, `state`, `type`, `kind`, `mode`, `stage`, `phase`, `category`, `level`
  OR `name` ends with `_status`, `_state`, `_type`, `_kind`, `_mode`, `_stage`, `_phase`, `_category`, `_level` (case-insensitive, e.g. `order_status`, `account_type`, `delivery_stage`)

Check if `description` contains the substring `"Allowed values:"`. If not, add a WARNING:
```
⚠ [<domain_name>] Object Type '<name>' > property '<prop_name>'
  → description: status-pattern field missing allowed values documentation.
    Add 'Allowed values: X, Y, Z' to the description (e.g. "Allowed values: pending, active, cancelled").
```

**Empty properties check (add as WARNING):**

If `properties` is absent or an empty array, add a WARNING:
```
⚠ [<domain_name>] Object Type '<name>'
  → properties: no properties defined. Object Types should declare at least one property
    (typically an identifier). Add properties or verify this is intentional.
```

**Primary key completeness check (add as WARNING / error):**

After validating all properties of an Object Type (skip if `properties` is absent or an empty array — covered by the empty properties check above):

- Count properties where `primary: true`. Call this `pk_count`.
- If `pk_count == 0`: add a WARNING:
  ```
  ⚠ [<domain_name>] Object Type '<name>'
    → properties: no primary key defined. Add primary: true to the identifier property
      (e.g. user_id, order_id) so instances can be uniquely resolved.
  ```
- If `pk_count > 1`: add an error:
  ```
  [<domain_name>] Object Type '<name>'
    → properties: <pk_count> properties marked primary: true. Exactly one primary key is allowed.
      Remove primary: true from all but the identifier property.
  ```

#### Link Type validation

For each item:

| Field | Rule |
|-------|------|
| `name` | Required |
| `from` | Required |
| `to` | Required |
| `cardinality` | Required. Allowed values: `one_to_one`, `one_to_many`, `many_to_many`, `many_to_one` |

**Link Type missing `description` (WARNING):**

If a Link Type has no `description` field (absent or empty string), add a WARNING:
```
⚠ [<domain_name>] Link Type '<name>'
  → description: not set. Every type must have a description for discoverability (Palantir Principle 6).
    Example: "A User places an Order" or "An Order contains one or more Products"
```

**`many_to_many` cardinality advisory (HINT):**

If `cardinality` is `many_to_many`, add a HINT:
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

**`manual` trigger with no parameters (WARNING):**

If `trigger` is `manual` and `parameters` is absent or an empty array, add a WARNING:
```
⚠ [<domain_name>] Action Type '<name>'
  → trigger: manual actions should declare at least one parameter to document required inputs.
    If this action truly takes no inputs, document that explicitly in the action's description field.
    Example parameters: approval_reason (string), override_flag (boolean)
```

**`object_updated` without `trigger_condition` check:**

If `trigger` is `object_updated` and no `trigger_condition` block is present, add a WARNING:
```
⚠ [<domain_name>] Action Type '<name>'
  → trigger: object_updated without trigger_condition fires on every property change.
    Add a trigger_condition.field to specify which field change should trigger this action.
    If all-property firing is intentional (e.g. audit logging), document this in the action's `description` field instead of using a wildcard field value.
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
| `required` | Optional. If present, allowed values: `true`, `false`. Any other value is an error. |

**Parameter with no `name`**: Record as a schema error and skip further validation for that parameter.

If `required` is present with an invalid value, add an error:
```
[<domain_name>] Action Type '<name>' > parameter '<param_name>'
  → required: invalid value '<value>'. Allowed: true, false. Omit this field when the parameter is required (true is the default).
```

#### Cross-domain wiki link validation

After validating all Link Types and Action Types, perform a cross-domain wiki link integrity check.

For each Link Type, check the `from` and `to` fields. For each Action Type, check the `target` field. Apply the following checks only when the field value is a wiki link (matched in Step 3-B); skip plain string values here (they are handled by referential integrity in Step 5).

For each wiki link value found in `from`, `to`, or `target`:

1. **Validate the link format.** The value must match:
   ```
   [[ontology/domains/<directory>/objects/<Name>|<Name>]]
   ```
   If it does **not** match this pattern, add an error:
   ```
   [<domain_name>] <Type Kind> '<name>'
     → <field>: '<value>' is not a valid full-path Obsidian wiki link.
       Expected format: [[ontology/domains/<directory>/objects/<Name>|<Name>]]
   ```

2. **Check that the referenced file exists.** Glob `ontology/domains/<directory>/objects/<Name>.md`. If the file does not exist, add an error:
   ```
   [<domain_name>] <Type Kind> '<name>'
     → <field>: "[[ontology/domains/<directory>/objects/<Name>|<Name>]]" — file not found.
       Verify the Object Type name and domain directory are correct.
   ```

3. **Check cross-domain dependency declaration.** If `<directory>` differs from the current domain's `directory`:
   - Look up the current domain's entry in `_index.yaml` and read its `dependency_direction` list.
   - If the referenced domain's **name** is not present in `dependency_direction`, add an error:
     ```
     [<domain_name>] <Type Kind> '<name>'
       → <field>: cross-domain reference to '<Name>' in domain '<referenced_domain>' is not declared.
         Add '<referenced_domain>' to dependency_direction in _index.yaml for domain '<domain_name>'.
     ```

**Error message format:**

```
[<domain_name>] <Type Kind> '<name>'
  → <field>: <error description>
```

**For `directory`-format domains, render entity names as file links in error messages:**

```
[<domain_name>] [<TypeName>](ontology/domains/<directory>/<subdir>/<filename>.md): <error_message>
```

Where:
- Object Types → `objects/<Name>.md`
- Link Types → `links/<name>.md`
- Action Types → `actions/<name>.md`

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

**Cross-domain reference policy:**

For each Link Type `from`/`to` and Action Type `target`, first check whether the referenced Object Type name exists in the current domain's type list.

If not found in the current domain, check all other registered domains:
- If the type is found in another domain (`<other_domain>`):
  - **If the current domain's `_index.yaml` entry declares `dependency_direction` that includes `<other_domain>`**: emit a WARNING (not an error):
    ```
    ⚠ [<domain_name>] <TypeKind> '<name>'
      → <field>: '<value>' is defined in domain '<other_domain>', not '<domain_name>'.
        This cross-domain reference is declared via dependency_direction and is intentional.
        Consider using a reference ID property instead of a direct link for better decoupling.
    ```
  - **If the current domain does NOT declare `dependency_direction` including `<other_domain>`**: emit an error:
    ```
    [<domain_name>] <TypeKind> '<name>'
      → <field>: '<value>' does not exist in domain '<domain_name>' and no dependency_direction
        to '<other_domain>' is declared.
        Either add '<value>' to '<domain_name>', declare dependency_direction: ['<other_domain>']
        in _index.yaml, or use a reference ID property.
    ```
- If the type is not found in any registered domain: emit an error (unknown type).

#### Link Type reference validation

Check whether each Link Type's `from` and `to` values exist in `object_names` for the same domain. Apply the cross-domain reference policy above if not found in the current domain.

#### Action Type reference validation

Check whether each Action Type's `target` value exists in `object_names` for the same domain. Apply the cross-domain reference policy above if not found in the current domain.

If `trigger_condition` exists and `field` is set, verify that the `field` exists as a property of the `target` Object Type.

If not found, add an error:

```
[<domain_name>] Action Type '<action_name>'
  → trigger_condition.field: '<field_value>' does not exist as a property of target '<target_name>'.
```

- If `field` is set to `"*"`, `"any"`, or any other wildcard/placeholder value, add an error:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition.field: wildcard value '<value>' is not a valid property name.
      Specify the exact property name to watch, or remove trigger_condition entirely to
      document intentional all-property firing in the action's description field.
  ```

### Step 5b: Governance metadata validation

For each domain entry in `_index.yaml`, check for governance metadata:

| Field | Severity if missing | Warning text |
|-------|--------------------|--------------------------------------------|
| `domain_owner` | WARNING | `Domain '<name>' has no domain_owner. Add domain_owner: <team-name> to the _index.yaml entry.` |
| `stability` | WARNING | `Domain '<name>' has no stability. Add stability: stable\|experimental\|deprecated to the _index.yaml entry.` |
| `semantic_version` | HINT | `Domain '<name>' has no semantic_version. Add semantic_version: 1.0.0 to the _index.yaml entry.` |
| `dependency_direction` | — | Optional field. No warning if absent. Validated separately below. |

Allowed values for `stability`: `stable`, `experimental`, `deprecated`. If set to another value, add an error:
```
[<domain_name>] _index.yaml
  → stability: invalid value '<value>'. Allowed: stable, experimental, deprecated.
```

Emit all governance metadata issues as warnings (⚠), not errors. Include them in the warnings list.

**`dependency_direction` domain existence check:**

If a domain entry declares `dependency_direction: [<name1>, <name2>, ...]`, verify that each referenced name appears in the `domains` array of `_index.yaml`. If a referenced domain is not found, emit a WARNING:
```
⚠ [<domain_name>] _index.yaml
  → dependency_direction: '<ref_name>' does not match any registered domain.
    Registered domains: <list>. Check for typos or missing domain registration.
```

### Step 5-C: Circular trigger detection

After collecting all action types across all domains, perform a single-hop circular trigger check:

Build a list of all `object_created` actions: `{ domain, action_name, target }`.

For each pair of `object_created` actions (A, B) in the **same domain** where A ≠ B:
- If `A.target == B.target`, these two actions both fire when the same Object Type is created.
- This is a potential infinite loop if either action creates another instance of the same type as its side effect.
- Add a WARNING for each such pair:
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
[i] Tip: Run /ontologian-visualize to render relationship diagrams, or /ontologian-sync to push to the global store.
```

**No errors but warnings exist:**

Count warnings by severity before rendering:
- WARNING: governance issues (missing domain_owner, stability, etc.), implementation artifact names, missing primary keys, type heuristic mismatches, trigger_condition issues, missing Link description
- HINT: many_to_many advisories, computed property without expression, missing property descriptions

```
✓ Validation passed — <W> warning(s), <H> hint(s)

⚠ <warning1>
⚠ <warning2>
...
```

If there are zero warnings, omit the warning count and render as:
```
✓ Validation passed — <H> hint(s)
```

If there are zero hints (only warnings):
```
✓ Validation passed — <W> warning(s)
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
