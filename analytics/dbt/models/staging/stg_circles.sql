select
    circle_id,
    circle_type,
    monthly_rate_pct
from {{ ref('circles') }}
