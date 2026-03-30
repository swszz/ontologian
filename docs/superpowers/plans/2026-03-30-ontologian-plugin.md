# Ontologian Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `.claude/plugins/ontologian/` 아래에 온톨로지 지식 저장소를 관리하는 Claude Code 슬래시 커맨드 스킬 7개를 작성한다.

**Architecture:** 각 Skill은 독립적인 Markdown 파일로, Claude가 직접 해석한다. `.ontology/` 디렉토리를 소스 오브 트루스로 사용하며, Claude의 기본 툴(Read, Write, Edit, Grep, Glob)로만 YAML을 조작한다. 외부 의존성 없음.

**Tech Stack:** Markdown (skill 정의), YAML (데이터 저장), Claude Code 기본 툴

---

## 파일 구조

```
.claude/plugins/ontologian/skills/
├── ontologian/skill.md    → /ontologian  (도메인 목록 + 상태 요약)
├── add/skill.md           → /ontologian:add  (새 타입 추가)
├── search/skill.md        → /ontologian:search  (키워드 검색)
├── validate/skill.md      → /ontologian:validate  (무결성 검증)
├── sync/skill.md          → /ontologian:sync  (글로벌 싱크)
├── migrate/skill.md       → /ontologian:migrate  (타입별 파일 분리)
└── visualize/skill.md     → /ontologian:visualize  (관계 다이어그램)
```

**저장소 구조 (런타임 생성):**
```
<project-root>/.ontology/
├── config.yaml
├── domains/
│   ├── _index.yaml
│   └── <domain-name>/
│       └── ontology.yaml       # 기본. migrate 후엔 타입별 파일로 분리됨
└── migrations/
    └── YYYY-MM-DD-<desc>.log
```

---

## 공통 규칙 (모든 Task에서 반드시 숙지)

### .ontology/ 초기화 체크
모든 쓰기 스킬(add, sync, migrate)은 `.ontology/` 가 없으면 먼저 초기화를 제안한다:
```
.ontology/ 디렉토리가 없습니다. 지금 초기화할까요? (y/n)
```
초기화 시 아래 파일을 생성한다:

**.ontology/config.yaml:**
```yaml
version: 1
global_sync: ask   # ask | auto | off
global_path: ~/.ontologian
```

**.ontology/domains/_index.yaml:**
```yaml
domains: []
```

### global_sync 플로우
쓰기 작업(add, migrate) 완료 후:
1. `.ontology/config.yaml` 의 `global_sync` 값 확인
2. `ask` → "글로벌 저장소(`~/.ontologian`)에도 반영할까요?" 질의
3. `auto` → 바로 싱크 실행
4. `off` → 아무것도 하지 않음

### YAML diff 표시 형식
쓰기 전 항상 이 형태로 보여준다:
```yaml
# 추가될 내용 (domain: ecommerce, object_types)
- name: Product
  description: "상품"
  properties:
    - name: product_id
      type: string
      primary: true
```

### _index.yaml 업데이트
도메인에 변경이 발생할 때마다 `_index.yaml` 의 해당 도메인 `last_modified` 를 오늘 날짜로 갱신한다.

---

## Task 1: 메인 overview 스킬 (`/ontologian`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/ontologian/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/ontologian/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: ontologian
description: 현재 프로젝트의 온톨로지 도메인 목록과 상태를 요약해서 보여준다. /ontologian 으로 호출.
---

# Ontologian — Overview

프로젝트 온톨로지 저장소의 전체 상태를 조회한다.

## 절차

1. `{PROJECT_ROOT}/.ontology/` 디렉토리 존재 여부 확인 (Glob: `.ontology/config.yaml`)
   - 없으면: "아직 온톨로지가 초기화되지 않았습니다. `/ontologian:add` 로 첫 번째 타입을 추가하면 자동으로 초기화됩니다." 출력 후 종료

2. `.ontology/config.yaml` 읽기 (Read)

3. `.ontology/domains/_index.yaml` 읽기 (Read)
   - `domains` 배열이 비어 있으면: "등록된 도메인이 없습니다. `/ontologian:add` 로 추가하세요." 출력 후 종료

4. 각 도메인의 `ontology.yaml` 읽기 (Read) — 마이그레이션된 도메인은 `object_types.yaml`, `link_types.yaml`, `action_types.yaml` 을 각각 읽는다

5. 아래 형식으로 출력:

```
## Ontologian — 온톨로지 현황

설정:
  글로벌 싱크: ask | auto | off
  글로벌 경로: ~/.ontologian

도메인 목록:
┌────────────────┬──────────┬──────────┬──────────┬──────────────────┐
│ 도메인         │ Objects  │ Links    │ Actions  │ 마지막 수정       │
├────────────────┼──────────┼──────────┼──────────┼──────────────────┤
│ ecommerce      │ 3        │ 2        │ 1        │ 2026-03-30       │
│ hr             │ 2        │ 1        │ 0        │ 2026-03-29       │
└────────────────┴──────────┴──────────┴──────────┴──────────────────┘

총 도메인: 2 | 총 Object Types: 5 | 총 Link Types: 3 | 총 Action Types: 1

사용 가능한 커맨드:
  /ontologian:add       — 새 타입 추가
  /ontologian:search    — 키워드 검색
  /ontologian:validate  — 무결성 검증
  /ontologian:sync      — 글로벌 싱크
  /ontologian:migrate   — 타입별 파일 분리
  /ontologian:visualize — 관계 다이어그램
```
```

- [ ] **Step 2: 디렉토리 구조 확인**

파일이 올바른 경로에 생성됐는지 확인:
```bash
ls .claude/plugins/ontologian/skills/ontologian/
```
Expected: `skill.md`

- [ ] **Step 3: 커밋**

```bash
git add .claude/plugins/ontologian/skills/ontologian/skill.md
git commit -m "feat(ontologian): add main overview skill"
```

---

## Task 2: Add 스킬 (`/ontologian:add`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/add/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/add/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: add
description: 온톨로지에 새 Object Type, Link Type, 또는 Action Type을 대화형으로 추가한다. /ontologian:add 로 호출.
---

# Ontologian — Add

온톨로지에 새 타입을 추가한다. 모든 쓰기는 사용자 승인 후 실행한다.

## 절차

### 0. 초기화 체크

Glob으로 `.ontology/config.yaml` 존재 확인.
없으면:
> ".ontology/ 디렉토리가 없습니다. 지금 초기화할까요? (y/n)"

승인 시 아래 파일 생성:

**.ontology/config.yaml:**
```yaml
version: 1
global_sync: ask
global_path: ~/.ontologian
```

**.ontology/domains/_index.yaml:**
```yaml
domains: []
```

거절 시 종료.

### 1. 도메인 선택

`.ontology/domains/_index.yaml` 읽기.

기존 도메인이 있으면:
> "어느 도메인에 추가할까요?
> 기존: ecommerce, hr
> 새 도메인 이름을 입력하거나 기존 도메인명을 선택하세요:"

없으면:
> "첫 번째 도메인 이름을 입력하세요 (예: ecommerce, hr, logistics):"

### 2. 타입 선택

> "어떤 타입을 추가할까요?
> (A) Object Type — 실세계 엔티티 (예: User, Order, Product)
> (B) Link Type — 객체 간 관계 (예: User places Order)
> (C) Action Type — 실행 가능한 동작 (예: send_welcome_email)"

### 3-A. Object Type 정보 수집

순서대로 한 번에 하나씩 질의:
1. "Object Type 이름을 입력하세요 (PascalCase, 예: Product):"
2. "설명을 입력하세요:"
3. "Properties를 추가할까요? (y/n)"
   - y: 반복해서 property 추가
     - "Property 이름:"
     - "타입 (string / int / float / boolean / date / datetime):"
     - "Primary key입니까? (y/n)"
     - "계산된 값(computed)입니까? (y/n)"
     - "추가 property가 있습니까? (y/n)"

### 3-B. Link Type 정보 수집

순서대로:
1. "Link 이름을 입력하세요 (동사형, 예: places, belongs_to):"
2. "출발 Object Type (from):"
3. "도착 Object Type (to):"
4. "카디널리티 (one_to_one / one_to_many / many_to_many):"
5. "설명:"

### 3-C. Action Type 정보 수집

순서대로:
1. "Action 이름을 입력하세요 (snake_case, 예: send_welcome_email):"
2. "설명:"
3. "트리거 (object_created / object_updated / object_deleted / manual):"
4. "대상 Object Type:"

### 4. 변경 미리보기

수집한 정보로 YAML 스니펫을 생성해 보여준다:

Object Type 예시:
```yaml
# 추가 위치: .ontology/domains/ecommerce/ontology.yaml → object_types
- name: Product
  description: "상품"
  properties:
    - name: product_id
      type: string
      primary: true
    - name: price
      type: float
      computed: false
```

> "위 내용을 추가할까요? (y/n/수정)"
- `수정` 입력 시 어느 항목을 수정할지 재질의

### 5. YAML 파일 업데이트

승인 시:

**신규 도메인인 경우:**
- `.ontology/domains/<domain>/` 디렉토리가 없으면 ontology.yaml 신규 생성:
```yaml
domain: <domain>
version: 1
description: ""

object_types: []
link_types: []
action_types: []
```
- `_index.yaml` 에 도메인 추가:
```yaml
domains:
  - name: <domain>
    description: ""
    path: <domain>/ontology.yaml
    last_modified: <오늘 날짜 YYYY-MM-DD>
```

**기존 도메인인 경우:**
- 해당 도메인 ontology.yaml 읽기
- 마이그레이션된 도메인(타입별 파일 분리됨)이면 해당 타입 파일에 추가
- 아니면 ontology.yaml 의 해당 타입 배열에 항목 추가 (Edit 툴)
- `_index.yaml` 의 `last_modified` 갱신

### 6. 글로벌 싱크 체크

`.ontology/config.yaml` 의 `global_sync` 확인:
- `ask` → "글로벌 저장소(`~/.ontologian`)에도 반영할까요? (y/n)"
  - y: `~/.ontologian/domains/<domain>/` 에 동일 파일 복사 (Write)
- `auto` → 자동으로 싱크 실행
- `off` → 아무것도 하지 않음

완료 메시지:
> "✓ [도메인명] 에 [타입명] ([타입종류]) 추가 완료"
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/add/skill.md
git commit -m "feat(ontologian): add 'add' skill for creating ontology types"
```

---

## Task 3: Search 스킬 (`/ontologian:search`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/search/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/search/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: search
description: 키워드로 온톨로지 전체를 검색한다. /ontologian:search <keyword> 로 호출.
---

# Ontologian — Search

키워드로 Object Type, Property, Link Type, Action Type을 검색한다.

## 절차

### 1. 키워드 확인

사용자가 `/ontologian:search User` 처럼 인자를 줬으면 그대로 사용.
인자가 없으면:
> "검색 키워드를 입력하세요:"

### 2. .ontology/ 존재 확인

Glob으로 `.ontology/domains/_index.yaml` 확인.
없으면: "온톨로지가 초기화되지 않았습니다. `/ontologian:add` 로 시작하세요." 출력 후 종료.

### 3. 전체 도메인 순회

`.ontology/domains/_index.yaml` 읽기 → 각 도메인 ontology.yaml 읽기.
(마이그레이션된 도메인은 object_types.yaml, link_types.yaml, action_types.yaml 각각 읽기)

각 파일에서 키워드를 대소문자 무시하고 아래 필드에서 검색:
- object_types: name, description, properties[].name
- link_types: name, description, from, to
- action_types: name, description, target

### 4. 결과 출력

매칭된 항목이 없으면: "키워드 '[keyword]' 에 해당하는 항목을 찾지 못했습니다."

있으면 도메인별로 그룹핑해서 출력:

```
## 검색 결과: "User"

### 도메인: ecommerce

[Object Type] User
  설명: 서비스 사용자
  Properties: user_id (string, primary), email (string), churn_score (float, computed)

[Link Type] places
  User → Order (one_to_many)
  설명: 사용자가 주문을 생성

[Action Type] send_welcome_email
  대상: User | 트리거: object_created
  설명: 신규 사용자에게 환영 메일 발송

총 3건 (Object: 1, Link: 1, Action: 1)
```
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/search/skill.md
git commit -m "feat(ontologian): add 'search' skill"
```

---

## Task 4: Validate 스킬 (`/ontologian:validate`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/validate/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/validate/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: validate
description: 온톨로지 YAML 파일의 스키마와 참조 무결성을 검증한다. /ontologian:validate 로 호출.
---

# Ontologian — Validate

모든 도메인의 YAML 파일을 읽어 스키마와 관계 무결성을 검증한다.

## 절차

### 1. .ontology/ 존재 확인

Glob으로 `.ontology/domains/_index.yaml` 확인.
없으면: "온톨로지가 초기화되지 않았습니다." 출력 후 종료.

### 2. 모든 도메인 로드

`_index.yaml` 읽기 → 각 도메인 파일 읽기.

### 3. 검증 규칙 실행

각 도메인에 대해 아래를 순서대로 체크한다:

**[스키마 검증]**
- Object Type 필수 필드: `name`, `description`
- Property 필수 필드: `name`, `type`
- Property `type` 허용값: `string`, `int`, `float`, `boolean`, `date`, `datetime`
- Link Type 필수 필드: `name`, `from`, `to`, `cardinality`
- Link Type `cardinality` 허용값: `one_to_one`, `one_to_many`, `many_to_many`
- Action Type 필수 필드: `name`, `description`, `trigger`, `target`
- Action Type `trigger` 허용값: `object_created`, `object_updated`, `object_deleted`, `manual`

**[참조 무결성]**
- Link Type의 `from`, `to` 가 같은 도메인의 Object Type으로 존재하는지 확인
- Action Type의 `target` 이 같은 도메인의 Object Type으로 존재하는지 확인

**[중복 검사]**
- 같은 도메인 내 Object Type 이름 중복 없는지
- 같은 도메인 내 Link Type 이름 중복 없는지
- 같은 도메인 내 Action Type 이름 중복 없는지

### 4. 결과 출력

오류 없으면:
```
✓ 모든 도메인 검증 통과 (2개 도메인, 5 Objects, 3 Links, 1 Action)
```

오류 있으면:
```
✗ 검증 실패 — 3개 오류 발견

[ecommerce] Link Type 'places'
  → to: 'Order' 가 Object Type으로 존재하지 않습니다.

[ecommerce] Object Type 'User'
  → Property 'score' 의 type 'numeric' 은 허용되지 않습니다. (허용: string, int, float, boolean, date, datetime)

[hr] Action Type 'archive_employee'
  → target: 'Staff' 가 Object Type으로 존재하지 않습니다.
```
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/validate/skill.md
git commit -m "feat(ontologian): add 'validate' skill"
```

---

## Task 5: Sync 스킬 (`/ontologian:sync`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/sync/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/sync/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: sync
description: 프로젝트 로컬 온톨로지를 전역 저장소(~/.ontologian)에 싱크한다. /ontologian:sync 로 호출.
---

# Ontologian — Sync

로컬 `.ontology/` 를 전역 `~/.ontologian/` 에 수동으로 싱크한다.

## 절차

### 1. 로컬 저장소 확인

Glob으로 `.ontology/config.yaml` 확인.
없으면: "로컬 온톨로지가 초기화되지 않았습니다." 출력 후 종료.

### 2. config 읽기

`.ontology/config.yaml` 읽기 → `global_path` 값 확인 (기본: `~/.ontologian`).

### 3. 싱크 대상 미리보기

`.ontology/domains/_index.yaml` 읽기. 각 도메인 파일 목록 확인.

아래 형식으로 보여준다:
```
## 싱크 미리보기

로컬 → 글로벌 (~/.ontologian)

  ecommerce/ontology.yaml       → ~/.ontologian/domains/ecommerce/ontology.yaml
  hr/ontology.yaml              → ~/.ontologian/domains/hr/ontology.yaml
  domains/_index.yaml           → ~/.ontologian/domains/_index.yaml

총 3개 파일
```

> "진행할까요? (y/n)"

### 4. 싱크 실행

승인 시:
- `~/.ontologian/domains/` 디렉토리가 없으면 config와 함께 생성
  - `~/.ontologian/config.yaml` 생성 (없을 때만):
    ```yaml
    version: 1
    ```
- 각 도메인 디렉토리 및 파일을 Write 툴로 복사
- `_index.yaml` 복사

완료 메시지:
```
✓ 싱크 완료: 3개 파일 → ~/.ontologian
```

### 5. 오류 처리

파일 읽기/쓰기 실패 시 해당 파일명과 오류 내용을 출력하고 나머지 파일은 계속 진행.
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/sync/skill.md
git commit -m "feat(ontologian): add 'sync' skill"
```

---

## Task 6: Migrate 스킬 (`/ontologian:migrate`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/migrate/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/migrate/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: migrate
description: 도메인 단일 ontology.yaml을 object_types.yaml, link_types.yaml, action_types.yaml 3개 파일로 분리한다. /ontologian:migrate 로 호출.
---

# Ontologian — Migrate

도메인의 `ontology.yaml` 을 타입별 파일로 분리해 관리한다. 규모가 커진 도메인에 사용.

## 절차

### 1. .ontology/ 존재 확인

Glob으로 `.ontology/config.yaml` 확인.
없으면: "로컬 온톨로지가 초기화되지 않았습니다." 출력 후 종료.

### 2. 대상 도메인 선택

`_index.yaml` 읽기.

이미 분리된 도메인(ontology.yaml 없이 타입별 파일 존재)은 목록에서 제외.

분리 가능한 도메인 목록 출력:
```
분리 가능한 도메인:
  1. ecommerce  (Objects: 5, Links: 3, Actions: 2)
  2. hr         (Objects: 2, Links: 1, Actions: 0)

어느 도메인을 분리할까요? (번호 또는 이름)
```

### 3. 분리 미리보기

선택된 도메인의 `ontology.yaml` 읽기.

아래 형식으로 보여준다:
```
## 마이그레이션 미리보기: ecommerce

생성될 파일:
  .ontology/domains/ecommerce/object_types.yaml   (5개 항목)
  .ontology/domains/ecommerce/link_types.yaml     (3개 항목)
  .ontology/domains/ecommerce/action_types.yaml   (2개 항목)

삭제될 파일:
  .ontology/domains/ecommerce/ontology.yaml

_index.yaml 업데이트:
  path: ecommerce/ontology.yaml
  → paths:
      object_types: ecommerce/object_types.yaml
      link_types: ecommerce/link_types.yaml
      action_types: ecommerce/action_types.yaml
```

> "진행할까요? (y/n)"

### 4. 분리 실행

승인 시:

**object_types.yaml 생성:**
```yaml
domain: <domain>
version: 1

object_types:
  # 기존 ontology.yaml 의 object_types 내용 그대로
```

**link_types.yaml 생성:**
```yaml
domain: <domain>
version: 1

link_types:
  # 기존 ontology.yaml 의 link_types 내용 그대로
```

**action_types.yaml 생성:**
```yaml
domain: <domain>
version: 1

action_types:
  # 기존 ontology.yaml 의 action_types 내용 그대로
```

**_index.yaml 업데이트:**
해당 도메인의 `path` 필드를 `paths` 로 교체:
```yaml
- name: ecommerce
  description: "이커머스 도메인"
  paths:
    object_types: ecommerce/object_types.yaml
    link_types: ecommerce/link_types.yaml
    action_types: ecommerce/action_types.yaml
  last_modified: <오늘 날짜>
```

**기존 ontology.yaml 삭제:**
Write 툴로 빈 파일을 쓰지 말고, 사용자에게 직접 삭제 안내:
> "분리가 완료됐습니다. 기존 파일을 삭제하려면:
> `rm .ontology/domains/ecommerce/ontology.yaml`"

### 5. 마이그레이션 로그 기록

`.ontology/migrations/` 에 로그 파일 생성:

파일명: `YYYY-MM-DD-split-<domain>.log`
내용:
```
date: <오늘 날짜>
domain: ecommerce
action: split_ontology_yaml
files_created:
  - ecommerce/object_types.yaml
  - ecommerce/link_types.yaml
  - ecommerce/action_types.yaml
file_removed: ecommerce/ontology.yaml
```

### 6. 글로벌 싱크 체크

`config.global_sync` 확인 → 공통 규칙의 글로벌 싱크 플로우 실행.
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/migrate/skill.md
git commit -m "feat(ontologian): add 'migrate' skill"
```

---

## Task 7: Visualize 스킬 (`/ontologian:visualize`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/visualize/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/visualize/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: visualize
description: 도메인 온톨로지의 Object 관계를 텍스트 다이어그램으로 출력한다. /ontologian:visualize 로 호출.
---

# Ontologian — Visualize

도메인의 Object Type과 Link Type을 ASCII 다이어그램으로 시각화한다.

## 절차

### 1. .ontology/ 존재 확인

Glob으로 `.ontology/domains/_index.yaml` 확인.
없으면: "온톨로지가 초기화되지 않았습니다." 출력 후 종료.

### 2. 도메인 선택

`_index.yaml` 읽기.

도메인이 1개면 자동 선택.
2개 이상이면:
```
어느 도메인을 시각화할까요?
  1. ecommerce
  2. hr
  (전체: all)
```

### 3. 도메인 데이터 읽기

선택된 도메인의 ontology.yaml (또는 분리된 경우 object_types.yaml + link_types.yaml) 읽기.

### 4. 다이어그램 렌더링

**Object Types 목록:**
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
│   ├─ order_id: string (PK)          │
│   └─ total: float                   │
│                                     │
│  [Product]                          │
│   └─ product_id: string (PK)        │
└─────────────────────────────────────┘
```

**Link Types 관계도:**
```
RELATIONSHIPS

  [User] ──(places, 1:N)──▶ [Order]
  [Order] ──(contains, N:M)──▶ [Product]
```

카디널리티 표기:
- `one_to_one` → `1:1`
- `one_to_many` → `1:N`
- `many_to_many` → `N:M`

**Action Types:**
```
ACTIONS

  send_welcome_email
   └─ 트리거: object_created → [User]

  process_order
   └─ 트리거: object_created → [Order]
```

### 5. `all` 선택 시

도메인별로 위 형식을 반복 출력. 도메인 간 구분선 추가:
```
════════════════════════════════════
```
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/visualize/skill.md
git commit -m "feat(ontologian): add 'visualize' skill"
```

---

## Task 8: 예시 온톨로지 데이터 생성

실제 플러그인이 동작하는지 검증할 수 있도록 예시 `.ontology/` 를 생성한다.

**Files:**
- Create: `.ontology/config.yaml`
- Create: `.ontology/domains/_index.yaml`
- Create: `.ontology/domains/ecommerce/ontology.yaml`

- [ ] **Step 1: config.yaml 생성**

`.ontology/config.yaml`:
```yaml
version: 1
global_sync: ask
global_path: ~/.ontologian
```

- [ ] **Step 2: _index.yaml 생성**

`.ontology/domains/_index.yaml`:
```yaml
domains:
  - name: ecommerce
    description: "이커머스 도메인 예시"
    path: ecommerce/ontology.yaml
    last_modified: 2026-03-30
```

- [ ] **Step 3: 예시 ontology.yaml 생성**

`.ontology/domains/ecommerce/ontology.yaml`:
```yaml
domain: ecommerce
version: 1
description: "이커머스 도메인 온톨로지 예시"

object_types:
  - name: User
    description: "서비스 사용자"
    properties:
      - name: user_id
        type: string
        primary: true
      - name: email
        type: string
      - name: churn_score
        type: float
        computed: true

  - name: Order
    description: "주문"
    properties:
      - name: order_id
        type: string
        primary: true
      - name: total
        type: float
      - name: created_at
        type: datetime

  - name: Product
    description: "상품"
    properties:
      - name: product_id
        type: string
        primary: true
      - name: name
        type: string
      - name: price
        type: float

link_types:
  - name: places
    from: User
    to: Order
    cardinality: one_to_many
    description: "사용자가 주문을 생성"

  - name: contains
    from: Order
    to: Product
    cardinality: many_to_many
    description: "주문이 상품을 포함"

action_types:
  - name: send_welcome_email
    description: "신규 사용자에게 환영 메일 발송"
    trigger: object_created
    target: User

  - name: notify_order_created
    description: "주문 생성 알림 발송"
    trigger: object_created
    target: Order
```

- [ ] **Step 4: 커밋**

```bash
git add .ontology/
git commit -m "feat(ontologian): add example ecommerce ontology"
```

---

## Task 9: Analyze 스킬 (`/ontologian:analyze`)

**Files:**
- Create: `.claude/plugins/ontologian/skills/analyze/skill.md`

- [ ] **Step 1: 스킬 파일 생성**

`.claude/plugins/ontologian/skills/analyze/skill.md` 를 아래 내용으로 작성한다:

```markdown
---
name: analyze
description: 자유형식 비즈니스 요구사항을 분석해 Object/Link/Action Type을 도출하고, 사용자와 인터랙션으로 정보를 완성한 뒤 온톨로지에 추가한다. /ontologian:analyze 로 호출.
---

# Ontologian — Analyze

비즈니스 요구사항 텍스트를 입력받아, 온톨로지 구조를 도출하고 사용자와 대화를 통해 정보를 완성한 뒤 저장한다.

이 스킬은 `/ontologian:add` 와 달리 사용자가 구조를 미리 알 필요 없다. Claude가 요구사항을 분석해서 후보 구조를 먼저 제안한다.

## 절차

### 0. 초기화 체크

Glob으로 `.ontology/config.yaml` 존재 확인.
없으면:
> ".ontology/ 디렉토리가 없습니다. 지금 초기화할까요? (y/n)"

승인 시 아래 파일 생성:

**.ontology/config.yaml:**
```yaml
version: 1
global_sync: ask
global_path: ~/.ontologian
```

**.ontology/domains/_index.yaml:**
```yaml
domains: []
```

거절 시 종료.

### 1. 요구사항 수집

사용자가 인자 없이 호출했으면:
> "분석할 비즈니스 요구사항을 자유롭게 설명해주세요.
> 예: '고객이 상품을 장바구니에 담고 결제할 수 있어야 한다. 주문 완료 시 이메일 알림을 보낸다.'"

인자로 텍스트를 직접 넘겼으면 그대로 사용.

### 2. 1차 분석 — 후보 도출

요구사항에서 아래 패턴으로 후보를 추출한다:

**Object Type 후보:**
- 명사 / 명사구 중 실세계 엔티티로 볼 수 있는 것
- "~이/가", "~을/를" 의 주체·대상이 되는 개념
- 예: "고객", "상품", "장바구니", "주문"

**Link Type 후보:**
- 두 명사 사이의 동사 관계
- 예: "고객이 상품을 담는다" → Customer -[adds_to_cart]→ Product
- 카디널리티는 문맥에서 유추 (복수형, "여러", "하나의" 등)

**Action Type 후보:**
- "~한다", "~를 보낸다", "~를 처리한다" 등 실행 가능한 동작
- 예: "이메일 알림을 보낸다" → send_order_email (trigger: object_created, target: Order)

### 3. 분석 결과 발표

도출한 후보를 아래 형식으로 보여준다:

```
## 요구사항 분석 결과

입력: "고객이 상품을 장바구니에 담고 결제할 수 있어야 한다. 주문 완료 시 이메일 알림을 보낸다."

### 도출된 Object Types (후보)
  ✦ Customer   — 서비스를 이용하는 고객
  ✦ Product    — 판매 상품
  ✦ Cart       — 결제 전 임시 담기 공간
  ✦ Order      — 완료된 주문

### 도출된 Link Types (후보)
  ✦ Customer -[adds_to_cart]→ Product  (many_to_many)
     근거: "고객이 상품을 장바구니에 담고"
  ✦ Customer -[places]→ Order          (one_to_many)
     근거: "결제할 수 있어야 한다"
  ✦ Order -[contains]→ Product         (many_to_many)
     근거: 주문은 여러 상품을 포함함 (묵시적)

### 도출된 Action Types (후보)
  ✦ send_order_confirmation_email
     트리거: object_created | 대상: Order
     근거: "주문 완료 시 이메일 알림을 보낸다"

### 불확실한 항목 (결정 필요)
  ? Cart: 장바구니를 별도 Object Type으로 모델링할지,
          Order의 상태(status: cart/confirmed)로 처리할지 결정 필요
  ? Customer vs User: 기존 온톨로지에 User가 있다면 동일 개념일 수 있음
```

### 4. 결정이 필요한 항목 인터랙션

불확실한 항목을 **한 번에 하나씩** 질의한다.

**예시 — 개념 통합 여부:**
> "장바구니(Cart)를 별도 Object Type으로 모델링할까요,
> 아니면 Order의 status 필드(cart / confirmed / shipped)로 처리할까요?
>
> (A) Cart를 별도 Object Type으로 — 장바구니 단계의 데이터를 독립적으로 관리
> (B) Order.status 로 처리 — 단순한 구조, 상태 전이만 표현"

**예시 — 기존 개념과 중복 여부:**
기존 온톨로지에 유사한 Object Type이 있으면:
> "기존 온톨로지에 'User' 가 있습니다. 'Customer' 와 동일한 개념인가요?
>
> (A) 동일 — User 에 customer_grade 등 속성만 추가
> (B) 별개 — Customer 를 새 Object Type으로 추가 (User와 link)"

**예시 — 누락된 필수 속성:**
> "'Product' 에 어떤 식별자(primary key)를 사용할까요?
> (A) product_id (string, 자동 생성)
> (B) sku (string, 외부 코드 체계 사용)
> (C) 직접 입력"

**예시 — 카디널리티 확인:**
> "'Order -[contains]→ Product' 관계의 카디널리티를 확인합니다.
> 한 주문에 동일 상품이 여러 개 담길 수 있나요? (수량 개념)
>
> (A) many_to_many — 주문에 여러 상품, 상품은 여러 주문에 포함
> (B) Order 와 Product 사이에 OrderItem 중간 Object Type 추가 권장
>     (수량, 단가 등 관계 속성 저장 가능)"

모든 결정이 완료될 때까지 반복한다.

### 5. 기존 온톨로지와 충돌 검사

`.ontology/domains/_index.yaml` 읽기. 기존 도메인이 있으면 각 ontology.yaml 읽기.

도출된 Object Type 이름과 기존 이름을 비교:
- 동일 이름 존재 → Step 4에서 이미 처리
- 유사 이름(예: User/Customer, Item/Product) → 사용자에게 통합 여부 확인

### 6. 도메인 배치 결정

> "아래 항목들을 어느 도메인에 추가할까요?
>
> 기존 도메인: ecommerce, hr
> 신규 도메인 이름을 입력하거나 기존 도메인을 선택하세요:"

도출된 타입이 여러 도메인에 걸쳐 있다고 판단되면:
> "일부 항목은 별도 도메인으로 분리하는 것이 적절할 수 있습니다.
> - Customer, Order, Cart, Product → ecommerce 도메인
> - (없음)
> 이 배치로 진행할까요, 아니면 직접 조정하시겠습니까?"

### 7. 최종 추가 내용 미리보기

결정된 모든 내용을 YAML 형태로 보여준다:

```yaml
# 추가될 내용 — .ontology/domains/ecommerce/ontology.yaml

object_types:
  - name: Customer
    description: "서비스를 이용하는 고객"
    properties:
      - name: customer_id
        type: string
        primary: true
      - name: email
        type: string
      - name: customer_grade
        type: string

  - name: Product
    description: "판매 상품"
    properties:
      - name: sku
        type: string
        primary: true
      - name: name
        type: string
      - name: price
        type: float

  - name: Order
    description: "완료된 주문"
    properties:
      - name: order_id
        type: string
        primary: true
      - name: status
        type: string
      - name: created_at
        type: datetime

  - name: OrderItem
    description: "주문 내 상품 항목 (수량, 단가 포함)"
    properties:
      - name: order_item_id
        type: string
        primary: true
      - name: quantity
        type: int
      - name: unit_price
        type: float

link_types:
  - name: places
    from: Customer
    to: Order
    cardinality: one_to_many
    description: "고객이 주문을 생성"

  - name: includes
    from: Order
    to: OrderItem
    cardinality: one_to_many
    description: "주문이 주문항목을 포함"

  - name: references
    from: OrderItem
    to: Product
    cardinality: many_to_one
    description: "주문항목이 상품을 참조"

action_types:
  - name: send_order_confirmation_email
    description: "주문 완료 시 확인 이메일 발송"
    trigger: object_created
    target: Order
```

> "위 내용을 추가할까요? (y / n / 수정)"
- `수정` 입력 시: "어떤 부분을 수정할까요?" → 해당 항목 재질의

### 8. YAML 파일 업데이트

승인 시 `add` 스킬의 Step 5 로직과 동일하게 실행:
- 신규 도메인이면 ontology.yaml + _index.yaml 신규 생성
- 기존 도메인이면 해당 파일에 항목 추가 (Edit 툴)
- `_index.yaml` `last_modified` 갱신

### 9. 글로벌 싱크 체크

`.ontology/config.yaml` 의 `global_sync` 확인:
- `ask` → "글로벌 저장소(`~/.ontologian`)에도 반영할까요? (y/n)"
- `auto` → 자동 싱크
- `off` → 스킵

완료 메시지:
```
✓ 분석 완료 — ecommerce 도메인에 추가됨
  Object Types: Customer, Product, Order, OrderItem (4개)
  Link Types: places, includes, references (3개)
  Action Types: send_order_confirmation_email (1개)
```
```

- [ ] **Step 2: 커밋**

```bash
git add .claude/plugins/ontologian/skills/analyze/skill.md
git commit -m "feat(ontologian): add 'analyze' skill for requirements-driven ontology creation"
```

---

## Self-Review

### 스펙 커버리지 체크

| 스펙 요구사항 | 커버하는 Task |
|---|---|
| YAML 파일 기반 로컬 저장소 | Task 8 (예시 구조 생성) |
| 명시적 Skill 호출 (MCP 없음) | Task 1~9 (모든 스킬) |
| 쓰기 승인 플로우 | Task 2 (add), Task 6 (migrate), Task 9 (analyze) |
| 프로젝트 로컬 필수 | Task 2, Task 9 (초기화 로직) |
| 전역 저장소 선택 | Task 5 (sync), Task 2, Task 9 (add/analyze 후 싱크) |
| global_sync: ask/auto/off | Task 2, Task 6, Task 9 |
| /ontologian overview | Task 1 |
| /ontologian:add | Task 2 |
| /ontologian:analyze | Task 9 |
| /ontologian:search | Task 3 |
| /ontologian:validate | Task 4 |
| /ontologian:sync | Task 5 |
| /ontologian:migrate | Task 6 |
| /ontologian:visualize | Task 7 |
| 도메인→타입별 분리 (스케일업) | Task 6 |
| 마이그레이션 로그 | Task 6 |
| 예시 데이터 | Task 8 |

모든 스펙 요구사항 커버됨.

### Placeholder 스캔
- 없음. 모든 스텝에 실제 YAML 내용 포함.

### 타입 일관성
- `ontology.yaml` 구조: 모든 스킬에서 동일한 필드명 사용
- 마이그레이션된 도메인 읽기: Task 3(search), Task 4(validate), Task 7(visualize) 모두 분리 파일 처리 포함
- `_index.yaml` 의 `paths` 구조(migrate 후): Task 3, 4, 7에서 처리
- Task 9(analyze) 의 YAML 업데이트 로직은 Task 2(add) 의 Step 5와 동일한 구조를 참조하여 일관성 유지
