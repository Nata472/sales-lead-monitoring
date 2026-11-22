CREATE TABLE managers (
	manager_id INT PRIMARY KEY,
    name TEXT,
	team TEXT
);

CREATE TABLE leads (
    lead_id INT,
    source TEXT,
    project TEXT,
    manager_id INT,
    created_time TIMESTAMP,
	first_response_minutes NUMERIC,
    status TEXT
);

CREATE TABLE calls (
    call_id INT,
	lead_id INT,
	manager_id INT,
    call_time TIMESTAMP,
    call_status TEXT,
    duration_sec INT
);

CREATE TABLE tasks (
	task_id INT,
    lead_id INT,
	manager_id INT,
    due_date TIMESTAMP,
    completed_date TIMESTAMP
);