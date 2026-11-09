"""Заглушки dbt для sqlfluff с jinja-шаблонизатором.

Линтер работает без подключения к ClickHouse, поэтому dbt-контекст подменяется здесь:
var() отдаёт настоящие значения из dbt_project.yml, adapter.dispatch и exceptions нужны макросам проекта,
а пакетные макросы dbt_utils и dbt_date лежат в соседних модулях и рендерятся в простые SQL-выражения.
Нарушения в сгенерированном шаблоном коде sqlfluff не показывает, проверяется только написанный руками SQL.
"""

from pathlib import Path

import yaml

_PROJECT_FILE = Path(__file__).resolve().parents[1] / "dbt_project.yml"
_VARS = yaml.safe_load(_PROJECT_FILE.read_text(encoding="utf-8")).get("vars", {})


def var(name, default=None):
    return _VARS.get(name, default)


class _Adapter:
    def dispatch(self, macro_name, macro_namespace=None):
        return lambda *args, **kwargs: f"{macro_name}({', '.join(str(arg) for arg in args)})"


class _Exceptions:
    @staticmethod
    def raise_compiler_error(message):
        raise ValueError(message)


adapter = _Adapter()
exceptions = _Exceptions()
