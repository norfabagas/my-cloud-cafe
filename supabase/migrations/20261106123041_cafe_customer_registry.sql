-- Derived from accepted cloud snapshots, so a stale save cannot register or
-- change another device's customers before compare-and-swap succeeds.
create table public.mcc_customers (
  owner_id uuid not null references auth.users(id) on delete cascade,
  customer_id integer not null check (customer_id between 1 and 48),
  name text not null check (length(name) between 1 and 30),
  look integer not null check (look between 0 and 100000),
  first_seen bigint not null check (first_seen >= 0),
  visits integer not null check (visits >= 0),
  primary key (owner_id, customer_id)
);
alter table public.mcc_customers enable row level security;
revoke all on public.mcc_customers from public, anon, authenticated;
grant select, insert, update on public.mcc_customers to authenticated;
create policy mcc_customers_select_own on public.mcc_customers for select to authenticated using ((select auth.uid()) = owner_id);
create policy mcc_customers_insert_own on public.mcc_customers for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy mcc_customers_update_own on public.mcc_customers for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

create function public.mcc_register_customers() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.mcc_customers(owner_id,customer_id,name,look,first_seen,visits)
    select new.owner_id,(c->>'id')::integer,c->>'name',(c->>'look')::integer,
           (c->>'firstSeen')::bigint,(c->>'visits')::integer
    from pg_catalog.jsonb_array_elements(coalesce(new.state->'customers','[]'::jsonb)) c
  on conflict (owner_id,customer_id) do update set
    name=excluded.name,look=excluded.look,first_seen=excluded.first_seen,visits=excluded.visits;
  return new;
end;
$$;
revoke all on function public.mcc_register_customers() from public,anon,authenticated;
create trigger mcc_save_customers after insert or update of state on public.mcc_cafe_saves
  for each row execute function public.mcc_register_customers();
comment on table public.mcc_customers is 'Fictional cafe guests, registered by accepted owner-scoped game saves.';
notify pgrst, 'reload schema';
