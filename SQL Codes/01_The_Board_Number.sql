
--- ============================================================
--- 01. "The Board Number"
--- ============================================================

--- How many subscribers are real?

--- Subscribers by status (as of 2026-06-30)
SELECT status, COUNT(*) AS subscribers
FROM kilele.subscribers
GROUP BY status
ORDER BY subscribers DESC;

--- Status by region (gives active-by-region and the full picture)
SELECT r.region_name,
       COUNT(*) FILTER (WHERE s.status = 'active')  AS active,
       COUNT(*) FILTER (WHERE s.status = 'dormant') AS dormant,
       COUNT(*) FILTER (WHERE s.status = 'churned') AS churned,
       COUNT(*)                                      AS total
FROM kilele.subscribers s
JOIN kilele.regions r ON r.region_id = s.region_id
GROUP BY r.region_name
ORDER BY active DESC;

--- Karibu (promo SIM) activations by month, 2025
SELECT date_trunc('month', activated_on)::date AS month,
       COUNT(*) AS promo_sim_activations
FROM kilele.subscribers
WHERE activation_channel = 'promo_sim'
  AND activated_on >= '2025-01-01'
  AND activated_on <  '2026-01-01'
GROUP BY 1
ORDER BY 1;

--- Count and share of the active base
SELECT COUNT(*) FILTER (WHERE f.karibu_only) AS karibu_only_active,
       COUNT(*)                               AS reported_active,
       ROUND(100.0 * COUNT(*) FILTER (WHERE f.karibu_only) / COUNT(*), 1) AS pct_of_active
FROM kilele.subscribers s
JOIN kilele.subscriber_flags f ON f.msisdn = s.msisdn
WHERE s.status = 'active';

--- Split by region and activation channel
SELECT r.region_name,
       s.activation_channel,
       COUNT(*) AS karibu_only_active
FROM kilele.subscribers s
JOIN kilele.subscriber_flags f ON f.msisdn = s.msisdn
JOIN kilele.regions r          ON r.region_id = s.region_id
WHERE s.status = 'active' AND f.karibu_only
GROUP BY r.region_name, s.activation_channel
ORDER BY karibu_only_active DESC;

--- corrected active base
SELECT COUNT(*) FILTER (WHERE s.status = 'active')                          AS reported_active,
       COUNT(*) FILTER (WHERE s.status = 'active' AND f.karibu_only)        AS karibu_only,
       COUNT(*) FILTER (WHERE s.status = 'active' AND NOT f.karibu_only)    AS corrected_active
FROM kilele.subscribers s
JOIN kilele.subscriber_flags f ON f.msisdn = s.msisdn;

/*
Query Results

3 rows
status	subscribers
active	33235
churned	4784
dormant	1981

6 rows
region_name	active	dormant	churned	total
Nairobi	9905	507	1482	11894
Rift Valley	6743	338	994	8075
Coast	5006	260	747	6013
Nyanza	4457	540	580	5577
Central	4062	190	539	4791
Western	3062	146	442	3650

12 rows
month	promo_sim_activations
2025-01-01T00:00:00.000Z	26
2025-02-01T00:00:00.000Z	16
2025-03-01T00:00:00.000Z	18
2025-04-01T00:00:00.000Z	406
2025-05-01T00:00:00.000Z	483
2025-06-01T00:00:00.000Z	454
2025-07-01T00:00:00.000Z	474
2025-08-01T00:00:00.000Z	490
2025-09-01T00:00:00.000Z	528
2025-10-01T00:00:00.000Z	470
2025-11-01T00:00:00.000Z	387
2025-12-01T00:00:00.000Z	18

1 row
karibu_only_active	reported_active	pct_of_active
2519	33235	7.6

6 rows
region_name	activation_channel	karibu_only_active
Nairobi	promo_sim	732
Rift Valley	promo_sim	491
Coast	promo_sim	376
Nyanza	promo_sim	372
Central	promo_sim	329
Western	promo_sim	219

1 row
reported_active	karibu_only	corrected_active
33235	2519	30716

What did I find?
Of the 33,235 subscribers in our sample reported as active at 30 June, 2,519, or 7.6%, were only active because of 
1-shilling Karibu credits. They had no usage and no customer money in 90 days. All came from the free SIM drive that 
ran from April to November 2025. The corrected active base is 30,716, and from now on I will count a subscriber as 
active only if they have used the network or paid us in the last 90 days.

*/