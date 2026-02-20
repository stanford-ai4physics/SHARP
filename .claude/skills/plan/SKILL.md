---
name: plan
description: "Generate a physics analysis plan for a new or reinterpretation study. Use when planning an original analysis, a reinterpretation, or when asked to create an analysis plan. Triggers on: create a prd, write analysis plan, plan this analysis, spec out, plan this study."
user-invocable: true
---

# Analysis Plan Generator

Create a detailed physics analysis plan that is scientifically clear, actionable,
and suitable for conversion into `project.json` milestones via `/setup`.

**Important:** Do NOT start implementing. Just create the plan.

---

## The Job

1. Receive an analysis description from the researcher
2. Ask 3-5 essential clarifying questions (with lettered options)
3. Generate a structured analysis plan based on answers
4. Save to `analysis-plan.md` at the repo root

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial description is ambiguous. Focus on:

- **Scientific goal:** What physics question does this address?
- **Dataset:** What data or simulation is available?
- **Method:** Is the approach known, or does it need to be designed?
- **Scope:** Reimplementation, reinterpretation, or new analysis?
- **Success criteria:** What does a successful outcome look like?

### Format Questions Like This:

```
1. What is the primary scientific goal?
   A. Reproduce existing results from a paper
   B. Reinterpret existing results with a new method
   C. Perform an original search/measurement
   D. Other: [please specify]

2. What dataset will be used?
   A. Existing public dataset (specify which)
   B. Simulated data to be generated
   C. Real collision data (specify experiment)
   D. Other: [please specify]

3. What is the analysis method?
   A. Cut-based selection
   B. ML-based classifier
   C. Density estimation / anomaly detection
   D. Statistical fit / limit setting
```

This lets the researcher respond with "1B, 2A, 3C" for quick iteration.

---

## Step 2: Analysis Plan Structure

### 1. Overview
Brief description of the physics goal and approach.

### 2. Scientific Goals
Specific, measurable objectives:
- What observable or result will be produced?
- What comparison or baseline exists?
- What would constitute a successful reimplementation or new result?

### 3. Analysis Steps
Break the analysis into logical stages, each small enough for one Overwatcher
iteration. For each step:

```markdown
### Step N: [Title]
**Goal:** What this step produces
**Method:** How it will be done
**Success criterion:** How we know it worked (quantitative where possible)
**Depends on:** Which previous steps must be complete first
```

### 4. Dataset & Inputs
- Data source (paper, public repository, simulation)
- Format (ROOT, HDF5, CSV, etc.)
- Expected size and key features

### 5. Key Observables
- Which quantities will be computed
- Expected distributions or values (from paper or physics intuition)

### 6. Statistical Treatment
- How results will be quantified (significance, limits, comparison metrics)
- Treatment of uncertainties (statistical, systematic)

### 7. Non-Goals
What this analysis will NOT do — important for keeping scope manageable.

### 8. Open Questions
Physics or technical questions that need to be resolved during the analysis.

---

## Writing for the Overwatcher

The plan will be read by the Overwatcher agent and converted to `project.json`
milestones. Therefore:

- Be explicit and unambiguous — "apply mjj > 1000 GeV cut" not "select high-mass events"
- Success criteria must be verifiable by the Tester agent
- Steps should be independent enough to run in isolation as law tasks
- Reference the paper (arXiv ID) wherever specific numbers come from

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** repo root
- **Filename:** `analysis-plan.md`

---

## Example

```markdown
# Analysis Plan: CATHODE Reinterpretation with Supervised Classifier

## Overview

Reinterpret the CATHODE anomaly detection analysis (arXiv:2109.00546) by
replacing the unsupervised flow-based classifier with a supervised classifier
trained on a known BSM signal. Goal: compare sensitivity between the two approaches.

## Scientific Goals

- Reproduce the CATHODE baseline result (AUC, significance) within 5%
- Train a supervised classifier on a benchmark signal (Z' → qq, m=3 TeV)
- Compare ROC curves and expected significance between supervised and unsupervised

## Analysis Steps

### Step 1: Paper specification
**Goal:** Full methodology spec extracted from arXiv:2109.00546
**Method:** Paper Analyst reads paper and produces spec.md
**Success criterion:** spec.md covers dataset, signal region, flow architecture,
classifier setup, and all expected results from the paper
**Depends on:** Nothing

### Step 2: Data loading and exploration
**Goal:** Dataset loaded, key distributions reproduced
**Method:** Law task LoadData reads HDF5 files, plots mjj, pT, and substructure variables
**Success criterion:** mjj distribution matches paper Figure 1 qualitatively
**Depends on:** Step 1

### Step 3: Signal region selection
**Goal:** Event selection matching paper Section 2
**Method:** Law task SelectEvents applies mjj window and object cuts
**Success criterion:** Event yields within 10% of paper Table 1
**Depends on:** Step 2

...

## Dataset & Inputs

- Source: LHCO R&D dataset (zenodo.org/record/6466204)
- Format: HDF5, ~1M events, features: mjj, m1, m2, tau21_1, tau21_2
- Already available in source/

## Key Observables

- mjj: dijet invariant mass, signal region 3.3-3.7 TeV
- Classifier score distribution in signal vs sideband
- ROC AUC: expect ~0.8 for CATHODE baseline (paper Figure 3)

## Statistical Treatment

- Significance estimated via likelihood ratio test
- Systematic uncertainties: limited to statistical for this study
- Trial factor: single signal region, no LEE correction needed

## Non-Goals

- No real data — simulation only
- No full systematic uncertainty treatment
- No publication-quality plots (clarity over style)

## Open Questions

- Does the supervised classifier require signal injection during training, or is
  a pure signal sample sufficient?
- What signal cross-section assumption to use for sensitivity comparison?
```

---

## Checklist

Before saving `analysis-plan.md`:

- [ ] Asked clarifying questions with lettered options
- [ ] Incorporated researcher's answers
- [ ] Each step has a verifiable success criterion
- [ ] Dataset and inputs are specified concretely
- [ ] Non-goals define clear scope boundaries
- [ ] Open questions are listed
- [ ] Saved to `analysis-plan.md`
