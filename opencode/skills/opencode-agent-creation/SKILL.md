---
name: opencode-agent-creation
description: >
  Create, configure, and validate OpenCode agents. Use this skill when the user
  wants to create an OpenCode agent, make a primary agent or subagent, write an
  agent markdown file, configure agent settings in opencode.json, tune agent
  tools or permissions, set hidden or task permissions, or decide whether an
  OpenCode workflow should use build, plan, general, explore, or a custom
  agent. Do NOT use for skill creation, generic AI agent architecture, or
  Claude Agent SDK work.
---

# OpenCode Agent Creation

OpenCode agents are specialized assistants configured for a focused workflow.
This skill helps define the agent's job, choose the right mode, keep tool
access minimal, and produce a correct OpenCode configuration.

## What This Skill Does

- Design new OpenCode agents for a specific workflow
- Choose between `primary`, `subagent`, and `all`
- Produce either `opencode.json` config or a markdown agent file
- Configure tools, permissions, prompts, and model options
- Validate placement, scope, and likely invocation behavior

## When to Use This Skill

Use this skill when the user asks to:

- create an OpenCode agent
- make a subagent or primary agent
- configure agents in `opencode.json`
- write a markdown agent in `.opencode/agents/` or `~/.config/opencode/agents/`
- set agent permissions, tool access, `hidden`, `steps`, or `permission.task`
- decide whether a workflow should be a custom agent or use built-in agents

Do not use this skill for:

- creating or debugging skills
- generic AI agent architecture outside OpenCode
- Claude Agent SDK, MCP server authoring, or external agent frameworks

## Decision Questions

Before writing config, answer these questions:

1. What job should the agent own, and what should it refuse to do?
2. Should the user interact with it directly, or should another agent invoke it?
3. Does it need to modify files, run commands, fetch the web, or only analyze?
4. Should the agent be visible in `@` autocomplete, or internal only?
5. Does it need a custom model or can it inherit the active model?
6. Is JSON config or a markdown file the better fit for this repo?

If the request is vague, narrow the scope before writing config. A small,
purpose-built agent works better than a catch-all assistant with broad access.

## Built-In Agent Baselines

Use built-ins when they already match the need:

- `build`: default primary agent with full development access
- `plan`: primary agent for planning and analysis, with edits and bash gated
- `general`: subagent for multi-step work with broad tool access
- `explore`: read-only subagent for codebase exploration

Create a custom agent only when the user needs a distinct prompt, tool set,
permission policy, or workflow boundary.

## Step-by-Step Workflow

### Step 1: Choose the mode

- Use `primary` when the user wants to switch into the agent directly
- Use `subagent` when another agent should invoke it for focused tasks
- Use `all` only when the same agent should support both patterns

Prefer `subagent` for narrow helpers such as review, docs, debugging, or audit
flows. Prefer `primary` for broad day-to-day working modes.

### Step 2: Choose the smallest useful tool set

Start from least privilege:

- Analysis agents usually need `read`, `glob`, `grep`, and sometimes `webfetch`
- Implementation agents may need `write`, `edit`, and `bash`
- Internal orchestration patterns may also need `task`

If a tool is not clearly needed, leave it disabled.

### Step 3: Design permissions

Use permissions to shape risk, not just tools:

- Set `edit`, `bash`, or `webfetch` to `ask`, `allow`, or `deny`
- Use command patterns for bash when only a narrow command family is safe
- Use `permission.task` to control which subagents an agent may invoke

For planning or review agents, default toward read-only behavior and only allow
targeted exceptions.

### Step 4: Write the prompt

Write a short, specific prompt that explains:

- the agent's role
- what to prioritize
- what to avoid
- the expected output style

Do not restate global OpenCode rules unless the agent needs a tighter local
policy.

### Step 5: Choose the config surface

Use `opencode.json` when:

- the repo already centralizes config there
- you want one file for multiple agents and global overrides
- you need clear JSON diffs for review

Use a markdown agent file when:

- the agent prompt is long enough to benefit from standalone editing
- you want one file per agent
- you want project-local or global agents in the standard directories

See `references/agent-config-patterns.md` for both patterns.

### Step 6: Place the agent correctly

Supported markdown locations include:

- `~/.config/opencode/agents/`
- `.opencode/agents/`

The markdown filename becomes the agent name. For example, `review.md` creates
the `review` agent.

### Step 7: Validate behavior

Check all of the following:

- the description clearly says what the agent does and when to use it
- the tool set matches the job
- permissions are not broader than necessary
- `hidden: true` is used only for internal subagents
- `permission.task` matches the intended delegation model
- the agent should exist at all, rather than reusing a built-in

Use `references/validation-checklist.md` before considering the agent done.

## Agent Configuration Patterns

OpenCode supports both JSON and markdown definitions.

### JSON pattern

Use an `agent` entry in `opencode.json` with fields such as:

- `description`
- `mode`
- `model`
- `prompt`
- `tools`
- `permission`
- `steps`
- `hidden`
- `color`
- `top_p`

### Markdown pattern

Use frontmatter for config and the markdown body for the prompt. The filename is
the agent name.

### Important options

- `description` is required and should explain what the agent does and when to use it
- `mode` should be `primary`, `subagent`, or `all`
- `hidden` only affects `subagent` visibility in `@` autocomplete
- `steps` limits agentic iterations before the model must summarize
- unspecified models inherit defaults based on OpenCode behavior

Concrete examples live in `references/agent-config-patterns.md`.

## Validation Checklist

Before finalizing an agent:

- confirm the agent has one clear purpose
- confirm the user-facing description is specific and scoped
- confirm the mode matches direct use versus delegated use
- confirm tools follow least privilege
- confirm permissions match the real risk level
- confirm markdown placement or JSON nesting is correct
- confirm `hidden` and `permission.task` are aligned for subagents
- confirm the agent does not duplicate a built-in without a good reason

## Troubleshooting

### Agent is too broad

Split it into two agents or tighten the prompt and tool set. Agents work best
when they own one workflow.

### Agent should be a subagent but was made primary

If the user does not need to switch into it directly, prefer `subagent`.
Reserve `primary` for modes the user will actively inhabit.

### Agent has too much power

Reduce enabled tools first, then tighten permissions. Broad tools with broad
permissions create accidental behavior.

### Agent is noisy in `@` autocomplete

Set `hidden: true` for internal-only subagents.

### Delegation is not constrained enough

Use `permission.task` so orchestrator agents can invoke only the intended
subagents.

### The user might not need a custom agent

Check whether `build`, `plan`, `general`, or `explore` already solve the need.
Avoid custom agents that merely rename a built-in without changing behavior.

## Example Requests

| User says | Action |
|-----------|--------|
| "Create an OpenCode subagent for code review" | Design a read-only review subagent and write config |
| "Make a planning agent that asks before edits" | Configure a guarded primary agent with restrictive permissions |
| "Write a markdown agent file for docs work" | Create a project or global markdown agent |
| "Should this be a primary agent or subagent?" | Evaluate usage pattern and recommend a mode |
| "Limit which subagents this orchestrator can call" | Configure `permission.task` rules |
| "Tune this agent's tool access" | Minimize tools and tighten permissions |

## References

- `references/agent-config-patterns.md`
- `references/validation-checklist.md`
