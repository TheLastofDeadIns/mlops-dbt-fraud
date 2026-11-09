"""Заглушки макросов dbt_utils для sqlfluff."""


def generate_surrogate_key(field_list):
    return f"md5(concat({', '.join(field_list)}))"
