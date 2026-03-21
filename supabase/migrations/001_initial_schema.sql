create table if not exists public.posts (
  magnet_id text not null,
  content_type text not null,
  text_content text not null,
  media_url text,
  author_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.widget_push_tokens (
  magnet_id text not null,
  device_token text not null,
  updated_at timestamptz not null default now(),
  primary key (magnet_id, device_token)
);

create index if not exists widget_push_tokens_magnet_id_updated_at_idx
  on public.widget_push_tokens (magnet_id, updated_at desc);
