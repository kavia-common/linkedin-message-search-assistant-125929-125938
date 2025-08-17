-- 000_init.sql
-- Initializes core database objects for LinkedIn Message Search:
-- - Enable required extensions (pgvector, pgcrypto)
-- - Create tables: profiles, linkedin_connections, conversations, messages, message_chunks, sync_state
-- - Indexes (including pgvector ivfflat for message_chunks.embedding)
-- - Triggers for updated_at and automatic profile creation on new auth.users
-- - Helper function for vector search: match_message_chunks()

-- Ensure we're working in the public schema
set search_path = public, extensions;

-- Extensions
create extension if not exists pgcrypto;  -- for gen_random_uuid()
create extension if not exists vector;    -- for embeddings

-- Timestamp trigger for updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Profiles
-- Mirrors the authenticated user in a public profile table.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_email on public.profiles (email);

create or replace trigger trg_profiles_set_updated
before update on public.profiles
for each row execute procedure public.set_updated_at();

-- Automatically create a profile row when a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = coalesce(excluded.full_name, public.profiles.full_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- LinkedIn OAuth connections per user
create table if not exists public.linkedin_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'linkedin',
  provider_account_id text,
  access_token text,
  refresh_token text,
  scope text,
  expires_at timestamptz,
  profile_id text,       -- LinkedIn profile ID
  profile_name text,     -- friendly profile name
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

create index if not exists idx_linkedin_connections_user on public.linkedin_connections(user_id);

create or replace trigger trg_linkedin_connections_set_updated
before update on public.linkedin_connections
for each row execute procedure public.set_updated_at();

-- Conversations
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  external_id text not null, -- LinkedIn conversation identifier
  title text,
  participants jsonb,        -- array of participant identifiers/names
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, external_id)
);

create index if not exists idx_conversations_user on public.conversations(user_id);
create index if not exists idx_conversations_last_message_at on public.conversations(last_message_at);

create or replace trigger trg_conversations_set_updated
before update on public.conversations
for each row execute procedure public.set_updated_at();

-- Messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  external_id text,     -- LinkedIn message identifier
  sender_id text,
  sent_at timestamptz,
  body text,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, external_id)
);

create index if not exists idx_messages_user on public.messages(user_id);
create index if not exists idx_messages_conversation_sent_at on public.messages(conversation_id, sent_at);
create index if not exists idx_messages_sent_at on public.messages(sent_at);

create or replace trigger trg_messages_set_updated
before update on public.messages
for each row execute procedure public.set_updated_at();

-- Message chunks (for embeddings / vector search on message content)
-- Use 1536-dim vectors (compatible with many OpenAI embeddings). Adjust if needed.
create table if not exists public.message_chunks (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  chunk_index int not null,
  content text not null,
  embedding vector(1536),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (message_id, chunk_index)
);

create index if not exists idx_message_chunks_user on public.message_chunks(user_id);
create index if not exists idx_message_chunks_message on public.message_chunks(message_id);
-- Vector index (Approximate NN)
-- Note: This index is global; ensure queries filter by user_id to keep search scoped and performant.
create index if not exists idx_message_chunks_embedding_ivfflat
on public.message_chunks
using ivfflat (embedding vector_cosine_ops)
with (lists = 100);

create or replace trigger trg_message_chunks_set_updated
before update on public.message_chunks
for each row execute procedure public.set_updated_at();

-- Sync state per user/provider
create table if not exists public.sync_state (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'linkedin',
  cursor text,
  status text,             -- e.g., 'idle', 'running', 'error'
  error text,              -- last error details if any
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

create index if not exists idx_sync_state_user on public.sync_state(user_id);

create or replace trigger trg_sync_state_set_updated
before update on public.sync_state
for each row execute procedure public.set_updated_at();

-- Helper function: match_message_chunks for vector similarity search
-- Returns chunks for the current authenticated user only.
create or replace function public.match_message_chunks(
  query_embedding vector(1536),
  match_count int default 10,
  similarity_threshold float default 0.7
)
returns table (
  id bigint,
  message_id uuid,
  content text,
  similarity float
)
language sql
stable
set search_path = public, extensions
as $$
  select
    mc.id,
    mc.message_id,
    mc.content,
    1 - (mc.embedding <=> query_embedding) as similarity
  from public.message_chunks mc
  where mc.user_id = auth.uid()
    and mc.embedding is not null
    and (1 - (mc.embedding <=> query_embedding)) >= similarity_threshold
  order by mc.embedding <=> query_embedding
  limit match_count
$$;

comment on function public.match_message_chunks is
  'Per-user vector similarity search over message_chunks. Requires queries to run with an authenticated JWT (auth.uid()).';

-- End of 000_init.sql
