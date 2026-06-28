"""Tax reserve calculations for freelancers.

Computes how much of the freelancer's revenue must be set aside for
VAT payments and estimated income tax, yielding the actual spendable income.
"""

import calendar
import datetime
import logging
from decimal import Decimal
from typing import List, NamedTuple, Optional

from .model import Invoice, RecurringExpense
from .tax import get_tax_system
from .time import Cycle

logger = logging.getLogger(__name__)


class VATReserve(NamedTuple):
    """VAT collected that must be remitted to the tax authority."""

    vat_collected: Decimal  # total VAT on invoices in the period
    invoice_count: int  # number of invoices considered
    period_start: datetime.date
    period_end: datetime.date


class IncomeTaxReserve(NamedTuple):
    """Estimated income tax reserve for the current year."""

    estimated_annual_tax: Decimal  # full-year income tax estimate
    solidarity_surcharge: Decimal  # full-year soli estimate
    total_annual_reserve: Decimal  # tax + soli
    ytd_reserve: Decimal  # prorated to current date
    effective_rate: Decimal  # total_annual_reserve / annualized_income


class SpendableIncome(NamedTuple):
    """What the freelancer can actually spend."""

    gross_revenue_ytd: Decimal  # total invoiced amount (incl. VAT)
    business_expenses: Decimal  # recurring expenses prorated to period
    net_revenue_ytd: Decimal  # gross minus VAT
    taxable_profit: Decimal  # net_revenue - business_expenses
    vat_reserve: Decimal  # VAT to set aside
    income_tax_reserve: Decimal  # estimated income tax + soli (prorated)
    spendable: Decimal  # taxable_profit - income_tax_reserve


def _invoice_currency(inv: Invoice) -> Optional[str]:
    """Return the ISO 4217 currency code for an invoice, or None."""
    if inv.contract and inv.contract.currency:
        return inv.contract.currency
    return None


def compute_vat_reserves(
    invoices: List[Invoice],
    period_start: datetime.date,
    period_end: datetime.date,
    currency: Optional[str] = None,
) -> VATReserve:
    """Sum VAT collected on non-cancelled invoices in the given period.

    If *currency* is given, only invoices denominated in that currency are
    included; others are silently skipped (a debug log is emitted).
    """
    vat_total = Decimal(0)
    count = 0
    skipped = 0
    for inv in invoices:
        if inv.cancelled:
            continue
        if period_start <= inv.date <= period_end:
            if currency and _invoice_currency(inv) not in (currency, None):
                skipped += 1
                continue
            vat_total += inv.VAT_total
            count += 1
    if skipped:
        logger.debug(
            "compute_vat_reserves: skipped %d invoice(s) with currency != %s",
            skipped,
            currency,
        )
    return VATReserve(
        vat_collected=vat_total,
        invoice_count=count,
        period_start=period_start,
        period_end=period_end,
    )


def compute_income_tax_reserve(
    net_revenue_ytd: Decimal,
    country: str,
    deductions: Decimal = Decimal(0),
    year: Optional[int] = None,
) -> IncomeTaxReserve:
    """Estimate income tax reserve based on year-to-date net revenue.

    For the current year: annualizes YTD net revenue, computes the tax on
    that projected annual income, then prorates back to the current date.

    For a past year (*year* given and < current year): treats *net_revenue_ytd*
    as the full-year amount -- no annualization or proration.
    """
    today = datetime.date.today()
    _zero = IncomeTaxReserve(
        estimated_annual_tax=Decimal(0),
        solidarity_surcharge=Decimal(0),
        total_annual_reserve=Decimal(0),
        ytd_reserve=Decimal(0),
        effective_rate=Decimal(0),
    )

    ref_date = datetime.date(year, 7, 1) if year is not None else today
    is_past_year = year is not None and year < today.year

    try:
        tax_system = get_tax_system(country, date=ref_date)
    except NotImplementedError:
        return _zero

    if is_past_year:
        annualized_income = net_revenue_ytd - deductions
    else:
        year_start = today.replace(month=1, day=1)
        days_elapsed = max((today - year_start).days, 1)
        days_in_year = 365
        annualized_income = (net_revenue_ytd - deductions) * days_in_year / days_elapsed

    if annualized_income <= 0:
        return _zero

    annual_tax = tax_system.income_tax(annualized_income)
    annual_soli = tax_system.solidarity_surcharge(annual_tax)
    total_annual = annual_tax + annual_soli

    if is_past_year:
        ytd_reserve = total_annual.quantize(Decimal("0.01"))
    else:
        year_start = today.replace(month=1, day=1)
        days_elapsed = max((today - year_start).days, 1)
        days_in_year = 365
        ytd_reserve = (total_annual * days_elapsed / days_in_year).quantize(
            Decimal("0.01")
        )

    effective_rate = (
        (total_annual / annualized_income) if annualized_income > 0 else Decimal(0)
    )

    return IncomeTaxReserve(
        estimated_annual_tax=annual_tax,
        solidarity_surcharge=annual_soli,
        total_annual_reserve=total_annual,
        ytd_reserve=ytd_reserve,
        effective_rate=effective_rate.quantize(Decimal("0.0001")),
    )


def compute_spendable_income(
    invoices: List[Invoice],
    country: str,
    expenses: Optional[List[RecurringExpense]] = None,
    deductions: Decimal = Decimal(0),
    currency: Optional[str] = None,
    year: Optional[int] = None,
) -> SpendableIncome:
    """Compute spendable income: what's left after VAT, expenses, and income tax.

    This answers the freelancer's core question: "How much of this money is mine?"

    Business *expenses* (health insurance, operating costs, etc.) are deducted
    from net revenue before estimating income tax, yielding the correct taxable
    profit.  The waterfall is:

        Gross Revenue
        − VAT
        − Business Expenses
        = Taxable Profit
        − Est. Income Tax
        = Safe to Spend

    If *year* is given (and is a past year), the full calendar year is used
    without annualization. Otherwise the current YTD is used.

    If *currency* is given (the tax system's native currency), only invoices
    denominated in that currency are counted.  If not given, the currency is
    resolved automatically from the tax system for *country*.
    """
    today = datetime.date.today()
    is_past_year = year is not None and year < today.year

    if year is not None and is_past_year:
        year_start = datetime.date(year, 1, 1)
        year_end = datetime.date(year, 12, 31)
    else:
        year_start = today.replace(month=1, day=1)
        year_end = today

    ref_date = datetime.date(year, 7, 1) if year is not None else today

    if currency is None:
        try:
            tax_system = get_tax_system(country, date=ref_date)
            currency = tax_system.currency
        except NotImplementedError:
            pass

    gross_ytd = Decimal(0)
    vat_ytd = Decimal(0)
    skipped = 0

    for inv in invoices:
        if inv.cancelled:
            continue
        if year_start <= inv.date <= year_end:
            if currency and _invoice_currency(inv) not in (currency, None):
                skipped += 1
                continue
            gross_ytd += inv.total
            vat_ytd += inv.VAT_total

    if skipped:
        logger.debug(
            "compute_spendable_income: skipped %d invoice(s) with currency != %s",
            skipped,
            currency,
        )

    net_ytd = gross_ytd - vat_ytd

    # Compute YTD business expenses from recurring expense list
    if expenses:
        monthly_exp = _monthly_expenses_total(expenses)
        if is_past_year:
            biz_expenses_ytd = (monthly_exp * 12).quantize(Decimal("0.01"))
        else:
            months_elapsed = max(
                (today.year - year_start.year) * 12
                + today.month
                - year_start.month
                + 1,
                1,
            )
            biz_expenses_ytd = (monthly_exp * months_elapsed).quantize(
                Decimal("0.01")
            )
    else:
        biz_expenses_ytd = Decimal(0)

    taxable_profit = net_ytd - biz_expenses_ytd

    tax_reserve = compute_income_tax_reserve(
        taxable_profit, country, deductions, year=year
    )

    spendable = taxable_profit - tax_reserve.ytd_reserve

    return SpendableIncome(
        gross_revenue_ytd=gross_ytd,
        business_expenses=biz_expenses_ytd,
        net_revenue_ytd=net_ytd,
        taxable_profit=taxable_profit,
        vat_reserve=vat_ytd,
        income_tax_reserve=tax_reserve.ytd_reserve,
        spendable=spendable,
    )


def _normalize_to_monthly(expense: RecurringExpense) -> Decimal:
    """Convert a recurring expense amount to its monthly equivalent."""
    period_to_months = {
        Cycle.monthly: Decimal(1),
        Cycle.quarterly: Decimal(3),
        Cycle.yearly: Decimal(12),
        Cycle.weekly: Decimal("0.25"),  # ~4.33 weeks/month → approx
        Cycle.daily: Decimal("30"),
        Cycle.hourly: Decimal("160"),  # rough ~160 work-hours/month
    }
    divisor = period_to_months.get(expense.period, Decimal(1))
    return (expense.amount / divisor).quantize(Decimal("0.01"))


def _monthly_expenses_total(expenses: List[RecurringExpense]) -> Decimal:
    """Sum all recurring expenses, normalized to a monthly amount."""
    return sum((_normalize_to_monthly(e) for e in expenses), Decimal(0))


class EffectiveSalary(NamedTuple):
    """The freelancer's safe-to-spend monthly salary, expressed as a range.

    conservative_monthly — floor: based only on revenue already received (paid invoices)
    optimistic_monthly   — ceiling: includes outstanding (unpaid, non-cancelled) invoices
    monthly_expenses     — normalized total of recurring operating expenses
    income_tax_reserve_monthly — prorated income-tax reserve per month
    vat_reserve_monthly        — prorated VAT reserve per month
    currency             — ISO 4217 currency code
    """

    conservative_monthly: Decimal
    optimistic_monthly: Decimal
    monthly_expenses: Decimal
    income_tax_reserve_monthly: Decimal
    vat_reserve_monthly: Decimal
    currency: str


def compute_effective_salary(
    invoices: List[Invoice],
    expenses: List[RecurringExpense],
    country: str,
    currency: Optional[str] = None,
) -> EffectiveSalary:
    """Compute the freelancer's effective monthly salary range.

    The *conservative* figure uses only paid invoices (certain, received revenue).
    The *optimistic* figure adds outstanding (sent but unpaid) invoices.
    Both are reduced by the prorated VAT reserve, income-tax reserve, and the
    total monthly recurring expenses.
    """
    today = datetime.date.today()
    year_start = today.replace(month=1, day=1)

    if currency is None:
        try:
            tax_system = get_tax_system(country, date=today)
            currency = tax_system.currency
        except NotImplementedError:
            currency = "EUR"

    months_elapsed = max(
        (today.year - year_start.year) * 12 + today.month - year_start.month + 1, 1
    )

    gross_paid = Decimal(0)
    vat_paid = Decimal(0)
    gross_outstanding = Decimal(0)
    vat_outstanding = Decimal(0)

    for inv in invoices:
        if inv.cancelled:
            continue
        if inv.date < year_start:
            continue
        if currency and _invoice_currency(inv) not in (currency, None):
            continue
        if inv.paid:
            gross_paid += inv.total
            vat_paid += inv.VAT_total
        else:
            gross_outstanding += inv.total
            vat_outstanding += inv.VAT_total

    net_paid = gross_paid - vat_paid
    net_all = net_paid + (gross_outstanding - vat_outstanding)

    # Income-tax reserve based on each revenue scenario
    tax_conservative = compute_income_tax_reserve(net_paid, country)
    tax_optimistic = compute_income_tax_reserve(net_all, country)

    monthly_vat_conservative = (vat_paid / months_elapsed).quantize(Decimal("0.01"))
    monthly_vat_optimistic = ((vat_paid + vat_outstanding) / months_elapsed).quantize(
        Decimal("0.01")
    )

    monthly_tax_conservative = (tax_conservative.ytd_reserve / months_elapsed).quantize(
        Decimal("0.01")
    )
    monthly_tax_optimistic = (tax_optimistic.ytd_reserve / months_elapsed).quantize(
        Decimal("0.01")
    )

    monthly_exp = _monthly_expenses_total(expenses)

    conservative = (
        net_paid / months_elapsed - monthly_tax_conservative - monthly_exp
    ).quantize(Decimal("0.01"))

    optimistic = (
        net_all / months_elapsed - monthly_tax_optimistic - monthly_exp
    ).quantize(Decimal("0.01"))

    # Use the average monthly figures for display breakdown
    avg_monthly_vat = (
        (monthly_vat_conservative + monthly_vat_optimistic) / 2
    ).quantize(Decimal("0.01"))
    avg_monthly_tax = (
        (monthly_tax_conservative + monthly_tax_optimistic) / 2
    ).quantize(Decimal("0.01"))

    return EffectiveSalary(
        conservative_monthly=conservative,
        optimistic_monthly=optimistic,
        monthly_expenses=monthly_exp,
        income_tax_reserve_monthly=avg_monthly_tax,
        vat_reserve_monthly=avg_monthly_vat,
        currency=currency,
    )


def monthly_vat_breakdown(
    invoices: List[Invoice],
    year: Optional[int] = None,
    currency: Optional[str] = None,
) -> list:
    """VAT breakdown by month for the given year.

    Returns list of dicts: month, vat_collected, invoice_count, period_start, period_end.
    """
    if year is None:
        year = datetime.date.today().year

    month_names = [calendar.month_abbr[m] for m in range(1, 13)]
    months = []
    for m in range(1, 13):
        period_start = datetime.date(year, m, 1)
        if m == 12:
            period_end = datetime.date(year, 12, 31)
        else:
            period_end = datetime.date(year, m + 1, 1) - datetime.timedelta(days=1)

        reserve = compute_vat_reserves(
            invoices, period_start, period_end, currency=currency
        )
        months.append(
            {
                "month": month_names[m - 1],
                "vat_collected": reserve.vat_collected,
                "invoice_count": reserve.invoice_count,
                "period_start": period_start,
                "period_end": period_end,
            }
        )
    return months
