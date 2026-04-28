with transactions as (

    select * from {{ ref('stg_finance__transactions') }}

),

daily_summary as (

    select
        transaction_date,
        business_line,
        branch_city,
        count(*) as transaction_count,
        sum(
            case
                when transaction_type in ('Deposit', 'Interest', 'Dividend')
                    then transaction_amount
                else 0
            end
        ) as total_credit_amount,
        sum(
            case
                when transaction_type in ('Withdrawal', 'Fee', 'ATM')
                    then transaction_amount
                else 0
            end
        ) as total_debit_amount,
        sum(
            case
                when transaction_type in ('Deposit', 'Interest', 'Dividend')
                    then transaction_amount
                when transaction_type in ('Withdrawal', 'Fee', 'ATM')
                    then -1 * transaction_amount
                else 0
            end
        ) as net_flow,
        avg(transaction_amount) as average_transaction_amount

    from transactions
    group by 1, 2, 3

)

select * from daily_summary
