"""Defines the app theme — dark only, macOS-inspired."""

from flet import Theme, ColorScheme, TextTheme, ThemeMode, VisualDensity
from .fonts import DEFAULT_FONT
from .colors import accent, bg, bg_surface, text_primary, text_secondary, border, danger
from enum import Enum


# Kept for backward compatibility — always returns dark.
class THEME_MODES(Enum):
    light = "dark"  # mapped to dark
    dark = "dark"

    def __str__(self) -> str:
        return str(self.value)


def get_theme_mode_from_value(value: str):
    # Always dark
    return THEME_MODES.dark


APP_THEME = Theme(
    color_scheme_seed=accent,
    color_scheme=ColorScheme(
        primary=accent,
        on_primary="#FFFFFF",
        surface=bg_surface,
        on_surface=text_primary,
        error=danger,
        outline=border,
        surface_container=bg_surface,
        on_surface_variant=text_secondary,
    ),
    use_material3=True,
    font_family=DEFAULT_FONT,
    visual_density=VisualDensity.COMPACT,
)
