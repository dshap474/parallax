# Prompt helpers: headless developer instructions and resource loading.
# USAGE:
#   from codex_app_client.prompts import load_headless_instructions, load_agents_template

from __future__ import annotations

from functools import lru_cache
from importlib import resources

# --------------------------------------------------------------------------- #
# Resource loading
# --------------------------------------------------------------------------- #


@lru_cache(maxsize=1)
def load_headless_instructions() -> str:
    """Load the bundled non-interactive developer instructions."""
    return _read_resource("headless.md")


@lru_cache(maxsize=1)
def load_agents_template() -> str:
    """Load the consumer AGENTS.md template used by ``cxa init``."""
    return _read_resource("AGENTS.template.md")


def _read_resource(name: str) -> str:
    package = "codex_app_client.resources"
    return resources.files(package).joinpath(name).read_text(encoding="utf-8")
