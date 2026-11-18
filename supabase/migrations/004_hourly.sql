-- Haulwise: rebuild the community data every hour instead of every night.
-- Run after 001-003: Supabase -> SQL Editor -> New query -> paste -> Run. Safe to run twice.
-- Each run takes well under a second at this size; check Database -> Cron if that changes.
select cron.unschedule(jobname) from cron.job where jobname in ('coffer-refresh', 'haulwise-places', 'haulwise-refresh');
select cron.schedule('haulwise-refresh', '17 * * * *', $$select public.refresh_community(); select public.refresh_places()$$);
