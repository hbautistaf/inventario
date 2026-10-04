
SELECT
    routine_name,
    security_type,
    routine_schema
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'is_business_member';
