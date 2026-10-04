
SELECT
    t.relname AS table_name,
    c.conname AS constraint_name,
    c.contype AS constraint_type
FROM pg_constraint AS c
JOIN pg_class AS t
    ON t.oid = c.conrelid
JOIN pg_namespace AS n
    ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relname IN (
      'inventory_movements',
      'inventory_movement_lines',
      'inventory_balances'
  )
ORDER BY t.relname, c.conname;
