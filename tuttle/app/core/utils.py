"""Utility functions shared across the application."""

from typing import List, Tuple

import base64

import pycountry

from .formatting import fmt_currency  # noqa: F401 — re-export


def truncate_str(txt: str, max_chars: int = 25) -> str:
    if not txt:
        return ""
    if len(txt) <= max_chars:
        return txt
    else:
        return f"{txt[0:max_chars]}..."


def image_to_base64(image_path):
    """Converts an image to a base64-encoded string."""
    with open(image_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode("utf-8")
    return encoded_string


def get_currencies() -> List[Tuple[str, str, str]]:
    """Returns a list of available currencies sorted alphabetically"""
    currencies = []
    currency_list = list(pycountry.currencies)
    for currency in currency_list:
        abbreviation = currency.alpha_3
        symbol = currency.symbol if hasattr(currency, "symbol") else None
        currencies.append((currency.name, abbreviation, symbol))
    currencies.sort(key=lambda tup: tup[1])
    return currencies
