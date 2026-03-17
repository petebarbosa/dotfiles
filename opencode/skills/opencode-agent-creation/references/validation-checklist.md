# Validation Checklist

Use this checklist before finishing an OpenCode agent.

## Scope

- The agent has one clear job
- The prompt defines what it should prioritize
- The prompt defines what it should avoid or refuse
- A built-in agent would not already solve the request well enough

## Description

- The description says what the agent does
- The description says when to use it
- The description is specific enough for the intended workflow
- The description is not so broad that it catches unrelated work

## Mode

- `primary` is used only when the user should switch into the agent directly
- `subagent` is used for focused delegated helpers
- `all` is used intentionally, not by default

## Tools And Permissions

- Enabled tools are the minimum needed for the job
- `edit`, `bash`, and `webfetch` permissions match the real risk level
- Bash permission rules allow only the intended command families when narrowed
- `permission.task` rules are present when delegation needs boundaries

## Placement

- JSON agents live under the `agent` key in `opencode.json`
- Markdown agents live in `.opencode/agents/` or `~/.config/opencode/agents/`
- The markdown filename matches the intended agent name
- `hidden: true` is used only for internal subagents

## Behavior

- The agent output style matches its job
- The agent should not duplicate `build`, `plan`, `general`, or `explore` without a reason
- The agent can be explained in one sentence without hand-waving

## Manual Test Prompts

- Write at least two prompts the agent should handle well
- Write at least one prompt that should not need this agent
- Check whether the resulting behavior is narrower, safer, or clearer than using a built-in directly
