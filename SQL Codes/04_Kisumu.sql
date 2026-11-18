
--- ============================================================
--- 4. "Kisumu"
--- ============================================================

--- Check the town names first
SELECT r.region_name, s.town, s.status, COUNT(*) AS sites
FROM kilele.sites s
JOIN kilele.regions r ON r.region_id = s.region_id
WHERE s.town ILIKE '%kisumu%'
   OR s.town IN ('Kondele', 'Mamboleo', 'Nyalenda')
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

--- Monthly utilisation and dropped calls, Jan 2025 to Jun 2026
SELECT date_trunc('month', d.day)::date AS month,
       CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
            THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
       COUNT(DISTINCT s.site_id)           AS sites,
       ROUND(AVG(d.busy_hour_util_pct), 1) AS avg_busy_hour_util_pct,
       ROUND(AVG(d.dropped_call_pct), 2)   AS avg_dropped_call_pct
FROM kilele.site_daily d
JOIN kilele.sites s ON s.site_id = d.site_id
WHERE s.status = 'live'
  AND d.day BETWEEN DATE '2025-01-01' AND DATE '2026-06-30'
GROUP BY 1, 2
ORDER BY 1, 2;

--- Sites above 90% and above 95%, 2026 H1
-- a). By town
WITH site_avg AS (
    SELECT s.site_id, s.town,
           CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
                THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
           AVG(d.busy_hour_util_pct) AS avg_util
    FROM kilele.site_daily d
    JOIN kilele.sites s ON s.site_id = d.site_id
    WHERE s.status = 'live'
      AND d.day BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
    GROUP BY s.site_id, s.town
)
SELECT area, town,
       COUNT(*)                                  AS live_sites,
       COUNT(*) FILTER (WHERE avg_util > 90)     AS sites_above_90,
       COUNT(*) FILTER (WHERE avg_util > 95)     AS sites_above_95,
       ROUND(AVG(avg_util), 1)                   AS avg_util_pct
FROM site_avg
GROUP BY area, town
ORDER BY area, sites_above_90 DESC, town;

-- b). Kisumu against the rest, in total
WITH site_avg AS (
    SELECT s.site_id,
           CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
                THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
           AVG(d.busy_hour_util_pct) AS avg_util
    FROM kilele.site_daily d
    JOIN kilele.sites s ON s.site_id = d.site_id
    WHERE s.status = 'live'
      AND d.day BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
    GROUP BY s.site_id, area
)
SELECT area,
       COUNT(*)                                                        AS live_sites,
       COUNT(*) FILTER (WHERE avg_util > 90)                           AS sites_above_90,
       COUNT(*) FILTER (WHERE avg_util > 95)                           AS sites_above_95,
       ROUND(100.0 * COUNT(*) FILTER (WHERE avg_util > 90) / COUNT(*), 1) AS pct_above_90,
       ROUND(100.0 * COUNT(*) FILTER (WHERE avg_util > 95) / COUNT(*), 1) AS pct_above_95
FROM site_avg
GROUP BY area
ORDER BY area;

--- Planned Kisumu sites and how late they are
SELECT s.site_code, s.town, s.county, s.technology, s.capacity_gb_day,
       s.commissioned_on                                   AS target_date,
       DATE '2026-06-30' - s.commissioned_on               AS days_late_at_30_jun_2026,
       ROUND((DATE '2026-06-30' - s.commissioned_on) / 30.4, 1) AS months_late
FROM kilele.sites s
WHERE s.status = 'planned'
  AND s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
ORDER BY s.commissioned_on, s.site_code;

--- Network complaints per 1,000 active subscriber-months
-- a). By half-year, Kisumu vs rest
WITH cmp AS (
    SELECT CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
                THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
           EXTRACT(YEAR FROM (c.opened_at AT TIME ZONE 'Africa/Nairobi'))::int::text
             || ' H' || CASE WHEN EXTRACT(MONTH FROM (c.opened_at AT TIME ZONE 'Africa/Nairobi')) <= 6
                             THEN '1' ELSE '2' END AS half,
           COUNT(*) AS complaints
    FROM kilele.complaints c
    JOIN kilele.sites s ON s.site_id = c.site_id
    WHERE c.category = 'network'
      AND (c.opened_at AT TIME ZONE 'Africa/Nairobi')::date BETWEEN DATE '2025-01-01' AND DATE '2026-06-30'
    GROUP BY 1, 2
),
sm AS (
    SELECT CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
                THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
           EXTRACT(YEAR FROM u.month)::int::text
             || ' H' || CASE WHEN EXTRACT(MONTH FROM u.month) <= 6 THEN '1' ELSE '2' END AS half,
           COUNT(*) AS active_subscriber_months
    FROM kilele.usage_monthly u
    JOIN kilele.subscribers sb ON sb.msisdn = u.msisdn
    JOIN kilele.sites s        ON s.site_id = sb.home_site_id
    WHERE u.active_days > 0
      AND u.month BETWEEN DATE '2025-01-01' AND DATE '2026-06-01'
    GROUP BY 1, 2
)
SELECT sm.area, sm.half,
       COALESCE(cmp.complaints, 0) AS network_complaints,
       sm.active_subscriber_months,
       ROUND(1000.0 * COALESCE(cmp.complaints, 0) / sm.active_subscriber_months, 2) AS complaints_per_1000
FROM sm
LEFT JOIN cmp ON cmp.area = sm.area AND cmp.half = sm.half
ORDER BY sm.half, sm.area;

-- b). Kisumu sub-categories, 2026 H1
SELECT c.sub_category,
       COUNT(*) AS complaints,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_kisumu_network_complaints
FROM kilele.complaints c
JOIN kilele.sites s ON s.site_id = c.site_id
WHERE c.category = 'network'
  AND s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
  AND (c.opened_at AT TIME ZONE 'Africa/Nairobi')::date BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'  
GROUP BY c.sub_category
ORDER BY complaints DESC;

--- Silent churn
WITH dec_users AS (
    SELECT DISTINCT msisdn
    FROM kilele.usage_monthly
    WHERE month = DATE '2025-12-01' AND active_days > 0
)
SELECT CASE WHEN s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda')
            THEN 'Kisumu town' ELSE 'Rest of network' END AS area,
       COUNT(*) AS dec_2025_users,
       COUNT(*) FILTER (WHERE sb.last_usage_on IS NULL
                           OR sb.last_usage_on <= DATE '2026-04-30') AS gone_quiet,
       ROUND(100.0 * COUNT(*) FILTER (WHERE sb.last_usage_on IS NULL
                           OR sb.last_usage_on <= DATE '2026-04-30') / COUNT(*), 1) AS pct_silent
FROM dec_users du
JOIN kilele.subscribers sb ON sb.msisdn = du.msisdn
JOIN kilele.sites s        ON s.site_id = sb.home_site_id
GROUP BY 1
ORDER BY 1;

---- Why the Nyanza average hides it
WITH base AS (
    SELECT r.region_name,
           s.town IN ('Kisumu CBD','Kondele','Mamboleo','Nyalenda') AS is_kisumu,
           s.site_id, d.busy_hour_util_pct, d.dropped_call_pct
    FROM kilele.site_daily d
    JOIN kilele.sites s   ON s.site_id = d.site_id
    JOIN kilele.regions r ON r.region_id = s.region_id
    WHERE s.status = 'live'
      AND d.day BETWEEN DATE '2026-01-01' AND DATE '2026-06-30'
)
SELECT '1. Kisumu town' AS grp,
       COUNT(DISTINCT site_id) AS sites,
       ROUND(AVG(busy_hour_util_pct), 1) AS avg_util_pct,
       ROUND(AVG(dropped_call_pct), 2)   AS avg_dropped_call_pct
FROM base WHERE is_kisumu
UNION ALL
SELECT '2. Nyanza excluding Kisumu town', COUNT(DISTINCT site_id),
       ROUND(AVG(busy_hour_util_pct), 1), ROUND(AVG(dropped_call_pct), 2)
FROM base WHERE region_name = 'Nyanza' AND NOT is_kisumu
UNION ALL
SELECT '3. Nyanza overall (the dashboard)', COUNT(DISTINCT site_id),
       ROUND(AVG(busy_hour_util_pct), 1), ROUND(AVG(dropped_call_pct), 2)
FROM base WHERE region_name = 'Nyanza'
UNION ALL
SELECT '4. All other regions', COUNT(DISTINCT site_id),
       ROUND(AVG(busy_hour_util_pct), 1), ROUND(AVG(dropped_call_pct), 2)
FROM base WHERE region_name <> 'Nyanza'
ORDER BY grp;

/*
Query Results

8 rows
region_name	town	status	sites
Nyanza	Kisumu CBD	live	8
Nyanza	Kisumu CBD	planned	2
Nyanza	Kondele	live	6
Nyanza	Kondele	planned	2
Nyanza	Mamboleo	live	5
Nyanza	Mamboleo	planned	1
Nyanza	Nyalenda	live	5
Nyanza	Nyalenda	planned	1

36 rows
month	area	sites	avg_busy_hour_util_pct	avg_dropped_call_pct
2025-01-01T00:00:00.000Z	Kisumu town	24	81.4	0.82
2025-01-01T00:00:00.000Z	Rest of network	389	59.7	0.55
2025-02-01T00:00:00.000Z	Kisumu town	24	82.6	0.91
2025-02-01T00:00:00.000Z	Rest of network	389	60.3	0.55
2025-03-01T00:00:00.000Z	Kisumu town	24	85.1	1.11
2025-03-01T00:00:00.000Z	Rest of network	389	61.0	0.55
2025-04-01T00:00:00.000Z	Kisumu town	24	87.3	1.38
2025-04-01T00:00:00.000Z	Rest of network	389	62.3	0.55
2025-05-01T00:00:00.000Z	Kisumu town	24	88.4	1.51
2025-05-01T00:00:00.000Z	Rest of network	389	63.1	0.56
2025-06-01T00:00:00.000Z	Kisumu town	24	90.5	1.79
2025-06-01T00:00:00.000Z	Rest of network	389	63.9	0.56
2025-07-01T00:00:00.000Z	Kisumu town	24	92.2	2.03
2025-07-01T00:00:00.000Z	Rest of network	389	65.1	0.57
2025-08-01T00:00:00.000Z	Kisumu town	24	93.5	2.25
2025-08-01T00:00:00.000Z	Rest of network	389	65.6	0.58
2025-09-01T00:00:00.000Z	Kisumu town	24	95.5	2.60
2025-09-01T00:00:00.000Z	Rest of network	389	67.1	0.59
2025-10-01T00:00:00.000Z	Kisumu town	24	96.6	2.79
2025-10-01T00:00:00.000Z	Rest of network	389	68.2	0.61
2025-11-01T00:00:00.000Z	Kisumu town	24	97.1	2.86
2025-11-01T00:00:00.000Z	Rest of network	389	68.6	0.62
2025-12-01T00:00:00.000Z	Kisumu town	24	98.3	3.07
2025-12-01T00:00:00.000Z	Rest of network	389	70.1	0.65
2026-01-01T00:00:00.000Z	Kisumu town	24	98.4	3.12
2026-01-01T00:00:00.000Z	Rest of network	389	71.0	0.68
2026-02-01T00:00:00.000Z	Kisumu town	24	99.0	3.22
2026-02-01T00:00:00.000Z	Rest of network	389	72.1	0.72
2026-03-01T00:00:00.000Z	Kisumu town	24	99.3	3.27
2026-03-01T00:00:00.000Z	Rest of network	389	73.2	0.76
2026-04-01T00:00:00.000Z	Kisumu town	24	99.4	3.27
2026-04-01T00:00:00.000Z	Rest of network	389	74.4	0.81
2026-05-01T00:00:00.000Z	Kisumu town	24	99.4	3.29
2026-05-01T00:00:00.000Z	Rest of network	389	75.0	0.84
2026-06-01T00:00:00.000Z	Kisumu town	24	99.5	3.31
2026-06-01T00:00:00.000Z	Rest of network	389	76.6	0.92

42 rows
area	town	live_sites	sites_above_90	sites_above_95	avg_util_pct
Kisumu town	Kisumu CBD	8	8	8	99.2
Kisumu town	Kondele	6	6	6	99.1
Kisumu town	Mamboleo	5	5	5	99.3
Kisumu town	Nyalenda	5	5	5	99.1
Rest of network	Nairobi CBD	26	3	0	78.9
Rest of network	Kasarani	20	2	0	75.5
Rest of network	Nakuru	20	2	0	75.2
Rest of network	Eldoret	18	1	0	75.1
Rest of network	Embakasi	24	1	0	75.5
Rest of network	Embu	7	1	0	73.5
Rest of network	Kibera	12	1	0	74.6
Rest of network	Malindi	8	1	0	78.1
Rest of network	Mtwapa	7	1	0	76.2
Rest of network	Nanyuki	8	1	0	75.6
Rest of network	Nyali	10	1	0	68.8
Rest of network	Voi	4	1	0	80.8
Rest of network	Ahero	3	0	0	79.5
Rest of network	Bungoma	9	0	0	75.9
Rest of network	Busia	7	0	0	70.8
Rest of network	Homa Bay	6	0	0	74.9
Rest of network	Kakamega	11	0	0	75.2
Rest of network	Kericho	9	0	0	70.3
Rest of network	Kerugoya	6	0	0	69.4
Rest of network	Kikuyu	8	0	0	70.9
Rest of network	Kilifi	7	0	0	68.4
Rest of network	Kisii	9	0	0	70.7
Rest of network	Kitale	9	0	0	72.3
Rest of network	Likoni	8	0	0	73.7
Rest of network	Migori	6	0	0	78.3
Rest of network	Mombasa Island	16	0	0	72.6
Rest of network	Mumias	5	0	0	68.1
Rest of network	Murang'a	8	0	0	73.1
Rest of network	Naivasha	9	0	0	74.5
Rest of network	Narok	7	0	0	80.4
Rest of network	Nyeri	12	0	0	67.2
Rest of network	Ongata Rongai	10	0	0	73.8
Rest of network	Ruiru	12	0	0	69.8
Rest of network	Siaya	5	0	0	68.8
Rest of network	Thika	14	0	0	72.5
Rest of network	Ukunda	6	0	0	70.3
Rest of network	Webuye	5	0	0	79.4
Rest of network	Westlands	18	0	0	70.1

2 rows
area	live_sites	sites_above_90	sites_above_95	pct_above_90	pct_above_95
Kisumu town	24	24	24	100.0	100.0
Rest of network	389	16	0	4.1	0.0

6 rows
site_code	town	county	technology	capacity_gb_day	target_date	days_late_at_30_jun_2026	months_late
KSM-0010	Kisumu CBD	Kisumu	4G	1276.5	2025-03-08T00:00:00.000Z	479	15.8
KSM-0017	Kondele	Kisumu	4G	1030.4	2025-04-23T00:00:00.000Z	433	14.2
KSM-0030	Nyalenda	Kisumu	4G	991.4	2025-07-18T00:00:00.000Z	347	11.4
KSM-0009	Kisumu CBD	Kisumu	4G	1254.2	2025-07-20T00:00:00.000Z	345	11.3
KSM-0018	Kondele	Kisumu	4G	912.1	2025-08-04T00:00:00.000Z	330	10.9
KSM-0024	Mamboleo	Kisumu	4G	1230.1	2025-09-22T00:00:00.000Z	281	9.2


6 rows
area	half	network_complaints	active_subscriber_months	complaints_per_1000
Kisumu town	2025 H1	143	10553	13.55
Rest of network	2025 H1	970	156282	6.21
Kisumu town	2025 H2	200	11909	16.79
Rest of network	2025 H2	1060	169988	6.24
Kisumu town	2026 H1	286	10606	26.97
Rest of network	2026 H1	1007	170623	5.90

4 rows
sub_category	complaints	pct_of_kisumu_network_complaints
slow_data	156	54.5
dropped_calls	75	26.2
cannot_connect_4g	31	10.8
no_signal	24	8.4

2 rows
area	dec_2025_users	gone_quiet	pct_silent
Kisumu town	2043	613	30.0
Rest of network	28627	2366	8.3

4 rows
grp	sites	avg_util_pct	avg_dropped_call_pct
1. Kisumu town	24	99.2	3.25
2. Nyanza excluding Kisumu town	29	73.7	0.76
3. Nyanza overall (the dashboard)	53	85.3	1.89
4. All other regions	360	73.7	0.79

What did I find?
Findings, anchored to 30 June 2026 
All 24 live Kisumu town sites averaged above 95% busy-hour utilisation in 2026 H1 (99.2% on average), against none of the 389 
other live sites. Dropped calls reached 3.31% in June 2026, against 0.92% elsewhere. The six planned Kisumu sites, which would 
add about 6,700 GB a day of design capacity, are 9 to 16 months past their target dates.
Customers are reacting. Network complaints reached 27.0 per 1,000 active subscriber-months in 2026 H1, up from 13.6 in 2025 H1,
while the rest of the network stayed near 6. Slow data and dropped calls make up 81% of Kisumu’s 286 network complaints. Many more
have left without complaining: 30.0% of Kisumu subscribers who used the network in December 2025 have not used it since April, 
against 8.3% elsewhere.
The data shows these moving together, and the rest of Nyanza is normal, so saturated capacity is the likely cause. It doesn’t prove 
that capacity caused the churn, so I would say “consistent with” to the CFO.
Why the Nyanza average hides it: Nyanza’s 85.3% average blends Kisumu’s 24 sites at 99.2% with the region’s other 29 sites at 73.7%, 
which is the same as the rest of the country.
*/