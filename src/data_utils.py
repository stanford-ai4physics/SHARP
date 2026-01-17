"""
Data utilities for CATHODE figure reproduction
"""
import numpy as np
import h5py
from pathlib import Path


def load_lhco_data(file_path):
    """
    Load LHC Olympics R&D dataset

    Parameters
    ----------
    file_path : str or Path
        Path to the HDF5 file

    Returns
    -------
    dict
        Dictionary containing events and labels
    """
    with h5py.File(file_path, "r") as f:
        # Load all datasets
        data = {
            "mJJ": f["mJJ"][:],
            "mJ1": f["mJ1"][:],
            "DeltaM": f["DeltaM"][:],
            "tau21_J1": f["tau21_J1"][:],
            "tau21_J2": f["tau21_J2"][:],
            "label": f["label"][:] if "label" in f else None,
        }
    return data


def apply_feature_shift(data, shift_coefficient=0.1):
    """
    Apply feature shift to add correlations with mJJ

    According to Eq. 3 in the paper:
    mJ1 -> mJ1 + 0.1 * mJJ
    DeltaM -> DeltaM + 0.1 * mJJ

    Parameters
    ----------
    data : dict
        Data dictionary with features
    shift_coefficient : float
        Coefficient for shifting (default 0.1)

    Returns
    -------
    dict
        Data dictionary with shifted features
    """
    shifted_data = data.copy()
    shifted_data["mJ1"] = data["mJ1"] + shift_coefficient * data["mJJ"]
    shifted_data["DeltaM"] = data["DeltaM"] + shift_coefficient * data["mJJ"]
    return shifted_data


def get_signal_sideband_regions(data, sr_min=3.3, sr_max=3.7):
    """
    Split data into signal region (SR) and sideband (SB) regions

    Parameters
    ----------
    data : dict
        Data dictionary
    sr_min : float
        Signal region lower bound in TeV
    sr_max : float
        Signal region upper bound in TeV

    Returns
    -------
    dict
        Dictionary with SR and SB masks
    """
    mJJ = data["mJJ"]
    sr_mask = (mJJ >= sr_min) & (mJJ <= sr_max)
    sb_mask = ~sr_mask

    return {
        "sr_mask": sr_mask,
        "sb_mask": sb_mask,
        "sr_data": {k: v[sr_mask] for k, v in data.items()},
        "sb_data": {k: v[sb_mask] for k, v in data.items()},
    }


def get_features(data, include_mJJ=False):
    """
    Extract feature matrix from data dictionary

    Parameters
    ----------
    data : dict
        Data dictionary
    include_mJJ : bool
        Whether to include mJJ as a feature

    Returns
    -------
    np.ndarray
        Feature matrix of shape (n_events, n_features)
    """
    features = [
        data["mJ1"],
        data["DeltaM"],
        data["tau21_J1"],
        data["tau21_J2"],
    ]

    if include_mJJ:
        features.append(data["mJJ"])

    return np.column_stack(features)


def preprocess_features(X, transform_type="logit"):
    """
    Preprocess features for training

    Parameters
    ----------
    X : np.ndarray
        Feature matrix
    transform_type : str
        Type of transformation: "logit", "standard", or "none"

    Returns
    -------
    np.ndarray
        Transformed features
    dict
        Transformation parameters
    """
    # First, scale to [0, 1]
    X_min = X.min(axis=0)
    X_max = X.max(axis=0)
    X_scaled = (X - X_min) / (X_max - X_min + 1e-8)

    params = {
        "X_min": X_min,
        "X_max": X_max,
    }

    if transform_type == "logit":
        # Logit transform
        epsilon = 1e-6
        X_scaled = np.clip(X_scaled, epsilon, 1 - epsilon)
        X_transformed = np.log(X_scaled / (1 - X_scaled))

        # Standardize
        mean = X_transformed.mean(axis=0)
        std = X_transformed.std(axis=0)
        X_final = (X_transformed - mean) / (std + 1e-8)

        params["mean"] = mean
        params["std"] = std
        params["transform_type"] = "logit"

    elif transform_type == "standard":
        # Just standardize
        mean = X_scaled.mean(axis=0)
        std = X_scaled.std(axis=0)
        X_final = (X_scaled - mean) / (std + 1e-8)

        params["mean"] = mean
        params["std"] = std
        params["transform_type"] = "standard"

    else:  # none
        X_final = X_scaled
        params["transform_type"] = "none"

    return X_final, params


def inverse_preprocess_features(X_transformed, params):
    """
    Inverse transformation to get back to original feature space

    Parameters
    ----------
    X_transformed : np.ndarray
        Transformed features
    params : dict
        Transformation parameters

    Returns
    -------
    np.ndarray
        Original features
    """
    transform_type = params["transform_type"]

    if transform_type == "logit":
        # Inverse standardization
        X_logit = X_transformed * params["std"] + params["mean"]

        # Inverse logit
        X_scaled = 1.0 / (1.0 + np.exp(-X_logit))

    elif transform_type == "standard":
        # Inverse standardization
        X_scaled = X_transformed * params["std"] + params["mean"]

    else:  # none
        X_scaled = X_transformed

    # Inverse scaling
    X_original = X_scaled * (params["X_max"] - params["X_min"]) + params["X_min"]

    return X_original


def compute_sic(y_true, y_pred, n_points=1000):
    """
    Compute Significance Improvement Characteristic (SIC)

    SIC = S / sqrt(B) where S is signal efficiency and B is background efficiency

    Parameters
    ----------
    y_true : np.ndarray
        True labels (1 for signal, 0 for background)
    y_pred : np.ndarray
        Predicted scores
    n_points : int
        Number of points to evaluate

    Returns
    -------
    dict
        Dictionary with signal_eff, background_eff, and sic arrays
    """
    # Sort by prediction score (descending)
    sorted_indices = np.argsort(y_pred)[::-1]
    y_true_sorted = y_true[sorted_indices]

    n_signal_total = (y_true == 1).sum()
    n_background_total = (y_true == 0).sum()

    # Compute cumulative sums
    signal_cumsum = np.cumsum(y_true_sorted == 1)
    background_cumsum = np.cumsum(y_true_sorted == 0)

    # Compute efficiencies
    signal_eff = signal_cumsum / n_signal_total
    background_eff = background_cumsum / n_background_total

    # Compute SIC
    sic = signal_eff / np.sqrt(background_eff + 1e-8)

    # Sample at regular intervals
    indices = np.linspace(0, len(signal_eff) - 1, n_points).astype(int)

    return {
        "signal_eff": signal_eff[indices],
        "background_eff": background_eff[indices],
        "sic": sic[indices],
    }
