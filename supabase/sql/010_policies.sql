-- 010_policies.sql
-- Enables RLS and configures owner-only policies for all tables.
-- Also grants full access to service_role for internal operations (e.g., auth triggers, backend jobs).

-- Helpers for DRY policy rules:
-- Note: 'authenticated' and 'service_role' are Supabase built-in roles.

-- Profiles
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

-- Allow service role full access
drop policy if exists "profiles service role access" on public.profiles;
create policy "profiles service role access"
on public.profiles
for all
to service_role
using (true)
with check (true);

-- Owner policies
drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Insert typically occurs via trigger from auth.users.
-- Allow authenticated users to upsert their own profile if needed.
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

-- LinkedIn Connections
alter table public.linkedin_connections enable row level security;
alter table public.linkedin_connections force row level security;

drop policy if exists "linkedin_connections service role access" on public.linkedin_connections;
create policy "linkedin_connections service role access"
on public.linkedin_connections
for all
to service_role
using (true)
with check (true);

drop policy if exists "linkedin_connections owner select" on public.linkedin_connections;
create policy "linkedin_connections owner select"
on public.linkedin_connections
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "linkedin_connections owner insert" on public.linkedin_connections;
create policy "linkedin_connections owner insert"
on public.linkedin_connections
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "linkedin_connections owner update" on public.linkedin_connections;
create policy "linkedin_connections owner update"
on public.linkedin_connections
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "linkedin_connections owner delete" on public.linkedin_connections;
create policy "linkedin_connections owner delete"
on public.linkedin_connections
for delete
to authenticated
using (auth.uid() = user_id);

-- Conversations
alter table public.conversations enable row level security;
alter table public.conversations force row level security;

drop policy if exists "conversations service role access" on public.conversations;
create policy "conversations service role access"
on public.conversations
for all
to service_role
using (true)
with check (true);

drop policy if exists "conversations owner select" on public.conversations;
create policy "conversations owner select"
on public.conversations
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "conversations owner insert" on public.conversations;
create policy "conversations owner insert"
on public.conversations
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "conversations owner update" on public.conversations;
create policy "conversations owner update"
on public.conversations
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "conversations owner delete" on public.conversations;
create policy "conversations owner delete"
on public.conversations
for delete
to authenticated
using (auth.uid() = user_id);

-- Messages
alter table public.messages enable row level security;
alter table public.messages force row level security;

drop policy if exists "messages service role access" on public.messages;
create policy "messages service role access"
on public.messages
for all
to service_role
using (true)
with check (true);

drop policy if exists "messages owner select" on public.messages;
create policy "messages owner select"
on public.messages
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "messages owner insert" on public.messages;
create policy "messages owner insert"
on public.messages
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "messages owner update" on public.messages;
create policy "messages owner update"
on public.messages
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "messages owner delete" on public.messages;
create policy "messages owner delete"
on public.messages
for delete
to authenticated
using (auth.uid() = user_id);

-- Message Chunks
alter table public.message_chunks enable row level security;
alter table public.message_chunks force row level security;

drop policy if exists "message_chunks service role access" on public.message_chunks;
create policy "message_chunks service role access"
on public.message_chunks
for all
to service_role
using (true)
with check (true);

drop policy if exists "message_chunks owner select" on public.message_chunks;
create policy "message_chunks owner select"
on public.message_chunks
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "message_chunks owner insert" on public.message_chunks;
create policy "message_chunks owner insert"
on public.message_chunks
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "message_chunks owner update" on public.message_chunks;
create policy "message_chunks owner update"
on public.message_chunks
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "message_chunks owner delete" on public.message_chunks;
create policy "message_chunks owner delete"
on public.message_chunks
for delete
to authenticated
using (auth.uid() = user_id);

-- Sync State
alter table public.sync_state enable row level security;
alter table public.sync_state force row level security;

drop policy if exists "sync_state service role access" on public.sync_state;
create policy "sync_state service role access"
on public.sync_state
for all
to service_role
using (true)
with check (true);

drop policy if exists "sync_state owner select" on public.sync_state;
create policy "sync_state owner select"
on public.sync_state
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "sync_state owner insert" on public.sync_state;
create policy "sync_state owner insert"
on public.sync_state
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "sync_state owner update" on public.sync_state;
create policy "sync_state owner update"
on public.sync_state
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "sync_state owner delete" on public.sync_state;
create policy "sync_state owner delete"
on public.sync_state
for delete
to authenticated
using (auth.uid() = user_id);

-- End of 010_policies.sql
