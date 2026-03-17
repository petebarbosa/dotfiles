# Quick Reference

## Naming

```regex
^[a-z0-9]+(-[a-z0-9]+)*$
```

Valid: `git-release`, `rails-setup`, `database-migration-v2`
Invalid: `Git-Release`, `-skill`, `skill--name`, `my_skill`

## Frontmatter Template

```yaml
---
name: skill-name
description: >
  What this skill does. Use when the user mentions X, Y, or Z.
  Also use for A, B, and C.
license: MIT
allowed-tools: "Bash(python:*) WebFetch"
compatibility: Designed for OpenCode
metadata:
  author: your-name
  version: "1.0"
---
```

## Directory Structure

```
# Minimal
~/.config/opencode/skills/my-skill/SKILL.md

# With resources
~/.config/opencode/skills/my-skill/
├── SKILL.md
├── scripts/
│   └── helper.py
└── references/
    └── guide.md
```

## Permission Configuration

Control skill access in `opencode.json`:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "sensitive-*": "ask",
      "dangerous-*": "deny"
    }
  }
}
```

| Permission | Behavior |
|------------|----------|
| `allow` | Skill loads immediately |
| `deny` | Skill hidden, access rejected |
| `ask` | User prompted for approval |

Patterns support wildcards: `internal-*` matches `internal-docs`, `internal-tools`, etc.

### Per-Agent Overrides

Override permissions for specific agents:

```json
{
  "agent": {
    "plan": {
      "permission": {
        "skill": {
          "internal-*": "allow"
        }
      }
    }
  }
}
```

Disable skills entirely for an agent:

```json
{
  "agent": {
    "plan": {
      "tools": {
        "skill": false
      }
    }
  }
}
```

## Testing Workflow

1. Write skill
2. Create `evals/evals.json` with test prompts
3. Place skill in appropriate directory
4. Run test prompts in OpenCode
5. Review outputs with user
6. Iterate based on feedback
7. Repeat until satisfied
