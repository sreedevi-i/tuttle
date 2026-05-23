from ..contacts.intent import ContactsIntent
from ..core.abstractions import CrudIntent
from ..core.intent_result import IntentResult
from ...model import Address, Client


class ClientsIntent(CrudIntent):
    """Client CRUD with validation."""

    entity_type = Client
    entity_name = "client"
    deletion_guards = [
        ("contracts", "contracts", lambda c: c.title),
    ]
    __save_nested__ = {"address": Address}
    __save_skip__ = {"contracts"}

    def __init__(self):
        super().__init__()
        self._contacts_intent = ContactsIntent()

    def get_all_contacts_as_map(self):
        """Delegate to ContactsIntent for cross-entity lookup."""
        return self._contacts_intent.get_all_as_map()

    def _validated_save(self, client: Client) -> IntentResult:
        if not client.name:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Please provide the client's name",
            )
        if client.address and client.address.is_empty:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Saving client failed. Please specify the address.",
            )
        is_updating = client.id is not None
        result = self.save(client)
        if not result.was_intent_successful:
            if is_updating:
                old = self.get_by_id(client.id)
                result.data = old.data if old.was_intent_successful else None
            result.error_msg = self._describe_save_error(result.exception)
            result.log_message_if_any()
        return result

    @staticmethod
    def _describe_save_error(exc) -> str:
        if exc is None:
            return "Failed to save the client."
        detail = str(getattr(exc, "orig", exc))
        if "UNIQUE" in detail or "duplicate" in detail.lower():
            if "name" in detail:
                return "A client with this name already exists."
            return "A client with these details already exists."
        if "NOT NULL" in detail:
            return "A required field is missing."
        return "Failed to save the client."
