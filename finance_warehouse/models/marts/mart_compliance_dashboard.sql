{{
    config(
        materialized='table'
    )
}}

with enriched_alerts as (

    select * from {{ ref('int_compliance_alerts__enriched') }}

),

final as (

    select
        surrogate_alert_key,
        alert_id,
        alert_date,
        customer_id,
        alert_type,
        alert_status,
        alert_severity,
        client_segment,
        risk_rating,
        customer_account_status,
        days_open,
        is_escalated,
        avg(is_escalated::int) over (
            partition by alert_severity
        ) as escalation_rate_by_severity,
        count(*) over (
            partition by client_segment
            order by alert_date
            range between interval '29 days' preceding and current row
        ) as rolling_30d_alerts_by_segment

    from enriched_alerts

)

select * from final
