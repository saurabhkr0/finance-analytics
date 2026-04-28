{{ config(materialized='view') }}

with source as (

    select * from {{ source('finance_raw', 'CUSTOMERS') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as surrogate_customer_key,
        customer_id::number(10, 0) as customer_id,
        trim(risk_rating) as risk_rating,
        trim(account_status) as account_status,
        onboarding_date::date as onboarding_date,
        total_aum::decimal(18, 2) as total_assets_under_management,
        trim(client_segment) as client_segment

    from source

)

select * from renamed
