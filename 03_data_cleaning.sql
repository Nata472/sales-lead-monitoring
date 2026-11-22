-- STAGE 1: STANDARDIZING

-- Name cleaned (INITCAP): lowercase and uppercase names fixed
SELECT
	customer_name,
	INITCAP(customer_name) AS cleaned_name
FROM leads
WHERE customer_name <> INITCAP(customer_name);


-- Phone cleaned: digits only, standardized to +1 999 999 9999
SELECT
	phone,
	'+1 ' || SUBSTRING(d, 1, 3) || ' ' || SUBSTRING(d, 4, 3) || ' ' || SUBSTRING(d, 7, 4) AS cleaned_phone
FROM (
	SELECT
		phone,
		RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 10) AS d
	FROM leads
	WHERE phone IS NOT NULL
) AS digits;


-- Phone cleaned check: 0 phones not 15 characters long
SELECT COUNT(*) AS bad_phones
FROM (
	SELECT
		'+1 ' || SUBSTRING(d, 1, 3) || ' ' || SUBSTRING(d, 4, 3) || ' ' || SUBSTRING(d, 7, 4) AS cleaned_phone
	FROM (
		SELECT RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 10) AS d
		FROM leads
		WHERE phone IS NOT NULL
	) AS digits
) AS cleaned
WHERE LENGTH(cleaned_phone) <> 15;


-- Source cleaned (CASE): 4 values + 120 blank
SELECT
	COUNT(*) AS source_count,
	CASE LOWER(TRIM(SOURCE))
	WHEN 'insta' THEN 'instagram'
	WHEN 'ig' THEN 'instagram'
	WHEN 'referal' THEN 'referral'
	WHEN 'web site' THEN 'website'
	ELSE LOWER(TRIM(SOURCE))
	END AS cleaned_source
FROM leads
GROUP BY cleaned_source;


-- Status cleaned (CASE): in_progress fixed, 4 values + 50 blank
SELECT
	COUNT(*) AS status_count,
	CASE LOWER(TRIM(status))
	WHEN 'in_progress' THEN 'in progress'
	ELSE LOWER(TRIM(status))
	END AS cleaned_status
FROM leads
GROUP BY cleaned_status;


-- Call status cleaned (CASE): 2 values, answered and missed
SELECT
	COUNT(*) AS status_count,
	CASE LOWER(TRIM(call_status))
	WHEN 'no answer' THEN 'missed'
	ELSE LOWER(TRIM(call_status))
	END AS cleaned_call_status
FROM calls
GROUP BY cleaned_call_status;


-- Team cleaned (TRIM): 2 values, Team A and Team B
SELECT
	TRIM(team) AS cleaned_team
FROM managers
GROUP BY cleaned_team;


-- STAGE 2: DUPLICATES

-- Exact copies removed, leads: 5,070 rows down to 5,040
SELECT COUNT(*)
FROM (
	SELECT DISTINCT *
	FROM leads
) AS unique_leads;


-- Exact copies removed, calls: 10,110 rows down to 10,010
SELECT COUNT(*)
FROM (
	SELECT DISTINCT *
	FROM calls
) AS unique_calls;


-- Exact copies removed, tasks: 4,399 rows down to 4,339
SELECT COUNT(*)
FROM (
	SELECT DISTINCT *
	FROM tasks
) AS unique_tasks;


-- Near-duplicates numbered by email (n = 2 is the repeat)
SELECT
	lead_id, email, created_time,
	ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_time) AS n
FROM (
	SELECT DISTINCT *
	FROM leads
) AS unique_leads
WHERE email IS NOT NULL 
ORDER BY email, n;


-- Near-duplicates counted by n: 4,634 originals, 36 repeats
SELECT n, COUNT(*) AS lead_count
FROM (
	SELECT
		ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_time) AS n
	FROM (
		SELECT DISTINCT *
		FROM leads
	) AS unique_leads
	WHERE email IS NOT NULL
) AS numbered
GROUP BY n
ORDER BY n;


-- STAGE 3: BLANKS

-- Blank customer_name (50): filled with 'Unknown'
SELECT
	lead_id, COALESCE(customer_name, 'Unknown') AS filled_customer_name
FROM leads
WHERE customer_name IS NULL;


-- Blank source (120): filled with 'Unknown' (not recorded, not a real source)
SELECT
	lead_id, COALESCE(source, 'Unknown') AS filled_source
FROM leads
WHERE source IS NULL;


-- Blank status (50): filled with 'Unknown', excluded from win rates
SELECT
	lead_id, COALESCE(status, 'Unknown') AS filled_status
FROM leads
WHERE status IS NULL;


-- Blank email (373), phone (193): kept as NULL, CRM data gap
-- Blank manager_id: leads 43, calls 40: kept as NULL, unassigned
-- Blank deal_value (412): kept as NULL, normal for new leads
-- Blank due_date (101): kept as NULL, task without a deadline
-- Blank completed_date (1,463): kept as NULL, task not done yet


-- STAGE 4: IMPOSSIBLE VALUES

-- Response time cleaned: 50 invalid values (below 0 or above 1440) set to NULL
SELECT 
	first_response_minutes,
	CASE 
	WHEN first_response_minutes < 0
	OR first_response_minutes > 1440
	THEN NULL
	ELSE first_response_minutes
	END AS cleaned_response_minutes
FROM leads
WHERE first_response_minutes < 0 
OR first_response_minutes > 1440;


-- Deal value cleaned: 35 invalid values (0 or above 250,000) set to NULL
SELECT 
	deal_value,
	CASE
	WHEN deal_value = 0
	OR deal_value > 250000
	THEN NULL
	ELSE deal_value
	END AS cleaned_deal_value
FROM leads 
WHERE deal_value = 0
OR deal_value > 250000;


-- Task due_date cleaned: 15 dates of 1900-01-01 set to NULL
SELECT
	due_date,
	CASE
	WHEN EXTRACT(YEAR FROM due_date) < 2026
	THEN NULL
	ELSE due_date
	END AS cleaned_due_date
FROM tasks
WHERE EXTRACT(YEAR FROM due_date) < 2026;


-- Created time: all dates valid (1 Jul to 1 Oct 2026)
-- Call duration: no invalid values (0 to 900 sec)


-- STAGE 5: RELATIONSHIPS AND CONTRADICTIONS


-- Calls flagged is_orphan: 15 (lead_id not in leads)
SELECT
	c.call_id, c.lead_id, 
	CASE WHEN l.lead_id IS NULL THEN TRUE ELSE FALSE END AS is_orphan
FROM calls c
LEFT JOIN leads l
ON l.lead_id = c.lead_id
WHERE l.lead_id IS NULL;


-- Calls flagged is_before_lead: 40 (call_time earlier than lead created_time)
SELECT
	c.call_id, c.call_time, l.created_time,
	CASE WHEN c.call_time < l.created_time THEN TRUE ELSE FALSE END AS is_before_lead
FROM (
	SELECT DISTINCT * FROM leads l 
) AS l
JOIN calls c 
ON c.lead_id = l.lead_id
WHERE c.call_time < l.created_time;


-- Calls flagged is_status_conflict: 100 (answered with 0 sec or missed with duration)
SELECT DISTINCT
	call_id,
	cleaned_status,
	duration_sec,
	CASE WHEN (cleaned_status = 'missed' AND duration_sec > 0)
		OR (cleaned_status = 'answered' AND duration_sec = 0)
		THEN TRUE ELSE FALSE END AS is_status_conflict
FROM (
	SELECT
		call_id,
		duration_sec,
		CASE LOWER(TRIM(call_status))
		WHEN 'no answer' THEN 'missed'
		ELSE LOWER(TRIM(call_status))
		END AS cleaned_status
	FROM calls
) AS cleaned
WHERE (cleaned_status = 'missed' AND duration_sec > 0)
	OR (cleaned_status = 'answered' AND duration_sec = 0);


-- Tasks flagged is_manager_mismatch: 79 (task manager differs from lead manager)
SELECT DISTINCT
	t.task_id,
	t.manager_id,
	l.manager_id,
	CASE WHEN t.manager_id <> l.manager_id THEN TRUE ELSE FALSE END AS is_manager_mismatch
FROM (
SELECT DISTINCT *
	FROM leads l
) AS l
JOIN tasks t 
ON l.lead_id = t.lead_id
WHERE t.manager_id <> l.manager_id
AND t.manager_id IS NOT NULL;


-- Tasks flagged is_completed_before_lead: 40 (completed_date earlier than lead created_time)
SELECT
	t.task_id, t.completed_date, l.created_time,
	CASE WHEN t.completed_date < l.created_time THEN TRUE ELSE FALSE END AS is_completed_before_lead
FROM (
SELECT DISTINCT * FROM leads l
) AS l
JOIN tasks t
ON l.lead_id = t.lead_id;


-- Not changed in stage 5:
-- manager_id not in managers: 0 in leads, calls and tasks
-- Orphan tasks (lead_id not in leads): 0