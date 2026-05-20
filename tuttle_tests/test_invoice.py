"""Tests for the invoice module."""

import datetime
from decimal import Decimal

import pandas
import pytest

from tuttle import invoicing, timetracking
from tuttle.model import (
    Address,
    Client,
    Contract,
    Invoice,
    InvoiceItem,
    Project,
)
from tuttle.time import Cycle, TimeUnit
from tuttle.calendar import get_month_start_end


def test_invoice():
    the_invoice = Invoice(
        number="27B-6",
        date=datetime.date.today(),
        sent=True,
        paid=False,
        cancelled=False,
    )

    item_1 = InvoiceItem(
        invoice=the_invoice,
        start_date=datetime.date.today(),
        end_date=datetime.date.today(),
        quantity=10,
        unit="hours",
        unit_price=Decimal(50),
        description="work work",
        VAT_rate=Decimal(0.20),
    )

    item_2 = InvoiceItem(
        invoice=the_invoice,
        start_date=datetime.date.today(),
        end_date=datetime.date.today(),
        quantity=10,
        unit="hours",
        unit_price=Decimal(100),
        description="work work",
        VAT_rate=Decimal(0.20),
    )

    assert item_1.invoice == the_invoice
    assert item_2.invoice == the_invoice

    assert the_invoice.sum == Decimal(1500)
    assert the_invoice.VAT_total == Decimal(300)
    assert the_invoice.total == Decimal(1800)


def test_generate_invoice(
    demo_projects,
    demo_calendar_timetracking,
):
    for i, project in enumerate(demo_projects):
        timesheets = []
        for period in ["January 2022", "February 2022"]:
            (period_start, period_end) = get_month_start_end(period)
            try:
                timesheet = timetracking.generate_timesheet(
                    timetracking_data=demo_calendar_timetracking.to_data(),
                    project=project,
                    period_start=period_start,
                    period_end=period_end,
                    item_description=project.title,
                )
            except ValueError:
                continue
            if not timesheet.empty:
                timesheets.append(timesheet)
        if not timesheets:
            continue
        invoice = invoicing.generate_invoice(
            timesheets=timesheets,
            contract=project.contract,
            project=project,
            date=datetime.date.today(),
            number=f"{datetime.date.today().strftime('%Y-%m-%d')}-{i}",
        )
        # Regression: previously every assertion in this test was commented out,
        # so a totally broken generate_invoice would pass.  Now we check that the
        # output actually reflects the input.
        assert len(invoice.items) == len(timesheets)
        assert invoice.sum == sum(item.subtotal for item in invoice.items)
        assert all(item.unit == project.contract.unit.value for item in invoice.items)
        if Decimal(str(project.contract.rate)) > 0:
            assert invoice.sum > 0
            assert invoice.total > 0


# ---------------------------------------------------------------------------
# Per-unit regression tests for Bug A (generate_invoice ignored contract.unit)
# ---------------------------------------------------------------------------


def _build_project(unit: TimeUnit, rate, tag: str) -> Project:
    client = Client(
        name="Acme Co",
        address=Address(
            street="Main",
            number="1",
            postal_code="00000",
            city="Nowhere",
            country="N/A",
        ),
    )
    contract = Contract(
        title="Test Contract",
        client=client,
        signature_date=datetime.date(2022, 1, 1),
        start_date=datetime.date(2022, 1, 1),
        rate=rate,
        currency="EUR",
        VAT_rate=Decimal("0.19"),
        unit=unit,
        units_per_workday=8,
        term_of_payment=14,
        billing_cycle=Cycle.monthly,
    )
    return Project(
        title=f"Test Project {tag}",
        description="Project for unit-test coverage",
        tag=tag,
        contract=contract,
        start_date=datetime.date(2022, 1, 1),
        end_date=datetime.date(2022, 12, 31),
    )


def _synthetic_timetracking_data(tag: str) -> pandas.DataFrame:
    """8 hours of tracked time across two work blocks."""
    data = {
        "begin": pandas.to_datetime(["2022-01-03 09:00:00", "2022-01-03 13:00:00"]),
        "end": pandas.to_datetime(["2022-01-03 13:00:00", "2022-01-03 17:00:00"]),
        "title": ["Morning", "Afternoon"],
        "tag": [tag, tag],
        "description": ["", ""],
        "all_day": [False, False],
    }
    df = pandas.DataFrame(data)
    df["duration"] = df["end"] - df["begin"]
    return df.set_index("begin")


def test_generate_invoice_respects_hour_unit():
    """8h tracked on an hour-rate contract → quantity=8, subtotal=400."""
    project = _build_project(TimeUnit.hour, Decimal("50"), tag="#HourProj")
    data = _synthetic_timetracking_data(project.tag)

    timesheet = timetracking.generate_timesheet(
        timetracking_data=data,
        project=project,
        period_start=datetime.date(2022, 1, 1),
        period_end=datetime.date(2022, 1, 31),
    )
    invoice = invoicing.generate_invoice(
        timesheets=[timesheet],
        contract=project.contract,
        project=project,
        number="HOUR-001",
        date=datetime.date(2022, 2, 1),
    )

    assert len(invoice.items) == 1
    item = invoice.items[0]
    assert item.quantity == pytest.approx(8.0)
    assert item.unit == "hour"
    assert item.unit_price == Decimal("50")
    assert invoice.sum == Decimal("400")


def test_generate_invoice_respects_day_unit():
    """8h tracked on a day-rate contract (8h/workday) → quantity=1.0, subtotal=500.

    This is the Bug-A reproducer: previously total_hours was used verbatim with
    unit hardcoded to ``"hour"``, producing 8 × €500 = €4000 instead of €500.
    """
    project = _build_project(TimeUnit.day, Decimal("500"), tag="#DayProj")
    data = _synthetic_timetracking_data(project.tag)

    timesheet = timetracking.generate_timesheet(
        timetracking_data=data,
        project=project,
        period_start=datetime.date(2022, 1, 1),
        period_end=datetime.date(2022, 1, 31),
    )
    invoice = invoicing.generate_invoice(
        timesheets=[timesheet],
        contract=project.contract,
        project=project,
        number="DAY-001",
        date=datetime.date(2022, 2, 1),
    )

    assert len(invoice.items) == 1
    item = invoice.items[0]
    # A contractual "day" is units_per_workday=8 hours, so 8h tracked = 1.0 day.
    assert item.quantity == pytest.approx(1.0)
    assert item.unit == "day"
    assert invoice.sum == Decimal("500")
