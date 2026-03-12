"""Revenue forecasting based on contracts, time allocation, and invoices."""

import datetime
from decimal import Decimal
from typing import List

import pandas
from pandas import DataFrame

from .model import Contract, Invoice


def monthly_revenue_from_contracts(
    contracts: List[Contract],
    start_date: datetime.date,
    end_date: datetime.date,
) -> DataFrame:
    """Project monthly revenue from active contracts and their rates.

    For each month in [start_date, end_date], estimates revenue based on
    contract rate × volume distributed across the contract duration.

    Returns a DataFrame with columns: month, project, revenue, contract_id.
    """
    records = []
    current = start_date.replace(day=1)
    while current <= end_date:
        month_end = (current + datetime.timedelta(days=32)).replace(
            day=1
        ) - datetime.timedelta(days=1)
        for contract in contracts:
            if contract.start_date > month_end:
                continue
            if contract.end_date and contract.end_date < current:
                continue
            if contract.is_completed:
                continue

            # Estimate workdays in this month (approx 22)
            workdays_in_month = 22

            if contract.volume and contract.start_date and contract.end_date:
                # Distribute volume evenly across contract duration
                total_days = (contract.end_date - contract.start_date).days or 1
                contract_months = max(total_days / 30.0, 1.0)
                units_per_month = contract.volume / contract_months
            else:
                # Assume full-time allocation: workdays × units_per_workday
                units_per_month = workdays_in_month * contract.units_per_workday

            monthly_revenue = Decimal(str(units_per_month)) * contract.rate
            project_title = (
                contract.projects[0].title if contract.projects else contract.title
            )

            records.append(
                {
                    "month": current,
                    "project": project_title,
                    "revenue": float(monthly_revenue),
                    "contract_id": contract.id,
                }
            )
        current = (current + datetime.timedelta(days=32)).replace(day=1)

    if not records:
        return DataFrame(columns=["month", "project", "revenue", "contract_id"])
    return DataFrame(records)


def revenue_history(
    invoices: List[Invoice],
) -> DataFrame:
    """Build a monthly revenue history from past invoices.

    Returns a DataFrame with columns: month, revenue, invoice_count.
    """
    if not invoices:
        return DataFrame(columns=["month", "revenue", "invoice_count"])

    records = []
    for inv in invoices:
        if inv.cancelled:
            continue
        records.append(
            {
                "date": inv.date,
                "revenue": float(inv.total),
            }
        )

    if not records:
        return DataFrame(columns=["month", "revenue", "invoice_count"])

    df = DataFrame(records)
    df["month"] = pandas.to_datetime(df["date"]).dt.to_period("M").dt.to_timestamp()
    monthly = (
        df.groupby("month")
        .agg(
            revenue=("revenue", "sum"),
            invoice_count=("revenue", "count"),
        )
        .reset_index()
    )
    return monthly


def revenue_curve(
    invoices: List[Invoice],
    contracts: List[Contract],
    forecast_months: int = 6,
) -> DataFrame:
    """Combine historical revenue with forecast into a single time series.

    Returns a DataFrame with columns: month, revenue, is_forecast.
    """
    # Historical
    history = revenue_history(invoices)
    if not history.empty:
        history["is_forecast"] = False
    else:
        history = DataFrame(columns=["month", "revenue", "is_forecast"])

    # Forecast
    today = datetime.date.today()
    forecast_start = today.replace(day=1)
    forecast_end = (
        forecast_start + datetime.timedelta(days=30 * forecast_months)
    ).replace(day=1)
    forecast = monthly_revenue_from_contracts(contracts, forecast_start, forecast_end)
    if not forecast.empty:
        forecast_monthly = (
            forecast.groupby("month").agg(revenue=("revenue", "sum")).reset_index()
        )
        forecast_monthly["is_forecast"] = True
    else:
        forecast_monthly = DataFrame(columns=["month", "revenue", "is_forecast"])

    combined = pandas.concat([history, forecast_monthly], ignore_index=True)
    combined["month"] = pandas.to_datetime(combined["month"])
    combined = combined.sort_values("month").reset_index(drop=True)

    # Cumulative revenue
    combined["cumulative_revenue"] = combined["revenue"].cumsum()

    return combined
