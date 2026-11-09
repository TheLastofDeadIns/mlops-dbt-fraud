{#
    Сегментация суммы транзакции по корзинам.
    thresholds это возрастающий список из четырёх границ, по умолчанию берётся из var('amount_bucket_thresholds').
    Значение меньше первой границы попадает в micro, дальше small, medium, large, всё от последней границы это very_large.
#}
{% macro amount_bucket(column_name, thresholds=none) -%}
    {%- set bounds = thresholds if thresholds is not none else var('amount_bucket_thresholds', [10, 50, 200, 1000]) -%}
    {%- set labels = ['micro', 'small', 'medium', 'large'] -%}
    {%- if bounds | length != labels | length -%}
        {{ exceptions.raise_compiler_error('amount_bucket ждёт ' ~ labels | length ~ ' границы, получено ' ~ bounds | length) }}
    {%- endif -%}
    {%- if bounds != bounds | sort -%}
        {{ exceptions.raise_compiler_error('границы amount_bucket должны возрастать: ' ~ bounds) }}
    {%- endif -%}
    case
        {%- for upper_bound in bounds %}
        when {{ column_name }} < {{ upper_bound }} then '{{ labels[loop.index0] }}'
        {%- endfor %}
        else 'very_large'
    end
{%- endmacro %}
