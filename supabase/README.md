# Supabase Setup: Schema, RLS, and Vector Search

This folder contains SQL files to initialize the Supabase database for the LinkedIn Message Search Assistant. It enables pgvector for embeddings, creates tables with owner-only Row Level Security (RLS), adds triggers for profile creation and timestamps, and provides a helper function for vector similarity search.

## Files

- `sql/000_init.sql`  
  Creates extensions (`pgcrypto`, `vector`), tables (`profiles`, `linkedin_connections`, `conversations`, `messages`, `message_chunks`, `sync_state`), indexes (including `ivfflat` for vector search), triggers (`updated_at` and profile auto-insert), and the vector search function `match_message_chunks`.

- `sql/010_policies.sql`  
  Enables RLS and defines owner-only policies for all tables. Grants full access to the `service_role` for internal operations.

## Apply the SQL to your Supabase project

1. Open Supabase Dashboard -> SQL Editor.
2. Run the contents of `sql/000_init.sql`.
3. Run the contents of `sql/010_policies.sql`.

Alternatively, you can run these scripts using the Supabase CLI (`supabase db remote commit` / `reset`), or psql connected to your project database.

## Extensions

- `pgcrypto` is used for `gen_random_uuid()`.
- `vector` (pgvector) enables vector columns and similarity indexes for semantic search.

The init script includes:
```sql
create extension if not exists pgcrypto;
create extension if not exists vector;
```

## Ownership and Security

All tables have RLS enabled and are configured with owner-only policies:
- Authenticated users can only access rows where `user_id = auth.uid()` (or `id = auth.uid()` for `profiles`).
- A permissive `service_role` policy is provided for internal operations such as:
  - `auth.users` trigger inserting into `public.profiles`.
  - Backend jobs performing sync or ingestion.

Ensure you keep the `service_role` key only in secure server-side environments.

## Vector Search Usage

The `message_chunks` table stores text chunks and their `embedding vector(1536)`.

An index is created for approximate nearest neighbor search:
```sql
create index if not exists idx_message_chunks_embedding_ivfflat
on public.message_chunks using ivfflat (embedding vector_cosine_ops) with (lists = 100);
```

A helper function scopes search to the current authenticated user:
```sql
select * from public.match_message_chunks(
  -- supply your 1536-d embedding vector here
  ARRAY[0.01, 0.02, ...]::vector(1536),
  10,   -- top-k
  0.70  -- similarity threshold
);
```

Tips:
- Always filter by `user_id` when querying `message_chunks` directly:
  ```sql
  select id, message_id, content, 1 - (embedding <=> ARRAY[...]::vector(1536)) as similarity
  from public.message_chunks
  where user_id = auth.uid()
  order by embedding <=> ARRAY[...]::vector(1536)
  limit 10;
  ```

## Table Overview

- `public.profiles`: Mirrors `auth.users`; auto-created via trigger on user creation.  
- `public.linkedin_connections`: Stores LinkedIn OAuth tokens/metadata for the user.  
- `public.conversations`: LinkedIn conversation metadata per user.  
- `public.messages`: Messages belonging to a conversation.  
- `public.message_chunks`: Chunked message text with per-chunk embeddings for semantic search.  
- `public.sync_state`: Sync cursors and status per user/provider.

All tables include `created_at` and `updated_at` with a `set_updated_at` trigger for updates.

## Applying in Dev and Prod

- Run `000_init.sql` then `010_policies.sql` in each environment.
- After running, verify:
  - Extensions exist (`select * from pg_available_extensions where name in ('vector','pgcrypto');`)
  - Tables exist (`select table_name from information_schema.tables where table_schema='public';`)
  - RLS enabled (`select relname, relrowsecurity, relforcerowsecurity from pg_class join pg_namespace on ...;` or via the UI)
  - Indexes created (via Table Editor -> Indexes or `\d+` in psql)

## Frontend/Backend Integration Notes

Environment variables are required to connect to the Supabase project:

Frontend (React):
- `REACT_APP_SUPABASE_URL`
- `REACT_APP_SUPABASE_ANON_KEY`

Backend (if applicable):
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (never expose to the client)
- `OPENAI_API_KEY` (or other embedding provider) for generating embeddings

Make sure to allow redirect URLs in Supabase Dashboard:
- Authentication -> URL Configuration
  - Site URL: your domain or http://localhost:3000
  - Additional Redirect URLs: http://localhost:3000/** and your production domain /**

## Embedding Generation

The database schema assumes 1536-dimensional embeddings. If you use a different model, update:
- `message_chunks.embedding` dimension in `000_init.sql`
- Any queries and functions casting vectors (e.g., `::vector(1536)`)

## Troubleshooting

- If profile insertion fails during sign-up, ensure the `profiles` table policies are present and that `service_role` has access (provided in `010_policies.sql`). The `handle_new_user` trigger runs as `security definer` and relies on these settings.
- If vector index creation fails, make sure the `vector` extension is enabled before creating the index.
- When querying via `match_message_chunks`, ensure the session is authenticated so `auth.uid()` is available within SQL.

---
Last updated: Generated by Supabase configuration scripts for LinkedIn Message Search Assistant.
