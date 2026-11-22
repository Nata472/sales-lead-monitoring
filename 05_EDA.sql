-- Conversion rate by lead source (referral best at 22.4%, ads worst at 5.0%)
SELECT source,
	COUNT(*) AS leads,
	COUNT(*) FILTER (WHERE status = 'won') AS won,
	ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'won') / COUNT(*), 1) AS conv_pct
FROM leads_clean
GROUP BY source
ORDER BY conv_pct DESC;


-- Conversion rate by first-response time (flat 13-15%, speed doesn't matter)
SELECT CASE WHEN first_response_minutes <= 5 THEN '0-5 min'
			WHEN first_response_minutes <= 30 THEN '6-30 min'
			WHEN first_response_minutes <= 120 THEN '31-120 min'
			ELSE '2h+' END AS response_bucket,
	   COUNT(*) AS leads,
	   ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'won') / COUNT(*), 1) AS conv_pct
FROM leads_clean
GROUP BY 1
ORDER BY MIN(first_response_minutes);


-- Manager performance: won revenue and conversion % (Noah Rhodes best on both, Connie Lawrence lowest)
SELECT m.team, m.name,
       COUNT(*) AS leads,
       COUNT(*) FILTER (WHERE l.status = 'won') AS won,
       ROUND(100.0 * COUNT(*) FILTER (WHERE l.status = 'won') / COUNT(*), 1) AS conv_pct,
       SUM(l.deal_value) FILTER (WHERE l.status = 'won') AS revenue
FROM leads_clean l
JOIN managers_clean m ON m.manager_id = l.manager_id
GROUP BY m.team, m.name
ORDER BY revenue DESC;


-- Conversion % by calls per lead (0-1 calls ~0%, 4 calls 94%; link, not proof of cause)
WITH call_counts AS (
	SELECT lead_id, COUNT(*) AS n_calls
	FROM calls_clean
	GROUP BY lead_id
)
SELECT COALESCE(c.n_calls, 0) AS calls_per_lead,
	COUNT(*) AS leads,
	ROUND(100.0 * COUNT(*) FILTER (WHERE l.status = 'won') / COUNT(*), 1) AS conv_pct
FROM leads_clean l
LEFT JOIN call_counts c ON c.lead_id = l.lead_id
GROUP BY 1
ORDER BY 1;


-- Task discipline per manager (~33% of tasks never completed everywhere, Daniel Wagner best on late, Connie  Lawrence worst)
SELECT m.name,
	COUNT(*) AS tasks,
	COUNT(*) FILTER (WHERE t.completed_date IS NULL) AS not_done,
	COUNT(*) FILTER (WHERE t.completed_date > t.due_date) AS late
FROM tasks_clean t
JOIN managers_clean m 
ON t.manager_id = m.manager_id
GROUP BY m.name
ORDER BY late DESC;


-- Monthly leads, wins, won revenue (Aug peak at 31.7M; leads trending down; Oct partial so excluded)
SELECT DATE_TRUNC('month', created_time) AS month,
	COUNT(*) AS leads,
	COUNT(*) FILTER (WHERE status = 'won') AS won,
	SUM(deal_value) FILTER (WHERE status = 'won') AS revenue
FROM leads_clean
WHERE created_time < '2026-10-01'
GROUP BY 1
ORDER BY 1;


-- Conversion and won revenue by project (Gamma top: 44.5M, avg deal 181K; Alpha weakest)
SELECT project,
       COUNT(*) AS leads,
       COUNT(*) FILTER (WHERE status = 'won') AS won,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'won') / COUNT(*), 1) AS conv_pct,
       SUM(deal_value) FILTER (WHERE status = 'won') AS won_revenue,
       ROUND(AVG(deal_value) FILTER (WHERE status = 'won')) AS avg_won_deal
FROM leads_clean
GROUP BY project
ORDER BY won_revenue DESC;


-- Conversion % by total talk time per lead (under 5 min 1.4% -> 15+ min 55.6%; link, not proof)
WITH talk AS (
  SELECT lead_id, SUM(duration_sec) AS total_sec
  FROM calls_clean
  GROUP BY lead_id
)
SELECT CASE WHEN COALESCE(t.total_sec, 0) < 300 THEN '1. under 5 min'
            WHEN t.total_sec < 600 THEN '2. 5-10 min'
            WHEN t.total_sec < 900 THEN '3. 10-15 min'
            ELSE '4. 15+ min' END AS talk_time,
       COUNT(*) AS leads,
       ROUND(100.0 * COUNT(*) FILTER (WHERE l.status = 'won') / COUNT(*), 1) AS conv_pct
FROM leads_clean l
LEFT JOIN talk t ON t.lead_id = l.lead_id
GROUP BY 1
ORDER BY 1;

