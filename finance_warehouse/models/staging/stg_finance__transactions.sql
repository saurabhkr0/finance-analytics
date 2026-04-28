{{ config(materialized='view') }}

with source as (

    select * from {{ source('finance_raw', 'TRANSACTIONS') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'transaction_id',
            'transaction_date',
            'customer_id',
            'transaction_type',
            'amount'
        ]) }} as surrogate_transaction_key,
        transaction_id,
        transaction_date::date as transaction_date,
        customer_id,
        trim(account_type) as account_type,
        trim(transaction_type) as transaction_type,
        amount::decimal(18, 2) as transaction_amount,
        case when amount < 0 then true else false end as is_negative_amount,
        trim(currency) as currency,
        trim(branch_city) as branch_city,
        trim(business_line) as business_line

    from source

)

select * from renamed
