/* Run after build: CHROME_PATH=/path/to/chrome-headless-shell node tools/qa/browser_smoke.cjs */
const fs = require('fs');
const path = require('path');
const http = require('http');
const assert = require('assert/strict');
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
    await page.getByRole('button',{name:'Siapkan',exact:true}).first().click();
    await page.getByRole('button',{name:'Sajikan',exact:true}).first().click({timeout:12000});
    await page.waitForFunction(()=>{
      let v=JSON.parse(localStorage.getItem('flutter.cafe.save.v1')||'null');
      if(typeof v==='string')v=JSON.parse(v);
      return v?.served===1;
    });
    await page.screenshot({path:path.join(output,'browser-desktop.png'),fullPage:true});
    await page.waitForFunction(()=>document.documentElement.dataset.offlineReady==='true',null,{timeout:60000});
    await page.setViewportSize({width:390,height:844});
    await page.getByRole('tab',{name:'Lainnya',exact:true}).click();
    await page.getByText('Akun & data',{exact:true}).first().click();
    await page.getByRole('button',{name:'Masuk',exact:true}).waitFor();
    await page.screenshot({path:path.join(output,'browser-mobile-account.png'),fullPage:true});
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
    const result={served,offlineReload:true,desktop:true,mobile:true,errors,externalRequests:external,failed};
    fs.writeFileSync(path.join(output,'browser-smoke.json'),JSON.stringify(result,null,2)+'\n');
    console.log(JSON.stringify(result));
  } finally {if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e.stack);process.exitCode=1;server.close();});
