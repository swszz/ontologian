---
name: ontologian:sync
description: Use when the user runs /ontologian:sync or wants to manually sync local .ontology/ to the global ~/.ontologian/ directory.
---

# Ontologian — Sync

## Overview

로컬 `.ontology/` 디렉터리를 전역 `~/.ontologian/`에 수동으로 싱크한다.
싱크 전에 미리보기를 출력하고 사용자 승인을 받은 뒤 파일을 복사한다.

---

## Steps

### Step 1: 초기화 체크

Glob 툴로 `.ontology/config.yaml`을 검색한다.

```
Glob: pattern=".ontology/config.yaml"
```

파일이 없으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
온톨로지가 초기화되지 않았습니다. (.ontology/config.yaml 없음)
```

### Step 2: config.yaml 읽기

Read 툴로 `.ontology/config.yaml`을 읽는다.

```
Read: .ontology/config.yaml
```

아래 값을 메모리에 저장한다.

- `global_path`: 없으면 기본값 `~/.ontologian`
- `global_sync`: 있으면 참고용으로 저장 (sync 스킬은 항상 수동 실행이므로 값과 무관하게 진행)

### Step 3: _index.yaml 읽기

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

```
Read: .ontology/domains/_index.yaml
```

`domains` 배열이 없거나 비어있으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
싱크할 도메인이 없습니다. (domains 배열이 비어있음)
```

각 도메인 항목에서 파일 목록을 수집한다. 항목마다 마이그레이션 여부를 판단한다.

- `path` 필드가 있으면 → 파일 1개: `<path>` (예: `ecommerce/ontology.yaml`)
- `paths` 필드가 있으면 → `paths.object_types`, `paths.link_types`, `paths.action_types` 값을 각각 파일 목록에 추가 (예: `ecommerce/object_types.yaml`)

수집된 파일 목록을 `sync_files` 배열로 메모리에 저장한다.
`_index.yaml` 자체도 싱크 대상에 포함한다.

### Step 4: 싱크 미리보기 출력

`sync_files` 배열을 바탕으로 아래 형식의 미리보기를 출력한다.
로컬 경로는 `.ontology/domains/<file>`, 글로벌 경로는 `<global_path>/domains/<file>` 형태로 표시한다.
`_index.yaml`은 로컬 `.ontology/domains/_index.yaml` → `<global_path>/domains/_index.yaml`로 표시한다.

```
## 싱크 미리보기
로컬 → 글로벌 (<global_path>)
  ecommerce/ontology.yaml → <global_path>/domains/ecommerce/ontology.yaml
  domains/_index.yaml     → <global_path>/domains/_index.yaml
총 N개 파일

진행할까요? (y/n)
```

`N`은 도메인 파일 수 + 1(`_index.yaml`)이다.

사용자 입력을 기다린다.

- **`n`** → 아래 메시지를 출력하고 종료한다.
  ```
  취소되었습니다.
  ```
- **`y`** → Step 5로 진행한다.

### Step 5: 글로벌 config.yaml 확인 및 생성

Glob 툴로 `<global_path>/config.yaml`이 존재하는지 확인한다.

```
Glob: pattern="<global_path>/config.yaml"
```

파일이 없으면 Write 툴로 아래 내용으로 생성한다.

```yaml
version: 1
```

파일이 이미 있으면 건너뛴다.

### Step 6: 도메인 파일 복사

`sync_files` 배열을 순회하며 각 파일을 복사한다.

각 파일마다:

1. Read 툴로 로컬 파일을 읽는다: `.ontology/domains/<file>`
2. Write 툴로 글로벌 경로에 쓴다: `<global_path>/domains/<file>`

파일 읽기 또는 쓰기에 실패한 경우, 해당 파일명을 경고 목록에 추가하고 **다음 파일로 계속 진행**한다.

```
⚠ 복사 실패: <file>
```

실패해도 나머지 파일 복사를 중단하지 않는다.

### Step 7: _index.yaml 복사

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.
Write 툴로 `<global_path>/domains/_index.yaml`에 쓴다.

실패 시 경고 목록에 추가하고 계속 진행한다.

```
⚠ 복사 실패: domains/_index.yaml
```

### Step 8: 완료 메시지 출력

성공한 파일 수(`N`)를 계산한다 (전체 대상 파일 수 - 실패 파일 수).

경고가 없는 경우:

```
✓ 싱크 완료: N개 파일 → <global_path>
```

경고가 하나 이상인 경우, 경고 목록을 먼저 출력한 뒤 완료 메시지를 출력한다:

```
⚠ 복사 실패: <file1>
⚠ 복사 실패: <file2>

✓ 싱크 완료: N개 파일 → <global_path>  (M개 실패)
```

`M`은 실패한 파일 수다.

---

## Common Mistakes

- **`path`와 `paths` 혼동** → `path`(단수) = 마이그레이션 전 단일 파일, `paths`(복수) = 마이그레이션 후 타입별 파일. Step 3 분기 조건을 정확히 확인한다.
- **`_index.yaml` 누락** → 도메인 파일 외에 `_index.yaml`도 반드시 싱크 대상에 포함해야 한다.
- **`global_path` 기본값 누락** → `config.yaml`에 `global_path`가 없으면 `~/.ontologian`을 사용한다.
- **파일 실패 시 전체 중단** → 개별 파일 복사 실패는 경고만 출력하고 나머지 파일 복사를 계속한다.
- **미리보기 파일 수 오류** → 총 N개는 도메인 파일 수 + `_index.yaml` 1개다. `_index.yaml`을 빠뜨리지 않는다.
- **글로벌 config.yaml 덮어쓰기** → 이미 존재하는 경우 생성하지 않는다. 존재 여부를 Glob으로 먼저 확인한다.
