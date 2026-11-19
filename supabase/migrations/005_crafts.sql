-- Haulwise: recipes players know, with their reagents, so item tooltips can say what an item is
-- used for even when none of your characters knows the recipe.
-- Run after 001-004: Supabase -> SQL Editor -> New query -> paste -> Run. Safe to run twice.
--
-- Each upload replaces that player's recipes. The pool keeps, per crafted item, the reagent list
-- most players reported (recipes are facts you can check in game, so one player is enough).

create table if not exists public.source_craft (
    uid_hash text not null,
    item     int  not null,  -- item the recipe makes
    qty      int  not null,  -- how many one craft makes
    prof     text not null,
    reagents text not null,  -- "itemID:count/itemID:count"
    primary key (uid_hash, item)
);

create table if not exists public.community_craft (
    item     int primary key,
    qty      int, prof text, reagents text,
    seen_by  int
);

alter table public.source_craft    enable row level security;
alter table public.community_craft enable row level security;

create or replace function public.replace_crafts(p_uid_hash text, p_crafts jsonb)
returns int language plpgsql security definer set search_path = public as $$
begin
    if jsonb_typeof(p_crafts) <> 'array' or jsonb_array_length(p_crafts) > 5000 then
        raise exception 'bad crafts';
    end if;
    delete from source_craft where uid_hash = p_uid_hash;
    insert into source_craft (uid_hash, item, qty, prof, reagents)
    select distinct on ((c->>'out')::int)
           p_uid_hash, (c->>'out')::int, greatest(1, least(100, (c->>'qty')::int)), left(c->>'prof', 40),
           (select string_agg((r->>0)::int || ':' || (r->>1)::int, '/' order by (r->>0)::int)
              from jsonb_array_elements(c->'reagents') r)
    from jsonb_array_elements(p_crafts) c
    where jsonb_typeof(c->'reagents') = 'array'
      and jsonb_array_length(c->'reagents') between 1 and 12;
    return (select count(*) from source_craft where uid_hash = p_uid_hash);
end $$;

create or replace function public.refresh_crafts()
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from community_craft;
    insert into community_craft (item, qty, prof, reagents, seen_by)
    with counted as (
        select item, qty, prof, reagents, count(*) as n,
               row_number() over (partition by item order by count(*) desc, reagents) as r
        from source_craft group by item, qty, prof, reagents
    )
    select c.item, c.qty, c.prof, c.reagents, (select count(*) from source_craft s where s.item = c.item)
    from counted c where c.r = 1;
end $$;

-- "C,item,count,profession,reagents;..." for tools/build-data.mjs and the website's community copy.
create or replace function public.community_crafts_export()
returns text language sql stable security definer set search_path = public as $$
    select coalesce(string_agg(
        'C,' || item || ',' || qty || ',' || regexp_replace(coalesce(prof, '?'), '[,;:/~|]', ' ', 'g') || ',' || reagents,
        ';' order by item), '')
    from community_craft
$$;

revoke all on function public.replace_crafts(text, jsonb) from public, anon, authenticated;
revoke all on function public.refresh_crafts() from public, anon, authenticated;
grant execute on function public.replace_crafts(text, jsonb) to service_role;
grant execute on function public.refresh_crafts() to service_role;
grant execute on function public.community_crafts_export() to anon, authenticated;

-- Rebuilt every hour with the rest of the community data.
select cron.unschedule(jobname) from cron.job where jobname = 'haulwise-refresh';
select cron.schedule('haulwise-refresh', '17 * * * *',
    $$select public.refresh_community(); select public.refresh_places(); select public.refresh_crafts()$$);
