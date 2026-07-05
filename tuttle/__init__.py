"""Top-level package for tuttle."""

__authors__ = [
    "Christian Staudt",
    "Vladimir Peter",
]
__version__ = "3.13.2"

try:
    from . import app  # noqa: F401
except ImportError:
    pass

from . import (  # noqa: F401
    banking,
    calendar,
    invoicing,
    model,
    tax,
    timetracking,
    dataviz,
    time,
    rendering,
    os_functions,
    mail,
)
