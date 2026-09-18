// Drive every step's build() and check() against a minimal DOM, so a
// ReferenceError like `avail` fails HERE rather than on the published page.
import fs from 'fs';

// web/setup.html is 1 000 lines of dense JavaScript with no build step and
// no runtime anywhere in CI — so a plain ReferenceError in one step's
// build() ships, and the step renders NOTHING. That is not theoretical:
// `avail` did exactly that to step 2 (Features) on the published page,
// and because render() threw before drawing the navigation, the wizard
// became a dead end with no message.
//
// This drives every step's build() and check() against a minimal DOM, in
// each of the five languages the page speaks (#1366). It is not a UI test.
// It asks three questions:
//
//  1. does this code run — in every language?
//  2. does the language change what the page SAYS (lang, title, chrome) and
//     never leave French on a page that is not French?
//  3. does it never change what the page EXPORTS — the same answers give
//     byte-identical XML in all five languages?
const html = fs.readFileSync(new URL('../../web/setup.html', import.meta.url), 'utf8');
const l10nSource = fs.readFileSync(new URL('../../web/setup_l10n.js', import.meta.url), 'utf8');
const catalogueSource = fs.readFileSync(new URL('../../web/setup_catalogue.js', import.meta.url), 'utf8');
const src = /<script>([\s\S]*)<\/script>/.exec(html)[1];
const LOCALES = ['en', 'fr', 'de', 'es', 'it'];

let created = [];
const mk = (tag) => {
  const e = {
    tagName:(tag||'').toUpperCase(), children:[], attrs:{}, style:{}, classList:{
      _s:new Set(), add(...c){c.forEach(x=>this._s.add(x))}, remove(...c){c.forEach(x=>this._s.delete(x))},
      toggle(c,on){on?this._s.add(c):this._s.delete(c)}, contains(c){return this._s.has(c)} },
    append(...k){k.forEach(x=>{if(x!=null)this.children.push(x)})},
    setAttribute(k,v){this.attrs[k]=v}, getAttribute(k){return this.attrs[k]??null},
    insertBefore(n){this.children.unshift(n)}, remove(){}, click(){},
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
    set textContent(v){this.children.length=0; this._text=String(v)}, get textContent(){return ''},
    set innerHTML(v){this._html=String(v)}, set value(v){this._v=v}, get value(){return this._v??this.attrs.value??''},
    set checked(v){this._c=v}, get checked(){return !!this._c},
    set disabled(v){this._d=v}, get disabled(){return !!this._d},
    set title(v){this.attrs.title=v}, set onclick(f){}, set oninput(f){}, set onchange(f){},
    get options(){return this.children.filter(c=>typeof c==='object'&&c.tagName==='OPTION')}, scrollTo(){},
  };
  created.push(e);
  return e;
};

// The static chrome as the page marks it up: every data-t / data-th element.
const marked = (attr) => [...html.matchAll(new RegExp(`${attr}="(\\w+)"`, 'g'))].map(m => m[1]);

// A full set of answers, with every feature on so every step asks everything.
// ASCII on purpose: anything accented on a non-French page must come from
// the page, not from these answers.
const everyFeature = (features) => Object.fromEntries(features.map(f => [f[0], true]));
const answers = (features) => ({
  name:'Harness Space', country:'FR', currency:'EUR', timezone:'Europe/Paris', environment:'prod', language:'de',
  address:'1 Harness Road', whatsapp:'https://chat.whatsapp.com/harness',
  weekdays:['1','2','3','4','5','6'], granularity:'hours', dayStart:'07:30', boundary:'12:30', dayEnd:'19:00',
  closures:['2026-12-25'], halfDayHours:'4', fullDayHours:'9', deskOpacity:'80',
  horizonDays:'365', minDuration:'60', maxDuration:'720',
  policies:{allowPast:true,adminCheckout:true,outsideHours:'walkup_only',simultaneous:'2'},
  invites:{fr:'Bonjour {firstName}',en:'Hello {firstName}',de:'',es:'',it:''},
  einvoice:{url:'https://einvoice.example/upload',token:'tok',header:'Authorization',field:'file',uatUrl:'',uatToken:'',devUrl:'',devToken:'',
    customerUrl:'https://customer.example/in',customerToken:'ctok',customerHeader:'',customerField:''},
  vatPeriod:'month',
  features:everyFeature(features),
  sites:[{name:'North',street:'2 North Street',postal:'1000',city:'Northtown',legalId:'123'}],
  // An unnamed level and an empty seat prefix take the export's fallback names.
  levels:[{name:'Ground',site:'North',bookable:true,offices:[{name:'Main room',bookable:true,price:'40',desks:[{name:'Long desk',seats:6,prefix:'Seat'},{name:'Corner',seats:'',prefix:''}]}]},
    {name:'',offices:[{name:'Loft',bookable:false,price:'',desks:[{name:'D1',seats:3,prefix:''}]}]}],
  accessories:[{name:'Screen',supp:'2.5'}], services:[{name:'Locker',price:'10',vat:'20'}],
  tiers:[{from:0,to:50,fee:'150',over:'20'},{from:50,to:100,fee:'250',over:'18'}], subLevels:['50','100'], freeLevel:false,
  packages:[{name:'Ten days',days:'10',price:'200'}],
  pay:{iban:'FR7630006000011234567890189',paypal_me:'harness',wero:'',lydia:'',wise:'',reference:'Name and month',bank_name:'Bank',account_number:'',bank_code:'',bic:'AGRIFRPP'},
  org:'company', vatRegime:'registered', vatExigibility:'payment',
  numbering:{prefix:'F-',datePart:'year_month',digits:'5',reset:'monthly'}, memberNumbering:{prefix:'M-',digits:'3'},
  regNumber:'RCS 123', vatId:'FR12345678901', exemption:'', street:'1 Harness Road', postal:'34000', city:'Montpellier',
  vatRates:[{label:'Standard',percent:'20',group:'standard',validFrom:'2024-01-01'},{label:'Reduced',percent:'5.5',group:'reduced',validFrom:''}],
  mentions:{legalForm:'SAS',register:'',terms:'30 days',penalty:'',recovery:'40',escompte:'',insurance:'',special:''},
  reminders:{levels:3,firstDays:10,betweenDays:7,automatic:false},
  validation:{required:2,ownerSignOff:true},
  domains:{payment:{on:true,required:2,ownerSignOff:true,validators:'members'},reservation_delete:{on:true,required:1,ownerSignOff:false},
    price_negotiation:{on:true,required:1,ownerSignOff:false,validators:'named'}},
  autoValidate:{admin:true,owner:false},
  members:[{name:'Ada',email:'ada@example.com',role:'admin',pct:'100',overage:'packages',wholeSpaces:true,simultaneous:'3',limit:'5'},
    {name:'Bob',email:'bob@example.com',role:'member',pct:'50',overage:'payg',wholeSpaces:false,simultaneous:'',limit:''}],
});

// One page load: fresh globals, the resource, the script. `locale` is the
// ?lang= parameter (null for none); the browser says `browser`; `remembered`
// is the language this page stored on an earlier visit.
function load(locale, stored, { browser = 'fr-FR', remembered = null } = {}) {
  created = [];
  const byId = {};
  for (const id of ['form','bar','rail','nav','saved','allmode','stepno','lang']) byId[id]=mk('div');
  const chrome = { 'data-t': marked('data-t').map(k => ({k, e: mk('span')})), 'data-th': marked('data-th').map(k => ({k, e: mk('p')})) };
  for (const list of Object.values(chrome)) for (const x of list) x.e.setAttribute(list === chrome['data-t'] ? 'data-t' : 'data-th', x.k);
  const store = stored ? { 'deskilo-setup-v1': JSON.stringify(stored) } : {};
  if (remembered) store['deskilo-setup-v1-lang'] = remembered;
  globalThis.document = {
    createElement: mk, getElementById:(id)=>byId[id]||mk('div'), documentElement:{lang:''}, title:'',
    querySelectorAll:(sel)=>sel==='[data-t]'?chrome['data-t'].map(x=>x.e):sel==='[data-th]'?chrome['data-th'].map(x=>x.e):[],
  };
  globalThis.window = { scrollTo(){} };
  globalThis.location = { search: locale ? `?lang=${locale}` : '' };
  Object.defineProperty(globalThis, 'navigator', { value:{ language:browser }, configurable:true, writable:true });
  globalThis.localStorage = { getItem:(k)=>store[k]??null, setItem:(k,v)=>{store[k]=v}, removeItem:(k)=>{delete store[k]} };
  globalThis.confirm = ()=>true;
  globalThis.alert = ()=>{};
  let xml = null;
  globalThis.Blob = class { constructor(parts){ xml = parts.join(''); } };
  globalThis.URL = { createObjectURL:()=>'blob:', revokeObjectURL(){} };
  globalThis.DOMParser = class { parseFromString(){ return {querySelector:()=>null, querySelectorAll:()=>[]} } };
  // The repository's own three files, evaluated the way the browser would.
  eval(catalogueSource);
  eval(l10nSource);
  eval(src + `
;globalThis.__STEPS=STEPS; globalThis.__FEATURES=FEATURES; globalThis.__exportXml=exportXml; globalThis.__S=S;
`);
  return { byId, chrome, exportXml: () => { globalThis.__exportXml(); return xml; } };
}

// Every string the page put on screen: text children, text set directly,
// trusted markup, and the title/placeholder attributes.
function renderedText() {
  const out = [];
  for (const e of created) {
    for (const c of e.children) if (typeof c === 'string') out.push(c);
    if (e._text) out.push(e._text);
    if (e._html) out.push(e._html);
    if (e.attrs.title) out.push(String(e.attrs.title));
    if (e.attrs.placeholder) out.push(String(e.attrs.placeholder));
  }
  return out.join('\n');
}

let failed = 0;
const fail = (msg) => { failed++; console.log('FAIL ' + msg); };
const runSteps = (locale, label) => {
  for (const st of globalThis.__STEPS) {
    for (const fn of ['build','check']) {
      if (typeof st[fn] !== 'function') continue;
      try { st[fn](); }
      catch (e) { fail(`[${locale}${label}] ${st.id}.${fn}: ${e.constructor.name}: ${e.message}`); }
    }
  }
};

const xmls = {};
let resource = null;
for (const locale of LOCALES) {
  // The defaults, as a first visit sees them.
  load(locale, null);
  resource = globalThis.window.SETUP_L10N;
  runSteps(locale, '');
  // Every question asked, then exported.
  const page = load(locale, answers(globalThis.__FEATURES));
  runSteps(locale, ' answered');
  try { xmls[locale] = page.exportXml(); }
  catch (e) { fail(`[${locale}] exportXml: ${e.constructor.name}: ${e.message}`); }

  const s = resource[locale].s;
  if (globalThis.document.documentElement.lang !== locale) fail(`[${locale}] <html lang> is "${globalThis.document.documentElement.lang}"`);
  if (globalThis.document.title !== s.setupTitle) fail(`[${locale}] title is "${globalThis.document.title}"`);
  for (const { k, e } of page.chrome['data-t']) if (e._text !== s[k]) fail(`[${locale}] data-t="${k}" reads "${e._text}"`);
  for (const { k, e } of page.chrome['data-th']) if (!e._html || !e._html.startsWith(s[k].split('{')[0])) fail(`[${locale}] data-th="${k}" not filled`);

  const text = renderedText();
  if (!text.includes(resource[locale].feature.calendarTab[0])) fail(`[${locale}] the features step does not show the ${locale} feature names`);
  if (locale !== 'fr') {
    // Each language's own name is the one thing every page shows as-is.
    const shown = ['Français', 'Español'].reduce((t, n) => t.split(n).join(''), text);
    const fr = resource.fr;
    const leaks = [];
    // French text is the French value where it differs from English (a
    // string both share — "Admin", "WhatsApp" — is nobody's leak). Copied
    // verbatim into another locale, it still counts.
    const probe = (frValue, enValue, key) => {
      if (frValue === enValue) return;
      const longest = frValue.split(/\{\w+\}|<[^>]+>/).reduce((a, b) => b.length > a.length ? b : a, '');
      if (longest.trim().length >= 12 && shown.includes(longest)) leaks.push(`${key}: ${longest}`);
    };
    const en = resource.en;
    for (const [k, v] of Object.entries(fr.s)) probe(v, en.s[k], k);
    for (const [k, v] of Object.entries(fr.feature)) { probe(v[0], en.feature[k][0], k); probe(v[1], en.feature[k][1], k + 'Desc'); }
    if (leaks.length) fail(`[${locale}] French text rendered:\n  ${leaks.slice(0, 10).join('\n  ')}`);
    if (locale === 'en') {
      const accented = shown.split('\n').filter(l => /[àâçéèêîôûùœ«»]/i.test(l));
      if (accented.length) fail(`[en] accented French-looking text rendered:\n  ${accented.slice(0, 10).join('\n  ')}`);
    }
  }
}

// Which language a visitor gets: ?lang= wins, then the one chosen here
// before, then the browser's, then English.
for (const [expected, locale, opts] of [
  ['it', 'it', { browser:'de-DE', remembered:'es' }],
  ['es', null, { browser:'de-DE', remembered:'es' }],
  ['de', null, { browser:'de-AT' }],
  ['en', null, { browser:'pt-BR' }],
  ['en', 'xx', { browser:'ja' }],
]) {
  load(locale, null, opts);
  const got = globalThis.document.documentElement.lang;
  if (got !== expected) fail(`?lang=${locale} browser=${opts.browser} remembered=${opts.remembered}: got ${got}, want ${expected}`);
}

const reference = xmls.en;
if (!reference || !reference.includes('<deskilo-workspace version="3">')) fail('no XML exported');
for (const locale of LOCALES) if (xmls[locale] !== reference) fail(`[${locale}] exported XML differs from en`);

// #1330 — the features step shows every switch exactly once, under its
// process; the harness would still pass with an empty catalogue otherwise.
{
  load('en', null);
  const step = globalThis.__STEPS.find(s => s.id === 'features');
  const shown = [];
  const walk = (n) => { for (const c of (n.children || [])) { if (typeof c !== 'object') continue; if (c.tagName === 'INPUT') shown.push(c); walk(c); } };
  for (const k of step.build()) walk(k);
  if (shown.length !== globalThis.__FEATURES.length) fail(`the features step shows ${shown.length} switches for ${globalThis.__FEATURES.length} features`);
  const processes = globalThis.window.SETUP_PROCESSES.length;
  if (!processes) fail('the process catalogue is empty');
  console.log('processes:', processes);
}
console.log('steps:', globalThis.__STEPS.length, '| features:', globalThis.__FEATURES.length);
console.log('locales:', LOCALES.join(','));
if (failed) { console.log(`\n${failed} failure(s)`); process.exit(1); }
console.log(`xml: byte-identical in ${LOCALES.length} locales (${reference.length} bytes)`);
console.log('every step build() and check() ran clean');
