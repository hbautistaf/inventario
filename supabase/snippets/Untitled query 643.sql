
BEGIN;

ALTER TABLE public.inventory_movement_lines
ADD COLUMN adjustment_direction text;

ALTER TABLE public.inventory_movement_lines
ADD CONSTRAINT inventory_line_adjustment_direction_check
CHECK (
    adjustment_direction IS NULL
    OR adjustment_direction IN ('increase', 'decrease')
);

COMMIT;
