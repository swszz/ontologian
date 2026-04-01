---
name: ontologian:validate
description: Use when the user runs /ontologian:validate or wants to check ontology YAML schema correctness and referential integrity across all domains.
---

# Ontologian — Validate

## Overview

모든 도메인의 YAML 스키마와 참조 무결성을 검증한다.
오류가 없으면 통과 메시지를, 오류가 있으면 도메인·타입·필드별 오류 목록을 출력한다.

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/domains/_index.yaml` → 없으면 `"온톨로지가 초기화되지 않았습니다."` 출력 후 **즉시 종료**.

### Step 2: `_index.yaml` 읽기

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

`domains` 배열이 비어있거나 파일이 없으면:

```
등록된 도메인이 없습니다. 검증할 항목이 없습니다.
```

를 출력하고 종료한다.

### Step 3: 도메인별 파일 읽기

`_index.yaml`의 `domains` 배열을 순회하며 각 도메인의 타입 데이터를 읽는다.

**마이그레이션 여부 판단:**

- `path` 필드가 있으면 → `.ontology/domains/<path>` 파일 하나를 Read로 읽는다. `object_types`, `link_types`, `action_types` 배열을 추출한다.
- `paths` 필드가 있으면 → `paths.object_types`, `paths.link_types`, `paths.action_types` 각 값을 `.ontology/domains/<paths.X>` 경로로 조합해 Read로 읽는다. 각 파일에서 해당 배열을 추출한다.

파일 읽기에 실패한 도메인은 오류 목록에 다음 항목을 추가하고 해당 도메인의 나머지 검증을 건너뛴다:

```
[<domain_name>] 파일을 읽을 수 없습니다: <파일경로>
```

각 도메인마다 아래 데이터를 메모리에 저장한다:

```
domain_data[domain_name] = {
  object_types: [...],   # 없으면 빈 배열
  link_types: [...],     # 없으면 빈 배열
  action_types: [...]    # 없으면 빈 배열
}
```

### Step 4: 스키마 검증

각 도메인의 모든 타입 항목을 순회하며 필수 필드와 허용 값을 검사한다. 위반 시 `errors` 목록에 추가한다.

#### Object Type 검증

각 항목에 대해:

| 필드 | 규칙 |
|------|------|
| `name` | 필수. 없으면 오류 |
| `description` | 필수. 없거나 빈 문자열이면 오류 |

`properties` 배열이 있으면 각 property도 검증한다:

| 필드 | 규칙 |
|------|------|
| `name` | 필수 |
| `type` | 필수. 허용값: `string`, `int`, `float`, `boolean`, `date`, `datetime`. `integer`는 `int`의 별칭으로 허용 (오류로 처리하지 않음) |
| `description` | 선택. 없으면 경고(warning, 오류는 아님): `[ObjectType명.property명] description이 없습니다. 필드 의미를 기록하면 지식 유지에 도움이 됩니다.` |
| `computed` | 선택. `true`이면 `expression` 필드의 존재 여부를 확인한다. 없으면 경고(warning, 오류는 아님): `computed 속성 '<name>'에 expression이 없습니다.` |

#### Link Type 검증

각 항목에 대해:

| 필드 | 규칙 |
|------|------|
| `name` | 필수 |
| `from` | 필수 |
| `to` | 필수 |
| `cardinality` | 필수. 허용값: `one_to_one`, `one_to_many`, `many_to_many`, `many_to_one` |

#### Action Type 검증

각 항목에 대해:

| 필드 | 규칙 |
|------|------|
| `name` | 필수 |
| `description` | 필수. 없거나 빈 문자열이면 오류 |
| `trigger` | 필수. 허용값: `object_created`, `object_updated`, `object_deleted`, `manual` |
| `target` | 필수 |

**`trigger_condition` 검증 (선택적 필드):**

`trigger_condition` 필드가 존재하면:
- `trigger`가 `object_updated`인 경우에만 허용한다. 다른 trigger 값과 함께 존재하면 오류:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition: trigger가 '<trigger_value>'일 때 사용할 수 없습니다. object_updated일 때만 허용됩니다.
  ```
- 필수 하위 필드: `field`, `from`, `to` 모두 존재해야 한다. 하나라도 없으면 오류:
  ```
  [<domain_name>] Action Type '<name>'
    → trigger_condition.<field_name>: 필수 필드가 없습니다. (field, from, to 모두 필요)
  ```

`parameters` 배열이 있으면 각 parameter도 검증한다:

| 필드 | 규칙 |
|------|------|
| `name` | 필수 |
| `type` | 필수. 허용값: `string`, `int`, `float`, `boolean`, `date`, `datetime` |

**parameter에 `name`이 없는 경우:** 스키마 오류로 기록하되 해당 parameter의 나머지 필드(`type` 등) 검증은 건너뛴다.

**오류 메시지 형식:**

```
[<domain_name>] <Type Kind> '<name>'
  → <field>: <오류 내용>
```

예시:

```
[ecommerce] Object Type 'Product'
  → description: 필수 필드가 없습니다.

[ecommerce] Object Type 'Product' > property 'price'
  → type: 허용되지 않는 값 'number'. (허용값: string, int, float, boolean, date, datetime)

[ecommerce] Link Type 'places'
  → cardinality: 허용되지 않는 값 'one_to_few'. (허용값: one_to_one, one_to_many, many_to_many, many_to_one)

[ecommerce] Action Type 'send_welcome_email'
  → trigger: 허용되지 않는 값 'on_create'. (허용값: object_created, object_updated, object_deleted, manual)

[ecommerce] Action Type 'send_email' > parameter 'index 0': name 필드 없음
```

warning 예시:

```
⚠ [ecommerce] Object Type 'Product' > property 'price': description이 없습니다. 필드 의미를 기록하면 지식 유지에 도움이 됩니다.
⚠ [ecommerce] Object Type 'User' > property 'status': description이 없습니다. 필드 의미를 기록하면 지식 유지에 도움이 됩니다.
```

### Step 5: 참조 무결성 검증

각 도메인에서 해당 도메인의 `object_types` 이름 목록(`object_names`)을 먼저 수집한다.

**크로스 도메인 참조 정책:** `from`, `to`, `target` 필드는 동일 도메인 내 Object Type만 허용한다. 다른 도메인의 타입을 참조하면 오류로 처리한다.

#### Link Type 참조 검증

각 Link Type의 `from`, `to` 값이 같은 도메인의 `object_names`에 존재하는지 확인한다.

존재하지 않으면 오류 추가:

```
[<domain_name>] Link Type '<link_name>'
  → from: '<value>'가 Object Type으로 존재하지 않습니다.

[<domain_name>] Link Type '<link_name>'
  → to: '<value>'가 Object Type으로 존재하지 않습니다.
```

#### Action Type 참조 검증

각 Action Type의 `target` 값이 같은 도메인의 `object_names`에 존재하는지 확인한다.

존재하지 않으면 오류 추가:

```
[<domain_name>] Action Type '<action_name>'
  → target: '<value>'가 Object Type으로 존재하지 않습니다.
```

`trigger_condition`이 존재하고 `field` 값이 있으면, `target` Object Type의 `properties`에 해당 `field`가 존재하는지 확인한다.

존재하지 않으면 오류 추가:

```
[<domain_name>] Action Type '<action_name>'
  → trigger_condition.field: '<field_value>'가 target '<target_name>'의 property로 존재하지 않습니다.
```

### Step 6: 중복 이름 검증

각 도메인 내에서 Object Type, Link Type, Action Type 이름이 각 범주 안에서 중복되는지 확인한다.

- `object_types` 배열 내 `name` 중복
- `link_types` 배열 내 `name` 중복
- `action_types` 배열 내 `name` 중복

중복 발견 시 오류 추가:

```
[<domain_name>] Object Type 이름 중복: '<name>'
[<domain_name>] Link Type 이름 중복: '<name>'
[<domain_name>] Action Type 이름 중복: '<name>'
```

### Step 7: 결과 출력

**모든 도메인에서 오류가 없는 경우 (warning 없음):**

```
✓ 모든 도메인 검증 통과 (<N>개 도메인, <N> Objects, <N> Links, <N> Actions)
```

**오류는 없지만 warning이 있는 경우:**

```
✓ 검증 통과 — 단, <W>개 권고사항 있음

⚠ <warning1>
⚠ <warning2>
...
```

`N` 값은 모든 도메인을 합산한 총 개수다.

**오류가 하나 이상인 경우:**

```
✗ 검증 실패 — <N>개 오류 발견

<오류1>

<오류2>

...
```

오류 뒤에 warning이 있으면 오류 목록 다음에 아래와 같이 이어서 출력한다:

```
⚠ 권고사항 (<W>개)
⚠ <warning1>
⚠ <warning2>
...
```

오류는 수집된 순서대로 출력한다. 각 오류 항목 사이에 빈 줄을 넣는다.

---

## Common Mistakes

- **배열 키 부재** → `object_types`, `link_types`, `action_types` 키가 없으면 빈 배열로 처리한다.
- **name 없는 항목의 참조 검증** → `name`이 없는 항목은 스키마 오류로 기록하고 참조 검증에서는 건너뛴다.
- **오류 카운트 불일치** → 헤더의 `N개 오류 발견`은 `errors` 목록의 실제 항목 수와 정확히 일치해야 한다.
- **통과 메시지 합계** → Objects/Links/Actions 수는 모든 도메인의 합산값 (도메인별 수가 아님).
- **warning과 오류 혼용 금지** → property description 누락은 `errors`가 아닌 `warnings`에 추가한다. 오류 카운트에 포함하지 않는다.
