-- Created clean leads view with deduplicated records, nullified outliers, and standardized text/phone formats
CREATE OR REPLACE VIEW leads_clean AS
SELECT
    lead_id,
    manager_id,
    created_time,
    CASE
        WHEN first_response_minutes < 0 OR first_response_minutes > 1440 THEN NULL
        ELSE first_response_minutes
    END AS first_response_minutes,
    CASE
        WHEN deal_value = 0 OR deal_value > 250000 THEN NULL
        ELSE deal_value
    END AS deal_value,
    project,
    COALESCE(
        CASE LOWER(TRIM(status))
            WHEN 'in_progress' THEN 'in progress'
            ELSE LOWER(TRIM(status))
        END, 'unknown') AS status,
    COALESCE(INITCAP(customer_name), 'unknown') AS customer_name,
    email,
    '+1 ' || SUBSTRING(d, 1, 3) || ' ' || SUBSTRING(d, 4, 3) || ' ' || SUBSTRING(d, 7, 4) AS phone,
    COALESCE(
        CASE LOWER(TRIM(source))
            WHEN 'insta' THEN 'instagram'
            WHEN 'ig' THEN 'instagram'
            WHEN 'referal' THEN 'referral'
            WHEN 'web site' THEN 'website'
            ELSE LOWER(TRIM(source))
        END, 'unknown') AS source
FROM (
    SELECT
        *,
        RIGHT(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 10) AS d,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_time) AS n
    FROM (SELECT DISTINCT * FROM leads) AS unique_leads
) AS numbered
WHERE n = 1 OR email IS NULL;


-- Created clean calls view with deduplicated records, standardized statuses, and data quality flags
CREATE OR REPLACE VIEW calls_clean AS
SELECT
    c.call_id,
    c.lead_id,
    c.manager_id,
    c.call_time,
    c.duration_sec,
    CASE LOWER(TRIM(c.call_status))
        WHEN 'no answer' THEN 'missed'
        ELSE LOWER(TRIM(c.call_status))
    END AS call_status,
    CASE WHEN (LOWER(TRIM(c.call_status)) IN ('no answer', 'missed') AND c.duration_sec > 0)
           OR (LOWER(TRIM(c.call_status)) = 'answered' AND c.duration_sec = 0)
         THEN TRUE ELSE FALSE END AS is_status_conflict,
    CASE WHEN l.lead_id IS NULL THEN TRUE ELSE FALSE END AS is_orphan,
    CASE WHEN c.call_time < l.created_time THEN TRUE ELSE FALSE END AS is_before_lead
FROM (SELECT DISTINCT * FROM calls) AS c
LEFT JOIN (SELECT DISTINCT lead_id, created_time FROM leads) AS l
    ON l.lead_id = c.lead_id;


-- Created clean managers view with trimmed team names
CREATE OR REPLACE VIEW managers_clean AS
SELECT
    manager_id,
	name,
    TRIM(team) AS team
FROM managers;


-- Created clean tasks view with deduplicated records, filtered due dates, and lead/manager mismatch flags
CREATE OR REPLACE VIEW tasks_clean AS
SELECT
    t.task_id,
    t.lead_id,
    t.manager_id,
    CASE
        WHEN EXTRACT(YEAR FROM t.due_date) < 2026 THEN NULL
        ELSE t.due_date
    END AS due_date,
    t.completed_date,
    CASE WHEN t.manager_id <> l.manager_id THEN TRUE ELSE FALSE END AS is_manager_mismatch,
    CASE WHEN t.completed_date < l.created_time THEN TRUE ELSE FALSE END AS is_completed_before_lead
FROM (SELECT DISTINCT * FROM tasks) AS t
LEFT JOIN (SELECT DISTINCT lead_id, manager_id, created_time FROM leads) AS l
    ON l.lead_id = t.lead_id;





