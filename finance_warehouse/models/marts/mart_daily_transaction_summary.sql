{{
    config(
        materialized='table',
        cluster_by=['transaction_date']
    )
}}

with daily_summary as (

    select * from {{ ref('int_transactions__daily_summary') }}

)

select
    transaction_date,
    business_line,
    branch_city,
    transaction_count,
    total_credit_amount,
    total_debit_amount,
    net_flow,
    average_transaction_amount

from daily_summary
