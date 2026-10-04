
SELECT
    c.conrelid::regclass AS tabla,
    c.conname AS restriccion,
    pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint AS c
JOIN pg_namespace AS n
    ON n.oid = c.connamespace
WHERE n.nspname = 'public'
  AND c.conrelid IN (
      'public.inventory_balances'::regclass,
      'public.inventory_movements'::regclass,
      'public.inventory_movement_lines'::regclass,
      'public.products'::regclass,
      'public.warehouses'::regclass
  )
ORDER BY tabla, restriccion;
