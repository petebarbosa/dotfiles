---
name: opencode-skill-creator
description: >
  Create, test, and improve OpenCode skills. Use this skill when the user wants
  to make a new skill, edit an existing skill, optimize a skill description, or
  understand how skills work. Also use when the user mentions "create a skill",
  "make a skill", "skill doesn't trigger", "improve my skill", "test my skill",
  or "write a SKILL.md". Apply this skill whenever configuring OpenCode skills,
  skills directory, .opencode/skills, skill frontmatter, or Agent Skills spec.
---

# OpenCode Skill Creator

Skills are folders with a `SKILL.md` file containing instructions that OpenCode
loads dynamically. The workflow: **decide** what the skill does, **write** the
SKILL.md, **test** with realistic prompts, **evaluate** and **improve** based
on feedback, **repeat** until satisfied.

## Skill Format Reference

### Directory Structure

```
skill-name/
└── SKILL.md          # Required: metadata + instructions
```

Optional directories for larger skills:

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
└── assets/           # Optional: templates, resources
```

Do NOT include a `README.md` inside the skill folder. All documentation
belongs in `SKILL.md` or `references/`. A README is only appropriate at the
repository level when distributing skills via GitHub.

### SKILL.md Format

Each SKILL.md must start with YAML frontmatter followed by Markdown content.

#### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (1-64 chars, lowercase alphanumeric with hyphens) |
| `description` | Yes | What the skill does and when to use it (1-1024 chars) |
| `license` | No | License name or reference |
| `allowed-tools` | No | Restrict which tools the skill can use (e.g., `"Bash(python:*) WebFetch"`) |
| `compatibility` | No | Environment requirements (max 500 chars) |
| `metadata` | No | Key-value map for additional data |

#### Minimal Example

```markdown
---
name: my-skill
description: A description of what this skill does and when to use it.
---

# My Skill

Instructions here...
```

#### Name Field Rules

- Must be 1-64 characters
- Lowercase letters, numbers, and hyphens only (`a-z`, `0-9`, `-`)
- Must not start or end with a hyphen
- Must not contain consecutive hyphens (`--`)
- Must match the parent directory name

Valid: `database-connections`, `rails-setup`, `api-testing-123`
Invalid: `Database-Connections`, `-my-skill`, `my--skill`, `my_skill`

Reserved names: Do not use `claude` or `anthropic` as a skill name or prefix
(e.g., `claude-helper`, `anthropic-tools`). These are reserved by Anthropic.

#### Frontmatter Security

Frontmatter is injected into the system prompt, so restrictions apply:

- No XML angle brackets (`<` or `>`) anywhere in frontmatter — they could
  enable prompt injection
- No code execution in YAML values (safe YAML parsing is enforced)

#### Description Field

The description is the primary mechanism for skill triggering. It must:

- Be 1-1024 characters
- Describe what the skill does AND when to use it
- Include specific keywords that help identify relevant tasks
- Be "pushy" (include trigger phrases even if obvious)

**Good example:**

```yaml
description: >
  Extracts text and tables from PDF files, fills PDF forms, and merges multiple
PDFs. Use when working with PDF documents or when the user mentions PDFs, forms,
or document extraction.
```

**Poor example:**

```yaml
description: Helps with PDFs.
```

### Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (~100 tokens): `name` and `description` loaded at startup
2. **Instructions** (<5000 tokens recommended): Full SKILL.md body loaded when triggered
3. **Resources** (as needed): Files in scripts/, references/, assets/ loaded only when required

**Keep SKILL.md under 500 lines.** If approaching this limit, add hierarchy with
pointers to reference files.

### File References

Reference other files using relative paths from the skill root:

```markdown
See [the reference guide](references/API.md) for details.

Run the extraction script: scripts/extract.py
```

Keep file references one level deep. Avoid deeply nested reference chains.

## OpenCode-Specific Placement

OpenCode discovers skills from these locations:

| Location | Type | Path |
|----------|------|------|
| Project config | Project | `.opencode/skills/<name>/SKILL.md` |
| Global config | Global | `~/.config/opencode/skills/<name>/SKILL.md` |
| Project Claude | Project | `.claude/skills/<name>/SKILL.md` |
| Global Claude | Global | `~/.claude/skills/<name>/SKILL.md` |
| Project agent | Project | `.agents/skills/<name>/SKILL.md` |
| Global agent | Global | `~/.agents/skills/<name>/SKILL.md` |

**For project-local paths**, OpenCode walks up from the working directory to
the git worktree root, loading matching `skills/*/SKILL.md` in `.opencode/`,
`.claude/`, or `.agents/` along the way.

**Global definitions** are loaded from `~/.config/opencode/skills/`,
`~/.claude/skills/`, and `~/.agents/skills/`.

### Skill Permissions

Permissions (`allow`, `deny`, `ask`) and per-agent overrides are configured in
`opencode.json`. See [references/quick-reference.md](references/quick-reference.md)
for configuration examples.

### How Skill Triggering Works

OpenCode lists available skills in the `skill` tool description. Each entry
includes the skill name and description. The agent loads a skill by calling
the tool: `skill({ name: "my-skill" })`.

Claude only consults skills for tasks it can't easily handle alone. Simple
one-step queries may not trigger skills even with matching descriptions.
Complex, multi-step, or specialized queries reliably trigger skills when
the description matches.

## Creating a Skill

### Step 1: Capture Intent

Understand what the user wants:

1. What should this skill enable OpenCode to do?
2. When should this skill trigger? (what phrases/contexts)
3. What's the expected output format?
4. Should we test it? (objectively verifiable outputs benefit from testing)

Proactively ask about edge cases, input/output formats, success criteria,
and dependencies.

### Step 2: Write the SKILL.md

Based on the interview, create the skill:

```markdown
---
name: skill-name
description: >
  What this skill does and when to use it. Include trigger phrases
  like "use this when" and specific keywords.
---

# Skill Name

## What This Skill Does
- Capability 1
- Capability 2

## When to Use This Skill
Use this when the user mentions X, Y, or Z.

## Step-by-Step Instructions
1. Step one...
2. Step two...

## Examples
**Example 1:**
Input: ...
Output: ...

## Common Pitfalls
- Pitfall 1 and how to avoid it
- Pitfall 2 and how to avoid it
```

### Writing Patterns

**Design for composability:**

Multiple skills can be loaded simultaneously. A skill should not assume it is
the only one active — avoid generic section names that clash (like `## Setup`),
don't override broad behaviors, and keep the skill's scope well-defined so it
cooperates with other skills rather than conflicting.

**Prefer the imperative form:**

```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
```

**Explain the why:**

Instead of rigid "MUST" rules, explain why something matters. Today's LLMs
have good theory of mind and can go beyond rote instructions when they
understand the reasoning.

**Avoid overfitting:**

Write skills that generalize. Don't encode specific examples as rigid rules.
If the user gives examples, extract the underlying principle.

**Keep it lean:**

Remove instructions that aren't pulling their weight. If something causes
the model to waste time without adding value, cut it.

**Safety first:**

Never include malware, exploits, or instructions that could compromise
system security. Don't create misleading skills or skills designed for
unauthorized access.

## Testing a Skill

### Start with One Task

Before broad testing, iterate on a single challenging task until OpenCode
succeeds consistently. Then extract the winning approach into the skill.
This gives faster signal than testing many cases at once. Once the foundation
works, expand to multiple test cases for coverage.

### Manual Testing (OpenCode)

Since OpenCode doesn't have subagents like Claude Code, testing is manual:

1. **Create test prompts**
   - Write 2-3 realistic prompts the skill should handle
   - Include edge cases and typical usage
   - Save them in `evals/evals.json`:

```json
{
  "skill_name": "my-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result"
    }
  ]
}
```

2. **Test in OpenCode**
   - Place the skill in the appropriate directory
   - Restart OpenCode or trigger a skill reload
   - Run each test prompt
   - Observe the behavior and output

3. **Evaluate results**
   - Did the skill trigger when expected?
   - Did it follow the instructions?
   - Was the output correct?
   - Note any issues or surprises

4. **Iterate**
   - Fix issues in the SKILL.md
   - Retest
   - Repeat until satisfied

### Performance Comparison

To verify a skill adds value, compare the same task with and without the skill:

- **Without skill**: How many back-and-forth messages? How many retries or
  corrections? Did the user need to re-explain context?
- **With skill**: Does it complete in fewer steps? Are there fewer failed
  attempts? Is the output more consistent across runs?

If the skill doesn't measurably reduce effort or improve consistency, the
instructions may need tightening.

### Testing the Description

Verify the description triggers the skill correctly:

1. Write trigger phrases that should activate the skill
2. Write non-trigger phrases that should NOT activate it
3. Test both sets in OpenCode
4. Refine the description if triggering is off

Example trigger phrases:
- "Create a PDF from this data" (for a PDF skill)
- "Extract tables from this document"
- "Fill out this form"

Example non-trigger phrases:
- "Read this file" (too simple, OpenCode handles directly)
- "What is 2+2?" (not related)

## Improving a Skill

### The Iteration Loop

After initial testing:

1. **Review outputs** with the user
2. **Identify issues** (wrong behavior, missed edge cases, unclear instructions)
3. **Improve the skill** based on feedback
4. **Retest** with the same prompts
5. **Repeat** until satisfied

Keep iterating until:
- The user is happy
- All test cases pass
- No meaningful progress is being made

### Improvement Principles

**Generalize from feedback:**

The goal is a skill that works across millions of uses, not just the test
cases. If the user points out an issue, understand the underlying principle
and fix it generally, not just for that specific example.

**Keep the prompt lean:**

Read the transcripts, not just final outputs. If the skill causes OpenCode to
waste time on unproductive steps, remove those instructions.

**Explain the why:**

If you find yourself writing "MUST" or "ALWAYS" in all caps, pause. Can you
explain why instead? Understanding the reasoning helps the model apply the
principle correctly in new situations.

**Look for repeated work:**

If every test run involves writing similar helper scripts or taking the same
multi-step approach, bundle that work into a script in `scripts/`. Write it
once, reference it in the skill, save future invocations from reinventing
the wheel.

**Theory of mind:**

Write for a smart assistant that can reason. Today's LLMs can handle nuanced
instructions and make judgment calls when given good guidance. Trust them
to think, but give them clear principles to think with.

For specific fixes (skill doesn't trigger, triggers wrong, too verbose), see
the Troubleshooting section below.

## Description Optimization

For the full description optimization process — including test query generation,
over-triggering prevention with negative triggers, and best practices — see
[references/description-optimization.md](references/description-optimization.md).

## Validation Checklist

Before considering a skill complete:

**Frontmatter:**
- [ ] `name` is present and matches directory name
- [ ] `name` is 1-64 chars, lowercase, hyphens only, no leading/trailing
- [ ] `name` does not use reserved prefixes (`claude`, `anthropic`)
- [ ] `description` is present and 1-1024 chars
- [ ] `description` includes what AND when
- [ ] No XML angle brackets (`<` `>`) in frontmatter values
- [ ] Optional fields (license, compatibility, metadata) are valid if present

**Body:**
- [ ] Under 500 lines (or well-structured with references)
- [ ] Clear instructions in imperative form
- [ ] Examples included
- [ ] Edge cases documented
- [ ] No README.md in the skill folder
- [ ] No malware or security issues

**Placement:**
- [ ] Directory name matches `name` field
- [ ] File is named `SKILL.md` (all caps)
- [ ] Placed in one of the 6 discovery locations

**Testing:**
- [ ] Tested with realistic prompts
- [ ] Triggers correctly
- [ ] Produces expected output
- [ ] User reviewed and approved

## Troubleshooting

### Skill Doesn't Appear in Available Skills

1. Verify `SKILL.md` is spelled in all caps
2. Check that frontmatter includes `name` and `description`
3. Ensure skill name matches directory name exactly
4. Check `opencode.json` permissions — skills with `deny` are hidden
5. Verify the skill is in one of the 6 discovery locations
6. Check for duplicate names across locations (must be unique)

### Skill Doesn't Trigger

1. Ask OpenCode: "When would you use the [skill-name] skill?" — it will quote
   the description back, revealing what's missing or misleading
2. Review the description — is it specific enough?
3. Add more trigger phrases to the description
4. Check if the task is too simple (OpenCode may handle directly)
5. Ensure the query is complex enough to benefit from a skill
6. Try more explicit mentions of the skill domain

### Skill Triggers But Produces Wrong Output

1. Review the instructions — are they clear?
2. Add step-by-step guidance
3. Include examples of correct behavior
4. Document common pitfalls
5. Add validation steps
6. Test with the failing prompt and iterate

## Sharing Skills

To distribute a skill to others:

1. Host the skill folder on GitHub with a repo-level `README.md` (separate
   from the skill folder itself — remember, no README inside the skill)
2. Include installation instructions: clone the repo, copy the skill folder
   into one of the 6 discovery locations
3. Provide example usage and screenshots so users know what to expect

Focus on outcomes when describing your skill to others: "Set up complete
project workspaces in seconds" is more compelling than "A folder containing
YAML frontmatter and Markdown instructions."

## Example Requests

| User says | Action |
|-----------|--------|
| "Create a skill for X" | Interview about intent, edge cases, outputs; draft SKILL.md |
| "My skill isn't triggering" | Review description, suggest improvements, test trigger phrases |
| "Improve my existing skill" | Identify issues from transcripts, generalize improvements |
| "Why did my skill do X?" | Analyze transcript, explain behavior, suggest fixes |
| "Test my skill" | Create test prompts, run them in OpenCode, evaluate |
| "Where do I put skills?" | Explain the 6 discovery locations, recommend based on scope |
| "What's the skill format?" | Explain frontmatter, naming rules, body structure |
| "How do I disable a skill?" | Show opencode.json permission configuration |

## Quick Reference

For naming regex, frontmatter template, directory structure, permission
configuration, and testing workflow cheat sheet, see
[references/quick-reference.md](references/quick-reference.md).
