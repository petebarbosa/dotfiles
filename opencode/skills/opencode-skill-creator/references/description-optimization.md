# Description Optimization

The description is the primary trigger mechanism. A good description makes
the difference between a skill that gets used and one that gets ignored.

## Manual Optimization Process

1. **Generate test queries**
   - Create 10-20 realistic prompts
   - Mix of should-trigger and should-not-trigger
   - Include edge cases and near-misses

2. **Test triggering**
   - Run each prompt in OpenCode
   - Note which trigger the skill
   - Identify false positives and false negatives

3. **Analyze results**
   - Look for patterns in what triggers and what doesn't
   - Identify gaps where the description is unclear

4. **Refine the description**
   - Add missing trigger phrases
   - Clarify ambiguous language
   - Remove phrases that cause false triggers

5. **Retest**
   - Repeat until triggering is accurate

## Good Test Queries

**Should-trigger examples:**
- "ok so my boss just sent me this xlsx file and wants me to add a column"
- "Can you help me fill out this PDF form with the data I provided?"

**Should-not-trigger examples:**
- "Read this file" (too simple)
- "What is the weather?" (unrelated)
- "Format this code" (different domain)

The negative cases should be genuinely tricky, not obviously irrelevant.

## Preventing Over-Triggering

If a skill loads for unrelated queries, add negative triggers to the description:

```yaml
description: >
  Advanced data analysis for CSV files. Use for statistical modeling,
  regression, and clustering. Do NOT use for simple data viewing or
  exploration (use data-viz skill instead).
```

Be more specific about scope rather than more generic. Narrowing from
"Processes documents" to "Processes PDF legal documents for contract review"
eliminates most false positives.

## Description Best Practices

- Start with what the skill does
- Add "Use when..." with specific triggers
- Add "Do NOT use for..." to prevent over-triggering on adjacent domains
- Include domain-specific keywords
- Mention file types or technologies if relevant
- Be explicit about edge cases where it applies
- Keep it under 1024 characters
