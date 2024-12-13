-- ingest_semi_structured_into_landing_sql

{% macro ingest_semi_structured_into_landing_sql(full_table_name, field_definitions, file_pattern, full_stage_name, full_format_name) %}
BEGIN TRANSACTION;

COPY INTO {{ full_table_name }}
FROM (
    SELECT 
        {{ field_definitions }}, 
        
        METADATA$FILENAME               as FROM_FILE,
        METADATA$FILE_ROW_NUMBER        as FILE_ROW_NUMBER,
        METADATA$FILE_LAST_MODIFIED     as FILE_LAST_MODIFIED_TS_UTC, 
        '{{ run_started_at }}'          as INGESTION_TS_UTC

    FROM @{{ full_stage_name }}/
)
PATTERN = '{{ file_pattern }}'
{%- if full_format_name %}
, FILE_FORMAT = (FORMAT_NAME = '{{ full_format_name }}')
{%- endif %}
;

COMMIT;

{%- endmacro %}