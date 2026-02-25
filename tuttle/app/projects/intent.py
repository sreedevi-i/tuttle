from typing import Optional

import datetime

from ..clients.intent import ClientsIntent
from ..contracts.intent import ContractsIntent
from ..core.intent_result import IntentResult
from ..core.abstractions import CrudIntent

from ...model import Contract, Project


class ProjectsIntent(CrudIntent):
    """Handles intents related to the projects data UI."""

    entity_type = Project

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

    def save_project(
        self,
        title: str,
        description: str,
        unique_tag: str,
        start_date: datetime.date,
        end_date: datetime.date,
        is_completed: bool = False,
        contract: Optional[Contract] = None,
        project: Optional[Project] = None,
    ) -> IntentResult[Optional[Project]]:
        """Create a new project, or update if a project is provided."""
        is_updating = project is not None
        if not project:
            project = Project()
        project.title = title
        project.description = description
        project.tag = unique_tag
        project.start_date = start_date
        project.end_date = end_date
        project.is_completed = is_completed
        project.contract = contract
        result = self.save(project)
        if not result.was_intent_successful:
            if is_updating:
                old = self.get_by_id(project.id)
                result.data = old.data if old.was_intent_successful else None
            result.error_msg = "Failed to save the project."
            result.log_message_if_any()
        return result

    def toggle_project_completed_status(
        self, project: Project
    ) -> IntentResult[Project]:
        """Updates the project completed status."""
        return self.toggle_completed(project)
