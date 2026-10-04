
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
      'businesses',
      'business_members',
      'warehouses',
      'products',
      'inventory_balances',
      'inventory_movements',
      'inventory_movement_lines'
  )
ORDER BY tablename;
