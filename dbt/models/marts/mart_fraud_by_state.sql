{{
    config(
        order_by='us_state'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

by_state as (

    select
        us_state,
        state_name,
        region,
        division,
        count(*) as txn_count,
        sum(is_fraud) as fraud_txn_count,
        count(distinct customer_id) as unique_customers,
        count(distinct merchant_name) as unique_merchants,
        count(distinct case when is_fraud = 1 then customer_id end) as fraud_customers,
        count(distinct case when is_fraud = 1 then merchant_name end) as fraud_merchants,
        round(sum(amount), 2) as total_amount,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount,
        round(avg(amount), 2) as avg_amount
    from transactions
    group by
        us_state,
        state_name,
        region,
        division

)

select
    us_state,
    state_name,
    region,
    division,
    txn_count,
    fraud_txn_count,
    {{ safe_pct('fraud_txn_count', 'txn_count') }} as fraud_rate,
    unique_customers,
    unique_merchants,
    fraud_customers,
    {{ safe_pct('fraud_customers', 'unique_customers') }} as fraud_customer_share_pct,
    fraud_merchants,
    total_amount,
    fraud_amount,
    {{ safe_pct('fraud_amount', 'total_amount') }} as fraud_amount_share_pct,
    avg_amount,
    rank() over (order by fraud_txn_count / txn_count desc) as fraud_rate_rank
from by_state
