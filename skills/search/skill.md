---
name: ontologian:search
description: Use when the user runs /ontologian:search or wants to search for a keyword across all ontology domains (object types, link types, action types).
---

# Ontologian — Search

## Overview

키워드로 온톨로지 전체를 검색한다. 모든 도메인의 Object Type, Link Type, Action Type을 대상으로 대소문자 무시 검색을 수행하고, 결과를 도메인별로 그룹핑하여 출력한다.

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/domains/_index.yaml` → 없으면 `"온톨로지가 초기화되지 않았습니다."` 출력 후 종료.

---

### Step 2: 키워드 및 필터 확인

인자에서 키워드와 필터 옵션을 파싱한다.

- `--type=object|link|action` → 해당 타입만 검색
- `--domain=<name>` → 해당 도메인만 검색
- 나머지 텍스트 → 키워드

예: `/ontologian:search User --type=object --domain=ecommerce`

인자가 없으면 질의:
```
검색할 키워드를 입력하세요:
```

키워드, 타입 필터, 도메인 필터를 저장하고 Step 3으로 진행.

---

### Step 3: _index.yaml 읽기 및 도메인 파일 로드

Read `.ontology/domains/_index.yaml`. `domains` 배열이 비어있으면 `"등록된 도메인이 없습니다."` 출력 후 종료.

`--domain` 필터가 있으면 해당 도메인만 처리. `domains` 배열을 순회하며 파일 Read.

**path/paths 분기:**
- `path` 있으면 → `.ontology/domains/<path>` Read (object_types, link_types, action_types 모두 포함)
- `paths` 있으면 → `.ontology/domains/<paths.object_types>`, `<paths.link_types>`, `<paths.action_types>` 각 Read

타입 데이터를 도메인별로 메모리에 저장. 파일 Read 실패 시 해당 도메인 오류 기록 후 계속.

---

### Step 4: 키워드 검색

저장된 데이터를 도메인별로 순회하며 키워드를 대소문자 무시로 검색한다.
`--type` 필터가 있으면 해당 타입 배열만 검색.

검색 대상 필드:

| 타입 | 검색 필드 |
|------|-----------|
| Object Type | `name`, `description`, `properties[].name` |
| Link Type | `name`, `description`, `from`, `to` |
| Action Type | `name`, `description`, `target`, `parameters[].name` |

매칭된 항목을 도메인별로 수집한다.

---

### Step 5: 결과 출력

#### 결과가 없는 경우

```
키워드 '<keyword>'에 해당하는 항목이 없습니다.
```

#### 결과가 있는 경우

도메인별로 그룹핑하여 출력한다. 각 항목은 타입 레이블과 핵심 필드를 요약하여 표시한다.

**출력 형식:**

```
## 검색 결과: "<keyword>"

### 도메인: <domain_name>
[Object Type] <name>
  설명: <description>
  Properties: <prop1_name> (<type>[, PK][, computed]), <prop2_name> (<type>), ...

[Link Type] <name>
  <from> → <to> (<cardinality>)
  설명: <description>

[Action Type] <name>
  설명: <description>
  대상: <target> / 트리거: <trigger>

### 도메인: <domain_name2>
...

총 <N>건 (Object: <N>, Link: <N>, Action: <N>)

(일부 도메인 로드 실패: <이름1>, <이름2>)  ← 로드 실패한 도메인이 있을 때만 표시
```

**필드 출력 규칙:**
- `description`이 없는 항목은 설명 줄을 생략한다.
- Object Type의 `properties`는 한 줄로 요약한다. `primary: true`이면 `PK`, `computed: true`이면 `computed`를 괄호 안에 표기한다. properties가 없으면 생략한다.
- Link Type의 `cardinality`가 없으면 화살표(`→`)만 표기한다.
- Action Type의 `trigger`가 없으면 대상만 표기한다.
- 각 타입별 매칭 항목이 없는 경우 해당 타입 섹션을 생략한다.

---

## 출력 예시

```
## 검색 결과: "User"

### 도메인: ecommerce
[Object Type] User
  설명: 서비스 사용자
  Properties: user_id (string, PK), email (string), churn_score (float, computed)

[Link Type] places
  User → Order (one_to_many)
  설명: 사용자가 주문을 생성

총 2건 (Object: 1, Link: 1, Action: 0)
```

---

## Common Mistakes

- **대소문자 구분 검색** → 키워드 검색은 반드시 대소문자 무시(case-insensitive)로 수행한다.
- **도메인 파일 읽기 실패 시 전체 중단** → 특정 도메인 실패해도 나머지 계속. 실패한 도메인은 결과 하단에 `(일부 도메인 로드 실패: <이름>)` 경고 표시.
- **총계 누락** → 결과 출력 마지막에 반드시 총 건수와 타입별 건수를 출력한다.
