"""Flet-free bridge for the macOS native app.

Thin serialization layer that delegates to the existing Intent classes
and converts their results to PythonKit-friendly dicts.
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional

from loguru import logger

from .app.core.formatting import fmt_currency
from .app.clients.intent import ClientsIntent
from .app.contacts.intent import ContactsIntent
from .app.contracts.intent import ContractsIntent
from .app.dashboard.intent import DashboardIntent
from .app.invoicing.data_source import InvoicingDataSource
from .app.projects.intent import ProjectsIntent
from .app.timeline.intent import TimelineIntent
from .migrations.run import run_migrations


class TuttleBridge:
    """Flet-free service layer for the Swift macOS app."""

    def __init__(self):
        self._dashboard = DashboardIntent()
        self._timeline = TimelineIntent()
        self._clients = ClientsIntent()
        self._contacts = ContactsIntent()
        self._contracts = ContractsIntent()
        self._projects = ProjectsIntent()
        self._invoicing_ds = InvoicingDataSource()
        self._db_path = Path.home() / ".tuttle" / "tuttle.db"

    def install_demo_data(self, n_projects: int = 4):
        """Reset DB and install demo data. Returns True on success."""
        from . import demo

        try:
            if self._db_path.exists():
                self._db_path.unlink()
            db_url = f"sqlite:///{self._db_path}"
            run_migrations(db_url)
            demo.install_demo_data(
                n_projects=n_projects,
                db_path=str(self._db_path),
                on_cache_timetracking_dataframe=lambda _df: None,
            )
            self._dashboard = DashboardIntent()
            self._timeline = TimelineIntent()
            self._clients = ClientsIntent()
            self._contacts = ContactsIntent()
            self._contracts = ContractsIntent()
            self._projects = ProjectsIntent()
            self._invoicing_ds = InvoicingDataSource()
            return True
        except Exception as e:
            logger.exception(e)
            return False

    # ── Dashboard ──────────────────────────────────────────────

    def get_dashboard_kpis(self) -> dict:
        result = self._dashboard.get_kpis()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        kpis = result.data
        tc = kpis.tax_currency
        return {
            "ok": True,
            "total_revenue_ytd": float(kpis.total_revenue_ytd),
            "outstanding_amount": float(kpis.outstanding_amount),
            "overdue_amount": float(kpis.overdue_amount),
            "effective_hourly_rate": float(kpis.effective_hourly_rate)
            if kpis.effective_hourly_rate
            else None,
            "utilization_rate": kpis.utilization_rate,
            "active_projects": kpis.active_projects,
            "active_contracts": kpis.active_contracts,
            "unpaid_invoices": kpis.unpaid_invoices,
            "vat_reserve": float(kpis.vat_reserve),
            "income_tax_reserve": float(kpis.income_tax_reserve),
            "spendable_income": float(kpis.spendable_income),
            "tax_currency": tc,
            "total_revenue_ytd_fmt": fmt_currency(kpis.total_revenue_ytd, tc),
            "outstanding_amount_fmt": fmt_currency(kpis.outstanding_amount, tc),
            "overdue_amount_fmt": fmt_currency(kpis.overdue_amount, tc),
            "effective_hourly_rate_fmt": fmt_currency(kpis.effective_hourly_rate, tc)
            if kpis.effective_hourly_rate
            else "—",
            "vat_reserve_fmt": fmt_currency(kpis.vat_reserve, tc),
            "income_tax_reserve_fmt": fmt_currency(kpis.income_tax_reserve, tc),
            "spendable_income_fmt": fmt_currency(kpis.spendable_income, tc),
            "utilization_rate_fmt": f"{kpis.utilization_rate * 100:.0f}%"
            if kpis.utilization_rate is not None
            else "—",
        }

    def get_monthly_chart_data(self, n_months: int = 12) -> dict:
        result = self._dashboard.get_monthly_chart_data(n_months=n_months)
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        data = result.data
        rev_list = [
            {"month": m["month"], "revenue": float(m["revenue"])}
            for m in data["revenue"]
        ]
        sp_list = [
            {"month": m["month"], "spendable": float(m["spendable"])}
            for m in data["spendable"]
        ]
        return {"ok": True, "revenue": rev_list, "spendable": sp_list}

    def get_project_budgets(self) -> dict:
        result = self._dashboard.get_project_budgets()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        return {"ok": True, "budgets": result.data}

    def get_financial_goals(self) -> dict:
        result = self._dashboard.get_financial_goals()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}

        kpi_result = self._dashboard.get_kpis()
        ytd_revenue = 0.0
        tc = "EUR"
        if kpi_result.was_intent_successful and kpi_result.data is not None:
            ytd_revenue = float(kpi_result.data.total_revenue_ytd)
            tc = kpi_result.data.tax_currency

        goals_out = []
        for g in result.data:
            target = float(g.target_amount)
            progress = min(ytd_revenue / target, 1.0) if target > 0 else 0.0
            goals_out.append(
                {
                    "id": g.id,
                    "title": g.title,
                    "target_amount": target,
                    "target_amount_fmt": fmt_currency(g.target_amount, tc),
                    "target_date": g.target_date.isoformat(),
                    "target_date_fmt": g.target_date.strftime("%b %Y"),
                    "is_reached": g.is_reached,
                    "progress": progress,
                    "ytd_revenue_fmt": fmt_currency(ytd_revenue, tc),
                }
            )
        return {"ok": True, "goals": goals_out, "currency": tc}

    # ── Timeline ───────────────────────────────────────────────

    def get_timeline_events(self, category_filter: Optional[str] = None) -> dict:
        result = self._timeline.get_timeline_events(category_filter=category_filter)
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}

        events_out = [
            {
                "date": e.date.isoformat(),
                "title": e.title,
                "description": e.description,
                "category": e.category,
                "icon": e.icon,
                "color": e.color,
                "status": self._infer_status(e.title),
                "is_future": e.is_future,
                "entity_id": e.entity_id,
            }
            for e in result.data
        ]
        return {"ok": True, "events": events_out}

    @staticmethod
    def _infer_status(title: str) -> str:
        t = title.lower()
        for keyword in ("cancelled", "overdue", "paid", "completed", "reached", "due"):
            if keyword in t:
                return keyword
        return "default"

    # ── Contacts ───────────────────────────────────────────────

    def get_all_contacts(self) -> dict:
        result = self._contacts.get_all()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        contacts = []
        for c in result.data:
            addr = c.address
            contacts.append(
                {
                    "id": c.id,
                    "first_name": c.first_name or "",
                    "last_name": c.last_name or "",
                    "company": c.company or "",
                    "email": c.email or "",
                    "street": addr.street if addr else "",
                    "city": addr.city if addr else "",
                    "postal_code": addr.postal_code if addr else "",
                    "country": addr.country if addr else "",
                }
            )
        return {"ok": True, "contacts": contacts}

    def delete_contact(self, contact_id: int) -> dict:
        result = self._contacts.delete(contact_id)
        if not result.was_intent_successful:
            return {"ok": False, "error": result.error_msg}
        return {"ok": True}

    # ── Clients ────────────────────────────────────────────────

    def get_all_clients(self) -> dict:
        result = self._clients.get_all()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        clients = []
        for cl in result.data:
            contact = cl.invoicing_contact
            n_contracts = len(cl.contracts) if cl.contracts else 0
            clients.append(
                {
                    "id": cl.id,
                    "name": cl.name,
                    "contact_name": contact.name if contact else "",
                    "contact_email": contact.email if contact else "",
                    "contact_company": contact.company if contact else "",
                    "contact_city": contact.address.city
                    if contact and contact.address
                    else "",
                    "contact_country": contact.address.country
                    if contact and contact.address
                    else "",
                    "num_contracts": n_contracts,
                }
            )
        return {"ok": True, "clients": clients}

    def delete_client(self, client_id: int) -> dict:
        result = self._clients.delete(client_id)
        if not result.was_intent_successful:
            return {"ok": False, "error": result.error_msg}
        return {"ok": True}

    # ── Contracts ──────────────────────────────────────────────

    def get_all_contracts(self) -> dict:
        result = self._contracts.get_all()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        contracts = []
        for c in result.data:
            client_name = c.client.name if c.client else "—"
            contracts.append(
                {
                    "id": c.id,
                    "title": c.title,
                    "client_name": client_name,
                    "status": c.get_status(),
                    "start_date": c.start_date.isoformat(),
                    "end_date": c.end_date.isoformat() if c.end_date else None,
                    "rate": float(c.rate),
                    "rate_fmt": fmt_currency(c.rate, c.currency),
                    "currency": c.currency,
                    "unit": c.unit.value if c.unit else "hour",
                    "volume": c.volume,
                    "billing_cycle": c.billing_cycle.value if c.billing_cycle else "",
                    "is_completed": c.is_completed,
                    "vat_rate": float(c.VAT_rate),
                    "num_projects": len(c.projects) if c.projects else 0,
                    "num_invoices": len(c.invoices) if c.invoices else 0,
                }
            )
        return {"ok": True, "contracts": contracts}

    def delete_contract(self, contract_id: int) -> dict:
        result = self._contracts.delete(contract_id)
        if not result.was_intent_successful:
            return {"ok": False, "error": result.error_msg}
        return {"ok": True}

    def toggle_contract_completed(self, contract_id: int) -> dict:
        result = self._contracts.get_by_id(contract_id)
        if not result.was_intent_successful or result.data is None:
            return {"ok": False, "error": result.error_msg}
        toggle_result = self._contracts.toggle_complete_status(result.data)
        if not toggle_result.was_intent_successful:
            return {"ok": False, "error": toggle_result.error_msg}
        return {"ok": True}

    # ── Projects ───────────────────────────────────────────────

    def get_all_projects(self) -> dict:
        result = self._projects.get_all()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        projects = []
        for p in result.data:
            client_name = ""
            contract_title = ""
            if p.contract:
                contract_title = p.contract.title
                if p.contract.client:
                    client_name = p.contract.client.name
            projects.append(
                {
                    "id": p.id,
                    "title": p.title,
                    "tag": p.tag,
                    "description": p.description,
                    "client_name": client_name,
                    "contract_title": contract_title,
                    "status": p.get_status(),
                    "start_date": p.start_date.isoformat(),
                    "end_date": p.end_date.isoformat() if p.end_date else None,
                    "is_completed": p.is_completed,
                    "num_invoices": len(p.invoices) if p.invoices else 0,
                    "num_timesheets": len(p.timesheets) if p.timesheets else 0,
                }
            )
        return {"ok": True, "projects": projects}

    def delete_project(self, project_id: int) -> dict:
        result = self._projects.delete(project_id)
        if not result.was_intent_successful:
            return {"ok": False, "error": result.error_msg}
        return {"ok": True}

    def toggle_project_completed(self, project_id: int) -> dict:
        result = self._projects.get_by_id(project_id)
        if not result.was_intent_successful or result.data is None:
            return {"ok": False, "error": result.error_msg}
        toggle_result = self._projects.toggle_project_completed_status(result.data)
        if not toggle_result.was_intent_successful:
            return {"ok": False, "error": toggle_result.error_msg}
        return {"ok": True}

    # ── Invoicing ─────────────────────────────────────────────

    def get_all_invoices(self) -> dict:
        result = self._invoicing_ds.get_all_invoices()
        if not result.was_intent_successful or result.data is None:
            result.log_message_if_any()
            return {"ok": False, "error": result.error_msg}
        invoices = []
        for inv in result.data:
            client_name = ""
            if inv.contract and inv.contract.client:
                client_name = inv.contract.client.name
            project_title = inv.project.title if inv.project else ""
            contract_title = inv.contract.title if inv.contract else ""
            currency = inv.contract.currency if inv.contract else "EUR"

            status = "draft"
            if inv.cancelled:
                status = "cancelled"
            elif inv.paid:
                status = "paid"
            elif inv.sent:
                due = inv.due_date
                if due and due < __import__("datetime").date.today():
                    status = "overdue"
                else:
                    status = "sent"

            items_out = []
            for item in inv.items or []:
                items_out.append(
                    {
                        "id": item.id,
                        "description": item.description,
                        "quantity": float(item.quantity),
                        "unit": item.unit,
                        "unit_price": float(item.unit_price),
                        "unit_price_fmt": fmt_currency(item.unit_price, currency),
                        "vat_rate": float(item.VAT_rate),
                        "subtotal": float(item.subtotal),
                        "subtotal_fmt": fmt_currency(item.subtotal, currency),
                        "start_date": item.start_date.isoformat(),
                        "end_date": item.end_date.isoformat()
                        if item.end_date
                        else None,
                    }
                )

            invoices.append(
                {
                    "id": inv.id,
                    "number": inv.number or "",
                    "date": inv.date.isoformat(),
                    "client_name": client_name,
                    "project_title": project_title,
                    "contract_title": contract_title,
                    "currency": currency,
                    "subtotal": float(inv.sum),
                    "subtotal_fmt": fmt_currency(inv.sum, currency),
                    "vat_total": float(inv.VAT_total),
                    "vat_total_fmt": fmt_currency(inv.VAT_total, currency),
                    "total": float(inv.total),
                    "total_fmt": fmt_currency(inv.total, currency),
                    "status": status,
                    "sent": bool(inv.sent),
                    "paid": bool(inv.paid),
                    "cancelled": bool(inv.cancelled),
                    "rendered": bool(inv.rendered),
                    "due_date": inv.due_date.isoformat() if inv.due_date else None,
                    "items": items_out,
                }
            )
        return {"ok": True, "invoices": invoices}

    def delete_invoice(self, invoice_id: int) -> dict:
        try:
            self._invoicing_ds.delete_invoice_by_id(invoice_id)
            return {"ok": True}
        except Exception as e:
            logger.exception(e)
            return {"ok": False, "error": str(e)}

    def _get_invoice_by_id(self, invoice_id: int):
        """Load a single Invoice from DB by primary key."""
        from .model import Invoice

        with self._invoicing_ds.create_session() as session:
            inv = session.get(Invoice, invoice_id)
            return inv

    def toggle_invoice_sent(self, invoice_id: int) -> dict:
        inv = self._get_invoice_by_id(invoice_id)
        if inv is None:
            return {"ok": False, "error": "Invoice not found"}
        inv.sent = not inv.sent
        self._invoicing_ds.save_invoice(inv)
        return {"ok": True}

    def toggle_invoice_paid(self, invoice_id: int) -> dict:
        inv = self._get_invoice_by_id(invoice_id)
        if inv is None:
            return {"ok": False, "error": "Invoice not found"}
        inv.paid = not inv.paid
        self._invoicing_ds.save_invoice(inv)
        return {"ok": True}

    def toggle_invoice_cancelled(self, invoice_id: int) -> dict:
        inv = self._get_invoice_by_id(invoice_id)
        if inv is None:
            return {"ok": False, "error": "Invoice not found"}
        inv.cancelled = not inv.cancelled
        self._invoicing_ds.save_invoice(inv)
        return {"ok": True}
