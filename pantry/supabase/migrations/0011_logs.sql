-- 0011_logs.sql
-- Debug log for outbound API calls, primarily Instacart (Phase 3). Full request
-- and response bodies are kept on failure so a bad product match or unit mapping
-- can be traced without reproducing it.
--
-- Created in Phase 1 alongside the rest of the schema so there is exactly one
-- migration history to apply, but nothing writes to it until Phase 3.

create table logs (
  id            uuid primary key default gen_random_uuid(),
  source        text not null,              -- 'instacart', 'anthropic', 'edge-function'
  level         text not null default 'error' check (level in ('debug', 'info', 'warn', 'error')),
  event         text not null,              -- 'products.recipe.create', ...
  order_id      uuid references orders (id) on delete set null,
  recipe_id     uuid references recipes (id) on delete set null,
  http_status   integer,
  request_body  jsonb,
  response_body jsonb,
  error_message text,
  created_at    timestamptz not null default now()
);

create index logs_created_at_idx on logs (created_at desc);
create index logs_source_event_idx on logs (source, event, created_at desc);
create index logs_errors_idx on logs (created_at desc) where level = 'error';
