select
    l.loan_id,
    l.user_id,
    l.circle_id,
    c.circle_type,
    c.monthly_rate_pct,
    l.amount_usd,
    l.term_months,
    l.status,
    l.created_at,
    case when l.status = 'defaulted' then 1 else 0 end as is_default
from {{ ref('stg_loans') }} l
left join {{ ref('stg_circles') }} c on l.circle_id = c.circle_id
