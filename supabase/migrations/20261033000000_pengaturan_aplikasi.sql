-- Pengaturan aplikasi: masa berlaku QR dan kontak admin.
-- Satu baris (id = 1) agar mudah dibaca RPC dan UI.

create table if not exists public.app_settings (
  id smallint primary key default 1 check (id = 1),
  qr_ttl_minutes integer not null default 120
    check (qr_ttl_minutes between 5 and 1440),
  contact_email text,
  contact_location text,
  contact_hours text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists app_settings_select on public.app_settings;
create policy app_settings_select on public.app_settings
  for select to authenticated using (true);

revoke insert, update, delete on public.app_settings from anon, authenticated;
grant select on public.app_settings to authenticated;

create or replace function public.get_app_settings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'qr_ttl_minutes', qr_ttl_minutes,
    'contact_email', contact_email,
    'contact_location', contact_location,
    'contact_hours', contact_hours
  )
  from public.app_settings
  where id = 1;
$$;

grant execute on function public.get_app_settings() to authenticated;

create or replace function public.update_app_settings(
  p_qr_ttl_minutes integer,
  p_contact_email text,
  p_contact_location text,
  p_contact_hours text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := nullif(btrim(coalesce(p_contact_email, '')), '');
  v_location text := nullif(btrim(coalesce(p_contact_location, '')), '');
  v_hours text := nullif(btrim(coalesce(p_contact_hours, '')), '');
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengubah pengaturan.';
  end if;

  if p_qr_ttl_minutes is null or p_qr_ttl_minutes < 5 or p_qr_ttl_minutes > 1440 then
    raise exception 'Masa berlaku QR harus antara 5 dan 1440 menit.';
  end if;

  if v_email is not null and v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'Format email kontak tidak valid.';
  end if;

  if v_location is not null and char_length(v_location) > 160 then
    raise exception 'Lokasi maksimal 160 karakter.';
  end if;

  if v_hours is not null and char_length(v_hours) > 160 then
    raise exception 'Jam layanan maksimal 160 karakter.';
  end if;

  update public.app_settings
  set qr_ttl_minutes = p_qr_ttl_minutes,
      contact_email = v_email,
      contact_location = v_location,
      contact_hours = v_hours,
      updated_at = now(),
      updated_by = auth.uid()
  where id = 1;

  return public.get_app_settings();
end;
$$;

grant execute on function public.update_app_settings(integer, text, text, text)
  to authenticated;

-- create_deposit memakai TTL dari pengaturan, bukan hardcode 2 jam.
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
  v_ttl integer;
  v_tx public.transactions;
begin
  if v_uid is null then raise exception 'Sesi tidak valid. Silakan login ulang.'; end if;
  if p_weight is null or p_weight <= 0 then raise exception 'Berat sampah harus lebih dari 0 kg.'; end if;

  select price_per_kg into v_price from public.trash_types where id = p_trash_type_id and is_active;
  if v_price is null then raise exception 'Jenis sampah tidak ditemukan atau tidak aktif.'; end if;

  select qr_ttl_minutes into v_ttl from public.app_settings where id = 1;
  v_ttl := coalesce(v_ttl, 120);

  insert into public.transactions (tx_code, qr_token, mahasiswa_id, trash_type_id,
    weight, price_per_kg_snapshot, estimated_amount, qr_expires_at)
  values ('BS-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.tx_code_seq')::text, 4, '0'),
    replace(gen_random_uuid()::text, '-', ''), v_uid, p_trash_type_id,
    p_weight, v_price, round(p_weight * v_price, 2), now() + make_interval(mins => v_ttl))
  returning * into v_tx;

  insert into public.transaction_audits (transaction_id, actor_id, from_status, to_status, note)
  values (v_tx.id, v_uid, null, 'PENDING', 'Pengajuan setoran dibuat');

  return to_jsonb(v_tx) || jsonb_build_object('trash_types', (
    select jsonb_build_object('name', name, 'price_per_kg', price_per_kg)
    from public.trash_types where id = p_trash_type_id));
end;
$$;
