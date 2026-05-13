-- ═══════════════════════════════════════════════════════════════
-- ChatApp - Enhanced Schema for Status Bar Features
-- Run this in: Supabase → SQL Editor → New query
-- Optional: Enhances typing indicators and presence tracking
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Add typing status tracking table ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.typing_status (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  chat_id         UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  is_typing       BOOLEAN DEFAULT FALSE,
  last_activity   TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, chat_id)
);

-- ─── 2. Add user presence tracking (real-time) ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_presence (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status          TEXT DEFAULT 'active',  -- 'active', 'away', 'offline', 'do_not_disturb'
  last_seen       TIMESTAMPTZ DEFAULT NOW(),
  device_info     TEXT,  -- optional: device/platform info
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- ─── 3. Add message delivery status tracking ─────────────────────────────────
-- Status: 'sending', 'sent', 'delivered', 'read', 'failed'
-- Note: 'status' column already exists in messages table, but we can add an index

CREATE INDEX IF NOT EXISTS idx_messages_status 
  ON public.messages(status);

CREATE INDEX IF NOT EXISTS idx_typing_status_active 
  ON public.typing_status(chat_id) 
  WHERE is_typing = TRUE;

CREATE INDEX IF NOT EXISTS idx_user_presence_status 
  ON public.user_presence(status);

-- ─── 4. Auto-clean up old typing status records ──────────────────────────────
CREATE OR REPLACE FUNCTION cleanup_expired_typing_status()
RETURNS void AS $$
BEGIN
  DELETE FROM public.typing_status
  WHERE last_activity < NOW() - INTERVAL '10 seconds'
  AND is_typing = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ─── 5. Auto-update timestamp on typing_status ──────────────────────────────
CREATE OR REPLACE FUNCTION update_typing_status_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER typing_status_updated_at
  BEFORE UPDATE ON public.typing_status
  FOR EACH ROW EXECUTE FUNCTION update_typing_status_timestamp();

-- ─── 6. Auto-update timestamp on user_presence ──────────────────────────────
CREATE OR REPLACE FUNCTION update_user_presence_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_presence_updated_at
  BEFORE UPDATE ON public.user_presence
  FOR EACH ROW EXECUTE FUNCTION update_user_presence_timestamp();

-- ─── 7. Add RLS policies for typing_status ───────────────────────────────────
ALTER TABLE public.typing_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Typing status: participants can read"
  ON public.typing_status FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chats
      WHERE chats.id = typing_status.chat_id
      AND (chats.user1_id = auth.uid() OR chats.user2_id = auth.uid())
    )
  );

CREATE POLICY "Typing status: users can update own"
  ON public.typing_status FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Typing status: users can insert own"
  ON public.typing_status FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ─── 8. Add RLS policies for user_presence ───────────────────────────────────
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "User presence: read all"
  ON public.user_presence FOR SELECT
  TO authenticated
  USING (TRUE);

CREATE POLICY "User presence: users can update own"
  ON public.user_presence FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "User presence: users can insert own"
  ON public.user_presence FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ─── 9. Enable Realtime on new tables ────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_status;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_presence;

-- ─── Notes ───────────────────────────────────────────────────────────────────
-- 1. Typing Status:
--    - User calls updateTypingStatus(true) when they start typing
--    - Updates set last_activity timestamp
--    - Frontend can subscribe to real-time changes for a specific chat_id
--    - Auto-cleanup: typing records older than 10 seconds with is_typing=false get deleted
--
-- 2. User Presence:
--    - Tracks user status: 'active', 'away', 'offline', 'do_not_disturb'
--    - Updated when user opens/closes app or changes status
--    - last_seen timestamp is auto-updated
--
-- 3. Connection Status:
--    - Flutter app uses connectivity_plus to detect network state
--    - ConnectionService syncs this to user_presence.status
--    - Status bar shows user's connection state visually
--
-- 4. Optional Cleanup Job:
--    - Create a Supabase Edge Function or scheduled task to run cleanup_expired_typing_status()
--    - Recommend running every 5-10 seconds to remove stale typing indicators
