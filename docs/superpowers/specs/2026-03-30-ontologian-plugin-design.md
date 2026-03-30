# Ontologian — Claude Code Plugin Design

**Date:** 2026-03-30
**Status:** Approved

---

## Overview

Palantir 온톨로지 개념(Object Type, Property, Link Type, Action Type)을 기반으로 지식을 구조화하고 관리하는 Claude Code 플러그인. 개인 및 팀 지식 관리를 주 목적으로 하며, 데이터 모델링 보조도 지원한다.

**핵심 원칙:**
- YAML 파일 기반 로컬 저장소 (git 친화적, 외부 의존성 없음)
- Skill(슬래시 커맨드)로 사용자가 명시적으로 호출 (MCP 없음)
- 쓰기 작업은 항상 사용자 승인 후 실행
- 프로젝트 로컬 필수, 전역 저장소 선택

---

## 1. 저장소 구조

### 프로젝트 로컬 (필수)

```
<project-root>/
└── .ontology/
    ├── config.yaml          # 플러그인 설정
    ├── domains/
    │   ├── <domain-name>/
    │   │   └── ontology.yaml    # 도메인 내 모든 타입 정의
    │   └── _index.yaml          # 전체 도메인 목록 & 메타데이터
    └── migrations/              # 도메인→타입별 분리 이력
        └── YYYY-MM-DD-<desc>.log
```

### 전역 저장소 (선택)

```
~/.ontologian/
├── config.yaml
└── domains/
    └── ...                  # 여러 프로젝트에서 싱크된 도메인들
```

### `config.yaml`

```yaml
version: 1
global_sync: ask          # ask | auto | off
global_path: ~/.ontologian
```

### `domains/_index.yaml`

```yaml
domains:
  - name: ecommerce
    description: "이커머스 도메인"
    path: ecommerce/ontology.yaml
    last_modified: 2026-03-30
  - name: hr
    description: "인사 도메인"
    path: hr/ontology.yaml
    last_modified: 2026-03-30
```

### `domains/<name>/ontology.yaml`

```yaml
domain: ecommerce
version: 1
description: "이커머스 도메인 온톨로지"

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

link_types:
  - name: places
    from: User
    to: Order
    cardinality: one_to_many
    description: "사용자가 주문을 생성"

action_types:
  - name: send_welcome_email
    description: "신규 사용자에게 환영 메일 발송"
    trigger: object_created
    target: User
```

---

## 2. Skill (슬래시 커맨드)

| 커맨드 | 동작 |
|---|---|
| `/ontologian` | 현재 도메인 목록 + 상태 요약 출력 |
| `/ontologian add` | 대화형으로 새 타입 추가 |
| `/ontologian analyze` | 비즈니스 요구사항 분석 → 온톨로지 자동 도출 및 추가 |
| `/ontologian search <keyword>` | 키워드로 온톨로지 검색 |
| `/ontologian validate` | 전체 YAML 무결성 검증 |
| `/ontologian sync` | 로컬 → 글로벌 싱크 수동 실행 |
| `/ontologian migrate` | 도메인 단일파일 → 타입별 분리 실행 |
| `/ontologian visualize` | 도메인 관계를 텍스트 다이어그램으로 출력 |

### Skill 파일 구조

```
.claude/
└── plugins/
    └── ontologian/
        └── skills/
            ├── add/
            │   └── skill.md
            ├── analyze/
            │   └── skill.md
            ├── search/
            │   └── skill.md
            ├── validate/
            │   └── skill.md
            ├── sync/
            │   └── skill.md
            ├── migrate/
            │   └── skill.md
            └── visualize/
                └── skill.md
```

---

## 4. 데이터 플로우

### 읽기

```
사용자가 /ontologian search or /ontologian 호출
    → Skill이 .ontology/domains/_index.yaml 읽기
    → 해당 도메인 ontology.yaml 읽기
    → 결과 출력
```

### 쓰기 (승인 필요)

```
사용자가 /ontologian add or /ontologian update 호출
    → Claude가 추가/수정안 제안 (YAML diff 형태로 표시)
    → 사용자 승인
    → ontology.yaml + _index.yaml 업데이트
    → 변경 감지 → 글로벌 싱크 플로우 진입
```

### 글로벌 싱크

```
로컬 변경 발생
    → config.global_sync 확인
    → ask  → 쓰기 작업 완료 직후 Claude가 싱크 여부 질의
    → auto → 자동 싱크 실행
    → off  → 싱크 없음
```

---

## 5. 스케일업 경로

도메인 파일이 커지면 `/ontologian migrate` 로 타입별 분리:

```
# 분리 전
domains/ecommerce/ontology.yaml

# 분리 후
domains/ecommerce/
├── object_types.yaml
├── link_types.yaml
└── action_types.yaml
```

마이그레이션 이력은 `.ontology/migrations/` 에 기록.

---

## 6. 기술 스택

- **Skill 구현:** Markdown (Claude가 직접 해석, 별도 빌드 없음)
- **YAML 조작:** Claude의 기본 툴 (Read, Write, Edit, Grep, Glob)
- **외부 의존성:** 없음
