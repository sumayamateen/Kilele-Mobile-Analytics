
--- ============================================================
--- 2. "Is Usiku a hit"
--- ============================================================

--- Check the bundles first
SELECT 
  bundle_code, 
  bundle_name, 
  usage_window, 
  data_mb, price_kes, 
  launched_on, retired_on
FROM kilele.bundles
WHERE usage_window = 'night' OR bundle_code = 'D-1GB-24H'
ORDER BY usage_window, price_kes;

--- How many night adopters
SELECT 
  COUNT(*) FILTER (WHERE night_adopter) AS night_adopters,
  COUNT(*) AS all_subscribers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE night_adopter) / COUNT(*), 1) AS pct_of_base,
  MIN(first_night_purchase) FILTER (WHERE night_adopter) AS earliest_first_purchase
FROM kilele.subscriber_flags;

--- Average month, adopters vs everyone else, active months only
SELECT 
  CASE WHEN f.night_adopter THEN 'adopter' ELSE 'other' END AS grp,
  CASE WHEN u.month BETWEEN DATE '2025-06-01' AND DATE '2025-08-01'
  THEN '1. Jun-Aug 2025'
  ELSE '2. Dec 2025-Feb 2026' END AS period,
  COUNT(*) AS subscriber_months,
  COUNT(DISTINCT u.msisdn) AS subscribers,
  ROUND(AVG(u.data_mb_day + u.data_mb_night), 1) AS avg_total_mb,
  ROUND(AVG(u.data_mb_day), 1) AS avg_day_mb,
  ROUND(AVG(u.data_mb_night), 1) AS avg_night_mb,
  ROUND(AVG(u.revenue_kes), 2) AS avg_revenue_kes
FROM kilele.usage_monthly u
JOIN kilele.subscriber_flags f ON f.msisdn = u.msisdn
WHERE u.active_days > 0
  AND (u.month BETWEEN DATE '2025-06-01' AND DATE '2025-08-01'
    OR u.month BETWEEN DATE '2025-12-01' AND DATE '2026-02-01')
GROUP BY 1, 2
ORDER BY 2, 1;

--- Daily 1GB purchases, before and after 1 September 2025
WITH p AS (
    SELECT bp.msisdn,
           f.night_adopter,
           (bp.purchased_at AT TIME ZONE 'Africa/Nairobi')::date AS purchase_day,
           bp.price_paid_kes
    FROM kilele.bundle_purchases bp
    JOIN kilele.subscriber_flags f ON f.msisdn = bp.msisdn
    WHERE bp.bundle_code = 'D-1GB-24H'
)
SELECT 
  CASE WHEN night_adopter THEN 'adopter' ELSE 'other' END AS grp,
  CASE WHEN purchase_day < DATE '2025-09-01'
  THEN '1. before 1 Sep 2025' ELSE '2. from 1 Sep 2025' END AS period,
  COUNT(*) AS purchases,
  COUNT(DISTINCT msisdn) AS buyers,
  SUM(price_paid_kes) AS kes_paid,
  ROUND(COUNT(*) / CASE WHEN purchase_day < DATE '2025-09-01' THEN 8.0 ELSE 10.0 END, 1) AS purchases_per_month
FROM p
GROUP BY 1, 2, purchase_day < DATE '2025-09-01'
ORDER BY 1, 2;

--- Month by month, for the chart
SELECT 
  date_trunc('month', bp.purchased_at AT TIME ZONE 'Africa/Nairobi')::date AS month,
  CASE WHEN f.night_adopter THEN 'adopter' ELSE 'other' END AS grp,
  COUNT(*)                AS purchases,
  SUM(bp.price_paid_kes)  AS kes_paid
FROM kilele.bundle_purchases bp
JOIN kilele.subscriber_flags f ON f.msisdn = bp.msisdn
WHERE bp.bundle_code = 'D-1GB-24H'
GROUP BY 1, 2
ORDER BY 1, 2;

--- Company totals by month
SELECT 
  month,
  COUNT(*) FILTER (WHERE active_days > 0) AS active_subscribers,
  ROUND(SUM(data_mb_day + data_mb_night) / 1024.0, 0) AS total_gb,
  ROUND(SUM(data_mb_night) / 1024.0, 0) AS night_gb,
  ROUND(100.0 * SUM(data_mb_night) / NULLIF(SUM(data_mb_day + data_mb_night), 0), 1) AS night_share_pct,
  ROUND(SUM(revenue_kes), 0) AS customer_revenue_kes,
  ROUND(SUM(revenue_kes) / NULLIF(COUNT(*) FILTER (WHERE active_days > 0), 0), 2) AS revenue_per_active_sub,
  ROUND(SUM(revenue_kes) / NULLIF(SUM(data_mb_day + data_mb_night) / 1024.0, 0), 2) AS kes_per_gb
FROM kilele.usage_monthly
GROUP BY month
ORDER BY month;

/*
Query Results

3 rows
bundle_code	bundle_name	usage_window	data_mb	price_kes	launched_on	retired_on
D-1GB-24H	Daily 1GB	anytime	1024	99.00	2020-06-01T00:00:00.000Z	NULL
N-1GB-NIGHT	Usiku 1GB	night	1024	20.00	2025-09-01T00:00:00.000Z	NULL
N-3GB-NIGHT	Usiku 3GB	night	3072	45.00	2025-09-01T00:00:00.000Z	NULL

1 row
night_adopters	all_subscribers	pct_of_base	earliest_first_purchase
8011	40000	20.0	2025-08-31T00:00:00.000Z

4 rows
grp	period	subscriber_months	subscribers	avg_total_mb	avg_day_mb	avg_night_mb	avg_revenue_kes
adopter	1. Jun-Aug 2025	20089	6858	3339.4	2989.1	350.3	1058.06
other	1. Jun-Aug 2025	68091	24237	1530.9	1370.1	160.8	560.55
adopter	2. Dec 2025-Feb 2026	21945	7536	4079.1	1752.1	2327.0	709.63
other	2. Dec 2025-Feb 2026	69843	24048	1583.7	1417.1	166.6	548.68

4 rows
grp	period	purchases	buyers	kes_paid	purchases_per_month
adopter	1. before 1 Sep 2025	58514	6703	5673987.00	7314.3
adopter	2. from 1 Sep 2025	36883	7643	3580632.00	3688.3
other	1. before 1 Sep 2025	105760	14251	10256796.00	13220.0
other	2. from 1 Sep 2025	134917	14886	13090077.00	13491.7

36 rows
month	grp	purchases	kes_paid
2025-01-01T00:00:00.000Z	adopter	7030	680625.00
2025-01-01T00:00:00.000Z	other	13299	1291554.00
2025-02-01T00:00:00.000Z	adopter	6600	640332.00
2025-02-01T00:00:00.000Z	other	12484	1211562.00
2025-03-01T00:00:00.000Z	adopter	7087	688446.00
2025-03-01T00:00:00.000Z	other	13102	1270269.00
2025-04-01T00:00:00.000Z	adopter	7193	697554.00
2025-04-01T00:00:00.000Z	other	13027	1264527.00
2025-05-01T00:00:00.000Z	adopter	7448	721314.00
2025-05-01T00:00:00.000Z	other	13425	1302048.00
2025-06-01T00:00:00.000Z	adopter	7437	721611.00
2025-06-01T00:00:00.000Z	other	13155	1275120.00
2025-07-01T00:00:00.000Z	adopter	7678	744480.00
2025-07-01T00:00:00.000Z	other	13692	1325610.00
2025-08-01T00:00:00.000Z	adopter	8041	779625.00
2025-08-01T00:00:00.000Z	other	13576	1316106.00
2025-09-01T00:00:00.000Z	adopter	6491	629541.00
2025-09-01T00:00:00.000Z	other	13674	1325808.00
2025-10-01T00:00:00.000Z	adopter	5166	501336.00
2025-10-01T00:00:00.000Z	other	13704	1327491.00
2025-11-01T00:00:00.000Z	adopter	4097	398277.00
2025-11-01T00:00:00.000Z	other	13692	1327590.00
2025-12-01T00:00:00.000Z	adopter	3405	329868.00
2025-12-01T00:00:00.000Z	other	13893	1349370.00
2026-01-01T00:00:00.000Z	adopter	3060	297000.00
2026-01-01T00:00:00.000Z	other	13527	1314126.00
2026-02-01T00:00:00.000Z	adopter	2728	265617.00
2026-02-01T00:00:00.000Z	other	12486	1211760.00
2026-03-01T00:00:00.000Z	adopter	2982	289080.00
2026-03-01T00:00:00.000Z	other	13618	1322640.00
2026-04-01T00:00:00.000Z	adopter	3051	296703.00
2026-04-01T00:00:00.000Z	other	13643	1322838.00
2026-05-01T00:00:00.000Z	adopter	2971	288882.00
2026-05-01T00:00:00.000Z	other	13411	1300464.00
2026-06-01T00:00:00.000Z	adopter	2932	284328.00
2026-06-01T00:00:00.000Z	other	13269	1287990.00

18 rows
month	active_subscribers	total_gb	night_gb	night_share_pct	customer_revenue_kes	revenue_per_active_sub	kes_per_gb
2025-01-01T00:00:00.000Z	26999	49080	5156	10.5	18572581	687.90	378.41
2025-02-01T00:00:00.000Z	27151	46755	4907	10.5	17200622	633.52	367.89
2025-03-01T00:00:00.000Z	27340	50573	5292	10.5	18644281	681.94	368.66
2025-04-01T00:00:00.000Z	27913	51804	5449	10.5	18853324	675.43	363.94
2025-05-01T00:00:00.000Z	28485	53368	5610	10.5	19120796	671.26	358.28
2025-06-01T00:00:00.000Z	28947	54495	5728	10.5	19548239	675.31	358.72
2025-07-01T00:00:00.000Z	29417	55726	5854	10.5	19884379	675.95	356.82
2025-08-01T00:00:00.000Z	29816	57089	5983	10.5	19990935	670.48	350.17
2025-09-01T00:00:00.000Z	30310	60415	10984	18.2	19544292	644.81	323.50
2025-10-01T00:00:00.000Z	30779	62465	14739	23.6	19138003	621.79	306.38
2025-11-01T00:00:00.000Z	30905	64441	17873	27.7	18581954	601.26	288.35
2025-12-01T00:00:00.000Z	30670	65970	20051	30.4	18572615	605.56	281.53
2026-01-01T00:00:00.000Z	30650	66692	21234	31.8	18414840	600.81	276.12
2026-02-01T00:00:00.000Z	30468	62773	19948	31.8	16906596	554.90	269.33
2026-03-01T00:00:00.000Z	30536	67270	21413	31.8	18380663	601.93	273.24
2026-04-01T00:00:00.000Z	30164	67680	21496	31.8	18145748	601.57	268.11
2026-05-01T00:00:00.000Z	29792	68364	21851	32.0	18016205	604.73	263.53
2026-06-01T00:00:00.000Z	29619	68125	21695	31.8	17947293	605.94	263.45


What did I find?
Volume is up, but about 19%, not 30%. Total data rose from 57,089 GB in Aug 2025 to 68,125 GB in Jun 2026. 
Night data rose 263% (5,983 to 21,695 GB), while daytime data fell 9%. The “30%” may be the night share of traffic (31.8%), which isn’t growth.
Revenue went the other way. Customer revenue fell 10% (KES 19.99M to 17.95M), revenue per active subscriber fell 10% (670 to 606), 
and revenue per GB fell 25% (350 to 263), while active subscribers stayed flat.
Adopters (8,011, 20% of the base) are where the money went. Their revenue per active month fell 33% (1,058 to 710 KES) as night 
data rose from 350 to 2,327 MB, while non-adopters were flat (561 to 549).
Usiku replaced Daily 1GB sales rather than adding to them. Adopters’ Daily 1GB purchases fell 50% (7,314 to 3,688 a month,
8,041 in Aug to 2,932 in Jun), while non-adopters stayed near 13,300. The same 1GB costs 20 KES at night against 99 KES by day, 
so roughly KES 350k a month of Daily 1GB revenue disappeared from adopters.
*/