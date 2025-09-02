# GitWiz# GitWiz

**Visual and interactive Git plugin for Neovim.**

## Purpose

GitWiz provides a visual interface for common and advanced Git tasks (branches, stashes, conflicts, diffs, cherry-pick, etc.) using Telescope and floating windows. The plugin is modular and extensible for future integrations like CopilotChat.

## Structure

```
lua/gitwiz/
├── init.lua           -- Entry point for the plugin
├── telescope.lua      -- Telescope sources and pickers
├── actions.lua        -- Git actions (checkout, merge, diff, etc.)
├── ui.lua             -- Floating windows, buffers, UI helpers
├── copilot.lua        -- (Future) CopilotChat integration
```

## Initial Tasks

- [ ] Create repository and local folder
- [x] Initialize plugin structure and base files
- [ ] Define entry point and register main commands
- [ ] Implement Telescope source to list Git branches
- [ ] Implement basic action: checkout selected branch
- [ ] Add floating window to show branch details
- [ ] Document structure and initial commands
- [ ] Track progress and update the task list

## Usage

After installation, use `:GitWizBranches` to list and interact with Git branches.

## Development

See code comments for extension points and implementation details.

## Roadmap

### Stage 1: Base and Usability
- [x] List local and remote branches
- [x] Checkout branches
- [x] Show repository status (modified, staged, untracked files)
- [x] View commit history per branch
- [x] View commit details
- [x] Visual diff between files/commits
- [x] Interactive blame per file/line
- [x] Floating windows and dedicated buffers for each feature
- [x] Icons and colors (NerdFonts) in UI
- [x] Quick actions from Telescope and configurable keymaps

### Stage 2: Advanced Branch and Commit Management
- [ ] Create, rename, and delete branches
- [ ] Merge branches
- [ ] Interactive rebase
- [ ] Cherry-pick commits
- [ ] Revert commits
- [ ] Squash commits

### Stage 3: Stash and Advanced Search
- [ ] List stashes
- [ ] Create, apply, and drop stashes
- [ ] View stash contents
- [ ] Search by commit message, author, or file

### Stage 4: Remote Integration and Sync
- [ ] View and manage remotes
- [ ] Push and pull branches
- [ ] Sync branches with remote

### Stage 5: Conflict Resolution and Advanced Visualization
- [ ] Detect and show conflicted files
- [ ] Visualize and resolve conflicts (visual tool)
- [ ] Visualize branch history and relationships (graph)
- [ ] Tree view for branches and commits

### Stage 6: Integrations and Advanced Tools
- [ ] CopilotChat integration for contextual help
- [ ] GitHub issues and PRs integration
