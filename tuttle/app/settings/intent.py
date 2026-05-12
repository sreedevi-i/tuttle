"""App-level key/value settings backed by AppDatabase."""

from ..core.intent_result import IntentResult
from ...app_db import AppDatabase


class SettingsIntent:
    def __init__(self):
        self._app_db = AppDatabase()

    def get(self, key: str) -> IntentResult:
        return IntentResult(
            was_intent_successful=True,
            data=self._app_db.get_setting(key),
        )

    def set(self, key: str, value: str) -> IntentResult:
        self._app_db.set_setting(key, value)
        return IntentResult(was_intent_successful=True, data=None)

    def get_all(self, prefix: str = None) -> IntentResult:
        return IntentResult(
            was_intent_successful=True,
            data=self._app_db.get_all_settings(prefix=prefix),
        )
