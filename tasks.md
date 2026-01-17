# Tasks

## Task 1: Reproduce Figure 8 from CATHODE Paper (arXiv:2109.00546)

### Objective
Reproduce Figure 8 which demonstrates CATHODE's robustness to correlations between features and the mass variable.

### Description
Figure 8 shows two panels:
- **Left**: Significance improvement vs signal efficiency for various methods on the shifted dataset
- **Right**: Ratio of significance improvement (shifted vs default dataset)

Methods to implement and compare:
1. CATHODE (our main method)
2. CWoLa Hunting
3. ANODE
4. Idealized Anomaly Detector
5. Fully Supervised Classifier

### Steps
1. Download LHC Olympics R&D dataset
2. Implement data preprocessing and feature engineering
3. Implement feature shifting (adding artificial correlations per Eq. 3 in paper)
4. Implement CATHODE method (MAF density estimator + sampling + classifier)
5. Implement comparison methods
6. Train all methods on both default and shifted datasets
7. Compute significance improvement characteristics (SIC)
8. Generate publication-quality Figure 8