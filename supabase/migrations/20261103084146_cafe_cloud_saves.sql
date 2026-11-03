create table public.cafe_saves (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null,
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now(),
  constraint cafe_save_state_valid check (
    jsonb_typeof(state) = 'object'
    and jsonb_typeof(state->'version') = 'number'
    and state->>'version' = '1'
    and octet_length(state::text) <= 100000
  )
);

alter table public.cafe_saves enable row level security;

revoke all on public.cafe_saves from public, anon, authenticated;
grant select, insert, update on public.cafe_saves to authenticated;

create policy cafe_saves_select_own on public.cafe_saves
  for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy cafe_saves_insert_own on public.cafe_saves
  for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy cafe_saves_update_own on public.cafe_saves
  for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

create function public.cafe_save_compare_and_swap(
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
    insert into public.cafe_saves(owner_id, state, revision)
      values (v_owner, p_state, 1)
      on conflict (owner_id) do nothing;
  else
    update public.cafe_saves as s
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
      from public.cafe_saves as s
     where s.owner_id = v_owner;
end;
$$;

revoke all on function public.cafe_save_compare_and_swap(jsonb, bigint)
  from public, anon, authenticated;
grant execute on function public.cafe_save_compare_and_swap(jsonb, bigint)
  to authenticated;

comment on table public.cafe_saves is
  'My Cloud Cafe account snapshots; owner-isolated, revision checked by the save RPC.';
