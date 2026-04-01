# Plugin Deployment Design

**Date:** 2026-04-01
**Status:** Approved

## Problem

`/plugin install ontologian@ontologian-marketplace` fails because `swszz/ontologian-marketplace` lacks `.claude-plugin/marketplace.json`. The two-repo setup also creates maintenance overhead: every version bump requires updating both `ontologian` and `ontologian-marketplace`.

## Goal

- Anyone can install ontologian with minimal steps
- Version updates require changes to one repo only
- Users can update via `/plugin update ontologian`

## Design

### Repository Structure

`swszz/ontologian` serves as both the plugin and its own marketplace. `swszz/ontologian-marketplace` is archived.

```
ontologian/
  .claude-plugin/
    plugin.json        ← existing, no changes needed
    marketplace.json   ← NEW: lists ontologian, points source to itself
  skills/
  hooks/
  setup.sh             ← NEW: registers ontologian repo as a marketplace in settings.json
  README.md
```

### `.claude-plugin/marketplace.json`

```json
{
  "name": "ontologian",
  "owner": { "name": "swszz" },
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

### `setup.sh`

Adds `ontologian` to `extraKnownMarketplaces` in `~/.claude/settings.json`, pointing to `swszz/ontologian`. Merges with existing settings using `jq` or `python3`.

### Installation Flow (user)

```bash
# Terminal
curl -fsSL https://raw.githubusercontent.com/swszz/ontologian/main/setup.sh | bash

# Claude Code
/plugin install ontologian@ontologian
```

### Update Flow (maintainer)

1. Push changes to `swszz/ontologian`
2. Bump `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (same value)
3. Users run `/plugin update ontologian` in Claude Code

## Migration

- `swszz/ontologian-marketplace`: archive the repository
- `setup.sh` in `ontologian-marketplace`: no longer maintained; README can redirect to `swszz/ontologian`
