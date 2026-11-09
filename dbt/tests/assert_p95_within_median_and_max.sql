-- P95 суммы за день в штате не меньше медианы и не больше максимума
select
    transaction_date,
    us_state,
    median_amount,
    p95_amount,
    max_amount
from {{ ref('mart_daily_state_metrics') }}
where
    p95_amount < median_amount
    or p95_amount > max_amount
