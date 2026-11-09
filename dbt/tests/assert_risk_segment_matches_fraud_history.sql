-- сегмент риска согласован с историей клиента: LOW только без фрода, HIGH и MEDIUM только с фродом,
-- HIGH только при fraud_rate не ниже порога
select
    customer_id,
    risk_segment,
    fraud_txn_count,
    fraud_rate
from {{ ref('mart_customer_risk_profile') }}
where
    (risk_segment = 'LOW' and fraud_txn_count > 0)
    or (risk_segment in ('HIGH', 'MEDIUM') and fraud_txn_count = 0)
    or (risk_segment = 'HIGH' and fraud_rate < {{ var('high_risk_fraud_rate_pct') }})
    or (risk_segment = 'MEDIUM' and fraud_rate >= {{ var('high_risk_fraud_rate_pct') }})
