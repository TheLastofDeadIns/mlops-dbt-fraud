{{
    config(
        order_by='(transaction_date, us_state)'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

daily as (

    select
        transaction_date,
        us_state,
        state_name,
        region,
        count(*) as txn_count,
        count(distinct customer_id) as unique_customers,
        round(sum(amount), 2) as total_amount,
        round(avg(amount), 2) as avg_amount,
        round({{ percentile('amount', 0.5) }}, 2) as median_amount,
        round({{ percentile('amount', 0.95) }}, 2) as p95_amount,
        max(amount) as max_amount,
        sum(is_large_amount) as large_txn_count,
        sum(is_fraud) as fraud_txn_count,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount
    from transactions
    group by
        transaction_date,
        us_state,
        state_name,
        region

)

select
    transaction_date,
    us_state,
    state_name,
    region,
    txn_count,
    unique_customers,
    total_amount,
    avg_amount,
    median_amount,
    p95_amount,
    max_amount,
    large_txn_count,
    {{ safe_pct('large_txn_count', 'txn_count') }} as large_txn_share_pct,
    fraud_txn_count,
    {{ safe_pct('fraud_txn_count', 'txn_count') }} as fraud_rate,
    fraud_amount
from daily
