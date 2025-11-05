#!/usr/bin/env python3
"""Analyzer entry point that dispatches to the configurable pipeline."""

from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parent
if str(SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPT_ROOT))

from analyzer_core import AnalyzerPipeline, load_manifest


def _build_pipeline() -> AnalyzerPipeline:
    manifest = load_manifest(SCRIPT_ROOT)
    return AnalyzerPipeline(manifest, base_path=SCRIPT_ROOT)


def main() -> int:
    payload = sys.stdin.read()
    try:
        request = json.loads(payload or "{}")
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Invalid JSON: {exc}")
        return 1

    pipeline = _build_pipeline()
    try:
        result = pipeline.process(request)
    except ValueError as exc:
        sys.stderr.write(str(exc))
        return 1

    sys.stdout.write(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
