---
name: chat
description: "Chat about the current status of the analysis, review progress, and request revisions to milestones. Use when the user wants to talk about what's working, what isn't, or what needs changing. Triggers on: chat, review status, what's the status, request revision, something is wrong, adjust."
user-invocable: true
---

# Discuss Analysis Status

Interactive discussion about the current state of the analysis project.
Helps the user understand progress, diagnose issues, and request revisions
that get written into `project.json` for the Overwatcher to apply.

---

## The Job

1. Read `project.json` and `progress.txt` to understand current state
2. Present a concise status summary to the user
3. Have a conversation about any concerns, issues, or desired changes
4. If the user wants revisions: write them as a `"revisions"` array on the
   appropriate milestone in `project.json`

---

## Step 1: Status Summary

Read the current `project.json` and `progress.txt`, then present:

- Which milestones are done, which are pending, which are at a checkpoint
- The current checkpoint (if any) and what it achieved
- Any recent learnings or issues from `progress.txt`

Keep it concise — 5-10 lines max. Let the user drive the conversation.

---

## Step 2: Conversation

The user may want to:

- **Understand what happened:** Explain what the Overwatcher did, what tests
  passed or failed, what the subagents produced
- **Diagnose problems:** Help figure out why something isn't working — read
  relevant source files, test outputs, or logs
- **Request changes:** The user wants something adjusted — a different approach,
  a bug fixed, a naming convention changed, etc.

Listen carefully. Ask clarifying questions if the request is ambiguous.
Read the relevant code files to understand the current implementation before
suggesting changes.

---

## Step 3: Writing Revisions

When the user confirms they want changes applied, write them as a `"revisions"`
array on the appropriate milestone in `project.json`.

### Rules for writing revisions

- Each revision item must be a **concrete, actionable instruction** that the
  Overwatcher can execute without ambiguity
- **Only add `"revisions"` to milestones that have already been worked on**
  (`passes: true`). For future milestones (`passes: false`), edit their
  `description` or other fields directly in `project.json` instead — there is
  no existing work to revise, and adding revisions would waste an extra iteration
- If the milestone is at a checkpoint (`passes: true`, `checkpoint_approved: false`),
  add revisions directly — the Overwatcher will apply them on the next iteration
- If the milestone already has `checkpoint_approved: true`, set it back to `false`
  and add the revisions
- Do NOT set `passes: false` unless the user explicitly wants a full redo

### Revision format in project.json

```json
{
  "id": "M-003",
  "title": "ParticleNet-Lite model architecture",
  "is_checkpoint": true,
  "checkpoint_approved": false,
  "passes": true,
  "revisions": [
    "Rename knn() to k_nearest_neighbors() for clarity",
    "Add a test that checks output is invariant to particle ordering"
  ]
}
```

### Translating user concerns into revisions

The user might say vague things like "the plots look wrong" or "this command
doesn't work". Your job is to:

1. Investigate — read the code, check the outputs, understand the issue
2. Formulate concrete revision instructions the Overwatcher can act on
3. Confirm with the user before writing to `project.json`

**Good revisions:**
- "Fix the x-axis range in the mjj distribution plot to [3000, 4000] GeV"
- "The SelectEvents task crashes with KeyError 'jet_pt' — rename the column access to match the dataset schema"
- "Add a legend to all plots produced by PlotDistributions"

**Bad revisions (too vague):**
- "Fix the plots"
- "Make it work"
- "Improve the code"

---

## Step 4: Confirm and Save

Before writing revisions to `project.json`:

1. Show the user the exact revisions you will write
2. Show which milestone they will be added to
3. Ask for confirmation
4. Write to `project.json`
5. Tell the user to re-run `./researcher.sh` to apply the revisions

---

## Important

- Do NOT modify any source code, tests, or other files — only `project.json`
- Do NOT run the Overwatcher or any law tasks — just discuss and write revisions
- The Overwatcher will apply the revisions on its next iteration
- If the user wants to approve a checkpoint, help them set `checkpoint_approved: true`
  in `project.json` instead of writing revisions
