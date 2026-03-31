---
name: _common
description: 모든 ontologian 스킬이 공유하는 공통 패턴 모음. 직접 실행하지 않는다. 각 skill.md에서 인라인 요약본을 사용하고, 상세 절차가 필요할 때 이 파일을 참조한다.
---

# Ontologian — 공통 패턴 참조

각 스킬의 인라인 요약으로 충분히 실행할 수 있다. 이 파일은 상세 절차가 필요할 때 참조하는 문서다.

---

## 프리앰블 A: 초기화 체크 (읽기 전용 스킬)

> ontologian, search, validate, migrate, visualize에서 사용

**인라인 요약 (각 스킬에 이 형태로 삽입):**
```
Glob `.ontology/domains/_index.yaml` → 없으면 "온톨로지가 초기화되지 않았습니다." 출력 후 종료.
있으면 다음 단계로 진행.
```

**sync 스킬 변형 (config.yaml 체크):**
```
Glob `.ontology/config.yaml` → 없으면 "온톨로지가 초기화되지 않았습니다." 출력 후 종료.
있으면 Read 후 global_path 저장 (기본값: ~/.ontologian).
```

---

## 프리앰블 B: 초기화 체크 + 자동 초기화 (쓰기 스킬)

> add, analyze에서 사용

**인라인 요약 (각 스킬에 이 형태로 삽입):**
```
Glob `.ontology/config.yaml`:
- 없으면: "온톨로지 저장소가 초기화되지 않았습니다. 지금 초기화할까요? (y/n)"
  → n=종료, y=아래 두 파일 Write 생성 후 계속:
    .ontology/config.yaml: { version: 1, global_sync: ask, global_path: ~/.ontologian }
    .ontology/domains/_index.yaml: { domains: [] }
- 있으면: Read 후 global_sync, global_path 저장 (기본값: ask, ~/.ontologian)
```

---

## 패턴: 도메인 파일 읽기 (path/paths)

> ontologian, add, analyze, search, validate, visualize, sync에서 사용

**인라인 요약 (각 스킬에 이 형태로 삽입):**
```
path/paths 분기:
- path 있으면: .ontology/domains/<path> Read → object_types, link_types, action_types 추출
- paths 있으면: .ontology/domains/<paths.object_types>, <paths.link_types>, <paths.action_types> 각 Read
배열 키 없으면 빈 배열로 처리. 파일 읽기 실패 시 오류 기록 후 해당 도메인 건너뜀.
```

---

## 서브루틴: 도메인 선택 메뉴

> add Step 3, analyze Step 7에서 사용

**인라인 요약:**
```
기존 도메인 목록 번호 출력 + "N. 새 도메인 생성"
→ 도메인 없으면: "새 도메인 이름을 입력하세요:"
→ 신규 선택 시: 이름 입력 → 설명 입력(선택, 빈칸=건너뜀)
```

**전체 출력 형식:**
```
어떤 도메인에 추가할까요?

  1. <domain_name_1> — <description_1>
  2. <domain_name_2> — <description_2>
  ...
  N. 새 도메인 생성

번호를 입력하세요:
```

---

## 서브루틴: 글로벌 싱크 체크

> add Step 8, analyze Step 10, migrate Step 10에서 사용

**인라인 요약 (각 스킬에 이 형태로 삽입):**
```
global_sync에 따라:
- ask → "글로벌 저장소(<global_path>)에도 반영할까요? (y/n)" — y=실행, n=건너뜀
- auto → 즉시 실행
- off → 건너뜀
실행 내용: 수정된 도메인 파일(들) + _index.yaml을 <global_path>/domains/ 경로에 Write 복사
```

**상세:**
- 마이그레이션 전 도메인: `<global_path>/domains/<domain_name>/ontology.yaml` Write
- 마이그레이션 후 도메인: 수정된 타입 파일(들) Write
- `<global_path>/domains/_index.yaml` Write (최신 내용으로 덮어쓰기)

---

## 공통 주의사항

모든 스킬에서 유효한 규칙 — 각 스킬의 Common Mistakes에서 중복 제거됨.

1. **path/paths 혼동**: `path`(단수) = 마이그레이션 전 단일 파일, `paths`(복수) = 마이그레이션 후 타입별 3파일. 필드 이름을 정확히 확인한다.
2. **빈 배열(`[]`) 처리**: `object_types: []` 형태일 때 직접 항목을 추가하면 YAML이 깨진다. 반드시 배열 형식으로 교체:
   ```
   old: "object_types: []"
   new: "object_types:\n  - name: ..."
   ```
3. **last_modified 갱신**: YAML 파일 수정 후 반드시 `_index.yaml`의 해당 도메인 `last_modified`를 오늘 날짜(YYYY-MM-DD)로 갱신한다.
4. **description 빈 값**: 설명이 없으면 `description: ""`가 아닌 필드 자체를 생략한다.
5. **false 필드 생략**: `primary: false`, `computed: false`는 명시하지 않는다. `true`일 때만 포함한다.
