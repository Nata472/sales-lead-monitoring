-- BLANKS: leads
SELECT 
	COUNT(*) AS total_rows,
	COUNT(*) - COUNT(lead_id) AS blank_lead_id,
	COUNT(*) - COUNT(customer_name) AS blank_customer_name,
	COUNT(*) - COUNT(email) AS blank_email,
	COUNT(*) - COUNT(phone) AS blank_phone,
	COUNT(*) - COUNT(source) AS blank_source,
	COUNT(*) - COUNT(project) AS blank_project,
	COUNT(*) - COUNT(manager_id) AS blank_manager_id,
	COUNT(*) - COUNT(created_time) AS blank_created_time,
	COUNT(*) - COUNT(first_response_minutes) AS blank_first_response_minutes,
	COUNT(*) - COUNT(status) AS blank_status,
	COUNT(*) - COUNT(deal_value) AS blank_deal_value
FROM leads;

-- BLANKS: calls
SELECT  
	COUNT(*) AS total_rows,
	COUNT(*) - COUNT(call_id) AS blank_call_id,
	COUNT(*) - COUNT(lead_id) AS blank_lead_id,
	COUNT(*) - COUNT(manager_id) AS blank_manager_id,
	COUNT(*) - COUNT(call_time) AS blank_call_time,
	COUNT(*) - COUNT(call_status) AS blank_call_status,
	COUNT(*) - COUNT(duration_sec) AS blank_duration_sec
FROM calls;

-- BLANKS: tasks
SELECT 
	COUNT(*) AS total_rows,
	COUNT(*) - COUNT(task_id) AS blank_task_id,
	COUNT(*) - COUNT(lead_id) AS blank_lead_id,
	COUNT(*) - COUNT(manager_id) AS blank_manager_id,
	COUNT(*) - COUNT(due_date) AS blank_due_date,
	COUNT(*) - COUNT(completed_date) AS blank_completed_date
FROM tasks;

-- BLANKS: managers
SELECT 
	COUNT(*) AS total_rows,
	COUNT(*) - COUNT(manager_id) AS blank_manager_id,
	COUNT(*) - COUNT(name) AS blank_name,
	COUNT(*) - COUNT(team) AS blank_team
FROM managers;

-- DUPLICATES: leads
SELECT 
	lead_id, 
	COUNT(*) AS times_seen
FROM leads
GROUP BY lead_id
HAVING COUNT(*) > 1
ORDER BY lead_id ASC;

-- DUPLICATES: calls
SELECT 
	call_id, 
	COUNT(*) AS times_seen
FROM calls
GROUP BY call_id
HAVING COUNT(*) > 1
ORDER BY call_id ASC;

-- DUPLICATES: tasks
SELECT 
	task_id, 
	COUNT(*) AS times_seen
FROM tasks
GROUP BY task_id
HAVING COUNT(*) > 1
ORDER BY task_id ASC;


-- Result: 30 repeated lead_ids, all exact copies, safe to remove one of each
SELECT 
	*, 
	COUNT(*) AS times_seen
FROM leads
GROUP BY lead_id, customer_name, email, phone, source, project, manager_id, 
created_time, first_response_minutes, status, deal_value
HAVING COUNT(*) > 1
ORDER BY lead_id ASC;


-- Result: 100 repeated call_ids, all exact copies, safe to remove one of each
SELECT 
	*, 
	COUNT(*) AS times_seen
FROM calls
GROUP BY call_id, lead_id, manager_id, call_time, call_status, duration_sec
HAVING COUNT(*) > 1
ORDER BY lead_id ASC;


-- Result: 60 repeated task_ids, all exact copies, safe to remove one of each
SELECT 
	*, 
	COUNT(*) AS times_seen
FROM tasks
GROUP BY task_id, lead_id, manager_id, due_date, completed_date
HAVING COUNT(*) > 1
ORDER BY lead_id ASC;



-- NEAR-DUPLICATES: emails shared by several lead_ids. Result: 36
SELECT
	email,
	COUNT(DISTINCT lead_id) AS total_rows
FROM leads
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(DISTINCT lead_id) > 1;


-- NEAR-DUPLICATES: leads with those emails
SELECT * 
FROM leads
WHERE email IN (	
	SELECT email FROM leads
	WHERE email IS NOT NULL
	GROUP BY email
	HAVING COUNT(DISTINCT lead_id) > 1	
)
ORDER BY email, lead_id;


-- Source: typos (referal, IG, insta, web site), mixed case, trailing spaces
SELECT 
	source,
	COUNT(*) AS row_count,
	LENGTH(source) AS source_length  
FROM leads
GROUP BY source, source_length
ORDER BY row_count DESC;


-- Status: mixed case, trailing spaces, in_progress vs in progress, blanks
SELECT
	status,
	COUNT(*) AS row_count,
	LENGTH(status) AS status_length
FROM leads
GROUP BY status, status_length
ORDER BY row_count DESC;


-- Project: clean, 3 values
SELECT
	project,
	COUNT(*) AS row_count,
	LENGTH(project) AS project_length
FROM leads
GROUP BY project, project_length
ORDER BY row_count DESC;


-- Call status: mixed case, trailing space, 'no answer' = missed
SELECT 
	call_status,
	COUNT(*) AS row_count,
	LENGTH(call_status) AS call_status_length
FROM calls
GROUP BY call_status, call_status_length
ORDER BY row_count DESC;


-- Team: 'Team B' has a trailing space variant
SELECT
	team,
	COUNT(*) AS row_count,
	LENGTH(team) AS team_length
FROM managers
GROUP BY team, team_length
ORDER BY row_count DESC;


-- Response time: min -5 and max 9000 minutes, impossible values
SELECT 
	MIN(first_response_minutes) AS smallest_response_time,
	MAX(first_response_minutes) AS largest_response_time,
	AVG(first_response_minutes) AS average_response_time
FROM leads;


-- Response time: 26 leads with negative values
SELECT
	COUNT(*) AS row_count
FROM leads
WHERE first_response_minutes < 0;


-- Response time: top 30 values, gap between 9000 and under 200
SELECT
	first_response_minutes
FROM leads
ORDER BY first_response_minutes DESC LIMIT 30;


-- Response time: leads over 1440 min (my rule for invalid) = 24
SELECT
	COUNT(*) AS invalid_response_time
FROM leads
WHERE first_response_minutes > 1440;


-- Deal value: min 0, max 2,005,000 (average ~127,000), suspicious extremes
SELECT
	MIN(deal_value) AS smallest_deal_value,
	MAX(deal_value) AS largest_deal_value,
	AVG(deal_value) AS average_deal_value
FROM leads;


-- Deal value: top 30 values, huge ones first, normal ones end at ~220,000
SELECT
	deal_value
FROM leads
ORDER BY deal_value DESC NULLS LAST LIMIT 30;


-- Deal value over 250,000 (my rule for invalid): 15 leads
SELECT
	deal_value
FROM leads
WHERE deal_value > 250000;


-- Deal value = 0: 20 leads, need to check their status
SELECT
	deal_value
FROM leads
WHERE deal_value = 0;


-- Deal value = 0: 20 leads, 3 are won. Decision: treat as missing
SELECT
	status,
	COUNT(*)
FROM leads
WHERE deal_value = 0
GROUP BY status;


-- Created time: 1 Jul to 1 Oct 2026, looks fine
SELECT
	MIN(created_time) AS earliest_date,
	MAX(created_time) AS latest_date
FROM leads;


-- Call duration: 0 to 900 sec, no extreme values
SELECT
	MIN(duration_sec) AS smallest_duration,
	MAX(duration_sec) AS largest_duration,
	AVG(duration_sec) AS average_duration
FROM calls;


-- Call status cleaned: Answered 7405, Missed 2669, No Answer 36 (= missed)
SELECT
	COUNT(*) AS call_count,
	INITCAP(TRIM(call_status)) AS clean_call_status
FROM calls
GROUP BY clean_call_status;


-- Call status vs duration: 50 answered with 0 sec, 50 missed with duration
SELECT
	INITCAP(TRIM(call_status)) AS clean_call_status,
	COUNT(*) AS call_count,
	CASE WHEN duration_sec = 0 THEN 'zero duration' ELSE 'has duration' END
	AS duration_check
FROM calls
GROUP BY clean_call_status, duration_check;


-- Orphan calls (lead_id not in leads): 15
SELECT
	c.lead_id
FROM calls c
LEFT JOIN leads l
ON l.lead_id = c.lead_id
WHERE l.lead_id IS NULL;


-- Orphan tasks (lead_id not in leads): 0
SELECT
	t.lead_id
FROM tasks t
LEFT JOIN leads l
ON l.lead_id = t.lead_id
WHERE l.lead_id IS NULL;


-- Tasks with a different manager than their lead: 79
SELECT
	COUNT(DISTINCT task_id) AS task_count
FROM tasks t
JOIN leads l
ON t.lead_id = l.lead_id
WHERE t.manager_id != l.manager_id
AND t.manager_id IS NOT NULL;


-- Task dates: due_date min is 1900-01-01 (invalid), the rest July to Oct 2026
SELECT
	MIN(due_date) AS earliest_due_date,
	MAX(due_date) AS latest_due_date,
	MIN(completed_date) AS earliest_completed_date,
	MAX(completed_date) AS latest_completed_date
FROM tasks;


-- Tasks with due_date before 2026: 15
SELECT
	COUNT(task_id) AS task_count
FROM tasks
WHERE EXTRACT(YEAR FROM due_date) < 2026;


-- Tasks completed before their lead was created (impossible): 40
SELECT
	COUNT(DISTINCT task_id) AS task_count
FROM tasks t
JOIN leads l
ON t.lead_id = l.lead_id
WHERE l.created_time > t.completed_date;


-- Calls made before their lead was created (impossible): 40
SELECT
	COUNT(DISTINCT c.call_id) AS call_count
FROM calls c
JOIN leads l
ON c.lead_id = l.lead_id
WHERE c.call_time < l.created_time;


-- Leads with manager_id not in managers: 0
SELECT l.manager_id
FROM leads l
LEFT JOIN managers m
ON l.manager_id = m.manager_id
WHERE m.manager_id IS NULL
AND l.manager_id IS NOT NULL;


-- Calls with manager_id not in managers: 0
SELECT c.manager_id
FROM calls c
LEFT JOIN managers m
ON c.manager_id = m.manager_id
WHERE m.manager_id IS NULL
AND c.manager_id IS NOT NULL;

-- Tasks with manager_id not in managers: 0
SELECT t.manager_id
FROM tasks t
LEFT JOIN managers m
ON t.manager_id = m.manager_id
WHERE m.manager_id IS NULL
AND t.manager_id IS NOT NULL;

