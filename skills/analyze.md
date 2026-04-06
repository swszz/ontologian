---
name: analyze
description: Use when the user runs /ontologian:analyze or wants to derive an ontology structure from free-form business requirements text.
---

# Ontologian — Analyze

## Overview

Accept free-form business requirements text and automatically derive an ontology structure (Object Types, Link Types, Action Types). Query the user only for low-confidence items to complete the ontology with minimal intervention.

**Core principles:**
- confidence:high → auto-accept. Only query confidence:low items.
- Ask only one question at a time. Never bundle multiple questions together.
- Show all analysis results first, then begin querying.

---

## Steps

### Step 1: Initialization check

Glob `.ontology/config.yaml`:
- **If missing**: `"The ontology repository is not initialized. Initialize it now? (y/n)"` → `n`=exit, `y`=Write the following two files and continue:
  - `.ontology/config.yaml`: `version: 1 / global_sync: ask / global_path: ~/.ontologian`
  - `.ontology/domains/_index.yaml`: `domains: []`
- **If present**: Read it and store `global_sync`, `global_path` (defaults: `ask`, `~/.ontologian`)

---

### Step 2: Collect requirements

If arguments are provided, use them. Otherwise prompt:

```
Describe your business requirements in free form.
(e.g. "A user adds products to a cart, places an order, which reduces inventory and creates a shipment.")

Requirements:
```

Store the input as `requirements_text`.

---

### Step 3: Load existing ontology

Read `.ontology/domains/_index.yaml`. Iterate over the `domains` array and Read each domain file.

**Branch on path/paths:**
- If `path` is present → Read `.ontology/domains/<path>`
- If `paths` is present → Read `.ontology/domains/<paths.object_types>`, `<paths.link_types>`, `<paths.action_types>` separately

Store in `existing_ontology`:
```
{ domains: [{ name, object_types: [names], link_types: [names], action_types: [names] }] }
```
If no domains or files are empty, use `{ domains: [] }` and continue.

---

### Step 4: Initial analysis — derive candidates

Analyze `requirements_text`. **This step is Claude's autonomous analysis. Do not ask the user any questions.**

**Initialize internal state at the start of Step 4:**
```
candidate_objects: []   # {name, description, properties[], confidence}
candidate_links: []     # {name, from, to, cardinality, confidence}
candidate_actions: []   # {name, description, trigger, target, parameters[], confidence}
uncertain_items: []
```

#### 4-A: Extract Object Type candidates

**Input**: `requirements_text`
**Output**: `candidate_objects[]`
**Immediate validation**: Ensure all properties have a `type` (default to `string` if missing).

Extraction criteria:
- Nouns acting as subjects/objects, entities that are created/read/updated/deleted, concepts with an independent set of attributes.
- Exclude: simple quantities or state values ("inventory count" → count is a property; inventory is the entity).
- **Type classification vs. independent Object**: If an Object's `type`/`account_type` enum values map one-to-one to other Object Types in the same domain, that is duplicate modeling.
  - Example: If `Account.account_type = fixed_deposit` exists alongside a `FixedDeposit` Object, only keep `FixedDeposit` separate if it has a distinct lifecycle and unique attributes.
  - Split criteria: If the two candidates have distinct attribute sets and different Actions/Links, keep them separate (confidence:high). If one's attributes and behavior are a subset of the parent type's, add as `concept_split` in `uncertain_items`.

Infer for each candidate:
- `name`: PascalCase (e.g. "user" → `User`, "shopping cart" → `Cart`)
- `description`: role description
- `properties`: inferred attributes
  - `type` inference: email→`string`, count→`int`, amount→`float`, date→`datetime`
  - Identifier attributes → `primary: true`
  - **Property description**: If the requirements convey meaning or context for a field, write it in one sentence in `description`. Omit if not inferrable.
    - **Status properties** (status, state, type, etc.): If allowed values are clear, write them as `"Allowed values: X, Y, Z"` in `description`. If unclear, add `missing_enum_values` to `uncertain_items`.
    - **Computed properties**: Describe the expression meaning in one sentence in `description` (e.g. `"Sum of gross_amount across settlement_items"`).
    - **General properties**: Omit if the name is self-explanatory; include if there is domain-specific context.
  - Derived values → `computed: true`. If the expression is clear, infer `expression`. If not, add `missing_computed_expression` to `uncertain_items`.
  - **No FK properties**: Do not include foreign key attributes referencing other Object Types (e.g. merchant_id, order_id). Express relationships as Link Types in 4-B.
- `confidence`: `high` / `low`

**Confidence examples:**
```
confidence: high  →  "A user places an order" → User, Order (clear nouns, clear roles)
                     "inventory count decreases" → Inventory(object), quantity(property) — clear
confidence: low   →  "add to cart" → unclear if Cart is a separate Object or Order.status
                     Korean-only term where PascalCase mapping is ambiguous
```

#### 4-B: Extract Link Type candidates

**Input**: `requirements_text`, `candidate_objects` (from 4-A)
**Output**: `candidate_links[]`
**Immediate validation**: Check that `from` and `to` values exist in `candidate_objects`. If not, add as `action_target_unclear` in `uncertain_items`.

Extraction criteria:
- "A does something to B" verb relationships, "B belongs to A" containment relationships.
- Do not create the same relationship in both directions.
- If a direct A→C link is added when an A→B→C path already exists, add as `concept_split` in `uncertain_items` for user confirmation.
- **Avoid skipping intermediate Objects**: If the requirements don't explicitly say "A directly uses C" and an A→B→C path exists, do not create a direct A→C link. (e.g. Vehicle→Package might be better expressed as Vehicle→DeliveryOrder→Package.)

Infer for each candidate:
- `name`: snake_case **pure verb form** — do not include the target noun in the name.
  - ✓ `places`, `contains`, `writes`, `earns`, `attends`, `paid_with`, `belongs_to`, `works_at`
  - ✗ `places_order`, `reviews_course`, `earns_certificate` (verb+noun form — not allowed)
  - ✗ `granted`, `notified_by`, `assigned_to`, `based_on`, `filled_from` — past participle adjectives, passive voice, and prepositional phrases are not allowed. Convert to active present-tense verbs:
    - `granted` → `grants` (Application grants JobOffer)
    - `notified_by` → `generates` (Application generates DecisionNotification)
    - `assigned_to` → `handles` or `treats` (active verb from the actor's perspective)
    - `based_on` → `follows` (a prescription follows an appointment) or reconsider direction
    - `filled_from` → reconsider direction as `fulfills` (Prescription → Medication one_to_many)
  - Choose a verb that represents the action of `from` toward `to`.
  - Reference direction links (from references to): forms like `belongs_to`, `works_at` (verb+preposition) are allowed. Passive voice (`assigned_to`) and pure prepositional phrases (`based_on`, `filled_from`) are not allowed. Avoid overly generic names like `references`.
  - **`_by` pattern allowed when**: `sent_by`, `written_by`, `reported_by` — use `<past_participle>_by` to express ownership or origin ("from was created/sent by to"). Prefer reversing the direction (to→from active verb) if that reads more naturally.
  - **Two links from same source to same target (role distinction needed)**: Choose two distinct verbs that each convey a different role. The `as_<role>` prefix is a noun — not allowed. Find a verb pair that differentiates the roles:
    - Follow→User two roles: "User who initiated" → `initiated_by` / "User it is directed at" → `directed_at`
    - Message→User two roles: "User who sent" → `sent_by` / "User who received" → `received_by`
  - ✓ `initiated_by`, `directed_at` (distinguishing two Follow→User roles)
  - ✓ `sent_by`, `received_by` (distinguishing two Message→User roles)
  - ✗ `as_follower`, `as_followee` (noun prefix — not a verb)
- `from`/`to`: **Direction principle** — prefer "owner/parent → owned/child" direction.
  - When `many_to_one` is derived and parent-child is clear, consider reversing to `one_to_many`.
    (e.g. "transactions belong to a settlement" → `Settlement → Transaction (one_to_many)`)
  - **Exception — Reference relationships**: If one side references the other's ID, preserve the semantic reference direction. Do not force reversal.
    - Candidates for reversal: "A aggregates into / belongs to B" (e.g. `Settlement → Transaction (one_to_many)`)
    - Keep direction: "A actively references / selects B" (e.g. `Application → JobPosting`, `Enrollment → Course`)
    - **Distinction criterion**: If B can exist independently of A → reference (keep direction). If A is part of B → membership (consider reversal).
  - `one_to_one`: prefer semantic reference direction; do not force reversal.
- `cardinality` inference:
  - "one X has many Y" → `one_to_many`
  - "many X, many Y" → `many_to_many`
  - "one X, one Y" → `one_to_one`
  - "many X for one Y" → `one_to_many` (reversed direction)
  - If unclear → `confidence: low`
- **`many_to_many` direct link vs. intermediate Object**:
  - If the relationship itself has independent attributes (created_at, reason, status) or relationship instances need to be queried/deleted individually → **create an intermediate Object** (e.g. `Like`, `Follow`, `Enrollment`)
  - If it's simple classification/tagging with no relationship-level attributes → **`many_to_many` direct link** is acceptable (e.g. `Post → Hashtag`)
  - If an intermediate Object is created, express it as two `many_to_one` links from that Object to each side. Do not create the original `many_to_many` link.
- `confidence`: `high` / `low`

#### 4-C: Extract Action Type candidates

**Input**: `requirements_text`, `candidate_objects` (from 4-A)
**Output**: `candidate_actions[]`
**Immediate validation**: Check that `target` values exist in `candidate_objects`. If not, add as `action_target_unclear` in `uncertain_items`.

Extraction criteria:
- Actions the system performs ("sends", "creates", "processes")
- Operations that execute automatically when an event occurs
- Tasks that users trigger manually

Infer for each candidate:
- `name`: snake_case (e.g. `send_order_confirmation`, `reduce_stock`)
- `description`: purpose of the action
- `target`: **interpretation depends on trigger type**
  - `object_created` → the newly created Object Type
  - `object_updated` → **the Object Type whose field change is being detected** (the owner of `trigger_condition.field`). Not the Object created as a side effect.
    - ✓ "interview scheduled when application passes document review" → `target: Application` (status field owner); Interview creation is a side effect
    - ✓ "onboarding starts when job offer is accepted" → `target: JobOffer` (status field owner); OnboardingProcess creation is a side effect
    - ✗ `target: Interview` + `trigger_condition.field: status` — invalid if Interview has no status property
  - `manual` → the Object Type the action directly creates or modifies
- `trigger`:
  - On new entity creation → `object_created`
  - On entity update → `object_updated`
  - **Phrases like "when confirmed", "when completed", "when approved", "when cancelled"** → infer as `object_updated` + always add `ambiguous_trigger_condition` to `uncertain_items`
  - If condition is unclear or manually triggered → `manual`
- `trigger_condition`: when `trigger` is `object_updated` and the condition is clear:
  ```
  field: <field being watched>
  from: <value before change>
  to: <value after change>
  ```
  If field/from/to is unclear, add `ambiguous_trigger_condition` to `uncertain_items`.
  - **⚠️ Multiple outcome conditions (e.g. "notify when approved OR rejected")**: The `to` field in a single `trigger_condition` accepts only one value. For two target states, either omit `to` and specify only `from` (fires on any change away from that state), or split into two separate actions. Always mark as `ambiguous_trigger_condition` for user confirmation.
  - **⚠️ Threshold / comparison conditions (e.g. "when N or more times")**: Comparison conditions with no single concrete value cannot be expressed in `trigger_condition`. Simplify to `trigger: manual`, or add a boolean flag property (e.g. `is_flagged: boolean`) to the Object and trigger on `false→true`. Never write comparison expressions as `to` values (e.g. `"threshold_exceeded"`).
  - **⚠️ Never use wildcard placeholders** like `"any"`, `"*"`, or `"all values"`. If a specific value is unknown, omit the field or mark as `ambiguous_trigger_condition`.
  - **⚠️ trigger_condition constraint (object_updated)**: `trigger_condition.field` must be a property of the `target` Object.
  - **⚠️ Minimal trigger_condition**: Having only `field` with no `from`/`to` is valid — it means "fire on any change to this field". Use this for actions that respond to all state transitions (e.g. audit logging).
  - **⚠️ Circular trigger ban (object_created)**: If the action's `target` is X and `trigger: object_created`, but the action itself creates X, that is a circular trigger (e.g. `send_fraud_alert` target=FraudAlert, trigger=object_created on FraudAlert → alert fires when alert is created — meaningless). Change `target` to an upstream Object (e.g. BankTransaction) or use `trigger: manual`. If this pattern is found during 4-C extraction, add as `ambiguous_trigger_condition` in `uncertain_items`.
  - **⚠️ Same constraint for object_created**: "When B is created, update A" (e.g. "recalculate course rating when a review is created") — the trigger target (Review) differs from the action target (Course). Set `target` to the Object that causes the trigger (Review), or use `trigger: manual`. Always mark as `ambiguous_trigger_condition`.
  - For the pattern "a change to X triggers an action on Y" (trigger target ≠ action target):
    - Consider setting `target` to the actual trigger Object (X)
    - Or use `trigger: manual`
    - Always add as `ambiguous_trigger_condition` in `uncertain_items` for user confirmation.
- `parameters`: input values mentioned in the requirements.
  - **Multi-actor pattern check**: If `trigger` is `object_created`/`object_updated` and a separate actor (e.g. pharmacy, warehouse) is needed to perform the action, add that actor's identifier as a parameter (e.g. `dispense_medication` trigger=Prescription object_created → needs `pharmacy_id` parameter).
  - If the actor is unclear from the requirements, set the action's `trigger` to `manual` and add `ambiguous_trigger_condition` to `uncertain_items`.
- `confidence`: `high` / `low`

#### 4-D: Detect conflicts with existing ontology

**Input**: `candidate_objects`, `existing_ontology`
**Output**: Mark conflict candidates + add `existing_conflict` items to `uncertain_items`

Similarity criteria (flag as conflict candidate if any apply):
- **Exact name match**: case-insensitive comparison
- **Prefix/suffix containment**: one name fully contains the other as a prefix or suffix (e.g. `Settlement` ⊂ `SettlementItem`)
- **Shared PascalCase tokens**: sharing tokens after word-splitting (exclude: Service/Repository/Controller/Handler/Factory/Manager/Util/Helper)
- **Semantic similarity**: same concept in different language/term (e.g. `User` ↔ `Member`, `Cart` ↔ `Basket`)

Add `conflict: { domain, existing_name, reason }` to conflict candidates.

#### 4-E: Build uncertain items list

**Input**: `candidate_*` (results from 4-A through 4-D)
**Output**: `uncertain_items[]` — all candidates with `confidence: low` + items matching the criteria below

| Item type | Criteria |
|-----------|----------|
| `concept_split` | Ambiguous whether it's a standalone Object Type or an attribute/status of another type |
| `existing_conflict` | Similar name detected in existing ontology (4-D) |
| `missing_primary_key` | Object Type candidate has no or ambiguous identifier property |
| `ambiguous_cardinality` | Link Type cardinality cannot be determined |
| `action_target_unclear` | Action Type target Object Type is unclear |
| `ambiguous_trigger_condition` | Status change field/value unclear, multiple outcome condition, or circular trigger pattern |
| `missing_enum_values` | Allowed values for a status property are unclear |
| `missing_computed_expression` | Computation expression for a computed property is unclear |

#### Edge case A — zero candidates

If all candidate arrays are empty after Step 4:
```
Could not derive any ontology candidates from the requirements. Please provide more detail (e.g. who does what to which entity).
```
→ Exit.

---

### Step 5: Present analysis results

Output all analysis results in the following format. **Do not ask any questions yet.**

```
## Analysis Results

### Object Types (N)
  ✓ User           — Service user [properties: user_id(string, PK), email(string), ...]
  ✓ Order          — Order record [properties: order_id(string, PK), status(string), created_at(datetime)]
  ? Cart           — Shopping cart (unclear if this should be a separate Object Type)

### Link Types (N)
  ✓ places         — User → Order (one_to_many)
  ? belongs_to     — Cart → User (cardinality unclear)

### Action Types (N)
  ✓ send_order_confirmation — Sends confirmation email on Order creation (object_created)
  ? reduce_stock            — Reduce inventory (target Object Type unclear)

### Uncertain items (N)
  [1] Cart: separate Object Type vs. Order.status attribute?
  [2] Existing 'Member' (auth domain) and new 'User' — are these the same concept?
  [3] Product has no primary key property
  [4] Cart-User relationship cardinality unclear
```

Display rules:
- `✓` = `confidence: high` / `?` = `confidence: low` or item is in `uncertain_items`
- Number uncertain items in order.

After output:
- **0 uncertain items** → `"All items are clear. Proceeding to domain placement."` → skip to Step 7
- **1 or more uncertain items** → `"There are N uncertain items. Let's go through them one by one."` → proceed to Step 6

---

### Step 6: Resolve uncertain items

Query `uncertain_items` **one at a time in order**. Every item includes a `(S) Skip` option. Choosing `(S)` keeps the item at `confidence: low` and marks it as pending in the Step 8 preview.

After processing each item → run **Step 6-cleanup**.

#### 6-A: concept_split — merge or keep separate

```
[N/totalN] How should '<name>' be handled?

  (A) Create as a separate Object Type
  (B) Treat as <related_type>.status = "<value>" (remove this Object Type)
  (C) Decide manually — enter another approach
  (S) Skip — leave as pending

Choose (A/B/C/S):
```
- `A` → promote to `confidence: high`
- `B` → remove from candidates → **run Step 6-cleanup**
- `C` → accept free-text input and apply the change
- `S` → keep `confidence: low`

#### 6-B: existing_conflict — duplicate detection

```
[N/totalN] New '<name>' and existing '<existing_name>' (<domain> domain) appear similar.

  (A) Same concept — reuse existing type (do not add the new candidate)
      → Update references in links/actions to point to '<existing_name>'
  (B) Different concept — keep both
  (C) Request a name change (manual edit recommended)
  (S) Skip — leave as pending

Choose (A/B/C/S):
```
- `A` → remove new candidate + update all references to existing name → **run Step 6-cleanup**
- `B` → promote to `confidence: high`
- `C` → same as `B`, and suggest manual edit
- `S` → keep `confidence: low`

#### 6-C: missing_primary_key — missing identifier

```
[N/totalN] '<name>' has no primary key property.

  (A) Auto-add <name_lower>_id (string) as primary key
  (B) Specify another property as primary key — enter name and type
  (C) Add without a primary key (not recommended)
  (S) Skip — leave as pending

Choose (A/B/C/S):
```
- `A` → prepend `{ name: "<name_lower>_id", type: "string", primary: true }` to that Object Type's properties
- `B` → prompt for property name, then select type (`1.string 2.int 3.float 4.boolean 5.date 6.datetime`) → add with `primary: true`

#### 6-D: ambiguous_cardinality — unclear cardinality

```
[N/totalN] Confirm the cardinality for the <from>-<to> relationship (<link_name>).

  (A) one_to_one   (B) one_to_many   (C) many_to_many   (S) Skip

Choose (A/B/C/S):
```
Apply the selection to that Link Type's `cardinality`.

#### 6-E: action_target_unclear — unclear action target

```
[N/totalN] Select the target Object Type for action '<action_name>'.

  (A) <candidate1>  (B) <candidate2>  (C) Enter manually  (S) Skip
```
Apply the selection to that Action Type's `target`.

#### 6-F: ambiguous_trigger_condition — unclear trigger condition

```
[N/totalN] Under what condition should action '<action_name>' execute?

  (A) When a new [Object] is created (object_created)
  (B) When a specific field on [Object] changes (object_updated) — enter field name, before/after values
  (C) Manual execution (manual)
  (S) Skip
```
If `B` is selected, prompt for `field`, `from`, and `to` in order (press Enter to skip each).

#### 6-G: missing_enum_values — unclear allowed values

```
[N/totalN] The allowed values for '<ObjectType>.<property_name>' are unclear.

  (A) Enter allowed values (comma-separated, e.g. pending, active, closed)
  (B) Keep as string without specifying allowed values
  (S) Skip
```
`A` → write as `"Allowed values: ..."` in that property's `description`.

#### 6-H: missing_computed_expression — unclear computation

```
[N/totalN] '<ObjectType>.<property_name>' is a computed property. Do you know the expression?

  (A) Enter the expression (e.g. gross_amount - fee)
  (B) Keep as computed without an expression
  (S) Skip
```
`A` → store the input in that property's `expression` field.

#### Step 6-cleanup: Apply cascade deletions

**When an Object Type is removed (6-A option B or 6-B option A):**
1. Remove any `candidate_links` where `from` or `to` matches the deleted name.
2. For any `candidate_actions` where `target` matches the deleted name → add as `action_target_unclear` in `uncertain_items` (skip if already present).
3. Remove any `uncertain_items` related to the deleted Object.

#### Interaction complete

After processing all `uncertain_items`: `"All uncertain items have been reviewed."`

#### Edge case B — zero confirmed candidates

If no `confidence: high` items remain after Step 6 → skip to Step 11.

---

### Step 7: Decide domain placement

Output the confirmed candidates (`confidence: high`) and prompt for placement:

```
## Confirmed Candidates

  [Object Types]  <name1>, <name2>, ... (N)
  [Link Types]    <name1>, ... (N)
  [Action Types]  <name1>, ... (N)

  (A) Add all to a single domain
  (B) Distribute across multiple domains

Choose (A/B):
```

**Option A — single domain**: Display existing domain list + "N. Create new domain". If no domains exist, prompt for a name directly. If creating a new domain, collect the following **one at a time**:
1. Domain name (required)
2. Description (optional, press Enter to skip)
3. Team or owner responsible for this domain (required, e.g. platform-team) → stored as `domain_owner`
4. Stability level: `1. experimental` / `2. stable` / `3. deprecated` (default: experimental) → stored as `stability`

Store governance fields (`domain_owner`, `stability`, `semantic_version: "1.0.0"`) and write them to both the domain YAML header and the `_index.yaml` entry in Step 9-A.

**Option B — distribute**: Specify a domain for each Object Type:
```
Assign each type to a domain.
  User → (1) auth  (2) ecommerce  (N) New domain: __
  Order → ...
```
Store the per-type domain assignments. In Step 9, process each domain separately.

---

### Step 8: Final preview and approval

Output all confirmed candidates in YAML format. If pending items exist, display them in a separate section.

```
## Final Preview

Adding the following to the '<domain_name>' domain.

# Object Types (N)
object_types:
  - name: User
    description: "Service user"
    properties:
      - name: user_id
        type: string
        primary: true
      - name: status
        type: string
        description: "Account status. Allowed values: active, inactive, suspended"
  ...

# Link Types (N)
link_types:
  ...

# Action Types (N)
action_types:
  ...

## Pending Items (skipped)
  [1] Product.primary_key — pending (confidence:low)
  [2] reduce_stock.trigger_condition — pending
```

Approval prompt:
```
Proceed with adding the above? (y / n / edit)
```
- `n` → output `"Cancelled."` and exit
- `edit` → display numbered menu by type (Object/Link/Action) → re-collect the selected item → return to Step 8
- `y` → proceed to Step 9

---

### Step 9: Update YAML files

Add confirmed Object Types, Link Types, and Action Types to each domain file.
If option B (distribute) was selected in Step 7, repeat the logic below for each domain.

#### 9-A: New domain

Write `.ontology/domains/<domain_name>/ontology.yaml`:
```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types:
  # all confirmed Object Types ([] if none)
link_types:
  # confirmed Link Types ([] if none)
action_types:
  # confirmed Action Types ([] if none)
```
Use Edit to add the new domain entry to `_index.yaml` with governance metadata and `last_modified: today`:
```yaml
  - name: <domain_name>
    description: "<domain_description>"
    domain_owner: "<domain_owner>"
    stability: <stability>
    semantic_version: "1.0.0"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>   # YYYY-MM-DD
```

#### 9-B: Existing domain — `path` field present (pre-migration)

Read `.ontology/domains/<path>` → loop through confirmed candidates and use Edit to append to each type array.
If an array is `[]`, replace with proper array form before appending.
After all appends (including edge case where no new YAML is written due to all merges), always update the domain's `last_modified` in `_index.yaml` to today's date (YYYY-MM-DD) using the Edit tool.

#### 9-C: Existing domain — `paths` field present (post-migration)

Read each type file → loop through confirmed candidates and use Edit to append. Apply the same empty-array logic as 9-B.
After all appends (including edge case where no new YAML is written), always update the domain's `last_modified` in `_index.yaml` to today's date (YYYY-MM-DD) using the Edit tool.

---

### Step 10: Global sync check

- `ask` → `"Sync to global store (<global_path>) as well? (y/n)"` → y=proceed, n=skip
- `auto` → proceed immediately
- `off` → skip

**Proceed**: Write-copy the modified domain file(s) + `_index.yaml` to `<global_path>/domains/`.

---

### Step 11: Completion message

**When items were added:**
```
✓ [<domain_name>] Analysis complete

  Added:
    Object Types  : N (<name1>, <name2>, ...)
    Link Types    : N (...)
    Action Types  : N (...)

  → .ontology/domains/<domain_name>/ontology.yaml

[i] Tip: Run /ontologian:validate to check for schema issues, or /ontologian:visualize to see your new types in context.
```

**Edge case B (nothing added):**
```
✓ Analysis complete — no new types added (all merged into existing ontology)
```

---

## Common Mistakes

- **Asking multiple questions at once** → In Step 6, always ask one question at a time and wait for a response.
- **Querying before presenting results** → Step 5 must finish outputting all results before Step 6 begins.
- **Including confidence:low items without querying** → Always add to `uncertain_items` and confirm in Step 6.
- **Missing Step 6-cleanup** → When an Object Type is removed, always cascade and update related links/action references.
- **Skipping Step 3** → Always load existing ontology. Conflict detection depends on it.
- **Including pending items (S) in final YAML** → Items still at `confidence: low` are not added to YAML. Show them only in the Step 8 pending section.
- **Wrong path format for new domains** → The `path` value in `_index.yaml` must be `<domain_name>/ontology.yaml` (no leading `domains/`).
- **Wrong name format in output YAML** → Object Type=PascalCase, Link Type=lowercase+underscores, Action Type=snake_case.
- **Nouns in Link Type names** → `reviews_course`, `earns_certificate` are not allowed. Use pure verb form: `reviews`, `earns`. Phrasal verbs with prepositions (`results_in`, `belongs_to`, `paid_with`) are allowed since the suffix is a preposition, not a noun.
- **trigger_condition.field must be a property of target** → When trigger target ≠ action target, always mark as `ambiguous_trigger_condition` and get user confirmation. In `object_updated` actions, `target` is the Object whose field changes (the field owner), not an Object created as a side effect.
- **Past participles / passive voice in Link Type names** → `granted`, `notified_by` style past-participle adjectives are not allowed. Convert to active present-tense verbs (e.g. `grants`, `generates`).
- **Vague verb choice for reference-direction links** → For "A references B" structures, the link name should clearly express A's action. Avoid `follows` when the business meaning is ambiguous. Prefer domain-specific verbs: consider `stems_from` (origin), `covers` (coverage), `pertains_to` (attribution). Always choose the most specific active verb that fits the domain language.
- **Missing reverse link for side-effect Objects** → Objects created as action side effects (e.g. Notification, Log, Receipt) should have a Link back to the trigger Object to ensure traceability. When the pattern "a change to A creates B" is found in 4-B, automatically add a B→A candidate link (e.g. `concerns`, `triggered_by`).
