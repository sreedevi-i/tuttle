"""Tests for tuttle.forecasting and tuttle.kpi modules."""

import datetime
from decimal import Decimal

import pytest

from tuttle.model import (
    Address,
    BankAccount,
    Client,
    Contact,
    Contract,
    Invoice,
    InvoiceItem,
    Project,
    Timesheet,
    TimeTrackingItem,
    User,
    FinancialGoal,
)
from tuttle.time import Cycle, TimeUnit
from tuttle.forecasting import (
    monthly_revenue_from_contracts,
    revenue_history,
    revenue_curve,
)
from tuttle.kpi import compute_kpis, monthly_revenue_breakdown, project_budget_status


# ── Fixtures ──────────────────────────────────────────────────


@pytest.fixture
def contact():
    return Contact(
        first_name="Test",
        last_name="Client",
        email="test@example.com",
        address=Address(
            street="Test St",
            number="1",
            postal_code="12345",
            city="Berlin",
            country="Germany",
        ),
    )


@pytest.fixture
def client(contact):
    return Client(name="Test Corp", invoicing_contact=contact)


@pytest.fixture
def active_contract(client):
    today = datetime.date.today()
    return Contract(
        title="Active Contract",
        client=client,
        signature_date=today - datetime.timedelta(days=60),
        start_date=today - datetime.timedelta(days=30),
        end_date=today + datetime.timedelta(days=180),
        rate=Decimal("100.00"),
        currency="EUR",
        unit=TimeUnit.hour,
        units_per_workday=8,
        volume=500,
        term_of_payment=14,
        billing_cycle=Cycle.monthly,
    )


@pytest.fixture
def project(active_contract):
    today = datetime.date.today()
    return Project(
        title="Test Project",
        tag="#TestProject",
        description="A test project",
        start_date=today - datetime.timedelta(days=30),
        end_date=today + datetime.timedelta(days=180),
        contract=active_contract,
    )


@pytest.fixture
def timesheet_with_items(project):
    today = datetime.date.today()
    ts = Timesheet(
        title="Test Timesheet",
        date=today,
        period_start=today - datetime.timedelta(days=30),
        period_end=today,
        project=project,
    )
    for i in range(5):
        item = TimeTrackingItem(
            timesheet=ts,
            begin=datetime.datetime(
                today.year, today.month, max(today.day - 5 + i, 1), 9, 0
            ),
            end=datetime.datetime(
                today.year, today.month, max(today.day - 5 + i, 1), 17, 0
            ),
            duration=datetime.timedelta(hours=8),
            title=f"Work day {i+1}",
            tag="#TestProject",
        )
        ts.items.append(item)
    return ts


@pytest.fixture
def paid_invoice(active_contract, project, timesheet_with_items):
    today = datetime.date.today()
    inv = Invoice(
        number="2026-001",
        date=today - datetime.timedelta(days=15),
        contract=active_contract,
        project=project,
        sent=True,
        paid=True,
        rendered=True,
    )
    inv.items.append(
        InvoiceItem(
            invoice=inv,
            start_date=today - datetime.timedelta(days=30),
            end_date=today,
            quantity=40,
            unit="hour",
            unit_price=Decimal("100.00"),
            description="Development work",
            VAT_rate=Decimal("0.19"),
        )
    )
    timesheet_with_items.invoice = inv
    return inv


@pytest.fixture
def unpaid_invoice(active_contract, project):
    today = datetime.date.today()
    inv = Invoice(
        number="2026-002",
        date=today - datetime.timedelta(days=5),
        contract=active_contract,
        project=project,
        sent=True,
        paid=False,
        rendered=True,
    )
    inv.items.append(
        InvoiceItem(
            invoice=inv,
            start_date=today - datetime.timedelta(days=10),
            end_date=today - datetime.timedelta(days=5),
            quantity=20,
            unit="hour",
            unit_price=Decimal("100.00"),
            description="More work",
            VAT_rate=Decimal("0.19"),
        )
    )
    return inv


# ── Forecasting Tests ─────────────────────────────────────────


class TestMonthlyRevenueFromContracts:
    def test_empty_contracts(self):
        today = datetime.date.today()
        result = monthly_revenue_from_contracts(
            [], today, today + datetime.timedelta(days=60)
        )
        assert result.empty

    def test_active_contract_produces_rows(self, active_contract, project):
        # project must be attached for the function to pick up the title
        active_contract.projects = [project]
        today = datetime.date.today()
        result = monthly_revenue_from_contracts(
            [active_contract],
            today,
            today + datetime.timedelta(days=90),
        )
        assert not result.empty
        assert "month" in result.columns
        assert "revenue" in result.columns
        assert all(result["revenue"] > 0)

    def test_completed_contract_excluded(self, active_contract, project):
        active_contract.is_completed = True
        active_contract.projects = [project]
        today = datetime.date.today()
        result = monthly_revenue_from_contracts(
            [active_contract],
            today,
            today + datetime.timedelta(days=90),
        )
        assert result.empty

    def test_future_contract_excluded_before_start(self, active_contract, project):
        today = datetime.date.today()
        active_contract.start_date = today + datetime.timedelta(days=100)
        active_contract.end_date = today + datetime.timedelta(days=200)
        active_contract.projects = [project]
        result = monthly_revenue_from_contracts(
            [active_contract],
            today,
            today + datetime.timedelta(days=30),
        )
        assert result.empty


class TestRevenueHistory:
    def test_empty_invoices(self):
        result = revenue_history([])
        assert result.empty

    def test_cancelled_invoices_excluded(self, paid_invoice):
        paid_invoice.cancelled = True
        result = revenue_history([paid_invoice])
        assert result.empty

    def test_paid_invoice_included(self, paid_invoice):
        result = revenue_history([paid_invoice])
        assert not result.empty
        assert result["revenue"].sum() > 0


class TestRevenueCurve:
    def test_combined_history_and_forecast(
        self, paid_invoice, active_contract, project
    ):
        active_contract.projects = [project]
        result = revenue_curve([paid_invoice], [active_contract], forecast_months=3)
        assert not result.empty
        assert "is_forecast" in result.columns
        assert "cumulative_revenue" in result.columns

    def test_empty_data(self):
        result = revenue_curve([], [], forecast_months=3)
        assert result.empty or len(result) == 0


# ── KPI Tests ─────────────────────────────────────────────────


class TestComputeKPIs:
    def test_with_paid_invoice(self, paid_invoice, active_contract, project):
        kpis = compute_kpis([paid_invoice], [active_contract], [project])
        assert kpis.total_revenue > 0
        assert kpis.outstanding_amount == 0
        assert kpis.active_contracts == 1
        assert kpis.active_projects == 1
        assert kpis.unpaid_invoices == 0

    def test_with_unpaid_invoice(self, unpaid_invoice, active_contract, project):
        kpis = compute_kpis([unpaid_invoice], [active_contract], [project])
        assert kpis.total_revenue == 0
        assert kpis.outstanding_amount > 0
        assert kpis.unpaid_invoices == 1

    def test_effective_hourly_rate(self, paid_invoice, active_contract, project):
        kpis = compute_kpis([paid_invoice], [active_contract], [project])
        if kpis.effective_hourly_rate is not None:
            assert kpis.effective_hourly_rate > 0

    def test_empty_data(self):
        kpis = compute_kpis([], [], [])
        assert kpis.total_revenue == 0
        assert kpis.active_projects == 0
        assert kpis.active_contracts == 0


class TestMonthlyRevenueBreakdown:
    def test_empty_invoices(self):
        result = monthly_revenue_breakdown([])
        assert isinstance(result, list)
        assert len(result) > 0  # should still have month buckets

    def test_with_invoices(self, paid_invoice):
        result = monthly_revenue_breakdown([paid_invoice], n_months=3)
        assert isinstance(result, list)
        total = sum(float(m["revenue"]) for m in result)
        assert total > 0


class TestProjectBudgetStatus:
    def test_project_without_volume(self, project):
        project.contract.volume = None
        result = project_budget_status([project])
        assert result == []

    def test_project_with_volume_and_timesheets(self, project, timesheet_with_items):
        project.contract.volume = 100
        project.timesheets = [timesheet_with_items]
        result = project_budget_status([project])
        assert len(result) == 1
        assert result[0]["project"] == "Test Project"
        assert result[0]["hours_tracked"] > 0
        assert 0 <= result[0]["progress"] <= 1.0

    def test_empty_projects(self):
        result = project_budget_status([])
        assert result == []
