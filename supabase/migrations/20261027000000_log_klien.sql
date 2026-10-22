create table if not exists public.client_error_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  pesan text not null,
  detail text,
  platform text,
  versi_aplikasi text,
  dibuat_pada timestamptz not null default now()
);
create index if not exists client_error_logs_dibuat_pada_idx on public.client_error_logs (dibuat_pada desc);
alter table public.client_error_logs enable row level security;
-- Tidak ada policy: klien tidak boleh membaca/menulis langsung, hanya lewat RPC.

create or replace function public.log_client_error(
  p_pesan text,
  p_detail text default null,
  p_platform text default null,
  p_versi text default null
) returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_jumlah int;
begin
  if p_pesan is null or length(btrim(p_pesan)) = 0 then
    return;
  end if;

  -- Batasi spam: maksimal 20 catatan per pengguna (atau per anon) per jam.
  select count(*) into v_jumlah
  from public.client_error_logs
  where dibuat_pada > now() - interval '1 hour'
    and (user_id = auth.uid() or (user_id is null and auth.uid() is null));

  if v_jumlah >= 20 then
    return;
  end if;

  insert into public.client_error_logs (user_id, pesan, detail, platform, versi_aplikasi)
  values (auth.uid(), left(p_pesan, 500), left(p_detail, 2000), left(p_platform, 32), left(p_versi, 32));
end $function$;

revoke all on public.client_error_logs from anon, authenticated;
grant execute on function public.log_client_error(text, text, text, text) to anon, authenticated;
