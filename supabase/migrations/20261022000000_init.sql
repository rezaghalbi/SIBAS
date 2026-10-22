-- =============================================================================
-- SIBAS — skema awal, RLS, dan RPC
-- Jalankan lewat Supabase CLI: supabase db push
-- Semua penulisan transaksi/saldo WAJIB lewat RPC di bawah, bukan dari klien.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Tabel
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text not null default '',
  nim text unique,
  role text not null default 'mahasiswa'
    check (role in ('mahasiswa', 'admin')),
  balance numeric(14, 2) not null default 0 check (balance >= 0),
  total_weight numeric(12, 2) not null default 0 check (total_weight >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.trash_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  unit text not null default 'kg',
  price_per_kg numeric(12, 2) not null default 0 check (price_per_kg >= 0),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create sequence if not exists public.tx_code_seq;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  tx_code text not null unique,
  qr_token text not null unique,
  mahasiswa_id uuid not null references public.profiles (id) on delete cascade,
  trash_type_id uuid not null references public.trash_types (id),
  weight numeric(10, 2) not null check (weight > 0),
  price_per_kg_snapshot numeric(12, 2) not null default 0,
  estimated_amount numeric(14, 2) not null default 0,
  final_amount numeric(14, 2),
  status text not null default 'PENDING'
    check (status in ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED')),
  rejection_reason text,
  verified_by uuid references public.profiles (id),
  verified_at timestamptz,
  qr_expires_at timestamptz not null default now() + interval '2 hours',
  created_at timestamptz not null default now()
);

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

-- -----------------------------------------------------------------------------
-- Profil otomatis untuk user baru. Role SELALU mahasiswa; admin dibuat manual.
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
    encode(gen_random_bytes(16), 'hex'),
    v_uid, p_trash_type_id,
    p_weight, v_price, round(p_weight * v_price, 2)
  )
  returning * into v_tx;

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
  -- p_code = qr_token (utama) atau id (kompatibilitas QR lama)
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
  if v_tx.qr_expires_at <= now() then
    update public.transactions set status = 'EXPIRED' where id = v_tx.id;
    insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
    values (v_tx.id, v_uid, 'PENDING', 'EXPIRED', 'QR kedaluwarsa saat akan disetujui');
    raise exception 'QR sudah kedaluwarsa. Minta mahasiswa mengajukan ulang.';
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
    update public.transactions set status = 'EXPIRED' where id = v_tx.id;
    insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
    values (v_tx.id, v_uid, 'PENDING', 'EXPIRED', 'QR kedaluwarsa saat akan ditolak');
    raise exception 'QR sudah kedaluwarsa. Minta mahasiswa mengajukan ulang.';
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

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.trash_types enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_audits enable row level security;
alter table public.withdrawals enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists trash_types_select on public.trash_types;
create policy trash_types_select on public.trash_types
  for select to authenticated using (true);

drop policy if exists trash_types_admin_write on public.trash_types;
create policy trash_types_admin_write on public.trash_types
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists transactions_select on public.transactions;
create policy transactions_select on public.transactions
  for select to authenticated
  using (mahasiswa_id = auth.uid() or public.is_admin());

drop policy if exists withdrawals_select on public.withdrawals;
create policy withdrawals_select on public.withdrawals
  for select to authenticated
  using (mahasiswa_id = auth.uid() or public.is_admin());

drop policy if exists audits_admin_select on public.transaction_audits;
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

-- Akun admin TIDAK dibuat di sini. Buat user lewat Dashboard/Auth Admin API,
-- lalu promosikan dengan:
--   update public.profiles set role = 'admin' where email = 'admin@contoh.ac.id';
