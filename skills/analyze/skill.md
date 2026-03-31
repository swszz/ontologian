---
name: ontologian:analyze
description: Use when the user runs /ontologian:analyze or wants to derive an ontology structure from free-form business requirements text.
---

# Ontologian — Analyze

## Overview

비즈니스 요구사항 자유 텍스트를 입력받아 온톨로지 구조(Object Types, Link Types, Action Types)를 자동 도출하고, 불확실한 항목(confidence:low)만 사용자에게 질의해 최소 개입으로 온톨로지를 완성한다.

**핵심 원칙:**
- confidence:high는 자동 수락 — confidence:low만 질의
- 한 번에 하나의 질문만 한다. 여러 질문을 한꺼번에 묶지 않는다.
- 분석 결과를 먼저 모두 보여준 후 질의 시작

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/config.yaml`:
- **없으면**: `"온톨로지 저장소가 초기화되지 않았습니다. 지금 초기화할까요? (y/n)"` → `n`=종료, `y`=아래 두 파일 Write 생성 후 계속:
  - `.ontology/config.yaml`: `version: 1 / global_sync: ask / global_path: ~/.ontologian`
  - `.ontology/domains/_index.yaml`: `domains: []`
- **있으면**: Read 후 `global_sync`, `global_path` 저장 (기본값: `ask`, `~/.ontologian`)

---

### Step 2: 요구사항 수집

인자가 있으면 사용, 없으면 아래 질의:

```
비즈니스 요구사항을 자유롭게 설명해 주세요.
(예: "사용자가 상품을 장바구니에 담고 주문하면 재고가 줄어들고 배송이 생성된다")

요구사항:
```

입력값을 `requirements_text`로 저장.

---

### Step 3: 기존 온톨로지 로드

Read `.ontology/domains/_index.yaml`. `domains` 배열을 순회하며 각 도메인 파일을 Read.

**path/paths 분기:**
- `path` 있으면 → `.ontology/domains/<path>` Read
- `paths` 있으면 → `.ontology/domains/<paths.object_types>`, `<paths.link_types>`, `<paths.action_types>` 각각 Read

`existing_ontology`에 저장:
```
{ domains: [{ name, object_types: [이름목록], link_types: [이름목록], action_types: [이름목록] }] }
```
도메인 없거나 파일이 비어있으면 `{ domains: [] }`로 처리하고 계속 진행.

---

### Step 4: 1차 분석 — 후보 도출

`requirements_text` 분석. **이 단계는 Claude의 자율 분석이며 사용자에게 질문하지 않는다.**

**내부 상태 초기화 (Step 4 시작 시):**
```
candidate_objects: []   # {name, description, properties[], confidence}
candidate_links: []     # {name, from, to, cardinality, confidence}
candidate_actions: []   # {name, description, trigger, target, parameters[], confidence}
uncertain_items: []
```

#### 4-A: Object Type 후보 추출

**입력**: `requirements_text`
**출력**: `candidate_objects[]`
**즉시 검증**: 모든 property에 `type`이 있는지 확인 (없으면 `string`으로 기본 설정)

추출 기준:
- 주어/목적어 역할 명사, 생성·조회·수정·삭제의 대상, 독립적인 속성 집합을 가진 개념
- 제외: 단순 수량/상태 값 ("재고 수량" → 수량은 속성, 재고는 엔티티)
- **타입 분류 vs 독립 Object 판별**: 동일 도메인 내에서 어떤 Object의 `type`/`account_type` 등 열거형 속성 값이 다른 Object Type과 1:1로 대응하면 중복 모델링이다.
  - 예: `Account.account_type = fixed_deposit`이 있고 `FixedDeposit` Object도 있으면, FixedDeposit이 Account와 별개의 생명주기·속성을 가질 때만 분리한다.
  - 분리 기준: 두 후보가 서로 다른 고유 속성 집합, 다른 Action/Link를 가지면 분리 유지 (confidence:high). 속성·행위가 부모 타입의 서브셋이면 `concept_split`으로 `uncertain_items`에 추가.

각 후보 추론:
- `name`: PascalCase (예: "사용자" → `User`, "장바구니" → `Cart`)
- `description`: 역할 설명
- `properties`: 귀속 속성 목록
  - `type` 추론: 이메일→`string`, 횟수→`int`, 금액→`float`, 날짜→`datetime`
  - 식별자 속성 → `primary: true`
  - **상태 속성** (status, state, type 등): 허용값 명확하면 `description`에 `"허용값: X, Y, Z"` 기재, 불명확하면 `uncertain_items`에 `missing_enum_values` 추가
  - 파생값 → `computed: true`, 식이 명확하면 `expression` 추론, 불명확하면 `uncertain_items`에 `missing_computed_expression` 추가
  - **FK 속성 추가 금지**: 다른 Object Type 참조용 외래키(예: merchant_id, order_id)는 포함하지 않는다. 관계는 4-B에서 Link Type으로 표현.
- `confidence`: `high` / `low`

**신뢰도 판단 예시:**
```
confidence: high  →  "사용자가 주문을 생성한다" → User, Order (명확한 명사, 역할 분명)
                     "재고 수량이 감소한다" → Inventory(object), quantity(property) 명확
confidence: low   →  "장바구니에 담기" → Cart가 별도 Object인지 Order.status인지 불분명
                     한국어로만 언급돼 PascalCase 변환이 불명확한 경우
```

#### 4-B: Link Type 후보 추출

**입력**: `requirements_text`, `candidate_objects` (4-A 결과)
**출력**: `candidate_links[]`
**즉시 검증**: `from`, `to` 값이 `candidate_objects`에 존재하는지 확인. 없으면 해당 링크를 `uncertain_items`에 `action_target_unclear` 추가.

추출 기준:
- "A가 B를 ~한다" 동사 관계, "A에 B가 속한다" 포함 관계
- 동일한 관계를 양방향으로 중복 생성하지 않는다
- A→B→C 경로가 이미 있을 때 A→C 직접 링크 추가는 `uncertain_items`에 `concept_split` 추가 후 사용자 확인
- **중간 Object를 건너뛰는 링크 주의**: 요구사항이 "A가 C를 직접 사용"처럼 명시하지 않는데 A→B→C 경로가 있다면 A→C 직접 링크는 생성하지 않는다. (예: Vehicle→Package 대신 Vehicle→DeliveryOrder→Package 경로가 더 자연스러울 수 있음)

각 후보 추론:
- `name`: snake_case **순수 동사형** — 대상 명사를 이름에 포함하지 않는다
  - ✓ `places`, `contains`, `writes`, `earns`, `attends`, `paid_with`, `belongs_to`, `works_at`
  - ✗ `places_order`, `reviews_course`, `earns_certificate` (동사+명사 형태 금지)
  - ✗ `granted`, `notified_by`, `assigned_to`, `based_on`, `filled_from` — 과거분사 형용사 및 수동태·전치사구 형태도 금지. 능동 현재형 동사로 전환:
    - `granted` → `grants` (Application grants JobOffer)
    - `notified_by` → `generates` (Application generates DecisionNotification)
    - `assigned_to` → `handles` 또는 `treats` (수행 주체 기준 능동 동사)
    - `based_on` → `follows` (처방전이 예약을 따른다) 또는 방향 반전 검토
    - `filled_from` → 방향 반전 후 `fulfills` (Prescription → Medication one_to_many) 검토
  - **from→to 방향의 행위를 표현하는 동사** 선택: "A가 B를 ~한다"의 ~에 해당하는 동사
  - 참조 방향 링크(from이 to를 참조): `belongs_to`, `works_at`처럼 동사+(전치사) 형태 허용. 수동태(`assigned_to`) 및 순수 전치사구(`based_on`, `filled_from`)는 금지. 너무 제네릭한 `references`는 피한다.
  - **`_by` 패턴 허용 조건**: `sent_by`, `written_by`, `reported_by`처럼 "from이 to에 의해 생성/발송된다"는 소유·출처 관계를 표현할 때는 `<past_participle>_by` 형태를 허용한다. 단, 방향 반전(to→from 능동 동사)이 더 자연스러우면 반전을 우선 검토한다.
  - **동일 출발지에서 동일 도착지로 가는 링크가 2개인 경우 (역할 구분 필요)**: 각 역할의 의미를 담은 서로 다른 동사를 선택한다. `as_<역할>` 접두어는 명사이므로 금지. 역할별 의미를 달리하는 동사 쌍을 찾는다:
    - Follow→User 두 방향: "팔로우를 시작한 User" → `initiated_by` / "팔로우가 향하는 User" → `directed_at`
    - Message→User 두 방향: "보낸 User" → `sent_by` / "받은 User" → `received_by`
  - ✓ `initiated_by`, `directed_at` (Follow→User 두 역할 구분)
  - ✓ `sent_by`, `received_by` (Message→User 두 역할 구분)
  - ✗ `as_follower`, `as_followee` (명사형 접두어 — 동사 아님)
- `from`/`to`: **방향 일관성 원칙** — "소유자/부모 → 피소유자/자식" 방향 우선
  - many_to_one 도출 시 부모-자식이 명확하면 방향 반전해 one_to_many로 재표현 검토
    (예: "거래가 정산에 귀속" → `Settlement → Transaction (one_to_many)`)
  - **예외 — 참조(Reference) 관계**: 한쪽이 다른 쪽의 ID를 참조하는 구조이면 의미적 참조 방향을 유지한다. 강제 반전 하지 않는다.
    - 반전 검토 대상: "A가 B에 집계·소속된다" 관계 (예: `Settlement → Transaction (one_to_many)`)
    - 참조 방향 유지 대상: "A가 B를 능동적으로 참조·선택한다" 관계 (예: `Application → JobPosting`, `Enrollment → Course`)
    - **구분 기준**: B가 A 없이 독립적으로 존재 가능하면 참조(방향 유지), A가 B의 일부이면 소속(반전 검토)
  - one_to_one은 의미적 참조 방향 우선, 반전 검토 제외
- `cardinality` 추론:
  - "한 X가 여러 Y" → `one_to_many`
  - "여러 X, 여러 Y" → `many_to_many`
  - "한 X, 한 Y" → `one_to_one`
  - "여러 X가 하나의 Y" → `one_to_many` (방향 반전)
  - 불명확하면 `confidence: low`
- **`many_to_many` 직접 링크 vs. 중간 Object 판단 기준**:
  - 관계 자체에 독립 속성(예: 생성일, 이유, 상태)이 있거나 관계 인스턴스를 개별적으로 조회·삭제해야 하면 → **중간 Object 생성** (예: `Like`, `Follow`, `Enrollment`)
  - 단순 분류/태깅이고 관계 자체에 속성 불필요하면 → **`many_to_many` 직접 링크** 허용 (예: `Post → Hashtag`)
  - 중간 Object를 생성했으면 해당 Object에서 양쪽을 가리키는 `many_to_one` 링크 2개로 표현하며, 원본 `many_to_many` 링크는 생성하지 않는다.
- `confidence`: `high` / `low`

#### 4-C: Action Type 후보 추출

**입력**: `requirements_text`, `candidate_objects` (4-A 결과)
**출력**: `candidate_actions[]`
**즉시 검증**: `target` 값이 `candidate_objects`에 존재하는지 확인. 없으면 `uncertain_items`에 `action_target_unclear` 추가.

추출 기준:
- 시스템이 수행하는 동작 ("~를 보낸다", "~를 생성한다", "~를 처리한다")
- 이벤트 발생 시 자동 실행되는 행위
- 사용자가 수동으로 실행하는 작업

각 후보 추론:
- `name`: snake_case (예: `send_order_confirmation`, `reduce_stock`)
- `description`: 행위의 목적
- `target`: **trigger 유형별로 의미가 다름**
  - `object_created` → 새로 생성된 Object Type
  - `object_updated` → **변화를 감지할 Object Type** (`trigger_condition.field`가 속한 Object). 액션의 결과로 생성되는 다른 Object가 아니다.
    - ✓ "지원서 서류심사 통과 시 면접 일정" → `target: Application` (status 필드 소유자), Interview 생성은 부수 효과
    - ✓ "입사 제안 수락 시 온보딩 시작" → `target: JobOffer` (status 필드 소유자), OnboardingProcess 생성은 부수 효과
    - ✗ `target: Interview` + `trigger_condition.field: status` — Interview에 status 속성이 없으면 규칙 위반
  - `manual` → 액션이 직접 생성·수정하는 Object Type
- `trigger`:
  - 새 엔티티 생성 시 → `object_created`
  - 엔티티 변경 시 → `object_updated`
  - **"확정되면", "완료되면", "승인되면", "취소되면" 등 상태 변화 표현** → `object_updated`로 추론 + 반드시 `ambiguous_trigger_condition`으로 `uncertain_items` 추가
  - 조건 불명확하거나 수동 실행 → `manual`
- `trigger_condition`: `trigger`가 `object_updated`이고 조건이 명확할 때:
  ```
  field: <변화 감지 필드명>
  from: <변화 전 값>
  to: <변화 후 값>
  ```
  field/from/to 중 하나라도 불명확하면 `ambiguous_trigger_condition`으로 `uncertain_items` 추가
  - **⚠️ 다중 결과 조건 (예: "승인 또는 거절 시 통보")**: 단일 trigger_condition의 `to` 필드는 하나의 값만 허용한다. "A 또는 B 상태가 됐을 때"처럼 두 가지 목표 상태가 있는 경우, `to`를 생략하고 `from`만 지정하거나 (`from: under_review` → 심사 중 상태에서 변경될 때마다 발동), 동일 액션을 두 개로 분리한다. 반드시 `ambiguous_trigger_condition`으로 표시해 사용자 확인을 받는다.
  - **⚠️ 임계값/비교 조건 (예: "N회 이상이면")**: `from`/`to`에 구체적인 단일 값이 없는 비교 조건은 `trigger_condition`으로 표현할 수 없다. 이 경우 `trigger: manual`로 단순화하거나, 비교 대상 숫자 필드에 boolean flag 속성(예: `is_flagged: boolean`)을 Object에 추가하고 해당 flag의 `false→true` 전환을 trigger_condition으로 사용한다. 비교 조건 자체를 `to` 값에 기술하는 것(`"threshold_exceeded"` 등)은 허용하지 않는다.
  **⚠️ "any", "*", "모든 값" 같은 와일드카드 플레이스홀더는 절대 사용하지 않는다.** 특정 값을 알 수 없으면 해당 필드를 생략하거나 `ambiguous_trigger_condition`으로 표시한다.

  **⚠️ trigger_condition 제약 (object_updated)**: `trigger_condition.field`는 반드시 `target` Object의 property여야 한다.
  **⚠️ trigger_condition 최소 구조**: `field`만 있고 `from`/`to`가 없는 것은 유효하다 — "해당 필드가 어떤 값으로든 변경될 때"를 의미한다. `from`/`to` 없이 `field`만 명시하는 형태는 "모든 상태 전환에 반응"하는 액션(예: 이력 기록)에 사용한다.

  **⚠️ object_created 순환 트리거 금지**: 액션의 `target`이 X이고 `trigger: object_created`인데, 그 액션 자체가 X를 생성하는 경우 순환 트리거가 된다 (예: `send_fraud_alert` target=FraudAlert, trigger=object_created on FraudAlert → 알림이 생성될 때 알림 발송 = 무의미). 이 패턴은 업스트림 Object(예: BankTransaction)를 trigger 대상으로 삼거나 `trigger: manual`로 변경해야 한다. 4-C 추출 중 이 패턴이 발견되면 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가.

  **⚠️ object_created trigger도 동일 제약**: "B가 생성될 때 A를 업데이트"하는 패턴(예: "리뷰 생성 시 강좌 평점 재계산")도 trigger 대상(Review)과 action target(Course)이 다름.
  - 이런 경우 `target`은 변화를 일으키는 Object(Review)로 설정하는 게 올바름
  - 또는 `trigger: manual`로 단순화

  "X의 변화/생성이 Y에 액션을 일으킨다" 패턴(trigger 대상 ≠ action target)인 경우:
  - `target`을 실제 trigger 대상 Object(X)로 설정 검토
  - 또는 `trigger: manual`로 설정
  이 패턴은 반드시 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가해 사용자 확인을 받는다.
- `parameters`: 요구사항에서 언급된 입력값
  - **다중 행위자 패턴 체크**: trigger가 `object_created`/`object_updated`이고 별도 행위자(예: 약국, 창고)가 액션 수행에 필요한 경우, 해당 행위자 식별자를 `parameters`에 추가한다. (예: `dispense_medication` trigger=Prescription object_created → `pharmacy_id` 파라미터 필요)
  - 행위자가 요구사항에서 불명확하면 해당 액션의 `trigger`를 `manual`로 설정하고 `ambiguous_trigger_condition`으로 `uncertain_items`에 추가.
- `confidence`: `high` / `low`

#### 4-D: 기존 온톨로지와 충돌 감지

**입력**: `candidate_objects`, `existing_ontology`
**출력**: 충돌 후보에 `conflict` 마킹 + `uncertain_items`에 `existing_conflict` 항목 추가

유사도 기준 (아래 중 하나라도 해당하면 충돌 후보):
- **동일 이름**: 대소문자 무시 비교에서 완전 일치
- **접두어/접미어 포함**: 한쪽이 다른 쪽의 접두/접미어 완전 포함 (예: `Settlement` ⊂ `SettlementItem`)
- **PascalCase 토큰 공유**: 단어 분리 시 공유 토큰 있음 (Service/Repository/Controller/Handler/Factory/Manager/Util/Helper는 제외)
- **의미 유사**: 같은 개념을 다른 언어/용어로 표현 (예: `User` ↔ `Member`, `Cart` ↔ `Basket`)

충돌 후보에 `conflict: { domain, existing_name, reason }` 표시.

#### 4-E: 불확실 항목 목록 작성

**입력**: `candidate_*` (4-A~D 결과)
**출력**: `uncertain_items[]` — `confidence: low`인 모든 후보 + 아래 기준 해당 항목

| 항목 유형 | 판단 기준 |
|-----------|-----------|
| `concept_split` | 독립 Object Type인지 다른 타입의 속성/상태인지 모호 |
| `existing_conflict` | 기존 온톨로지에 유사 이름 감지 (4-D) |
| `missing_primary_key` | Object Type 후보에 식별자 속성 없거나 불명확 |
| `ambiguous_cardinality` | Link Type 카디널리티 확정 불가 |
| `action_target_unclear` | Action Type 대상 Object Type 불명확 |
| `ambiguous_trigger_condition` | 상태 변경 조건의 필드/값 불명확, 다중 결과 조건, 또는 순환 트리거 패턴 |
| `missing_enum_values` | 상태 속성 허용값 목록 불명확 |
| `missing_computed_expression` | computed 속성의 계산식 불명확 |

#### 엣지케이스 A — 후보 0개

Step 4 완료 후 candidate 배열이 모두 비어있으면:
```
요구사항에서 온톨로지 후보를 도출하지 못했습니다. 더 구체적인 내용을 추가해 주세요 (예: 어떤 주체가 무엇을 하는지).
```
→ 종료

---

### Step 5: 분석 결과 발표

아래 형식으로 전체 분석 결과를 출력한다. **질문은 하지 않는다.**

```
## 분석 결과

### Object Types (N개)
  ✓ User           — 서비스 사용자 [속성: user_id(string, PK), email(string), ...]
  ✓ Order          — 주문 정보 [속성: order_id(string, PK), status(string), created_at(datetime)]
  ? Cart           — 장바구니 (별도 Object Type인지 불확실)

### Link Types (N개)
  ✓ places         — User → Order (one_to_many)
  ? belongs_to     — Cart → User (카디널리티 불확실)

### Action Types (N개)
  ✓ send_order_confirmation — Order 생성 시 확인 이메일 발송 (object_created)
  ? reduce_stock            — 재고 감소 (대상 Object Type 불확실)

### 불확실한 항목 (N개)
  [1] Cart: 별도 Object Type vs Order.status 속성?
  [2] 기존 'Member'(auth 도메인)와 새 'User' — 동일 개념인가요?
  [3] Product의 primary key 속성 없음
  [4] Cart-User 관계 카디널리티 불명확
```

표시 규칙:
- `✓` = `confidence: high` / `?` = `confidence: low` 또는 `uncertain_items` 포함 항목
- 불확실한 항목은 번호 붙여 순서대로 나열

출력 후:
- **불확실한 항목 0개** → `"모든 항목이 명확합니다. 바로 도메인 배치로 넘어갑니다."` → Step 7로 건너뜀
- **불확실한 항목 1개 이상** → `"불확실한 항목이 N개 있습니다. 하나씩 확인하겠습니다."` → Step 6으로 진행

---

### Step 6: 결정 필요 항목 인터랙션

`uncertain_items`를 **순서대로 하나씩** 질의한다. 모든 항목에 `(S) 건너뜀` 옵션 포함. `(S)` 선택 시 해당 항목은 `confidence: low` 유지, Step 8 미리보기에서 "미결 항목"으로 표시.

각 항목 처리 후 → **Step 6-정리** 실행.

#### 6-A: concept_split — 개념 통합/분리

```
[N/전체N] <name>을(를) 어떻게 처리할까요?

  (A) 별도 Object Type으로 생성
  (B) <관련 타입>.status = "<값>"으로 처리 (Object Type 제거)
  (C) 직접 결정 — 다른 방식을 입력하세요
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```
- `A` → `confidence: high`로 승격
- `B` → 후보 목록에서 제거 → **Step 6-정리 실행**
- `C` → 자유 텍스트 입력 후 수정
- `S` → `confidence: low` 유지

#### 6-B: existing_conflict — 기존 중복 감지

```
[N/전체N] 새 '<name>'와 기존 '<existing_name>'(<domain> 도메인)이 유사합니다.

  (A) 동일 개념 — 기존 타입 재사용 (새 후보 추가 안 함)
      → 링크/액션의 참조 대상을 '<existing_name>'으로 변경
  (B) 다른 개념 — 둘 다 유지
  (C) 이름 변경 요청 (직접 수정 권장)
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```
- `A` → 새 후보 제거 + 참조 타입명을 기존 이름으로 수정 → **Step 6-정리 실행**
- `B` → `confidence: high`로 승격
- `C` → `B`와 동일 처리, 직접 수정 안내
- `S` → `confidence: low` 유지

#### 6-C: missing_primary_key — 누락 식별자

```
[N/전체N] '<name>'의 primary key 속성이 없습니다.

  (A) <name_lower>_id (string)를 primary key로 자동 추가
  (B) 다른 속성을 primary key로 지정 — 이름과 타입을 입력하세요
  (C) primary key 없이 추가 (권장하지 않음)
  (S) 건너뜀 — 미결 항목으로 보류

선택 (A/B/C/S):
```
- `A` → `{ name: "<name_lower>_id", type: "string", primary: true }` 속성을 해당 Object Type 최상위에 추가
- `B` → 속성명 입력 후 타입 선택 (`1.string 2.int 3.float 4.boolean 5.date 6.datetime`) → `primary: true`로 추가

#### 6-D: ambiguous_cardinality — 카디널리티 불확실

```
[N/전체N] <from>-<to> 관계(<link_name>)의 카디널리티를 확인해 주세요.

  (A) one_to_one   (B) one_to_many   (C) many_to_many   (S) 건너뜀

선택 (A/B/C/S):
```
선택값을 해당 Link Type의 `cardinality`에 반영.

#### 6-E: action_target_unclear — 액션 대상 불명확

```
[N/전체N] '<action_name>' 액션의 대상 Object Type을 선택하세요.

  (A) <후보1>  (B) <후보2>  (C) 직접 입력  (S) 건너뜀
```
선택값을 해당 Action Type의 `target`에 반영.

#### 6-F: ambiguous_trigger_condition — 트리거 조건 불명확

```
[N/전체N] '<action_name>' Action은 어떤 조건에서 실행되나요?

  (A) 새 [Object] 생성 시 (object_created)
  (B) [Object]의 특정 필드 변경 시 (object_updated) — 필드명/전/후 값 입력
  (C) 수동 실행 (manual)
  (S) 건너뜀
```
`B` 선택 시 `field`, `from`, `to`를 순서대로 추가 질문 (각 "모르면 빈칸 엔터").

#### 6-G: missing_enum_values — 상태값 허용 목록 불명확

```
[N/전체N] '<ObjectType>.<property_name>'의 허용값이 불명확합니다.

  (A) 허용값 입력 (쉼표 구분, 예: pending, active, closed)
  (B) 허용값 없이 string으로 유지
  (S) 건너뜀
```
`A` → 해당 속성 `description`에 `"허용값: ..."` 기재.

#### 6-H: missing_computed_expression — 계산식 불명확

```
[N/전체N] '<ObjectType>.<property_name>'은 computed 속성입니다. 계산식을 알고 있나요?

  (A) 계산식 입력 (예: gross_amount - fee)
  (B) 계산식 없이 computed로 유지
  (S) 건너뜀
```
`A` → 해당 속성 `expression` 필드에 저장.

#### Step 6-정리: 연쇄 삭제 적용

**Object Type이 제거된 경우 (6-A의 B 또는 6-B의 A):**
1. `candidate_links`에서 `from` 또는 `to`가 삭제된 이름인 항목 제거
2. `candidate_actions`에서 `target`이 삭제된 이름인 항목 → `action_target_unclear`로 `uncertain_items`에 추가 (이미 있으면 중복 추가 안 함)
3. `uncertain_items`에서 삭제된 Object에 관련된 항목 제거

#### 인터랙션 완료

모든 `uncertain_items` 처리 후: `"모든 불확실한 항목을 확인했습니다."`

#### 엣지케이스 B — 확정 후보 0개

Step 6 완료 후 `confidence: high` 항목이 없어 추가할 것이 없으면 → Step 11로 건너뜀.

---

### Step 7: 도메인 배치 결정

확정된 후보(`confidence: high`) 목록 출력 후 배치 방식 선택:

```
## 확정된 후보

  [Object Types]  <name1>, <name2>, ... (N개)
  [Link Types]    <name1>, ... (N개)
  [Action Types]  <name1>, ... (N개)

  (A) 모두 하나의 도메인에 추가
  (B) 도메인별로 나누어 배치

선택 (A/B):
```

**A 선택 — 단일 도메인**: 기존 도메인 목록 번호 출력 + "N. 새 도메인 생성" → 없으면 이름 직접 입력. 신규 도메인이면 설명도 입력(선택).

**B 선택 — 분할 배치**: Object Type마다 배치 도메인 지정:
```
각 타입을 어느 도메인에 배치할지 지정해 주세요.
  User → (1) auth  (2) ecommerce  (N) 새 도메인: __
  Order → ...
```
타입별 도메인 배치 결과를 저장. Step 9에서 도메인별로 분리해 파일에 추가.

---

### Step 8: 최종 미리보기 및 승인

확정된 모든 후보를 YAML 형식으로 출력. 미결 항목이 있으면 별도 섹션으로 표시.

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
  ...

# Link Types (N개)
link_types:
  ...

# Action Types (N개)
action_types:
  ...

## 미결 항목 (건너뜀)
  [1] Product.primary_key — 미결 (confidence:low 유지)
  [2] reduce_stock.trigger_condition — 미결
```

승인 질문:
```
위 내용으로 추가할까요? (y / n / 수정)
```
- `n` → `"취소되었습니다."` 출력 후 종료
- `수정` → 수정할 항목 선택 (Object/Link/Action 유형별 번호 메뉴) → 재수집 후 Step 8로 돌아옴
- `y` → Step 9로 진행

---

### Step 9: YAML 파일 업데이트

확정된 Object Types, Link Types, Action Types를 각 도메인 파일에 추가.
도메인별 분할 배치(B) 선택 시 도메인마다 아래 로직을 반복.

#### 9-A: 신규 도메인

Write `.ontology/domains/<domain_name>/ontology.yaml`:
```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types:
  # 확정된 Object Types 모두 포함 (없으면 [])
link_types:
  # 확정된 Link Types (없으면 [])
action_types:
  # 확정된 Action Types (없으면 [])
```
`_index.yaml`에 Edit으로 새 도메인 항목 추가 (`path: <domain_name>/ontology.yaml`, `last_modified: 오늘`).

#### 9-B: 기존 도메인 — `path` 필드 있음 (마이그레이션 전)

`.ontology/domains/<path>` Read → 각 타입 배열에 확정 후보 루프하며 Edit append.
빈 배열(`[]`) 있으면 배열 형식으로 교체 후 추가. `_index.yaml` `last_modified` 오늘 날짜로 갱신.

#### 9-C: 기존 도메인 — `paths` 필드 있음 (마이그레이션 후)

각 타입 파일 Read → 해당 배열에 확정 후보 루프하며 Edit append. 빈 배열 처리 9-B와 동일. `_index.yaml` `last_modified` 갱신.

---

### Step 10: 글로벌 싱크 체크

- `ask` → `"글로벌 저장소(<global_path>)에도 반영할까요? (y/n)"` → y=실행, n=건너뜀
- `auto` → 즉시 실행
- `off` → 건너뜀

**실행**: 수정된 도메인 파일(들) + `_index.yaml`을 `<global_path>/domains/` 경로에 Write 복사.

---

### Step 11: 완료 메시지

확정 후보가 있는 경우:
```
✓ [<domain_name>] 분석 완료

  추가된 항목:
    Object Types  : N개 (<name1>, <name2>, ...)
    Link Types    : N개 (...)
    Action Types  : N개 (...)

  → .ontology/domains/<domain_name>/ontology.yaml
```

엣지케이스 B (추가 없음):
```
✓ 분석 완료 — 추가된 새 타입 없음 (모두 기존 온톨로지와 통합)
```

---

## Common Mistakes

- **여러 질문을 한꺼번에 출력** → Step 6에서 반드시 하나씩 질의하고 응답을 기다린다.
- **분석 결과 발표 전에 질문** → Step 5 전체 발표가 완료된 후에만 Step 6 질의를 시작한다.
- **confidence:low 항목을 질의 없이 포함** → 반드시 `uncertain_items`에 포함하고 Step 6에서 사용자 확인.
- **Step 6-정리 누락** → Object Type 제거 시 관련 링크/액션 참조를 반드시 연쇄 처리한다.
- **기존 온톨로지 로드 생략** → Step 3을 반드시 수행한다. 기존 타입과의 충돌 감지가 핵심.
- **미결 항목(S)을 최종 YAML에 포함** → `confidence: low` 미결 항목은 최종 YAML에 포함하지 않고 Step 8 미결 섹션에만 표시.
- **신규 도메인 path 형식** → `_index.yaml`의 `path` 값은 `<domain_name>/ontology.yaml` 형태 (앞에 `domains/` 없음).
- **Object Type 이름 형식** → 최종 YAML에서 Object Type=PascalCase, Link Type=소문자+언더스코어, Action Type=snake_case.
- **Link Type 이름에 명사 포함 금지** → `reviews_course`, `earns_certificate` 같이 동사+명사 형태는 사용하지 않는다. `reviews`, `earns`처럼 순수 동사형으로 유지한다. 단, 전치사가 결합된 구동사(phrasal verb) — `results_in`, `belongs_to`, `paid_with` 등 — 는 허용된다. 이는 명사가 아닌 전치사이므로 "동사+명사" 규칙 위반이 아니다.
- **trigger_condition.field는 target property여야 함** → trigger 대상과 action target이 다른 경우 반드시 `ambiguous_trigger_condition`으로 표시하고 사용자 확인. `object_updated` 액션의 `target`은 변화를 감지할 Object(field 소유자)이며, 액션 결과로 생성되는 다른 Object가 아니다.
- **Link Type 이름에 과거분사/수동태 금지** → `granted`, `notified_by` 같은 과거분사 형용사는 허용하지 않는다. 능동 현재형 동사로 전환 (예: `grants`, `generates`).
- **참조 방향 링크의 동사 의미 명확성** → "A가 B를 참조한다"는 구조에서 link name은 `from(A)` 주체의 행위를 명확히 표현해야 한다. `follows`처럼 "따른다"는 뜻의 동사는 비즈니스 문맥에서 모호할 수 있다. 더 도메인 특화된 동사 선택 권장: `references` 대신 `stems_from`(기원 관계), `covers`(보장 관계), `pertains_to`(귀속 관계) 검토. 최종 선택은 도메인 언어에 맞는 가장 구체적인 능동 동사로 한다.
- **부수 효과 Object의 역방향 링크 누락** → 액션으로 생성되는 부수 Object(예: Notification, Log, Receipt)는 트리거 Object를 참조하는 Link를 가져야 추적 가능성이 확보된다. 4-B에서 "A의 변화로 B가 생성된다"는 패턴을 발견하면 B→A 링크(예: `concerns`, `triggered_by`)를 자동 후보에 추가한다.
