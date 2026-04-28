{{
    config(
        materialized='table',
        cluster_by=['risk_rating', 'client_segment']
    )
}}

with customers as (

    select * from {{ ref('stg_finance__customers') }}

),

transactions as (

    select * from {{ ref('stg_finance__transactions') }}

),

alerts as (

    select * from {{ ref('stg_finance__compliance_alerts') }}
    where is_orphan_customer = false

),

transaction_summary as (

    select
        customer_id,
        count(*) as total_transactions,
        sum(transaction_amount) as total_transaction_amount,
        avg(transaction_amount) as avg_transaction_amount,
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,
        count(distinct account_type) as distinct_account_types,
        count(distinct currency) as distinct_currencies,
        sum(case when is_negative_amount then 1 else 0 end) as negative_amount_count,
        sum(case when transaction_type in ('Deposit', 'Interest', 'Dividend') then transaction_amount else 0 end) as total_credits,
        sum(case when transaction_type in ('Withdrawal', 'Fee', 'ATM') then transaction_amount else 0 end) as total_debits

    from transactions
    group by 1

),

alert_summary as (

    select
        customer_id,
        count(*) as total_alerts,
        sum(case when alert_severity = 'Critical' then 1 else 0 end) as critical_alert_count,
        sum(case when alert_severity = 'High' then 1 else 0 end) as high_alert_count,
        sum(case when alert_status = 'Escalated' then 1 else 0 end) as escalated_alert_count,
        sum(case when alert_status in ('Closed - SAR Filed') then 1 else 0 end) as sar_filed_count,
        count(distinct alert_type) as distinct_alert_types,
        min(alert_date) as first_alert_date,
        max(alert_date) as last_alert_date

    from alerts
    group by 1

),

joined as (

    select
        {{ dbt_utils.generate_surrogate_key(['c.customer_id']) }} as surrogate_customer_risk_key,
        c.customer_id,
        c.risk_rating,
        c.account_status,
        c.onboarding_date,
        c.total_assets_under_management,
        c.client_segment,

        -- transaction metrics
        coalesce(t.total_transactions, 0) as total_transactions,
        coalesce(t.total_transaction_amount, 0)::decimal(18, 2) as total_transaction_amount,
        t.avg_transaction_amount::decimal(18, 2) as avg_transaction_amount,
        t.first_transaction_date,
        t.last_transaction_date,
        coalesce(t.distinct_account_types, 0) as distinct_account_types,
        coalesce(t.distinct_currencies, 0) as distinct_currencies,
        coalesce(t.negative_amount_count, 0) as negative_amount_count,
        coalesce(t.total_credits, 0)::decimal(18, 2) as total_credits,
        coalesce(t.total_debits, 0)::decimal(18, 2) as total_debits,

        -- alert metrics
        coalesce(a.total_alerts, 0) as total_alerts,
        coalesce(a.critical_alert_count, 0) as critical_alert_count,
        coalesce(a.high_alert_count, 0) as high_alert_count,
        coalesce(a.escalated_alert_count, 0) as escalated_alert_count,
        coalesce(a.sar_filed_count, 0) as sar_filed_count,
        coalesce(a.distinct_alert_types, 0) as distinct_alert_types,
        a.first_alert_date,
        a.last_alert_date,

        -- derived risk category
        case
            when a.sar_filed_count > 0 or a.critical_alert_count >= 3 then 'Critical'
            when c.risk_rating = 'High' and coalesce(a.total_alerts, 0) > 0 then 'High'
            when coalesce(a.total_alerts, 0) >= 5 or a.escalated_alert_count >= 2 then 'High'
            when c.risk_rating = 'High' or coalesce(a.total_alerts, 0) >= 2 then 'Medium'
            when coalesce(a.total_alerts, 0) >= 1 then 'Low'
            else 'Minimal'
        end as derived_risk_category

    from customers as c
    left join transaction_summary as t
        on c.customer_id = t.customer_id
    left join alert_summary as a
        on c.customer_id = a.customer_id

)

select * from joined
