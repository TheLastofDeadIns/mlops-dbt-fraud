"""Заглушки макросов dbt_date для sqlfluff."""


def date_part(datepart, date):
    return f"extract({datepart} from {date})"


def day_of_week(date, isoweek=True):
    return f"toDayOfWeek({date})"


def day_name(date, short=True, language="default"):
    return f"dateName('weekday', {date})"
