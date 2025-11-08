from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Protocol


@dataclass
class DetectorConfig:
    id: str
    config: Dict[str, Any]


class DetectorStage(Protocol):
    """Protocol for detector stages."""

    config: DetectorConfig

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:  # pragma: no cover - protocol signature
        ...


class BaseDetector:
    """Base class providing path/config utilities for detectors."""

    def __init__(self, *, config: Dict[str, Any], base_path: Path) -> None:
        self.base_path = base_path
        self.config = config

