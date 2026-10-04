
-- Función auxiliar para comprobar la membresía
-- sin provocar recursión en las políticas RLS.

CREATE OR REPLACE FUNCTION public.is_business_member(
    p_business_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.business_members AS m
        WHERE m.business_id = p_business_id
          AND m.user_id = (SELECT auth.uid())
    );
$$;

-- Limitar quién puede ejecutar la función.
REVOKE ALL ON FUNCTION public.is_business_member(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.is_business_member(uuid)
TO authenticated;

-- Corregir la política de miembros.
DROP POLICY IF EXISTS members_same_business_select
ON public.business_members;

CREATE POLICY members_same_business_select
ON public.business_members
FOR SELECT
TO authenticated
USING (
    public.is_business_member(business_id)
);

-- Corregir la política de empresas.
DROP POLICY IF EXISTS businesses_member_select
ON public.businesses;

CREATE POLICY businesses_member_select
ON public.businesses
FOR SELECT
TO authenticated
USING (
    public.is_business_member(id)
);
