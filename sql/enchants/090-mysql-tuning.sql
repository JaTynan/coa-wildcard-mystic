-- Not an enchant fix: rides along because patch night runs this folder as the database administrator at every start.
-- MySQL tuning (8 Nov). The manager rewrites mysql\my.ini at every start with a 256 MB buffer pool, so the values are
-- stored with SET PERSIST instead (kept in the data folder's mysqld-auto.cnf, read after my.ini, and applied straight
-- away without a restart). To undo one: RESET PERSIST innodb_buffer_pool_size; (and so on), then restart.
--   innodb_buffer_pool_size 4 GB     the databases stay in memory instead of being re-read from disk: faster startup,
--                                    bot logins, character lists. The VM has 18 GB; the server used about 9 at 1,500 bots.
--   innodb_redo_log_capacity 1 GB    room for the constant stream of bot saves (default 100 MB forces frequent flushing).
--   innodb_flush_log_at_trx_commit 2 a save is written to disk about once a second instead of on every single save;
--                                    only a power cut or VM crash (not a server crash) can lose that last second.
SET PERSIST innodb_buffer_pool_size = 4294967296;
SET PERSIST innodb_redo_log_capacity = 1073741824;
SET PERSIST innodb_flush_log_at_trx_commit = 2;
