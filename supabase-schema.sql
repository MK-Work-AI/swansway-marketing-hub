-- ============================================================
-- SWANSWAY MARKETING HUB — Supabase Schema
-- Run this once in your Supabase project SQL Editor
-- Project: https://app.supabase.com → SQL Editor → New query
-- ============================================================

-- ── EXTENSIONS ──────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── PROFILES ────────────────────────────────────────────────
-- Extends Supabase auth.users with display name + role
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  role        text default 'marketer', -- 'marketer' | 'manager' | 'admin'
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
comment on table public.profiles is 'Swansway marketing team members';

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── BRIEFS ──────────────────────────────────────────────────
create table if not exists public.briefs (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  
  -- Identity
  title            text not null default 'Untitled Brief',
  status           text not null default 'draft'  -- 'draft' | 'final' | 'archived'
                   check (status in ('draft','final','archived')),

  -- Brand
  brand_id         text not null,               -- e.g. 'audi', 'byd', 'cupra'
  brand_name       text not null,               -- e.g. 'Audi'
  brand_color      text,                        -- hex e.g. '#BB0A21'

  -- Campaign
  campaign_type_id text,                        -- e.g. 'plate', 'launch', 'ev'
  campaign_type    text,                        -- e.g. 'Plate Change'
  objective_id     text,                        -- e.g. 'leads', 'units'
  objective        text,                        -- full text
  objective_kpi    text,
  objective_funnel text,

  -- Budget
  budget           integer not null default 0,  -- in GBP
  duration_weeks   integer,
  duration_label   text,

  -- Audiences (array of audience IDs)
  audience_ids     text[] default '{}',
  audiences        jsonb default '[]',          -- full audience objects

  -- Channels (PESO)
  channel_ids      text[] default '{}',
  channels         jsonb default '[]',

  -- Allocation
  allocation       jsonb default '[]',          -- [{n, p, c}]

  -- Proposition
  proposition      text,
  mandatories      text,

  -- Computed KPIs (stored for reporting)
  kpi_primary_label  text,
  kpi_primary_value  text,
  kpi_cpl_meta       integer,
  kpi_cpl_search     integer,

  -- Sites
  locations        text[],

  -- Notes
  notes            text,

  -- Timestamps
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

comment on table public.briefs is 'Campaign briefs built in the Swansway Brief Builder';
comment on column public.briefs.status is 'draft = in progress, final = signed off, archived = historical';

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger briefs_set_updated_at
  before update on public.briefs
  for each row execute procedure public.set_updated_at();

-- ── ROW LEVEL SECURITY ───────────────────────────────────────
-- Users can only see and edit their own briefs.
-- Managers can see all briefs for their team (future extension).

alter table public.profiles enable row level security;
alter table public.briefs   enable row level security;

-- Profiles: users can read/update their own profile
create policy "profiles: own read"   on public.profiles for select using (auth.uid() = id);
create policy "profiles: own update" on public.profiles for update using (auth.uid() = id);

-- Briefs: full CRUD on own briefs only
create policy "briefs: own select" on public.briefs for select using (auth.uid() = user_id);
create policy "briefs: own insert" on public.briefs for insert with check (auth.uid() = user_id);
create policy "briefs: own update" on public.briefs for update using (auth.uid() = user_id);
create policy "briefs: own delete" on public.briefs for delete using (auth.uid() = user_id);

-- ── INDEXES ──────────────────────────────────────────────────
create index if not exists briefs_user_id_idx    on public.briefs(user_id);
create index if not exists briefs_brand_id_idx   on public.briefs(brand_id);
create index if not exists briefs_status_idx     on public.briefs(status);
create index if not exists briefs_created_at_idx on public.briefs(created_at desc);

-- ── VIEWS ────────────────────────────────────────────────────
-- Useful read-only view for dashboards
create or replace view public.briefs_summary as
select
  b.id,
  b.user_id,
  p.full_name as author,
  b.title,
  b.status,
  b.brand_id,
  b.brand_name,
  b.campaign_type,
  b.objective,
  b.budget,
  b.duration_weeks,
  b.proposition,
  b.kpi_primary_value,
  array_length(b.audience_ids, 1) as audience_count,
  array_length(b.channel_ids, 1)  as channel_count,
  b.created_at,
  b.updated_at
from public.briefs b
left join public.profiles p on p.id = b.user_id;

-- ── GRANT PERMISSIONS ─────────────────────────────────────────
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.briefs   to authenticated;
grant select, update                  on public.profiles to authenticated;
grant select on public.briefs_summary to authenticated;


-- ── BRAND QUARTERLY PLANS ─────────────────────────────────────
create table if not exists public.brand_plans (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  brand_id    text not null,
  brand_name  text not null,
  quarter     text not null,  -- e.g. 'Q2 2026'
  year        text,
  filename    text,
  extracted   jsonb not null default '{}', -- full Claude-extracted plan
  status      text default 'active' check (status in ('active','archived')),
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

comment on table public.brand_plans is 'Manufacturer quarterly campaign plans uploaded and processed by Claude';

create trigger brand_plans_set_updated_at
  before update on public.brand_plans
  for each row execute procedure public.set_updated_at();

alter table public.brand_plans enable row level security;

create policy "brand_plans: own select" on public.brand_plans for select using (auth.uid() = user_id);
create policy "brand_plans: own insert" on public.brand_plans for insert with check (auth.uid() = user_id);
create policy "brand_plans: own update" on public.brand_plans for update using (auth.uid() = user_id);
create policy "brand_plans: own delete" on public.brand_plans for delete using (auth.uid() = user_id);

create index if not exists brand_plans_user_brand_idx on public.brand_plans(user_id, brand_id);
create index if not exists brand_plans_created_at_idx on public.brand_plans(created_at desc);

grant select, insert, update, delete on public.brand_plans to authenticated;


-- ── CAMPAIGN AUTOPSIES ───────────────────────────────────────
create table if not exists public.autopsies (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  brand_id    text, brand_name text,
  data        jsonb not null default '{}',
  created_at  timestamptz default now(), updated_at timestamptz default now()
);
alter table public.autopsies enable row level security;
create policy "autopsies: own" on public.autopsies for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.autopsies to authenticated;

-- ── BUDGET ACTUALS ───────────────────────────────────────────
create table if not exists public.budget_actuals (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null default '{}',
  updated_at  timestamptz default now()
);
alter table public.budget_actuals enable row level security;
create policy "budget_actuals: own" on public.budget_actuals for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.budget_actuals to authenticated;

-- ── COMPETITOR SCANS ─────────────────────────────────────────
create table if not exists public.competitor_scans (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null default '{}',
  created_at  timestamptz default now()
);
alter table public.competitor_scans enable row level security;
create policy "competitor_scans: own" on public.competitor_scans for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.competitor_scans to authenticated;


-- ── ADMIN CONFIG ─────────────────────────────────────────────
-- Stores the full admin dashboard configuration per user
-- One row per user — upserted on every save
create table if not exists public.admin_config (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  config      jsonb not null default '{}',
  updated_at  timestamptz default now()
);
alter table public.admin_config enable row level security;
create policy "admin_config: own" on public.admin_config for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.admin_config to authenticated;

-- ── ADMIN SNAPSHOTS ──────────────────────────────────────────
-- Point-in-time snapshots of admin config (for history/audit)
create table if not exists public.admin_snapshots (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null,
  config      jsonb not null default '{}',
  created_at  timestamptz default now()
);
alter table public.admin_snapshots enable row level security;
create policy "admin_snapshots: own" on public.admin_snapshots for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.admin_snapshots to authenticated;


-- ── QPLAN ACTION STATE ───────────────────────────────────────
-- Q-plan tick-off checkboxes per brand/quarter
create table if not exists public.qplan_actions (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  key         text not null,   -- e.g. 'qplan_actions_audi_Q2 2026'
  data        jsonb not null default '{}',
  updated_at  timestamptz default now(),
  unique(user_id, key)
);
alter table public.qplan_actions enable row level security;
create policy "qplan_actions: own" on public.qplan_actions for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.qplan_actions to authenticated;

-- ── ADMIN CONFIG ─────────────────────────────────────────────
create table if not exists public.admin_config (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  config      jsonb not null default '{}',
  updated_at  timestamptz default now()
);
alter table public.admin_config enable row level security;
create policy "admin_config: own" on public.admin_config for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.admin_config to authenticated;

-- ── ADMIN SNAPSHOTS ──────────────────────────────────────────
create table if not exists public.admin_snapshots (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null,
  config      jsonb not null default '{}',
  created_at  timestamptz default now()
);
alter table public.admin_snapshots enable row level security;
create policy "admin_snapshots: own" on public.admin_snapshots for all using (auth.uid() = user_id);
grant select, insert, update, delete on public.admin_snapshots to authenticated;

-- ── DONE ─────────────────────────────────────────────────────
-- After running this schema:
-- 1. Go to Authentication → Settings → enable Email auth
-- 2. Go to Project Settings → API → copy URL and anon key
-- 3. Paste them into index.html where marked SUPABASE_URL / SUPABASE_ANON_KEY
-- ─────────────────────────────────────────────────────────────
