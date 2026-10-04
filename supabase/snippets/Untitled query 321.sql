
SELECT
    c.relname AS table_name,
    t.tgname AS trigger_name,
    p.proname AS trigger_function,
    t.tgenabled AS enabled_status
FROM pg_trigger AS t
JOIN pg_class AS c ON c.oid = t.tgrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
JOIN pg_proc AS p ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND c.relname IN (
      'inventory_movements',
      'inventory_movement_lines'
  )
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
