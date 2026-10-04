
SELECT
    c.relname AS tabla,
    t.tgname AS trigger,
    t.tgenabled AS habilitado
FROM pg_trigger AS t
JOIN pg_class AS c ON c.oid = t.tgrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
      'inventory_movements',
      'inventory_movement_lines'
  )
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
