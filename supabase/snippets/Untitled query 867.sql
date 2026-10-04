
SELECT
    tablename,
    policyname,
    cmd,
    qual AS using_expression,
    with_check AS check_expression
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
