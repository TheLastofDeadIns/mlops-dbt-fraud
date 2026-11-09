{{
    config(
        order_by='(day_of_week, transaction_hour)'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

hourly as (

    select
        day_of_week,
        day_name,
        transaction_hour,
        day_part,
        count(*) as txn_count,
        sum(is_fraud) as fraud_txn_count,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount,
        round(avg(amount), 2) as avg_amount,
        round(avg(case when is_fraud = 1 then amount end), 2) as avg_fraud_amount
    from transactions
    group by
        day_of_week,
        day_name,
        transaction_hour,
        day_part

),

with_rates as (

    select
        *,
        {{ safe_pct('fraud_txn_count', 'txn_count') }} as fraud_rate,
        {{ safe_pct('sum(fraud_txn_count) over ()', 'sum(txn_count) over ()') }} as overall_fraud_rate
    from hourly

),

with_lift as (

    select
        *,
        round(
            case
                when overall_fraud_rate = 0 then 0
                else fraud_rate / overall_fraud_rate
            end,
            2
        ) as fraud_rate_lift
    from with_rates

)

select
    day_of_week,
    day_name,
    transaction_hour,
    day_part,
    txn_count,
    fraud_txn_count,
    fraud_rate,
    overall_fraud_rate,
    fraud_rate_lift,
    toUInt8(fraud_rate_lift >= {{ var('high_risk_window_lift') }}) as is_high_risk_window,
    fraud_amount,
    avg_amount,
    avg_fraud_amount,
    rank() over (order by fraud_rate desc) as fraud_rate_rank
from with_lift
