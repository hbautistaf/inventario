
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
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
ORDER BY tablename, policyname;

