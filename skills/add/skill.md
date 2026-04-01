---
name: ontologian:add
description: Use when the user runs /ontologian:add or wants to add a new Object Type, Link Type, or Action Type to an ontology domain.
---

# Ontologian — Add Type

## Overview

사용자와 대화형으로 새 Object Type, Link Type, 또는 Action Type을 온톨로지에 추가한다.
**한 번에 하나의 질문만 한다. 여러 질문을 한꺼번에 묶지 않는다.**

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/config.yaml`:
- **없으면**: `"온톨로지 저장소가 초기화되지 않았습니다. 지금 초기화할까요? (y/n)"` → `n`=종료, `y`=아래 두 파일 Write 생성 후 계속:
  - `.ontology/config.yaml`: `version: 1 / global_sync: ask / global_path: ~/.ontologian`
  - `.ontology/domains/_index.yaml`: `domains: []`
- **있으면**: Read 후 `global_sync`, `global_path` 저장 (기본값: `ask`, `~/.ontologian`)

### Step 2: _index.yaml 읽기

Read 툴로 도메인 목록을 읽는다.

```
Read: .ontology/domains/_index.yaml
```

`domains` 배열을 메모리에 저장한다. 배열이 비어있어도 계속 진행한다.

### Step 3: 도메인 선택

현재 등록된 도메인 목록과 신규 생성 옵션을 출력한다.

**기존 도메인이 있는 경우:**
```
어떤 도메인에 추가할까요?

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  N. 새 도메인 생성

번호를 입력하세요:
```

**기존 도메인이 없는 경우:**
```
등록된 도메인이 없습니다. 새 도메인 이름을 입력하세요:
```

사용자 입력을 받는다.

- **번호 선택** (기존 도메인): 해당 도메인의 `name`, `path`/`paths` 필드를 메모리에 저장한다. Step 4로 진행.
- **"N" 또는 새 도메인 텍스트 입력**: 도메인 이름(영소문자, 하이픈/언더스코어 허용)을 입력받고, 다음 질문으로 이동한다.

  ```
  도메인 설명을 입력하세요 (선택, 빈칸 엔터로 건너뜀):
  ```

  입력 후 `new_domain = { name, description }` 으로 메모리에 저장. Step 4로 진행.

### Step 4: 타입 선택

```
추가할 타입을 선택하세요:

  1. Object Type  — 비즈니스 엔티티 (예: User, Product)
  2. Link Type    — 엔티티 간 관계 (예: places, contains)
  3. Action Type  — 트리거 가능한 행위 (예: send_welcome_email)

번호를 입력하세요:
```

선택값(`object` / `link` / `action`)을 메모리에 저장하고 해당 Step으로 이동한다.

---

### Step 5-A: Object Type 정보 수집

아래 질문을 **한 번에 하나씩** 순서대로 한다.

1. **이름과 설명** (PascalCase):
   ```
   Object Type 이름과 설명을 입력하세요.
   (형식: "이름, 설명"  예: "Product, 판매 상품"  /  설명 없이: "Product")
   ```

   이름이 PascalCase(첫 글자 대문자, 이후 영문/숫자, 공백·언더스코어·하이픈 없음)가 아니면 즉시 재질의한다:
   ```
   이름은 PascalCase여야 합니다(예: Product). 다시 입력하세요:
   ```
   올바른 값이 입력될 때까지 반복한다.

3. **Properties 반복 수집**: 아래 프롬프트를 반복한다.

   ```
   Property 이름을 입력하세요 (완료하려면 빈칸 엔터):
   ```

   이름이 입력되면 순서대로:

   ```
   타입을 선택하세요:
     1. string
     2. int
     3. float
     4. boolean
     5. date
     6. datetime
   번호를 입력하세요:
   ```

   ```
   Primary key로 설정할까요? (y/n, 기본값 n):
   ```

   ```
   Computed 속성인가요? (y/n, 기본값 n):
   ```

   - `computed: true`는 `y` 입력 시에만 필드를 포함한다.
   - `computed: true` 선택 시 expression을 추가로 질문한다:
     ```
     계산식을 입력하세요 (예: "gross_amount - fee", 모르면 빈칸 엔터로 건너뜀):
     ```
     입력값이 있으면 `expression` 필드에 저장한다.

   그 다음 description을 질문한다:
   ```
   이 필드의 설명을 입력하세요 (의미·허용값·맥락 등, 생략하려면 빈칸 엔터):
   ```
   입력값이 있으면 해당 property의 `description` 필드에 저장한다. 빈칸이면 필드를 생략한다.

   - Property를 하나 이상 수집한 후 이름 입력에서 빈칸 엔터가 오면 수집 종료.

수집된 데이터를 `new_entry` 객체로 메모리에 저장:
```yaml
name: <PascalCase 이름>
description: "<설명>"      # 설명이 있는 경우만 포함
properties:
  - name: <property_name>
    type: <type>
    description: "<설명>"  # 설명이 입력된 경우만 포함
    primary: true           # primary=true인 경우만 포함
    computed: true          # computed=true인 경우만 포함
    expression: "<식>"      # computed=true이고 expression이 입력된 경우만 포함
```

---

### Step 5-B: Link Type 정보 수집

아래 질문을 **한 번에 하나씩** 순서대로 한다.

현재 도메인에서 알려진 Object Type 이름 목록을 Step 6 전에 미리 참조용으로 보여준다 (기존 도메인인 경우, 신규 도메인이면 생략).

1. **이름** (소문자 단어, 언더스코어 허용):
   ```
   Link Type 이름을 입력하세요 (동사형, 예: places, contains):
   ```

   입력값이 소문자 단어(언더스코어 허용, 숫자 가능, 대문자·공백·하이픈 불가)가 아니면 즉시 재질의한다:
   ```
   이름은 소문자와 언더스코어만 허용됩니다(예: places, has_order). 다시 입력하세요:
   ```
   올바른 값이 입력될 때까지 반복한다.

2. **from** (출발 Object Type):
   ```
   from Object Type을 입력하세요 (예: User):
   ```

3. **to** (도착 Object Type):
   ```
   to Object Type을 입력하세요 (예: Order):
   ```

4. **cardinality**:
   ```
   관계 카디널리티를 선택하세요:
     1. one_to_one
     2. one_to_many
     3. many_to_many
     4. many_to_one
   번호를 입력하세요:
   ※ many_to_one은 from/to를 반전한 one_to_many로도 표현 가능
   ```

5. **설명**:
   ```
   설명을 입력하세요 (선택, 빈칸 엔터로 건너뜀):
   ```

수집된 데이터를 `new_entry` 객체로 메모리에 저장:
```yaml
name: <이름>
from: <ObjectType>
to: <ObjectType>
cardinality: <cardinality>
description: "<설명>"      # 설명이 있는 경우만 포함
```

---

### Step 5-C: Action Type 정보 수집

아래 질문을 **한 번에 하나씩** 순서대로 한다.

1. **이름** (snake_case):
   ```
   Action Type 이름을 입력하세요 (snake_case, 예: send_welcome_email):
   ```

   입력값이 snake_case(소문자와 언더스코어만, 숫자 허용, 대문자·공백·하이픈 불가)가 아니면 즉시 재질의한다:
   ```
   이름은 snake_case여야 합니다(예: send_email). 다시 입력하세요:
   ```
   올바른 값이 입력될 때까지 반복한다.

2. **설명**:
   ```
   설명을 입력하세요 (선택, 빈칸 엔터로 건너뜀):
   ```

3. **target** (대상 Object Type):
   ```
   대상 Object Type을 입력하세요 (예: User):
   ```

4. **trigger**:
   ```
   트리거 조건을 선택하세요:
     1. object_created
     2. object_updated
     3. object_deleted
     4. manual
   번호를 입력하세요:
   ```

   `object_updated` 선택 시 trigger_condition을 추가로 질문한다:
   ```
   어떤 필드의 변화 시 트리거됩니까? (예: status, 모르면 빈칸 엔터로 건너뜀):
   ```
   필드명이 입력되면:
   ```
   변화 전 값 (from, 예: calculated, 모르면 빈칸 엔터로 건너뜀):
   ```
   ```
   변화 후 값 (to, 예: approved, 모르면 빈칸 엔터로 건너뜀):
   ```
   field, from, to 중 하나라도 입력되었으면 `trigger_condition: {field, from, to}` 으로 저장한다.

5. **Parameters 반복 수집**: 아래 프롬프트를 반복한다.

   ```
   파라미터를 추가할까요? (y/n):
   ```

   `y`면 순서대로 질문한다:

   ```
   파라미터 이름을 입력하세요:
   ```

   ```
   타입을 선택하세요:
     1. string
     2. int
     3. float
     4. boolean
     5. date
     6. datetime
   번호를 입력하세요:
   ```

   ```
   필수 파라미터인가요? (y/n, 기본값 y):
   ```

   파라미터를 저장한 뒤 다시 "파라미터를 추가할까요?" 프롬프트를 반복한다.
   `n`이면 수집 종료.

수집된 데이터를 `new_entry` 객체로 메모리에 저장:
```yaml
name: <snake_case 이름>
description: "<설명>"      # 설명이 있는 경우만 포함
target: <ObjectType>
trigger: <trigger>
trigger_condition:          # trigger=object_updated이고 하나 이상 입력된 경우만 포함
  field: <field_name>
  from: <value>
  to: <value>
parameters:                 # 파라미터가 하나 이상인 경우만 포함
  - name: <param_name>
    type: <type>
    required: true          # required=false인 경우만 명시, true는 기본값이므로 생략 가능
```

---

### Step 6: 미리보기 및 승인

수집된 `new_entry`를 YAML diff 형식으로 출력한다. 주석에 도메인명과 타입 종류를 명시한다.

**Object Type 예시:**
```yaml
# 추가될 내용 (domain: ecommerce, object_types)
- name: Product
  description: "상품"
  properties:
    - name: product_id
      type: string
      primary: true
    - name: price
      type: float
      description: "판매 가격 (원화 기준)"
    - name: status
      type: string
      description: "상품 상태. 허용값: active, inactive, discontinued"
```

**Link Type 예시:**
```yaml
# 추가될 내용 (domain: ecommerce, link_types)
- name: contains
  from: Order
  to: Product
  cardinality: one_to_many
  description: "주문이 상품을 포함"
```

**Action Type 예시:**
```yaml
# 추가될 내용 (domain: ecommerce, action_types)
- name: send_welcome_email
  description: "신규 사용자에게 환영 메일 발송"
  target: User
  trigger: object_created
  parameters:
    - name: email_template
      type: string
```

그 다음 입력을 요청한다.

```
위 내용으로 추가할까요? (y / n / 수정)
```

- **`n`** → 종료 메시지 출력 후 종료:
  ```
  취소되었습니다.
  ```
- **`수정`** → 수정 가능한 항목 목록을 번호로 출력하고 선택하게 한다:
  ```
  수정할 항목을 선택하세요:
    1. <field_1> (현재: <value_1>)
    2. <field_2> (현재: <value_2>)
    ...
  번호를 입력하세요:
  ```
  예를 들어 Object Type의 경우:
  ```
  수정할 항목을 선택하세요:
    1. name (현재: User)
    2. description (현재: 서비스 사용자)
    3. properties
  번호를 입력하세요:
  ```
  선택된 항목만 재질의한 뒤 Step 6으로 돌아간다.
- **`y`** → Step 7로 진행.

---

### Step 7: YAML 업데이트

#### 7-A: 신규 도메인인 경우

**ontology.yaml 생성**: Write 툴로 `.ontology/domains/<domain_name>/ontology.yaml`을 생성한다.

```yaml
domain: <domain_name>
version: 1
description: "<domain_description>"
object_types: []
link_types: []
action_types: []
```

단, 추가하는 타입 배열에는 `new_entry`를 즉시 포함하여 작성한다. 예를 들어 Object Type을 추가하는 경우:

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

**_index.yaml 업데이트**: Read 툴로 현재 `_index.yaml`을 읽은 뒤 Edit 툴로 `domains: []` 또는 기존 배열 끝에 새 항목을 추가한다.

추가할 항목 형태:
```yaml
  - name: <domain_name>
    description: "<domain_description>"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>   # YYYY-MM-DD 형식
```

`domains: []`인 경우 아래와 같이 교체한다:
```yaml
domains:
  - name: <domain_name>
    description: "<domain_description>"
    path: <domain_name>/ontology.yaml
    last_modified: <today_date>
```

#### 7-B: 기존 도메인 — 마이그레이션 전 (`path` 필드 있음)

대상 파일: `.ontology/domains/<path>` (예: `.ontology/domains/ecommerce/ontology.yaml`)

Read 툴로 파일을 읽고, 타입에 따라 해당 배열 끝에 항목을 추가한다. Edit 툴을 사용한다.

- **Object Type** → `object_types` 배열 끝에 추가
- **Link Type** → `link_types` 배열 끝에 추가
- **Action Type** → `action_types` 배열 끝에 추가

배열이 `[]`(빈 배열)인 경우: Edit 툴로 해당 줄을 아래와 같이 교체한다.

```
old: "object_types: []"
new:
object_types:
  - name: <name>
    ...
```

배열에 기존 항목이 있는 경우: Edit 툴로 배열의 마지막 항목 다음(다음 최상위 키 바로 위)에 새 항목 YAML 블록을 삽입한다.

_index.yaml의 해당 도메인 `last_modified`를 오늘 날짜로 갱신한다 (Edit 툴 사용).

#### 7-C: 기존 도메인 — 마이그레이션 후 (`paths` 필드 있음)

타입에 따라 대상 파일을 결정한다.

| 타입 | 필드 | 파일 경로 예시 |
|------|------|---------------|
| Object Type | `paths.object_types` | `.ontology/domains/ecommerce/object_types.yaml` |
| Link Type | `paths.link_types` | `.ontology/domains/ecommerce/link_types.yaml` |
| Action Type | `paths.action_types` | `.ontology/domains/ecommerce/action_types.yaml` |

실제 경로는 `.ontology/domains/<paths.<type>_types>` 형태로 조합한다.

Read 툴로 해당 파일을 읽고, 배열 끝에 `new_entry`를 추가한다 (Edit 툴 사용). 7-B와 동일한 빈 배열/기존 항목 분기 규칙을 적용한다.

_index.yaml의 해당 도메인 `last_modified`를 오늘 날짜로 갱신한다 (Edit 툴 사용).

---

### Step 8: 글로벌 싱크 체크

- `ask` → `"글로벌 저장소(<global_path>)에도 반영할까요? (y/n)"` → y=실행, n=건너뜀
- `auto` → 즉시 실행
- `off` → 건너뜀

**실행**: 수정된 도메인 파일(들) + `_index.yaml`을 `<global_path>/domains/` 경로에 Write 복사.
- 마이그레이션 전: `<global_path>/domains/<domain_name>/ontology.yaml`
- 마이그레이션 후: 수정된 타입 파일 1개
- `<global_path>/domains/_index.yaml`도 덮어쓰기

---

### Step 9: 완료 메시지

```
✓ [<domain_name>] 에 <entry_name> (<type_label>) 추가 완료 → .ontology/domains/<domain_name>/ontology.yaml
```

`<type_label>` 매핑:
- Object Type → `Object Type`
- Link Type → `Link Type`
- Action Type → `Action Type`

파일 경로는 실제 수정된 파일의 경로를 출력한다 (마이그레이션 후 도메인의 경우 해당 타입 파일 경로).

---

## Common Mistakes

- **여러 질문을 한꺼번에 출력** → 반드시 한 번에 하나씩 질문하고 응답을 기다린다.
- **`computed: false` 또는 `primary: false` 명시** → `false`인 경우 해당 필드 자체를 생략한다. `true`일 때만 포함한다.
- **_index.yaml `last_modified` 갱신 누락** → YAML 파일 수정 후 반드시 갱신한다.
- **신규 도메인 path 형식** → `_index.yaml`의 `path` 값은 `<domain_name>/ontology.yaml` 형태 (앞에 `domains/` 없음).
- **이름 형식 검증 누락** → Object Type=PascalCase, Action Type=snake_case, Link Type=소문자+언더스코어. 위반 시 올바른 값이 입력될 때까지 재질의한다.
