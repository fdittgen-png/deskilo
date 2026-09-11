// Drive every step's build() and check() against a minimal DOM, so a
// ReferenceError like `avail` fails HERE rather than on the published page.
import fs from 'fs';

// web/setup.html is 900 lines of dense JavaScript with no build step and
// no runtime anywhere in CI — so a plain ReferenceError in one step's
// build() ships, and the step renders NOTHING. That is not theoretical:
// `avail` did exactly that to step 2 (Fonctionnalités) on the published
// page, and because render() threw before drawing the navigation, the
// wizard became a dead end with no message.
//
// This drives every step's build() and check() against a minimal DOM.
// It is not a UI test — it asks only "does this code run".
const html = fs.readFileSync(new URL('../../web/setup.html', import.meta.url), 'utf8');
const src = /<script>([\s\S]*)<\/script>/.exec(html)[1];

const mk = (tag) => {
  const e = {
    tagName:(tag||'').toUpperCase(), children:[], attrs:{}, style:{}, classList:{
      _s:new Set(), add(...c){c.forEach(x=>this._s.add(x))}, remove(...c){c.forEach(x=>this._s.delete(x))},
      toggle(c,on){on?this._s.add(c):this._s.delete(c)}, contains(c){return this._s.has(c)} },
    append(...k){k.forEach(x=>{if(x!=null)this.children.push(x)})},
    setAttribute(k,v){this.attrs[k]=v}, getAttribute(k){return this.attrs[k]??null},
    insertBefore(n){this.children.unshift(n)}, remove(){},
    querySelector(sel){ const want = sel.replace(/^span\s*/,'').trim();
      const walk=(n)=>{ for(const c of (n.children||[])){
        if(typeof c!=='object') continue;
        if(want==='input'&&c.tagName==='INPUT') return c;
        if(want==='h2'&&c.tagName==='H2') return c;
        if((want==='span'||sel==='span')&&c.tagName==='SPAN') return c;
        if(want==='div'&&c.tagName==='DIV') return c;
        const r=walk(c); if(r) return r; } return null};
      return walk(this) },
    querySelectorAll(){return []},
    get firstChild(){return this.children[0]},
    set textContent(v){this.children.length=0}, get textContent(){return ''},
    set innerHTML(v){}, set value(v){this._v=v}, get value(){return this._v??''},
    set checked(v){this._c=v}, get checked(){return !!this._c},
    set disabled(v){this._d=v}, get disabled(){return !!this._d},
    set title(v){}, set onclick(f){}, set oninput(f){}, set onchange(f){},
    options:[], scrollTo(){},
  };
  return e;
};
const byId = {};
for (const id of ['form','bar','rail','nav','saved','allmode']) byId[id]=mk('div');
globalThis.document = { createElement: mk, getElementById:(id)=>byId[id]||mk('div') };
globalThis.window = { scrollTo(){} };
globalThis.location = { search:'' };
const store = {};
globalThis.localStorage = { getItem:(k)=>store[k]??null, setItem:(k,v)=>{store[k]=v}, removeItem:(k)=>{delete store[k]} };
globalThis.confirm = ()=>true;
globalThis.alert = ()=>{};
globalThis.Blob = class {constructor(){}};
globalThis.URL = { createObjectURL:()=>'blob:', revokeObjectURL(){} };
globalThis.DOMParser = class { parseFromString(){ return {querySelector:()=>null, querySelectorAll:()=>[]} } };

const mod = src + `
;globalThis.__STEPS=STEPS; globalThis.__render=render; globalThis.__S=S;
globalThis.__findings=findings; globalThis.__on=on; globalThis.__go=go;
globalThis.__enableWith=enableWith; globalThis.__REQUIRES=REQUIRES; globalThis.__FEATURES=FEATURES;
globalThis.__blockers=blockers; globalThis.__reqState=reqState;
`;
eval(mod);

let failed = 0;
for (const st of globalThis.__STEPS) {
  for (const fn of ['build','check']) {
    if (typeof st[fn] !== 'function') continue;
    try { st[fn](); }
    catch (e) { failed++; console.log(`FAIL ${st.id}.${fn}: ${e.constructor.name}: ${e.message}`); }
  }
}
console.log('steps:', globalThis.__STEPS.length, '| features:', globalThis.__FEATURES.length);
if (failed) { console.log(`\n${failed} step function(s) threw`); process.exit(1); }
console.log('every step build() and check() ran clean');
