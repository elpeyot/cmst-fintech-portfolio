select
    r.repayment_id,
    r.loan_id,
    l.circle_id,
    l.circle_type,
    r.repayment_amount_usd,
    r.paid_at,
    r.is_overdue
from {{ ref('stg_repayments') }} r
left join {{ ref('fact_loan') }} l on r.loan_id = l.loan_id
