# OpenCode Custom Tools

This directory contains custom tools for OpenCode agents.

## Available Tools

### gitingest

Analyzes Git repositories and returns a structured digest of the codebase optimized for AI analysis.

**Installation Requirements:**
```bash
# Recommended: Install with pipx (isolated environment)
pipx install gitingest

# Alternative: Install with pip
pip install gitingest

# Verify installation
gitingest --version
```

**Features:**
- Fetch and analyze any Git repository (GitHub, GitLab, etc.)
- Filter files by pattern (include/exclude)
- Limit file sizes for memory management
- Analyze specific branches
- Support for private repositories with GitHub tokens

**Example Usage in OpenCode:**

1. **Basic repository analysis:**
   ```
   Use the gitingest tool to analyze https://github.com/octocat/Hello-World
   ```

2. **Focused analysis (Python files only):**
   ```
   Use gitingest to analyze https://github.com/user/repo but only include Python files
   ```

3. **Exclude dependencies:**
   ```
   Analyze https://github.com/user/repo but exclude node_modules and dist folders
   ```

4. **Private repository:**
   ```
   Analyze https://github.com/user/private-repo (provide your GitHub token when prompted)
   ```

**Arguments:**
- `repository_url` (required): Git repository URL
- `include_patterns` (optional): Array of file patterns to include (e.g., `["*.py", "*.js"]`)
- `exclude_patterns` (optional): Array of file patterns to exclude (e.g., `["node_modules/*", "*.log"]`)
- `max_file_size` (optional): Maximum file size in bytes (e.g., `51200` for 50KB)
- `branch` (optional): Specific branch to analyze
- `github_token` (optional): GitHub personal access token for private repos

**Output Format:**

The tool returns three sections:

1. **Summary**: Repository metadata (file count, token estimate)
2. **Directory Tree**: Hierarchical structure of the repository
3. **File Contents**: Full contents of analyzed files with clear delimiters

**Use Cases:**
- Understanding unfamiliar codebases
- Gathering context for code reviews
- Analyzing project structure and architecture
- Extracting documentation and examples
- Security audits and dependency analysis

**Best Practices for Search-Focused Agents:**
- Use `include_patterns` to focus on relevant file types
- Use `exclude_patterns` to filter out dependencies and build artifacts
- Set `max_file_size` to manage memory for large repositories
- For large repos, analyze in multiple passes (e.g., docs first, then code by language)

## Tool Development

To add a new tool, create a TypeScript file in this directory:

```typescript
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Tool description",
  args: {
    param: tool.schema.string().describe("Parameter description"),
  },
  async execute(args, context) {
    // Implementation
    return "result"
  },
})
```

The filename becomes the tool name. See the [OpenCode documentation](https://opencode.ai/docs/custom-tools/) for more details.
