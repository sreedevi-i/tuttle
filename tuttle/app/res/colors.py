"""Design tokens — semantic colors for Tuttle's dark theme.

Inspired by macOS dark-mode conventions and VS Code's editor palette.
All entity views, components, and the app shell should reference these
tokens instead of hard-coding hex values.
"""

# ── Backgrounds ──────────────────────────────────────────────
bg = "#1E1E1E"  # main window / page background
bg_sidebar = "#252526"  # sidebar panel
bg_surface = "#2D2D2D"  # cards, panels, inputs
bg_surface_hovered = "#383838"  # hovered cards / elevated surfaces
bg_titlebar = "#1E1E1E"  # title bar (matches bg for seamless look)
bg_statusbar = "#007ACC"  # VS Code-style status bar accent
bg_toolbar = "#252526"  # action bar / toolbar
bg_input = "#3C3C3C"  # text field fill

# ── Text ─────────────────────────────────────────────────────
text_primary = "#CCCCCC"  # main text
text_secondary = "#9D9D9D"  # secondary / subtitle text
text_muted = "#6D6D6D"  # labels, section headers, placeholders
text_inverse = "#FFFFFF"  # text on accent backgrounds

# ── Accent ───────────────────────────────────────────────────
accent = "#0A84FF"  # primary accent (macOS system blue)
accent_hovered = "#409CFF"  # hovered accent
accent_muted = "#1a3a5c"  # selected-item bg tint

# ── Semantic ─────────────────────────────────────────────────
danger = "#FF453A"  # destructive actions (macOS system red)
success = "#30D158"  # success indicators (macOS system green)
warning = "#FFD60A"  # warnings (macOS system yellow)

# ── Borders & separators ─────────────────────────────────────
border = "#3C3C3C"  # card borders, dividers
border_subtle = "#2D2D2D"  # very subtle separators
separator = "#1a1a1a"  # hairline dividers

# ── Activity bar ─────────────────────────────────────────────
activity_bar_bg = "#333333"  # activity bar background
activity_bar_icon = "#858585"  # inactive icon
activity_bar_icon_active = "#FFFFFF"  # active icon
activity_bar_indicator = "#FFFFFF"  # active indicator bar

# ── Backward-compatibility aliases ───────────────────────────
# Maps old constant names to new tokens so un-migrated code still works.
PRIMARY_COLOR = accent
ERROR_COLOR = danger
DANGER_COLOR = danger
GRAY_COLOR = text_secondary
GRAY_DARK_COLOR = text_muted
BLACK_COLOR = "#1E1C28"
BLACK_COLOR_ALT = bg_surface
WHITE_COLOR = text_inverse
WHITE_COLOR_ALT = "#F6F6F6"
GRAY_LIGHT_COLOR = "#E5E4EA"
BORDER_DARK_COLOR = border
SIDEBAR_DARK_COLOR = bg_sidebar
SIDEBAR_LIGHT_COLOR = bg_sidebar  # no light mode
ACTION_BAR_DARK_COLOR = bg_toolbar
ACTION_BAR_LIGHT_COLOR = bg_toolbar  # no light mode
