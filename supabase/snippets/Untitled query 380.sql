
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'businesses',
      'business_members',
      'inventory_balances',
      'inventory_movements',
      'inventory_movement_lines'
  )
ORDER BY table_name, ordinal_position;
