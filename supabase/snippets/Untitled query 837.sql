
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'inventory_movement_lines'
  AND column_name IN (
      'business_id',
      'movement_id',
      'product_id',
      'quantity',
      'unit_cost',
      'adjustment_direction',
      'physical_count'
  )
ORDER BY ordinal_position;
