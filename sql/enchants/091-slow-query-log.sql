-- TEMPORARY (8 Nov): find what makes "Retrieving character list" take ~40 seconds. Logs every query that takes over
-- 1 second to C:\Games\CoA Server\mysql\logs\slow-queries.log. SET GLOBAL lasts until MySQL restarts; patch night
-- turns it on again at each start while this file exists. Delete this file once the cause is found.
SET GLOBAL slow_query_log_file = 'C:/Games/CoA Server/mysql/logs/slow-queries.log';
SET GLOBAL long_query_time = 1;
SET GLOBAL slow_query_log = ON;
