{{
    config(
        order_by='category'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

by_category as (

    select
        category,
        count(*) as txn_count,
        sum(is_fraud) as fraud_txn_count,
        round(sum(amount), 2) as total_amount,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount,
        round(avg(amount), 2) as avg_amount,
        round(avg(case when is_fraud = 1 then amount end), 2) as avg_fraud_amount
    from transactions
    group by category

)

select
    category,
    txn_count,
    fraud_txn_count,
    txn_count - fraud_txn_count as legit_txn_count,
    {{ safe_pct('fraud_txn_count', 'txn_count') }} as fraud_rate,
    total_amount,
    fraud_amount,
    round(total_amount - fraud_amount, 2) as legit_amount,
    {{ safe_pct('fraud_amount', 'total_amount') }} as fraud_amount_share_pct,
    avg_amount,
    avg_fraud_amount,
    {{ safe_pct('fraud_txn_count', 'sum(fraud_txn_count) over ()') }} as share_of_all_fraud_pct,
    rank() over (order by fraud_txn_count / txn_count desc) as fraud_rate_rank
from by_category
