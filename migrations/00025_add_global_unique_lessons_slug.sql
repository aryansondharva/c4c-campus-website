-- Migration: enforce globally unique lesson slugs
--
-- Context: lesson URLs route at /lessons/{slug}, so slugs must be unique
-- across the entire lessons table, not just within a module.
-- The client-side validation already checks globally; this migration
-- adds the matching DB constraint so concurrent inserts and direct SQL
-- writes cannot create duplicates.
--
-- Step 1: resolve any existing duplicate slugs by appending the lesson id.
-- (Safe no-op if no duplicates exist.)
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT slug
    FROM lessons
    GROUP BY slug
    HAVING COUNT(*) > 1
  LOOP
    -- Rename all but the oldest row by appending '-{id}'
    UPDATE lessons
    SET slug = slug || '-' || id
    WHERE slug = rec.slug
      AND id NOT IN (
        SELECT MIN(id) FROM lessons WHERE slug = rec.slug
      );
  END LOOP;
END $$;

-- Step 2: add the global unique constraint.
-- The existing UNIQUE(module_id, slug) is retained for backwards
-- compatibility with any code that still references it.
ALTER TABLE lessons
  ADD CONSTRAINT unique_lessons_slug UNIQUE (slug);
