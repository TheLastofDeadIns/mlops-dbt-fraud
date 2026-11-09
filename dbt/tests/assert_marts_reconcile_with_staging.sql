-- каждая витрина покрывает все транзакции staging без потерь и задвоений
-- сверяются число транзакций, число фродов и сумма, для суммы допускается погрешность округления
{% set marts = [
    'mart_daily_state_metrics',
    'mart_fraud_by_category',
    'mart_fraud_by_state',
    'mart_customer_risk_profile',
    'mart_hourly_fraud_pattern',
    'mart_merchant_analytics'
] %}

with staging_totals as (

    select
        count(*) as txn_count,
        sum(is_fraud) as fraud_txn_count,
        sum(case when is_fraud = 1 then amount else 0 end) as fraud_amount
    from {{ ref('stg_transactions') }}

),

mart_totals as (

    {% for mart in marts %}
        select
            '{{ mart }}' as mart_name,
            sum(txn_count) as txn_count,
            sum(fraud_txn_count) as fraud_txn_count,
            sum(fraud_amount) as fraud_amount
        from {{ ref(mart) }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    mart_totals.mart_name,
    mart_totals.txn_count as mart_txn_count,
    staging_totals.txn_count as staging_txn_count,
    mart_totals.fraud_txn_count as mart_fraud_txn_count,
    staging_totals.fraud_txn_count as staging_fraud_txn_count,
    mart_totals.fraud_amount as mart_fraud_amount,
    staging_totals.fraud_amount as staging_fraud_amount
from mart_totals
cross join staging_totals
where
    mart_totals.txn_count != staging_totals.txn_count
    or mart_totals.fraud_txn_count != staging_totals.fraud_txn_count
    or abs(mart_totals.fraud_amount - staging_totals.fraud_amount) > 1
