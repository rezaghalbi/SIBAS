-- =============================================================================
-- Lokasi bank sampah: master lokasi, kolom lokasi pada transaksi/penarikan,
-- dan pembaruan RPC agar setiap pengajuan tercatat pada satu lokasi.
-- =============================================================================

create table if not exists public.bank_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null
    check (char_length(btrim(name)) between 3 and 80),
  address text not null
    check (char_length(btrim(address)) between 3 and 200),
  latitude numeric(9, 6)
    check (latitude is null or latitude between -90 and 90),
  longitude numeric(9, 6)
    check (longitude is null or longitude between -180 and 180),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null
);

create unique index if not exists bank_locations_name_lower_key
  on public.bank_locations (lower(name));

-- Seed hanya bila tabel masih kosong.
insert into public.bank_locations (name, address)
select 'Bank Sampah Poltekkes', 'Poltekkes Kemenkes Yogyakarta'
where not exists (select 1 from public.bank_locations);

-- -----------------------------------------------------------------------------
-- Kolom lokasi pada transaksi dan penarikan
-- -----------------------------------------------------------------------------
alter table public.transactions add column if not exists location_id uuid;
alter table public.withdrawals add column if not exists location_id uuid;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'transactions_location_id_fkey') then
    alter table public.transactions
      add constraint transactions_location_id_fkey
      foreign key (location_id) references public.bank_locations (id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'withdrawals_location_id_fkey') then
    alter table public.withdrawals
      add constraint withdrawals_location_id_fkey
      foreign key (location_id) references public.bank_locations (id) on delete restrict;
  end if;
end $$;

-- Baris lama dipindahkan ke lokasi default (yang paling awal dibuat).
update public.transactions t
set location_id = (
  select l.id from public.bank_locations l order by l.created_at, l.id limit 1
)
where t.location_id is null;

update public.withdrawals w
set location_id = (
  select l.id from public.bank_locations l order by l.created_at, l.id limit 1
)
where w.location_id is null;

create index if not exists transactions_location_created_idx
  on public.transactions (location_id, created_at desc);
create index if not exists withdrawals_location_created_idx
  on public.withdrawals (location_id, created_at desc);

-- -----------------------------------------------------------------------------
-- RLS: mahasiswa hanya melihat lokasi aktif, admin melihat semua.
-- -----------------------------------------------------------------------------
alter table public.bank_locations enable row level security;

drop policy if exists bank_locations_select on public.bank_locations;
create policy bank_locations_select on public.bank_locations
  for select to authenticated
  using (public.is_admin() or is_active);

drop policy if exists bank_locations_admin_insert on public.bank_locations;
create policy bank_locations_admin_insert on public.bank_locations
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists bank_locations_admin_update on public.bank_locations;
create policy bank_locations_admin_update on public.bank_locations
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists bank_locations_admin_delete on public.bank_locations;
create policy bank_locations_admin_delete on public.bank_locations
  for delete to authenticated
  using (public.is_admin());

revoke insert, update, delete on public.bank_locations from anon;
grant select on public.bank_locations to authenticated;

-- -----------------------------------------------------------------------------
-- RPC: baca dan kelola lokasi
-- -----------------------------------------------------------------------------
create or replace function public.get_locations()
returns table (
  id uuid,
  name text,
  address text,
  latitude numeric,
  longitude numeric,
  is_active boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select l.id, l.name, l.address, l.latitude, l.longitude, l.is_active
  from public.bank_locations l
  where public.is_admin() or l.is_active
  order by l.name;
$$;

create or replace function public.simpan_lokasi(
  p_id uuid,
  p_name text,
  p_address text,
  p_latitude numeric default null,
  p_longitude numeric default null,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_address text := btrim(coalesce(p_address, ''));
  v_row public.bank_locations;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menyimpan lokasi bank sampah.';
  end if;

  if char_length(v_name) < 3 or char_length(v_name) > 80 then
    raise exception 'Nama lokasi harus 3 sampai 80 karakter.';
  end if;
  if char_length(v_address) < 3 or char_length(v_address) > 200 then
    raise exception 'Alamat lokasi harus 3 sampai 200 karakter.';
  end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then
    raise exception 'Latitude harus antara -90 dan 90.';
  end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then
    raise exception 'Longitude harus antara -180 dan 180.';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Latitude dan longitude harus diisi bersamaan.';
  end if;

  if p_id is null then
    begin
      insert into public.bank_locations (
        name, address, latitude, longitude, is_active, created_by
      ) values (
        v_name, v_address, p_latitude, p_longitude,
        coalesce(p_is_active, true), auth.uid()
      )
      returning * into v_row;
    exception when unique_violation then
      raise exception 'Nama lokasi sudah dipakai.';
    end;
  else
    begin
      update public.bank_locations
      set name = v_name,
          address = v_address,
          latitude = p_latitude,
          longitude = p_longitude,
          is_active = coalesce(p_is_active, true),
          updated_at = now()
      where id = p_id
      returning * into v_row;
    exception when unique_violation then
      raise exception 'Nama lokasi sudah dipakai.';
    end;

    if v_row.id is null then
      raise exception 'Lokasi bank sampah tidak ditemukan.';
    end if;
  end if;

  return to_jsonb(v_row);
end;
$$;

create or replace function public.hapus_lokasi(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menghapus lokasi bank sampah.';
  end if;

  select true into v_exists from public.bank_locations where id = p_id;
  if v_exists is null then
    raise exception 'Lokasi bank sampah tidak ditemukan.';
  end if;

  if exists (select 1 from public.transactions where location_id = p_id)
     or exists (select 1 from public.withdrawals where location_id = p_id) then
    update public.bank_locations
    set is_active = false, updated_at = now()
    where id = p_id;
    return jsonb_build_object('dihapus', false);
  end if;

  delete from public.bank_locations where id = p_id;
  return jsonb_build_object('dihapus', true);
end;
$$;

-- -----------------------------------------------------------------------------
-- create_deposit: lokasi wajib tersedia, TTL tetap dari app_settings.
-- Versi lama dihapus agar tidak ada overload tanpa p_location_id.
-- -----------------------------------------------------------------------------
drop function if exists public.create_deposit(uuid, numeric);

create or replace function public.create_deposit(
  p_trash_type_id uuid,
  p_weight numeric,
  p_location_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_price numeric;
  v_ttl integer;
  v_loc public.bank_locations;
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

  if p_location_id is null then
    select * into v_loc
    from public.bank_locations
    where is_active
    order by created_at, id
    limit 1;
    if v_loc.id is null then
      raise exception 'Lokasi bank sampah belum tersedia.';
    end if;
  else
    select * into v_loc
    from public.bank_locations
    where id = p_location_id and is_active;
    if v_loc.id is null then
      raise exception 'Lokasi bank sampah tidak ditemukan atau tidak aktif.';
    end if;
  end if;

  select qr_ttl_minutes into v_ttl from public.app_settings where id = 1;
  v_ttl := coalesce(v_ttl, 120);

  insert into public.transactions (
    tx_code, qr_token, mahasiswa_id, trash_type_id, location_id,
    weight, price_per_kg_snapshot, estimated_amount, qr_expires_at
  ) values (
    'BS-' || to_char(now(), 'YYYY') || '-' ||
      lpad(nextval('public.tx_code_seq')::text, 4, '0'),
    replace(gen_random_uuid()::text, '-', ''),
    v_uid, p_trash_type_id, v_loc.id,
    p_weight, v_price, round(p_weight * v_price, 2),
    now() + make_interval(mins => v_ttl)
  )
  returning * into v_tx;

  insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
  values (v_tx.id, v_uid, null, 'PENDING', 'Pengajuan setoran dibuat di ' || v_loc.name);

  return to_jsonb(v_tx) || jsonb_build_object(
    'trash_types', (
      select jsonb_build_object('name', name, 'price_per_kg', price_per_kg)
      from public.trash_types where id = p_trash_type_id
    ),
    'location', jsonb_build_object(
      'id', v_loc.id,
      'name', v_loc.name,
      'address', v_loc.address,
      'latitude', v_loc.latitude,
      'longitude', v_loc.longitude
    )
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- create_withdrawal: logika lokasi sama dengan setoran.
-- -----------------------------------------------------------------------------
drop function if exists public.create_withdrawal(numeric);

create or replace function public.create_withdrawal(
  p_amount numeric,
  p_location_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_available numeric;
  v_loc public.bank_locations;
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

  if p_location_id is null then
    select * into v_loc
    from public.bank_locations
    where is_active
    order by created_at, id
    limit 1;
    if v_loc.id is null then
      raise exception 'Lokasi bank sampah belum tersedia.';
    end if;
  else
    select * into v_loc
    from public.bank_locations
    where id = p_location_id and is_active;
    if v_loc.id is null then
      raise exception 'Lokasi bank sampah tidak ditemukan atau tidak aktif.';
    end if;
  end if;

  insert into public.withdrawals (mahasiswa_id, amount, location_id)
  values (v_uid, p_amount, v_loc.id)
  returning * into v_row;

  insert into public.withdrawal_audits (withdrawal_id, actor_id, from_status, to_status, note)
  values (v_row.id, v_uid, null, 'PENDING',
    'Pengajuan penarikan dibuat di ' || v_loc.name);

  return to_jsonb(v_row) || jsonb_build_object(
    'location', jsonb_build_object(
      'id', v_loc.id,
      'name', v_loc.name,
      'address', v_loc.address,
      'latitude', v_loc.latitude,
      'longitude', v_loc.longitude
    )
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- Detail riwayat: tambah objek location, aturan akses tidak berubah.
-- -----------------------------------------------------------------------------
create or replace function public.detail_transaksi(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    || jsonb_build_object('location', case
         when v_tx.location_id is null then null
         else (select jsonb_build_object(
                        'id', l.id, 'name', l.name, 'address', l.address,
                        'latitude', l.latitude, 'longitude', l.longitude)
               from public.bank_locations l where l.id = v_tx.location_id)
       end)
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
$$;

create or replace function public.detail_penarikan(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    || jsonb_build_object('location', case
         when v_row.location_id is null then null
         else (select jsonb_build_object(
                        'id', l.id, 'name', l.name, 'address', l.address,
                        'latitude', l.latitude, 'longitude', l.longitude)
               from public.bank_locations l where l.id = v_row.location_id)
       end)
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
$$;

-- -----------------------------------------------------------------------------
-- tarik_by_qr: validasi & status tetap lewat approve_withdrawal, hanya
-- ditambah lokasi pada respons. Signature tetap uuid agar cocok dengan klien.
-- -----------------------------------------------------------------------------
create or replace function public.tarik_by_qr(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.withdrawals;
  v_result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menyetujui QR penarikan.';
  end if;

  select * into v_row from public.withdrawals where qr_token = p_token;
  if not found then
    raise exception 'Kode QR penarikan tidak dikenali.';
  end if;

  v_result := public.approve_withdrawal(v_row.id);

  return v_result || jsonb_build_object('location', case
    when v_row.location_id is null then null
    else (select jsonb_build_object('id', l.id, 'name', l.name)
          from public.bank_locations l where l.id = v_row.location_id)
  end);
end;
$$;

-- -----------------------------------------------------------------------------
-- Hak eksekusi
-- -----------------------------------------------------------------------------
revoke all on function public.get_locations() from public, anon;
revoke all on function public.simpan_lokasi(uuid, text, text, numeric, numeric, boolean) from public, anon;
revoke all on function public.hapus_lokasi(uuid) from public, anon;
revoke all on function public.create_deposit(uuid, numeric, uuid) from public, anon;
revoke all on function public.create_withdrawal(numeric, uuid) from public, anon;
revoke all on function public.detail_transaksi(uuid) from public, anon;
revoke all on function public.detail_penarikan(uuid) from public, anon;
revoke all on function public.tarik_by_qr(uuid) from public, anon;

grant execute on function public.get_locations() to authenticated;
grant execute on function public.simpan_lokasi(uuid, text, text, numeric, numeric, boolean) to authenticated;
grant execute on function public.hapus_lokasi(uuid) to authenticated;
grant execute on function public.create_deposit(uuid, numeric, uuid) to authenticated;
grant execute on function public.create_withdrawal(numeric, uuid) to authenticated;
grant execute on function public.detail_transaksi(uuid) to authenticated;
grant execute on function public.detail_penarikan(uuid) to authenticated;
grant execute on function public.tarik_by_qr(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261034000000', 'lokasi_bank_sampah')
on conflict (version) do nothing;
