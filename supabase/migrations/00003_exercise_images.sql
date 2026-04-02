-- Add exercise demonstration image URLs
ALTER TABLE exercises
  ADD COLUMN image_start_url TEXT,
  ADD COLUMN image_end_url   TEXT;

COMMENT ON COLUMN exercises.image_start_url IS 'URL to start position demonstration image';
COMMENT ON COLUMN exercises.image_end_url IS 'URL to end position demonstration image';

-- Public storage bucket for exercise media (2MB limit, images only)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'exercise-media',
  'exercise-media',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Anyone can read exercise images
CREATE POLICY "Public read exercise media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'exercise-media');

-- Only service role can manage exercise images
CREATE POLICY "Service role upload exercise media"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'exercise-media' AND auth.role() = 'service_role');

CREATE POLICY "Service role update exercise media"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'exercise-media' AND auth.role() = 'service_role');

CREATE POLICY "Service role delete exercise media"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'exercise-media' AND auth.role() = 'service_role');
