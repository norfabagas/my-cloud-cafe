-- Exercises the deployed policies and trigger, then rolls back every test write.
begin;
do $$ begin
  perform set_config('cafe.test_owner',(select id::text from auth.users order by id limit 1),true);
  perform set_config('cafe.test_other',(select id::text from auth.users order by id offset 1 limit 1),true);
  assert current_setting('cafe.test_owner') <> '', 'two existing accounts required';
  assert current_setting('cafe.test_other') <> '', 'two existing accounts required';
  perform set_config('request.jwt.claim.sub',current_setting('cafe.test_owner'),true);
end $$;
set local role authenticated;
do $$
declare v_revision bigint; v_rejected boolean := false;
begin
  select revision into v_revision from public.mcc_cafe_saves
    where owner_id=auth.uid() for update;
  v_revision := coalesce(v_revision,0);
  perform public.cafe_save_compare_and_swap(
    '{"version":1,"customers":[{"id":48,"name":"QA Cafe","look":31,"firstSeen":1000,"visits":1}]}'::jsonb,v_revision);
  assert (select name from public.mcc_customers where owner_id=auth.uid() and customer_id=48)='QA Cafe', 'arrival must register';
  perform public.cafe_save_compare_and_swap(
    '{"version":1,"customers":[{"id":48,"name":"QA Cafe","look":31,"firstSeen":1000,"visits":2}]}'::jsonb,v_revision+1);
  assert (select visits from public.mcc_customers where owner_id=auth.uid() and customer_id=48)=2, 'revisit must upsert';
  begin
    perform public.cafe_save_compare_and_swap(
      '{"version":1,"customers":[{"id":48,"name":"Stale writer","look":31,"firstSeen":1000,"visits":99}]}'::jsonb,v_revision+1);
  exception when serialization_failure then v_rejected := true;
  end;
  assert v_rejected, 'stale writer must fail';
  assert (select visits from public.mcc_customers where owner_id=auth.uid() and customer_id=48)=2, 'stale registration must be atomic';
  v_rejected := false;
  begin
    update public.mcc_customers set owner_id=current_setting('cafe.test_other')::uuid where owner_id=auth.uid() and customer_id=48;
  exception when insufficient_privilege then v_rejected := true;
  end;
  assert v_rejected, 'owner reassignment must fail';
  perform set_config('request.jwt.claim.sub',current_setting('cafe.test_other'),true);
  assert not exists(select 1 from public.mcc_customers where owner_id=current_setting('cafe.test_owner')::uuid), 'other account must not read customer';
  assert not has_table_privilege('anon','public.mcc_customers','select'), 'guest reads must be denied';
  assert not has_table_privilege('anon','public.mcc_customers','insert'), 'guest writes must be denied';
end $$;
reset role;
select 'PASS: customer registration, revisit, stale-save atomicity, owner isolation, ownership reassignment denial, guest denial; all test writes rolled back' as result;
rollback;
