-- Coffer community database.
-- Paste into Supabase: SQL Editor -> New query -> Run.
--
-- Privacy: no character names, no account names, no IP addresses are stored. A contributor is a
-- one-way hash of the random id the addon makes; IPs are only hashed (with a daily-changing salt)
-- to rate-limit uploads, and those rows are deleted after 2 days.
--
-- Nobody reads or writes these tables directly: row level security is on with no policies, so
-- the public key can only call the two read-only functions at the bottom. Uploads go through the
-- `submit` edge function, which validates everything and uses the service role.

create table if not exists public.contributors (
    uid_hash    text primary key,
    build       text,
    first_seen  timestamptz not null default now(),
    last_upload timestamptz not null default now(),
    uploads     int not null default 1
);

create table if not exists public.mob_stats (
    uid_hash    text not null references public.contributors on delete cascade,
    npc         int  not null check (npc > 0 and npc < 10000000),
    name        text check (length(name) <= 80),
    min_l       int check (min_l between 0 and 100),
    max_l       int check (max_l between 0 and 100),
    kills       int    not null check (kills between 0 and 100000),
    money       bigint not null default 0 check (money >= 0),
    gathered    int    not null default 0 check (gathered >= 0 and gathered <= kills),
    pp          int    not null default 0 check (pp between 0 and 100000),
    pp_money    bigint not null default 0 check (pp_money >= 0),
    t_intervals int    not null default 0 check (t_intervals >= 0),
    t_seconds   bigint not null default 0 check (t_seconds >= 0),
    zones       jsonb  not null default '{}'::jsonb,
    primary key (uid_hash, npc)
);

create table if not exists public.item_stats (
    uid_hash text not null,
    npc      int  not null,
    bucket   text not null check (bucket in ('drop', 'gather', 'pp')),
    item     int  not null check (item > 0 and item < 10000000),
    k        int  not null check (k >= 0),
    q        int  not null check (q >= k),
    primary key (uid_hash, npc, bucket, item),
    foreign key (uid_hash, npc) references public.mob_stats on delete cascade
);

-- What players saw at trainers and vendors, and what vendors charge for reagents.
create table if not exists public.source_trainer (
    uid_hash text not null references public.contributors on delete cascade,
    recipe   text not null check (length(recipe) <= 80),
    npc      text not null check (length(npc) <= 80),
    zone     text check (length(zone) <= 80),
    cost     int  not null check (cost >= 0),
    skill    int  check (skill between 0 and 1000),
    prof     text check (length(prof) <= 40),
    primary key (uid_hash, recipe, npc)
);

create table if not exists public.source_vendor (
    uid_hash text not null references public.contributors on delete cascade,
    recipe   text not null check (length(recipe) <= 80),
    npc      text not null check (length(npc) <= 80),
    zone     text check (length(zone) <= 80),
    price    int  not null check (price >= 0),
    limited  boolean not null default false,
    item     int  check (item >= 0 and item < 10000000),
    primary key (uid_hash, recipe, npc)
);

create table if not exists public.vendor_buy (
    uid_hash text not null references public.contributors on delete cascade,
    item     int  not null check (item > 0 and item < 10000000),
    price    int  not null check (price > 0),
    primary key (uid_hash, item)
);

create table if not exists public.recipe_items (
    uid_hash text not null references public.contributors on delete cascade,
    recipe   text not null check (length(recipe) <= 80),
    item     int  not null check (item > 0 and item < 10000000),
    primary key (uid_hash, recipe)
);

create table if not exists public.community_trainer (recipe text, npc text, zone text, cost int, skill int, prof text, seen_by int, primary key (recipe, npc));
create table if not exists public.community_vendor (recipe text, npc text, zone text, price int, limited boolean, item int, seen_by int, primary key (recipe, npc));
create table if not exists public.community_vendor_buy (item int primary key, price int, seen_by int);
create table if not exists public.community_recipe_items (recipe text primary key, item int, seen_by int);

create table if not exists public.upload_limits (
    ip_hash text not null,
    day     date not null default current_date,
    count   int  not null default 0,
    primary key (ip_hash, day)
);

create table if not exists public.community_mobs (
    npc int primary key, name text, min_l int, max_l int,
    kills int, money bigint, gathered int, pp int, pp_money bigint,
    t_intervals int, t_seconds bigint, zones jsonb, contributors int
);

create table if not exists public.community_items (
    npc int, bucket text, item int, k int, q int,
    primary key (npc, bucket, item)
);

create table if not exists public.community_meta (
    id int primary key default 1 check (id = 1),
    refreshed_at timestamptz, contributors int, kills bigint, mobs int, excluded int, build text
);

alter table public.contributors    enable row level security;
alter table public.mob_stats       enable row level security;
alter table public.item_stats      enable row level security;
alter table public.upload_limits   enable row level security;
alter table public.community_mobs  enable row level security;
alter table public.community_items enable row level security;
alter table public.community_meta  enable row level security;
alter table public.source_trainer  enable row level security;
alter table public.source_vendor   enable row level security;
alter table public.vendor_buy      enable row level security;
alter table public.recipe_items    enable row level security;
alter table public.community_trainer      enable row level security;
alter table public.community_vendor       enable row level security;
alter table public.community_vendor_buy   enable row level security;
alter table public.community_recipe_items enable row level security;

-- Upload: replace everything one contributor has sent before (so re-uploading never counts
-- kills twice). Called by the edge function only.
create or replace function public.replace_contribution(p_uid_hash text, p_build text, p_mobs jsonb, p_extra jsonb default '{}'::jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare
    m jsonb;
    b text;
    it jsonb;
    n int := 0;
begin
    if jsonb_typeof(p_mobs) <> 'array' or jsonb_array_length(p_mobs) > 5000 then
        raise exception 'bad mobs';
    end if;

    insert into contributors (uid_hash, build) values (p_uid_hash, left(p_build, 20))
    on conflict (uid_hash) do update
        set build = excluded.build, last_upload = now(), uploads = contributors.uploads + 1;

    delete from mob_stats where uid_hash = p_uid_hash;
    delete from source_trainer where uid_hash = p_uid_hash;
    delete from source_vendor where uid_hash = p_uid_hash;
    delete from vendor_buy where uid_hash = p_uid_hash;
    delete from recipe_items where uid_hash = p_uid_hash;

    insert into source_trainer (uid_hash, recipe, npc, zone, cost, skill, prof)
    select p_uid_hash, left(lower(xt->>'recipe'), 80), left(xt->>'npc', 80), left(xt->>'zone', 80), (xt->>'cost')::int,
           (xt->>'skill')::int, left(xt->>'prof', 40)
    from jsonb_array_elements(coalesce(p_extra->'trainers', '[]'::jsonb)) xt
    on conflict do nothing;

    insert into source_vendor (uid_hash, recipe, npc, zone, price, limited, item)
    select p_uid_hash, left(lower(xv->>'recipe'), 80), left(xv->>'npc', 80), left(xv->>'zone', 80), (xv->>'price')::int,
           coalesce((xv->>'limited')::boolean, false), nullif((xv->>'item')::int, 0)
    from jsonb_array_elements(coalesce(p_extra->'vendors', '[]'::jsonb)) xv
    on conflict do nothing;

    insert into vendor_buy (uid_hash, item, price)
    select p_uid_hash, (xb->>0)::int, (xb->>1)::int
    from jsonb_array_elements(coalesce(p_extra->'buys', '[]'::jsonb)) xb
    where (xb->>1)::int > 0
    on conflict do nothing;

    insert into recipe_items (uid_hash, recipe, item)
    select p_uid_hash, left(lower(xr->>0), 80), (xr->>1)::int
    from jsonb_array_elements(coalesce(p_extra->'recipeItems', '[]'::jsonb)) xr
    on conflict do nothing;

    for m in select * from jsonb_array_elements(p_mobs) loop
        insert into mob_stats (uid_hash, npc, name, min_l, max_l, kills, money, gathered, pp, pp_money,
                               t_intervals, t_seconds, zones)
        values (p_uid_hash, (m->>'npc')::int, left(m->>'name', 80), (m->>'minL')::int, (m->>'maxL')::int,
                (m->>'kills')::int, (m->>'money')::bigint, (m->>'gathered')::int, (m->>'pp')::int,
                (m->>'ppMoney')::bigint, (m->>'tIntervals')::int, (m->>'tSeconds')::bigint,
                coalesce(m->'zones', '{}'::jsonb));
        foreach b in array array['drop', 'gather', 'pp'] loop
            for it in select * from jsonb_array_elements(coalesce(m->(case b when 'drop' then 'items'
                                                                         when 'gather' then 'gather'
                                                                         else 'ppItems' end), '[]'::jsonb)) loop
                insert into item_stats (uid_hash, npc, bucket, item, k, q)
                values (p_uid_hash, (m->>'npc')::int, b, (it->>0)::int, (it->>1)::int, (it->>2)::int);
            end loop;
        end loop;
        n := n + 1;
    end loop;
    return n;
end $$;

create or replace function public.bump_upload_limit(p_ip_hash text)
returns int language plpgsql security definer set search_path = public as $$
declare c int;
begin
    delete from upload_limits where day < current_date - 1;
    insert into upload_limits (ip_hash) values (p_ip_hash)
    on conflict (ip_hash, day) do update set count = upload_limits.count + 1
    returning count into c;
    return c;
end $$;

-- Nightly: pool everyone's data into community_mobs / community_items.
--  * One player can't dominate a mob: anyone with more than 3000 kills of it is scaled down to 3000.
--  * Fake or broken data is dropped: when 3+ players have 30+ kills of a mob, a player whose drop
--    rate for any item is more than 5 standard deviations from the median player's is left out
--    for that mob.
create or replace function public.refresh_community()
returns void language plpgsql security definer set search_path = public as $$
begin
    drop table if exists pg_temp.gp_trials, pg_temp.gp_excluded, pg_temp.gp_keep;

    create temp table gp_trials as
    with w as (
        select uid_hash, npc, kills, gathered, pp,
               least(1.0, 3000.0 / greatest(kills, 1))    as wk,
               least(1.0, 3000.0 / greatest(gathered, 1)) as wg,
               least(1.0, 3000.0 / greatest(pp, 1))       as wp
        from mob_stats where kills > 0
    )
    select uid_hash, npc, 'drop'::text as bucket, kills as n, wk as w from w
    union all select uid_hash, npc, 'gather', gathered, wg from w where gathered > 0
    union all select uid_hash, npc, 'pp', pp, wp from w where pp > 0;

    -- Outliers are judged against the MEDIAN player's drop rate (a cheater can't drag a median),
    -- using each player's capped kill count, so a huge honest farmer isn't flagged over a tiny
    -- difference.
    create temp table gp_excluded as
    with players as (
        select npc, count(*) as c from gp_trials where bucket = 'drop' and n >= 30 group by npc
    ),
    rates as (
        select t.uid_hash, t.npc, t.bucket, i.item, t.n * t.w as n_eff, coalesce(s.k, 0) * t.w as k_eff,
               coalesce(s.k, 0)::float8 / t.n as rate
        from gp_trials t
        join (select distinct npc, bucket, item from item_stats) i on i.npc = t.npc and i.bucket = t.bucket
        left join item_stats s on s.uid_hash = t.uid_hash and s.npc = t.npc and s.bucket = t.bucket and s.item = i.item
        where t.n >= 30
    ),
    typical as (
        select npc, bucket, item, percentile_cont(0.5) within group (order by rate) as p
        from rates group by npc, bucket, item
    )
    select distinct r.uid_hash, r.npc
    from rates r
    join players pl on pl.npc = r.npc and pl.c >= 3
    join typical p on p.npc = r.npc and p.bucket = r.bucket and p.item = r.item
    where r.n_eff * p.p * (1 - p.p) >= 1
      and abs(r.k_eff - r.n_eff * p.p) / sqrt(r.n_eff * p.p * (1 - p.p)) > 5;

    create temp table gp_keep as
    select t.* from gp_trials t
    where not exists (select 1 from gp_excluded e where e.uid_hash = t.uid_hash and e.npc = t.npc);

    delete from community_items;
    delete from community_mobs;

    insert into community_mobs (npc, name, min_l, max_l, kills, money, gathered, pp, pp_money,
                                t_intervals, t_seconds, zones, contributors)
    select m.npc,
           mode() within group (order by m.name),
           min(m.min_l), max(m.max_l),
           round(sum(m.kills * k.w)),
           round(sum(m.money * k.w)),
           round(sum(m.gathered * coalesce(g.w, 0))),
           round(sum(m.pp * coalesce(pp.w, 0))),
           round(sum(m.pp_money * coalesce(pp.w, 0))),
           round(sum(m.t_intervals * k.w)), round(sum(m.t_seconds * k.w)),
           '{}'::jsonb,
           count(*)
    from mob_stats m
    join gp_keep k on k.uid_hash = m.uid_hash and k.npc = m.npc and k.bucket = 'drop'
    left join gp_keep g on g.uid_hash = m.uid_hash and g.npc = m.npc and g.bucket = 'gather'
    left join gp_keep pp on pp.uid_hash = m.uid_hash and pp.npc = m.npc and pp.bucket = 'pp'
    group by m.npc;

    update community_mobs c set zones = z.zones
    from (
        select npc, jsonb_object_agg(zone, n) as zones
        from (
            select m.npc, e.key as zone, sum(e.value::int) as n
            from mob_stats m
            join gp_keep k on k.uid_hash = m.uid_hash and k.npc = m.npc and k.bucket = 'drop'
            cross join lateral jsonb_each_text(m.zones) e
            group by m.npc, e.key
        ) zz group by npc
    ) z where z.npc = c.npc;

    insert into community_items (npc, bucket, item, k, q)
    select s.npc, s.bucket, s.item, round(sum(s.k * k.w)), round(sum(s.q * k.w))
    from item_stats s
    join gp_keep k on k.uid_hash = s.uid_hash and k.npc = s.npc and k.bucket = s.bucket
    group by s.npc, s.bucket, s.item
    having round(sum(s.k * k.w)) > 0;

    -- Trainers, vendors, vendor prices: the value most players saw wins.
    delete from community_trainer;
    insert into community_trainer (recipe, npc, zone, cost, skill, prof, seen_by)
    select recipe, npc, mode() within group (order by zone), mode() within group (order by cost),
           mode() within group (order by skill), mode() within group (order by prof), count(*)
    from source_trainer group by recipe, npc;

    delete from community_vendor;
    insert into community_vendor (recipe, npc, zone, price, limited, item, seen_by)
    select recipe, npc, mode() within group (order by zone), mode() within group (order by price),
           bool_or(limited), mode() within group (order by item), count(*)
    from source_vendor group by recipe, npc;

    delete from community_vendor_buy;
    insert into community_vendor_buy (item, price, seen_by)
    select item, mode() within group (order by price), count(*) from vendor_buy group by item;

    delete from community_recipe_items;
    insert into community_recipe_items (recipe, item, seen_by)
    select recipe, mode() within group (order by item), count(*) from recipe_items group by recipe;

    insert into community_meta (id, refreshed_at, contributors, kills, mobs, excluded, build)
    select 1, now(),
           (select count(*) from contributors),
           (select coalesce(sum(kills), 0) from community_mobs),
           (select count(*) from community_mobs),
           (select count(*) from gp_excluded),
           (select mode() within group (order by build) from contributors where last_upload > now() - interval '30 days')
    on conflict (id) do update set refreshed_at = excluded.refreshed_at, contributors = excluded.contributors,
        kills = excluded.kills, mobs = excluded.mobs, excluded = excluded.excluded, build = excluded.build;

    drop table if exists pg_temp.gp_trials, pg_temp.gp_excluded, pg_temp.gp_keep;
end $$;

-- Public, read-only: the pooled data as a Coffer import string (same format as /coffer export).
create or replace function public.community_export()
returns text language sql stable security definer set search_path = public as $$
    with items as (
        select npc, bucket, string_agg(item || ':' || k || ':' || q, '/' order by item) as s
        from community_items group by npc, bucket
    )
    select concat_ws(';',
        'CF2,community,Community,' || coalesce(extract(epoch from (select refreshed_at from community_meta))::bigint, 0)
            || ',' || coalesce((select build from community_meta), '') || ','
            || coalesce((select contributors from community_meta), 0),
        (select string_agg(concat_ws(',',
            m.npc, regexp_replace(coalesce(m.name, ''), '[,;:/~|]', ' ', 'g'),
            coalesce(m.min_l, 0), coalesce(m.max_l, 0), m.kills, m.money, m.gathered, m.pp, m.pp_money,
            m.t_intervals, m.t_seconds,
            coalesce((select string_agg(regexp_replace(z.key, '[,;:/~|]', ' ', 'g') || ':' || z.value, '/')
                      from jsonb_each_text(m.zones) z), ''),
            coalesce(d.s, ''), coalesce(g.s, ''), coalesce(p.s, '')), ';' order by m.npc)
         from community_mobs m
         left join items d on d.npc = m.npc and d.bucket = 'drop'
         left join items g on g.npc = m.npc and g.bucket = 'gather'
         left join items p on p.npc = m.npc and p.bucket = 'pp'
         where m.kills > 0),
        (select string_agg(concat_ws(',', 'T', regexp_replace(recipe, '[,;:/~|]', ' ', 'g'), regexp_replace(npc, '[,;:/~|]', ' ', 'g'),
                regexp_replace(coalesce(zone, '?'), '[,;:/~|]', ' ', 'g'), cost, coalesce(skill, 0), regexp_replace(coalesce(prof, ''), '[,;:/~|]', ' ', 'g')), ';')
         from community_trainer),
        (select string_agg(concat_ws(',', 'V', regexp_replace(recipe, '[,;:/~|]', ' ', 'g'), regexp_replace(npc, '[,;:/~|]', ' ', 'g'),
                regexp_replace(coalesce(zone, '?'), '[,;:/~|]', ' ', 'g'), price, case when limited then 1 else 0 end, coalesce(item, 0)), ';')
         from community_vendor),
        (select string_agg('B,' || item || ',' || price, ';') from community_vendor_buy),
        (select string_agg('R,' || regexp_replace(recipe, '[,;:/~|]', ' ', 'g') || ',' || item, ';') from community_recipe_items)
    );
$$;

create or replace function public.community_stats()
returns json language sql stable security definer set search_path = public as $$
    select json_build_object('refreshed_at', refreshed_at, 'contributors', contributors, 'kills', kills,
                             'mobs', mobs, 'build', build,
                             'trainers', (select count(*) from community_trainer),
                             'vendors', (select count(*) from community_vendor))
    from community_meta where id = 1;
$$;

revoke all on function public.replace_contribution(text, text, jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.bump_upload_limit(text) from public, anon, authenticated;
revoke all on function public.refresh_community() from public, anon, authenticated;
grant execute on function public.community_export() to anon, authenticated;
grant execute on function public.community_stats() to anon, authenticated;
grant execute on function public.replace_contribution(text, text, jsonb, jsonb) to service_role;
grant execute on function public.bump_upload_limit(text) to service_role;
grant execute on function public.refresh_community() to service_role;
