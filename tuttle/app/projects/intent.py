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
            result.error_msg = self._describe_save_error(result.exception)
            result.log_message_if_any()
        return result

    @staticmethod
    def _describe_save_error(exc: Optional[Exception]) -> str:
        if exc is None:
            return "Failed to save the project."
        detail = str(getattr(exc, "orig", exc))
        if "UNIQUE" in detail or "duplicate" in detail.lower():
            if "title" in detail:
                return "A project with this title already exists."
            if "tag" in detail:
                return "A project with this tag already exists."
            return "A project with these details already exists."
        if "NOT NULL" in detail:
            return "A required field is missing."
        if "FOREIGN KEY" in detail or "foreign key" in detail:
            return "The selected contract is invalid."
        return "Failed to save the project."

    toggle_project_completed_status = CrudIntent.toggle_completed
