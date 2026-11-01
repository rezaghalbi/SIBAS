-- =============================================================================
-- SIBAS — batas pengajuan setoran menunggu
--
-- Satu mahasiswa maksimal punya 10 setoran PENDING. Mencegah antrean admin
-- dibanjiri pengajuan berulang tanpa mengubah alur normal (satu kunjungan
-- biasanya hanya beberapa jenis sampah).
-- =============================================================================

create or replace function public.batasi_pending_setoran()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if (
    select count(*)
    from public.transactions
    where mahasiswa_id = new.mahasiswa_id
      and status = 'PENDING'
  ) >= 10 then
    raise exception
      'Terlalu banyak pengajuan setoran menunggu. Tunggu verifikasi petugas sebelum mengirim lagi.';
  end if;

  return new;
end;
$function$;

drop trigger if exists batasi_pending_setoran_trg on public.transactions;
create trigger batasi_pending_setoran_trg
before insert on public.transactions
for each row execute function public.batasi_pending_setoran();

insert into supabase_migrations.schema_migrations (version, name)
values ('20261040000000', 'batas_pending_setoran')
on conflict (version) do nothing;
