
ALTER TABLE public.inventory_movement_lines
ADD COLUMN IF NOT EXISTS physical_count numeric
CHECK (physical_count IS NULL OR physical_count >= 0);
