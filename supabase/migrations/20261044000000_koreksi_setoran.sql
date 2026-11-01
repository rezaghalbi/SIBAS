-- =============================================================================
-- SIBAS — koreksi berat setoran APPROVED
--
-- Menyesuaikan berat dan nominal final berdasarkan harga snapshot, lalu
-- menyesuaikan total berat/saldo mahasiswa. Status tetap APPROVED (bukan
-- pembatalan); semua perubahan dicatat di transaction_audits.
-- =============================================================================

create or replace function public.koreksi_setoran(
  p_transaction_id uuid,
  p_weight numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions;
  v_lama numeric;
  v_baru numeric;
  v_delta_berat numeric;
  v_delta_nominal numeric;
  v_saldo numeric;
  v_alasan text := btrim(coalesce(p_reason, ''));
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengoreksi setoran.';
  end if;
  if p_weight is null or p_weight <= 0 then
    raise exception 'Berat koreksi harus lebih dari 0 kg.';
  end if;
  if v_alasan = '' then
    raise exception 'Alasan koreksi wajib diisi.';
  end if;

  select * into v_tx
  from public.transactions
  where id = p_transaction_id
  for update;
  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;
  if v_tx.status <> 'APPROVED' then
    raise exception 'Hanya setoran APPROVED yang dapat dikoreksi.';
  end if;

  v_lama := coalesce(v_tx.final_amount, round(v_tx.weight * v_tx.price_per_kg_snapshot, 2));
  v_baru := round(p_weight * v_tx.price_per_kg_snapshot, 2);
  v_delta_berat := p_weight - v_tx.weight;
  v_delta_nominal := v_baru - v_lama;

  select balance into v_saldo
  from public.profiles
  where id = v_tx.mahasiswa_id
  for update;

  if v_saldo + v_delta_nominal < 0 then
    raise exception 'Saldo mahasiswa tidak cukup untuk koreksi ini.';
  end if;

  update public.transactions
  set weight = p_weight,
      final_amount = v_baru
  where id = v_tx.id
  returning * into v_tx;

  update public.profiles
  set total_weight = total_weight + v_delta_berat,
      balance = balance + v_delta_nominal
  where id = v_tx.mahasiswa_id;

  insert into public.transaction_audits (
    transaction_id, actor_id, from_status, to_status, note
  ) values (
    v_tx.id,
    v_uid,
    'APPROVED',
    'APPROVED',
    format('Koreksi berat %s -> %s kg. Nominal %s -> %s. Alasan: %s',
           v_tx.weight - v_delta_berat, p_weight, v_lama, v_baru, v_alasan)
  );

  return to_jsonb(v_tx) || jsonb_build_object(
    'delta_weight', v_delta_berat,
    'delta_amount', v_delta_nominal
  );
end;
$function$;

revoke all on function public.koreksi_setoran(uuid, numeric, text)
  from public, anon;
grant execute on function public.koreksi_setoran(uuid, numeric, text)
  to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261044000000', 'koreksi_setoran')
on conflict (version) do nothing;
