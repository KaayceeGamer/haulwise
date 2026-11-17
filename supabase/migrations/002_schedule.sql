-- Run after 001. Rebuilds the community data every night at 03:17 UTC.
-- If this fails with "extension not available", enable pg_cron first:
-- Dashboard -> Database -> Extensions -> search "pg_cron" -> enable. Then run this again.
create extension if not exists pg_cron;

select cron.schedule('coffer-refresh', '17 3 * * *', $$select public.refresh_community()$$);
