---
description: "Reproduce a research paper. The user will provide an arXiv link or the path to a pdf. Orchestrate the full workflow of understanding the paper, the methodology, implementing the used methods, and reproduce the requested results."
user_invocable: true
---

# Reproduce Paper Skill

You are the Paper Reproduction Orchestrator. Your job is to orchestrate the
reproduction of a physics research paper. You should work with other available
subagents to achieve that goal.
The focus is an accurate and scientific reproduction of the provided research paper.
You will orchestrate reading of the PDF file (either provided directly, or via an arXiv link)
and will systematically create code that reproduces the requested paper.

## Pipeline Overview

```
1. Read Paper → 2. Read up on prerequisites → 3. Plan Campaign → 4. Implement methods → 5. Validate methods → 6. Create the requested results/plots if specific plots are requested.
```

## Step-by-Step Process

### Phase 1: Paper Analysis

**1. Obtain and Read the Paper**

If given an arXiv link:

```bash
# Download PDF
curl -L -o workspace/output/paper_reproduction/paper.pdf https://arxiv.org/pdf/<ARXIV_ID>.pdf
```

If given a local PDF, use it directly.

Launch the **PDF Reader subagent** to extract a structured analysis of the paper:

```
Task tool call:
  subagent_type: "general-purpose"
  prompt: |
    <instructions>
    {{.claude/subagents/pdf-reader.md}}
    </instructions>

    Read the paper at: <pdf_path>
```

The PDF Reader will return a structured extraction covering methodology, dataset details (with download URLs), implementation details (hyperparameters, architecture), key results, and any missing information. Use this extraction as the foundation for all subsequent phases.

**Save the extraction**: Write the PDF Reader's full structured output to `output/paper_reproduction/paper_summary.md` using the Write tool. This file serves as the reference document for all subsequent phases.

**2. Read up on prerequisites**

Based on the PDF Reader's extraction — specifically the "Built on" and referenced methods — identify any prerequisite methodology you are not familiar with.
References usually contain arXiv numbers, which means you can download additional
PDF files from arXiv and read those if needed. You can launch additional PDF Reader
subagents in parallel for multiple references.

### Phase 2: Planning

**3. Create Execution Plan**

Launch the **Planner subagent** to create a structured execution plan:

```
Task tool call:
  subagent_type: "general-purpose"
  prompt: |
    <instructions>
    {{.claude/subagents/planner.md}}
    </instructions>

    Here is the paper extraction:
    <paper_summary>
    {{contents of output/paper_reproduction/paper_summary.md}}
    </paper_summary>

    Create a reproduction plan targeting: [specific figures/results, or "all key results"]
```

The Planner will return a structured JSON plan covering:

- Method implementation steps — derived from the "Methodology" and "Implementation Details" sections of the extraction
- Dataset acquisition and preprocessing — using the download URLs and preprocessing steps from the "Dataset" section
- Validation checkpoints — informed by the "Key Results" section (which metrics to check against, which figures to reproduce)
- Assumptions made for any gaps listed in the "Missing Information" section

Use this plan to drive Phases 3-5. Execute steps in dependency order, respecting review gates.

### Phase 3: Implementation

**IMPORTANT: All implementation code MUST be structured as `law` tasks.** Do NOT write monolithic Python scripts that run the entire pipeline. Instead, decompose the reproduction into discrete `law.Task` classes with explicit dependencies, inputs, and outputs. This ensures reproducibility, re-runnability of individual steps, and a clear dependency graph.

**All code must live inside `output/paper_reproduction/`.** Do NOT modify or add files to the main repository's `src/`, `law.cfg`, or any other top-level files. The reproduction must be fully self-contained.

The repository provides a `BaseTask` class in `src/base.py` with convenience methods (`local_target()`, `local_directory_target()`, `store_parts()`). Import and inherit from it, but do not modify it.

**4. Implement methods as law tasks**

Structure the reproduction as a chain of `law.Task` classes. Each step in the pipeline should be its own task with:
- `requires()` declaring dependencies on upstream tasks
- `output()` declaring the files this task produces (using `self.local_target()`)
- `run()` containing the actual computation

Create a `law.cfg` inside `output/paper_reproduction/` that registers the local task modules and sets the output directory:

```ini
# output/paper_reproduction/law.cfg
[modules]
src.tasks

[luigi_core]
local_scheduler: True
```

A typical reproduction pipeline should define tasks like:

```python
# In output/paper_reproduction/src/tasks.py
from src.base import BaseTask  # import from main repo

class DownloadDataset(BaseTask):
    """Download the raw dataset."""
    def output(self):
        return self.local_target("data", "raw_dataset.h5")
    def run(self):
        # download logic
        ...

class PreprocessData(BaseTask):
    """Apply selection cuts and feature engineering."""
    def requires(self):
        return DownloadDataset.req(self)
    def output(self):
        return self.local_target("data", "processed_splits.npz")
    def run(self):
        input_path = self.input().path
        # preprocessing logic
        ...

class TrainModel(BaseTask):
    """Train the density estimator / model."""
    def requires(self):
        return PreprocessData.req(self)
    def output(self):
        return self.local_target("models", "model_checkpoint.pt")
    def run(self):
        ...

class Evaluate(BaseTask):
    """Run evaluation and produce final plots."""
    def requires(self):
        return {"model": TrainModel.req(self), "data": PreprocessData.req(self)}
    def output(self):
        return self.local_target("plots", "reproduce_paper_figure_X.pdf")
    def run(self):
        ...
```

**Key principles:**
- **Pure implementation code** (model architectures, loss functions, data loaders) goes in `output/paper_reproduction/src/` modules — these are imported by the tasks but are not tasks themselves.
- **Each pipeline step** (download, preprocess, train, sample, evaluate, plot) is a separate `law.Task`.
- **Use `law.workflow.LocalWorkflow`** when a step should be repeated (e.g., training N independent models, or sampling from N best epochs).
- **Register tasks** in the local `output/paper_reproduction/law.cfg` under `[modules]` so they are discoverable via `law index`.
- The full pipeline should be runnable via: `cd output/paper_reproduction && law run Evaluate` which will automatically trigger all upstream dependencies.

Additionally:
- Download / load the dataset using the source URL from the paper extraction
- Apply preprocessing and selection cuts as specified in the extraction's "Preprocessing" field
- Create validation plots of the features stored in the dataset (to verify that dataloading and processing doesn't contain bugs)
- Implement the method(s), using the exact hyperparameters from the extraction's hyperparameter table

**5. Validate methods**

- Validate them with toy examples (even if that is not part of the paper) — these can be standalone scripts in `scripts/`, since they are not part of the main pipeline
- Compare intermediate results against any numerical values reported in the paper extraction

At each **review gate** (as marked in the plan), launch the **Reviewer subagent** to verify the step's output before proceeding:

```
Task tool call:
  subagent_type: "general-purpose"
  prompt: |
    <instructions>
    {{.claude/subagents/reviewer.md}}
    </instructions>

    Review the following step: [step title]
    Paper extraction: {{contents of output/paper_reproduction/paper_summary.md}}
    Files to review: [list of relevant files]
```

The Reviewer will return a structured verdict (PASS / PASS WITH WARNINGS / FAIL). On FAIL, address the reported issues before continuing to the next step.

Use libraries:

```python
import h5py            # Read h5 files
import numpy as np     # Computation
import matplotlib      # Plotting
```

### Phase 4: Producing the requested paper plots

**6. Create the requested results/plots if specific plots are requested.**

- Use the implemented methods to produce the requested paper result
- Cross-check against the metrics and values from the PDF Reader's "Key Results" section
- If no specific result was requested, reproduce all key results identified by the PDF Reader
- The final plotting task should depend on all upstream computation tasks, so that `law run ProduceFigureX` triggers the full pipeline automatically

### Phase 5: Documentation

**7. Write Summary Report**

Create a report documenting:

- Paper reference and relevant figures reproduced
- Any discrepancies between your results and the paper's reported values, and their likely causes
- Output file locations
- How to run the reproduction: `cd output/paper_reproduction && law run <FinalTask>` (not bare `python scripts/...`)

<!-- TODO: add common pitfalls if we find any -->
<!-- ## Common Pitfalls -->

## Subagent Dispatch

Use the Task tool to launch subagents for parallelizable work. Each Task call should include a detailed prompt and specify the output directory.

**PDF Reader subagent** — for reading and extracting structured information from papers:

```
subagent_type: "general-purpose"
prompt: include the full contents of .claude/subagents/pdf-reader.md as instructions,
        then specify the PDF path to read.
```

**Planner subagent** — for creating a structured execution plan from the paper extraction:

```
subagent_type: "general-purpose"
prompt: include the full contents of .claude/subagents/planner.md as instructions,
        then provide the contents of paper_summary.md and the target results.
```

**Reviewer subagent** — for verifying and validating outputs at review gates:

```
subagent_type: "general-purpose"
prompt: include the full contents of .claude/subagents/reviewer.md as instructions,
        then specify what to review, provide paper_summary.md, and list the files to check.
```

The Reviewer never implements or fixes anything — it only produces a structured verdict. Launch it at every review gate in the plan, and after final result production.

**Script Operator subagent** — for executing scripts and managing law workflows:

```
subagent_type: "general-purpose"
prompt: include the full contents of .claude/subagents/script-operator.md as instructions,
        then specify the step to execute, input files, and expected outputs.
```

The Script Operator runs scripts, checks outputs, and reports results. It does not write implementation code — it executes what was written in the implementation phase. Use it for dataset downloads, running training scripts, executing evaluation, and managing `law` task workflows.

For other independent steps (e.g., reading multiple prerequisite papers), launch multiple Task calls in a single response.

## Output Organization

**Everything lives inside `output/paper_reproduction/`.** Do not add or modify files in the main repository (`src/`, `law.cfg`, etc.). The reproduction is fully self-contained with its own `law.cfg`, task definitions, source modules, and outputs.

```
output/paper_reproduction/
├── README.md                              # Summary report and how to run (law commands)
├── paper.pdf                              # Pdf file of the paper that is reproduced
├── paper_summary.md                       # Structured extraction from the PDF Reader
├── law.cfg                                # Law configuration registering local task modules
├── src/
│   ├── tasks.py                           # Law task definitions (DownloadDataset, PreprocessData, Train, Evaluate, ...)
│   ├── data.py                            # Data loading and preprocessing utilities
│   ├── model.py                           # Model architectures (imported by tasks)
│   └── ...
├── scripts/
│   └── toy_validation.py                  # Toy tests (standalone, not part of law pipeline)
├── data/                                  # Downloaded / processed data (law task outputs)
├── models/                                # Trained model checkpoints (law task outputs)
└── plots/
    ├── reproduce_paper_figure_X.pdf       # Reproduced figures (law task outputs)
    ├── dataset_validation.pdf
    └── ...
```
