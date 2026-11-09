{{
    config(
        order_by='customer_id'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

customers as (

    select
        customer_id,
        first_name,
        last_name,
        gender,
        us_state,
        min(transaction_time) as first_txn_at,
        max(transaction_time) as last_txn_at,
        count(*) as txn_count,
        count(distinct transaction_date) as active_days,
        count(distinct category) as unique_categories,
        count(distinct merchant_name) as unique_merchants,
        round(sum(amount), 2) as total_amount,
        round(avg(amount), 2) as avg_amount,
        max(amount) as max_amount,
        sum(is_large_amount) as large_txn_count,
        sum(case when day_part = 'night' then 1 else 0 end) as night_txn_count,
        sum(is_fraud) as fraud_txn_count,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount,
        max(case when is_fraud = 1 then transaction_time end) as last_fraud_at
    from transactions
    group by
        customer_id,
        first_name,
        last_name,
        gender,
        us_state

),

scored as (

    select
        *,
        {{ safe_pct('fraud_txn_count', 'txn_count') }} as fraud_rate,
        {{ safe_pct('night_txn_count', 'txn_count') }} as night_txn_share_pct,
        {{ safe_pct('large_txn_count', 'txn_count') }} as large_txn_share_pct
    from customers

)

select
    customer_id,
    concat(first_name, ' ', last_name) as customer_name,
    gender,
    us_state,
    first_txn_at,
    last_txn_at,
    dateDiff('day', first_txn_at, last_txn_at) as customer_lifetime_days,
    active_days,
    txn_count,
    unique_categories,
    unique_merchants,
    total_amount,
    avg_amount,
    max_amount,
    large_txn_share_pct,
    night_txn_share_pct,
    fraud_txn_count,
    fraud_amount,
    fraud_rate,
    last_fraud_at,
    case
        when fraud_rate >= {{ var('high_risk_fraud_rate_pct') }} then 'HIGH'
        when fraud_txn_count > 0 then 'MEDIUM'
        else 'LOW'
    end as risk_segment
from scored
