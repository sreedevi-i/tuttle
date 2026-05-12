"""Database lifecycle — ensure, existence check."""

from ..core.intent_result import IntentResult
from ..core.abstractions import get_active_db
from ..users.intent import UsersIntent


class DbIntent:
    def ensure(self) -> IntentResult:
        return UsersIntent().ensure_db()

    def exists(self) -> IntentResult:
        return IntentResult(
            was_intent_successful=True,
            data=get_active_db().exists(),
        )
