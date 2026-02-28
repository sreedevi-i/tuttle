"""Defines font related constants used in app.

Sizes bumped for readability (matching VS Code / macOS standards).
"""

DEFAULT_FONT = "body"
HEADLINE_FONT = "headline"
MONOSPACE_FONT = "monospace"

APP_FONTS = {
    DEFAULT_FONT: "/fonts/SF-Pro-Display-Regular.otf",
    HEADLINE_FONT: "/fonts/SF-Pro-Display-Regular.otf",
    # MONOSPACE_FONT: "/fonts/SFMono-Regular.otf",  # add when available
}


# ── Font sizes ───────────────────────────────────────────────
HEADLING_1_SIZE = 24  # page titles
HEADLINE_2_SIZE = 20  # section titles
HEADLINE_3_SIZE = 17  # sub-section titles
HEADLINE_4_SIZE = 15  # card titles, toolbar headings
BODY_1_SIZE = 13  # primary body text
BODY_2_SIZE = 12  # secondary body text
SUBTITLE_1_SIZE = 14  # emphasized labels
SUBTITLE_2_SIZE = 13  # secondary labels
BUTTON_SIZE = 13  # button text
OVERLINE_SIZE = 11  # overline / section headers
CAPTION_SIZE = 11  # captions, helper text

# ── Font weights ─────────────────────────────────────────────
from flet import FontWeight

BOLD_FONT = FontWeight.W_500
BOLDER_FONT = FontWeight.BOLD
