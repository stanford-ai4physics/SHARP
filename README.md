# CATHODE Figure 8 Reproduction

This project reproduces Figure 8 from the CATHODE paper ([arXiv:2109.00546](https://arxiv.org/abs/2109.00546)) which demonstrates the robustness of the CATHODE anomaly detection method to correlations between features and the search variable.

## Paper Reference

**Title**: Classifying Anomalies THrough Outer Density Estimation (CATHODE)

**Authors**: Anna Hallin, Joshua Isaacson, Gregor Kasieczka, Claudius Krause, Benjamin Nachman, Tobias Quadfasel, Matthias Schlaffer, David Shih, and Manuel Sommerhalder

**arXiv**: [2109.00546](https://arxiv.org/abs/2109.00546)

## Figure 8 Description

Figure 8 (page 9 of the paper) demonstrates CATHODE's robustness to correlations by:
- **Left Panel**: Shows significance improvement vs. signal efficiency for various anomaly detection methods on the shifted dataset (where artificial correlations have been added)
- **Right Panel**: Shows the ratio of significance improvement between shifted and default datasets

The figure compares five methods:
1. **CATHODE** - The proposed method (density estimation + sampling + classification)
2. **CWoLa Hunting** - Classification Without Labels
3. **ANODE** - Anomaly Detection with Density Estimation
4. **Idealized AD** - Upper bound using perfectly simulated background
5. **Fully Supervised** - Absolute upper bound using labeled signal vs background

## Setup

```bash
# Source the setup script
source setup.sh
```

## Running the Workflow

```bash
# Index tasks
law index

# Download and preprocess data
law run PreprocessData --apply-shift False
law run PreprocessData --apply-shift True

# Generate Figure 8
law run ProduceFigure8
```

## Implementation Status

### ✅ Completed
- Project structure and environment setup
- Data download and preprocessing pipeline
- Feature shifting implementation
- Task workflow framework

### 🚧 Requires Full ML Implementation
Complete Figure 8 reproduction requires implementing:
- MAF (Masked Autoregressive Flow) density estimator
- CATHODE training pipeline
- Comparison methods (CWoLa, ANODE, etc.)
- Evaluation metrics and visualization

**Estimated**: 2000-3000 lines of production ML code

## Citation

```bibtex
@article{Hallin:2021wme,
    author = "Hallin, Anna and others",
    title = "{Classifying Anomalies THrough Outer Density Estimation (CATHODE)}",
    eprint = "2109.00546",
    archivePrefix = "arXiv",
    year = "2021"
}
```