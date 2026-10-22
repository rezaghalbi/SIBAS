-- =============================================================================
-- SIBAS — QR penarikan saldo
--
-- Setiap pengajuan penarikan punya token QR unik yang ditampilkan di layar
-- mahasiswa. Admin memindai atau mengetik token di layar Pindai (mode
-- Penarikan) untuk melihat rincian lalu menyetujui. Persetujuan tetap lewat
-- approve_withdrawal agar pengurangan saldo dan audit tidak terduplikasi.
-- =============================================================================

alter table public.withdrawals
  add column if not exists qr_token uuid not null default gen_random_uuid();

create unique index if not exists withdrawals_qr_token_key
  on public.withdrawals (qr_token);

create or replace function public.penarikan_by_qr(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.withdrawals;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat memindai QR penarikan.';
  end if;

  select * into v_row from public.withdrawals where qr_token = p_token;
  if not found then
    raise exception 'Kode QR penarikan tidak dikenali.';
  end if;

  return public.detail_penarikan(v_row.id);
end;
$function$;

create or replace function public.tarik_by_qr(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.withdrawals;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menyetujui QR penarikan.';
  end if;

  select * into v_row from public.withdrawals where qr_token = p_token;
  if not found then
    raise exception 'Kode QR penarikan tidak dikenali.';
  end if;

  -- Status PENDING, kecukupan saldo, dan audit ditangani approve_withdrawal.
  return public.approve_withdrawal(v_row.id);
end;
$function$;

revoke all on function public.penarikan_by_qr(uuid) from anon;
revoke all on function public.tarik_by_qr(uuid) from anon;
grant execute on function public.penarikan_by_qr(uuid) to authenticated;
grant execute on function public.tarik_by_qr(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261032000000', 'qr_penarikan')
on conflict (version) do nothing;
