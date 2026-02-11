-- Memoria persistente por sesion para mejorar contexto y respuestas exactas.
create table if not exists public.bot_session_memory (
  session_id text not null,
  bot_id uuid not null,
  summary text,
  first_user_message text,
  last_user_message text,
  last_bot_reply text,
  last_intent_score integer not null default 0,
  last_detected_goal text,
  message_count integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bot_session_memory_pk primary key (session_id, bot_id)
);

create index if not exists bot_session_memory_bot_id_idx
  on public.bot_session_memory (bot_id);

create index if not exists bot_session_memory_updated_at_idx
  on public.bot_session_memory (updated_at desc);
