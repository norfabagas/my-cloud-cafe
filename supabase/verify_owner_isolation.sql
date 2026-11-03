begin;
select set_config('cafe.test_owner', (select id::text from auth.users order by id limit 1), true);
select set_config('cafe.test_other', (select id::text from auth.users order by id offset 1 limit 1), true);
select set_config('request.jwt.claim.sub', current_setting('cafe.test_owner'), true);
set local role authenticated;
do $test$
declare
  v_revision bigint;
  v_conflict boolean := false;
  v_rejected boolean := false;
begin
  select revision into v_revision from public.cafe_save_compare_and_swap('{"version":1,"test":"first"}', 0);
  assert v_revision = 1, 'first insert must return revision 1';
  select revision into v_revision from public.cafe_save_compare_and_swap('{"version":1,"test":"device_a"}', 1);
  assert v_revision = 2, 'valid writer must advance revision';
  begin
    perform public.cafe_save_compare_and_swap('{"version":1,"test":"stale_device_b"}', 1);
  exception when serialization_failure then v_conflict := true;
  end;
  assert v_conflict, 'second writer with same base revision must conflict';
  assert (select state->>'test' from public.cafe_saves) = 'device_a', 'stale writer changed save';
  begin
    update public.cafe_saves set owner_id = current_setting('cafe.test_other')::uuid;
  exception when insufficient_privilege then v_rejected := true;
  end;
  assert v_rejected, 'owner reassignment must fail';
end $test$;
select set_config('request.jwt.claim.sub', current_setting('cafe.test_other'), true);
do $test$
declare v_count integer;
begin
  assert (select count(*) from public.cafe_saves) = 0, 'other user can see save';
  update public.cafe_saves set state = '{"version":1,"test":"attack"}'
    where owner_id = current_setting('cafe.test_owner')::uuid;
  get diagnostics v_count = row_count;
  assert v_count = 0, 'other user can update save';
  assert not has_table_privilege('anon', 'public.cafe_saves', 'select'), 'anon has table access';
  assert not has_function_privilege('anon', 'public.cafe_save_compare_and_swap(jsonb,bigint)', 'execute'), 'anon has RPC access';
end $test$;
reset role;
select 'PASS: insert, CAS, stale writer rejection, owner isolation, owner reassignment, anon grants; transaction rolled back' as result;
rollback;
