---
name: ontologian:migrate
description: Use when the user runs /ontologian:migrate or wants to split a domain's single ontology.yaml into separate object_types.yaml, link_types.yaml, and action_types.yaml files.
---

# Ontologian — Migrate

## Overview

도메인의 단일 `ontology.yaml`을 `object_types.yaml`, `link_types.yaml`, `action_types.yaml` 3개 파일로 분리한다.
이미 `paths` 필드로 마이그레이션된 도메인은 대상에서 제외한다.

---

## Steps

### Step 1: 초기화 체크

Glob `.ontology/domains/_index.yaml` → 없으면 `"온톨로지가 초기화되지 않았습니다."` 출력 후 **즉시 종료**.

### Step 2: `_index.yaml` 읽기

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

`domains` 배열을 메모리에 저장한다.

`domains` 배열이 비어있으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
등록된 도메인이 없습니다.
```

**분리 가능한 도메인 필터링:**

`domains` 배열에서 `path` 필드가 있는 항목만 추출한다. (`paths` 필드가 있는 항목은 이미 마이그레이션 완료 → 제외)

분리 가능한 도메인이 하나도 없으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
분리 가능한 도메인이 없습니다. 모든 도메인이 이미 마이그레이션되었습니다.
```

필터링된 목록을 `migratable_domains`로 메모리에 저장한다.

### Step 3: 대상 도메인 선택

`migratable_domains` 목록을 번호로 출력한다.

```
분리할 도메인을 선택하세요:

  1. <domain_name_1> — <description_1>  (경로: <path_1>)
  2. <domain_name_2> — <description_2>  (경로: <path_2>)
  ...

번호를 입력하세요:
```

`description` 필드가 없는 도메인은 `—` 이후 부분을 생략한다.

사용자 입력을 받아 선택된 도메인을 `target_domain`으로 메모리에 저장한다.

유효하지 않은 번호가 입력되면 재질의한다:

```
올바른 번호를 입력하세요 (1–<N>):
```

### Step 4: ontology.yaml 읽기

Read 툴로 `.ontology/domains/<target_domain.path>` 파일을 읽는다.

예: `.ontology/domains/ecommerce/ontology.yaml`

파일에서 아래 항목을 추출해 메모리에 저장한다:

- `domain`: 도메인 이름
- `version`: 버전 (없으면 `1`로 기본값 사용)
- `object_types`: 배열 (없으면 빈 배열)
- `link_types`: 배열 (없으면 빈 배열)
- `action_types`: 배열 (없으면 빈 배열)

대상 디렉토리를 `target_dir`로 저장한다: `<target_domain.path>`에서 파일명을 제거한 경로.
예: `path = ecommerce/ontology.yaml` → `target_dir = ecommerce`

### Step 5: 분리 미리보기 출력

아래 형식으로 미리보기를 출력한다.

```
[<domain_name>] 분리 미리보기

생성될 파일:
  • .ontology/domains/<target_dir>/object_types.yaml  (<N>개 Object Types)
  • .ontology/domains/<target_dir>/link_types.yaml    (<N>개 Link Types)
  • .ontology/domains/<target_dir>/action_types.yaml  (<N>개 Action Types)

_index.yaml 변경:
  - path: <target_domain.path>
  + paths:
      object_types: <target_dir>/object_types.yaml
      link_types: <target_dir>/link_types.yaml
      action_types: <target_dir>/action_types.yaml

진행할까요? (y/n)
```

`<N>`은 각 배열의 항목 수다. 빈 배열이면 `0`을 출력한다.

- `n` → 아래 메시지를 출력하고 **종료**:
  ```
  취소되었습니다.
  ```
- `y` → Step 6으로 진행.

### Step 6: 분리 파일 생성

#### 6-A: object_types.yaml 생성

Write 툴로 `.ontology/domains/<target_dir>/object_types.yaml`을 생성한다.

`object_types` 배열이 비어있지 않은 경우:
```yaml
domain: <domain_name>
version: <version>
object_types:
  # 기존 object_types 내용 그대로
```

`object_types` 배열이 비어있는 경우:
```yaml
domain: <domain_name>
version: <version>
object_types: []
```

#### 6-B: link_types.yaml 생성

Write 툴로 `.ontology/domains/<target_dir>/link_types.yaml`을 생성한다.

`link_types` 배열이 비어있지 않은 경우:
```yaml
domain: <domain_name>
version: <version>
link_types:
  # 기존 link_types 내용 그대로
```

`link_types` 배열이 비어있는 경우:
```yaml
domain: <domain_name>
version: <version>
link_types: []
```

#### 6-C: action_types.yaml 생성

Write 툴로 `.ontology/domains/<target_dir>/action_types.yaml`을 생성한다.

`action_types` 배열이 비어있지 않은 경우:
```yaml
domain: <domain_name>
version: <version>
action_types:
  # 기존 action_types 내용 그대로
```

`action_types` 배열이 비어있는 경우:
```yaml
domain: <domain_name>
version: <version>
action_types: []
```

### Step 7: `_index.yaml` 업데이트

Read 툴로 `.ontology/domains/_index.yaml`의 현재 내용을 다시 읽는다.

Edit 툴로 해당 도메인 항목의 `path` 필드를 `paths` 블록으로 교체한다.

**변경 전 (`old_string` — `path` 줄만 포함):**
```yaml
  path: <target_domain.path>
```

**변경 후 (`new_string`):**
```yaml
  paths:
    object_types: <target_dir>/object_types.yaml
    link_types: <target_dir>/link_types.yaml
    action_types: <target_dir>/action_types.yaml
  last_modified: <today_date>
```

`<today_date>`는 오늘 날짜를 `YYYY-MM-DD` 형식으로 사용한다.

`description` 등 기타 필드는 그대로 유지한다.

### Step 8: 마이그레이션 로그 기록

Write 툴로 `.ontology/migrations/YYYY-MM-DD-split-<domain_name>.log` 파일을 생성한다.

파일명의 날짜는 오늘 날짜를 `YYYY-MM-DD` 형식으로 사용한다.
예: `.ontology/migrations/2026-03-30-split-ecommerce.log`

로그 파일 내용:

```
date: <today_date>
domain: <domain_name>
action: split ontology.yaml into separate type files

source:
  file: .ontology/domains/<target_domain.path>

created:
  - .ontology/domains/<target_dir>/object_types.yaml  (<N> object_types)
  - .ontology/domains/<target_dir>/link_types.yaml    (<N> link_types)
  - .ontology/domains/<target_dir>/action_types.yaml  (<N> action_types)

index_updated: .ontology/domains/_index.yaml
  path -> paths (object_types, link_types, action_types)
```

### Step 9: 완료 안내

아래 메시지를 출력한다.

```
✓ [<domain_name>] 마이그레이션 완료

생성된 파일:
  • .ontology/domains/<target_dir>/object_types.yaml
  • .ontology/domains/<target_dir>/link_types.yaml
  • .ontology/domains/<target_dir>/action_types.yaml

_index.yaml 업데이트 완료 (path → paths)
로그: .ontology/migrations/<log_filename>

기존 파일은 직접 삭제하세요:
  rm .ontology/domains/<target_domain.path>
```

### Step 10: 글로벌 싱크 체크

Glob `.ontology/config.yaml` → 없으면 건너뜀. 있으면 Read 후 `global_sync`, `global_path` 확인.

- `ask` → `"글로벌 저장소(<global_path>)에도 반영할까요? (y/n)"` → y=실행, n=건너뜀
- `auto` → 즉시 실행
- `off` 또는 config.yaml 없으면 → 건너뜀

**실행**: `object_types.yaml`, `link_types.yaml`, `action_types.yaml`을 `<global_path>/domains/<domain_name>/`에 Write 복사. `_index.yaml`도 `<global_path>/domains/`에 덮어쓰기.

---

## Common Mistakes

- **`paths` 도메인 제외 누락** → `paths` 필드가 이미 있는 도메인은 Step 2에서 반드시 제외한다.
- **`target_dir` 추출 오류** → `path: ecommerce/ontology.yaml` → `target_dir = ecommerce`. 중첩 경로(예: `shop/v2/ontology.yaml` → `shop/v2`)도 정확히 처리한다.
- **기존 타입 배열 내용 누락** → 분리 파일 생성 시 원본 배열 항목을 그대로 복사한다.
- **`_index.yaml` 교체 시 기타 필드 손실** → `path` 줄만 정확히 교체한다. `description`, `name` 등 나머지 필드는 유지.
- **Edit `old_string`에 `last_modified` 포함 금지** → 날짜 불일치로 매칭 실패. `path` 줄(`  path: <value>`)만 교체 대상.
- **Edit `old_string` 들여쓰기** → 2칸 공백과 정확히 일치해야 한다.
- **원본 파일 자동 삭제 금지** → 기존 `ontology.yaml` 삭제는 사용자에게 안내만 한다.
