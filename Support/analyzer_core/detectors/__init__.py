"""Detector registry for the analyzer pipeline."""

from .changepoint import ChangePointDetector
from .legacy import LegacyAnomalyDetector
from .multivariate import MultivariateDetector
from .new_talker import NewTalkerDetector
from .seasonality import SeasonalityDetector

__all__ = [
    "LegacyAnomalyDetector",
    "SeasonalityDetector",
    "ChangePointDetector",
    "MultivariateDetector",
    "NewTalkerDetector",
]
