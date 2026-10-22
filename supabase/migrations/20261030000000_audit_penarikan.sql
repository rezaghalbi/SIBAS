-- =============================================================================
-- SIBAS — audit penarikan dan RPC detail transaksi/penarikan
--
-- `transaction_audits` sudah mencatat setoran; penarikan belum punya jejak.
-- Tabel `withdrawal_audits` diisi dari RPC (security definer) saat pengajuan
-- dibuat, disetujui, atau ditolak. RPC detail mengembalikan nama pengaju dan
-- admin penyetuju supaya UI tidak menampilkan UUID mentah.
-- =============================================================================

create table if not exists public.withdrawal_audits (
  id bigserial primary key,
  withdrawal_id uuid not null references public.withdrawals (id) on delete cascade,
  actor_id uuid references public.profiles (id),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists withdrawal_audits_withdrawal_idx
  on public.withdrawal_audits (withdrawal_id, created_at);

alter table public.withdrawal_audits enable row level security;

drop policy if exists withdrawal_audits_select_admin on public.withdrawal_audits;
create policy withdrawal_audits_select_admin on public.withdrawal_audits
  for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Audit pada alur penarikan
-- ---------------------------------------------------------------------------
create or replace function public.create_withdrawal(p_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_available numeric;
  v_row public.withdrawals;
begin
  if v_uid is null then raise exception 'Sesi tidak valid. Silakan login ulang.'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Nominal penarikan harus lebih dari 0.'; end if;

  perform 1 from public.profiles where id = v_uid for update;
  v_available := public.available_balance(v_uid);
  if p_amount > v_available then
    raise exception 'Saldo tersedia tidak mencukupi (tersedia %).', v_available;
  end if;

  insert into public.withdrawals (mahasiswa_id, amount) values (v_uid, p_amount)
  returning * into v_row;

  insert into public.withdrawal_audits (withdrawal_id, actor_id, from_status, to_status, note)
  values (v_row.id, v_uid, null, 'PENDING', 'Pengajuan penarikan dibuat');

  return to_jsonb(v_row);
end;
$function$;

create or replace function public.approve_withdrawal(p_withdrawal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
  v_balance numeric;
begin
  if not public.is_admin() then raise exception 'Hanya admin yang dapat menyetujui penarikan.'; end if;

  select * into v_row from public.withdrawals where id = p_withdrawal_id for update;
  if not found then raise exception 'Pengajuan penarikan tidak ditemukan.'; end if;
  if v_row.status <> 'PENDING' then raise exception 'Pengajuan sudah diproses (status %).', v_row.status; end if;

  select balance into v_balance from public.profiles where id = v_row.mahasiswa_id for update;
  if v_balance < v_row.amount then raise exception 'Saldo mahasiswa tidak mencukupi untuk penarikan ini.'; end if;

  update public.profiles set balance = balance - v_row.amount where id = v_row.mahasiswa_id;
  update public.withdrawals set status = 'APPROVED', verified_by = v_uid, verified_at = now()
  where id = v_row.id returning * into v_row;

  insert into public.withdrawal_audits (withdrawal_id, actor_id, from_status, to_status, note)
  values (v_row.id, v_uid, 'PENDING', 'APPROVED', 'Disetujui admin');

  return to_jsonb(v_row);
end;
$function$;

create or replace function public.reject_withdrawal(p_withdrawal_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
begin
  if not public.is_admin() then raise exception 'Hanya admin yang dapat menolak penarikan.'; end if;
  if p_reason is null or btrim(p_reason) = '' then raise exception 'Alasan penolakan wajib diisi.'; end if;

  select * into v_row from public.withdrawals where id = p_withdrawal_id for update;
  if not found then raise exception 'Pengajuan penarikan tidak ditemukan.'; end if;
  if v_row.status <> 'PENDING' then raise exception 'Pengajuan sudah diproses (status %).', v_row.status; end if;

  update public.withdrawals
  set status = 'REJECTED', rejection_reason = btrim(p_reason), verified_by = v_uid, verified_at = now()
  where id = v_row.id returning * into v_row;

  insert into public.withdrawal_audits (withdrawal_id, actor_id, from_status, to_status, note)
  values (v_row.id, v_uid, 'PENDING', 'REJECTED', btrim(p_reason));

  return to_jsonb(v_row);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Detail untuk layar riwayat: satu panggilan, nama aktor sudah di-resolve.
-- ---------------------------------------------------------------------------
create or replace function public.detail_transaksi(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions;
begin
  select * into v_tx from public.transactions where id = p_id;
  if not found then raise exception 'Transaksi tidak ditemukan.'; end if;
  if not public.is_admin() and v_tx.mahasiswa_id <> v_uid then
    raise exception 'Anda tidak berhak melihat transaksi ini.';
  end if;

  return to_jsonb(v_tx)
    || jsonb_build_object('trash_name', (
         select name from public.trash_types where id = v_tx.trash_type_id))
    || jsonb_build_object('mahasiswa', (
         select jsonb_build_object('full_name', full_name, 'nim', nim)
         from public.profiles where id = v_tx.mahasiswa_id))
    || jsonb_build_object('verifikator', (
         select jsonb_build_object('full_name', full_name)
         from public.profiles where id = v_tx.verified_by))
    || jsonb_build_object('audits', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'from_status', a.from_status,
                  'to_status', a.to_status,
                  'note', a.note,
                  'created_at', a.created_at,
                  'actor_name', p.full_name) order by a.created_at)
         from public.transaction_audits a
         left join public.profiles p on p.id = a.actor_id
         where a.transaction_id = v_tx.id), '[]'::jsonb));
end;
$function$;

create or replace function public.detail_penarikan(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
begin
  select * into v_row from public.withdrawals where id = p_id;
  if not found then raise exception 'Penarikan tidak ditemukan.'; end if;
  if not public.is_admin() and v_row.mahasiswa_id <> v_uid then
    raise exception 'Anda tidak berhak melihat penarikan ini.';
  end if;

  return to_jsonb(v_row)
    || jsonb_build_object('mahasiswa', (
         select jsonb_build_object('full_name', full_name, 'nim', nim)
         from public.profiles where id = v_row.mahasiswa_id))
    || jsonb_build_object('verifikator', (
         select jsonb_build_object('full_name', full_name)
         from public.profiles where id = v_row.verified_by))
    || jsonb_build_object('audits', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'from_status', a.from_status,
                  'to_status', a.to_status,
                  'note', a.note,
                  'created_at', a.created_at,
                  'actor_name', p.full_name) order by a.created_at)
         from public.withdrawal_audits a
         left join public.profiles p on p.id = a.actor_id
         where a.withdrawal_id = v_row.id), '[]'::jsonb));
end;
$function$;

revoke all on function public.detail_transaksi(uuid) from anon;
revoke all on function public.detail_penarikan(uuid) from anon;
grant execute on function public.detail_transaksi(uuid) to authenticated;
grant execute on function public.detail_penarikan(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261030000000', 'audit_penarikan')
on conflict (version) do nothing;
