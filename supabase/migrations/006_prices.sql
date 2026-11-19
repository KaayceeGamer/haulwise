-- Haulwise: auction house prices shared per realm and faction.
-- Run after 001-005: Supabase -> SQL Editor -> New query -> paste -> Run. Safe to run twice.
--
-- Each upload replaces that player's prices for the realm and faction of their last scan (one
-- price per item: the 10th percentile of what was listed). The pool keeps, per realm, faction
-- and item, the median over players whose scan is at most 7 days old, and over all realms the
-- median of those (a rough guess for realms nobody shares from yet). AH prices are public in
-- game, so the per-realm medians are published too, with how many players they're from.

create table if not exists public.source_price (
    uid_hash text not null,
    realm    text not null,
    fac      text not null,  -- 'A' or 'H'
    day      int  not null,  -- days since 1970 of the scan
    item     int  not null,
    price    bigint not null, -- copper per unit
    qty      int  not null,  -- units listed
    primary key (uid_hash, realm, fac, item)
);
create index if not exists source_price_realm on public.source_price (realm, fac, item);

create table if not exists public.community_price (
    realm   text not null,
    fac     text not null,
    item    int  not null,
    price   bigint not null,
    seen_by int  not null,
    day     int  not null,  -- newest scan behind it
    primary key (realm, fac, item)
);

create table if not exists public.community_price_all (
    item    int primary key,
    price   bigint not null,
    realms  int not null
);

alter table public.source_price        enable row level security;
alter table public.community_price     enable row level security;
alter table public.community_price_all enable row level security;

-- p_prices: [[item, price, qty], ...]
create or replace function public.replace_prices(p_uid_hash text, p_realm text, p_fac text, p_day int, p_prices jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare today int := floor(extract(epoch from now()) / 86400);
begin
    if jsonb_typeof(p_prices) <> 'array' or jsonb_array_length(p_prices) > 3000 then raise exception 'bad prices'; end if;
    if p_fac not in ('A', 'H') or length(p_realm) not between 1 and 60 or p_realm ~ '[,;:/~|<>]' then raise exception 'bad realm'; end if;
    if p_day < today - 3 or p_day > today + 1 then raise exception 'scan too old'; end if;
    delete from source_price where uid_hash = p_uid_hash and realm = p_realm and fac = p_fac;
    insert into source_price (uid_hash, realm, fac, day, item, price, qty)
    select distinct on ((e->>0)::int) p_uid_hash, p_realm, p_fac, p_day, (e->>0)::int, (e->>1)::bigint, (e->>2)::int
    from jsonb_array_elements(p_prices) e
    where jsonb_typeof(e) = 'array' and (e->>0)::int between 1 and 9999999
      and (e->>1)::bigint between 1 and 99999999999 and (e->>2)::int between 1 and 999999;
    return (select count(*) from source_price where uid_hash = p_uid_hash and realm = p_realm and fac = p_fac);
end $$;

create or replace function public.refresh_prices()
returns void language plpgsql security definer set search_path = public as $$
declare today int := floor(extract(epoch from now()) / 86400);
begin
    delete from source_price where day < today - 14;
    delete from community_price;
    insert into community_price (realm, fac, item, price, seen_by, day)
    select realm, fac, item, round(percentile_cont(0.5) within group (order by price))::bigint, count(*), max(day)
    from source_price where day >= today - 7
    group by realm, fac, item;
    delete from community_price_all;
    insert into community_price_all (item, price, realms)
    select item, round(percentile_cont(0.5) within group (order by price))::bigint, count(*)
    from community_price group by item;
end $$;

-- "M,item:price:realms/..." for tools/build-data.mjs: the median over all realms, shipped with
-- every release as a rough guess until you scan or import your realm's prices.
create or replace function public.community_prices_export()
returns text language sql stable security definer set search_path = public as $$
    select case when count(*) = 0 then '' else
        'M,' || string_agg(item || ':' || price || ':' || realms, '/' order by item) end
    from community_price_all
$$;

-- Realms with shared prices, for the website's list.
create or replace function public.price_realms()
returns jsonb language sql stable security definer set search_path = public as $$
    select coalesce(jsonb_agg(r order by r->>'realm', r->>'fac'), '[]'::jsonb) from (
        select jsonb_build_object('realm', realm, 'fac', fac, 'items', count(*), 'players', max(seen_by), 'day', max(day)) as r
        from community_price group by realm, fac
    ) x
$$;

-- An import string for one realm and faction: "CF2,prices,<realm>,<time>,,<players>;A,realm,fac,day,..."
create or replace function public.realm_prices(p_realm text, p_fac text)
returns text language sql stable security definer set search_path = public as $$
    select case when count(*) = 0 then '' else
        'CF2,prices,' || regexp_replace(p_realm, '[,;:/~|<>]', ' ', 'g') || ',' || floor(extract(epoch from now()))::bigint
        || ',,' || max(seen_by) || ';A,' || regexp_replace(p_realm, '[,;:/~|<>]', ' ', 'g') || ',' || p_fac || ',' || max(day) || ','
        || string_agg(item || ':' || price || ':' || seen_by, '/' order by item) end
    from community_price where realm = p_realm and fac = p_fac
$$;

revoke all on function public.replace_prices(text, text, text, int, jsonb) from public, anon, authenticated;
revoke all on function public.refresh_prices() from public, anon, authenticated;
grant execute on function public.replace_prices(text, text, text, int, jsonb) to service_role;
grant execute on function public.refresh_prices() to service_role;
grant execute on function public.community_prices_export() to anon, authenticated;
grant execute on function public.price_realms() to anon, authenticated;
grant execute on function public.realm_prices(text, text) to anon, authenticated;

-- Rebuilt every hour with the rest of the community data.
select cron.unschedule(jobname) from cron.job where jobname = 'haulwise-refresh';
select cron.schedule('haulwise-refresh', '17 * * * *',
    $$select public.refresh_community(); select public.refresh_places(); select public.refresh_crafts(); select public.refresh_prices()$$);
