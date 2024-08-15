{%- macro stage( 
    source,
    calculated_columns = none,
    hashed_columns = none,
    default_records = none,
    remove_duplicates = none
) -%}

{%- if execute and not source.model %}
    {{ exceptions.raise_compiler_error('No source model provided.') }}
{% endif %}

WITH
src_data as (
    SELECT 
    {%- if source.columns.include_all %} *
        {% if source.columns.exclude_columns %} EXCLUDE (
            {%- for col in source.columns.exclude_columns -%}
               {{col}}{% if not loop.last %}, {% endif -%}
            {%- endfor -%}
        )
        {%- endif %}
        {% if source.columns.replace_columns %} REPLACE (
            {{- column_expressions(source.columns.replace_columns)}}
        )
        {%- endif %}
        {% if source.columns.rename_columns %} RENAME (
            {{- column_expressions(source.columns.rename_columns)}}
        )
        {%- endif %}
    {%- endif %}

    {%- if source.columns.include_all and calculated_columns %},{% endif %}
    {{- column_expressions(calculated_columns)}}

    FROM {{ source.model }}
    WHERE {{ source['where'] or 'true' }}   
)

{%- if default_records %}
, default_record_inputs as (
    {%- for default_record in default_records -%}
        {%- for default_record_name, columns in default_record.items() %}
    SELECT '{{default_record_name}}' as default_record_name, 
    {{- column_expressions(columns)}}
        {%- endfor %}
    {% if not loop.last %}UNION ALL {% endif -%}
    {%- endfor -%}
)
, default_records as (
    SELECT r.*
        REPLACE(
    {%- for default_record_name, column_dicts in default_records[0].items() %}
        {%- for column_dict in column_dicts %}
            {%- for column_name, sql_expression in column_dict.items() %}
            d.{{column_name}} as {{column_name}}
            {%- endfor -%}{%- if not loop.last %}, {% endif %}
        {%- endfor -%}
    {%- endfor -%}
      )
    FROM default_record_inputs as d
    LEFT OUTER JOIN (SELECT * FROM src_data WHERE false) as r
        ON(d.default_record_name = r.$1)
) 
, with_default_record as(
    SELECT * FROM src_data
    UNION ALL
    SELECT * FROM default_records
)
    {% else %}
, with_default_record as(
    SELECT * FROM src_data
)
{% endif %}

, hashed as (
    SELECT *,
    {%- for hash_name, definition in hashed_columns.items() %}
        {%- if definition is mapping and definition.is_hashdiff %}
            {{ pdp_hash(definition['columns']) }} as {{ hash_name }}
        {%- else %}
            {{ pdp_hash(definition) }} as {{ hash_name }}
        {%- endif %}
        {%- if not loop.last %}, {% endif %}
    {%- endfor %}
    FROM with_default_record
)

SELECT * FROM hashed
{%- if remove_duplicates %}
{% set qualify_function = remove_duplicates['qualify_function'] if remove_duplicates['qualify_function'] else 'row_number()' %}
{% set qualify_value = remove_duplicates['qualify_value'] if remove_duplicates['qualify_value'] else '1' %}
QUALIFY {{qualify_function}} OVER( 
        PARTITION BY {%- for c in remove_duplicates['partition_by'] %} {{c}}{%- if not loop.last %}, {% endif %}{% endfor %}
        ORDER BY{%- for c in remove_duplicates['order_by'] %} {{c}}{%- if not loop.last %}, {% endif %}{% endfor %}
    ) = {{qualify_value}}
{%- endif -%}
    
{%- endmacro %}