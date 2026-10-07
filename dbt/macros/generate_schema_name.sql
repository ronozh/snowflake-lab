{# Use the configured schema (SILVER, GOLD) as-is. Environments are separate databases,
   so dbt's default <target>_<schema> prefixing is not needed. #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ (custom_schema_name or target.schema) | trim | upper }}
{%- endmacro %}
