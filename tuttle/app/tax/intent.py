"""Business logic for the Tax view."""

import datetime
from decimal import Decimal

from ..core.abstractions import SQLModelDataSourceMixin, Intent
from ..core.intent_result import IntentResult

from ...model import Invoice, User
from ...tax import get_tax_system, supported_countries
from ...tax_reserves import (
    compute_spendable_income,
    compute_income_tax_reserve,
    monthly_vat_breakdown,
)


class TaxIntent(SQLModelDataSourceMixin, Intent):
    """Gathers tax-related data for the freelance tax planning view."""

    def __init__(self):
        SQLModelDataSourceMixin.__init__(self)

    def _get_country(self) -> str:
        """Determine the user's operating country for tax purposes."""
        try:
            users = self.query(User)
            if users and users[0].operating_country:
                return users[0].operating_country
        except Exception:
            pass
        return "Germany"

    def _get_tax_currency(self, country: str) -> str:
        """Return the ISO 4217 currency for the country's tax system."""
        try:
            return get_tax_system(country).currency
        except NotImplementedError:
            return "EUR"

    def get_spendable_income(self, year: int | None = None) -> IntentResult:
        """Compute spendable income breakdown."""
        try:
            invoices = self.query(Invoice)
            country = self._get_country()
            currency = self._get_tax_currency(country)
            spending = compute_spendable_income(
                invoices, country, currency=currency, year=year
            )
            data = {"spending": spending, "currency": currency}
            return IntentResult(was_intent_successful=True, data=data)
        except Exception as e:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Failed to compute spendable income.",
                log_message=f"TaxIntent.get_spendable_income: {e}",
                exception=e,
            )

    def get_income_tax_estimate(self, year: int | None = None) -> IntentResult:
        """Get detailed income tax estimate with bracket info."""
        try:
            today = datetime.date.today()
            is_past_year = year is not None and year < today.year

            invoices = self.query(Invoice)
            country = self._get_country()
            currency = self._get_tax_currency(country)
            spending = compute_spendable_income(
                invoices, country, currency=currency, year=year
            )
            tax_reserve = compute_income_tax_reserve(
                spending.net_revenue_ytd, country, year=year
            )

            if is_past_year:
                annualized = float(spending.net_revenue_ytd)
            else:
                days_elapsed = max((today - today.replace(month=1, day=1)).days, 1)
                annualized = float(spending.net_revenue_ytd) * 365 / days_elapsed

            ref_date = datetime.date(year, 7, 1) if year else today
            try:
                tax_system = get_tax_system(country, date=ref_date)
                bracket_data = self._compute_bracket_data(
                    tax_system, Decimal(str(annualized))
                )
                country_supported = True
            except NotImplementedError:
                bracket_data = []
                country_supported = False

            data = {
                "tax_reserve": tax_reserve,
                "annualized_income": Decimal(str(round(annualized, 2))),
                "brackets": bracket_data,
                "country": country,
                "country_supported": country_supported,
                "currency": currency,
            }
            return IntentResult(was_intent_successful=True, data=data)
        except Exception as e:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Failed to compute income tax estimate.",
                log_message=f"TaxIntent.get_income_tax_estimate: {e}",
                exception=e,
            )

    def _compute_bracket_data(self, tax_system, annualized_income: Decimal) -> list:
        """Build bracket visualization data from the tax system's zone data."""
        zones = tax_system.bracket_info
        income_f = float(annualized_income)
        allowance = tax_system.params.basic_allowance
        brackets = []
        prev_end = 0
        for zone in zones:
            up_to = zone["up_to"]
            ztype = zone.get("type")
            if ztype == "zero":
                start = 0
                end = up_to
            elif ztype in ("quadratic", "linear") and "reference_offset" in zone:
                # German-style zones with explicit reference offsets
                start = zone["reference_offset"]
                end = up_to if up_to is not None else start + 100000
            else:
                # Marginal bracket zones: display bracket range offset by allowance
                start = prev_end + allowance if not brackets else prev_end
                end = (up_to + allowance) if up_to is not None else start + 100000
            brackets.append(
                {
                    "label": zone["label"],
                    "start": start,
                    "end": end,
                    "is_current": start
                    <= income_f
                    < (end if up_to is not None else float("inf")),
                }
            )
            prev_end = end
        return brackets

    def get_available_years(self) -> IntentResult:
        """Return distinct years (descending) that have invoice data."""
        try:
            invoices = self.query(Invoice)
            years = sorted(
                {inv.date.year for inv in invoices if not inv.cancelled},
                reverse=True,
            )
            return IntentResult(was_intent_successful=True, data=years)
        except Exception as e:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Failed to get available years.",
                log_message=f"TaxIntent.get_available_years: {e}",
                exception=e,
            )

    def supported_countries(self) -> IntentResult:
        """Return list of countries with tax system support."""
        return IntentResult(was_intent_successful=True, data=supported_countries())

    def get_monthly_vat(self, year: int | None = None) -> IntentResult:
        """Get monthly VAT breakdown."""
        try:
            invoices = self.query(Invoice)
            country = self._get_country()
            currency = self._get_tax_currency(country)
            months = monthly_vat_breakdown(invoices, year=year, currency=currency)
            data = {"months": months, "currency": currency}
            return IntentResult(was_intent_successful=True, data=data)
        except Exception as e:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Failed to compute monthly VAT.",
                log_message=f"TaxIntent.get_monthly_vat: {e}",
                exception=e,
            )
