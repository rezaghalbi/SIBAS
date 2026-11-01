-- =============================================================================
-- SIBAS — retensi log error klien
--
-- client_error_logs bisa memuat potongan pesan/stack yang menyentuh data
-- pengguna. Simpan 30 hari, lalu bersihkan otomatis lewat pg_cron.
-- =============================================================================

create or replace function public.bersihkan_log_klien()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_count integer;
begin
  delete from public.client_error_logs
  where dibuat_pada < now() - interval '30 days';

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

revoke all on function public.bersihkan_log_klien() from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1 from cron.job where jobname = 'bersihkan-log-klien'
  ) then
    perform cron.schedule(
      'bersihkan-log-klien',
      '15 3 * * *',
      'select public.bersihkan_log_klien();'
    );
  end if;
end;
$$;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261038000000', 'retensi_log_klien')
on conflict (version) do nothing;
