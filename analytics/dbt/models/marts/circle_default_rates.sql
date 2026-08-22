-- Headline portfolio-quality metric: default rate by circle type (Area/Nation/Relative/Religion).
-- This is the metric that most directly demonstrates whether the guaranty
-- system in the CMST white paper is actually working in practice.
select
    circle_type,
    count(*) as total_loans,
    sum(is_default) as defaulted_loans,
    round(100.0 * sum(is_default) / nullif(count(*), 0), 2) as default_rate_pct,
    round(avg(amount_usd), 2) as avg_loan_amount_usd
from {{ ref('fact_loan') }}
group by circle_type
order by default_rate_pct desc
