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
const webmcpSource = fs.readFileSync(new URL('../../web/webmcp.js', import.meta.url), 'utf8');
const setupWebmcpSource = fs.readFileSync(new URL('../../web/setup_webmcp.js', import.meta.url), 'utf8');
// #2926 — the page's own code: its inline scripts and the files it splits
// into (setup_params.js, setup_steps.js, setup_xml.js), in the page's
// order, as ONE source — classic scripts share one global scope in the
// browser. The generated resources and the WebMCP files load on their own.
const SHARED = new Set(['setup_catalogue.js', 'setup_l10n.js', 'webmcp.js', 'setup_webmcp.js']);
const pageScripts = [...html.matchAll(/<script(?: src="([^"]+)")?>([\s\S]*?)<\/script>/g)].filter((m) => !SHARED.has(m[1]));
const src = pageScripts.map((m) => (m[1] ? fs.readFileSync(new URL(`../../web/${m[1]}`, import.meta.url), 'utf8') : m[2])).join('\n');
// #2925 — files a page before the <answers> tree wrote, with the state each
// loads to (read here: load() replaces URL with a stub).
const FIXTURES = new URL('./fixtures/', import.meta.url);
const fixtures = Object.fromEntries(fs.readdirSync(FIXTURES).map((f) => [f, fs.readFileSync(new URL(f, FIXTURES), 'utf8')]));
const fixture = (name) => fixtures[name];
const fixtureNames = Object.keys(fixtures).filter((f) => f.endsWith('.xml')).map((f) => f.slice(0, -4)).sort();
// #2926 — the WebMCP tools' names, annotations and input schemas (words
// aside), pinned: moving the page's code must not change what agents see.
const toolPin = fs.readFileSync(new URL('./webmcp_tools.json', import.meta.url), 'utf8');
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
  name:'Harness Space', country:'FR', currency:'EUR', timezone:'Europe/Paris', environment:'prod', language:'de', brandColor:'#1f3a5f',
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
  // 'service' is the page's key for the service_charge event type, and
  // 'named' a scope the server does not know (#2331): both must arrive in
  // the server's own words.
  domains:{payment:{on:true,required:2,ownerSignOff:true,validators:'members'},reservation_delete:{on:true,required:1,ownerSignOff:false},
    service:{on:true,required:3,ownerSignOff:false},
    price_negotiation:{on:true,required:1,ownerSignOff:false,validators:'named'}},
  autoValidate:{admin:true,owner:false},
  members:[{name:'Ada',email:'ada@example.com',role:'admin',pct:'100',overage:'packages',wholeSpaces:true,simultaneous:'3',limit:'5'},
    {name:'Bob',email:'bob@example.com',role:'member',pct:'50',overage:'payg',wholeSpaces:false,simultaneous:'',limit:''}],
});

// One page load: fresh globals, the resource, the script. `locale` is the
// ?lang= parameter (null for none); the browser says `browser`; `remembered`
// is the language this page stored on an earlier visit.
function load(locale, stored, { browser = 'fr-FR', remembered = null, modelContext = null, search = '', patch = (s) => s } = {}) {
  created = [];
  const byId = {};
  for (const id of ['form','bar','rail','nav','saved','allmode','expertview','expertwrap','stepno','lang']) byId[id]=mk('div');
  const chrome = { 'data-t': marked('data-t').map(k => ({k, e: mk('span')})), 'data-th': marked('data-th').map(k => ({k, e: mk('p')})) };
  for (const list of Object.values(chrome)) for (const x of list) x.e.setAttribute(list === chrome['data-t'] ? 'data-t' : 'data-th', x.k);
  const store = stored ? { 'deskilo-setup-v1': JSON.stringify(stored) } : {};
  if (remembered) store['deskilo-setup-v1-lang'] = remembered;
  globalThis.document = {
    createElement: mk, getElementById:(id)=>byId[id]||mk('div'), documentElement:{lang:''}, title:'', ...(modelContext ? { modelContext } : {}),
    querySelectorAll:(sel)=>sel==='[data-t]'?chrome['data-t'].map(x=>x.e):sel==='[data-th]'?chrome['data-th'].map(x=>x.e):[],
  };
  globalThis.window = { scrollTo(){} };
  globalThis.location = { search: (locale ? `?lang=${locale}` : '') + (search ? (locale ? '&' : '?') + search : '') };
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
  eval(patch(src) + `
;globalThis.__STEPS=STEPS; globalThis.__FEATURES=FEATURES; globalThis.__exportXml=exportXml; globalThis.__S=S;
globalThis.__recommend=recommendLevels; globalThis.__answer=answerQuestion; globalThis.__levelsNow=levelsNow; globalThis.__parseBack=parseBack;
globalThis.__applicable=()=>applicable().map(st=>st.id); globalThis.__go=go; globalThis.__setExpert=setExpert; globalThis.__cur=()=>cur;
globalThis.__setMode=setMode; globalThis.__migrate=migrate;
`);
  // The shared module and the questionnaire's tools, as the page loads them
  // after its own script (#2501).
  eval(webmcpSource);
  eval(setupWebmcpSource);
  return { byId, chrome, exportXml: () => { globalThis.__exportXml(); return xml; } };
}

// `--export-xml=<mode>` prints ONE real page export on stdout and stops.
// It is how a Dart test reads what the page ACTUALLY produces (#1559):
// the old contract test asserted against a hand-written fixture, which
// could not notice that the page had stopped putting the working day and
// the booking policies into the <configuration> the app consumes.
//
//   answered     every question answered, every feature on
//   policies-off the same answers with bookingPolicies OFF — the export
//                must then carry the feature's documented off-values,
//                not the owner's answers
//   defaults     a first visit that only names the space and turns the
//                configuration transfer on
//   transfer-off a first visit that switches the configuration transfer
//                OFF — the file must carry the configuration all the same
//                (#2331), the app asks before applying it
const EXPORT_MODES = {
  answered: (features) => answers(features),
  'policies-off': (features) => {
    const a = answers(features);
    return { ...a, features: { ...a.features, bookingPolicies: false } };
  },
  defaults: () => ({ name: 'Defaults Space', features: { configurationTransfer: true } }),
  'transfer-off': () => ({ name: 'Transfer Off Space', features: { configurationTransfer: false } }),
  // #2868 — a first visit that answers the plain questions below: the file
  // carries a <profile> the app's import keeps as the setup journey.
  profile: () => ({ name: 'Profile Space' }),
};
const EXPORT_ANSWERS = { profile: ['association', 'issue_invoices', 'vat_registered', 'door_tablet'] };
const exportFlag = process.argv.find((a) => a.startsWith('--export-xml'));
if (exportFlag) {
  const mode = exportFlag.split('=')[1] || 'answered';
  const build = EXPORT_MODES[mode];
  if (!build) { console.error(`unknown --export-xml mode "${mode}"`); process.exit(2); }
  load('en', null); // one plain load, only to learn FEATURES
  const page = load('en', build(globalThis.__FEATURES));
  for (const q of EXPORT_ANSWERS[mode] || []) globalThis.__answer(q, true);
  process.stdout.write(page.exportXml());
  process.exit(0);
}

// #2868 — `--recommend-all` answers every combination of the plain
// questions, in order, on a fresh page, and prints what the page then
// recommends and which switches it ticked: setup_levels_web_test compares
// both with setup_levels.dart, so the page cannot drift from the app.
if (process.argv.includes('--recommend-all')) {
  load('en', null);
  const P = globalThis.window.__setup;
  const questions = globalThis.window.SETUP_LEVELS.questions;
  const ticked = () => Object.entries(P.S.features).filter(([, v]) => v).map(([k]) => k).sort();
  const out = { initial: ticked(), combos: [] };
  // Answering touches only the switches and the journey: putting those two
  // back is a fresh page, without drawing it 4096 times.
  const fresh = JSON.stringify({ features: P.S.features, journey: P.S.journey });
  for (let bits = 0; bits < 1 << questions.length; bits++) {
    Object.assign(P.S, JSON.parse(fresh));
    questions.forEach((q, i) => globalThis.__answer(q, (bits & (1 << i)) !== 0));
    const rec = globalThis.__recommend(P.S.journey.answers);
    out.combos.push({ bits, recommended: Object.fromEntries(Object.entries(rec).map(([p, r]) => [p, `${r.level}/${r.reason}`])),
      levels: globalThis.__levelsNow(), on: ticked() });
  }
  // A pipe takes the text in chunks: exit only once it is all written.
  await new Promise((done) => process.stdout.write(JSON.stringify(out), done));
  process.exit(0);
}

// A small XML reader for the page's own export: elements, attributes, text,
// `a > b` and descendant selectors — what parseBack asks of DOMParser.
function miniXml(text) {
  const unescape = (v) => v.replace(/&#(\d+);/g, (m, n) => String.fromCharCode(Number(n))).replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
  const node = (tagName, attrs, parent) => ({ tagName, attrs, parent, children: [], text: '',
    get textContent() { return this.text + this.children.map((c) => c.textContent).join(''); },
    getElementsByTagName(tag) { return this.querySelectorAll(tag); },
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }, hasAttribute(k) { return k in this.attrs; },
    querySelectorAll(sel) {
      const steps = sel.split('>').map((x) => x.trim());
      const all = []; const walk = (n) => { for (const c of n.children) { all.push(c); walk(c); } }; walk(this);
      return all.filter((e) => { let cur = e; for (let i = steps.length - 1; i >= 0; i--) { if (!cur || cur.tagName !== steps[i]) return false; if (i > 0) cur = cur.parent; if (cur === this && i > 0) return false; } return true; });
    },
    querySelector(sel) { return this.querySelectorAll(sel)[0] ?? null; } });
  const doc = node('#document', {}, null);
  let cur = doc;
  let at = 0;
  for (const m of text.matchAll(/<(\/?)([\w-]+)((?:\s+[\w-]+="[^"]*")*)\s*(\/?)>/g)) {
    cur.text += unescape(text.slice(at, m.index).replace(/<\?[^>]*\?>/g, ''));
    at = m.index + m[0].length;
    if (m[1]) { cur = cur.parent; continue; }
    const attrs = {}; for (const a of m[3].matchAll(/([\w-]+)="([^"]*)"/g)) attrs[a[1]] = unescape(a[2]);
    const e = node(m[2], attrs, cur); cur.children.push(e);
    if (!m[4]) cur = e;
  }
  doc.documentElement = doc.children[0];
  return doc;
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

// #2501 — the WebMCP tools, against a fake modelContext. An agent here is a
// function that calls the tools the page registered.
const fakeContext = () => {
  const tools = new Map();
  const ctx = { tools, registered: 0, aborted: 0,
    registerTool(def, { signal } = {}) {
      ctx.registered++;
      tools.set(def.name, def);
      signal?.addEventListener('abort', () => { ctx.aborted++; if (tools.get(def.name) === def) tools.delete(def.name); });
      return Promise.resolve();
    },
    call: async (name, input = {}) => tools.get(name).execute(input, {}) };
  return ctx;
};
{
  const eq = (a, b, what) => { if (JSON.stringify(a) !== JSON.stringify(b)) fail(`webmcp: ${what}: got ${JSON.stringify(a)}, want ${JSON.stringify(b)}`); };
  const toolNames = ['list_parameters', 'get_answers', 'set_answer', 'set_answers', 'explain_parameter', 'diff_with_default', 'export_configuration', 'reset', 'seed_vat_rates'];

  // Registration happens once, with the nine tools.
  let ctx = fakeContext();
  load('en', null, { modelContext: ctx });
  eq([...ctx.tools.keys()], toolNames, 'registered tools');
  const wordless = (v) => Array.isArray(v) ? v.map(wordless) : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).filter(([k]) => k !== 'description').map(([k, x]) => [k, wordless(x)])) : v;
  eq([...ctx.tools.values()].map(({ name, annotations, inputSchema }) => ({ name, annotations: annotations || null, inputSchema: wordless(inputSchema) })), JSON.parse(toolPin), 'the tools and their schemas (tool/setup/webmcp_tools.json)');
  eq(ctx.registered, toolNames.length, 'registerTool calls');
  const P = globalThis.window.__setup;

  // Unsupported environment: no throw, nothing registered, the page lives.
  load('en', null);
  eq(globalThis.window.WebMcp.register([]).supported, false, 'unsupported reports supported:false');
  eq(typeof globalThis.window.__setup.buildXml, 'function', 'page still exposes its surface');
  // A modelContext that throws never reaches the page.
  load('en', null, { modelContext: { registerTool() { throw new Error('boom'); } } });

  // The tool list and the page agree on every parameter, both ways.
  ctx = fakeContext();
  load('en', null, { modelContext: ctx });
  {
    const Pg = globalThis.window.__setup;
    const listed = (await ctx.call('list_parameters')).data.parameters.map(p => p.key);
    const leaves = [];
    const walk = (o, path) => {
      for (const [k, v] of Object.entries(o)) {
        const key = path ? `${path}.${k}` : k;
        if (key in Pg.PARAM_EXCLUDED) continue;
        if (v && typeof v === 'object' && !Array.isArray(v)) walk(v, key); else leaves.push(key);
      }
    };
    walk(Pg.DEFAULTS, '');
    const features = Pg.FEATURES.map(f => 'features.' + f[0]);
    const missing = leaves.filter(k => !listed.includes(k));
    if (missing.length) fail(`webmcp: answers in the page but not in list_parameters: ${missing.join(', ')} (add a PARAM_META row or a PARAM_EXCLUDED reason)`);
    const extra = listed.filter(k => !leaves.includes(k) && !features.includes(k));
    if (extra.length) fail(`webmcp: list_parameters offers answers the page does not have: ${extra.join(', ')}`);
    const lacking = features.filter(k => !listed.includes(k));
    if (lacking.length) fail(`webmcp: features missing from list_parameters: ${lacking.join(', ')}`);
    const noWords = Pg.PARAM_META.filter(m => !(m[1] in globalThis.window.SETUP_L10N.en.s)).map(m => m[0]);
    if (noWords.length) fail(`webmcp: PARAM_META rows whose label key is not in the l10n resource: ${noWords.join(', ')}`);
    console.log('webmcp parameters:', listed.length, '(' + features.length + ' features)');

    // set_answer validates like the UI.
    let r = await ctx.call('set_answer', { key: 'granularity', value: 'quarterly' });
    if (r.ok || r.error.code !== 'validation_error' || !r.error.allowed?.includes('half_day')) fail('webmcp: invalid granularity is not a validation_error with the allowed set');
    r = await ctx.call('set_answer', { key: 'brandColor', value: 'blue' });
    if (r.ok) fail('webmcp: brandColor "blue" accepted');
    r = await ctx.call('set_answer', { key: 'nope', value: 1 });
    if (r.ok || r.error.code !== 'not_found') fail('webmcp: unknown key is not not_found');
    r = await ctx.call('set_answer', { key: 'sites', value: [] });
    if (r.ok || r.error.code !== 'unsupported') fail('webmcp: a collection is not refused as unsupported');

    // A REQUIRES violation names the parent.
    await ctx.call('set_answer', { key: 'features.bookingPolicies', value: false });
    r = await ctx.call('set_answer', { key: 'policies.allowPast', value: true });
    if (r.ok || r.error.code !== 'requires_feature' || r.error.requires !== 'features.bookingPolicies' || !r.error.message.includes(Pg.featureTitle('bookingPolicies'))) fail('webmcp: a gated question does not name its feature');
    r = await ctx.call('set_answer', { key: 'features.bookingPolicies', value: true });
    r = await ctx.call('set_answer', { key: 'policies.allowPast', value: true });
    if (!r.ok || Pg.S.policies.allowPast !== true) fail('webmcp: a gated question is refused with its feature on');

    // A switch turns its parents on and says so.
    await ctx.call('reset');
    r = await ctx.call('set_answer', { key: 'features.vatReport', value: true });
    if (!r.ok || !('features.vatDeclarations' in r.data.also_changed || 'features.vatManagement' in r.data.also_changed) && Pg.REQUIRES.vatReport) fail('webmcp: a switch does not report the parents it enabled');
    await ctx.call('reset');

    // set_answers is atomic.
    const before = JSON.stringify(Pg.S);
    r = await ctx.call('set_answers', { answers: { name: 'Atomic', country: 'ZZ', dayStart: 'noon' } });
    if (r.ok || r.error.errors?.length !== 2) fail('webmcp: set_answers does not list one error per refused key');
    eq(JSON.stringify(Pg.S), before, 'a refused set_answers leaves the state untouched');

    // Secrets are masked.
    await ctx.call('set_answer', { key: 'einvoice.token', value: 'sekret' });
    const got = (await ctx.call('get_answers')).data.answers['einvoice.token'];
    if (got === 'sekret') fail('webmcp: a secret is returned by get_answers');
    await ctx.call('reset');
    eq((await ctx.call('diff_with_default')).data.differences, [], 'no difference after reset');
  }

  // The representative questionnaire: the tools and the UI give one export.
  {
    const run = async () => {
      const c = fakeContext();
      const page = load('en', null, { modelContext: c });
      const rates = globalThis.window.__setup.VAT_RATES.FR.map(([label, percent]) => ({ label, percent }));
      const r1 = await c.call('set_answers', { answers: {
        name: 'Agent Space', country: 'FR', vatRegime: 'registered', vatId: 'FR12345678901', regNumber: 'RCS 1', street: '1 Rue', postal: '34000', city: 'Montpellier',
        'features.moneyTab': false, 'features.services': false, 'features.workingHours': true, 'features.bookingPolicies': true, 'features.kioskMode': true, 'policies.allowPast': true } });
      if (!r1.ok) fail('webmcp: representative answers refused: ' + JSON.stringify(r1.error));
      const r2 = await c.call('seed_vat_rates');
      if (!r2.ok) fail('webmcp: seed_vat_rates refused');
      const exported = await c.call('export_configuration', { format: 'xml' });
      return { exported, rates, page };
    };
    const { exported, rates } = await run();
    if (!exported.ok) fail('webmcp: export refused: ' + JSON.stringify(exported.error));
    else {
      // What clicking the same answers leaves in storage, loaded as a visit.
      const ui = load('en', { name: 'Agent Space', country: 'FR', vatRegime: 'registered', vatId: 'FR12345678901', regNumber: 'RCS 1', street: '1 Rue', postal: '34000', city: 'Montpellier',
        features: { moneyTab: false, services: false, workingHours: true, bookingPolicies: true, kioskMode: true }, policies: { allowPast: true }, vatRates: rates });
      eq(exported.data.text, ui.exportXml(), 'the tools export equals the UI export for the same answers');
    }
    // The export refuses while a blocking finding remains.
    const c = fakeContext();
    load('en', null, { modelContext: c });
    const blocked = await c.call('export_configuration');
    if (blocked.ok || blocked.error.code !== 'blocked') fail('webmcp: export of an unnamed space is not blocked');
  }

  // A language switch re-registers with the new words.
  {
    const c = fakeContext();
    load('en', null, { modelContext: c });
    const english = c.tools.get('get_answers').description;
    globalThis.window.__setup.setLang('de');
    eq(c.registered, 2 * toolNames.length, 'registerTool calls after a language switch');
    eq(c.aborted, toolNames.length, 'tools unregistered by the language switch');
    eq([...c.tools.keys()], toolNames, 'tools after a language switch');
    if (c.tools.get('get_answers').description === english) fail('webmcp: the description did not follow the language');
    if (c.tools.get('get_answers').description !== globalThis.window.SETUP_L10N.de.s.webmcpGetAnswers) fail('webmcp: the German description is not the German string');
  }
}
// #2868 — the questions step round-trips: the answers and the levels the
// switches reach come back from the file the page exported, and a file
// made without the step carries no profile.
{
  const page = load('en', { name: 'Profile Space' });
  if (page.exportXml().includes('<profile')) fail('profile: exported although no question was answered');
  globalThis.__answer('issue_invoices', true);
  globalThis.__answer('vat_registered', true);
  globalThis.__answer('door_tablet', true);
  const P = globalThis.window.__setup;
  const levels = JSON.stringify(globalThis.__levelsNow());
  const answers = JSON.stringify(P.S.journey.answers);
  const first = page.exportXml();
  if (!first.includes('<answer question="vat_registered" value="true"/>') || !first.includes('<level of="tax" value="vat"/>')) fail('profile: the export lacks the answers or the levels');
  P.reset();
  globalThis.DOMParser = class { parseFromString(text) { return miniXml(text); } };
  globalThis.__parseBack(first);
  if (JSON.stringify(globalThis.__levelsNow()) !== levels) fail(`profile: levels after import ${JSON.stringify(globalThis.__levelsNow())}, want ${levels}`);
  const back = Object.fromEntries(Object.entries(P.S.journey.answers).filter(([, v]) => v));
  if (JSON.stringify(back) !== answers) fail(`profile: answers after import ${JSON.stringify(back)}, want ${answers}`);
  if (page.exportXml() !== first) fail('profile: the re-exported file differs from the imported one');
  else console.log('profile: round-trips');
  // With the guide switched off the page is as before: no questions step.
  load('en', { name: 'Off Space', features: { setupGuide: false } });
  if (globalThis.__STEPS.find((st) => st.id === 'levels').applies()) fail('profile: the questions step shows with setupGuide off');
}
// #2868 — the switches are the expert view: the questions are the way
// through, and every way to the features step still arrives there.
{
  const steps = () => globalThis.__applicable();
  const page = load('en', { name: 'Expert Space' });
  if (steps().includes('features') || !steps().includes('levels')) fail(`expert: the default path is ${steps().join(',')}`);
  if (!page.byId.expertview || page.byId.expertview.checked) fail('expert: the expert switch is on by default');
  const levels = globalThis.__STEPS.find((st) => st.id === 'levels');
  const next = steps()[steps().indexOf('levels') + 1];
  if (next === 'features') fail('expert: the questions lead to the switches');
  // A "needs the feature" note, a finding, the rail: they all go() there.
  globalThis.__go('features');
  if (globalThis.__cur() !== 'features' || !steps().includes('features')) fail('expert: following a link to the features step does not open it');
  if (!page.byId.expertview.checked) fail('expert: the switch does not show the expert view open');
  globalThis.__setExpert(false);
  if (steps().includes('features') || globalThis.__cur() !== 'levels') fail(`expert: closing the expert view leaves ${globalThis.__cur()}`);
  // The levels step offers it too.
  const shown = [];
  const walk = (n) => { for (const c of (n.children || [])) { if (typeof c !== 'object') continue; if (c.tagName === 'BUTTON') shown.push(c); walk(c); } };
  for (const k of levels.build()) if (k && typeof k === 'object') { if (k.tagName === 'BUTTON') shown.push(k); walk(k); }
  if (!shown.some((b) => b._text === globalThis.window.SETUP_L10N.en.s.levelsExpertOpen || b.children.includes(globalThis.window.SETUP_L10N.en.s.levelsExpertOpen))) fail('expert: the questions step does not offer the expert view');
  // A link straight to the step (the guide, a colleague) opens it.
  load('en', { name: 'Linked Space' }, { search: 'step=features' });
  if (globalThis.__cur() !== 'features' || !steps().includes('features')) fail('expert: ?step=features does not open the expert view');
  // With the guide off, the switches are the way through, as before.
  const off = load('en', { name: 'Off Space', features: { setupGuide: false } });
  if (!steps().includes('features')) fail('expert: the features step is hidden with setupGuide off');
  if (off.byId.expertwrap.style.display !== 'none') fail('expert: the expert switch shows with setupGuide off');
  console.log('expert: the switches are the expert view; links open it');
}
// #2924 — one pure normalize() repairs the answers on every save and every
// load; drawing a step never writes. So the WebMCP tools, which compute
// their blocking findings without drawing anything, see what the screen
// shows once drawn, and a stored answer is repaired before any step runs.
{
  const same = (a, b, what) => { if (JSON.stringify(a) !== JSON.stringify(b)) fail(`normalize: ${what}: got ${JSON.stringify(a)}, want ${JSON.stringify(b)}`); };
  const c = fakeContext();
  load('en', { name: 'Normal Space', domains: { payment: { on: true, required: '0', ownerSignOff: false } } }, { modelContext: c });
  const P = globalThis.window.__setup;
  const domainErr = globalThis.window.SETUP_L10N.en.s.rolesErrDomain.split('{')[0];
  const errs = () => P.findings().filter((x) => x.lvl === 'err').map((x) => x.t);
  if (!errs().some((t) => t.startsWith(domainErr))) fail('normalize: the fixture lacks its blocking domain finding');
  const r = await c.call('set_answers', { answers: { 'features.moneyTab': false } });
  if (!r.ok) fail('normalize: set_answers refused: ' + JSON.stringify(r.error));
  const tools = r.data.blocking_findings;
  globalThis.__setMode(true); // every step drawn, as the screen shows them
  same(tools, errs(), 'blocking_findings after set_answers vs the drawn screen');
  if (tools.some((t) => t.startsWith(domainErr))) fail('normalize: a card whose switch is off still blocks');
  // A reset that cannot follow the number's date, repaired on load.
  load('en', { name: 'Numbered Space', numbering: { prefix: 'F-', datePart: 'none', digits: '4', reset: 'monthly' } });
  const Q = globalThis.window.__setup;
  if (globalThis.__cur() === 'legal') fail('normalize: the legal step was drawn');
  same(Q.S.numbering.reset, 'never', 'numbering.reset after load');
  // Pure: the answers handed in are not touched.
  const given = { ...Q.S, numbering: { ...Q.S.numbering, datePart: 'year', reset: 'monthly' } };
  const out = Q.normalize(given);
  same([given.numbering.reset, out.numbering.reset], ['monthly', 'yearly'], 'normalize copies, never mutates');
  console.log('normalize: the tools and the screen read the same answers');
}
// #2925 — the page's own round trip is its answers, written once as a typed
// tree and read back by readTree(): every answer set exports, loads and
// exports again to the same bytes.
{
  // load() puts the stub DOMParser back; the reader goes in after it.
  const reads = () => { globalThis.DOMParser = class { parseFromString(t) { return miniXml(t); } }; };
  const sets = { ...EXPORT_MODES, harness: EXPORT_MODES.answered };
  for (const [mode, build] of Object.entries(sets)) {
    const page = load('en', build(globalThis.__FEATURES));
    for (const q of EXPORT_ANSWERS[mode] || []) globalThis.__answer(q, true);
    const first = page.exportXml();
    globalThis.window.__setup.reset();
    reads();
    globalThis.__parseBack(first);
    if (page.exportXml() !== first) fail(`answers: ${mode}: export -> load -> export differs`);
  }
  // A new scalar answer is a DEFAULTS entry and a PARAM_META row, and
  // travels with no export or import line of its own.
  const patch = (s) => s.replace('const DEFAULTS={\n', "const DEFAULTS={\n synthetic:'',\n")
    .replace('const PARAM_META=[\n', "const PARAM_META=[\n ['synthetic','identityName','text'],\n");
  const page = load('en', { name: 'Synthetic Space', synthetic: 'kept' }, { patch });
  const P = globalThis.window.__setup;
  if (!('synthetic' in P.DEFAULTS)) fail('answers: the synthetic parameter was not patched in');
  const first = page.exportXml();
  P.reset();
  reads();
  if (P.S.synthetic !== '') fail('answers: reset kept the synthetic answer');
  globalThis.__parseBack(first);
  if (P.S.synthetic !== 'kept') fail(`answers: the synthetic answer came back as ${JSON.stringify(P.S.synthetic)}`);
  if (page.exportXml() !== first) fail('answers: the synthetic answer does not round-trip');
  // Each rule of migrate(), on answers as a page before it stored them.
  const m = globalThis.__migrate({ policies: { gridHours: true }, perms: { admin: ['manageMembers'] }, vatExigibility: 'payment', vatPeriod: 'biennial' });
  if (m.policies.outsideHours !== 'walkup_only' || 'gridHours' in m.policies) fail('migrate: gridHours');
  if (!m.perms.admin.includes('viewAnalytics') || m.permsV !== 2) fail('migrate: the permissions added by #2331');
  if (m.vatExigibility !== 'cash' || m.vatPeriod !== 'quarter') fail('migrate: the tax point or the period');
  // Files written before #2925: every legacy shape loads, through the
  // frozen parseLegacySetup and migrate(), to the state the page's own
  // parseBack reached before (pinned as JSON from that page). A key the
  // pin lacks is a later default and may be added.
  const within = (got, want, at) => {
    if (want && typeof want === 'object') {
      if (!got || typeof got !== 'object' || Array.isArray(want) !== Array.isArray(got)) return [at];
      if (Array.isArray(want) && want.length !== got.length) return [at + '.length'];
      return Object.keys(want).flatMap((k) => within(got[k], want[k], at + '.' + k));
    }
    return got === want ? [] : [`${at}: ${JSON.stringify(got)} != ${JSON.stringify(want)}`];
  };
  const shapes = fixtureNames;
  for (const name of shapes) {
    load('en', null);
    globalThis.window.__setup.reset();
    reads();
    globalThis.__parseBack(fixture(name + '.xml'));
    const off = within(globalThis.window.__setup.S, JSON.parse(fixture(name + '.json')), name);
    if (off.length) fail(`answers: ${name} loads differently:\n  ${off.slice(0, 8).join('\n  ')}`);
  }
  if (shapes.length < 5) fail(`answers: ${shapes.length} legacy fixtures`);
  console.log(`answers: round-trip; ${shapes.length} legacy files load as before`);
}
console.log('steps:', globalThis.__STEPS.length, '| features:', globalThis.__FEATURES.length);
console.log('locales:', LOCALES.join(','));
if (failed) { console.log(`\n${failed} failure(s)`); process.exit(1); }
console.log(`xml: byte-identical in ${LOCALES.length} locales (${reference.length} bytes)`);
console.log('every step build() and check() ran clean');
