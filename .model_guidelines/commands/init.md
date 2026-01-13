# /init - Initialize Project Context

Generate an `AGENTS.md` file for this project by analyzing the codebase structure, configuration files, and conventions.

## Instructions

You are tasked with creating a comprehensive `AGENTS.md` file in the root of the current project. This file will serve as context for AI assistants working on this codebase.

### Step 1: Analyze the Project

Gather information by examining:

1. **Project Structure**
   - List the main directories and their purposes
   - Identify the entry points
   - Note any monorepo or multi-package structure

2. **Package/Dependency Files**
   - `package.json` (Node.js/JavaScript/TypeScript)
   - `requirements.txt` or `pyproject.toml` or `setup.py` (Python)
   - `Cargo.toml` (Rust)
   - `go.mod` (Go)
   - `pom.xml` or `build.gradle` (Java)
   - `Gemfile` (Ruby)
   - Any other relevant dependency files

3. **Configuration Files**
   - `.eslintrc`, `.eslintrc.js`, `.eslintrc.json` (ESLint)
   - `.prettierrc`, `prettier.config.js` (Prettier)
   - `tsconfig.json` (TypeScript)
   - `.editorconfig`
   - `jest.config.js`, `vitest.config.ts` (Testing)
   - `webpack.config.js`, `vite.config.ts`, `rollup.config.js` (Bundlers)
   - `docker-compose.yml`, `Dockerfile`
   - `Makefile`
   - CI/CD files (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`)

4. **Existing Documentation**
   - `README.md`
   - `CONTRIBUTING.md`
   - `docs/` directory
   - Existing `AGENTS.md` or `.cursorrules`

5. **Code Conventions** (sample a few source files)
   - Naming conventions (camelCase, snake_case, PascalCase)
   - File organization patterns
   - Import/export style
   - Comment style
   - Testing patterns

### Step 2: Generate the AGENTS.md File

Create the `AGENTS.md` file with the following structure:

```markdown
# AGENTS.md

## Persona

You are a Senior Software Engineer with more than 10 years of experience building applications with [DETECTED TECH STACK - e.g., React, TypeScript, Node.js, Python, etc.]. You have deep expertise in:

- [List relevant technologies detected in the project]
- Best practices for [framework/language]
- Testing methodologies (TDD, unit testing, integration testing)
- Clean code principles and design patterns

You will plan everything thoroughly before implementing. All implementations should be reviewed and approved by the tech lead.

## Behavioral Guidelines

- **It's okay to make mistakes** - You don't need to know everything. Do not assume or invent any information.
- **Never assume** - Always ask for more context. Ask as many questions as needed to have the complete picture and understand the task at hand.
- **Clarify requirements** - If something is ambiguous, ask before implementing.
- **Follow existing patterns** - Respect the established code conventions and architectural decisions in this codebase.

## Project Overview

[Describe the project purpose, architecture, and main components]

The project uses the following technologies:

- **Language:** [Primary language(s)]
- **Framework:** [Main framework(s)]
- **State Management:** [If applicable]
- **Routing:** [If applicable]
- **Styling:** [CSS approach]
- **Build Tool:** [Build system]
- **Testing:** [Test framework(s)]
- **Linting:** [Linter(s) and formatters]

## Project Structure

[Describe the main directories and their purposes]

```
project-root/
├── src/           # [Description]
├── tests/         # [Description]
├── config/        # [Description]
└── ...
```

## Building and Running

### Prerequisites

[List required tools and versions, e.g.:]
- Node.js X.X.X
- npm/yarn/pnpm X.X.X

### Installation

```bash
[Installation command]
```

### Development

```bash
[Development server command]
```

### Building

```bash
[Build command]
```

### Testing

```bash
[Test command]
```

### Linting

```bash
[Lint command]
```

## Development Conventions

### Code Style

[Describe code style conventions, derived from linter configs and codebase analysis:]
- **Naming:** [camelCase for variables, PascalCase for components, etc.]
- **Files:** [Naming and organization conventions]
- **Imports:** [Import ordering and style]
- **Formatting:** [Tabs/spaces, line length, etc.]

### Styling Guidelines

[If applicable - CSS/SCSS conventions, units to use, etc.]

### Git Workflow

[Describe branching strategy, commit message format, PR process if detectable]

### Testing Requirements

[Describe testing expectations - unit tests, integration tests, coverage requirements]

## Important Files and Directories

[List key files that AI should be aware of:]
- `src/index.js` - Application entry point
- `src/config/` - Configuration files
- etc.

## Common Tasks

[List common development tasks and how to accomplish them:]

### Adding a new feature
1. ...

### Running specific tests
```bash
[command]
```

### Debugging
[Tips and tools available]
```

### Step 3: Handle Existing Files

- If `AGENTS.md` already exists, ask the user if they want to:
  1. Overwrite it completely
  2. Merge/update it with new findings
  3. Create a backup before overwriting
  
- If `.cursorrules` exists, mention that `AGENTS.md` is the newer recommended format and ask if they want to migrate the content

### Step 4: Final Output

1. Present a summary of what was discovered about the project
2. Show the generated `AGENTS.md` content for review
3. Ask for user confirmation before writing the file
4. After confirmation, write the file to the project root
5. Suggest any additional improvements or sections that could be added later

## Important Notes

- **Persona must be tailored** - The "10 years of experience" should mention the SPECIFIC technologies found in the project (React, Python, Go, etc.)
- Be thorough but concise - the file should be useful, not overwhelming
- Focus on information that helps AI assistants understand and work with the codebase
- Include specific examples from the codebase where helpful
- If you find any `.env.example` files, note the required environment variables (but NEVER include actual secrets)
- Respect any existing code style decisions, don't suggest changes unless asked
- Extract actual commands from `package.json` scripts, `Makefile`, etc. - don't guess
