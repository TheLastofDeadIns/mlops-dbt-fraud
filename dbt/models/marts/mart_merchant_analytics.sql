{{
    config(
        order_by='merchant_name'
    )
}}

with transactions as (

    select * from {{ ref('int_transactions_enriched') }}

),

merchant_categories as (

    select
        merchant_name,
        category,
        count(*) as category_txn_count
    from transactions
    group by
        merchant_name,
        category

),

main_categories as (

    -- у части мерчантов встречаются две категории, основной считается самая частая
    select
        merchant_name,
        argMax(category, category_txn_count) as main_category,
        count(*) as category_count
    from merchant_categories
    group by merchant_name

),

merchant_stats as (

    select
        merchant_name,
        count(*) as txn_count,
        round(sum(amount), 2) as turnover,
        round(avg(amount), 2) as avg_amount,
        count(distinct customer_id) as unique_customers,
        count(distinct us_state) as unique_customer_states,
        sum(is_fraud) as fraud_txn_count,
        round(sum(case when is_fraud = 1 then amount else 0 end), 2) as fraud_amount,
        min(transaction_date) as first_txn_date,
        max(transaction_date) as last_txn_date
    from transactions
    group by merchant_name

),

with_rates as (

    select
        merchant_stats.merchant_name,
        main_categories.main_category,
        main_categories.category_count,
        merchant_stats.txn_count,
        merchant_stats.turnover,
        merchant_stats.avg_amount,
        merchant_stats.unique_customers,
        merchant_stats.unique_customer_states,
        merchant_stats.fraud_txn_count,
        merchant_stats.fraud_amount,
        merchant_stats.first_txn_date,
        merchant_stats.last_txn_date,
        {{ safe_pct('merchant_stats.fraud_txn_count', 'merchant_stats.txn_count') }} as fraud_rate,
        {{ safe_pct('sum(merchant_stats.fraud_txn_count) over ()', 'sum(merchant_stats.txn_count) over ()') }}
            as overall_fraud_rate
    from merchant_stats
    inner join main_categories
        on merchant_stats.merchant_name = main_categories.merchant_name

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
    merchant_name,
    main_category,
    category_count,
    txn_count,
    turnover,
    avg_amount,
    unique_customers,
    unique_customer_states,
    fraud_txn_count,
    fraud_amount,
    fraud_rate,
    overall_fraud_rate,
    fraud_rate_lift,
    toUInt8(
        fraud_rate_lift >= {{ var('suspicious_merchant_lift') }}
        and fraud_txn_count >= {{ var('suspicious_merchant_min_fraud_txn') }}
    ) as is_suspicious,
    first_txn_date,
    last_txn_date,
    rank() over (order by turnover desc) as turnover_rank
from with_lift
