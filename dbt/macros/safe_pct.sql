{#
    Доля numerator от denominator в процентах с округлением.
    При нулевом знаменателе возвращает 0, а не NULL или inf, чтобы колонки витрин оставались не Nullable.
#}
{% macro safe_pct(numerator, denominator, precision=4) -%}
    round(
        case
            when {{ denominator }} = 0 then 0
            else 100.0 * {{ numerator }} / {{ denominator }}
        end,
        {{ precision }}
    )
{%- endmacro %}
