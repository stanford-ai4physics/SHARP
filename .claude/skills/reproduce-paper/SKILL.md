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

<!-- TODO: add the `/replication-planner` subagent -->
<!-- Use `/replication-planner` to create a structured plan covering: -->

Using the PDF Reader's structured extraction, create a plan covering:

- Method implementation steps — derived from the "Methodology" and "Implementation Details" sections of the extraction
- Dataset acquisition and preprocessing — using the download URLs and preprocessing steps from the "Dataset" section
- Validation checkpoints — informed by the "Key Results" section (which metrics to check against, which figures to reproduce)
- Address any gaps listed in the "Missing Information" section (decide on reasonable defaults or search for answers)

### Phase 3: Implementation

**4. Implement methods**

Write Python scripts to:

<!-- TODO: add subagent for plotting -->

- Download / load the dataset using the source URL from the paper extraction
- Apply preprocessing and selection cuts as specified in the extraction's "Preprocessing" field
- Create validation plots of the features stored in the dataset (to verify that dataloading and processing doesn't contain bugs)
- Implement the method(s), using the exact hyperparameters from the extraction's hyperparameter table

**5. Validate methods**

<!-- TODO: add a reviewer subagent that critically evaluates the implementation and the corresponding validation -->

- Validate them with toy examples (even if that is not part of the paper)
- Compare intermediate results against any numerical values reported in the paper extraction

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

### Phase 5: Documentation

**7. Write Summary Report**

Create a report documenting:

- Paper reference and relevant figures reproduced
- Any discrepancies between your results and the paper's reported values, and their likely causes
- Output file locations
- Make sure that the subfolder where your output is stored contains instructions on how to run the code

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

For other independent steps (e.g., reading multiple prerequisite papers), launch multiple Task calls in a single response.

## Output Organization

```
output/
├── paper_reproduction/
│   ├── README.md                           # Summary report and instructions on how to run the code
│   ├── paper.pdf                           # Pdf file of the paper that is reproduced
│   ├── paper_summary.md                    # Structured extraction from the PDF Reader (methodology, datasets, hyperparameters, key results)
│   ├── src/
│   │   ├── model.py                        # Python source files
│   │   ├── data.py
│   │   └── ...
│   ├── scripts/
│   │   ├── dataset_validation.py           # Analysis script
│   │   └── histograms.npz                  # Computed histograms
│   └── plots/
│       ├── reproduce_paper_figure_3a.pdf   # Reproduced figures
│       ├── dataset_validation.pdf
│       └── ...
```
