
--- ============================================================
--- 3. "Payday at the Coast"
--- ============================================================

--- Float failure rate by region, payday window vs other days
SELECT r.region_name,
       CASE WHEN d.is_payday_window THEN 'payday window' ELSE 'other days' END AS day_type,
       COUNT(*) AS withdrawals,
       COUNT(*) FILTER (WHERE t.status = 'failed'
                          AND t.fail_reason = 'insufficient_agent_float') AS float_failures,
       ROUND(100.0 * COUNT(*) FILTER (WHERE t.status = 'failed'
                          AND t.fail_reason = 'insufficient_agent_float') / COUNT(*), 2) AS float_failure_rate_pct
FROM kilele.kilelepay_transactions t
JOIN kilele.agents a   ON a.agent_id  = t.agent_id
JOIN kilele.regions r  ON r.region_id = a.region_id
JOIN kilele.dim_date d ON d.day = (t.txn_at AT TIME ZONE 'Africa/Nairobi')::date
WHERE t.txn_type = 'withdrawal'
  AND (t.txn_at AT TIME ZONE 'Africa/Nairobi')::date <= DATE '2026-06-30'
GROUP BY r.region_name, d.is_payday_window
ORDER BY r.region_name, d.is_payday_window DESC;

--- Every withdrawal failure reason, counted
SELECT t.status,
       COALESCE(t.fail_reason, '(none)') AS fail_reason,
       COUNT(*) AS withdrawals,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_non_success
FROM kilele.kilelepay_transactions t
WHERE t.txn_type = 'withdrawal'
  AND t.status <> 'success'
  AND (t.txn_at AT TIME ZONE 'Africa/Nairobi')::date <= DATE '2026-06-30'
GROUP BY t.status, t.fail_reason
ORDER BY withdrawals DESC;

--- Agent float limits by region and agent type
SELECT r.region_name,
       a.agent_type,
       COUNT(*)                         AS agents,
       MIN(a.float_limit_kes)           AS min_float_limit_kes,
       ROUND(AVG(a.float_limit_kes), 0) AS avg_float_limit_kes,
       MAX(a.float_limit_kes)           AS max_float_limit_kes
FROM kilele.agents a
JOIN kilele.regions r ON r.region_id = a.region_id
GROUP BY r.region_name, a.agent_type
ORDER BY r.region_name, a.agent_type;

--- Coast non-dealers vs everyone else: closing float and stockout minutes
SELECT CASE WHEN r.region_name = 'Coast' AND a.agent_type <> 'dealer'
            THEN 'Coast non-dealers' ELSE 'Everyone else' END AS agent_group,
       CASE WHEN d.is_payday_window THEN 'payday days' ELSE 'other days' END AS day_type,
       COUNT(DISTINCT a.agent_id)         AS agents,
       ROUND(AVG(f.closing_float_kes), 0) AS avg_closing_float_kes,
       ROUND(AVG(f.stockout_minutes), 1)  AS avg_stockout_minutes
FROM kilele.agent_float_daily f
JOIN kilele.agents a   ON a.agent_id  = f.agent_id
JOIN kilele.regions r  ON r.region_id = a.region_id
JOIN kilele.dim_date d ON d.day = f.day
WHERE f.day <= DATE '2026-06-30'
GROUP BY 1, 2
ORDER BY 1, 2 DESC;

--- The money on Coast payday days
WITH coast_payday AS (
    SELECT t.status, t.fail_reason, t.amount_kes, t.fee_kes
    FROM kilele.kilelepay_transactions t
    JOIN kilele.agents a   ON a.agent_id  = t.agent_id
    JOIN kilele.regions r  ON r.region_id = a.region_id
    JOIN kilele.dim_date d ON d.day = (t.txn_at AT TIME ZONE 'Africa/Nairobi')::date
    WHERE t.txn_type = 'withdrawal'
      AND r.region_name = 'Coast'
      AND d.is_payday_window
      AND d.day <= DATE '2026-06-30'
),
fee_rate AS (
    SELECT SUM(fee_kes) / NULLIF(SUM(amount_kes), 0) AS rate
    FROM coast_payday
    WHERE status = 'success'
)
SELECT COUNT(*)                                   AS float_failures,
       SUM(c.amount_kes)                          AS kes_not_served,
       ROUND(SUM(c.amount_kes) * MAX(fr.rate), 0) AS est_fee_income_not_earned_kes
FROM coast_payday c
CROSS JOIN fee_rate fr
WHERE c.status = 'failed'
  AND c.fail_reason = 'insufficient_agent_float';

/*
Query Results

12 rows
region_name	day_type	withdrawals	float_failures	float_failure_rate_pct
Central	payday window	11610	346	2.98
Central	other days	12084	140	1.16
Coast	payday window	14426	2658	18.43
Coast	other days	15217	514	3.38
Nairobi	payday window	29316	799	2.73
Nairobi	other days	29766	337	1.13
Nyanza	payday window	13278	391	2.94
Nyanza	other days	13545	149	1.10
Rift Valley	payday window	19430	518	2.67
Rift Valley	other days	20252	226	1.12
Western	payday window	8897	228	2.56
Western	other days	9313	110	1.18

6 rows
status	fail_reason	withdrawals	pct_of_non_success
failed	insufficient_agent_float	6416	56.52
failed	pin_failed	1510	13.30
failed	insufficient_balance	1241	10.93
failed	timeout	1059	9.33
reversed	(none)	768	6.77
failed	limit_exceeded	357	3.15

18 rows
region_name	agent_type	agents	min_float_limit_kes	avg_float_limit_kes	max_float_limit_kes
Central	dealer	7	300000.00	592857	1000000.00
Central	kiosk	56	20000.00	29375	40000.00
Central	sub_agent	102	60000.00	95588	150000.00
Coast	dealer	11	500000.00	750000	1000000.00
Coast	kiosk	67	20000.00	27836	40000.00
Coast	sub_agent	159	30000.00	30000	30000.00
Nairobi	dealer	19	300000.00	628947	1000000.00
Nairobi	kiosk	137	20000.00	28869	40000.00
Nairobi	sub_agent	284	60000.00	99718	150000.00
Nyanza	dealer	5	300000.00	570000	1000000.00
Nyanza	kiosk	68	20000.00	28603	40000.00
Nyanza	sub_agent	131	60000.00	93206	150000.00
Rift Valley	dealer	11	300000.00	559091	1000000.00
Rift Valley	kiosk	78	20000.00	28718	40000.00
Rift Valley	sub_agent	204	60000.00	97549	150000.00
Western	dealer	10	500000.00	625000	1000000.00
Western	kiosk	36	20000.00	29167	40000.00
Western	sub_agent	115	60000.00	93652	150000.00

4 rows
agent_group	day_type	agents	avg_closing_float_kes	avg_stockout_minutes
Coast non-dealers	payday days	226	453	298.5
Coast non-dealers	other days	226	8890	57.6
Everyone else	payday days	1274	10020	163.5
Everyone else	other days	1274	31246	56.0

1 row
float_failures	kes_not_served	est_fee_income_not_earned_kes
2658	3577900.00	96345

What did I find?
Cause: a setting Kilele controls. All 159 Coast sub-agents are capped at a KES 30,000 float limit, while sub-agents in every other 
region have a floor of 60,000 and an average near 95,000, so Coast agents run out of float on payday through no fault of their own.
Rate: the float failure rate on payday is 18.4% at the Coast against 2.6% to 3.0% elsewhere. Coast also fails at 3.4% on ordinary 
days, higher than any other region’s payday rate.
Volume: float is the biggest failure reason, 6,416 of 11,351 unsuccessful withdrawals (56.5%). Coast has about half of them with 15% 
of withdrawals. The rate is what matters for the forum, because it shows Coast agents fail far more often than Nairobi agents.
Money: on Coast payday days, 2,658 withdrawals failed for float, KES 3,577,900 was not served, and about KES 96,000 in fees was not earned (an estimate, at the 2.7% fee rate on successful withdrawals). These are sample figures, not scaled.
Fix: raise the Coast sub-agent limit to at least KES 60,000, allow a higher limit from the 25th to the 2nd, and support top-ups before
the 25th. Before the forum, confirm that sub-agents carry the failures by comparing failure rates by agent type within the Coast.
*/