# Plugin Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `swszz/ontologian` 저장소 하나로 플러그인과 마켓플레이스를 겸하도록 구성해 `/plugin install ontologian@ontologian` 한 명령으로 설치 가능하게 한다.

**Architecture:** `ontologian` 저장소 루트에 `.claude-plugin/marketplace.json`을 추가해 자기 자신을 가리키도록 구성. `setup.sh`는 `~/.claude/settings.json`에 `ontologian` 키로 마켓플레이스를 등록한다. `ontologian-marketplace` 저장소는 `ontologian`으로 리다이렉트하는 README만 남기고 종료.

**Tech Stack:** bash, jq (선택), python3 (fallback), JSON

---

### Task 1: `.claude-plugin/marketplace.json` 추가

**Files:**
- Create: `ontologian/.claude-plugin/marketplace.json`

- [ ] **Step 1: marketplace.json 생성**

`/Users/haku/Development/ontologian/.claude-plugin/marketplace.json` 파일을 아래 내용으로 생성한다:

```json
{
  "name": "ontologian",
  "owner": {
    "name": "swszz"
  },
  "metadata": {
    "description": "Ontologian plugin for Claude Code",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "ontologian",
      "description": "Palantir ontology concepts (Object Type, Link Type, Action Type) for knowledge management in Claude Code",
      "version": "1.0.0",
      "source": {
        "source": "url",
        "url": "https://github.com/swszz/ontologian.git"
      }
    }
  ]
}
```

- [ ] **Step 2: JSON 유효성 확인**

```bash
cd /Users/haku/Development/ontologian
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json')); print('valid')"
```

Expected output: `valid`

- [ ] **Step 3: 커밋**

```bash
cd /Users/haku/Development/ontologian
git add .claude-plugin/marketplace.json
git commit -m "feat: add marketplace.json to serve as self-hosted marketplace"
```

---

### Task 2: `setup.sh` 추가

**Files:**
- Create: `ontologian/setup.sh`

- [ ] **Step 1: setup.sh 생성**

`/Users/haku/Development/ontologian/setup.sh` 파일을 아래 내용으로 생성한다:

```bash
#!/bin/bash
set -e

SETTINGS_FILE="$HOME/.claude/settings.json"
MARKETPLACE_KEY="ontologian"
REPO="swszz/ontologian"

echo "Setting up Ontologian..."

mkdir -p "$(dirname "$SETTINGS_FILE")"

NEW_ENTRY=$(cat <<EOF
{
  "extraKnownMarketplaces": {
    "$MARKETPLACE_KEY": {
      "source": {
        "source": "github",
        "repo": "$REPO"
      }
    }
  }
}
EOF
)

if [ -f "$SETTINGS_FILE" ] && [ -s "$SETTINGS_FILE" ]; then
  if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --argjson entry "$NEW_ENTRY" '. * $entry' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  elif command -v python3 &>/dev/null; then
    python3 - "$SETTINGS_FILE" "$NEW_ENTRY" <<'PYEOF'
import sys, json
path, new_entry_str = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
new_entry = json.loads(new_entry_str)
def deep_merge(base, override):
    for k, v in override.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base
deep_merge(settings, new_entry)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  else
    echo "Error: jq or python3 is required. Please install one and retry."
    exit 1
  fi
else
  echo "$NEW_ENTRY" > "$SETTINGS_FILE"
  if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq '.' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  fi
fi

echo ""
echo "Done! settings.json updated: $SETTINGS_FILE"
echo ""
echo "Next step — run this in Claude Code:"
echo ""
echo "  /plugin install ontologian@ontologian"
echo ""
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x /Users/haku/Development/ontologian/setup.sh
```

- [ ] **Step 3: 로컬에서 실행 테스트**

```bash
bash /Users/haku/Development/ontologian/setup.sh
```

Expected output:
```
Setting up Ontologian...

Done! settings.json updated: /Users/haku/.claude/settings.json

Next step — run this in Claude Code:

  /plugin install ontologian@ontologian
```

- [ ] **Step 4: settings.json에 ontologian 키가 추가됐는지 확인**

```bash
python3 -c "import json; s=json.load(open('$HOME/.claude/settings.json')); print(s['extraKnownMarketplaces']['ontologian'])"
```

Expected output:
```
{'source': {'source': 'github', 'repo': 'swszz/ontologian'}}
```

- [ ] **Step 5: 커밋**

```bash
cd /Users/haku/Development/ontologian
git add setup.sh
git commit -m "feat: add setup.sh for marketplace registration"
```

---

### Task 3: README 업데이트 (ontologian)

**Files:**
- Modify: `ontologian/README.md`

- [ ] **Step 1: README 설치 섹션 교체**

`/Users/haku/Development/ontologian/README.md`의 `## 설치` 섹션을 아래 내용으로 교체한다:

```markdown
## 설치

### 1. 마켓플레이스 등록

터미널에서 실행:

```bash
curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash
```

### 2. 플러그인 설치

Claude Code에서 실행:

```
/plugin install ontologian@ontologian
```

### 업데이트

```
/plugin update ontologian
```
```

- [ ] **Step 2: 커밋**

```bash
cd /Users/haku/Development/ontologian
git add README.md
git commit -m "docs: update installation instructions for new deployment approach"
```

---

### Task 4: ontologian-marketplace 저장소 종료 처리

**Files:**
- Modify: `ontologian-marketplace/README.md`
- Modify: `ontologian-marketplace/setup.sh`

- [ ] **Step 1: README를 리다이렉트 문서로 교체**

`/Users/haku/Development/ontologian-marketplace/README.md` 전체를 아래 내용으로 교체한다:

```markdown
# Ontologian Marketplace (Deprecated)

이 저장소는 더 이상 사용되지 않습니다.

## 설치 방법

[swszz/ontologian](https://github.com/swszz/ontologian) 저장소를 참고하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash
```

그 다음 Claude Code에서:

```
/plugin install ontologian@ontologian
```
```

- [ ] **Step 2: setup.sh를 리다이렉트 스크립트로 교체**

`/Users/haku/Development/ontologian-marketplace/setup.sh` 전체를 아래 내용으로 교체한다:

```bash
#!/bin/bash
echo "This repository is deprecated."
echo "Please use the new setup script:"
echo ""
echo "  curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash"
echo ""
```

- [ ] **Step 3: 커밋**

```bash
cd /Users/haku/Development/ontologian-marketplace
git add README.md setup.sh
git commit -m "deprecate: redirect to swszz/ontologian for installation"
```

---

### Task 5: 최종 검증

- [ ] **Step 1: settings.json에서 기존 ontologian-marketplace 키 정리**

`~/.claude/settings.json`에 남아있는 `ontologian-marketplace` 키(구 마켓플레이스)를 제거한다.

현재 settings.json에서 `"ontologian-marketplace"` 블록을 삭제한다:

```bash
python3 - <<'EOF'
import json
path = f"{__import__('os').path.expanduser('~')}/.claude/settings.json"
with open(path) as f:
    s = json.load(f)
s.get('extraKnownMarketplaces', {}).pop('ontologian-marketplace', None)
with open(path, 'w') as f:
    json.dump(s, f, indent=2)
print("Cleaned up ontologian-marketplace key")
EOF
```

Expected output: `Cleaned up ontologian-marketplace key`

- [ ] **Step 2: settings.json 최종 상태 확인**

```bash
python3 -c "
import json, os
s = json.load(open(os.path.expanduser('~/.claude/settings.json')))
m = s.get('extraKnownMarketplaces', {})
print('ontologian:', m.get('ontologian'))
print('ontologian-marketplace:', m.get('ontologian-marketplace', 'removed'))
"
```

Expected output:
```
ontologian: {'source': {'source': 'github', 'repo': 'swszz/ontologian'}}
ontologian-marketplace: removed
```

- [ ] **Step 3: Claude Code에서 설치 확인**

Claude Code에서 실행:
```
/plugin install ontologian@ontologian
```

Expected: 플러그인이 정상 설치됨
