"""Effective Salary view — monthly salary planning for freelancers.

Sections:
1. Salary Dial: large central amount + slider to dial in the target (conservative → optimistic)
2. Monthly Breakdown: waterfall showing where revenue goes each month
"""

from decimal import Decimal, InvalidOperation

from flet import (
    BorderRadius,
    Column,
    Container,
    CrossAxisAlignment,
    Icon,
    Icons,
    MainAxisAlignment,
    Padding,
    Row,
    ScrollMode,
    Slider,
    Text,
    TextAlign,
)

from ..core.abstractions import TView, TViewParams
from ..core import views
from ..core.utils import fmt_currency
from ..res import colors, dimens, fonts, res_utils
from .intent import SalaryIntent


# ── Helpers ────────────────────────────────────────────────────


def _section_header(title: str, icon=None) -> Container:
    ctrl = []
    if icon:
        ctrl.append(Icon(icon, size=dimens.MD_ICON_SIZE, color=colors.text_secondary))
    ctrl.append(
        Text(
            title,
            size=fonts.HEADLINE_4_SIZE,
            color=colors.text_primary,
            weight=fonts.BOLD_FONT,
        )
    )
    return Container(
        padding=Padding.only(top=dimens.SPACE_LG, bottom=dimens.SPACE_SM),
        content=Row(spacing=dimens.SPACE_XS, controls=ctrl),
    )


def _zone_color(target: Decimal, conservative: Decimal, optimistic: Decimal) -> str:
    """Return a semantic color based on where target falls in the range."""
    if target <= 0:
        return colors.text_muted
    if target <= conservative:
        return colors.success
    if target <= optimistic:
        return colors.warning
    return colors.danger


def _zone_label(target: Decimal, conservative: Decimal, optimistic: Decimal) -> str:
    if target <= 0:
        return ""
    if target <= conservative:
        return "Safe zone — this amount is covered by paid invoices."
    if target <= optimistic:
        return "Optimistic zone — make sure outstanding invoices get paid."
    return "Above the optimistic estimate — consider reducing the target."


# ── Main Salary View ───────────────────────────────────────────


class SalaryView(TView, Column):
    """Effective Salary planning view."""

    def __init__(self, params: TViewParams):
        TView.__init__(self, params)
        Column.__init__(self)
        self.intent = SalaryIntent()
        self.scroll = ScrollMode.AUTO
        self.spacing = 0
        self.expand = True

        self._conservative = Decimal(0)
        self._optimistic = Decimal(0)
        self._target = Decimal(0)
        self._currency = "EUR"

    def build(self):
        self._dial_section = Column(spacing=0)
        self._breakdown_section = Column(spacing=0)

        # Central "big number" display
        self._amount_text = Text(
            "—",
            size=fonts.HEADLINE_0_SIZE,
            color=colors.text_primary,
            weight=fonts.BOLD_FONT,
            text_align=TextAlign.CENTER,
        )
        self._per_month_text = Text(
            "per month",
            size=fonts.BODY_2_SIZE,
            color=colors.text_muted,
            text_align=TextAlign.CENTER,
        )
        self._zone_text = Text(
            "",
            size=fonts.CAPTION_SIZE,
            color=colors.text_muted,
            text_align=TextAlign.CENTER,
        )

        # Slider — range will be set when data loads
        self._slider = Slider(
            min=0,
            max=1,
            value=0,
            active_color=colors.accent,
            inactive_color=colors.border,
            on_change=self._on_slider_change,
        )

        # Conservative / Optimistic endpoint labels
        self._con_label = Text(
            "—",
            size=fonts.CAPTION_SIZE,
            color=colors.text_muted,
            text_align=TextAlign.LEFT,
        )
        self._opt_label = Text(
            "—",
            size=fonts.CAPTION_SIZE,
            color=colors.text_muted,
            text_align=TextAlign.RIGHT,
        )

        self.controls = [
            Container(
                padding=Padding.all(dimens.SPACE_MD),
                content=Column(
                    spacing=dimens.SPACE_XS,
                    controls=[
                        views.THeading("Effective Salary", size=fonts.HEADLINE_2_SIZE),
                        Text(
                            "How much can you safely pay yourself each month?",
                            size=fonts.BODY_1_SIZE,
                            color=colors.text_muted,
                        ),
                        views.Spacer(sm_space=True),
                        self._dial_section,
                        self._breakdown_section,
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

    def _load_data(self):
        # _load_dial must run first — it populates self._salary used by _load_breakdown
        self._load_dial()
        if hasattr(self, "_salary"):
            self._load_breakdown()
        self.update_self()

    # ── Section 1: Salary Dial ────────────────────────────────

    def _load_dial(self):
        self._dial_section.controls.clear()

        result = self.intent.get_effective_salary()
        if not result.was_intent_successful or not result.data:
            self._dial_section.controls = [
                _section_header("Monthly Salary", Icons.SAVINGS),
                Container(
                    bgcolor=colors.bg_surface,
                    border_radius=dimens.RADIUS_LG,
                    padding=Padding.all(dimens.SPACE_STD),
                    content=Text(
                        "No invoice data yet. Start by adding contracts and tracking time.",
                        size=fonts.BODY_1_SIZE,
                        color=colors.text_muted,
                    ),
                ),
            ]
            return

        salary = result.data["salary"]
        currency = result.data.get("currency", "EUR")
        self._currency = currency
        self._conservative = salary.conservative_monthly
        self._optimistic = salary.optimistic_monthly

        # Determine safe slider bounds: use conservative as default target
        con = float(self._conservative)
        opt = float(self._optimistic)
        slider_min = min(con, 0)
        slider_max = max(
            opt * 1.1, 1
        )  # a bit above optimistic so user can see red zone

        if self._target == 0:
            self._target = self._conservative

        # Initialize slider & labels
        self._slider.min = slider_min
        self._slider.max = slider_max
        self._slider.value = float(self._target)
        self._slider.divisions = max(int((slider_max - slider_min) / 50), 20)

        self._salary = salary  # expose to _load_breakdown

        self._con_label.value = fmt_currency(self._conservative, currency)
        self._opt_label.value = fmt_currency(self._optimistic, currency)

        # ── Zone bar proportions ──────────────────────────────
        # Three segments: green (0→conservative), amber (conservative→optimistic),
        # red (optimistic→max).  Use integer expand ratios (×100).
        slider_range = slider_max - slider_min
        con_expand = max(int(((con - slider_min) / slider_range) * 100), 1)
        amb_expand = max(int(((opt - con) / slider_range) * 100), 1)
        red_expand = max(100 - con_expand - amb_expand, 1)

        zone_bar = Container(
            # Match the slider container's horizontal padding so the bar
            # roughly aligns with the slider track.
            padding=Padding.symmetric(horizontal=dimens.SPACE_SM),
            content=Row(
                spacing=0,
                controls=[
                    Container(
                        expand=con_expand,
                        height=5,
                        bgcolor=colors.success,
                        border_radius=BorderRadius.only(
                            top_left=dimens.RADIUS_PILL,
                            bottom_left=dimens.RADIUS_PILL,
                        ),
                    ),
                    Container(
                        expand=amb_expand,
                        height=5,
                        bgcolor=colors.warning,
                    ),
                    Container(
                        expand=red_expand,
                        height=5,
                        bgcolor=colors.danger,
                        border_radius=BorderRadius.only(
                            top_right=dimens.RADIUS_PILL,
                            bottom_right=dimens.RADIUS_PILL,
                        ),
                    ),
                ],
            ),
        )

        self._refresh_dial_display()

        self._dial_section.controls = [
            _section_header("Monthly Salary", Icons.SAVINGS),
            Container(
                bgcolor=colors.bg_surface,
                border_radius=dimens.RADIUS_LG,
                padding=Padding.symmetric(
                    horizontal=dimens.SPACE_STD, vertical=dimens.SPACE_LG
                ),
                content=Column(
                    horizontal_alignment=CrossAxisAlignment.CENTER,
                    spacing=dimens.SPACE_SM,
                    controls=[
                        # Central big number
                        Container(
                            padding=Padding.symmetric(vertical=dimens.SPACE_SM),
                            content=Column(
                                horizontal_alignment=CrossAxisAlignment.CENTER,
                                spacing=dimens.SPACE_XXS,
                                controls=[
                                    self._amount_text,
                                    self._per_month_text,
                                ],
                            ),
                        ),
                        # Slider
                        Container(
                            padding=Padding.symmetric(horizontal=dimens.SPACE_SM),
                            content=self._slider,
                        ),
                        # Zone colour bar — sits right below the slider track
                        zone_bar,
                        # Conservative / Optimistic range labels
                        Row(
                            alignment=MainAxisAlignment.SPACE_BETWEEN,
                            controls=[
                                Column(
                                    spacing=2,
                                    controls=[
                                        self._con_label,
                                        Text(
                                            "conservative",
                                            size=fonts.CAPTION_SIZE,
                                            color=colors.text_muted,
                                        ),
                                    ],
                                ),
                                Column(
                                    spacing=2,
                                    horizontal_alignment=CrossAxisAlignment.END,
                                    controls=[
                                        self._opt_label,
                                        Text(
                                            "optimistic",
                                            size=fonts.CAPTION_SIZE,
                                            color=colors.text_muted,
                                        ),
                                    ],
                                ),
                            ],
                        ),
                        # Zone feedback line
                        self._zone_text,
                    ],
                ),
            ),
        ]

    def _refresh_dial_display(self):
        """Update the big number, zone feedback, and slider thumb colour."""
        color = _zone_color(self._target, self._conservative, self._optimistic)
        self._amount_text.value = fmt_currency(self._target, self._currency)
        self._amount_text.color = color
        self._zone_text.value = _zone_label(
            self._target, self._conservative, self._optimistic
        )
        self._zone_text.color = color
        # Keep the slider's active track colour in sync with the current zone
        self._slider.active_color = color
        self._slider.thumb_color = color

    def _on_slider_change(self, e):
        try:
            self._target = Decimal(str(round(float(e.control.value), 2)))
        except (InvalidOperation, ValueError):
            return
        self._refresh_dial_display()
        self.update_self()

    # ── Section 2: Monthly Breakdown Waterfall ─────────────────

    def _load_breakdown(self):
        self._breakdown_section.controls.clear()
        salary = self._salary
        currency = self._currency

        gross_monthly = (
            salary.optimistic_monthly
            + salary.income_tax_reserve_monthly
            + salary.vat_reserve_monthly
            + salary.monthly_expenses
        )
        if gross_monthly <= 0:
            return

        items = [
            ("Gross Revenue / month", gross_monthly, colors.accent, False),
            ("VAT (to remit)", salary.vat_reserve_monthly, colors.warning, False),
            (
                "Est. Income Tax + Soli",
                salary.income_tax_reserve_monthly,
                colors.warning,
                False,
            ),
            (
                "= Available Salary",
                salary.optimistic_monthly,
                colors.success if salary.optimistic_monthly >= 0 else colors.danger,
                True,
            ),
        ]

        waterfall_controls = []
        for label, amount, bar_color, is_total in items:
            sign = "" if amount >= 0 or is_total else "−"
            display = abs(amount)
            ratio = float(abs(amount) / gross_monthly) if gross_monthly > 0 else 0
            bar_pct = max(ratio, 0.02)

            waterfall_controls.append(
                Container(
                    padding=Padding.symmetric(vertical=dimens.SPACE_XS),
                    content=Column(
                        spacing=2,
                        controls=[
                            Row(
                                alignment=MainAxisAlignment.SPACE_BETWEEN,
                                controls=[
                                    Text(
                                        label,
                                        size=fonts.BODY_1_SIZE,
                                        color=colors.text_primary,
                                        weight=fonts.BOLD_FONT if is_total else None,
                                    ),
                                    Text(
                                        f"{sign}{fmt_currency(display, currency)}",
                                        size=fonts.BODY_1_SIZE,
                                        color=bar_color,
                                        weight=fonts.BOLD_FONT if is_total else None,
                                    ),
                                ],
                            ),
                            Container(
                                height=6 if not is_total else 8,
                                bgcolor=colors.border,
                                border_radius=dimens.RADIUS_SM,
                                content=Row(
                                    spacing=0,
                                    controls=[
                                        Container(
                                            expand=max(int(bar_pct * 100), 1),
                                            height=6 if not is_total else 8,
                                            bgcolor=bar_color,
                                            border_radius=dimens.RADIUS_SM,
                                        ),
                                        Container(
                                            expand=max(int((1 - bar_pct) * 100), 0)
                                        ),
                                    ],
                                ),
                            ),
                        ],
                    ),
                )
            )

        self._breakdown_section.controls = [
            _section_header("Monthly Breakdown", Icons.WATERFALL_CHART),
            Container(
                bgcolor=colors.bg_surface,
                border_radius=dimens.RADIUS_LG,
                padding=Padding.all(dimens.SPACE_STD),
                content=Column(spacing=0, controls=waterfall_controls),
            ),
        ]
