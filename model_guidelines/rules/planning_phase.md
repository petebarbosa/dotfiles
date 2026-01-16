# Planning Phase Guidelines

## Core Planning Principles

### 1. Question-First Approach
- **NEVER code anything during the planning phase**
- **Only start planning after ALL context is gathered**
- **Asking questions is the most important part of the entire process**

### 2. Planning Phase Requirements
- Complete understanding must be achieved before any planning begins
- All requirements, constraints, and context must be explicitly confirmed
- No assumptions about user preferences, existing code, or implementation details
- Planning only starts when every necessary detail is clarified

### 3. Codebase Analysis Focus
- **Remember: your job is not to implement (yet)** - focus on exploring, planning, and asking questions
- **Continue going back and forth until you have no further questions** and complete understanding is achieved

### 4. Plan Documentation Requirements
- **Always write or update the @./PLAN.md** following the structure in `@.model_guidelines/templates/plan_template.md`
- Document all findings, issues, and planned fixes using the template format
- Update the PLAN.md file as new information is discovered during the planning phase
- Ensure the plan follows the template's structure with proper sections and status tracking

## When to Ask Questions During Planning

- **Before starting any task** - gather all context and analyze codebase
- **During codebase analysis** - clarify integration points and dependencies
- **During planning** - clarify any unclear requirements
- **When encountering edge cases** - don't assume behavior
- **When making design decisions** - confirm user preferences
- **When something is ambiguous** - always seek clarification

## Plan Documentation Process

- **Create initial PLAN.md** using the template structure when starting planning
- **Update PLAN.md continuously** as new issues and findings are discovered
- **Follow the template format** exactly as specified in `@.model_guidelines/templates/plan_template.md`
- **Document all critical issues** found during codebase analysis
- **Structure fixes by priority** using the template's phase system
- **Track status** using the provided status legend (🔴 Not Started, 🟡 In Progress, 🟢 Completed, ⚠️ Blocked)

## Prohibited Behaviors During Planning

- ❌ Writing any code
- ❌ Making assumptions about requirements
- ❌ Proceeding without complete context
- ❌ Guessing user preferences
- ❌ Assuming technical details
- ❌ Implementing before understanding codebase integration
- ❌ Skipping thorough analysis of existing code
- ❌ Not documenting findings in PLAN.md
- ❌ Not following the plan template structure

## Planning Phase Success Metrics

- ✅ All requirements explicitly confirmed
- ✅ All technical details clarified
- ✅ All constraints understood
- ✅ Complete context gathered
- ✅ No assumptions made
- ✅ Existing codebase thoroughly analyzed
- ✅ Integration points and dependencies identified
- ✅ All ambiguities clarified through questions
- ✅ PLAN.md created/updated following the template structure
- ✅ All critical issues documented with proper status tracking

## Remember

**Your job is exploration and planning first - implementation comes only after complete understanding.**
**The planning phase is about gathering complete context, not about writing code.**
**Always document your findings and plans using the @.model_guidelines/templates/plan_template.md structure.**
