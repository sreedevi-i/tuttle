"""Timeline view — chronological feed of freelance business events.

Renders a vertical timeline with a continuous spine, month groupings,
a "today" marker, colour-coded category dots, and filter chips.
"""

import datetime
import threading
from itertools import groupby
from typing import List, Optional

from flet import (
    Alignment,
    Border,
    BorderRadius,
    BorderSide,
    Column,
    Container,
    CrossAxisAlignment,
    Icon,
    Icons,
    MainAxisAlignment,
    Padding,
    ProgressRing,
    Row,
    ScrollMode,
    Text,
    TextStyle,
)

from ..core.abstractions import TView, TViewParams
from ..core import views
from ..res import colors, dimens, fonts, res_utils

from .intent import (
    CATEGORY_COLORS,
    CATEGORY_CONTRACT,
    CATEGORY_GOAL,
    CATEGORY_INVOICE,
    CATEGORY_PROJECT,
    TimelineEvent,
    TimelineIntent,
)


# ── Constants ─────────────────────────────────────────────────

_SPINE_WIDTH = 2
_DOT_SIZE = 12
_DOT_OUTER_SIZE = 20
_SPINE_COL_WIDTH = 40

_CATEGORY_LABELS = {
    None: "All",
    CATEGORY_INVOICE: "Invoices",
    CATEGORY_CONTRACT: "Contracts",
    CATEGORY_PROJECT: "Projects",
    CATEGORY_GOAL: "Goals",
}


# ── Spine helpers ─────────────────────────────────────────────
# Each timeline row carries a left-hand spine column built from
# explicit-height pieces so the vertical line is unbroken.


def _make_dot(color: str) -> Container:
    return Container(
        width=_DOT_OUTER_SIZE,
        height=_DOT_OUTER_SIZE,
        border_radius=dimens.RADIUS_PILL,
        bgcolor=f"#1A{color.lstrip('#')}",
        alignment=Alignment.CENTER,
        content=Container(
            width=_DOT_SIZE,
            height=_DOT_SIZE,
            border_radius=dimens.RADIUS_PILL,
            bgcolor=color,
        ),
    )


def _line(height: int, visible: bool = True) -> Container:
    return Container(
        width=_SPINE_WIDTH,
        height=height,
        bgcolor=colors.border if visible else "transparent",
    )


def _spine_plain(height: int, show_line: bool = True) -> Container:
    """Spine segment with just a line (no dot). Used for month headers."""
    return Container(
        width=_SPINE_COL_WIDTH,
        height=height,
        alignment=Alignment.CENTER,
        content=_line(height, visible=show_line),
    )


def _spine_with_dot(
    dot_color: str,
    total_height: int,
    is_last: bool = False,
) -> Container:
    """Spine segment with a coloured dot centred on the line."""
    line_h = (total_height - _DOT_OUTER_SIZE) // 2
    top_h = max(line_h, 0)
    bot_h = max(total_height - _DOT_OUTER_SIZE - top_h, 0)

    return Container(
        width=_SPINE_COL_WIDTH,
        height=total_height,
        content=Column(
            horizontal_alignment=CrossAxisAlignment.CENTER,
            spacing=0,
            controls=[
                _line(top_h),
                _make_dot(dot_color),
                _line(bot_h, visible=not is_last),
            ],
        ),
    )


# ── Filter chip ───────────────────────────────────────────────


class _FilterChip(Container):
    """Toggle chip for a timeline category."""

    def __init__(
        self,
        label: str,
        color: str,
        is_active: bool,
        on_click,
    ):
        bg = color if is_active else "transparent"
        text_color = colors.text_inverse if is_active else color

        super().__init__(
            bgcolor=bg,
            border=Border.all(1, color),
            border_radius=dimens.RADIUS_PILL,
            padding=Padding.symmetric(
                horizontal=dimens.SPACE_SM,
                vertical=dimens.SPACE_XXS,
            ),
            on_click=on_click,
            content=Text(
                label,
                size=fonts.CAPTION_SIZE,
                color=text_color,
                weight=fonts.BOLD_FONT,
            ),
        )


# ── Today marker ──────────────────────────────────────────────

_TODAY_HEIGHT = 36


def _today_marker(is_last: bool = False) -> Container:
    """A horizontal accent line labelled 'Today', with spine."""
    return Row(
        spacing=dimens.SPACE_XS,
        vertical_alignment=CrossAxisAlignment.CENTER,
        controls=[
            _spine_with_dot(colors.danger, _TODAY_HEIGHT, is_last=is_last),
            Container(
                bgcolor=colors.danger,
                border_radius=dimens.RADIUS_PILL,
                padding=Padding.symmetric(
                    horizontal=dimens.SPACE_SM,
                    vertical=2,
                ),
                content=Text(
                    "Today",
                    size=fonts.CAPTION_SIZE,
                    color=colors.text_inverse,
                    weight=fonts.BOLD_FONT,
                ),
            ),
            Container(
                expand=True,
                height=2,
                bgcolor=colors.danger,
                border_radius=dimens.RADIUS_PILL,
            ),
        ],
    )


# ── Month header ──────────────────────────────────────────────

_MONTH_HEIGHT = 40


def _month_header(label: str) -> Row:
    """Month group label with the spine running through it."""
    return Row(
        spacing=dimens.SPACE_XS,
        vertical_alignment=CrossAxisAlignment.CENTER,
        controls=[
            _spine_plain(_MONTH_HEIGHT),
            Text(
                label,
                size=fonts.HEADLINE_4_SIZE,
                color=colors.text_muted,
                weight=fonts.BOLD_FONT,
                style=TextStyle(letter_spacing=0.6),
            ),
        ],
    )


# ── Event card ────────────────────────────────────────────────

_EVENT_CARD_SPINE_HEIGHT = 80


class _TimelineEventCard(Container):
    """A single event rendered along the continuous timeline spine."""

    def __init__(self, event: TimelineEvent, is_last: bool = False):
        dot_color = event.color
        opacity = 0.55 if event.is_future else 1.0

        date_str = event.date.strftime("%b %d, %Y")
        card = Container(
            expand=True,
            bgcolor=colors.bg_surface,
            border=Border.all(dimens.CARD_BORDER_WIDTH, colors.border),
            border_radius=dimens.RADIUS_LG,
            padding=Padding.all(dimens.SPACE_SM),
            opacity=opacity,
            content=Column(
                spacing=dimens.SPACE_XXS,
                controls=[
                    Row(
                        alignment=MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=CrossAxisAlignment.START,
                        controls=[
                            Row(
                                spacing=dimens.SPACE_XS,
                                controls=[
                                    Icon(
                                        event.icon,
                                        size=dimens.MD_ICON_SIZE,
                                        color=event.color,
                                    ),
                                    Text(
                                        event.title,
                                        size=fonts.BODY_1_SIZE,
                                        color=colors.text_primary,
                                        weight=fonts.BOLD_FONT,
                                        expand=True,
                                    ),
                                ],
                                expand=True,
                            ),
                            Text(
                                date_str,
                                size=fonts.CAPTION_SIZE,
                                color=colors.text_muted,
                            ),
                        ],
                    ),
                    *(
                        [
                            Text(
                                event.description,
                                size=fonts.BODY_2_SIZE,
                                color=colors.text_secondary,
                            )
                        ]
                        if event.description
                        else []
                    ),
                    Container(
                        bgcolor=f"#1A{event.color.lstrip('#')}",
                        border_radius=dimens.RADIUS_PILL,
                        padding=Padding.symmetric(
                            horizontal=dimens.SPACE_XS,
                            vertical=2,
                        ),
                        content=Text(
                            _CATEGORY_LABELS.get(event.category, event.category),
                            size=10,
                            color=event.color,
                            weight=fonts.BOLD_FONT,
                        ),
                    ),
                ],
            ),
        )

        super().__init__(
            padding=Padding.only(right=dimens.SPACE_SM),
            content=Row(
                spacing=dimens.SPACE_XS,
                vertical_alignment=CrossAxisAlignment.CENTER,
                controls=[
                    _spine_with_dot(
                        dot_color,
                        _EVENT_CARD_SPINE_HEIGHT,
                        is_last=is_last,
                    ),
                    card,
                ],
            ),
        )


# ── Empty state ───────────────────────────────────────────────


def _empty_state() -> Container:
    return Container(
        padding=Padding.all(dimens.SPACE_XL),
        content=Column(
            horizontal_alignment=CrossAxisAlignment.CENTER,
            spacing=dimens.SPACE_SM,
            controls=[
                Icon(
                    Icons.TIMELINE_OUTLINED,
                    size=48,
                    color=colors.text_muted,
                ),
                Text(
                    "No events yet",
                    size=fonts.BODY_1_SIZE,
                    color=colors.text_muted,
                ),
                Text(
                    "Create invoices, contracts, or projects to see them here.",
                    size=fonts.BODY_2_SIZE,
                    color=colors.text_muted,
                    text_align="center",
                ),
            ],
        ),
    )


# ── Main view ─────────────────────────────────────────────────


class TimelineView(TView, Column):
    """Freelance business timeline — the chronological event feed."""

    def __init__(self, params: TViewParams):
        TView.__init__(self, params)
        Column.__init__(self)
        self.intent = TimelineIntent()
        self.scroll = ScrollMode.AUTO
        self.spacing = 0
        self.expand = True

        self._active_filter: Optional[str] = None
        self._search_query: str = ""
        self._all_events: List[TimelineEvent] = []

        self._filter_row = Row(
            spacing=dimens.SPACE_XS,
            vertical_alignment=CrossAxisAlignment.CENTER,
        )
        self._timeline_body = Column(spacing=0)
        self._spinner = ProgressRing(
            width=32, height=32, stroke_width=3, color=colors.accent
        )
        self._content = Column(
            spacing=dimens.SPACE_XS,
            visible=False,
            controls=[
                self._filter_row,
                self._timeline_body,
            ],
        )

    def build(self):
        self.controls = [
            Container(
                padding=Padding.all(dimens.SPACE_STD),
                content=Column(
                    spacing=dimens.SPACE_XS,
                    controls=[
                        views.THeading("Timeline", size=fonts.HEADLINE_2_SIZE),
                        Row(
                            alignment=MainAxisAlignment.CENTER,
                            controls=[self._spinner],
                        ),
                        self._content,
                    ],
                ),
            )
        ]

    def did_mount(self):
        self.mounted = True
        self._load_data()

    def on_resume_after_back_pressed(self):
        self._load_data()

    def parent_intent_listener(self, intent: str, data=None):
        if intent == res_utils.RELOAD_INTENT:
            self._load_data()

    def on_search_changed(self, query: str):
        self._search_query = query.strip().lower()
        self._rebuild_timeline()
        self.update_self()

    # ── Data loading ──────────────────────────────────────────

    def _load_data(self):
        self._spinner.visible = True
        self._content.visible = False
        self.update_self()
        threading.Thread(target=self._load_data_sync, daemon=True).start()

    def _load_data_sync(self):
        result = self.intent.get_timeline_events()
        if result.was_intent_successful and result.data is not None:
            self._all_events = result.data
        else:
            self._all_events = []
        self._rebuild_filters()
        self._rebuild_timeline()
        self._spinner.visible = False
        self._content.visible = True
        self.update_self()

    # ── Filters ───────────────────────────────────────────────

    def _rebuild_filters(self):
        categories = [
            None,
            CATEGORY_INVOICE,
            CATEGORY_CONTRACT,
            CATEGORY_PROJECT,
            CATEGORY_GOAL,
        ]
        self._filter_row.controls = [
            _FilterChip(
                label=_CATEGORY_LABELS[cat],
                color=CATEGORY_COLORS.get(cat, colors.accent),
                is_active=(cat == self._active_filter),
                on_click=lambda e, c=cat: self._on_filter_clicked(c),
            )
            for cat in categories
        ]

    def _on_filter_clicked(self, category: Optional[str]):
        self._active_filter = category
        self._rebuild_filters()
        self._rebuild_timeline()
        self.update_self()

    # ── Timeline rendering ────────────────────────────────────

    def _rebuild_timeline(self):
        events = self._all_events

        if self._active_filter:
            events = [e for e in events if e.category == self._active_filter]

        if self._search_query:
            q = self._search_query
            events = [
                e for e in events if q in e.title.lower() or q in e.description.lower()
            ]

        self._timeline_body.controls.clear()

        if not events:
            self._timeline_body.controls.append(_empty_state())
            return

        today = datetime.date.today()
        today_inserted = False
        total_events = len(events)
        event_index = 0

        def month_key(ev: TimelineEvent) -> str:
            return ev.date.strftime("%Y-%m")

        for mk, group_iter in groupby(events, key=month_key):
            group = list(group_iter)
            year, month = int(mk[:4]), int(mk[5:])
            month_label = datetime.date(year, month, 1).strftime("%B %Y")
            self._timeline_body.controls.append(_month_header(month_label))

            for ev in group:
                event_index += 1
                is_absolute_last = event_index == total_events

                if not today_inserted and not ev.is_future and ev.date <= today:
                    self._timeline_body.controls.append(_today_marker())
                    today_inserted = True

                self._timeline_body.controls.append(
                    _TimelineEventCard(ev, is_last=is_absolute_last)
                )

        if not today_inserted:
            self._timeline_body.controls.insert(0, _today_marker())
