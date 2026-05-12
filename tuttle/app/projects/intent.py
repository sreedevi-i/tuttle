from typing import Optional

from ..clients.intent import ClientsIntent
from ..contracts.intent import ContractsIntent
from ..core.intent_result import IntentResult
from ..core.abstractions import CrudIntent

from ...model import Project


class ProjectsIntent(CrudIntent):
    """Handles intents related to the projects data UI."""

    entity_type = Project
    deletion_guards = [
        ("invoices", "invoices", lambda i: i.number or f"#{i.id}"),
        ("timesheets", "timesheets", lambda t: t.title),
    ]
    __save_skip__ = {"contract", "timesheets", "invoices"}

    def __init__(self):
        super().__init__()
        self._clients_intent = ClientsIntent()
        self._contracts_intent = ContractsIntent()

    # -- Cross-entity delegates ------------------------------------------------

    def get_all_clients_as_map(self):
        return self._clients_intent.get_all_as_map()

    def get_all_contracts_as_map(self):
        return self._contracts_intent.get_all_as_map()

    # -- Project-specific logic ------------------------------------------------

    def _validated_save(self, project: Project) -> IntentResult[Optional[Project]]:
        is_updating = project.id is not None
        result = self.save(project)
        if not result.was_intent_successful:
            if is_updating:
                old = self.get_by_id(project.id)
                result.data = old.data if old.was_intent_successful else None
            result.error_msg = "Failed to save the project."
            result.log_message_if_any()
        return result

    toggle_project_completed_status = CrudIntent.toggle_completed
