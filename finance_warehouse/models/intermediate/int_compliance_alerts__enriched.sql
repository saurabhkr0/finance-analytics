with alerts as (

    select * from {{ ref('stg_finance__compliance_alerts') }}

),

customers as (

    select * from {{ ref('stg_finance__customers') }}

),

enriched as (

    select
        a.surrogate_alert_key,
        a.alert_id,
        a.alert_date,
        a.customer_id,
        a.alert_type,
        a.alert_status,
        a.alert_severity,
        c.client_segment,
        c.risk_rating,
        c.account_status as customer_account_status,
        case
            when a.alert_status not in ('Closed - SAR Filed', 'Closed - No Action')
                then datediff('day', a.alert_date, current_date)
        end as days_open,
        a.alert_status = 'Escalated' as is_escalated

    from alerts as a
    left join customers as c
        on a.customer_id = c.customer_id

)

select * from enriched
