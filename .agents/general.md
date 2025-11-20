# General Guidelines for LLM Interaction

## Core Principles

### 1. Question-First Approach
- **NEVER assume anything** - always ask for clarification
- **Ask as many questions as needed** to fully understand the task
- **Asking questions is the most important part of the entire process**

### 2. Codebase Analysis Requirements
- **Analyze and understand the existing codebase thoroughly** before making any changes
- **Determine exactly how this feature integrates**, including:
  - Dependencies and their relationships
  - Code structure and architecture patterns
  - Edge cases (within reason, don't go overboard)
  - Constraints and limitations
- **Clearly identify anything unclear or ambiguous** in the description or current implementation
- **List clearly all questions or ambiguities** that need clarification

## Question Categories to Consider

### Technical Context
- What programming language/framework should be used?
- What are the performance requirements?
- What are the security considerations?
- What are the scalability requirements?
- What are the compatibility requirements?

### Project Context
- What is the existing codebase structure?
- How does the new feature integrate with existing components?
- What are the coding standards and conventions?
- What dependencies are already in use?
- What testing frameworks are preferred?
- What documentation standards should be followed?
- What are the architectural patterns and design principles?
- How do similar features work in the current codebase?

### User Requirements
- What is the exact functionality needed?
- What are the success criteria?
- What are the constraints and limitations?
- What is the timeline or priority?
- Who are the end users?

### Implementation Details
- What specific features are required?
- What should the user interface look like?
- What data structures are needed?
- What error handling is required?
- What logging or monitoring is needed?
- What are the integration points with existing code?
- What are the potential edge cases and how should they be handled?
- What constraints exist in the current system?

## Communication Guidelines

### When to Ask Questions
- **Before starting any task** - gather all context and analyze codebase
- **When something is ambiguous** - always seek clarification
- **When encountering edge cases** - don't assume behavior
- **When making design decisions** - confirm user preferences

### How to Ask Questions
- Be specific and clear
- Ask as many questions as needed
- Provide context for why the question is important
- Offer multiple options when appropriate
- Confirm understanding after receiving answers

### Response Structure
1. **Acknowledge** the question or request
2. **Analyze the existing codebase** thoroughly
3. **Ask clarifying questions** about integration, dependencies, and constraints
4. **Wait for complete context** before proceeding
5. **Confirm understanding** before implementation
6. **Proceed only when all questions are answered** and codebase is fully understood

## Remember

**The quality of questions determines the quality of the solution.**
**Better to ask too many questions than to make wrong assumptions.**
**Complete understanding is the foundation of successful implementation.**
**Thorough codebase analysis prevents integration issues and ensures proper implementation.**

## Phase-Specific Guidelines

For detailed guidelines on specific phases, refer to:
- **Planning Phase**: See `@.model_guidelines/planning_phase.md`
- **Implementation Phase**: See `@.model_guidelines/implementation_phase.md`

These files contain phase-specific requirements, prohibited behaviors, and success metrics that should be followed during each respective phase of the development process.