"""Resolve the root data directory for all Tuttle user data.

Default: ``~/.tuttle``.  Override with the ``TUTTLE_DATA_DIR`` env var
to isolate dev data from a production install (e.g.
``TUTTLE_DATA_DIR=~/.tuttle-dev just dev``).
"""

import os
from pathlib import Path

_DEFAULT = Path.home() / ".tuttle"


def get_data_dir() -> Path:
    """Return the root data directory, creating it if necessary."""
    d = Path(os.environ.get("TUTTLE_DATA_DIR") or _DEFAULT)
    d.mkdir(parents=True, exist_ok=True)
    return d
