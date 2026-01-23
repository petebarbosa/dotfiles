/**
 * GitIngest Tool for OpenCode
 * 
 * Analyzes Git repositories and returns structured digest of codebase.
 * 
 * Prerequisites:
 * - Install gitingest: `pipx install gitingest` or `pip install gitingest`
 * - Verify installation: `gitingest --version`
 */

import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Analyze Git repositories and return structured digest of codebase using GitIngest. Returns repository summary, directory tree, and file contents optimized for AI analysis. Useful for understanding unfamiliar codebases, analyzing project structure, and gathering context for code reviews.",
  
  args: {
    repository_url: tool.schema
      .string()
      .describe("Git repository URL (GitHub, GitLab, etc.). Example: https://github.com/user/repo"),
    
    include_patterns: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("File patterns to include (Unix shell-style wildcards). Examples: ['*.py', '*.js', '*.md']. Can be used to focus analysis on specific file types."),
    
    exclude_patterns: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("File patterns to exclude (Unix shell-style wildcards). Examples: ['node_modules/*', '*.log', 'dist/*']. Useful for filtering out dependencies and build artifacts."),
    
    max_file_size: tool.schema
      .number()
      .optional()
      .describe("Maximum file size in bytes to process. Example: 51200 for 50KB limit. Helps manage memory for large repositories."),
    
    branch: tool.schema
      .string()
      .optional()
      .describe("Specific branch to analyze. Defaults to repository's default branch."),
    
    github_token: tool.schema
      .string()
      .optional()
      .describe("GitHub personal access token for private repositories. Can also be set via GITHUB_TOKEN environment variable."),
  },
  
  async execute(args, context) {
    // Build gitingest command
    let command = `gitingest ${args.repository_url}`
    
    try {
      
      // Add include patterns
      if (args.include_patterns && args.include_patterns.length > 0) {
        for (const pattern of args.include_patterns) {
          command += ` -i "${pattern}"`
        }
      }
      
      // Add exclude patterns
      if (args.exclude_patterns && args.exclude_patterns.length > 0) {
        for (const pattern of args.exclude_patterns) {
          command += ` -e "${pattern}"`
        }
      }
      
      // Add max file size
      if (args.max_file_size) {
        command += ` -s ${args.max_file_size}`
      }
      
      // Add branch
      if (args.branch) {
        command += ` -b ${args.branch}`
      }
      
      // Add GitHub token
      if (args.github_token) {
        command += ` -t ${args.github_token}`
      }
      
      // Output to stdout
      command += ` -o -`
      
      // Execute command
      const result = await Bun.$`sh -c ${command}`.text()
      
      return result.trim()
      
    } catch (error) {
      // Enhanced error handling
      if (error instanceof Error) {
        const errorMessage = error.message.toLowerCase()
        
        // Check for common errors
        if (errorMessage.includes("command not found") || errorMessage.includes("gitingest: not found")) {
          return `ERROR: GitIngest is not installed. Please install it with:\n  pipx install gitingest\n\nOr:\n  pip install gitingest\n\nThen verify: gitingest --version`
        }
        
        if (errorMessage.includes("authentication") || errorMessage.includes("401")) {
          return `ERROR: Authentication failed. For private repositories, provide a GitHub token:\n  - Pass github_token argument\n  - Or set GITHUB_TOKEN environment variable`
        }
        
        if (errorMessage.includes("not found") || errorMessage.includes("404")) {
          return `ERROR: Repository not found: ${args.repository_url}\n\nPlease verify:\n  - The URL is correct\n  - The repository exists\n  - You have access to the repository`
        }
        
        return `ERROR: Failed to analyze repository\n\nDetails: ${error.message}\n\nCommand attempted: ${command}`
      }
      
      return `ERROR: An unexpected error occurred: ${String(error)}`
    }
  },
})
