select
    repayment_id,
    loan_id,
    amount_usd as repayment_amount_usd,
    cast(paid_at as date) as paid_at,
    is_overdue
from {{ ref('repayments') }}
