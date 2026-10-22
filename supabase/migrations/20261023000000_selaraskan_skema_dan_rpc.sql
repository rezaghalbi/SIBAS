-- =============================================================================
-- SIBAS — menyelaraskan database remote dengan rancangan 20261022000000
--
-- Database remote dibuat manual sebelum migration ada, sehingga tertinggal:
-- tanpa kolom tx_code/qr_token/saldo, tanpa tabel audit & penarikan, RPC lama
-- menerima p_admin_id dari klien dan tidak memeriksa role pemanggil.
--
-- Migration ini idempoten: aman dijalankan pada database lama maupun baru.
-- Tidak ada data yang dihapus, kecuali tabel `verifications` yang sudah
-- digantikan kolom verified_by/verified_at + transaction_audits.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- profiles: email, saldo, akumulasi berat
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists email text;
alter table public.profiles
  add column if not exists balance numeric(14, 2) not null default 0;
alter table public.profiles
  add column if not exists total_weight numeric(12, 2) not null default 0;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_balance_check') then
    alter table public.profiles
      add constraint profiles_balance_check check (balance >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_total_weight_check') then
    alter table public.profiles
      add constraint profiles_total_weight_check check (total_weight >= 0);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- trash_types: kolom unit/deskripsi dan nama unik (database lama belum punya)
-- -----------------------------------------------------------------------------
alter table public.trash_types add column if not exists unit text not null default 'kg';
alter table public.trash_types add column if not exists description text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'trash_types_name_key') then
    alter table public.trash_types add constraint trash_types_name_key unique (name);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- transactions: kode transaksi, token QR, snapshot harga, hasil verifikasi
-- -----------------------------------------------------------------------------
create sequence if not exists public.tx_code_seq;

alter table public.transactions add column if not exists tx_code text;
alter table public.transactions add column if not exists qr_token text;
alter table public.transactions
  add column if not exists price_per_kg_snapshot numeric(12, 2) not null default 0;
alter table public.transactions add column if not exists final_amount numeric(14, 2);
alter table public.transactions add column if not exists rejection_reason text;
alter table public.transactions add column if not exists verified_by uuid;
alter table public.transactions add column if not exists verified_at timestamptz;

update public.transactions
set tx_code = 'BS-' || to_char(created_at, 'YYYY') || '-' ||
      lpad(nextval('public.tx_code_seq')::text, 4, '0')
where tx_code is null;

update public.transactions
set qr_token = replace(id::text, '-', '')
where qr_token is null;

alter table public.transactions alter column tx_code set not null;
alter table public.transactions alter column qr_token set not null;
alter table public.transactions
  alter column qr_expires_at set default now() + interval '2 hours';
alter table public.transactions alter column qr_expires_at set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'transactions_tx_code_key') then
    alter table public.transactions
      add constraint transactions_tx_code_key unique (tx_code);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'transactions_qr_token_key') then
    alter table public.transactions
      add constraint transactions_qr_token_key unique (qr_token);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'transactions_verified_by_fkey') then
    alter table public.transactions
      add constraint transactions_verified_by_fkey
      foreign key (verified_by) references public.profiles (id);
  end if;
end $$;

-- FK lama memakai RESTRICT; rancangan memakai cascade agar menghapus user
-- tidak menyisakan transaksi yatim.
alter table public.transactions drop constraint if exists transactions_mahasiswa_id_fkey;
alter table public.transactions
  add constraint transactions_mahasiswa_id_fkey
  foreign key (mahasiswa_id) references public.profiles (id) on delete cascade;

update public.transactions t
set price_per_kg_snapshot = tt.price_per_kg
from public.trash_types tt
where tt.id = t.trash_type_id and t.price_per_kg_snapshot = 0;

-- -----------------------------------------------------------------------------
-- Tabel audit & penarikan saldo
-- -----------------------------------------------------------------------------
create table if not exists public.transaction_audits (
  id bigserial primary key,
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  actor_id uuid references public.profiles (id),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.withdrawals (
  id uuid primary key default gen_random_uuid(),
  mahasiswa_id uuid not null references public.profiles (id) on delete cascade,
  amount numeric(14, 2) not null check (amount > 0),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  rejection_reason text,
  verified_by uuid references public.profiles (id),
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists transactions_mahasiswa_created_idx
  on public.transactions (mahasiswa_id, created_at desc);
create index if not exists transactions_status_idx
  on public.transactions (status);
create index if not exists withdrawals_mahasiswa_status_idx
  on public.withdrawals (mahasiswa_id, status);
create index if not exists transaction_audits_transaction_idx
  on public.transaction_audits (transaction_id, created_at desc);

-- -----------------------------------------------------------------------------
-- Profil otomatis. Role SELALU mahasiswa; admin hanya lewat Dashboard/seed.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, nim, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'nim', ''),
    'mahasiswa'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Helper
-- -----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.available_balance(p_user uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(p.balance, 0) - coalesce((
    select sum(w.amount) from public.withdrawals w
    where w.mahasiswa_id = p_user and w.status = 'PENDING'
  ), 0)
  from public.profiles p
  where p.id = p_user;
$$;

-- -----------------------------------------------------------------------------
-- RPC: setoran
-- -----------------------------------------------------------------------------
create or replace function public.create_deposit(
  p_trash_type_id uuid,
  p_weight numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_price numeric;
  v_tx public.transactions;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid. Silakan login ulang.';
  end if;
  if p_weight is null or p_weight <= 0 then
    raise exception 'Berat sampah harus lebih dari 0 kg.';
  end if;

  select price_per_kg into v_price
  from public.trash_types
  where id = p_trash_type_id and is_active;
  if v_price is null then
    raise exception 'Jenis sampah tidak ditemukan atau tidak aktif.';
  end if;

  insert into public.transactions (
    tx_code, qr_token, mahasiswa_id, trash_type_id,
    weight, price_per_kg_snapshot, estimated_amount
  ) values (
    'BS-' || to_char(now(), 'YYYY') || '-' ||
      lpad(nextval('public.tx_code_seq')::text, 4, '0'),
    replace(gen_random_uuid()::text, '-', ''),
    v_uid, p_trash_type_id,
    p_weight, v_price, round(p_weight * v_price, 2)
  )
  returning * into v_tx;

  insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
  values (v_tx.id, v_uid, null, 'PENDING', 'Pengajuan setoran dibuat');

  return to_jsonb(v_tx) || jsonb_build_object(
    'trash_types', (
      select jsonb_build_object('name', name, 'price_per_kg', price_per_kg)
      from public.trash_types where id = p_trash_type_id
    )
  );
end;
$$;

create or replace function public.get_transaction_by_qr(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat membuka transaksi.';
  end if;

  select jsonb_build_object(
    'id', t.id,
    'tx_code', t.tx_code,
    'mahasiswa_id', t.mahasiswa_id,
    'trash_type_id', t.trash_type_id,
    'weight', t.weight,
    'price_per_kg_snapshot', t.price_per_kg_snapshot,
    'estimated_amount', t.estimated_amount,
    'final_amount', t.final_amount,
    'status', t.status,
    'rejection_reason', t.rejection_reason,
    'verified_by', t.verified_by,
    'verified_at', t.verified_at,
    'created_at', t.created_at,
    'qr_expires_at', t.qr_expires_at,
    'profiles', jsonb_build_object('full_name', p.full_name, 'nim', p.nim),
    'trash_types', jsonb_build_object('name', tt.name, 'price_per_kg', tt.price_per_kg)
  )
  into v_result
  from public.transactions t
  left join public.profiles p on p.id = t.mahasiswa_id
  left join public.trash_types tt on tt.id = t.trash_type_id
  where t.qr_token = p_code or t.id::text = p_code
  limit 1;

  return v_result;
end;
$$;

create or replace function public.approve_transaction(p_transaction_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menyetujui setoran.';
  end if;

  select * into v_tx
  from public.transactions
  where id = p_transaction_id
  for update;

  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;
  if v_tx.status <> 'PENDING' then
    raise exception 'Transaksi sudah diproses (status %).', v_tx.status;
  end if;
  -- Status dikembalikan, bukan raise: raise exception akan membatalkan
  -- update EXPIRED di atas sehingga QR tetap PENDING.
  if v_tx.qr_expires_at <= now() then
    update public.transactions set status = 'EXPIRED' where id = v_tx.id returning * into v_tx;
    insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
    values (v_tx.id, v_uid, 'PENDING', 'EXPIRED', 'QR kedaluwarsa saat akan disetujui');
    return to_jsonb(v_tx);
  end if;

  update public.transactions
  set status = 'APPROVED',
      final_amount = round(v_tx.weight * v_tx.price_per_kg_snapshot, 2),
      verified_by = v_uid,
      verified_at = now()
  where id = v_tx.id
  returning * into v_tx;

  update public.profiles
  set total_weight = total_weight + v_tx.weight,
      balance = balance + coalesce(v_tx.final_amount, 0)
  where id = v_tx.mahasiswa_id;

  insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
  values (v_tx.id, v_uid, 'PENDING', 'APPROVED', 'Disetujui admin');

  return to_jsonb(v_tx);
end;
$$;

create or replace function public.reject_transaction(
  p_transaction_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menolak setoran.';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Alasan penolakan wajib diisi.';
  end if;

  select * into v_tx
  from public.transactions
  where id = p_transaction_id
  for update;

  if not found then
    raise exception 'Transaksi tidak ditemukan.';
  end if;
  if v_tx.status <> 'PENDING' then
    raise exception 'Transaksi sudah diproses (status %).', v_tx.status;
  end if;
  if v_tx.qr_expires_at <= now() then
    update public.transactions set status = 'EXPIRED' where id = v_tx.id returning * into v_tx;
    insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
    values (v_tx.id, v_uid, 'PENDING', 'EXPIRED', 'QR kedaluwarsa saat akan ditolak');
    return to_jsonb(v_tx);
  end if;

  update public.transactions
  set status = 'REJECTED',
      rejection_reason = btrim(p_reason),
      verified_by = v_uid,
      verified_at = now()
  where id = v_tx.id
  returning * into v_tx;

  insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
  values (v_tx.id, v_uid, 'PENDING', 'REJECTED', btrim(p_reason));

  return to_jsonb(v_tx);
end;
$$;

create or replace function public.expire_stale_transactions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_count integer := 0;
begin
  for v_row in
    select id from public.transactions
    where status = 'PENDING' and qr_expires_at <= now()
    for update skip locked
  loop
    update public.transactions set status = 'EXPIRED' where id = v_row.id;
    insert into public.transaction_audits (transaction_id, from_status, to_status, note)
    values (v_row.id, 'PENDING', 'EXPIRED', 'QR kedaluwarsa otomatis');
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC: penarikan saldo
-- -----------------------------------------------------------------------------
create or replace function public.create_withdrawal(p_amount numeric)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_available numeric;
  v_row public.withdrawals;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid. Silakan login ulang.';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Nominal penarikan harus lebih dari 0.';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  v_available := public.available_balance(v_uid);
  if p_amount > v_available then
    raise exception 'Saldo tersedia tidak mencukupi (tersedia %).', v_available;
  end if;

  insert into public.withdrawals (mahasiswa_id, amount)
  values (v_uid, p_amount)
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.approve_withdrawal(p_withdrawal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
  v_balance numeric;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menyetujui penarikan.';
  end if;

  select * into v_row
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'Pengajuan penarikan tidak ditemukan.';
  end if;
  if v_row.status <> 'PENDING' then
    raise exception 'Pengajuan sudah diproses (status %).', v_row.status;
  end if;

  select balance into v_balance
  from public.profiles
  where id = v_row.mahasiswa_id
  for update;

  if v_balance < v_row.amount then
    raise exception 'Saldo mahasiswa tidak mencukupi untuk penarikan ini.';
  end if;

  update public.profiles
  set balance = balance - v_row.amount
  where id = v_row.mahasiswa_id;

  update public.withdrawals
  set status = 'APPROVED', verified_by = v_uid, verified_at = now()
  where id = v_row.id
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.reject_withdrawal(
  p_withdrawal_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menolak penarikan.';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Alasan penolakan wajib diisi.';
  end if;

  select * into v_row
  from public.withdrawals
  where id = p_withdrawal_id
  for update;

  if not found then
    raise exception 'Pengajuan penarikan tidak ditemukan.';
  end if;
  if v_row.status <> 'PENDING' then
    raise exception 'Pengajuan sudah diproses (status %).', v_row.status;
  end if;

  update public.withdrawals
  set status = 'REJECTED', rejection_reason = btrim(p_reason),
      verified_by = v_uid, verified_at = now()
  where id = v_row.id
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

-- Versi lama menerima p_admin_id dari klien sehingga identitas admin bisa
-- dipalsukan. Hapus setelah versi baru (tanpa p_admin_id) dibuat.
drop function if exists public.approve_transaction(uuid, uuid);
drop function if exists public.reject_transaction(uuid, uuid, text);

-- -----------------------------------------------------------------------------
-- RLS: hapus seluruh policy lama (termasuk `Profiles - Read access` dengan
-- qual = true yang membocorkan seluruh NIM), lalu pasang policy final.
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.trash_types enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_audits enable row level security;
alter table public.withdrawals enable row level security;

do $$
declare
  r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy trash_types_select on public.trash_types
  for select to authenticated using (true);

create policy trash_types_admin_write on public.trash_types
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy transactions_select on public.transactions
  for select to authenticated
  using (mahasiswa_id = auth.uid() or public.is_admin());

create policy withdrawals_select on public.withdrawals
  for select to authenticated
  using (mahasiswa_id = auth.uid() or public.is_admin());

create policy audits_admin_select on public.transaction_audits
  for select to authenticated using (public.is_admin());

-- -----------------------------------------------------------------------------
-- Hak eksekusi fungsi
-- -----------------------------------------------------------------------------
revoke execute on function public.create_deposit(uuid, numeric) from public, anon;
revoke execute on function public.get_transaction_by_qr(text) from public, anon;
revoke execute on function public.approve_transaction(uuid) from public, anon;
revoke execute on function public.reject_transaction(uuid, text) from public, anon;
revoke execute on function public.expire_stale_transactions() from public, anon;
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.available_balance(uuid) from public, anon;
revoke execute on function public.create_withdrawal(numeric) from public, anon;
revoke execute on function public.approve_withdrawal(uuid) from public, anon;
revoke execute on function public.reject_withdrawal(uuid, text) from public, anon;

grant execute on function public.create_deposit(uuid, numeric) to authenticated;
grant execute on function public.get_transaction_by_qr(text) to authenticated;
grant execute on function public.approve_transaction(uuid) to authenticated;
grant execute on function public.reject_transaction(uuid, text) to authenticated;
grant execute on function public.create_withdrawal(numeric) to authenticated;
grant execute on function public.approve_withdrawal(uuid) to authenticated;
grant execute on function public.reject_withdrawal(uuid, text) to authenticated;

-- expire_stale_transactions sengaja hanya untuk service_role (cron), bukan klien.
revoke execute on function public.expire_stale_transactions() from authenticated;

-- -----------------------------------------------------------------------------
-- Tabel verifikasi lama digantikan kolom verified_by/verified_at + audit.
-- -----------------------------------------------------------------------------
drop table if exists public.verifications;

-- -----------------------------------------------------------------------------
-- Seed jenis sampah (nilai DEMO, ubah lewat menu admin)
-- -----------------------------------------------------------------------------
insert into public.trash_types (name, unit, price_per_kg, description)
values
  ('Sampah Plastik', 'kg', 2500, 'Botol PET, tutup botol, kemasan plastik bersih'),
  ('Kertas & Karton', 'kg', 1800, 'Kardus, kertas HVS bekas, koran, buku bekas'),
  ('Kaleng & Logam', 'kg', 5000, 'Kaleng minuman, aluminium, kawat, besi tipis'),
  ('Kaca & Botol Beling', 'kg', 1000, 'Botol sirup, kecap, toples kaca utuh tidak pecah'),
  ('Minyak Jelantah', 'kg', 4000, 'Minyak goreng bekas dalam jeriken tertutup')
on conflict (name) do nothing;
