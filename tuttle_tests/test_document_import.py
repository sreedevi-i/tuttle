"""Tests for the document import flow (invoice import via commit_import)."""

import datetime
from decimal import Decimal

import pytest
from sqlmodel import Session, SQLModel, create_engine, select

from tuttle.model import (
    Client,
    Contract,
    Invoice,
    InvoiceItem,
    Project,
)
from tuttle.app.imports.intent import ImportsIntent, _model_fields
from tuttle.app.core.abstractions import SQLModelDataSourceMixin


@pytest.fixture
def in_memory_db(monkeypatch):
    """Set up an in-memory SQLite database for testing."""
    engine = create_engine("sqlite:///:memory:")
    SQLModel.metadata.create_all(engine)

    def _create_session(self):
        return Session(engine)

    monkeypatch.setattr(SQLModelDataSourceMixin, "create_session", _create_session)
    return engine


class TestInvoiceImport:
    def test_commit_invoice_basic(self, in_memory_db):
        """Import a basic invoice with line items."""
        intent = ImportsIntent()

        data = {
            "contacts": [],
            "clients": [{"ref": "client_1", "name": "Acme Corp"}],
            "contracts": [
                {
                    "ref": "contract_1",
                    "title": "Web Development",
                    "client_ref": "client_1",
                    "rate": 100.0,
                    "currency": "EUR",
                    "unit": "hour",
                    "billing_cycle": "monthly",
                    "volume": 160,
                    "start_date": "2024-01-01",
                    "VAT_rate": 0.19,
                    "term_of_payment": 14,
                }
            ],
            "projects": [
                {
                    "ref": "project_1",
                    "title": "Website Redesign",
                    "description": "Full redesign of company website",
                    "tag": "#WebRedesign",
                    "contract_ref": "contract_1",
                    "start_date": "2024-01-01",
                    "end_date": "2024-06-30",
                }
            ],
            "invoices": [
                {
                    "ref": "invoice_1",
                    "number": "2024-01-01",
                    "date": "2024-01-31",
                    "notes": "Thank you for your business.",
                    "contract_ref": "contract_1",
                    "project_ref": "project_1",
                    "sent": True,
                    "paid": False,
                    "items": [
                        {
                            "description": "Frontend development",
                            "quantity": 40.0,
                            "unit": "hour",
                            "unit_price": 100.0,
                            "VAT_rate": 0.19,
                            "start_date": "2024-01-01",
                            "end_date": "2024-01-31",
                        },
                        {
                            "description": "Backend development",
                            "quantity": 20.0,
                            "unit": "hour",
                            "unit_price": 100.0,
                            "VAT_rate": 0.19,
                            "start_date": "2024-01-01",
                            "end_date": "2024-01-31",
                        },
                    ],
                }
            ],
        }

        result = intent.commit_import(data)
        assert result.was_intent_successful

        summary = result.data
        assert "Invoice: 2024-01-01" in summary["created"]
        assert any("Acme Corp" in s for s in summary["created"])
        assert any("Web Development" in s for s in summary["created"])

        # Verify DB state
        with Session(in_memory_db) as session:
            invoices = session.exec(select(Invoice)).all()
            assert len(invoices) == 1
            inv = invoices[0]
            assert inv.number == "2024-01-01"
            assert inv.date == datetime.date(2024, 1, 31)
            assert inv.sent is True
            assert inv.paid is False
            assert inv.rendered is True
            assert inv.notes == "Thank you for your business."
            assert inv.contract_id is not None
            assert inv.project_id is not None

            items = session.exec(select(InvoiceItem)).all()
            assert len(items) == 2
            assert items[0].quantity == 40.0
            assert items[0].unit_price == Decimal("100.0")
            assert items[1].quantity == 20.0

    def test_commit_invoice_with_existing_contract(self, in_memory_db):
        """Import an invoice linked to an existing DB contract via existing:ID."""
        with Session(in_memory_db) as session:
            client = Client(name="Existing Client")
            session.add(client)
            session.flush()
            contract = Contract(
                title="Existing Contract",
                client_id=client.id,
                rate=Decimal("80"),
                currency="EUR",
                unit="hour",
                start_date=datetime.date(2023, 1, 1),
            )
            session.add(contract)
            session.flush()
            project = Project(
                title="Existing Project",
                description="Project for testing",
                tag="#ExistingProj",
                contract_id=contract.id,
                start_date=datetime.date(2023, 1, 1),
                end_date=datetime.date(2023, 12, 31),
            )
            session.add(project)
            session.commit()
            contract_id = contract.id
            project_id = project.id

        intent = ImportsIntent()
        data = {
            "contacts": [],
            "clients": [],
            "contracts": [],
            "projects": [],
            "invoices": [
                {
                    "ref": "invoice_1",
                    "number": "2024-03-15",
                    "date": "2024-03-15",
                    "contract_ref": f"existing:{contract_id}",
                    "project_ref": f"existing:{project_id}",
                    "items": [
                        {
                            "description": "Consulting",
                            "quantity": 8.0,
                            "unit": "hour",
                            "unit_price": 80.0,
                            "VAT_rate": 0.19,
                            "start_date": "2024-03-15",
                            "end_date": "2024-03-15",
                        },
                    ],
                }
            ],
        }

        result = intent.commit_import(data)
        assert result.was_intent_successful

        with Session(in_memory_db) as session:
            inv = session.exec(select(Invoice)).first()
            assert inv.contract_id == contract_id
            assert inv.project_id == project_id

    def test_commit_invoice_no_items_validates(self, in_memory_db):
        """An invoice with no items still persists (validation is UI-side)."""
        intent = ImportsIntent()
        data = {
            "contacts": [],
            "clients": [],
            "contracts": [],
            "projects": [],
            "invoices": [
                {
                    "ref": "invoice_1",
                    "number": "EMPTY-001",
                    "date": "2024-05-01",
                    "contract_ref": "",
                    "project_ref": "",
                    "items": [],
                }
            ],
        }

        result = intent.commit_import(data)
        assert result.was_intent_successful

        with Session(in_memory_db) as session:
            inv = session.exec(select(Invoice)).first()
            assert inv.number == "EMPTY-001"
            assert inv.contract_id is None

    def test_model_fields_coercion(self):
        """Test that _model_fields correctly coerces invoice types."""
        data = {
            "number": "2024-01",
            "date": "2024-01-31",
            "sent": True,
            "rendered": True,
            "notes": "Hello",
            "ref": "should_be_excluded",
            "items": "should_be_excluded",
            "contract_ref": "should_be_excluded",
        }
        fields = _model_fields(data, Invoice)
        assert "ref" not in fields
        assert "items" not in fields
        assert "contract_ref" not in fields
        assert fields["number"] == "2024-01"
        assert fields["date"] == datetime.date(2024, 1, 31)
        assert fields["sent"] is True

    def test_validation_catches_missing_required_fields(self, in_memory_db):
        """Required fields are validated before DB insertion."""
        intent = ImportsIntent()
        data = {
            "contacts": [],
            "clients": [{"ref": "client_1", "name": "Acme"}],
            "contracts": [
                {
                    "ref": "contract_1",
                    "title": "Dev Contract",
                    "client_ref": "client_1",
                    "rate": 100.0,
                    "currency": "EUR",
                    "start_date": "2024-01-01",
                }
            ],
            "projects": [
                {
                    "ref": "project_1",
                    "title": "My Project",
                    "contract_ref": "contract_1",
                    "start_date": "2024-01-01",
                }
            ],
            "invoices": [],
        }

        result = intent.commit_import(data)
        assert not result.was_intent_successful
        msg = result.error_msg.lower()
        # Project missing fields (labels derived from model field names)
        assert "description" in msg
        assert "tag" in msg
        assert "end date" in msg
        # Contract missing fields
        assert "volume" in msg

    def test_validation_skips_existing_entities(self, in_memory_db):
        """Entities with existing_id skip validation (they're link-only)."""
        intent = ImportsIntent()
        data = {
            "contacts": [],
            "clients": [],
            "contracts": [],
            "projects": [
                {
                    "ref": "project_1",
                    "existing_id": 999,
                    "title": "Incomplete",
                }
            ],
            "invoices": [],
        }

        result = intent.commit_import(data)
        assert result.was_intent_successful


class TestLlmInvoiceSchema:
    def test_extraction_schema_includes_invoices(self):
        """Verify the extraction schema has an invoices field."""
        from tuttle.llm import DocumentExtractionResult

        assert "invoices" in DocumentExtractionResult.model_fields

    def test_invoice_extract_model_fields(self):
        """Verify the invoice extraction model has the right fields."""
        from tuttle.llm import _RefInvoice, _RefInvoiceItem

        inv_fields = set(_RefInvoice.model_fields.keys())
        assert "number" in inv_fields
        assert "date" in inv_fields
        assert "notes" in inv_fields
        assert "ref" in inv_fields
        assert "contract_ref" in inv_fields
        assert "project_ref" in inv_fields
        assert "items" in inv_fields

        item_fields = set(_RefInvoiceItem.model_fields.keys())
        assert "quantity" in item_fields
        assert "unit" in item_fields
        assert "unit_price" in item_fields
        assert "description" in item_fields
        assert "VAT_rate" in item_fields
        assert "start_date" in item_fields

    def test_map_invoices(self):
        """Test invoice mapping from extraction result to dict."""
        from tuttle.llm import _map_invoices, _RefInvoice, _RefInvoiceItem

        inv = _RefInvoice(
            ref="invoice_1",
            number="2024-06-01",
            date=datetime.date(2024, 6, 1),
            notes="Test",
            contract_ref="contract_1",
            project_ref="project_1",
            items=[
                _RefInvoiceItem(
                    start_date=datetime.date(2024, 6, 1),
                    end_date=datetime.date(2024, 6, 30),
                    quantity=10.0,
                    unit="hour",
                    unit_price=100.0,
                    description="Dev work",
                    VAT_rate=0.19,
                )
            ],
        )

        result = _map_invoices([inv])
        assert len(result) == 1
        assert result[0]["number"] == "2024-06-01"
        assert result[0]["ref"] == "invoice_1"
        assert len(result[0]["items"]) == 1
        assert result[0]["items"][0]["quantity"] == 10.0
        assert result[0]["items"][0]["start_date"] == "2024-06-01"

    def test_summary_prompt_includes_invoices(self):
        """Verify the generated summary prompt mentions invoices."""
        from tuttle.llm import _DOC_SUMMARY_PROMPT

        assert "INVOICES" in _DOC_SUMMARY_PROMPT
