-- ═══════════════════════════════════════════════════════════════
-- ChatApp - Supabase Database Schema
-- Run this entire script in: Supabase → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Users table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT DEFAULT '',
  profile_image_url TEXT DEFAULT '',
  status        TEXT DEFAULT 'Hey there! I am using ChatApp',
  is_online     BOOLEAN DEFAULT FALSE,
  last_seen     TIMESTAMPTZ DEFAULT NOW(),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 2. Chats table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.chats (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id              UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user2_id              UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_message          TEXT,
  last_message_type     TEXT DEFAULT 'text',
  unread_count_user1    INTEGER DEFAULT 0,
  unread_count_user2    INTEGER DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- ─── 3. Messages table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id             UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id           UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  receiver_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content             TEXT NOT NULL DEFAULT '',
  type                TEXT NOT NULL DEFAULT 'text',
  status              TEXT NOT NULL DEFAULT 'sent',
  file_url            TEXT,
  file_name           TEXT,
  file_size           BIGINT,
  is_deleted          BOOLEAN DEFAULT FALSE,
  reply_to_message_id UUID REFERENCES public.messages(id),
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 4. Indexes for performance ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_messages_chat_id   ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender    ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver  ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created   ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_chats_user1        ON public.chats(user1_id);
CREATE INDEX IF NOT EXISTS idx_chats_user2        ON public.chats(user2_id);
CREATE INDEX IF NOT EXISTS idx_chats_updated      ON public.chats(updated_at DESC);

-- ─── 5. Row Level Security (RLS) ─────────────────────────────────────────────
ALTER TABLE public.users    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users: anyone logged in can read; only self can update
CREATE POLICY "Users: read all"
  ON public.users FOR SELECT
  TO authenticated
  USING (TRUE);

CREATE POLICY "Users: insert own"
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users: update own"
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Chats: only participants can read/write
CREATE POLICY "Chats: participants only"
  ON public.chats FOR ALL
  TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Messages: only chat participants can read/write
CREATE POLICY "Messages: participants only"
  ON public.messages FOR ALL
  TO authenticated
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- ─── 6. Enable Realtime on tables ────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;

-- ─── 7. Auto-update updated_at on chats ──────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER chats_updated_at
  BEFORE UPDATE ON public.chats
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── Done! ────────────────────────────────────────────────────────────────────
-- After running this script, go to:
-- Supabase → Storage → Create two buckets:
--   1. "chat-files"  (public)
--   2. "avatars"     (public)
