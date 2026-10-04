SELECT
    tablename,
    policyname,
    qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('businesses', 'business_members')
ORDER BY tablename, policyname;