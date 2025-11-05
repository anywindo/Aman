"""Analyzer pipeline package for Phase 6 refactor."""

from pathlib import Path
from typing import Any, Dict, Optional

from .pipeline import AnalyzerPipeline, load_manifest


def build_default_pipeline(base_path: Optional[Path] = None) -> AnalyzerPipeline:
    """Convenience helper to build a pipeline using the default manifest."""

    manifest = load_manifest(base_path)
    return AnalyzerPipeline(manifest, base_path=base_path)


__all__ = [
    "AnalyzerPipeline",
    "build_default_pipeline",
    "load_manifest",
]
