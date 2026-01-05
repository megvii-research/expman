## Project Overview

ExpMan is a zsh-based experiment management tool that leverages git-worktree to enable working on multiple git branches simultaneously. It's particularly useful for machine learning and experimental sciences where engineers need to run multiple experiments in parallel.

## Architecture

The entire tool is implemented as a single zsh script (`expman.zsh`) that provides:
- Git worktree management functions for parallel branch operations
- Integration with fzf for fuzzy searching through branches
- Zsh completion system for tab-completion of commands and branches

Key functions in expman.zsh:
- `_em_cmd_*`: Core command implementations (init, cd, checkout, new, push, delete)
- `_em_git_branches`: Lists all branches (local and remote)
- `_em_fzf_select_branch`: Interactive branch selection using fzf
- `__em_zsh_comdef`: Zsh completion definition

## Development Commands

Since this is a zsh script tool without traditional build/test infrastructure:

```bash
# Load the tool for testing in current shell
source expman.zsh

# Test individual commands
em init test-project
em new empty test-branch
em cd test-branch
em delete test-branch

# Check zsh syntax
zsh -n expman.zsh
```

## Testing Considerations

- The tool requires zsh shell and git
- fzf integration is optional but recommended for full functionality
- All git operations are performed via the `__vgit` wrapper function which echoes commands before execution
- The tool creates worktrees in a `work/` directory by default (configurable via EM_WORK_DIR_NAME)

## Key Implementation Details

- Uses git worktrees for parallel branch management
- Stores worktrees in `{project_root}/{EM_WORK_DIR_NAME}/{branch_name}/`
- Prevents deletion of master and empty branches
- Automatically handles worktree cleanup when deleting branches
- Supports both local and remote branch operations
