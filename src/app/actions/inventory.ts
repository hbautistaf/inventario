'use server';

import { createClient } from '@/utils/supabase/server';
import { revalidatePath } from 'next/cache';

export async function createProductAction(formData: FormData) {
  const supabase = await createClient();
  const businessId = formData.get('business_id') as string;
  const sku = formData.get('sku') as string;
  const name = formData.get('name') as string;
  const unit = (formData.get('unit') as string) || 'pieza';

  if (!businessId || !sku || !name) {
    throw new Error('Empresa, SKU y Nombre son obligatorios');
  }

  const { error } = await supabase
    .from('products')
    .insert({
      business_id: businessId,
      sku: sku.trim(),
      name: name.trim(),
      unit: unit.trim(),
    });

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath('/');
}

export async function registerMovementAction(formData: FormData) {
  const supabase = await createClient();
  const businessId = formData.get('business_id') as string;
  const warehouseId = formData.get('warehouse_id') as string;
  const productId = formData.get('product_id') as string;
  const movementType = formData.get('movement_type') as 'receipt' | 'issue';
  const quantity = parseFloat(formData.get('quantity') as string);
  const unitCost = formData.get('unit_cost')
    ? parseFloat(formData.get('unit_cost') as string)
    : null;
  const reason = formData.get('reason') as string;

  if (!businessId || !warehouseId || !productId || !movementType || isNaN(quantity) || quantity <= 0) {
    throw new Error('Por favor completa todos los campos requeridos correctamente');
  }

  // 1. Crear movimiento en borrador
  const { data: movementId, error: createError } = await supabase.rpc(
    'create_inventory_movement',
    {
      p_business_id: businessId,
      p_warehouse_id: warehouseId,
      p_movement_type: movementType,
      p_reason: reason || (movementType === 'receipt' ? 'Entrada de almacén' : 'Salida de almacén'),
      p_reference: 'WEB-' + Date.now().toString().slice(-6),
      p_notes: 'Registrado desde la interfaz web',
    }
  );

  if (createError) {
    throw new Error(createError.message);
  }

  // 2. Agregar línea al movimiento
  const { error: lineError } = await supabase.rpc('add_inventory_movement_line', {
    p_business_id: businessId,
    p_movement_id: movementId,
    p_product_id: productId,
    p_quantity: quantity,
    p_unit_cost: movementType === 'receipt' ? unitCost : null,
    p_physical_count: null,
  });

  if (lineError) {
    throw new Error(lineError.message);
  }

  // 3. Confirmar movimiento (post_inventory_movement)
  const { error: postError } = await supabase.rpc('post_inventory_movement', {
    p_movement_id: movementId,
  });

  if (postError) {
    throw new Error(postError.message);
  }

  revalidatePath('/');
}
