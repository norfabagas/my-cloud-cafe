/* PGLITE_MODULE=/absolute/path/to/@electric-sql/pglite node tools/qa/customer_registry.cjs */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { PGlite } = require(process.env.PGLITE_MODULE || '@electric-sql/pglite');
(async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon; create role authenticated;
      create schema auth;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as
        $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated,anon;
      grant execute on function auth.uid() to authenticated,anon;
      insert into auth.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
    `);
    for (const file of fs.readdirSync('supabase/migrations').filter(f => f.endsWith('.sql')).sort()) {
      await db.exec(fs.readFileSync('supabase/migrations/' + file, 'utf8'));
    }
    const owner = '00000000-0000-0000-0000-000000000001';
    const other = '00000000-0000-0000-0000-000000000002';
    await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','${owner}',false);`);
    const snapshot = (visits = 1) => JSON.stringify({version:1,customers:[{id:1,name:'Nara',look:31,firstSeen:1000,visits}]});
    await db.query('select * from public.cafe_save_compare_and_swap($1::jsonb,0)', [snapshot()]);
    let rows = (await db.query('select * from public.mcc_customers')).rows;
    assert.equal(rows.length,1);assert.equal(rows[0].name,'Nara');
    await db.query('select * from public.cafe_save_compare_and_swap($1::jsonb,1)', [snapshot(2)]);
    rows = (await db.query('select * from public.mcc_customers')).rows;
    assert.equal(rows.length,1);assert.equal(rows[0].visits,2);
    await assert.rejects(db.query('select * from public.cafe_save_compare_and_swap($1::jsonb,1)', [snapshot(99)]), e => e.code === '40001');
    assert.equal((await db.query('select visits from public.mcc_customers')).rows[0].visits,2);
    await assert.rejects(db.query('update public.mcc_customers set owner_id=$1::uuid',[other]), e => e.code === '42501');
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false)`);
    assert.equal((await db.query('select * from public.mcc_customers')).rows.length,0);
    const denied = await db.query('update public.mcc_customers set name=$1 where owner_id=$2::uuid returning *',['attack',owner]);
    assert.equal(denied.rows.length,0);
    await assert.rejects(db.query('insert into public.mcc_customers values ($1::uuid,2,$2,1,0,1)',[owner,'attack']), e => e.code === '42501');
    await db.exec('reset role; set role anon;');
    await assert.rejects(db.query('select * from public.mcc_customers'), e=>e.code==='42501');
    console.log(JSON.stringify({registration:true,revisitUpsert:true,staleSaveAtomicity:true,ownerIsolation:true,ownerReassignmentDenied:true,anonDenied:true}));
  } finally { await db.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
