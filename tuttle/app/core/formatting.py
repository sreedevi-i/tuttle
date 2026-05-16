"""Formatting utilities."""

from babel.numbers import format_currency as _babel_format_currency


def fmt_currency(value, currency: str = "EUR", locale: str = "en_US") -> str:
    """Format a numeric value as a currency string using babel.

    Args:
        value: Decimal, float, or int to format. None returns "---".
        currency: ISO 4217 code (e.g. "EUR", "USD", "SEK").
        locale: Babel locale for number formatting.
    """
    if value is None:
        return "—"
    return _babel_format_currency(float(value), currency, locale=locale)
