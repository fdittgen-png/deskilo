// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3915 — the setup questionnaire's own code, moved out of web/setup.html
// so the page's policy allows no inline script. Loaded after the generated
// resources and before the files it is split into; setup_xml.js ends with
// the boot() call.
'use strict';
const LS='deskilo-setup-v1';

// ------------------------------------------------------------------ language (#1366)
// Every word this page shows comes from setup_l10n.js, which
// tool/build_setup_l10n.dart generates: feature, permission, validation-
// domain and country names straight from the app's ARB catalogue, and the
// page's own prose from web/setup_l10n/setup_<locale>.json. The language
// changes what the page SAYS, never what it EXPORTS: keys, defaults and the
// XML are the same in all five (tool/setup/step_harness.mjs proves it).
const L10N=(typeof window!=='undefined'&&window.SETUP_L10N)||{};
const LOCALES=['en','fr','de','es','it'];
const LANG_KEY=LS+'-lang';
// ?lang=xx, else the language chosen here last time, else the browser's,
// else English — the app's own fallback.
function pickLocale(){
 const ok=l=>l&&LOCALES.includes(l)&&L10N[l]?l:null;
 let asked=null,stored=null,browser=null;
 try{asked=new URLSearchParams(location.search).get('lang')}catch(e){asked=null}
 try{stored=localStorage.getItem(LANG_KEY)}catch(e){stored=null}
 try{browser=String(navigator.language||'').split('-')[0].toLowerCase()}catch(e){browser=null}
 return ok(asked)||ok(stored)||ok(browser)||'en';
}
let LANG=pickLocale();
// One page string, with {placeholders} filled from params. A missing key
// falls back to English, then to the key itself — never to a blank.
function T(key,params){
 const s=L10N[LANG]?.s?.[key]??L10N.en?.s?.[key]??key;
 return params?s.replace(/\{(\w+)\}/g,(m,k)=>k in params?String(params[k]):m):s;
}
const cat=(section,key)=>L10N[LANG]?.[section]?.[key]??L10N.en?.[section]?.[key];
const featureTitle=k=>(cat('feature',k)||[k])[0];
const featureDesc=k=>(cat('feature',k)||[k,''])[1];
// #1330 — the business processes the switches are grouped by. The
// structure is generated from the app's registry (setup_catalogue.js), the
// words come with the rest of the catalogue; the XML stays feature-keyed.
const PROCESSES=window.SETUP_PROCESSES||[];
const processTitle=k=>(cat('process',k)||[k])[0];
const processDesc=k=>(cat('process',k)||[k,''])[1];
const subprocessTitle=k=>(cat('subprocess',k)||[k])[0];
const permName=p=>cat('perm',p)||p;
const domainName=d=>cat('domain',d)||d;
const countryName=c=>cat('country',c)||c;
const quoted=x=>T('quoted',{x});
const quotedList=a=>a.map(quoted).join(T('listSep'));
const opts=list=>list.map(([v,k,p])=>[v,T(k,p)]);
// The published guide site: <lang>.html is the user guide, setup-<lang>.html
// the setup guide; every section's id is its anchor (user.x.y / setup.x.y).
const GUIDE_BASE='https://fdittgen-png.github.io/deskilo/guide/';
const guideUrl=anchor=>GUIDE_BASE+(anchor.startsWith('setup.')?'setup-':'')+LANG+'.html#'+anchor;
function setLang(l){if(!LOCALES.includes(l))return;LANG=l;try{localStorage.setItem(LANG_KEY,l)}catch(e){LANG=l}applyChrome();render();window.__setup.hooks.forEach(f=>{try{f()}catch(e){}})}
// The static chrome: <html lang>, the title, and every element carrying a
// data-t (text) or data-th (trusted markup from the resource) key.
function applyChrome(){
 document.documentElement.lang=LANG;
 document.title=T('setupTitle');
 const link='<a href="'+guideUrl('user.start.questionnaire')+'" target="_blank" rel="noopener">'+T('setupGuideLink')+'</a>';
 document.querySelectorAll('[data-t]').forEach(e=>{e.textContent=T(e.getAttribute('data-t'))});
 document.querySelectorAll('[data-th]').forEach(e=>{e.innerHTML=T(e.getAttribute('data-th'),{link})});
 const sel=document.getElementById('lang');sel.textContent='';
 for(const l of LOCALES){const o=document.createElement('option');o.value=l;o.textContent=ENDONYMS[l];sel.append(o)}
 sel.value=LANG;
}

// #2923 — the app's registries, generated from their Dart owners into
// setup_catalogue.js (tool/build_setup_l10n.dart); the page keeps no copy.
// features: [key, defaultOn] in registry order, the default a NEW
// workspace gets; requires / availableIn: featureManifest's tree and
// countries; permissions: WorkspacePermission in the roles screen's order;
// defaultMatrix: every permission for the co-owner, everydayMatrix() for
// the admin and the member; domains: the validation cards the page offers,
// domainGates the switch each needs, domainEventTypes the server's name
// where it differs from the page's key; invoicingCountries: where the app
// issues invoices itself; documentLanguageCountries: where the business must choose its document language (#3850);
// countries: [ISO code, currency, time zone, bank scheme, usual paper, papers allowed]; paymentSlipCountries: where invoices end on an A4 payment slip (#3852); reminders: DunningRules.defaults (#3888). Names and descriptions come from the ARB through setup_l10n.js.
const {features:FEATURES,requires:REQUIRES,availableIn:AVAILABLE_IN,permissions:PERMS,defaultMatrix:PERM_DEFAULTS,
 domains:DOMAINS,domainGates:DOMAIN_GATE,domainEventTypes:DOMAIN_EVENT_TYPE,invoicingCountries:INVOICING_COUNTRIES,documentLanguageCountries:DOCUMENT_LANGUAGE_COUNTRIES,paymentSlipCountries:PAYMENT_SLIP_COUNTRIES,countries:COUNTRIES,reminders:REMINDER_DEFAULTS}=window.SETUP_REGISTRY;
// #2926 — the untranslated words (language names, statutory VAT rate
// labels, the XML fallback names) are in setup_params.js.
const seedVatRates=()=>set('vatRates',(VAT_RATES[S.country]||[]).map(([label,percent])=>({label,percent})));
// A fresh office, named in the page language (the owner's data from then on).
function newOffice(n){return {name:T('defaultOffice',{n}),bookable:false,price:'',desks:[{name:T('defaultDesk',{n:1}),seats:4,prefix:T('defaultSeatPrefix')}]}}

// ------------------------------------------------------------------ state
const DEFAULTS={
 name:'',businessKind:'coworking',country:'FR',currency:'EUR',timezone:'Europe/Paris',environment:'dev',
 // #2561 L3 — the server's role and, for a workspace host only, the
 // explicit personal home of its people (typed in the instance wizard).
 network:{roles:'combined',homeUrl:'',homeKey:''},language:'',paper:'',address:'',whatsapp:'',brandColor:'',
 // #2562 C2a — enrolment at the personal home and the identity freshness
 // (typed in the instance wizard and the settings editor).
 enrolment:{accepting:true,lifetime:'900',reconcile:'300',skew:'30'},
 // #2472 (P) — the new discussion's directory at the personal home of a
 // combined server (platform settings personal.message_directory_*).
 directory:{pageSize:'50',queryLength:'120'},
 // #2563 C2 — how long the backchannel's receipts and ended-membership
 // tombstones are kept (platform setting federation.retention_hours), and
 // how long a server waits for an answer before it sends a message again
 // (platform setting federation.answer_wait_seconds), and how many membership facts it sends
 // per minute (platform setting federation.fact_drain_batch, #4327).
 federation:{retentionHours:'24',answerWait:'120',factBatch:'500'},
 // #4217 — how long after its first sending a checkout may be sent again under
 // its original request, per provider (platform settings payments.resend_window_*_minutes).
 paymentResend:{mollie:'50',paypal:'330',stripe:'1380'},
 // #4325 — how long a prepared e-invoice waits for its dispatch before the owner is told
 // (platform setting einvoice.stuck_attempt_minutes).
 einvoiceStuck:{minutes:'60'},quotes:{defaultValidity:'30',maxValidity:'365'},
 // #2556 — the inbox's page per source, read at the personal home and at
 // each workspace server (platform setting messaging.inbox_page_size).
 inbox:{pageSize:'50'},
 // #2863 — supplier lookup wait and quota (platform settings purchase.supplier_lookup_*).
 badgeSecurity:{failureLimit:'50',signinWhere:'enrolled_kiosks'},counter:{fiscalObligation:'register_required',documentChannel:'share',customerless:'allowed'},stock:{allowNegative:false,addressSeparator:'-',tagMode:'none',countDays:'0',priceRounding:'none',tagGrace:'30',repeatedScan:'add_one',tagReadMax:'500',tagReadQuantity:false,cycleHighValue:'50000',cycleOverdue:'7',weighedGoods:false},business:{shopType:'grocery'},supplierLookup:{timeout:'15',perMinute:'20'},retention:{usYears:'0'},bank:{maxBytes:'5242880',maxLines:'5000',matchWindow:'60'},records:{hostingCountry:'',craReference:''},map:{tiles:'',geocoder:''},bi:{detailPageSize:'50'},region:{currency:'EUR',country:'FR',locale:'en_US',weekStart:'locale'}, // #2380 bank.import_max_*/match_window_days; #2378 records.hosting_country ('' = none declared), records.cra_authorisation_reference; #2488 locale.default_currency/country/locale; #3648 locale.default_week_start; directory.tile_url_template/geocoder_url ('' = the app's default); #2578 bi.detail_page_size
 weekdays:['1','2','3','4','5'],granularity:'half_day',dayStart:'08:00',boundary:'12:00',dayEnd:'17:00',closures:[],
 halfDayHours:'4',fullDayHours:'8',deskOpacity:'100',
 horizonDays:'90',minDuration:'30',maxDuration:'1440',
 policies:{allowPast:false,adminCheckout:false,outsideHours:'charged',simultaneous:'1',legendProfile:'full'},
 invites:{fr:'',en:'',de:'',es:'',it:''},
 einvoice:{url:'',token:'',header:'',field:'',uatUrl:'',uatToken:'',devUrl:'',devToken:'',
           customerUrl:'',customerToken:'',customerHeader:'',customerField:''},
 vatPeriod:'quarter',
 // #2359 — the UK treats land as exempt unless the owner opted to tax it.
 landTax:{option:false,date:'',ref:'',facilities:false,bare:false,qst:'',quick:false},
 // FEATURES says what a NEW workspace starts with (the registry's default);
 // the page's own answer for the configuration transfer starts ON (#2331):
 // every questionnaire carries configuration answers, and the switch is
 // what lets the importing space keep applying them.
 features:{...Object.fromEntries(FEATURES.map(f=>[f[0],!!f[1]])),configurationTransfer:true,dataExport:true},
 sites:[],levels:[{name:T('defaultFirstLevel'),offices:[newOffice(1)]}],
 journey:{used:false,answers:{}},
 accessories:[],services:[],tiers:[{from:0,to:100,fee:'',over:''}],subLevels:['25','50','75','100'],freeLevel:false,packages:[],
 pay:{iban:'',paypal_me:'',wero:'',lydia:'',wise:'',reference:'',bank_name:'',account_number:'',bank_code:'',bic:'',qr_iban:''},
 org:'association',customerCapacity:'',vatRegime:'not_subject',vatExigibility:'standard',numbering:{prefix:'INV-',datePart:'year',digits:'4',reset:'yearly'},memberNumbering:{prefix:'M-',digits:'4'},regNumber:'',vatId:'',exemption:'',street:'',postal:'',city:'',subdivision:'',vatRates:[],
 mentions:{legalForm:'',register:'',terms:'',penalty:'',recovery:'',escompte:'',insurance:'',special:''},
 reminders:{...REMINDER_DEFAULTS},
 perms:JSON.parse(JSON.stringify(PERM_DEFAULTS)),permsV:2,
 validation:{required:1,ownerSignOff:false},
 domains:Object.fromEntries(DOMAINS.map(d=>[d,{on:false,required:1,ownerSignOff:false}])),
 autoValidate:{admin:false,owner:false},
 members:[]};
// The answers: boot() reads them from storage once every script has loaded
// (normalize() and migrate() read definitions from setup_params.js and
// setup_xml.js).
let S=null;

const restore=stored=>normalize(merged(stored));
// #2924 — the answers are written in ONE place. `set` and `setMany` copy
// what they change (the previous answers are never mutated) and save; the
// save runs normalize(), so the screen, the findings, the export and the
// WebMCP tools always read the same, repaired answers. Drawing a step
// never writes.
function save(){S=normalize(S);localStorage.setItem(LS,JSON.stringify(persistable(S)));document.getElementById('saved').textContent=T('setupSaved')+' '+new Date().toLocaleTimeString(LANG)}
function setMany(changes){const fresh=new Set(),draft={...S};fresh.add(draft);
 for(const[path,val]of changes){const p=path.split('.');let o=draft;
  for(let i=0;i<p.length-1;i++){let c=o[p[i]];if(!fresh.has(c)){c=Array.isArray(c)?c.slice():{...c};o[p[i]]=c;fresh.add(c)}o=c}
  o[p[p.length-1]]=val}
 S=draft;save()}
function set(path,val){setMany([[path,val]])}
// One answer changed in a copy of `s`: the pure write normalize() uses.
function put(s,path,val){const[k,...rest]=path.split('.');const c=Array.isArray(s)?s.slice():{...s};c[k]=rest.length?put(s[k],rest.join('.'),val):val;return c}
// #2924 — every repair the page applies to stored answers, as one pure
// function of them: run by save() before anything is stored and by
// restore() on every load, so no step has to repair the answers while it
// draws them (which used to need a save() at the end of render()).
function normalize(s){
 let n={...s};
 // #1320 — a number never restarts more often than it prints its date.
 const resets=resetsFor(n);if(!resets.includes(n.numbering.reset))n=put(n,'numbering.reset',resets[resets.length-1]);
 // A select offers only its options: an answer outside them reads as the
 // first one, as the select shows it.
 for(const[path,,kind,opt]of PARAM_META){if(kind!=='enum')continue;const allowed=opt(n);
  if(allowed.length&&!allowed.includes(String(get(path,n))))n=put(n,path,allowed[0])}
 // The roles step offers no card whose switch is off, and no automatic
 // decision on deletion requests without them.
 for(const dk of DOMAINS){const g=DOMAIN_GATE[dk];if(g&&!on(g,n)&&n.domains[dk]&&n.domains[dk].on!==false)n=put(n,`domains.${dk}.on`,false)}
 if(!on('deletionRequests',n)&&(n.autoValidate.admin!==false||n.autoValidate.owner!==false))n=put(n,'autoValidate',{admin:false,owner:false});
 // A member's level is one the space offers, and "packages" only while
 // there is a package.
 const levels=n.freeLevel?null:n.subLevels.length?n.subLevels:['100'],pk=n.packages.some(p=>p.name.trim());
 n.members.forEach((m,i)=>{if(levels&&!levels.includes(String(m.pct||'100')))n=put(n,`members.${i}.pct`,levels[0]);
  if((m.overage||'blocked')==='packages'&&!pk)n=put(n,`members.${i}.overage`,'blocked')});
 return n;
}

// ------------------------------------------------------------------ dependencies (#723)
// The feature tree as the app declares it (REQUIRES): a child is only
// offered while its parent is on, and switching a parent off switches its
// children off — exactly what effectiveFeatures does. #2454 — AVAILABLE_IN:
// the countries a switch is available in ('@eu' = the EU member states).
const EU=new Set(['AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','FR','GR','HR','HU','IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK']);
// Both read the current answers, or the ones given (normalize's).
const availableHere=(k,s=S)=>{const a=AVAILABLE_IN[k];return !a||a.includes(s.country)||(a.includes('@eu')&&EU.has(s.country))};
const on=(k,s=S)=>{let f=k;while(f){if(!s.features[f]||!availableHere(f,s))return false;f=REQUIRES[f]}return true};
const FEATURE_KEYS=new Set(FEATURES.map(([k])=>k));
// The nearest prerequisite that is off — why a ticked feature is not on.
const waitsFor=k=>{let f=REQUIRES[k];while(f&&S.features[f])f=REQUIRES[f];return f};
// #800 — ticking a feature switches on everything it needs: the writes.
const enableWith=k=>{const out=[[`features.${k}`,true]];let f=REQUIRES[k];while(f){out.push([`features.${f}`,true]);f=REQUIRES[f]}return out};
// The two answers whose change ripples: the UI inputs and the WebMCP tools
// both go through these.
const onCountry=v=>{const c=COUNTRIES.find(x=>x[0]===v);if(c)setMany([['currency',c[1]],['timezone',c[2]],['paper',c[5].includes(S.paper)?S.paper:'']])};
const applyFeature=(k,v)=>setMany(v?enableWith(k):[[`features.${k}`,false]]);
const alsoEnabled=k=>{const r=[];let f=REQUIRES[k];while(f){if(!S.features[f])r.push(featureTitle(f));f=REQUIRES[f]}return r};
const country=()=>COUNTRIES.find(c=>c[0]===S.country)||COUNTRIES[0];
const scheme=()=>country()[3];
const isEU=()=>EU.has(S.country);
const registered=()=>S.vatRegime==='registered';

// The little ? beside every field: straight to the guide section, the app
// location in the tooltip — the field's own section, else its feature's,
// else its step's (helpAnchorFor).
function helpIcon(key,{step,feature}={}){const a=helpAnchorFor({step,feature,key});if(!a)return null;const[app,anchor]=a;return h('a',{class:'helpq',href:guideUrl(anchor),target:'_blank',rel:'noopener',title:T('helpIconTitle',{app:T(app)})},'?')}
function destBadge(path){if(path==null)return null;const d=destOf(path);return h('span',{class:'dest '+d,title:T(DEST_TEXT[d][1])},T(DEST_TEXT[d][0]))}
const lbl=(t,hk,path,step)=>h('label',{},t,helpIcon(hk,{step}),destBadge(path));
function help(key){const a=helpAnchorFor({key});if(!a)return null;const[app,anchor]=a;return h('a',{class:'help',href:guideUrl(anchor),target:'_blank',rel:'noopener'},'ⓘ '+T('helpLink',{app:T(app)}))}
// "This question is hidden because…" — the guide's way of saying why,
// with a jump to the step that would change the answer.
function dep(text,stepId){const d=h('div',{class:'dep'},text+' ');if(stepId!=null){const a=h('a',{href:'#'},'→ '+T('depStepLink',{n:STEPS.findIndex(s=>s.id===stepId)+1}));a.onclick=e=>{e.preventDefault();go(stepId)};d.append(a)}return d}
const needs=(k,stepId='features')=>dep(T('needsFeature',{feature:quoted(featureTitle(k))}),stepId);

// ------------------------------------------------------------------ required fields
// A field that is MANDATORY, and the condition that makes it so.
//
// Stated ONCE, keyed by the same path the field widget already takes, and
// read by three things that must never disagree: the field itself (which
// marks itself required and says why, as you type), the step's status
// dot, and the export gate. Before this, a required answer was only
// discovered at the review step — eleven steps after the question — and
// the export happened anyway.
//
// `when` is the whole point: almost nothing here is required always. It
// is required BECAUSE of an earlier answer — a feature you switched on, a
// VAT regime you chose, a country you are in. The field says which, so
// the way out is never a guess: either fill it, or go back and change the
// answer that demanded it.
const REQ={
 'name':{when:()=>true,why:()=>T('reqName')},
 'street':{when:()=>true,why:()=>T('reqSellerAddress')},
 'postal':{when:()=>true,why:()=>T('reqSellerAddress')},
 'city':{when:()=>true,why:()=>T('reqSellerAddress')},
 'vatId':{when:()=>S.vatRegime!=='not_subject',
  why:()=>T('reqVatId',{regime:quoted(T(S.vatRegime==='exempt'?'reqRegimeExempt':'reqRegimeRegistered'))}),
  fix:{step:'legal'}},
 'network.homeUrl':{when:()=>S.network.roles==='workspace_host',why:()=>T('reqNetworkHome')},
 'network.homeKey':{when:()=>S.network.roles==='workspace_host',why:()=>T('reqNetworkHome')},
 'regNumber':{when:()=>S.org==='company',
  why:()=>T('reqRegNumber'),
  fix:{step:'legal'}},
};
// The condition and the answer, for one path. null when the field is not
// required under the current answers — which is most of them, most of the
// time, and is exactly what keeps the page quiet.
function reqState(path){
 const r=REQ[path];if(!r||!r.when())return null;
 const v=get(path);
 return {met:String(v??'').trim()!=='',why:typeof r.why==='function'?r.why():r.why,fix:r.fix};
}

// ------------------------------------------------------------------ UI helpers
let lid=0;const h=(tag,attrs={},...kids)=>{const e=document.createElement(tag);for(const[k,v]of Object.entries(attrs)){if(k==='onclick'||k==='oninput'||k==='onchange')e[k]=v;else if(k==='html')e.innerHTML=v;else e.setAttribute(k,v)}for(const k of kids){if(k!=null)e.append(k)}if(tag==='div'&&kids[0]&&kids[0].tagName==='LABEL'){const c=kids.find(x=>x&&/^(INPUT|SELECT|TEXTAREA)$/.test(x.tagName)&&x.type!=='checkbox');if(c&&!c.getAttribute('aria-label')){kids[0].id=kids[0].id||'l'+(++lid);c.setAttribute('aria-labelledby',kids[0].id)}}return e};
function get(path,s=S){const p=path.split('.');let o=s;for(const k of p)o=o[k];return o}
function input(label,path,hint,type='text',ph='',hk,step){const i=h('input',{type,placeholder:ph});i.value=get(path)??'';
 const rq=reqState(path);
 const badge=rq?h('span',{class:'req'+(rq.met?' met':'')},(rq.met?'✓ ':'')+T('setupRequired')):null;
 const why=rq?h('p',{class:'why'+(rq.met?' met':'')},rq.why):null;
 // Live, not on blur: the badge and the border answer the keystroke that
 // fixes them, so the field stops nagging the moment it is satisfied.
 const paint=()=>{if(!rq)return;const met=String(i.value).trim()!=='';
  i.classList.toggle('missing',!met);badge.classList.toggle('met',met);
  badge.textContent=(met?'✓ ':'')+T('setupRequired');why.classList.toggle('met',met)};
 i.oninput=()=>{set(path,i.value);paint()};
 const d=h('div',{},h('label',{},label,badge,helpIcon(hk,{step}),destBadge(path)),i);
 if(hint)d.append(h('p',{class:'hint'},hint));
 if(why)d.append(why);
 if(rq&&rq.fix)d.append(dep(T('reqByEarlierChoice'),rq.fix.step));
 paint();
 return d}
function selectEl(label,path,opts,hint,onch,hk,step){const s=h('select');for(const[v,t]of opts)s.append(h('option',{value:v},t));s.value=get(path);s.onchange=()=>{set(path,s.value);if(onch)onch(s.value);render()};const d=h('div',{},h('label',{},label,helpIcon(hk,{step}),destBadge(path)),s);if(hint)d.append(h('p',{class:'hint'},hint));return d}
function chip(text,on,cb){const c=h('button',{class:'chip'+(on?' on':''),type:'button'},text);c.onclick=()=>{cb(!on);render()};return c}
function checkbox(label,desc,checked,onch,cls='',hk){const c=h('input',{type:'checkbox'});c.checked=!!checked;c.onchange=()=>{onch(c.checked);render()};return h('label',{class:'check '+cls},c,h('span',{},label,hk?helpIcon(hk):null,desc?h('div',{class:'d'},desc):null))}
function section(title,...kids){const s=h('section',{},h('h2',{},title),h('div',{class:'body'},...kids));s.querySelector('h2').onclick=()=>s.classList.toggle('closed');return s}
// The list stored at `path`, one table row per entry: make(row, rowPath)
// draws its cells; ✕ and + write the list back.
function tableRows(cols,path,make,add,addLabel){const t=h('table',{},h('tr',{},...cols.map(c=>h('th',{},c)),h('th')));get(path).forEach((r,i)=>{const tr=h('tr',{},...make(r,`${path}.${i}`).map((c,j)=>h('td',{},(c&&/^(INPUT|SELECT)$/.test(c.tagName)&&typeof cols[j]==='string'&&c.setAttribute('aria-label',cols[j]),c))),h('td',{},h('button',{class:'del',type:'button','aria-label':T('tableRemoveRow'),onclick:()=>{set(path,get(path).filter((_,j)=>j!==i));render()}},'✕')));t.append(tr)});const w=h('div',{},t,h('button',{class:'add',type:'button',onclick:()=>{set(path,[...get(path),add()]);render()}},addLabel));return w}
function cell(path,type='text',ph=''){const i=h('input',{type,placeholder:ph});i.value=get(path)??'';i.oninput=()=>set(path,i.value);return i}
// A select over [value, label] pairs that writes `path`.
function pick(path,opts,value){const s=h('select');for(const[v,l]of opts)s.append(h('option',{value:v},l));s.value=value;s.onchange=()=>set(path,s.value);return s}
function yesNo(){const s=h('select');s.append(h('option',{value:'no'},T('optNo')),h('option',{value:'yes'},T('optYes')));return s}
const num=v=>{const n=parseFloat(v);return isNaN(n)?null:n};
const mins=t=>{const m=/^(\d{1,2}):(\d{2})$/.exec(t||'');return m?parseInt(m[1])*60+parseInt(m[2]):null};
const F={ok:(t,step)=>({lvl:'ok',t,step}),warn:(t,step)=>({lvl:'warn',t,step}),err:(t,step)=>({lvl:'err',t,step})};
// The helpers a step draws with (build(step)): a ? with no section of its
// own opens the step's.
const ui=st=>({helpIcon:(key,feature)=>helpIcon(key,{step:st.id,feature}),lbl:(t,hk,path)=>lbl(t,hk,path,st.id),
 input:(l,p,hint,type,ph,hk)=>input(l,p,hint,type,ph,hk,st.id),selectEl:(l,p,o,hint,onch,hk)=>selectEl(l,p,o,hint,onch,hk,st.id)});

// ------------------------------------------------------------------ wizard chrome
// ?step=<id>&mode=all — a link straight to one step (the guide, a
// colleague), and the whole page for review or print.
const Q=new URLSearchParams(location.search);
let mode=Q.get('mode')||localStorage.getItem(LS+'-mode')||'wizard';
let cur=Q.get('step')||localStorage.getItem(LS+'-step')||'';
function setMode(all){mode=all?'all':'wizard';localStorage.setItem(LS+'-mode',mode);render()}
function go(id){cur=id;localStorage.setItem(LS+'-step',id);render();window.scrollTo({top:0,behavior:'smooth'})}
// #2868 — with the setup guide on, the questions are the way through and
// the ~140 switches are the expert view, behind a switch. Every way to the
// features step — a "needs" note, a finding, the rail, ?step=features —
// still arrives there: following it opens the expert view. With the guide
// off the page is as it always was.
let expert=localStorage.getItem(LS+'-expert')==='1';
const expertView=()=>expert||!on('setupGuide');
function setExpert(v){expert=!!v;localStorage.setItem(LS+'-expert',expert?'1':'0');if(!expertView()&&STEPS.find(s=>s.id===cur)?.expertOnly)cur='levels';render()}
function applicable(){return STEPS.filter(s=>(!s.applies||s.applies())&&(!s.expertOnly||expertView()))}
function render(){
 // #800 — a sub-feature's choice SURVIVES its parent being switched off,
 // as in the app: switching the parent back on finds it as it was.
 const F_=document.getElementById('form');F_.textContent='';
 if(!expertView()&&STEPS.find(s=>s.id===cur)?.expertOnly){expert=true;localStorage.setItem(LS+'-expert','1')}
 renderLegend();
 const list=applicable();if(!list.some(s=>s.id===cur))cur=list[0].id;
 const idx=list.findIndex(s=>s.id===cur);
 document.getElementById('bar').style.width=Math.round((idx)/(list.length-1)*100)+'%';
 document.getElementById('stepno').textContent=mode==='wizard'?T('setupStep',{current:idx+1,total:list.length}):'';
 const rail=document.getElementById('rail');rail.textContent='';
 list.forEach((st,i)=>{const s=stepStatus(st);const b=h('button',{class:'step'+(st.id===cur&&mode==='wizard'?' cur':''),type:'button',onclick:()=>go(st.id)},h('span',{class:'dot '+s}),(i+1)+' · '+st.title);rail.append(b)});
 document.getElementById('allmode').checked=mode==='all';
 document.getElementById('expertview').checked=expertView();
 entryChrome(list,idx);
 const show=mode==='all'?list:[list[idx]];
 // A step that throws used to take the WHOLE page with it: the body was
 // empty, and because render() never reached the end, the navigation was
 // never drawn either — so the wizard became a dead end with no way
 // forward and no message. (That is exactly what `avail` did to step 2.)
 // Now the step says so, and everything else still works.
 for(const st of show){const n=list.indexOf(st)+1;
  let body;
  try{body=st.build(st)}
  catch(e){console.error('setup step "'+st.id+'" failed',e);
   body=[h('div',{class:'gate'},h('b',{},T('renderStepFailed')),
    h('span',{},T('renderStepFailedHint')+' '),
    h('code',{},String(e&&e.message||e)))]}
  F_.append(section(n+' · '+st.title,h('p',{class:'why'},st.why),...body))}
 const nav=document.getElementById('nav');nav.textContent='';
 if(mode==='wizard'){const prev=list[idx-1],next=list[idx+1];
  const b=blockers().length;
  const last=h('button',{class:'btn primary',type:'button',title:next?T('setupNext'):T('setupExportXml'),onclick:()=>next?go(next.id):exportChecked()},
   next?next.title+' ›':'⬇ '+(b?T('setupExportBlocked',{n:b}):T('setupExportXml')));
  if(!next&&b)last.disabled=true;
  nav.append(h('button',{class:'btn ghost',type:'button',title:T('setupPrevious'),onclick:()=>prev&&go(prev.id)},'‹ '+(prev?prev.title:T('navStart'))),last);
  nav.firstChild.disabled=!prev}
}
// #2926 — run once every script of the page has loaded (the last line of
// setup_xml.js, #3915): the answers from storage, the surface the
// WebMCP tools (setup_webmcp.js) use — the page's own state and handlers,
// never a copy; `hooks` run after a language change — and the first draw.
function boot(){
 S=restore(JSON.parse(localStorage.getItem(LS)||'null'));if(!cur)cur=STEPS[0].id;
 window.__setup={
  get S(){return S},get LANG(){return LANG},get FEATURES(){return FEATURES},get REQUIRES(){return REQUIRES},
  get DEFAULTS(){return DEFAULTS},get PROCESSES(){return PROCESSES},get PARAM_META(){return PARAM_META},get PARAM_EXCLUDED(){return PARAM_EXCLUDED},
  get WD(){return WD},get COUNTRIES(){return COUNTRIES},
  T,setLang,featureTitle,featureDesc,processTitle,subprocessTitle,weekdayName,on,mins,num,save,set,setMany,get,normalize,onCountry,applyFeature,enableWith,alsoEnabled,
  get VAT_RATES(){return VAT_RATES},seedVatRates,buildXml,findings,restore,hooks:[],
  reset(){S=restore(null);save();render()},
  rerender(){render()},
 };
 wireChrome();
 applyChrome();
 render();
}
// #3915 — the page's own controls, wired here: the policy runs no handler
// written in the markup.
function wireChrome(){
 const wire=(id,type,fn)=>document.getElementById(id).addEventListener(type,fn);
 wire('lang','change',e=>setLang(e.target.value));
 wire('allmode','change',e=>setMode(e.target.checked));
 wire('expertview','change',e=>setExpert(e.target.checked));
 wire('primary','click',()=>primaryAction());
 wire('loadbtn','click',()=>document.getElementById('load').click());
 wire('load','change',e=>loadFile(e.target.files[0]));
 wire('resetbtn','click',()=>{if(!confirm(T('setupClearAnswersConfirm')))return;
  for(const k of [LS,LS+'-step',LS+'-expert'])localStorage.removeItem(k);location.reload()});
}
