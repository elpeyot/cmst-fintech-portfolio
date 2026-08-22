select
    loan_id,
    user_id,
    circle_id,
    amount_usd,
    term_months,
    status,
    cast(created_at as date) as created_at
from {{ ref('loans') }}
