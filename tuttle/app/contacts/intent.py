from ..core.abstractions import CrudIntent
from ..core.intent_result import IntentResult
from ...model import Contact


class ContactsIntent(CrudIntent):
    """Contact CRUD with validation and referential integrity."""

    entity_type = Contact
    entity_name = "contact"

    def save_contact(self, contact: Contact) -> IntentResult:
        """Validate and save a contact."""
        if not contact.first_name or not contact.last_name:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Saving contact failed. A name is required.",
            )
        if contact.address.is_empty:
            return IntentResult(
                was_intent_successful=False,
                error_msg="Saving contact failed. Please specify the address.",
            )
        return self.save(contact)

    def delete_contact(self, contact_id) -> IntentResult:
        """Delete only if the contact is not an invoicing contact of any client."""
        result = self.get_by_id(contact_id)
        if not result.was_intent_successful:
            return result
        contact: Contact = result.data
        if len(contact.invoicing_contact_of) > 0:
            client_names = ", ".join(c.name for c in contact.invoicing_contact_of)
            return IntentResult(
                was_intent_successful=False,
                error_msg=f"Contact {contact.name} cannot be deleted because it is invoicing contact of clients: {client_names}",
            )
        return self.delete(contact_id)
