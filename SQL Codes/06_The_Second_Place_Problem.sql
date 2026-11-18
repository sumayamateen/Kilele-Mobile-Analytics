
--- ============================================================
--- 6. "The Second Place Problem"
--- ============================================================

-- =====================================================================
-- THE BRIDGE: five findings, one result set. Everything as of 2026-06-30.
-- CAVEAT: all figures come from the analytics sample (1 in 275 subscribers).
--         Counts and KES are sample figures and are NOT scaled to the full base.
-- CONVENTION: difference = first figure minus second figure.
-- TIME: timestamps are converted to Nairobi dates before comparing with dates.
-- =====================================================================
WITH params AS (
    SELECT DATE '2026-06-30' AS as_of,
           DATE '2026-04-01' AS window_start        -- 90 days to 30 Jun 2026
),

--- 1). ACTIVE BASE 
r1 AS (
    SELECT COUNT(*) AS reported,
           COUNT(*) FILTER (WHERE COALESCE(
                 s.last_usage_on >= p.window_start          
              OR EXISTS (SELECT 1 FROM kilele.recharges rc
                         WHERE rc.msisdn = s.msisdn
                           AND rc.channel <> 'promo_credit'   
                           AND (rc.recharged_at AT TIME ZONE 'Africa/Nairobi')::date
                               BETWEEN p.window_start AND p.as_of)
              OR EXISTS (SELECT 1 FROM kilele.bundle_purchases bp
                         WHERE bp.msisdn = s.msisdn
                           AND bp.payment_channel IN ('kilelepay', 'agent')  
                           AND bp.price_paid_kes > 0
                           AND (bp.purchased_at AT TIME ZONE 'Africa/Nairobi')::date
                               BETWEEN p.window_start AND p.as_of)
              , FALSE)) AS corrected
    FROM kilele.subscribers s
    CROSS JOIN params p
    WHERE s.status = 'active'                              
),

--- 2). USIKU 
adopters AS (
    SELECT DISTINCT bp.msisdn
    FROM kilele.bundle_purchases bp
    JOIN kilele.bundles b ON b.bundle_code = bp.bundle_code
    WHERE b.usage_window = 'night'                         
      AND (bp.purchased_at AT TIME ZONE 'Africa/Nairobi')::date <= (SELECT as_of FROM params)
),
r2 AS (
    SELECT ROUND(AVG(u.revenue_kes) FILTER (WHERE u.month BETWEEN DATE '2025-06-01' AND DATE '2025-08-01'), 2) AS before_rev,
           ROUND(AVG(u.revenue_kes) FILTER (WHERE u.month BETWEEN DATE '2025-12-01' AND DATE '2026-02-01'), 2) AS after_rev
    FROM kilele.usage_monthly u
    JOIN adopters a ON a.msisdn = u.msisdn
    WHERE u.active_days > 0                                  
      AND u.month <= DATE '2026-06-01'
     
),

--- 3). COAST PAYDAY WITHDRAWALS 
wd AS (
    SELECT (r.region_name = 'Coast') AS is_coast,
           t.status, t.fail_reason, t.amount_kes
    FROM kilele.kilelepay_transactions t
    JOIN kilele.agents a   ON a.agent_id  = t.agent_id       
    JOIN kilele.regions r  ON r.region_id = a.region_id      
    JOIN kilele.dim_date d ON d.day = (t.txn_at AT TIME ZONE 'Africa/Nairobi')::date
    CROSS JOIN params p
    WHERE t.txn_type = 'withdrawal'                          
      AND d.is_payday_window                                 
      AND d.day <= p.as_of
),
r3 AS (
    SELECT 100.0 * COUNT(*) FILTER (WHERE is_coast AND status = 'failed' AND fail_reason = 'insufficient_agent_float')
                 / NULLIF(COUNT(*) FILTER (WHERE is_coast), 0)                     AS coast_rate,
           100.0 * COUNT(*) FILTER (WHERE NOT is_coast AND status = 'failed' AND fail_reason = 'insufficient_agent_float')
                 / NULLIF(COUNT(*) FILTER (WHERE NOT is_coast), 0)                 AS rest_rate,
           COALESCE(SUM(amount_kes) FILTER (WHERE is_coast AND status = 'failed'
                                              AND fail_reason = 'insufficient_agent_float'), 0) AS coast_kes_not_served
    FROM wd                                                
),
limits AS (
    SELECT MAX(a.float_limit_kes) FILTER (WHERE r.region_name = 'Coast'  AND a.agent_type = 'sub_agent') AS coast_sub_max,
           MIN(a.float_limit_kes) FILTER (WHERE r.region_name <> 'Coast' AND a.agent_type = 'sub_agent') AS other_sub_min
    FROM kilele.agents a
    JOIN kilele.regions r ON r.region_id = a.region_id      
),

--- 4). KISUMU 
site_h1 AS (
    SELECT s.site_id,
           (s.town IN ('Kisumu CBD', 'Kondele', 'Mamboleo', 'Nyalenda')) AS is_kisumu,   
           AVG(d.busy_hour_util_pct) AS avg_util
    FROM kilele.site_daily d
    JOIN kilele.sites s ON s.site_id = d.site_id
    WHERE s.status = 'live'                               
      AND d.day BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'   
    GROUP BY s.site_id, s.town
),
sites95 AS (
    SELECT is_kisumu,
           COUNT(*) AS n,
           COUNT(*) FILTER (WHERE avg_util > 95) AS n95
    FROM site_h1
    GROUP BY is_kisumu
),
r4 AS (
    SELECT 100.0 * SUM(n95) FILTER (WHERE is_kisumu)     / NULLIF(SUM(n) FILTER (WHERE is_kisumu), 0)     AS kis_pct95,
           100.0 * SUM(n95) FILTER (WHERE NOT is_kisumu) / NULLIF(SUM(n) FILTER (WHERE NOT is_kisumu), 0) AS rest_pct95
    FROM sites95
),
silent AS (
    SELECT (st.town IN ('Kisumu CBD', 'Kondele', 'Mamboleo', 'Nyalenda')) AS is_kisumu,
           COUNT(*) AS users,
           COUNT(*) FILTER (WHERE sb.last_usage_on IS NULL
                               OR sb.last_usage_on <= DATE '2026-04-30') AS quiet   
    FROM kilele.usage_monthly u
    JOIN kilele.subscribers sb ON sb.msisdn  = u.msisdn
    JOIN kilele.sites st       ON st.site_id = sb.home_site_id   
    WHERE u.month = DATE '2025-12-01'
      AND u.active_days > 0                                 
    GROUP BY 1
),
r4b AS (
    SELECT 100.0 * SUM(quiet) FILTER (WHERE is_kisumu)     / NULLIF(SUM(users) FILTER (WHERE is_kisumu), 0)     AS kis_silent,
           100.0 * SUM(quiet) FILTER (WHERE NOT is_kisumu) / NULLIF(SUM(users) FILTER (WHERE NOT is_kisumu), 0) AS rest_silent
    FROM silent
),

--- 5). RUDI NYUMBANI
r5 AS (
    SELECT COUNT(*) FILTER (WHERE ct.target_group = 'target')                          AS n_t,
           COUNT(*) FILTER (WHERE ct.target_group = 'holdout')                         AS n_h,
           100.0 * COUNT(*) FILTER (WHERE ct.target_group = 'target'  AND ct.converted)
                 / NULLIF(COUNT(*) FILTER (WHERE ct.target_group = 'target'), 0)       AS target_rate,
           100.0 * COUNT(*) FILTER (WHERE ct.target_group = 'holdout' AND ct.converted)
                 / NULLIF(COUNT(*) FILTER (WHERE ct.target_group = 'holdout'), 0)      AS holdout_rate
    FROM kilele.campaign_targets ct
    JOIN kilele.campaigns c ON c.campaign_id = ct.campaign_id
    WHERE c.campaign_name LIKE 'Rudi Nyumbani%'             
)

-- =====================================================================
-- THE BRIDGE TABLE
-- =====================================================================
SELECT '1. Active base (reported vs promo credits excluded)' AS finding,
       r1.reported::numeric                                  AS reported_figure,
       r1.corrected::numeric                                 AS corrected_or_comparison_figure,
       (r1.reported - r1.corrected)::numeric                 AS difference,
       'subscribers (sample)'                                AS unit,
       format('The 90-day rule counts any credit, including free 1 KES promo credits, so %s active subscribers (%s%% of reported) had no usage and no customer money since 1 Apr 2026.',
              to_char(r1.reported - r1.corrected, 'FM999,999'),
              to_char(100.0 * (r1.reported - r1.corrected) / r1.reported, 'FM990.0')) AS mechanism
FROM r1

UNION ALL
SELECT '2. Usiku: adopters'' average monthly revenue (before vs after)',
       r2.before_rev,
       r2.after_rev,
       ROUND(r2.before_rev - r2.after_rev, 2),
       'KES per active month',
       format('Adopters spend KES %s (%s%%) less per active month after Usiku, consistent with cheap night bundles replacing higher-priced day bundles.',
              to_char(r2.before_rev - r2.after_rev, 'FM999,990'),
              to_char(100.0 * (r2.before_rev - r2.after_rev) / r2.before_rev, 'FM990')) 
FROM r2

UNION ALL
SELECT '3. Coast payday withdrawals (Coast vs rest of country)',
       ROUND(r3.coast_rate, 2),
       ROUND(r3.rest_rate, 2),
       ROUND(r3.coast_rate - r3.rest_rate, 2),
       '% of withdrawals failing for float (points)',
       format('Coast sub-agents are capped at KES %s float against a minimum of KES %s elsewhere; KES %s of withdrawals were not served on Coast payday days.',
              to_char(l.coast_sub_max, 'FM999,999,999'),
              to_char(l.other_sub_min, 'FM999,999,999'),
              to_char(r3.coast_kes_not_served, 'FM999,999,999'))
FROM r3 CROSS JOIN limits l

UNION ALL
SELECT '4. Kisumu town (vs rest of network)',
       ROUND(r4.kis_pct95, 2),
       ROUND(r4.rest_pct95, 2),
       ROUND(r4.kis_pct95 - r4.rest_pct95, 2),
       '% of live sites above 95% busy-hour use, 2026 H1 (points)',
       format('Kisumu town sites are saturated while the rest are not; silent churn is %s%% in Kisumu town against %s%% elsewhere.',
              to_char(r4b.kis_silent, 'FM990.0'),
              to_char(r4b.rest_silent, 'FM990.0'))
FROM r4 CROSS JOIN r4b

UNION ALL
SELECT '5. Rudi Nyumbani (contacted vs holdout)',
       ROUND(r5.target_rate, 2),
       ROUND(r5.holdout_rate, 2),
       ROUND(r5.target_rate - r5.holdout_rate, 2),
       '% converted (lift in points)',
       format('Customers we left alone converted as often as those we contacted, so the campaign added about nothing (contacted n=%s, holdout n=%s).',
              to_char(r5.n_t, 'FM999,999'),
              to_char(r5.n_h, 'FM999,999'))
FROM r5;
/*
Query Result

5 rows
finding	reported_figure	corrected_or_comparison_figure	difference	unit	mechanism
1. Active base (reported vs promo credits excluded)	33235	30709	2526	subscribers (sample)	The 90-day rule counts any credit, including free 1 KES promo credits, so 2,526 active subscribers (7.6% of reported) had no usage and no customer money since 1 Apr 2026.
2. Usiku: adopters' average monthly revenue (before vs after)	1058.06	709.63	348.43	KES per active month	Adopters spend KES 348 (33%) less per active month after Usiku, consistent with cheap night bundles replacing higher-priced day bundles.
3. Coast payday withdrawals (Coast vs rest of country)	18.43	2.77	15.66	% of withdrawals failing for float (points)	Coast sub-agents are capped at KES 30,000 float against a minimum of KES 60,000 elsewhere; KES 3,577,900 of withdrawals were not served on Coast payday days.
4. Kisumu town (vs rest of network)	100.00	0.00	100.00	% of live sites above 95% busy-hour use, 2026 H1 (points)	Kisumu town sites are saturated while the rest are not; silent churn is 30.0% in Kisumu town against 8.3% elsewhere.
5. Rudi Nyumbani (contacted vs holdout)	8.50	8.50	0.01	% converted (lift in points)	Customers we left alone converted as often as those we contacted, so the campaign added about nothing (contacted n=3,951, holdout n=1,695).


What did I find?
The Recommended Order to Read to the Board:
Active Base (Finding 1)
Usiku (Finding 2)
Kisumu (Finding 4)
Coast Payday Withdrawals (Finding 3)
Rudi Nyumbani (Finding 5)

The Reasoning:
1. Active Base: You always start with the denominator. The board must know the true size of the customer base (30,709) before they 
can understand any churn, revenue, or campaign metrics. Fixing this ensures every other metric is mathematically sound.
2. Usiku: This is the biggest financial threat. It is a product-level issue actively destroying our highest-margin revenue (a 33% drop
for adopters). The board needs to see this immediately.
3. Kisumu: This is a network crisis. 100% of our Kisumu sites are saturated, causing silent churn. This is urgent because it is actively 
driving customers away today and requires immediate capital expenditure (CAPEX) to fix.
4. Coast Withdrawals: This is an operational failure causing 3.5M KES in lost volume. It's critical, but it's a localized operational 
fix (raising a limit) rather than a systemic product/network failure.
5. Rudi Nyumbani: The campaign result is last because it is the 'smallest' issue in terms of damage. The campaign simply didn't work 
(0% lift), meaning we wasted some marketing spend, but it didn't break the business like Usiku or Kisumu did.
*/