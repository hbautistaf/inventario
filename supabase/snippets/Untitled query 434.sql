
BEGIN;

ALTER TABLE public.inventory_movements
ADD COLUMN IF NOT EXISTS reversal_of uuid;

ALTER TABLE public.inventory_movements
ADD CONSTRAINT inventory_movements_reversal_of_fkey
FOREIGN KEY (business_id, reversal_of)
REFERENCES public.inventory_movements (business_id, id);

ALTER TABLE public.inventory_movements
ADD CONSTRAINT inventory_movements_one_reversal_per_original
UNIQUE (business_id, reversal_of);

COMMIT;
