---
name: ontologian:analyze
description: Use when the user runs /ontologian:analyze or wants to derive an ontology structure from free-form business requirements text.
---

# Ontologian — Analyze

## Overview

비즈니스 요구사항 자유 텍스트를 입력받아 온톨로지 구조(Object Types, Link Types, Action Types)를 자동 도출하고, 불확실한 항목만 사용자에게 질의해 최소 개입으로 온톨로지를 완성한다.

**핵심 원칙:**
- Claude가 먼저 분석해서 확실한 후보를 추출 — 사용자가 구조를 미리 알 필요 없음
- 불확실한 항목만 질의 — 명확한 것은 조용히 처리
- 한 번에 하나의 질문만 한다. 여러 질문을 한꺼번에 묶지 않는다.
- 분석 결과를 먼저 모두 보여준 후 질의 시작 — 사용자가 전체 그림을 먼저 파악

---

## Steps

### Step 1: 초기화 체크

Glob 툴로 `.ontology/config.yaml`을 검색한다.

```
Glob: pattern=".ontology/config.yaml"
```

**파일이 없으면** 아래 메시지를 출력하고 사용자 동의를 구한다.

```
온톨로지 저장소가 초기화되지 않았습니다. 지금 초기화할까요? (y/n)
```

- `n` → 종료
- `y` → 아래 두 파일을 Write 툴로 생성한 뒤 Step 2로 진행

`.ontology/config.yaml` 생성 내용:
```yaml
version: 1
global_sync: ask
global_path: ~/.ontologian
```

`.ontology/domains/_index.yaml` 생성 내용:
```yaml
domains: []
```

**파일이 있으면** Read 툴로 읽어 `global_sync`, `global_path` 값을 메모리에 저장한다.

```
Read: .ontology/config.yaml
```

---

### Step 2: 요구사항 수집

스킬 호출 시 인자가 있으면 그것을 요구사항 텍스트로 사용한다.

인자가 없으면 아래 프롬프트를 출력하고 사용자 입력을 기다린다.

```
비즈니스 요구사항을 자유롭게 설명해 주세요.
(예: "사용자가 상품을 장바구니에 담고 주문하면 재고가 줄어들고 배송이 생성된다")

요구사항:
```

입력받은 텍스트를 `requirements_text`로 메모리에 저장한다.

---

### Step 3: 기존 온톨로지 로드

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

`domains` 배열을 순회하며 각 도메인의 ontology.yaml을 읽어 기존 온톨로지 전체를 메모리에 적재한다.

- `path` 필드가 있으면 → `.ontology/domains/<path>` 파일을 Read로 읽는다.
- `paths` 필드가 있으면 → `paths.object_types`, `paths.link_types`, `paths.action_types` 세 파일을 각각 Read로 읽는다.

`existing_ontology`에 저장:
```
existing_ontology = {
  domains: [
    {
      name: <domain_name>,
      object_types: [...],   # 기존 Object Type 이름 목록
      link_types: [...],     # 기존 Link Type 이름 목록
      action_types: [...]    # 기존 Action Type 이름 목록
    },
    ...
  ]
}
```

도메인이 없거나 파일이 비어 있으면 `existing_ontology = { domains: [] }` 로 처리하고 계속 진행한다.

---

### Step 4: 1차 분석 — 후보 도출

`requirements_text`를 분석해 후보 목록과 불확실한 항목을 도출한다. 이 단계는 Claude의 자율 분석이며, 사용자에게 질문하지 않는다.

#### 내부 상태 초기화 (Step 4 시작 시)

```
# 내부 상태 (Step 4에서 초기화, 이후 단계에서 참조)
candidate_objects: []      # {name, description, properties, confidence}
candidate_links: []        # {name, from, to, cardinality, confidence}
candidate_actions: []      # {name, description, trigger, target, parameters, confidence}
uncertain_items: []        # confidence: low 또는 모호한 항목들
# Step 6 완료 후 candidate_* 에서 제거되지 않은 항목 = "확정된 후보"
```

#### 4-A: Object Type 후보 추출

요구사항 텍스트에서 **실세계 엔티티**에 해당하는 명사/명사구를 추출한다.

추출 기준:
- 주어 또는 목적어 역할의 명사 (사람, 사물, 개념, 문서 등)
- 생성·조회·수정·삭제의 대상이 되는 명사
- 별개의 속성 집합을 가질 수 있는 독립적인 개념

추출 제외:
- 단순 수량/상태 값 (예: "재고 수량" → 수량은 속성, 재고는 엔티티)
- 동사나 형용사로만 쓰이는 단어

각 후보에 대해 아래를 추론한다:
- `name`: PascalCase로 변환 (예: "사용자" → `User`, "장바구니" → `Cart`)
- `description`: 요구사항에서 파악한 역할 설명
- `properties`: 요구사항에서 언급되거나 해당 엔티티에 자연스럽게 귀속되는 속성 목록
  - 각 속성의 `type`은 의미에서 추론. **허용 타입**: `string`, `int`, `float`, `boolean`, `date`, `datetime` (이메일 → `string`, 횟수 → `int`, 금액 → `float`, 날짜 → `datetime`)
  - 식별자 역할의 속성은 `primary: true` 표시
  - **상태(status) 속성 감지**: 속성명이 `status`, `state`, `type`처럼 열거형 값을 가질 가능성이 있을 때, 요구사항에서 언급된 허용값을 `description`에 "허용값: ..." 형태로 명시한다. 불명확하면 `uncertain_items`에 `missing_enum_values` 유형으로 추가한다.
  - 계산/파생 값은 `computed: true` 표시, 동시에 `expression` 추론
    - 요구사항에서 계산식이 명확하면 그대로 사용 (예: `"gross_amount - fee"`)
    - 불명확하면 `confidence: low`로 표시하고 `uncertain_items`에 `missing_computed_expression` 유형으로 추가
  - **FK 속성 추가 금지**: Object Type의 `properties` 배열에서, 다른 Object Type과의 관계를 표현하기 위해 추가하는 외래키 속성(예: `merchant_id`, `order_id`)은 포함하지 않는다. 해당 관계는 4-B에서 Link Type으로만 표현한다. Action Type의 `parameters`에는 이 규칙이 적용되지 않는다.
- `confidence`: `high` (명확한 엔티티) / `low` (모호하거나 다른 엔티티의 속성일 수 있음)

추출된 후보를 `candidate_objects`에 추가한다.

#### 4-B: Link Type 후보 추출

요구사항 텍스트에서 두 Object Type 후보 사이의 **동사 관계**를 추출한다.

추출 기준:
- "A가 B를 ~한다" 형태의 동사 관계 (예: "사용자가 상품을 주문한다" → `User --places--> Order`)
- "A에 B가 속한다" 형태의 포함 관계
- 이미 도출된 Object Type 후보 간 관계뿐 아니라, 새 후보와 기존 Object Type 간 관계도 포함

각 후보에 대해 추론:
- `name`: snake_case 동사형 (예: `places`, `contains`, `aggregates`)
- `from` / `to`: 관계의 방향 (주어 → 목적어)
  - **방향 일관성 원칙**: 가능하면 "소유자/부모 → 피소유자/자식" 방향으로 통일한다.
    - `one_to_many`: 부모 → 자식 (예: `Merchant → Transaction`)
    - `many_to_one`이 도출되고 부모-자식 관계가 명확한 경우에만 방향을 뒤집어 `one_to_many`로 재표현을 검토한다.
      (예: "거래가 정산에 소속" → `Settlement → Transaction (one_to_many, aggregates)` 가 더 자연스러울 수 있음)
    - `one_to_one` 관계는 방향 뒤집기 검토 대상에서 제외한다. 의미적 참조 방향을 우선한다.
  - 동일한 관계를 양방향으로 중복 생성하지 않는다.
  - **파생 가능한 링크 주의**: A → B → C 경로가 이미 존재할 때 A → C 직접 링크를 추가하면 중복이 된다. 이 경우 `uncertain_items`에 `concept_split` 유형으로 추가하고 직접 링크의 필요성을 사용자에게 확인한다.
- `cardinality`: 아래 규칙으로 추론
  - "한 명의 사용자가 여러 주문을" → `one_to_many`
  - "한 주문에 여러 상품, 한 상품이 여러 주문에" → `many_to_many`
  - "주문 하나에 배송 하나" → `one_to_one`
  - "여러 거래가 하나의 정산에 귀속" → `one_to_many` (방향을 뒤집어 정산→거래로 표현)
  - 요구사항에서 불명확하면 `confidence: low`로 표시
- `confidence`: `high` / `low`

추출된 후보를 `candidate_links`에 추가한다.

#### 4-C: Action Type 후보 추출

요구사항 텍스트에서 **트리거 가능한 행위**를 추출한다.

추출 기준:
- "~를 보낸다", "~를 생성한다", "~를 처리한다" 등 시스템이 수행하는 동작
- 특정 이벤트 발생 시 자동 실행되는 행위
- 사용자가 수동으로 실행하는 작업

각 후보에 대해 추론:
- `name`: snake_case (예: `send_order_confirmation`, `reduce_stock`)
- `description`: 행위의 목적
- `target`: 행위의 주 대상 Object Type
- `trigger`: 아래 규칙으로 추론
  - 새 엔티티 생성 시 → `object_created`
  - 엔티티 변경 시 → `object_updated`
  - 삭제 시 → `object_deleted`
  - **"확정되면", "완료되면", "승인되면", "취소되면" 등 상태 변화 표현** → `object_updated`로 추론하되, 반드시 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가 (어떤 필드의 어떤 값 변화인지 사용자 확인 필요)
  - 조건 불명확하거나 수동 실행 → `manual`
- `trigger_condition`: `trigger`가 `object_updated`이고 조건이 명확할 때 아래 구조로 추론한다:
  ```
  trigger_condition:
    field: <status 등 변화 감지 필드명>
    from: <변화 전 값>
    to: <변화 후 값>
  ```
  field/from/to 중 하나라도 불명확하면 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가한다.
- `parameters`: 행위에 필요한 입력값 (요구사항에서 언급된 경우)
- `confidence`: `high` / `low`

추출된 후보를 `candidate_actions`에 추가한다.

#### 4-D: 기존 온톨로지와 유사 이름 감지

`existing_ontology`의 모든 타입 이름과 새 후보 이름을 비교해 충돌/중복 후보를 감지한다.

유사도 판단 기준 (아래 중 하나라도 해당하면 `conflict` 표시):
- **동일 이름**: 대소문자 무시 비교에서 완전 일치
- **접두어/접미어 포함**: 한쪽 이름이 다른 쪽의 접두어 또는 접미어를 완전히 포함
  (예: `Settlement` ⊂ `SettlementItem` → 충돌 후보, `Order` ⊂ `OrderItem` → 충돌 후보)
- **PascalCase 토큰 공유**: 두 이름을 PascalCase 단어 단위로 분리했을 때 공유 토큰이 있는 경우
  (예: `OrderItem` vs `OrderProduct` → "Order" 공유 → 충돌 후보)
  단, 기술적 접미어(Service, Repository, Controller, Handler, Factory, Manager, Util, Helper)는 비교 대상에서 제외한다.
- **의미 유사**: 같은 개념을 다른 언어/용어로 표현
  (예: `User` ↔ `Member`, `Cart` ↔ `Basket`, `가맹점` → `Merchant` ↔ 기존 `Seller`)

충돌 후보에는 `conflict: { domain: <domain_name>, existing_name: <name>, reason: "동일/유사/의미 유사" }` 표시.

#### 4-E: 불확실한 항목 목록 작성

아래 기준으로 `uncertain_items` 목록을 작성한다.

| 항목 유형 | 판단 기준 |
|-----------|-----------|
| `concept_split` | 하나의 명사가 독립 Object Type인지 다른 타입의 속성/상태인지 모호한 경우 |
| `existing_conflict` | 기존 온톨로지에 유사 이름 감지 (4-D) |
| `missing_primary_key` | Object Type 후보에 식별자 속성이 없거나 불명확한 경우 |
| `ambiguous_cardinality` | Link Type의 카디널리티를 요구사항에서 확정할 수 없는 경우 |
| `action_target_unclear` | Action Type의 대상 Object Type이 여러 후보 중 하나인 경우 |
| `ambiguous_trigger_condition` | Action의 트리거가 상태 변경 조건인 경우 (어떤 필드의 어떤 값 변화인지 불명확) |
| `missing_computed_expression` | `computed: true` 속성의 계산식을 요구사항에서 추론할 수 없는 경우 |

`confidence: low`로 표시된 모든 후보는 자동으로 `uncertain_items`에 포함된다.

#### 엣지케이스 A — 후보 0개

Step 4 완료 후 `candidate_objects`, `candidate_links`, `candidate_actions`가 모두 비어 있으면:

```
요구사항에서 온톨로지 후보를 도출하지 못했습니다. 더 구체적인 내용을 추가해 주세요 (예: 어떤 주체가 무엇을 하는지).
```

→ 종료

---

### Step 5: 분석 결과 발표

아래 형식으로 분석 결과 전체를 출력한다. 질문은 하지 않는다.

```
## 분석 결과

요구사항에서 도출된 온톨로지 후보입니다.

### Object Types (N개)
  ✓ User           — 서비스 사용자 [속성: user_id(string, PK), email(string), ...]
  ✓ Order          — 주문 정보 [속성: order_id(string, PK), status(string), created_at(datetime)]
  ? Cart           — 장바구니 (별도 Object Type인지 불확실)

### Link Types (N개)
  ✓ places         — User → Order (one_to_many)
  ✓ contains       — Order → Product (many_to_many)
  ? belongs_to     — Cart → User (카디널리티 불확실)

### Action Types (N개)
  ✓ send_order_confirmation — Order 생성 시 확인 이메일 발송 (object_created)
  ? reduce_stock            — 재고 감소 (대상 Object Type 불확실)

### 불확실한 항목 (N개)
  [1] Cart: 별도 Object Type으로 관리 vs Order의 status 속성으로 처리?
  [2] 기존 'Member'(auth 도메인)와 새 'User' — 동일 개념인가요?
  [3] Product의 primary key 속성이 명시되지 않음
  [4] Cart-User 관계 카디널리티 불명확 (한 사용자당 장바구니 몇 개?)
```

표시 규칙:
- `✓` = `confidence: high` 항목 (확실한 후보)
- `?` = `confidence: low` 항목 또는 `uncertain_items`에 포함된 항목
- 불확실한 항목은 번호를 붙여 순서대로 나열 (나중에 이 번호 순서대로 질의)

출력 후 불확실한 항목 수(N)에 따라 분기한다.

**불확실한 항목이 0개이면:**

```
모든 항목이 명확합니다. 바로 도메인 배치로 넘어갑니다.
```

그리고 Step 7로 건너뛴다.

**불확실한 항목이 1~5개이면:**

```
불확실한 항목이 N개 있습니다. 하나씩 확인하겠습니다.
```

그리고 Step 6으로 진행한다.

**불확실한 항목이 6개 이상이면 (배치 모드 분기):**

```
불확실한 항목이 N개입니다. 처리 방식을 선택하세요:
  (A) 하나씩 확인 (N번 응답 필요 — 정밀도 높음)
  (B) 빠른 처리 (Claude가 추천 선택지를 자동 결정, Step 8 미리보기에서 한 번에 수정)
```

- `(A)` 선택 → Step 6으로 진행 (개별 인터랙션)
- `(B)` 선택 → Claude가 각 `uncertain_item`에 가장 높은 `confidence`의 선택지를 자동 적용한 뒤, 자동 결정 내용을 내부적으로 기록하고 Step 7로 바로 진행. Step 8 최종 미리보기에서 "자동 결정된 항목" 섹션으로 별도 표시.

---

### Step 6: 결정 필요 항목 인터랙션

`uncertain_items` 목록을 순서대로 처리한다. **한 번에 하나의 항목만 질의한다.**

각 항목은 (A)/(B)/(C)/(S) 형태의 명확한 선택지를 제시한다. 사용자 응답을 받고 다음 항목으로 넘어간다.

모든 질의 항목에 `(S) 건너뜀` 옵션이 포함된다. `(S)` 선택 시 해당 항목은 `confidence: low` 상태를 유지하며, Step 8 미리보기에서 "미결 항목" 섹션으로 별도 표시된다.

#### 6-A: concept_split — 개념 통합/분리

```
[1/N] Cart를 어떻게 처리할까요?

  (A) 별도 Object Type으로 생성
      → Cart { cart_id, created_at } + User-Cart 관계 추가
  (B) Order.status = "pending"으로 처리 (Object Type 제거)
      → 장바구니 상태를 주문의 상태값으로 관리
  (C) 직접 결정 — 다른 방식을 입력하세요
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

- `A` → 해당 후보를 `confidence: high`로 승격
- `B` → 해당 후보를 후보 목록에서 제거, 관련 링크도 제거
- `C` → 사용자 입력을 자유 텍스트로 받아 그에 맞게 후보 수정
- `S` → `confidence: low` 유지, 미결 항목으로 기록

#### 6-B: existing_conflict — 기존 중복 감지

```
[2/N] 새로 추가할 'User'와 기존 'Member'(auth 도메인)가 유사합니다.

  (A) 동일 개념 — 기존 'Member' 재사용 (새 'User' 추가 안 함)
      → 새 링크/액션의 참조 대상을 'Member'로 변경
  (B) 다른 개념 — 둘 다 유지
      → 'User'를 새 타입으로 추가, 필요 시 두 타입 간 링크도 추가
  (C) 기존 'Member' 이름을 'User'로 변경
      → 기존 타입 이름 수정 (이 스킬의 범위를 벗어남, 직접 수정 권장)
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

- `A` → 새 후보 제거, 해당 후보를 참조하는 링크/액션의 타입명을 기존 타입명으로 수정
- `B` → 새 후보를 `confidence: high`로 승격
- `C` → 사용자에게 직접 수정을 안내하고, 일단 `B`와 동일하게 처리
- `S` → `confidence: low` 유지, 미결 항목으로 기록

#### 6-C: missing_primary_key — 누락 식별자

```
[3/N] 'Product'의 primary key 속성이 명시되지 않았습니다.

  (A) product_id (string) 를 primary key로 자동 추가
  (B) 다른 속성을 primary key로 지정 — 이름을 입력하세요
  (C) primary key 없이 추가 (권장하지 않음)
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

- `A` → `{ name: "product_id", type: "string", primary: true }` 속성을 해당 Object Type 최상위에 추가
- `B` → 속성 이름 입력받고, 타입 선택 프롬프트 제시 후 `primary: true`로 추가
  ```
  타입을 선택하세요:
    1. string  2. int  3. float  4. boolean  5. date  6. datetime
  번호를 입력하세요:
  ```
- `C` → 그대로 진행
- `S` → `confidence: low` 유지, 미결 항목으로 기록

#### 6-D: ambiguous_cardinality — 카디널리티 불확실

```
[4/N] Cart-User 관계의 카디널리티를 확인해 주세요.

  (A) one_to_one  — 한 사용자는 장바구니 하나만 가짐
  (B) one_to_many — 한 사용자는 여러 장바구니를 가질 수 있음
  (C) many_to_many — 여러 사용자가 하나의 장바구니를 공유 가능
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

선택값을 해당 Link Type 후보의 `cardinality`에 반영한다.

#### 6-E: action_target_unclear — 액션 대상 불명확

```
[N/N] 'reduce_stock' 액션의 대상 Object Type을 선택하세요.

  (A) Product  — 상품의 재고를 직접 감소
  (B) Order    — 주문 처리 시 연쇄적으로 재고 감소
  (C) 직접 입력
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

선택값을 해당 Action Type 후보의 `target`에 반영한다.

#### 6-F: ambiguous_trigger_condition — 트리거 조건 불명확

```
[N/N] '[Action 이름]' Action은 어떤 조건에서 실행되나요?

  (A) 새 [Object] 생성 시 (trigger: object_created)
  (B) [Object]의 특정 필드 변경 시 (trigger: object_updated)
  (C) 수동 실행 (trigger: manual)
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```

선택값을 해당 Action Type 후보의 `trigger`에 반영한다.

#### 6-G: missing_enum_values — 상태값 허용 목록 불명확

```
[N/N] '<ObjectType>.<property_name>' 속성의 허용값이 명확하지 않습니다.

  (A) 허용값을 입력 — 쉼표로 구분 (예: pending, active, closed)
  (B) 허용값 없이 string으로 유지
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/S):
```

`(A)` 선택 시 입력된 허용값을 해당 속성의 `description`에 "허용값: ..." 형태로 저장한다.

#### 6-H: missing_computed_expression — 계산식 불명확

```
[N/N] '<ObjectType>.<property_name>'은 computed 속성입니다. 계산식을 알고 있나요?

  (A) 계산식을 입력 (예: gross_amount - fee, SUM(items.amount))
  (B) 계산식 없이 computed로 유지
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/S):
```

`(A)` 선택 시 입력된 계산식을 해당 속성의 `expression` 필드에 저장한다.

#### 인터랙션 완료

모든 `uncertain_items`를 처리하면 아래 메시지를 출력한다.

```
모든 불확실한 항목을 확인했습니다.
```

#### 엣지케이스 B — 확정 후보 0개

Step 6 완료 후 (`confident: high`인 항목이 하나도 없어) 모든 후보가 기존 온톨로지와 통합되거나 제거되어 새로 추가할 항목이 없으면, Step 7~10을 건너뛰고 Step 11로 바로 이동한다.

---

### Step 7: 도메인 배치 결정

확정된 후보(`confidence: high`인 Object Types, Link Types, Action Types)를 어느 도메인에 추가할지 결정한다.

확정된 후보 목록을 먼저 출력한다:

```
## 확정된 후보

  [Object Types]  User, Order, Product (3개)
  [Link Types]    places, contains (2개)
  [Action Types]  send_order_confirmation, reduce_stock (2개)
```

이어서 배치 방식을 질문한다:

```
  (A) 모두 하나의 도메인에 추가
  (B) 도메인별로 나누어 배치

선택 (A/B):
```

**`(A)` 선택 시 — 단일 도메인 배치:**

**기존 도메인이 있는 경우:**
```
어느 도메인에 추가할까요?

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  N. 새 도메인 생성

번호를 입력하세요:
```

**기존 도메인이 없는 경우:**
```
등록된 도메인이 없습니다. 새 도메인 이름을 입력하세요 (예: ecommerce):
```

신규 도메인 선택 시 추가 질문:
```
도메인 설명을 입력하세요 (선택, 빈칸 엔터로 건너뜀):
```

선택된 도메인 정보를 메모리에 저장한다.

**`(B)` 선택 시 — 도메인별 분할 배치:**

각 Object Type 이름 옆에 도메인을 지정하는 루프를 진행한다. 도메인 선택지는 기존 도메인 목록 + "새 도메인 생성" 옵션을 포함한다.

```
각 타입을 어느 도메인에 배치할지 지정해 주세요.

  User → (1) auth  (2) ecommerce  (N) 새 도메인: __
  Order → ...
  ...
```

타입별 도메인 배치 결과를 메모리에 저장하고, 이후 Step 9에서 도메인별로 분리하여 파일에 추가한다.

---

### Step 8: 최종 미리보기 및 승인

확정된 모든 후보를 YAML 형식으로 완성해 출력한다. 도메인명과 추가될 타입 종류를 명시한다.

```
## 최종 미리보기

아래 내용을 '<domain_name>' 도메인에 추가합니다.

# Object Types (N개)
object_types:
  - name: User
    description: "서비스 사용자"
    properties:
      - name: user_id
        type: string
        primary: true
      - name: email
        type: string
  - name: Order
    ...

# Link Types (N개)
link_types:
  - name: places
    from: User
    to: Order
    cardinality: one_to_many
    description: "사용자가 주문을 생성"
  ...

# Action Types (N개)
action_types:
  - name: send_order_confirmation
    description: "주문 생성 시 확인 메일 발송"
    target: Order
    trigger: object_created
    parameters:
      - name: recipient_email
        type: string
        required: true
  ...
```

**배치 모드(B)에서 자동 결정된 항목이 있으면** 별도 섹션으로 표시:

```
## 자동 결정된 항목 (빠른 처리 모드)

  [1] Cart → (B) Order.status = "pending"으로 처리 (자동 결정)
  [2] Cart-User 카디널리티 → (A) one_to_one (자동 결정)
  ...

위 항목을 수정하려면 '수정'을 입력하세요.
```

**건너뛴 항목(미결 항목)이 있으면** 별도 섹션으로 표시:

```
## 미결 항목 (건너뜀)

  [1] Product.primary_key — 미결 (confidence: low 유지)
  [2] reduce_stock.trigger_condition — 미결 (confidence: low 유지)
```

이어서 승인 질문을 한다.

```
위 내용으로 추가할까요? (y / n / 수정)
```

- **`n`** → 종료:
  ```
  취소되었습니다.
  ```
- **`수정`** → 수정 가능한 항목 목록을 번호로 출력하고 선택하게 한다:
  ```
  수정할 항목을 선택하세요:
    [Object Types]
      1. User
      2. Order
      ...
    [Link Types]
      N. places
      ...
    [Action Types]
      N. send_order_confirmation
      ...
  번호를 입력하세요:
  ```
  선택된 항목의 타입에 따라 해당 항목 유형(Object/Link/Action)에 맞는 수정 프롬프트를 직접 제시하고 재수집한 뒤 Step 8로 돌아온다.
  - Object Type 수정: 이름, 설명, 속성 목록(이름/타입/primary/computed)을 순서대로 질의
  - Link Type 수정: 이름, from, to, cardinality를 순서대로 질의
  - Action Type 수정: 이름, 설명, target, trigger, parameters를 순서대로 질의
- **`y`** → Step 9로 진행.

---

### Step 9: YAML 파일 업데이트

확정된 Object Types, Link Types, Action Types를 각각 대상 도메인 파일에 추가한다.

Step 7에서 도메인별 분할 배치를 선택한 경우, 도메인별로 아래 로직을 반복 실행한다.

#### 9-A: 신규 도메인인 경우

Write 툴로 `.ontology/domains/<domain_name>/ontology.yaml`을 생성한다.

```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types:
  # 확정된 Object Types 모두 포함
link_types:
  # 확정된 Link Types 모두 포함
action_types:
  # 확정된 Action Types 모두 포함
```

배열이 비어 있으면 `object_types: []` 형태로 작성한다.

Read 툴로 `_index.yaml`을 읽은 뒤 Edit 툴로 새 도메인 항목을 추가한다:

```yaml
  - name: <domain_name>
    description: "<domain_description>"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>   # YYYY-MM-DD
```

#### 9-B: 기존 도메인 — 마이그레이션 전 (`path` 필드 있음)

대상 파일: `.ontology/domains/<path>`

Read 툴로 파일을 읽고, 각 타입 배열에 확정 후보 전체를 순서대로 배열 append한다 (Edit 툴 사용).

- Object Types → `object_types` 배열 끝에 `candidate_objects`의 확정 항목 전체를 루프하며 추가
- Link Types → `link_types` 배열 끝에 `candidate_links`의 확정 항목 전체를 루프하며 추가
- Action Types → `action_types` 배열 끝에 `candidate_actions`의 확정 항목 전체를 루프하며 추가

각 타입에 대해 빈 배열 처리:
```
old: "object_types: []"
new:
object_types:
  - name: ...
```
(빈 배열 `[]` 형태일 때 그대로 항목을 추가하면 YAML이 깨지므로, 반드시 배열 형식으로 교체한다.)

`_index.yaml`의 해당 도메인 `last_modified`를 오늘 날짜로 갱신한다 (Edit 툴).

#### 9-C: 기존 도메인 — 마이그레이션 후 (`paths` 필드 있음)

타입별 파일 경로:

| 타입 | 경로 |
|------|------|
| Object Types | `.ontology/domains/<paths.object_types>` |
| Link Types | `.ontology/domains/<paths.link_types>` |
| Action Types | `.ontology/domains/<paths.action_types>` |

각 파일을 Read로 읽고, 해당 타입의 확정 후보 배열 전체를 파일 배열 끝에 루프하며 append한다 (Edit 툴). 빈 배열(`[]`) 처리는 9-B와 동일하게 배열 형식으로 교체한다.

`_index.yaml`의 해당 도메인 `last_modified`를 오늘 날짜로 갱신한다 (Edit 툴).

---

### Step 10: 글로벌 싱크 체크

Step 1에서 읽은 `global_sync` 값에 따라 동작한다.

**`ask`인 경우:**
```
글로벌 저장소(<global_path>)에도 반영할까요? (y/n)
```
- `y` → 싱크 실행
- `n` → 건너뜀

**`auto`인 경우:** 사용자 확인 없이 싱크 실행.

**`off`인 경우:** 아무것도 하지 않고 Step 11로 이동.

**싱크 실행 내용:**

수정된 도메인 파일(들)을 `<global_path>/domains/<domain_name>/` 경로에 Write 툴로 복사한다.

- 마이그레이션 전 도메인: `ontology.yaml` 1개 복사
- 마이그레이션 후 도메인: 수정된 타입 파일들 복사

`<global_path>/domains/_index.yaml`도 최신 내용으로 Write 툴로 덮어쓴다.

---

### Step 11: 완료 메시지

확정 후보가 있는 경우:

```
✓ [<domain_name>] 분석 완료

  추가된 항목:
    Object Types  : N개 (<name1>, <name2>, ...)
    Link Types    : N개 (<name1>, <name2>, ...)
    Action Types  : N개 (<name1>, ...)

  → .ontology/domains/<domain_name>/ontology.yaml
```

엣지케이스 B (확정 후보 0개)에서 이 단계로 직접 진입한 경우:

```
✓ 분석 완료 — 추가된 새 타입 없음 (모두 기존 온톨로지와 통합)
```

---

## Common Mistakes

- **여러 질문을 한꺼번에 출력하는 경우** → Step 6에서 반드시 한 번에 하나의 항목만 질의하고 응답을 기다린다.
- **분석 결과 발표 전에 질문하는 경우** → Step 5의 전체 발표가 완료된 후에만 Step 6 질의를 시작한다.
- **confidence: low 항목을 질의 없이 포함하는 경우** → `confidence: low` 후보는 반드시 `uncertain_items`에 포함하고 Step 6에서 사용자에게 확인한다.
- **기존 온톨로지 로드 생략** → Step 3은 반드시 수행한다. 기존 타입과 충돌 감지는 analyze 스킬의 핵심이다.
- **`path`와 `paths` 혼동** → `path`(단수) = 마이그레이션 전 단일 파일, `paths`(복수) = 마이그레이션 후 타입별 파일.
- **빈 배열(`[]`) 처리 누락** → `[]` 형태일 때 그대로 항목을 추가하면 YAML이 깨진다. 반드시 배열 형식으로 교체한다.
- **`computed: false` 또는 `primary: false` 명시** → `false`인 경우 해당 필드 자체를 생략한다.
- **설명이 없을 때 `description: ""` 작성** → 빈 설명은 필드를 생략한다.
- **_index.yaml `last_modified` 갱신 누락** → YAML 파일 수정 후 반드시 갱신한다.
- **Object Type 이름 형식 오류** → 최종 YAML에 포함되는 Object Type 이름은 반드시 PascalCase, Link Type은 소문자+언더스코어, Action Type은 snake_case여야 한다. 분석 단계에서 자동 변환한다.
- **신규 도메인 path 형식 오류** → `_index.yaml`의 `path` 값은 `<domain_name>/ontology.yaml` 형태로 저장 (앞에 `domains/` 없음).
- **`(S) 건너뜀` 항목을 최종 YAML에 포함하는 경우** → 건너뛴 항목은 `confidence: low` 상태이므로 최종 YAML에 포함하지 않고 Step 8 미리보기의 "미결 항목" 섹션에만 표시한다.
- **배치 모드(B) 자동 결정 항목을 Step 8에서 누락하는 경우** → 자동 결정된 모든 항목은 반드시 "자동 결정된 항목" 섹션에 명시해야 한다.
- **상태 변화 트리거를 uncertain_items에 추가하지 않는 경우** → "확정되면", "완료되면" 등 상태 변화 표현은 `object_updated`로 추론하되, 반드시 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가한다.
