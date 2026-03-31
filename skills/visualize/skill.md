---
name: ontologian:visualize
description: Use when the user runs /ontologian:visualize or wants to see a visual ASCII diagram of an ontology domain's Object Types, relationships, and actions.
---

# Ontologian — Visualize

## Overview

도메인 온톨로지를 ASCII 텍스트 다이어그램으로 시각화한다.
Object Types, Relationships(Link Types), Actions(Action Types)를 계층 구조로 출력한다.

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/domains/_index.yaml` → 없으면 `"온톨로지가 초기화되지 않았습니다."` 출력 후 **즉시 종료**.

### Step 2: `_index.yaml` 읽기

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

`domains` 배열이 비어있으면:

```
등록된 도메인이 없습니다. 시각화할 항목이 없습니다.
```

를 출력하고 종료한다.

### Step 3: 도메인 선택

`domains` 배열의 항목 수에 따라 분기한다.

**1개인 경우:** 자동으로 해당 도메인을 선택하고 Step 4로 진행한다. 사용자 입력을 요구하지 않는다.

**2개 이상인 경우:** 도메인 목록과 `all` 옵션을 출력하고 입력을 요청한다.

```
시각화할 도메인을 선택하세요:

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  all. 모든 도메인

번호 또는 all을 입력하세요:
```

- **번호 선택**: 해당 도메인 1개를 대상으로 Step 4 진행.
- **`all`**: 모든 도메인을 순서대로 처리. Step 4~5를 도메인마다 반복하고 도메인 사이에 구분선을 출력한다.

  구분선 형식:
  ```
  ════════════════════
  ```

### Step 4: 도메인 파일 읽기

선택된 도메인의 `path` 또는 `paths` 필드를 확인한다.

**`path` 필드가 있는 경우 (마이그레이션 전):**

Read 툴로 `.ontology/domains/<path>` 파일을 읽는다. `object_types`, `link_types`, `action_types` 배열을 추출한다.

**`paths` 필드가 있는 경우 (마이그레이션 후):**

`paths.object_types`, `paths.link_types`, `paths.action_types` 각 값을 `.ontology/domains/<paths.X>` 경로로 조합해 Read로 읽는다. 각 파일에서 해당 배열을 추출한다.

파일 읽기에 실패하면 아래 메시지를 출력하고 해당 도메인을 건너뛴다:

```
[<domain_name>] 파일을 읽을 수 없습니다: <파일경로>
```

읽은 데이터를 메모리에 저장한다:

```
object_types: [...],   # 없으면 빈 배열
link_types: [...],     # 없으면 빈 배열
action_types: [...]    # 없으면 빈 배열
```

### Step 5: 렌더링

아래 형식으로 출력한다. 섹션별 데이터가 없어도 섹션 자체는 항상 출력한다.

#### 5-A: Object Types 박스

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

**박스 너비 규칙:**
- 내부 콘텐츠 최대 너비 + 4 (좌우 `│ ` 패딩 포함)
- 최소 너비: 39자 (박스 포함)

**플래그(flags) 표기:**
- `primary: true` → `(PK)` 추가
- `computed: true`이고 `expression`이 없으면 → `(computed)` 추가
- `computed: true`이고 `expression`이 있으면 → `(computed: <expression>)` 추가
- `primary: true`와 `computed: true` 모두인 경우 → `(PK, computed)` 추가
- 플래그 없으면 괄호 생략

**트리 기호:**
- 마지막 property: `└─`
- 마지막이 아닌 property: `├─`
- Object Type 사이에 빈 줄(`│                                     │`)을 삽입한다.
- properties가 없는 Object Type은 이름만 출력한다.

**Object Type이 없는 경우:**
```
│ OBJECT TYPES                        │
│  (없음)                             │
```

#### 5-B: Relationships 섹션

박스 아래에 빈 줄 후 출력한다.

```
RELATIONSHIPS

  [<from>] ──(<link_name>, <cardinality>)──▶ [<to>]
```

**카디널리티 표기 변환:**

| YAML 값 | 표기 |
|---------|------|
| `one_to_one` | `1:1` |
| `one_to_many` | `1:N` |
| `many_to_many` | `N:M` |
| `many_to_one` | `N:1` |

**Link Type이 없는 경우:**
```
RELATIONSHIPS

  (없음)
```

#### 5-C: Actions 섹션

빈 줄 후 출력한다.

```
ACTIONS

  <action_name>
   └─ 트리거: <trigger> → [<target>]
```

`trigger_condition`이 있으면 조건을 인라인으로 표시한다:

```
  <action_name>
   └─ 트리거: object_updated (<field>: <from>→<to>) → [<target>]
```

여러 Action이 있는 경우 각 Action 사이에 빈 줄을 넣는다.

**Action Type이 없는 경우:**
```
ACTIONS

  (없음)
```

---

## 출력 예시

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
   └─ 트리거: object_created → [User]
```

`all` 선택 시:

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

- **1개 도메인일 때 선택 메뉴 출력** → 도메인이 1개면 자동 선택한다.
- **플래그 조건 혼동** → `primary: true`/`computed: true`일 때만 플래그 표기. 없거나 false면 생략.
- **박스 너비 불일치** → 상단(`┌─...─┐`), 구분선(`├─...─┤`), 하단(`└─...─┘`) 길이는 항상 동일.
- **`all` 선택 시 구분선 누락** → 도메인 사이에 반드시 `════════════════════` 출력.
- **카디널리티 변환 오류** → YAML 원본값(`one_to_many` 등)을 그대로 출력하지 않는다. 변환 테이블 적용.
