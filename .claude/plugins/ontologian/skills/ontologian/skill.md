---
name: ontologian
description: Use when the user runs /ontologian or wants to see the overall status of the ontology repository — domain list, type counts, last modified dates, and available commands.
---

# Ontologian — Overview

## Overview

프로젝트 온톨로지 저장소의 전체 현황을 조회하고 요약 테이블과 사용 가능한 커맨드 목록을 출력한다.

## Steps

### Step 1: `.ontology/` 존재 여부 확인

Glob 툴로 `.ontology/config.yaml` 파일을 검색한다.

```
Glob: pattern=".ontology/config.yaml"
```

파일이 존재하지 않으면 아래 메시지를 출력하고 **즉시 종료**한다.

```
온톨로지 저장소가 초기화되지 않았습니다.
시작하려면 `/ontologian:init` 커맨드를 실행하세요.

사용 가능한 커맨드:
  /ontologian:init      — 온톨로지 저장소 초기화
  /ontologian:add       — 새 타입 추가
  /ontologian:analyze   — 비즈니스 요구사항 분석 → 온톨로지 도출
  /ontologian:search    — 키워드 검색
  /ontologian:validate  — 무결성 검증
  /ontologian:sync      — 글로벌 싱크
  /ontologian:migrate   — 타입별 파일 분리
  /ontologian:visualize — 관계 다이어그램
```

### Step 2: config.yaml 읽기

Read 툴로 `.ontology/config.yaml`을 읽어 다음 필드를 추출한다.

- `version`
- `global_sync` (기본값: `ask`)
- `global_path` (기본값: `~/.ontologian`)

### Step 3: `_index.yaml` 읽기

Read 툴로 `.ontology/domains/_index.yaml`을 읽는다.

파일이 없거나 `domains` 목록이 비어있으면:

```
등록된 도메인이 없습니다.
도메인을 추가하려면 `/ontologian:add` 커맨드를 실행하세요.
```

를 출력하고 Step 5(커맨드 목록)로 건너뛴다.

### Step 4: 각 도메인의 온톨로지 파일 읽기

`_index.yaml`의 `domains` 배열을 순회하며 각 도메인의 타입 수를 집계한다.

**마이그레이션 여부 판단:**

- `path` 필드가 있으면 → 마이그레이션 **전**: `.ontology/domains/<path>` 파일 하나를 Read로 읽는다.
- `paths` 필드가 있으면 → 마이그레이션 **후**: `paths.object_types`, `paths.link_types`, `paths.action_types` 세 파일을 각각 Read로 읽는다. 각 파일의 실제 경로는 `.ontology/domains/<paths.object_types>` 형태로 조합한다(예: `paths.object_types` 값이 `user/object_types.yaml`이면 `.ontology/domains/user/object_types.yaml`).

**집계 항목 (도메인별):**

| 항목 | 집계 방법 |
|------|-----------|
| `object_count` | `object_types` 배열의 원소 수 |
| `link_count` | `link_types` 배열의 원소 수 |
| `action_count` | `action_types` 배열의 원소 수 |
| `last_modified` | `_index.yaml`의 해당 도메인 `last_modified` 값 |

파일 읽기에 실패한 도메인은 해당 행에 `(읽기 실패)`를 표시하고 건너뛴다.

### Step 5: 결과 출력

아래 형식으로 출력한다. 테이블은 유니코드 박스 문자를 사용한다.

```
## Ontologian — 온톨로지 현황

설정:
  글로벌 싱크: <global_sync>   ※ ask=변경 시 확인 요청 / auto=자동 싱크 / off=싱크 비활성화
  글로벌 경로: <global_path>

도메인 목록:
┌────────────────┬──────────┬──────────┬──────────┬──────────────────┐
│ 도메인         │ Objects  │ Links    │ Actions  │ 마지막 수정       │
├────────────────┼──────────┼──────────┼──────────┼──────────────────┤
│ <name>         │ <n>      │ <n>      │ <n>      │ <date>           │
└────────────────┴──────────┴──────────┴──────────┴──────────────────┘

총 도메인: <N> | 총 Object Types: <N> | 총 Link Types: <N> | 총 Action Types: <N>
관계 상세: /ontologian:visualize | 전체 검증: /ontologian:validate

사용 가능한 커맨드:
  /ontologian:add       — 새 타입 추가
  /ontologian:analyze   — 비즈니스 요구사항 분석 → 온톨로지 도출
  /ontologian:search    — 키워드 검색
  /ontologian:validate  — 무결성 검증
  /ontologian:sync      — 글로벌 싱크
  /ontologian:migrate   — 타입별 파일 분리
  /ontologian:visualize — 관계 다이어그램
```

**테이블 렌더링 규칙:**

- 도메인이 여러 개면 각 도메인마다 행(row)을 추가하고, 마지막 행 다음에 `└─…─┘` 하단 테두리를 출력한다.
- 각 열의 너비는 위 형식 기준으로 고정한다(내용이 길면 잘라서 `…` 처리).
- 합계 행은 테이블 밖 별도 줄로 출력한다.

## Common Mistakes

- `_index.yaml`의 `path`와 `paths` 필드를 혼동해 마이그레이션된 도메인을 잘못 읽는 경우 → Step 4의 분기 조건을 반드시 확인한다.
- `object_types` 키가 없는 파일에서 배열 길이를 집계하려다 오류가 나는 경우 → 키 부재 시 0으로 처리한다.
- 합계를 테이블 안에 넣는 경우 → 합계는 테이블 **바깥** 별도 줄로 출력한다.
