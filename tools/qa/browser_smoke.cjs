/* Run after build: CHROME_PATH=/path/to/chrome-headless-shell node tools/qa/browser_smoke.cjs */
const fs = require('fs');
const path = require('path');
const http = require('http');
const assert = require('assert/strict');
const crypto = require('node:crypto');
const {chromium} = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES ? process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES + '/playwright' : 'playwright');
const root = path.resolve('build/web');
const output = path.resolve('build/qa');
fs.mkdirSync(output, {recursive: true});
const types = {'.html':'text/html', '.js':'application/javascript', '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png', '.ttf':'font/ttf', '.otf':'font/otf', '.bin':'application/octet-stream'};
const server = http.createServer((req,res) => {
  const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const target = path.resolve(root, '.' + (name === '/' ? '/index.html' : name));
  if (!target.startsWith(root + path.sep)) {res.writeHead(403).end();return;}
  try {res.writeHead(200, {'Content-Type':types[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-store'});res.end(fs.readFileSync(target));}
  catch {res.writeHead(404).end();}
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const origin='http://127.0.0.1:'+server.address().port;
  let browser;
  try {
    browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true,args:['--no-sandbox','--single-process','--no-zygote']});
    const context=await browser.newContext({viewport:{width:1440,height:1000}});
    const page=await context.newPage();
    const errors=[],external=[],failed=[];
    page.on('pageerror',e=>errors.push(e.message));
    page.on('request',r=>{if(!r.url().startsWith(origin)&&!r.url().startsWith('data:')&&!r.url().startsWith('blob:'))external.push(r.url());});
    page.on('response',r=>{if(r.status()>=400)failed.push({url:r.url(),status:r.status()});});
    await page.goto(origin,{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:60000});
    await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
    await page.getByRole('checkbox',{name:/Nara · Espresso/}).click();
    await page.getByText('Ketuk Mesin espresso untuk espresso.',{exact:true}).waitFor();
    await page.getByRole('button',{name:'Mesin espresso',exact:true}).click();
    await page.getByRole('button',{name:'Sajikan',exact:true}).first().click({timeout:12000});
    await page.waitForFunction(()=>{
      let v=JSON.parse(localStorage.getItem('flutter.cafe.save.v1')||'null');
      if(typeof v==='string')v=JSON.parse(v);
      return v?.served===1;
    });
    await page.screenshot({path:path.join(output,'browser-desktop.png'),fullPage:true});
    await page.waitForFunction(()=>document.documentElement.dataset.offlineReady==='true',null,{timeout:60000});
    await page.setViewportSize({width:390,height:844});
    await page.getByRole('button',{name:'Akun & data',exact:true}).click();
    await page.getByRole('button',{name:'Masuk',exact:true}).waitFor();
    await page.screenshot({path:path.join(output,'browser-mobile-account.png'),fullPage:true});
    await page.getByRole('button',{name:'Tutup',exact:true}).click();
    await context.setOffline(true);
    await page.reload({waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:30000});
    await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
    const served=await page.evaluate(()=>{
      let v=JSON.parse(localStorage.getItem('flutter.cafe.save.v1')||'null');
      return (typeof v==='string'?JSON.parse(v):v)?.served;
    });
    assert.equal(served,1,'Served order survives offline reload');
    await page.screenshot({path:path.join(output,'browser-mobile-offline.png'),fullPage:true});
    assert.deepEqual(errors,[],'No JavaScript runtime errors');
    assert.deepEqual(external.filter(u=>!/\.supabase\.co\//.test(u)),[],'No remote font/renderer dependency');
    assert.deepEqual(failed,[],'All HTTP resources succeed');
    const second=await browser.newContext({viewport:{width:390,height:844}});
    const seed={version:1,coins:2000,xp:100,served:0,earned:0,nextId:1,lastSeen:Date.now(),nextArrival:0,nextStaff:0,staff:false,workers:[],customers:[],theme:'sage',unlocked:['espresso','latte'],machines:['coffee','milk'],disabledMenu:['espresso'],stories:[],claimedGoals:[],orders:[],brews:[],decor:[{kind:'table',x:2,y:2},{kind:'table',x:5,y:3},{kind:'plant',x:0,y:4},{kind:'chair',x:2,y:3},{kind:'chair',x:5,y:4}],toolPositions:{coffee:{kind:'coffee',x:1,y:0},milk:{kind:'milk',x:2,y:0}}};
    await second.addInitScript(value=>{if(!localStorage.getItem('cafe.qa.seeded')){localStorage.setItem('flutter.cafe.save.v1',JSON.stringify(JSON.stringify(value)));localStorage.setItem('cafe.qa.seeded','true');}},seed);
    const latte=await second.newPage();latte.on('pageerror',e=>errors.push(e.message));
    latte.on('request',r=>{if(!r.url().startsWith(origin)&&!r.url().startsWith('data:')&&!r.url().startsWith('blob:'))external.push(r.url());});
    latte.on('response',r=>{if(r.status()>=400)failed.push({url:r.url(),status:r.status()});});
    await latte.goto(origin,{waitUntil:'domcontentloaded'});
    await latte.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:60000});
    await latte.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
    const animationFrames=[];
    for(let i=0;i<4;i++){animationFrames.push(crypto.createHash('sha256').update(await latte.screenshot()).digest('hex'));await latte.waitForTimeout(100);}
    assert(new Set(animationFrames).size>1,'Scene animation changes between frames');
    await latte.getByRole('checkbox',{name:/Nara · Caffè latte/}).click();
    await latte.getByText('Ketuk Mesin espresso untuk espresso.',{exact:true}).waitFor();
    await latte.getByRole('button',{name:'Milk steamer',exact:true}).click();
    await latte.waitForTimeout(250);
    const raw=await latte.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.cafe.save.v1'))));
    assert.equal(raw.brews.length,0,'Milk cannot skip espresso');
    await latte.getByRole('button',{name:'Mesin espresso',exact:true}).click();
    await latte.getByText('Ketuk Milk steamer untuk susu.',{exact:true}).waitFor({timeout:10000});
    assert.equal(await latte.getByRole('button',{name:'Sajikan',exact:true}).count(),0,'Partial recipe cannot be served');
    await latte.getByRole('button',{name:'Milk steamer',exact:true}).click();
    await latte.getByRole('button',{name:'Sajikan',exact:true}).click({timeout:10000});
    await latte.waitForFunction(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.cafe.save.v1'))).served===1);
    await latte.getByRole('button',{name:'Tim',exact:true}).click();
    for(let i=0;i<3;i++){await latte.getByRole('button',{name:/Rekrut/}).click();}
    assert.equal(await latte.getByRole('button',{name:'Tim lengkap · 3/3',exact:true}).isDisabled(),true);
    await latte.screenshot({path:path.join(output,'browser-mobile-staff.png'),fullPage:true});
    await latte.getByRole('button',{name:'Tutup',exact:true}).click();
    for(const name of ['Menu','Toko','Pelanggan','Cerita','Cara bermain']) {
      await latte.getByRole('button',{name,exact:true}).click();
      await latte.getByRole('button',{name:'Tutup',exact:true}).waitFor();
      await latte.getByRole('button',{name:'Tutup',exact:true}).click();
    }
    const frameTiming=await latte.evaluate(()=>new Promise(resolve=>{let last;const values=[];function frame(t){if(last!==undefined)values.push(t-last);last=t;if(values.length<90)requestAnimationFrame(frame);else{values.sort((a,b)=>a-b);resolve({medianMs:values[45],p95Ms:values[85],framesOver50ms:values.filter(v=>v>50).length});}}requestAnimationFrame(frame);}));
    assert.deepEqual(errors,[],'No errors in multi-step or staff flow');
    assert.deepEqual(external.filter(u=>!/\.supabase\.co\//.test(u)),[],'All popup fonts and renderers stay local');
    assert.deepEqual(failed,[],'All popup HTTP resources succeed');
    const result={served,offlineReload:true,desktop:true,mobile:true,multiStepLatte:true,wrongIngredientRejected:true,staffLimit:3,animatedScene:true,frameTiming,errors,externalRequests:external,failed};
    fs.writeFileSync(path.join(output,'browser-smoke.json'),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify(result));
  } catch(error) {
    if(browser){for(const [i,context] of browser.contexts().entries()){for(const page of context.pages()){await page.screenshot({path:path.join(output,`failure-${i}.png`)}).catch(()=>{});fs.writeFileSync(path.join(output,`failure-${i}.html`),await page.content());}}}
    throw error;
  } finally {if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e.stack);process.exitCode=1;server.close();});
