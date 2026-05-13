-- ═══════════════════════════════════════════════════════════════
-- ChatApp - Stories/Status Feature Schema
-- Run this in: Supabase → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- ─── 1. Stories table ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stories (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content_url     TEXT NOT NULL,  -- URL to image/video in storage bucket
  content_type    TEXT NOT NULL,  -- 'image' or 'video'
  caption         TEXT DEFAULT '',
  duration        INTEGER DEFAULT 5,  -- display duration in seconds (for images)
  view_count      INTEGER DEFAULT 0,
  is_deleted      BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  expires_at      TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);

-- ─── 2. Story views table ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.story_views (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id        UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
  viewer_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  viewed_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(story_id, viewer_id)
);

-- ─── 3. Create indexes for performance ───────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_stories_user_id 
  ON public.stories(user_id);

CREATE INDEX IF NOT EXISTS idx_stories_expires_at 
  ON public.stories(expires_at DESC);

CREATE INDEX IF NOT EXISTS idx_stories_created_at 
  ON public.stories(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_story_views_story_id 
  ON public.story_views(story_id);

CREATE INDEX IF NOT EXISTS idx_story_views_viewer_id 
  ON public.story_views(viewer_id);

-- ─── 4. Function to auto-delete expired stories ──────────────────────────────
CREATE OR REPLACE FUNCTION delete_expired_stories()
RETURNS void AS $$
BEGIN
  DELETE FROM public.stories
  WHERE expires_at < NOW()
  AND is_deleted = FALSE;
END;
$$ LANGUAGE plpgsql;

-- ─── 5. Function to get view count ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_story_view_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.stories
  SET view_count = (SELECT COUNT(*) FROM public.story_views WHERE story_id = NEW.story_id)
  WHERE id = NEW.story_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER story_views_count_update
  AFTER INSERT ON public.story_views
  FOR EACH ROW EXECUTE FUNCTION update_story_view_count();

-- ─── 6. Enable RLS on new tables ─────────────────────────────────────────────
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

-- ─── 7. RLS policies for stories ─────────────────────────────────────────────
CREATE POLICY "Stories: users can insert own"
  ON public.stories FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Stories: public can read non-expired"
  ON public.stories FOR SELECT
  TO authenticated
  USING (
    is_deleted = FALSE 
    AND expires_at > NOW()
    AND (
      -- User can see their own stories
      auth.uid() = user_id
      OR
      -- Users can see stories of people they have chats with
      EXISTS (
        SELECT 1 FROM public.chats c
        WHERE (c.user1_id = auth.uid() AND c.user2_id = stories.user_id)
        OR (c.user2_id = auth.uid() AND c.user1_id = stories.user_id)
      )
    )
  );

CREATE POLICY "Stories: users can delete own"
  ON public.stories FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ─── 8. RLS policies for story_views ────────────────────────────────────────
CREATE POLICY "Story views: authenticated users can insert"
  ON public.story_views FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = viewer_id);

CREATE POLICY "Story views: story owner can read"
  ON public.story_views FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.stories s
      WHERE s.id = story_views.story_id
      AND s.user_id = auth.uid()
    )
  );

-- ─── 9. Enable Realtime on new tables ────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.stories;
ALTER PUBLICATION supabase_realtime ADD TABLE public.story_views;

-- ─── Notes ───────────────────────────────────────────────────────────────────
-- 1. Stories automatically expire after 24 hours (expires_at column)
-- 2. Run delete_expired_stories() periodically to clean up old stories
--    (Recommend: Edge Function or cron job)
-- 3. Story views are tracked automatically for analytics
-- 4. View count updates automatically when a view is recorded
-- 5. Stories are only visible to users you have chats with (privacy)
-- 6. Users can only delete/edit their own stories
