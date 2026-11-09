with transactions as (

    select * from {{ ref('stg_transactions') }}

),

states as (

    select * from {{ ref('states') }}

)

select
    transactions.transaction_id,
    transactions.customer_id,
    transactions.transaction_time,
    transactions.transaction_date,
    transactions.transaction_hour,
    transactions.day_of_week,
    transactions.day_name,
    transactions.is_weekend,
    transactions.day_part,
    transactions.merchant_name,
    transactions.category,
    transactions.amount,
    transactions.amount_bucket,
    transactions.is_large_amount,
    transactions.first_name,
    transactions.last_name,
    transactions.gender,
    transactions.us_state,
    states.state_name,
    states.region,
    states.division,
    transactions.customer_merchant_distance_km,
    transactions.is_fraud
from transactions
left join states
    on transactions.us_state = states.state_code
