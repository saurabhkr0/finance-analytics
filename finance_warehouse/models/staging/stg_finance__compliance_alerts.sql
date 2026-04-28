{{ config(materialized='view') }}

with source as (

    select * from {{ source('finance_raw', 'COMPLIANCE_ALERTS') }}

),

customers as (

    select distinct customer_id
    from {{ source('finance_raw', 'CUSTOMERS') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'source.alert_id',
            'source.alert_date',
            'source.customer_id',
            'source.alert_type',
            'source.status',
            'source.severity'
        ]) }} as surrogate_alert_key,
        source.alert_id,
        source.alert_date::date as alert_date,
        source.customer_id,
        trim(source.alert_type) as alert_type,
        trim(source.status) as alert_status,
        trim(source.severity) as alert_severity,
        case when customers.customer_id is null then true else false end as is_orphan_customer

    from source
    left join customers
        on source.customer_id = customers.customer_id

)

select * from renamed
