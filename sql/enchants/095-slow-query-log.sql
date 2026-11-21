-- Not an enchant fix: rides along because patch night runs this folder as the database administrator at every start.
-- Performance diagnosis (21 Nov). Measuring only: MySQL writes any query that takes longer than half a second to
-- Core\Logs\mysql-slow.log, with how long it took, how many rows it read and the time. SET PERSIST keeps it after
-- the manager rewrites my.ini, and it takes effect straight away. To stop: SET PERSIST slow_query_log = OFF;
SET PERSIST slow_query_log_file = 'C:/Games/CoA Server/Core/Logs/mysql-slow.log';
SET PERSIST long_query_time = 0.5;
SET PERSIST slow_query_log = ON;
