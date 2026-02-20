---
name: setup
description: "Convert a physics analysis plan into project.json format for the Researcher loop. Use when you have a paper or analysis description and need to create the milestone plan. Triggers on: create project.json, set up analysis, create project.json, ralph json, create milestone plan."
user-invocable: true
---

# Analysis Milestone Planner

Converts a physics analysis description or paper reference into `project.json` —
the milestone plan that drives the Overwatcher autonomous loop.

---

## The Job

Take a paper reference or analysis description and produce `project.json` at the
repo root. Each milestone is one focused unit of work completable in a single
Overwatcher iteration.

---

## Output Format

```json
{
  "paper": "arXiv:XXXX.XXXXX",
  "title": "Short analysis title",
  "branchName": "reimplementation/paper-name-kebab-case",
  "milestones": [
    {
      "id": "M-001",
      "title": "Milestone title",
      "description": "What the Overwatcher should achieve in this milestone",
      "subagents": ["paper-analyst"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    }
  ]
}
```

---

## Milestone Sizing: The Number One Rule

**Each milestone must be completable in ONE Overwatcher iteration (one context window).**

The Overwatcher spawns a fresh Claude instance per iteration. If a milestone is too
large, the context runs out before it finishes.

### Right-sized milestones:
- Extract full methodology spec from the paper
- Implement event selection law task and its tests
- Train and evaluate a single ML model
- Implement background estimation for one region

### Too large (split these):
- "Implement the full analysis pipeline" → split into selection, training, evaluation, statistics
- "Reproduce all paper results" → split into one milestone per figure/table group

**Rule of thumb:** If a milestone requires more than 2-3 law tasks, split it.

---

## Standard Milestone Sequence

For a typical paper reimplementation, use this structure as a starting point and
adapt to the specific paper:

| ID | Title | Subagents | Checkpoint |
|----|-------|-----------|------------|
| M-001 | Paper specification | paper-analyst | ✓ |
| M-002 | Data exploration | coder, tester | ✗ |
| M-003 | Event selection | coder, tester | ✓ |
| M-004 | Observable computation | coder, tester | ✗ |
| M-005 | [ML / background estimation] | coder, tester | ✓ |
| M-006 | Statistical analysis | statistician, tester | ✓ |
| M-007 | Results comparison | tester | ✓ |

Checkpoints (✓) are milestones where the human must review and approve before
the Overwatcher continues. All other milestones run autonomously.

---

## Milestone Fields

- **id**: Sequential, `M-001`, `M-002`, etc.
- **title**: Short, action-oriented (e.g., "Extract paper specification")
- **description**: What the Overwatcher should produce — concrete and verifiable
- **subagents**: Which subagents will be invoked (`paper-analyst`, `coder`, `tester`, `statistician`)
- **is_checkpoint**: `true` if human review is required after this milestone passes
- **checkpoint_approved**: Always `false` initially
- **passes**: Always `false` initially

---

## Acceptance: What Makes a Milestone "Done"

The Overwatcher marks a milestone `passes: true` only when the Tester returns
PASS or PARTIAL (no blockers) on all law tasks in the milestone. Make the
description specific enough that this is unambiguous:

### Good descriptions (verifiable):
- "Paper Analyst extracts full spec to `spec.md`: event selection, ML architecture, expected results"
- "Law task `SelectEvents` implemented and passes Tester checks: modularity PASS, validity PASS"
- "ROC curve reproduced within 5% of Figure 3 in the paper"

### Bad descriptions (vague):
- "Understand the paper"
- "Implement the selection"
- "Good results"

---

## Milestone Ordering: Dependencies First

Earlier milestones must not depend on later ones.

**Correct order:**
1. Paper spec (needed by all other milestones)
2. Data exploration (needed before any task can run)
3. Event selection (needed before any downstream task)
4. Observables / features
5. ML / background estimation
6. Statistical interpretation
7. Results comparison

---

## Archiving Previous Runs

Before writing a new `project.json`, check if one already exists:

1. Read the current `project.json` if it exists
2. If `branchName` differs from the new analysis:
   - Create `archive/YYYY-MM-DD-[old-branch]/`
   - Copy current `project.json` and `progress.txt` there
   - Reset `progress.txt` with a fresh header

---

## Checklist Before Saving

- [ ] Previous run archived (if `project.json` exists with different `branchName`)
- [ ] Each milestone is completable in one iteration
- [ ] Milestones are ordered by dependency
- [ ] Checkpoint milestones are placed at natural human review points
- [ ] All descriptions are specific and verifiable
- [ ] `passes: false` and `checkpoint_approved: false` for all milestones
- [ ] `subagents` list reflects which agents are actually needed

---

## Example

**Input:** "Reimplement the CATHODE anomaly detection paper (arXiv:2109.00546)"

**Output `project.json`:**
```json
{
  "paper": "arXiv:2109.00546",
  "title": "CATHODE Anomaly Detection Reimplementation",
  "branchName": "reimplementation/cathode-2109-00546",
  "milestones": [
    {
      "id": "M-001",
      "title": "Paper specification",
      "description": "Paper Analyst extracts full spec to spec.md: dataset, signal region definition, normalizing flow architecture, classifier setup, expected AUC and significance values",
      "subagents": ["paper-analyst"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-002",
      "title": "Data exploration",
      "description": "Law task LoadData implemented and passing: loads dataset, verifies feature shapes, produces distribution plots for key variables",
      "subagents": ["coder", "tester"],
      "is_checkpoint": false,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-003",
      "title": "Signal region selection",
      "description": "Law task SelectEvents implemented and passing: applies mjj window cut, sidebands defined, event yields within 10% of paper Table 1",
      "subagents": ["coder", "tester"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-004",
      "title": "Normalizing flow density estimation",
      "description": "Law task TrainFlow implemented and passing: normalizing flow trained on sideband, density estimates produced for signal region",
      "subagents": ["coder", "tester"],
      "is_checkpoint": false,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-005",
      "title": "Anomaly classifier",
      "description": "Law task TrainClassifier implemented and passing: classifier trained on flow samples vs data, AUC within 5% of paper Figure 3",
      "subagents": ["coder", "tester"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-006",
      "title": "Statistical significance",
      "description": "Statistician reviews and implements significance estimation: p-value computation matches paper methodology, trial factor treatment correct",
      "subagents": ["statistician", "tester"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    },
    {
      "id": "M-007",
      "title": "Results comparison",
      "description": "Tester produces full comparison report against all paper figures and tables: distributions, ROC curves, significance values",
      "subagents": ["tester"],
      "is_checkpoint": true,
      "checkpoint_approved": false,
      "passes": false
    }
  ]
}
```
