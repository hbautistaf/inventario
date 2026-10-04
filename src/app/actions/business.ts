'use server';

import { createClient } from '@/utils/supabase/server';
import { revalidatePath } from 'next/cache';

export async function createBusinessAction(formData: FormData) {
  const supabase = await createClient();
  const name = formData.get('name') as string;
  const legalName = formData.get('legal_name') as string;
  const taxId = formData.get('tax_id') as string;
  const currencyCode = (formData.get('currency_code') as string) || 'MXN';

  if (!name || name.trim() === '') {
    throw new Error('El nombre de la empresa es obligatorio');
  }

  const { data, error } = await supabase.rpc('create_business', {
    p_name: name.trim(),
    p_legal_name: legalName ? legalName.trim() : null,
    p_tax_id: taxId ? taxId.trim() : null,
    p_currency_code: currencyCode,
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath('/');
}
