from typing import Optional

import datetime

from ..clients.intent import ClientsIntent
from ..contacts.intent import ContactsIntent
from ..core.abstractions import ClientStorage, CrudIntent
from ..core.intent_result import IntentResult
from ..preferences.intent import PreferencesIntent
from ..preferences.model import PreferencesStorageKeys

from ...model import Client, Contact, Contract
from ...time import Cycle, TimeUnit


class ContractsIntent(CrudIntent):
    """Handles Contract CRUD intents."""

    entity_type = Contract

    def __init__(self):
        super().__init__()
        self._clients_intent = ClientsIntent()
        self._contacts_intent = ContactsIntent()

    # -- Cross-entity delegates ------------------------------------------------

    def get_all_clients_as_map(self):
        return self._clients_intent.get_all_as_map()

    def get_all_contacts_as_map(self):
        return self._contacts_intent.get_all_as_map()

    def save_client(self, client: Client) -> IntentResult:
        return self._clients_intent.save_client(client=client)

    def get_preferred_currency_intent(
        self, client_storage: ClientStorage
    ) -> IntentResult:
        _preferences_intent = PreferencesIntent(client_storage=client_storage)
        return _preferences_intent.get_preference_by_key(
            preference_key=PreferencesStorageKeys.default_currency_key
        )

    # -- Contract-specific logic -----------------------------------------------

    def save_contract(
        self,
        title: str,
        signature_date: datetime.date,
        start_date: datetime.date,
        end_date: Optional[datetime.date],
        client: Client,
        rate: str,
        currency: str,
        VAT_rate: str,
        unit: TimeUnit,
        units_per_workday: str,
        volume: Optional[str],
        term_of_payment: Optional[str],
        billing_cycle: Cycle = Cycle.hourly,
        is_completed: bool = False,
        contract: Optional[Contract] = None,
    ) -> IntentResult:
        """Creates a new contract or updates the given contract."""
        is_updating = contract is not None
        if not contract:
            contract = Contract()
        contract.title = title
        contract.signature_date = signature_date
        contract.start_date = start_date
        contract.end_date = end_date
        contract.client = client
        contract.rate = rate
        contract.currency = currency
        contract.VAT_rate = VAT_rate
        contract.unit = unit
        contract.units_per_workday = units_per_workday
        contract.volume = volume
        contract.term_of_payment = term_of_payment
        contract.billing_cycle = billing_cycle
        contract.is_completed = is_completed
        result = self.save(contract)
        if not result.was_intent_successful and is_updating:
            old = self.get_by_id(contract.id)
            result.data = old.data if old.was_intent_successful else None
            result.error_msg = "Failed to save the contract. Verify the info and retry."
            result.log_message_if_any()
        return result

    def toggle_complete_status(self, contract: Contract) -> IntentResult[Contract]:
        """Toggles the completed status of the contract."""
        return self.toggle_completed(contract)
