{{
    config(
        order_by='(transaction_date, us_state, transaction_time)'
    )
}}

with source as (

    select * from {{ source('transactions_db', 'transactions') }}

),

renamed as (

    -- сырые колонки получают префикс raw_, чтобы алиасы ниже не совпадали с именами исходных колонок
    select
        transaction_time as raw_transaction_time,
        merch as raw_merchant,
        cat_id as raw_category,
        amount as raw_amount,
        name_1 as raw_first_name,
        name_2 as raw_last_name,
        gender as raw_gender,
        us_state as raw_state,
        lat as raw_customer_lat,
        lon as raw_customer_lon,
        merchant_lat as raw_merchant_lat,
        merchant_lon as raw_merchant_lon,
        target as raw_target
    from source

),

cleaned as (

    select
        toDateTime(raw_transaction_time) as transaction_time,
        replaceRegexpOne(trimBoth(raw_merchant), '^fraud_', '') as merchant_name,
        lower(trimBoth(raw_category)) as category,
        round(toFloat64(raw_amount), 2) as amount,
        trimBoth(raw_first_name) as first_name,
        trimBoth(raw_last_name) as last_name,
        upper(trimBoth(raw_gender)) as gender,
        upper(trimBoth(raw_state)) as us_state,
        toFloat64(raw_customer_lat) as customer_lat,
        toFloat64(raw_customer_lon) as customer_lon,
        toFloat64(raw_merchant_lat) as merchant_lat,
        toFloat64(raw_merchant_lon) as merchant_lon,
        toUInt8(raw_target) as is_fraud
    from renamed

),

keyed as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'transaction_time', 'merchant_name', 'amount',
            'first_name', 'last_name', 'customer_lat', 'customer_lon'
        ]) }} as transaction_id,
        -- в данных нет номера карты, клиента однозначно задают имя, пол и координаты домашнего адреса
        {{ dbt_utils.generate_surrogate_key([
            'first_name', 'last_name', 'gender', 'customer_lat', 'customer_lon'
        ]) }} as customer_id,
        *
    from cleaned

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by transaction_id
            order by transaction_time
        ) as duplicate_rank
    from keyed

),

enriched as (

    select
        transaction_id,
        customer_id,
        transaction_time,
        toDate(transaction_time) as transaction_date,
        toUInt8({{ dbt_date.date_part('hour', 'transaction_time') }}) as transaction_hour,
        toUInt8({{ dbt_date.day_of_week('transaction_time', isoweek=true) }}) as day_of_week,
        {{ dbt_date.day_name('transaction_time', short=false) }} as day_name,
        merchant_name,
        category,
        amount,
        {{ amount_bucket('amount') }} as amount_bucket,
        toUInt8(amount >= {{ var('large_amount_threshold') }}) as is_large_amount,
        first_name,
        last_name,
        gender,
        us_state,
        customer_lat,
        customer_lon,
        merchant_lat,
        merchant_lon,
        round(
            {{ haversine_distance_km('customer_lat', 'customer_lon', 'merchant_lat', 'merchant_lon') }},
            2
        ) as customer_merchant_distance_km,
        is_fraud
    from deduplicated
    where duplicate_rank = 1

)

select
    transaction_id,
    customer_id,
    transaction_time,
    transaction_date,
    transaction_hour,
    day_of_week,
    day_name,
    toUInt8(day_of_week in (6, 7)) as is_weekend,
    case
        when transaction_hour < 6 then 'night'
        when transaction_hour < 12 then 'morning'
        when transaction_hour < 18 then 'afternoon'
        when transaction_hour < 22 then 'evening'
        else 'night'
    end as day_part,
    merchant_name,
    category,
    amount,
    amount_bucket,
    is_large_amount,
    first_name,
    last_name,
    gender,
    us_state,
    customer_lat,
    customer_lon,
    merchant_lat,
    merchant_lon,
    customer_merchant_distance_km,
    is_fraud
from enriched
