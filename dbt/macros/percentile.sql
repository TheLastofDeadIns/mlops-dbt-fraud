{#
    Перцентиль колонки через adapter.dispatch: в ClickHouse это параметрическая агрегатная функция quantileExact,
    в остальных базах стандартный percentile_cont.
#}
{% macro percentile(column_name, quantile) -%}
    {{ return(adapter.dispatch('percentile', 'fraud_analytics')(column_name, quantile)) }}
{%- endmacro %}

{% macro default__percentile(column_name, quantile) -%}
    percentile_cont({{ quantile }}) within group (order by {{ column_name }})
{%- endmacro %}

{% macro clickhouse__percentile(column_name, quantile) -%}
    quantileExact({{ quantile }})({{ column_name }})
{%- endmacro %}
