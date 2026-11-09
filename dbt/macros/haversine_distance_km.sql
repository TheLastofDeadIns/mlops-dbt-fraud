{#
    Расстояние по большому кругу между двумя точками в километрах (формула гаверсинусов).
    Нужны только sin, cos, asin, sqrt и radians, поэтому выражение одинаково работает в ClickHouse и других базах.
#}
{% macro haversine_distance_km(lat_1, lon_1, lat_2, lon_2) -%}
    2 * 6371 * asin(sqrt(
        pow(sin(radians(({{ lat_2 }} - {{ lat_1 }}) / 2)), 2)
        + cos(radians({{ lat_1 }})) * cos(radians({{ lat_2 }}))
        * pow(sin(radians(({{ lon_2 }} - {{ lon_1 }}) / 2)), 2)
    ))
{%- endmacro %}
