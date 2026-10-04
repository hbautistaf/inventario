
ALTER TABLE public.inventory_movement_lines
ADD CONSTRAINT inventory_movement_lines_unique_product_per_movement
UNIQUE (business_id, movement_id, product_id);
