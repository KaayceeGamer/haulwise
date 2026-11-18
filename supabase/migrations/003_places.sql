-- Haulwise: where trainers and vendors stand, as players saw them (for the waypoint arrow).
-- Run after 001 and 002: Supabase -> SQL Editor -> New query -> paste -> Run. Safe to run twice.
--
-- Each upload replaces that player's places. Every night the pool takes, per NPC, the map most
-- players saw it on and the median position there; it needs 1 player (positions are facts you
-- can check in game, and one visit is enough to fix an NPC that moved).

create table if not exists public.source_place (
    uid_hash text not null,
    npc      int  not null,
    name     text not null,
    kind     text not null,  -- 'T' trainer, 'V' vendor
    prof     text,
    fac      text,           -- 'A' or 'H': the faction of the player who saw it
    map      int  not null,  -- UiMapID
    x        real not null,  -- 0-100
    y        real not null,
    primary key (uid_hash, npc)
);

create table if not exists public.community_place (
    npc     int primary key,
    name    text, kind text, prof text, fac text,
    map     int, x real, y real,
    seen_by int
);

alter table public.source_place    enable row level security;
alter table public.community_place enable row level security;

create or replace function public.replace_places(p_uid_hash text, p_places jsonb)
returns int language plpgsql security definer set search_path = public as $$
begin
    if jsonb_typeof(p_places) <> 'array' or jsonb_array_length(p_places) > 5000 then
        raise exception 'bad places';
    end if;
    delete from source_place where uid_hash = p_uid_hash;
    insert into source_place (uid_hash, npc, name, kind, prof, fac, map, x, y)
    select distinct on ((p->>'npc')::int)
           p_uid_hash, (p->>'npc')::int, left(p->>'name', 80), left(p->>'kind', 1), left(p->>'prof', 40),
           left(p->>'fac', 1), (p->>'map')::int, (p->>'x')::real, (p->>'y')::real
    from jsonb_array_elements(p_places) p
    where (p->>'x')::real between 0 and 100 and (p->>'y')::real between 0 and 100;
    return (select count(*) from source_place where uid_hash = p_uid_hash);
end $$;

create or replace function public.refresh_places()
returns void language plpgsql security definer set search_path = public as $$
begin
    delete from community_place;
    insert into community_place (npc, name, kind, prof, fac, map, x, y, seen_by)
    with best_map as (
        select npc, map, count(*) as n,
               row_number() over (partition by npc order by count(*) desc, map) as r
        from source_place group by npc, map
    )
    select s.npc,
           mode() within group (order by s.name),
           mode() within group (order by s.kind),
           mode() within group (order by s.prof),
           mode() within group (order by s.fac),
           b.map,
           round((percentile_cont(0.5) within group (order by s.x))::numeric, 2),
           round((percentile_cont(0.5) within group (order by s.y))::numeric, 2),
           count(*)
    from source_place s join best_map b on b.npc = s.npc and b.map = s.map and b.r = 1
    group by s.npc, b.map;
end $$;

-- "P,npc,name,kind,prof,faction,map,x,y;..." for tools/build-data.mjs (shipped in Data.lua).
create or replace function public.community_places_export()
returns text language sql stable security definer set search_path = public as $$
    select coalesce(string_agg(
        'P,' || npc || ',' || regexp_replace(coalesce(name, '?'), '[,;:/~|]', ' ', 'g') || ',' || coalesce(kind, '') || ',' ||
        regexp_replace(coalesce(prof, ''), '[,;:/~|]', ' ', 'g') || ',' || coalesce(fac, '') || ',' || map || ',' || x || ',' || y,
        ';' order by npc), '')
    from community_place
$$;

revoke all on function public.replace_places(text, jsonb) from public, anon, authenticated;
revoke all on function public.refresh_places() from public, anon, authenticated;
grant execute on function public.replace_places(text, jsonb) to service_role;
grant execute on function public.refresh_places() to service_role;
grant execute on function public.community_places_export() to anon, authenticated;

-- Nightly, ten minutes after the rest of the community data.
select cron.unschedule('haulwise-places') where exists (select 1 from cron.job where jobname = 'haulwise-places');
select cron.schedule('haulwise-places', '27 3 * * *', $$select public.refresh_places()$$);
