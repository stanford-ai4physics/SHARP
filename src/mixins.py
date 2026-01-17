"""
Mixin classes for CATHODE figure reproduction
"""
import law


class DatasetMixin(law.Task):
    """
    Mixin for dataset-related parameters
    """

    n_background = law.Parameter(
        default=1000000,
        description="Number of background events to use",
    )

    n_signal = law.Parameter(
        default=1000,
        description="Number of signal events to inject",
    )

    signal_region_min = law.FloatParameter(
        default=3.3,
        description="Signal region lower bound in TeV",
    )

    signal_region_max = law.FloatParameter(
        default=3.7,
        description="Signal region upper bound in TeV",
    )

    def store_parts(self):
        sp = super().store_parts()
        return sp + (
            f"nbg_{self.n_background}",
            f"nsig_{self.n_signal}",
            f"sr_{self.signal_region_min}_{self.signal_region_max}",
        )


class ShiftedFeaturesMixin(law.Task):
    """
    Mixin for shifted features parameters
    """

    apply_shift = law.BoolParameter(
        default=False,
        description="Whether to apply feature shift (add correlations)",
    )

    shift_coefficient = law.FloatParameter(
        default=0.1,
        description="Coefficient for feature shifting",
    )

    def store_parts(self):
        sp = super().store_parts()
        if self.apply_shift:
            return sp + (f"shifted_{self.shift_coefficient}",)
        return sp + ("default",)


class ModelMixin(law.Task):
    """
    Mixin for model training parameters
    """

    model_type = law.Parameter(
        default="CATHODE",
        description="Model type: CATHODE, CWoLa, ANODE, Idealized, Supervised",
    )

    n_epochs = law.IntParameter(
        default=100,
        description="Number of training epochs",
    )

    batch_size = law.IntParameter(
        default=256,
        description="Batch size for training",
    )

    learning_rate = law.FloatParameter(
        default=1e-4,
        description="Learning rate",
    )

    def store_parts(self):
        sp = super().store_parts()
        return sp + (
            f"model_{self.model_type}",
            f"epochs_{self.n_epochs}",
            f"lr_{self.learning_rate}",
        )
