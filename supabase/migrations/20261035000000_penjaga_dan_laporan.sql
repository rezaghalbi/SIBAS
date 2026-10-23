-- =============================================================================
-- Penjaga pengajuan ganda, metrik per lokasi, dan koreksi data mahasiswa oleh
-- admin. Semua perubahan aditif; tidak ada kolom/tabel baru.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Satu pengajuan penarikan menunggu per mahasiswa.
--    Setoran tidak dibatasi karena satu kunjungan bisa berisi beberapa jenis
--    sampah; duplikat setoran dijaga di create_deposit lewat jendela waktu.
-- -----------------------------------------------------------------------------
create unique index if not exists withdrawals_satu_pending_per_mhs
  on public.withdrawals (mahasiswa_id)
  where status = 'PENDING';

-- -----------------------------------------------------------------------------
-- 2. create_deposit: tolak duplikat jenis + berat dalam 2 menit.
-- -----------------------------------------------------------------------------
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

  -- Cegah kirim ganda karena tombol ditekan berulang atau koneksi lambat.
  if exists (
    select 1
    from public.transactions
    where mahasiswa_id = v_uid
      and status = 'PENDING'
      and trash_type_id = p_trash_type_id
      and weight = p_weight
      and created_at > now() - interval '2 minutes'
  ) then
    raise exception 'Setoran dengan jenis dan berat yang sama baru saja dibuat. Tunggu verifikasi petugas.';
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
-- 3. create_withdrawal: pesan jelas saat masih ada pengajuan menunggu.
-- -----------------------------------------------------------------------------
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

  if exists (
    select 1 from public.withdrawals
    where mahasiswa_id = v_uid and status = 'PENDING'
  ) then
    raise exception 'Masih ada pengajuan penarikan yang menunggu verifikasi.';
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
exception
  when unique_violation then
    raise exception 'Masih ada pengajuan penarikan yang menunggu verifikasi.';
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. admin_metrics: filter lokasi + rekap per lokasi.
-- -----------------------------------------------------------------------------
drop function if exists public.admin_metrics();

create or replace function public.admin_metrics(p_location_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_total numeric;
  v_pending int;
  v_approved int;
  v_rejected int;
  v_lokasi jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat melihat metrik.';
  end if;

  select coalesce(sum(weight), 0) into v_total
  from public.transactions
  where status = 'APPROVED'
    and (p_location_id is null or location_id = p_location_id);

  select
    count(*) filter (where status = 'PENDING'),
    count(*) filter (where status = 'APPROVED'),
    count(*) filter (where status = 'REJECTED')
  into v_pending, v_approved, v_rejected
  from public.transactions
  where p_location_id is null or location_id = p_location_id;

  select coalesce(jsonb_agg(baris order by baris->>'name'), '[]'::jsonb)
  into v_lokasi
  from (
    select jsonb_build_object(
      'id', l.id,
      'name', l.name,
      'is_active', l.is_active,
      'total_weight_kg', coalesce(sum(t.weight) filter (where t.status = 'APPROVED'), 0),
      'pending_count', count(t.id) filter (where t.status = 'PENDING'),
      'approved_count', count(t.id) filter (where t.status = 'APPROVED'),
      'rejected_count', count(t.id) filter (where t.status = 'REJECTED')
    ) as baris
    from public.bank_locations l
    left join public.transactions t on t.location_id = l.id
    group by l.id, l.name, l.is_active
  ) rekap;

  return jsonb_build_object(
    'total_weight_kg', v_total,
    'pending_count', v_pending,
    'approved_count', v_approved,
    'rejected_count', v_rejected,
    'location_id', p_location_id,
    'locations', v_lokasi
  );
end $function$;

-- -----------------------------------------------------------------------------
-- 5. Admin mengoreksi identitas mahasiswa (nama, NIM, nomor WhatsApp).
--    Peran, saldo, total berat, dan status akun tetap terkunci.
-- -----------------------------------------------------------------------------
create or replace function public.admin_ubah_mahasiswa(
  p_id uuid,
  p_full_name text,
  p_nim text,
  p_phone text
) returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_nama text := btrim(coalesce(p_full_name, ''));
  v_nim text := nullif(btrim(coalesce(p_nim, '')), '');
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_row public.profiles;
  v_role text;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengubah data mahasiswa.';
  end if;

  select role into v_role from public.profiles where id = p_id;
  if v_role is null then
    raise exception 'Mahasiswa tidak ditemukan.';
  end if;
  if v_role <> 'mahasiswa' then
    raise exception 'Fungsi ini hanya untuk akun mahasiswa.';
  end if;

  if char_length(v_nama) < 2 or char_length(v_nama) > 80 then
    raise exception 'Nama harus 2 sampai 80 karakter.';
  end if;

  if v_nim is not null and v_nim !~ '^[A-Za-z0-9]{3,20}$' then
    raise exception 'NIM hanya boleh huruf dan angka, 3 sampai 20 karakter.';
  end if;

  if v_phone is not null and v_phone !~ '^[0-9+][0-9 -]{7,19}$' then
    raise exception 'Nomor WhatsApp tidak valid. Contoh: 081234567890.';
  end if;

  begin
    perform set_config('sibas.ubah_profil', 'on', true);

    update public.profiles
       set full_name = v_nama,
           nim = v_nim,
           phone = v_phone
     where id = p_id
     returning * into v_row;
  exception
    when unique_violation then
      raise exception 'NIM sudah dipakai akun lain.';
  end;

  return to_jsonb(v_row);
end;
$function$;

-- -----------------------------------------------------------------------------
-- Hak eksekusi
-- -----------------------------------------------------------------------------
revoke all on function public.admin_metrics(uuid) from public, anon;
revoke all on function public.admin_ubah_mahasiswa(uuid, text, text, text)
  from public, anon;
revoke all on function public.create_deposit(uuid, numeric, uuid)
  from public, anon;
revoke all on function public.create_withdrawal(numeric, uuid)
  from public, anon;

grant execute on function public.admin_metrics(uuid) to authenticated;
grant execute on function public.admin_ubah_mahasiswa(uuid, text, text, text)
  to authenticated;
grant execute on function public.create_deposit(uuid, numeric, uuid)
  to authenticated;
grant execute on function public.create_withdrawal(numeric, uuid)
  to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261035000000', 'penjaga_dan_laporan')
on conflict (version) do nothing;
