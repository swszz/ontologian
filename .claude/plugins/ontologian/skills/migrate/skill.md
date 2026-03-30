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

Glob 툴로 `.ontology/domains/_index.yaml`을 검색한다.

```
Glob: pattern=".ontology/domains/_index.yaml"
```

파일이 없으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
온톨로지가 초기화되지 않았습니다.
```

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

Glob 툴로 `.ontology/config.yaml`을 검색한다.

```
Glob: pattern=".ontology/config.yaml"
```

파일이 있으면 Read 툴로 읽어 `global_sync`, `global_path` 값을 확인한다.

**`ask`인 경우:**
```
글로벌 저장소(<global_path>)에도 반영할까요? (y/n)
```
- `y` → 아래 싱크 실행
- `n` → 건너뜀

**`auto`인 경우:** 사용자 확인 없이 싱크 실행.

**`off`인 경우 또는 config.yaml이 없는 경우:** 아무것도 하지 않고 종료.

**싱크 실행 내용:**

아래 파일들을 `<global_path>/domains/<domain_name>/` 경로에 Write 툴로 복사한다.

- `object_types.yaml`
- `link_types.yaml`
- `action_types.yaml`

`<global_path>/domains/_index.yaml`도 최신 내용으로 Write 툴로 덮어쓴다.

---

## Common Mistakes

- **`path`와 `paths` 혼동** → `path`(단수) = 마이그레이션 전 단일 파일, `paths`(복수) = 마이그레이션 후 타입별 파일. `paths` 필드가 이미 있는 도메인은 Step 2에서 반드시 제외한다.
- **`target_dir` 추출 오류** → `path: ecommerce/ontology.yaml`에서 `target_dir`은 `ecommerce`다. 파일명만 제거하고 앞의 디렉토리 경로를 정확히 추출한다. 디렉토리 구조가 중첩된 경우(예: `shop/v2/ontology.yaml`)도 올바르게 처리한다.
- **기존 타입 배열 내용 누락** → Write 툴로 분리 파일을 생성할 때 원본 `ontology.yaml`의 배열 항목을 그대로 복사해야 한다. 항목을 빠뜨리거나 임의로 수정하지 않는다.
- **`_index.yaml` 교체 시 기타 필드 손실** → Edit 툴로 `path` → `paths` 교체 시 `description`, `name`, `last_modified` 등 나머지 필드가 유지되어야 한다. `path` 줄만 정확히 교체한다.
- **로그 디렉토리 미생성** → `.ontology/migrations/` 디렉토리가 없어도 Write 툴은 파일 경로 전체를 기준으로 생성하므로 별도 mkdir 없이 Write 툴로 직접 파일을 생성한다.
- **오늘 날짜 형식 오류** → `last_modified` 및 로그 파일명의 날짜는 반드시 `YYYY-MM-DD` 형식이어야 한다.
- **원본 파일 자동 삭제 금지** → 기존 `ontology.yaml`은 사용자가 직접 삭제하도록 안내만 한다. 스킬이 자동으로 삭제하지 않는다.
- **Edit의 `old_string`에 `last_modified` 포함 금지** → `last_modified` 날짜는 파일마다 다르므로 `old_string`에 포함하면 날짜 불일치로 매칭에 실패한다. `path` 줄(`  path: <target_domain.path>`)만 교체 대상으로 한정한다.
- **`.ontology/config.yaml`은 있지만 `_index.yaml`이 없는 경우** → '초기화되지 않았습니다' 메시지를 출력하고 종료 (add 또는 analyze 스킬로 도메인을 먼저 추가해야 함)
- **Edit의 `old_string` 들여쓰기 불일치** → `old_string`은 실제 파일의 들여쓰기(2칸 공백)와 정확히 일치해야 함 — 탭/4칸 등 다른 형식이면 매칭 실패
