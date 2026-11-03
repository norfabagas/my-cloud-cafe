-- Keep the existing table identity, rows, grants and RLS policies.
alter table public.cafe_saves rename to mcc_cafe_saves;

-- PL/pgSQL source refers to tables by name; update the RPC in the same migration.
create or replace function public.cafe_save_compare_and_swap(
  p_state jsonb,
  p_expected_revision bigint
)
returns table (revision bigint, updated_at timestamptz)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_owner uuid := auth.uid();
  v_count integer;
begin
  if v_owner is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'Invalid expected revision' using errcode = '22023';
  end if;

  if p_expected_revision = 0 then
    insert into public.mcc_cafe_saves(owner_id, state, revision)
      values (v_owner, p_state, 1)
      on conflict (owner_id) do nothing;
  else
    update public.mcc_cafe_saves as s
       set state = p_state,
           revision = s.revision + 1,
           updated_at = pg_catalog.clock_timestamp()
     where s.owner_id = v_owner and s.revision = p_expected_revision;
  end if;
  get diagnostics v_count = row_count;
  if v_count <> 1 then
    raise exception 'Cloud save changed; fetch it before retrying'
      using errcode = '40001';
  end if;
  return query
    select s.revision, s.updated_at
      from public.mcc_cafe_saves as s
     where s.owner_id = v_owner;
end;
$$;

notify pgrst, 'reload schema';
