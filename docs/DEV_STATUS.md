# GitWiz – Development Status

Last update: (replace with date)

## 1. Overview

GitWiz provides:
- Conflict resolution panel (multi‑pane + actions)
- Modular commits picker (Telescope) with classification (ahead/behind/common/foreign)
- Diff content search (-G) inside commits picker
- Cherry-pick / revert batch operations with conflict integration
- Branch graph tab:
  - ASCII global multi-branch graph (lanes, birth labels, merge connectors)
  - Matrix view (branch status table with sort + filter)
  - Compact (topology compressed) view with foldable linear chains

## 2. Implemented Features (Current State)

| Area | Status | Notes |
|------|--------|-------|
| Config core | DONE | Added primary_branch override, graph config, lane label options |
| Conflict resolver | DONE (v1) | ours/theirs/base/keep_both/clean markers, metadata (cherry-pick/revert) |
| Commit classification | DONE | in_head, in_main, ahead/behind/common/foreign sets via rev-list |
| Commit picker modularization | DONE | Separated core (fetch/preview/filters/cache/highlights) from UI adapter |
| Commit filters (ga/gb/gf/gm/g*) | DONE | Dynamic preview summary |
| Diff content search (gs / g/) | DONE | Uses git log -G pattern |
| Multi-select disabling | DONE | Shift-Tab neutralized; actions single target |
| Keep both merge action | DONE | Marker parser integrated |
| Branch metadata extraction | DONE | ahead/behind/base/merged/stale (age), birth points |
| Graph tab layout | DONE | Tree + graph + details panes |
| Birth labels (◜) | DONE | In ASCII graph (labels_mode=birth) |
| Lane ownership (basic) | PARTIAL | Owner chosen from first exclusive owner commit; color groups defined |
| Merge connectors (╱╲) | BASIC | Visual hint only (no full diagonal continuity) |
| Matrix view | FIRST PASS | Sorting, filtering (regex), stable columns |
| Compact topology | FIRST PASS | Linear chain folding, per-line expand/collapse |
| Primary branch detection | HARDENED | Silent fallback, override + candidate list |
| ASCII graph lane color highlight | PARTIAL | Columns colored by owner (no diagonal continuity coloring) |
| Delete branch (safe / force) | DONE | dd / D from tree |
| Checkout branch | DONE | <CR> / c |
| Create branch from commit (picker) | DONE | <CR> in commits picker (option D earlier) |

## 3. Architecture (High-Level)

```
+---------------------------+
| core.config              |
+------------+-------------+
             |
             v
+------------+-------------+
| git runners / wrappers   |
| (runner, primary_branch) |
+------------+-------------+
             |
   +---------+-------------------------------+
   |                                         |
   v                                         v
Commits domain (classification)      Branches domain (ahead/behind/base)
   |                                         |
   |       +----------------------+          |
   +-----> UI adapters (Telescope) <---------+
           |  (adapter_commits)   |
           +----------------------+
                     |
         +-----------+-----------+
         | Preview (fetch, diff) |
         +-----------+-----------+
                     |
              Conflict resolver
                     |
               Graph subsystem
```

## 4. Graph Subsystem Modes

```
[Tree Pane] -- selection --> [Graph Renderer Dispatcher]
                                |
        +-----------------------+---------------------------+
        |                       |                           |
     ascii                matrix (table)              compact (folded)
        |                       |                           |
   lanes build            branches summary            raw log parse
(exclusive sets, birth)      sort/filter           fold linear chains
```

## 5. Data Flows

### Commit Classification
1. rev-list HEAD / rev-list primary → head_set / main_set
2. git log --all (--pretty custom) limited N
3. Per commit categorize: ahead / behind / common / foreign
4. Finder / preview merges counts + filter mode

### Branch Graph (ASCII mode)
1. for-each-ref (local [+ optional remote]) → tips
2. rev-list exclusive (branch ^ primary) → exclusive sets
3. birth commit per branch (first exclusive)
4. multi-branch log (--parents) truncated
5. Lane assignment (simple first-parent placement + additional parent insertion)
6. Merge connectors hint (╱╲)
7. Lane ownership color = first exclusive owner encountered

## 6. Design Decisions

| Decision | Rationale | Status |
|----------|-----------|--------|
| Use rev-list sets for reachability | Batch reachability faster than merge-base per commit | Accepted |
| Limit global graph commits (default 400) | Performance & readability | Accepted |
| Birth labeling at node (◜) instead of inline every commit | Reduces visual noise | Accepted |
| ASCII lane coloring per column, not per path | Simpler initial highlight step | Interim |
| Matrix view separate from ASCII graph | Different cognitive tasks (status vs structure) | Accepted |
| Compact view folds purely linear chains | Preserve important structural commits only | Accepted |
| Search triggers (gs / g/) do full list requery | Simplicity, adequate performance for current limits | Accepted |

## 7. Current Limitations / Technical Debt

| Area | Limitation |
|------|------------|
| Graph lane coloring | No diagonal continuity coloring; connectors not recolored |
| Merge rendering | Only marks immediate parents with ╱╲ (no multi-line wrap) |
| Focus mode | Not implemented (planned toggle to isolate selected branch + primary) |
| Compact mode | Birth labels & lane colors not integrated; no branch context |
| Matrix view styling | No highlight groups per status (merged/stale/ahead) yet |
| Caching | Full rebuild on every refresh (no dependency-based invalidation) |
| Tests | No automated test suite for parser / classification / graph building |
| Performance scaling | Very large repos (>50k commits) unbenchmarked; no progressive paging |

## 8. Backlog (Prioritized)

### P0 (Next)
1. Focus mode (gF) – filter graph (ascii + compact) to selected branch + primary + merge connectors
2. Enhanced merge diagonals – multi-line continuity (retain lane shapes)
3. Matrix status coloring – highlight merged, stale, head row
4. Compact mode birth integration – show ◜ where applicable in unfolded nodes
5. Lane recolor refresh on filter/change (avoid stale highlights)
6. Export DOT / Mermaid command (:GitWizGraphExport {dot|mermaid})

### P1
7. Diff scope mode (compare selected branch vs primary) – new view gW
8. Activity timeline (heatmap) – optional panel or alternate matrix submode
9. Branch focus diff aggregated (panel details: base..branch stats)
10. Batch delete stale merged branches (interactive confirm list)
11. Inline refs toggle (R) – cycle birth / tip / repeat
12. Repeat label mode (repeat_every N commits) implementation

### P2
13. Advanced lane compaction heuristics (collapse by depth weighting)
14. Incremental caching (hash -> precomputed lane meta)
15. Rebase assist (interactive list of behind commits, auto cherry-pick plan)
16. Quick actions in matrix (mark stale ignore, protect branch)
17. Multi-root workspace detection (cache per repo root)
18. Test suite (busted or plenary) for parser & lane assignment

### P3 (Stretch / Exploratory)
19. Inline blame overlay (latest author initials per lane segment)
20. Cross-repo graph imports (monorepo scenario)
21. Passive watch mode (auto-refresh on git events)
22. Telemetry (timing metrics for large repos)
23. Visual folding of merge subtrees (collapsible merges)
24. Visual diff highlight inside graph nodes (size-coded changes)

## 9. Incremental Roadmap (Suggested)

| Iteration | Goals |
|-----------|-------|
| 1 | Focus mode + matrix coloring + compact birth labels |
| 2 | Merge diagonals refinement + DOT/Mermaid export |
| 3 | Diff scope mode + lane recolor improvements |
| 4 | Activity timeline + filter toggles (refs cycle) |
| 5 | Caching & performance pass + test harness |
| 6 | Rebase assist + batch stale cleanup |
| 7 | Advanced lane compaction + repeat label mode |

## 10. Proposed Highlight Groups (Upcoming)

```
GitWizMatrixHead
GitWizMatrixMerged
GitWizMatrixStale
GitWizMatrixAhead
GitWizMatrixBehind
GitWizGraphFocusLane
GitWizGraphFocusDim
```

## 11. ASCII Diagrams – Future Focus Mode Concept

```
Before focus (no filter):
│ ● ... many lanes ...
│ │ ● commitX (foreign)
│ │ │ ● commitY (other branch)

After gF (focus branch=feature/login):
Lane(A) main  Lane(B) feature/login
│ ● base
│ ● merge commit (main)
│   ╲
│    ● branch exclusive 1
│    ● branch exclusive 2 (HEAD)
(dim all unrelated lanes)
```

## 12. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large repo slowdown | Poor UX | Add progressive paging & caching |
| Regex filter misuse (catastrophic pattern) | Freeze | Add timeout guard / fallback to literal |
| Merge diagonal complexity | Visual confusion | Progressive enhancement, keep fallback minimal |
| Stale branch mass delete errors | Data loss risk | Confirm each / dry-run mode |

## 13. Testing Targets (Planned)

| Component | Tests |
|-----------|-------|
| Conflict parser | Marker detection, malformed block recovery |
| Commit classification | Edge cases: shallow clone, missing main |
| Graph lane assignment | Deterministic lane indexes for fixtures |
| Birth labeling | Branch with no divergence, deep divergence |
| Compact folding | Mixed keep/fold boundaries correctness |
| Matrix sorting | Stable, directional toggle |

## 14. Configuration Surface (Key)

| Key | Purpose |
|-----|---------|
| graph.max_commits_global | Upper bound global graph range |
| graph.labels_mode | 'birth' (current) next: 'tip', 'repeat' |
| graph.lanes_colors_max | Distinct color lanes cap |
| graph.focus_key | Planned key for focus mode |
| primary_branch_override | Force base branch |
| commits.limit | Max commits load in picker |

## 15. Pending Design Decisions

| Topic | Options | Tentative |
|-------|---------|-----------|
| Focus dim method | (dim hl) vs (hide) vs (collapse) | Dim first, optional hide later |
| Repeat labels spacing | fixed N vs adaptive by screen width | Fixed (config repeat_every) |
| Merge diagonal style | Unicode (╱╲) vs ASCII (/\\) | Unicode fallback ASCII in no-nerd env |
| Lane color collisions | Cycle palette vs hash color | Palette, hash fallback |

## 16. Immediate Action Items (Concrete)

1. Implement focus mode skeleton (gF toggles a flag; filter graph lines).
2. Add highlight groups for matrix statuses.
3. Integrate birth labels in compact (reuse birth_points).
4. Add exporter command for DOT/Mermaid.
5. Add lane recolor pass after branch filters cycle.
6. Write minimal tests for conflict parser (foundation).

## 17. Contribution Notes (Internal)

- All code comments in English (project convention).
- Keep new modules small & pure (return { build=... }) for reusability.
- Avoid blocking I/O in UI thread: batch git calls if adding heavy operations.
- For new views: add a mode module under graph/modes and dispatch by state.view_mode.

---
