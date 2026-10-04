'use server';

import { createClient } from '@/utils/supabase/server';
import { revalidatePath } from 'next/cache';

export async function loginQuickAction(formData: FormData) {
  const supabase = await createClient();
  const email = (formData.get('email') as string) || 'admin@inventario.local';
  const password = (formData.get('password') as string) || 'Admin123456!';

  // Intentar iniciar sesión
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (signInError) {
    const { error: signUpError } = await supabase.auth.signUp({
      email,
      password,
    });

    if (signUpError) {
      throw new Error(signUpError.message);
    }
  }

  revalidatePath('/');
}

export async function signOutAction() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  revalidatePath('/');
}
