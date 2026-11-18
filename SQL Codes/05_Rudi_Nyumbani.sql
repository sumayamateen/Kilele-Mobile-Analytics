
--- ============================================================
--- 5. "Rudi Nyumbani"
--- ============================================================

--- Every campaign: sample sizes, conversion rates and lift
WITH g AS (
    SELECT campaign_id,
           COUNT(*) FILTER (WHERE target_group = 'target')                AS target_n,
           COUNT(*) FILTER (WHERE target_group = 'target'  AND converted) AS target_converted,
           COUNT(*) FILTER (WHERE target_group = 'holdout')               AS holdout_n,
           COUNT(*) FILTER (WHERE target_group = 'holdout' AND converted) AS holdout_converted
    FROM kilele.campaign_targets
    GROUP BY campaign_id
),
r AS (
    SELECT g.*,
           target_converted::numeric  / NULLIF(target_n, 0)  AS p_t,
           holdout_converted::numeric / NULLIF(holdout_n, 0) AS p_h
    FROM g
)
SELECT c.campaign_id,
       c.campaign_name,
       c.campaign_type,
       c.start_date,
       c.end_date,
       r.target_n,
       r.target_converted,
       ROUND(100 * r.p_t, 2)             AS target_rate_pct,
       r.holdout_n,
       r.holdout_converted,
       ROUND(100 * r.p_h, 2)             AS holdout_rate_pct,
       ROUND(100 * (r.p_t - r.p_h), 2)   AS lift_pp,
       -- 95% confidence interval on the lift (optional significance check)
       ROUND(100 * ((r.p_t - r.p_h)
             - 1.96 * SQRT(r.p_t * (1 - r.p_t) / NULLIF(r.target_n, 0)
                         + r.p_h * (1 - r.p_h) / NULLIF(r.holdout_n, 0))), 2) AS lift_ci_low_pp,
       ROUND(100 * ((r.p_t - r.p_h)
             + 1.96 * SQRT(r.p_t * (1 - r.p_t) / NULLIF(r.target_n, 0)
                         + r.p_h * (1 - r.p_h) / NULLIF(r.holdout_n, 0))), 2) AS lift_ci_high_pp
FROM r
JOIN kilele.campaigns c ON c.campaign_id = r.campaign_id
ORDER BY c.campaign_id;

--- Campaigns 4 and 5 against campaign 2, side by side
WITH g AS (
    SELECT campaign_id,
           COUNT(*) FILTER (WHERE target_group = 'target')                AS target_n,
           COUNT(*) FILTER (WHERE target_group = 'target'  AND converted) AS target_converted,
           COUNT(*) FILTER (WHERE target_group = 'holdout')               AS holdout_n,
           COUNT(*) FILTER (WHERE target_group = 'holdout' AND converted) AS holdout_converted
    FROM kilele.campaign_targets
    WHERE campaign_id IN (2, 4, 5)
    GROUP BY campaign_id
),
r AS (
    SELECT g.*,
           100.0 * target_converted  / NULLIF(target_n, 0)  AS target_rate_pct,
           100.0 * holdout_converted / NULLIF(holdout_n, 0) AS holdout_rate_pct
    FROM g
)
SELECT 'Target n'            AS measure,
       MAX(target_n)         FILTER (WHERE campaign_id = 4)::text AS "4 Win-back wave 1",
       MAX(target_n)         FILTER (WHERE campaign_id = 5)::text AS "5 Win-back wave 2",
       MAX(target_n)         FILTER (WHERE campaign_id = 2)::text AS "2 Weekly 2GB Upsell"
FROM r
UNION ALL
SELECT 'Target conversion rate %',
       ROUND(MAX(target_rate_pct)  FILTER (WHERE campaign_id = 4), 2)::text,
       ROUND(MAX(target_rate_pct)  FILTER (WHERE campaign_id = 5), 2)::text,
       ROUND(MAX(target_rate_pct)  FILTER (WHERE campaign_id = 2), 2)::text
FROM r
UNION ALL
SELECT 'Holdout n',
       MAX(holdout_n) FILTER (WHERE campaign_id = 4)::text,
       MAX(holdout_n) FILTER (WHERE campaign_id = 5)::text,
       MAX(holdout_n) FILTER (WHERE campaign_id = 2)::text
FROM r
UNION ALL
SELECT 'Holdout conversion rate %',
       ROUND(MAX(holdout_rate_pct) FILTER (WHERE campaign_id = 4), 2)::text,
       ROUND(MAX(holdout_rate_pct) FILTER (WHERE campaign_id = 5), 2)::text,
       ROUND(MAX(holdout_rate_pct) FILTER (WHERE campaign_id = 2), 2)::text
FROM r
UNION ALL
SELECT 'Lift (percentage points)',
       ROUND(MAX(target_rate_pct - holdout_rate_pct) FILTER (WHERE campaign_id = 4), 2)::text,
       ROUND(MAX(target_rate_pct - holdout_rate_pct) FILTER (WHERE campaign_id = 5), 2)::text,
       ROUND(MAX(target_rate_pct - holdout_rate_pct) FILTER (WHERE campaign_id = 2), 2)::text
FROM r;

--- Did win-back converters come back, or just take the free gigabyte?
SELECT ct.campaign_id,
       ct.target_group,
       COUNT(*) AS converters,
       COUNT(*) FILTER (WHERE ct.converted_at + INTERVAL '30 days' < TIMESTAMPTZ '2026-07-01 00:00:00+03')
                                                              AS observable_converters,
       COUNT(*) FILTER (
           WHERE ct.converted_at + INTERVAL '30 days' < TIMESTAMPTZ '2026-07-01 00:00:00+03'
             AND (
                 EXISTS (SELECT 1
                         FROM kilele.recharges rc
                         WHERE rc.msisdn = ct.msisdn
                           AND rc.channel <> 'promo_credit'
                           AND rc.recharged_at > ct.converted_at + INTERVAL '30 days'
                           AND rc.recharged_at < TIMESTAMPTZ '2026-07-01 00:00:00+03')
              OR EXISTS (SELECT 1
                         FROM kilele.bundle_purchases bp
                         WHERE bp.msisdn = ct.msisdn
                           AND bp.payment_channel IN ('kilelepay', 'agent')
                           AND bp.price_paid_kes > 0
                           AND bp.purchased_at > ct.converted_at + INTERVAL '30 days'
                           AND bp.purchased_at < TIMESTAMPTZ '2026-07-01 00:00:00+03')
             )
       ) AS paid_after_30_days,
       ROUND(100.0 * COUNT(*) FILTER (
           WHERE ct.converted_at + INTERVAL '30 days' < TIMESTAMPTZ '2026-07-01 00:00:00+03'
             AND (
                 EXISTS (SELECT 1
                         FROM kilele.recharges rc
                         WHERE rc.msisdn = ct.msisdn
                           AND rc.channel <> 'promo_credit'
                           AND rc.recharged_at > ct.converted_at + INTERVAL '30 days'
                           AND rc.recharged_at < TIMESTAMPTZ '2026-07-01 00:00:00+03')
              OR EXISTS (SELECT 1
                         FROM kilele.bundle_purchases bp
                         WHERE bp.msisdn = ct.msisdn
                           AND bp.payment_channel IN ('kilelepay', 'agent')
                           AND bp.price_paid_kes > 0
                           AND bp.purchased_at > ct.converted_at + INTERVAL '30 days'
                           AND bp.purchased_at < TIMESTAMPTZ '2026-07-01 00:00:00+03')
             )
       ) / NULLIF(COUNT(*) FILTER (
           WHERE ct.converted_at + INTERVAL '30 days' < TIMESTAMPTZ '2026-07-01 00:00:00+03'), 0), 1)
                                                              AS pct_paid_after_30_days
FROM kilele.campaign_targets ct
WHERE ct.campaign_id IN (4, 5)
  AND ct.converted
  AND ct.converted_at IS NOT NULL
GROUP BY ct.campaign_id, ct.target_group
ORDER BY ct.campaign_id, ct.target_group;

--- Sample sizes
SELECT campaign_id,
       COUNT(*)                                                                      AS rows,
       COUNT(DISTINCT msisdn)                                                        AS distinct_subscribers,
       COUNT(*) FILTER (WHERE target_group = 'holdout' AND contacted_at IS NOT NULL) AS holdout_contacted,
       COUNT(*) FILTER (WHERE target_group = 'target'  AND contacted_at IS NULL)     AS target_not_contacted,
       COUNT(*) FILTER (WHERE converted AND converted_at IS NULL)                    AS converted_without_time
FROM kilele.campaign_targets
GROUP BY campaign_id
ORDER BY campaign_id;

/*
Query Results

5 rows
campaign_id	campaign_name	campaign_type	start_date	end_date	target_n	target_converted	target_rate_pct	holdout_n	holdout_converted	holdout_rate_pct	lift_pp	lift_ci_low_pp	lift_ci_high_pp
1	Karibu Kilele Free SIM Drive	acquisition	2025-04-01T00:00:00.000Z	2025-11-30T00:00:00.000Z	3692	3692	100.00	0	0	NULL	NULL	NULL	NULL
2	Weekly 2GB Upsell	upsell	2025-06-02T00:00:00.000Z	2025-06-29T00:00:00.000Z	11217	1601	14.27	2783	150	5.39	8.88	7.82	9.94
3	Usiku Bundles Launch	upsell	2025-09-01T00:00:00.000Z	2025-09-21T00:00:00.000Z	17714	3712	20.96	1922	214	11.13	9.82	8.29	11.35
4	Rudi Nyumbani Win-back Wave 1	win_back	2025-10-06T00:00:00.000Z	2025-10-26T00:00:00.000Z	1749	149	8.52	727	62	8.53	-0.01	-2.42	2.41
5	Rudi Nyumbani Win-back Wave 2	win_back	2026-03-02T00:00:00.000Z	2026-03-29T00:00:00.000Z	2202	187	8.49	968	82	8.47	0.02	-2.08	2.13

5 rows
measure	4 Win-back wave 1	5 Win-back wave 2	2 Weekly 2GB Upsell
Target n	1749	2202	11217
Target conversion rate %	8.52	8.49	14.27
Holdout n	727	968	2783
Holdout conversion rate %	8.53	8.47	5.39
Lift (percentage points)	-0.01	0.02	8.88

4 rows
campaign_id	target_group	converters	observable_converters	paid_after_30_days	pct_paid_after_30_days
4	holdout	62	62	3	4.8
4	target	149	149	5	3.4
5	holdout	82	82	0	0.0
5	target	187	187	0	0.0

5 rows
campaign_id	rows	distinct_subscribers	holdout_contacted	target_not_contacted	converted_without_time
1	3692	3692	0	0	0
2	14000	14000	0	0	0
3	19636	19636	0	0	0
4	2476	2476	0	0	0
5	3170	3170	0	0	0


What did I find?
No measurable effect: the customers we left alone came back at the same rate as the ones we contacted. Wave 1 was 8.52% of 1,749 against
8.53% of 727 (lift -0.01 points), and wave 2 was 8.49% of 2,202 against 8.47% of 968 (lift +0.02 points). Both 95% ranges (about ±2 points) 
include zero.
A real lift looks different: the Weekly 2GB Upsell converted 14.27% of 11,217 against 5.39% of 2,783 in the holdout, a lift of 8.88
points with a range of +7.8 to +9.9.
They did not come back as customers: of wave 1’s 211 converters, 8 (3.8%) paid any customer money more than 30 days after converting 
(5 of 149 contacted, 3 of 62 in the holdout). In wave 2, none of 187 contacted converters and none of 82 holdout converters did.
For Daniel: “Both waves reached customers who were already coming back, since the group we left alone returned at the same 8.5%, so
the offer hasn’t moved anyone yet, and that is a design problem we can fix.”
Wave three: fund a smaller, redesigned test, not a repeat. Offer a bonus tied to a paid action such as a first top-up, judge it on 
customer money at 30 and 60 days, and size the holdout at about 1,600 per group to detect a 3-point lift. Two caveats: campaign 1 has no 
holdout, so its 100% is not a result, and the check that no holdout customer was contacted still needs to be run.
*/
