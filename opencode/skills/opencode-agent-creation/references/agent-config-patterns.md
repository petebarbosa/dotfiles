# Agent Config Patterns

Use these examples as starting points for OpenCode agents.

## JSON: Read-Only Review Subagent

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "code-reviewer": {
      "description": "Reviews code for bugs, maintainability, and risky changes.",
      "mode": "subagent",
      "tools": {
        "write": false,
        "edit": false,
        "bash": false
      },
      "prompt": "You are a code reviewer. Focus on correctness, maintainability, and risk.",
      "temperature": 0.1
    }
  }
}
```

## JSON: Guarded Planning Primary Agent

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "planner": {
      "description": "Analyzes code and prepares implementation plans without making direct changes.",
      "mode": "primary",
      "permission": {
        "edit": "ask",
        "bash": {
          "*": "ask",
          "git diff*": "allow",
          "git log*": "allow"
        }
      },
      "prompt": "You are in planning mode. Investigate, explain tradeoffs, and avoid direct modification unless asked.",
      "temperature": 0.1,
      "steps": 6
    }
  }
}
```

## JSON: Orchestrator With Task Boundaries

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "orchestrator": {
      "description": "Coordinates specialized OpenCode subagents for large workflows.",
      "mode": "primary",
      "permission": {
        "task": {
          "*": "deny",
          "code-reviewer": "allow",
          "docs-writer": "allow"
        }
      },
      "prompt": "Delegate only when a focused subagent clearly improves accuracy or speed."
    }
  }
}
```

## Markdown: Docs Writer Subagent

Path: `.opencode/agents/docs-writer.md`

```markdown
---
description: Writes and updates project documentation.
mode: subagent
tools:
  bash: false
---

You are a technical writer. Focus on clarity, structure, and accurate examples.
```

## Markdown: Hidden Internal Helper

Path: `~/.config/opencode/agents/internal-helper.md`

```markdown
---
description: Internal helper for focused repository analysis.
mode: subagent
hidden: true
tools:
  write: false
  edit: false
---

Investigate the requested area quickly and report concise findings.
```

## Selection Guide

- Use JSON for centralized configuration and mixed global plus per-agent policy
- Use markdown when the prompt is easier to maintain in its own file
- Use `subagent` for narrow helpers and `primary` for user-facing work modes
- Start with fewer tools than you think you need, then add only what proves necessary
