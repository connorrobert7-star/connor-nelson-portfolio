-- Enable pgvector extension
create extension if not exists vector;

-- Stories table (The Signal)
create table stories (
  id uuid primary key default gen_random_uuid(),
  headline text not null,
  dek text,
  body text not null,
  source_url text not null,
  source_platform text not null,
  category text not null check (category in ('subcultures', 'small-town', 'micro-celebrity')),
  audience_size_estimate integer,
  documentary_score integer not null check (documentary_score between 1 and 10),
  found_at timestamptz not null default now(),
  embedding vector(1536),
  created_at timestamptz not null default now()
);

create index on stories using ivfflat (embedding vector_cosine_ops) with (lists = 100);
create index on stories (found_at);
create index on stories (category);
create index on stories (found_at desc);

alter table stories enable row level security;
create policy "Anon can read stories" on stories
  for select using (true);
create policy "Service role full access on stories" on stories
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Guestbook table
create table guestbook (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Anonymous',
  message text not null,
  created_at timestamptz not null default now()
);

create index on guestbook (created_at desc);

alter table guestbook enable row level security;
create policy "Anyone can read guestbook" on guestbook
  for select using (true);
create policy "Anyone can insert guestbook" on guestbook
  for insert with check (true);
create policy "Service role manages guestbook" on guestbook
  for update using (auth.role() = 'service_role');
create policy "Service role deletes guestbook" on guestbook
  for delete using (auth.role() = 'service_role');

-- Daily photos (Glance Back)
create table daily_photos (
  id uuid primary key default gen_random_uuid(),
  photo_url text not null,
  taken_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index on daily_photos (taken_at desc);

alter table daily_photos enable row level security;
create policy "Anon can read photos" on daily_photos
  for select using (true);
create policy "Service role manages photos" on daily_photos
  for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- Storage bucket (run manually in Supabase dashboard):
-- 1. Go to Storage > New Bucket > name: "photos" > Public: ON
-- 2. Add policy: allow all operations with service key
