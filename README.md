# Ontologian

Palantir 온톨로지 개념(Object Type, Property, Link Type, Action Type)을 기반으로 지식을 구조화하고 관리하는 Claude Code 플러그인.

## 설치

### 1. 마켓플레이스 등록

`~/.claude/settings.json` 에 아래 내용을 추가한다:

```json
{
  "extraKnownMarketplaces": {
    "ontologian": {
      "source": {
        "source": "github",
        "repo": "swszz/ontologian-marketplace"
      }
    }
  }
}
```

### 2. 플러그인 설치

Claude Code에서 실행:

```
/plugin install ontologian@ontologian-marketplace
```

## 사용법

| 커맨드 | 동작 |
|---|---|
| `/ontologian` | 도메인 목록 + 상태 요약 |
| `/ontologian:add` | 대화형으로 새 타입 추가 |
| `/ontologian:analyze` | 요구사항 분석 → 온톨로지 자동 도출 |
| `/ontologian:search <keyword>` | 키워드 검색 |
| `/ontologian:validate` | YAML 무결성 검증 |
| `/ontologian:sync` | 로컬 → 글로벌 싱크 |
| `/ontologian:migrate` | 도메인 단일 파일 → 타입별 분리 |
| `/ontologian:visualize` | 도메인 관계 다이어그램 출력 |

## 저장소 구조

플러그인 설치 후 프로젝트에 `.ontology/` 디렉토리가 생성된다:

```
<project-root>/
└── .ontology/
    ├── config.yaml
    ├── domains/
    │   ├── _index.yaml
    │   └── <domain-name>/
    │       └── ontology.yaml
    └── migrations/
```
