from ..core.abstractions import CrudIntent
from ..core.intent_result import IntentResult
from ...model import Address, Contact


class ContactsIntent(CrudIntent):
    """Contact CRUD with validation and referential integrity."""

    entity_type = Contact
    entity_name = "contact"
    deletion_guards = [
        ("invoicing_contact_of", "clients", lambda c: c.name),
    ]
    __save_nested__ = {"address": Address}
    __save_skip__ = {"invoicing_contact_of"}

    def _validated_save(self, contact: Contact) -> IntentResult:
        if not contact.first_name or not contact.last_name:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Saving contact failed. A name is required.",
            )
        if contact.address and contact.address.is_empty:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Saving contact failed. Please specify the address.",
            )
        return self.save(contact)
