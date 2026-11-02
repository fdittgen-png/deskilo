// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup questionnaire's file (#2926): the export the app imports and
// the page reads back — the typed <configuration> tree, the <setup>
// answers and profile, readTree(), the frozen reader of the files a page
// before #2925 wrote, and migrate(), every rule an older questionnaire is
// read by. Loaded after web/setup.html's own script.
'use strict';
// #2331 — a stored role row REPLACES the app's defaults, so the page offers
// every permission. The ten a page older than #2331 never offered: an
// answer saved then has none of them, and gets their defaults (migrate())
// instead of losing them.
const PERMS_ADDED_2331=['deployToProd','deployToDev','accessProd','viewAnalytics','useMessages','makeReservations','viewCalendar','viewDirectory','viewMyMoney','viewDocuments'];
function upgradePerms(perms){for(const role of Object.keys(PERM_DEFAULTS)){const list=perms[role];if(!Array.isArray(list))continue;
 if(!list.some(p=>PERMS_ADDED_2331.includes(p)))perms[role]=[...list,...PERM_DEFAULTS[role].filter(p=>PERMS_ADDED_2331.includes(p))]}return perms}

// #2925 — every "a questionnaire saved before #N reads as…" rule, in the
// order they were made, in ONE place: run on the answers as stored or as a
// file carried them, before they meet the defaults (so a rule can tell an
// answer that was given from a default).
function migrate(raw){
 const m=JSON.parse(JSON.stringify(raw));
 // #600 -> #634: a questionnaire saved while the retired "minute bookings
 // within working hours" switch existed (gridHours; grid-within-hours in a
 // file) reads as the mode that replaced it, exactly as the server maps
 // the legacy booking_rules key.
 if(m.policies&&m.policies.gridHours!==undefined){
  if(m.policies.gridHours&&!m.policies.outsideHours)m.policies.outsideHours='walkup_only';
  delete m.policies.gridHours;
 }
 // #2331 — answers saved before the page offered every permission (no
 // permsV; no permissions-version in a file) get the ten it added.
 if(!m.permsV){if(m.perms)upgradePerms(m.perms);m.permsV=2}
 // #2355 — 'payment' was the tax point now called cash.
 if(m.vatExigibility==='payment')m.vatExigibility='cash';
 // #2357 — a period this page does not know reads as quarterly.
 if(m.vatPeriod!==undefined&&!VATPERIOD.some(([v])=>v===m.vatPeriod))m.vatPeriod='quarter';
 return m;
}
// A save written by an older version of this page is missing whatever
// fields did not exist then, and `render()` reads them unguarded. Merge
// the migrated answers ONTO the defaults rather than replacing them, one
// level deep — every nested value here is a flat object or an array, so
// one level is exactly enough. An array in storage wins whole (it is the
// owner's list); a plain object is filled in key by key.
function merged(stored){
 const out=JSON.parse(JSON.stringify(DEFAULTS));
 if(!stored||typeof stored!=='object')return out;
 for(const[k,v]of Object.entries(migrate(stored))){
  if(v===undefined||v===null)continue;
  const d=out[k];
  if(Array.isArray(v)||Array.isArray(d)||typeof v!=='object'||d===undefined||typeof d!=='object')out[k]=v;
  else out[k]=Object.assign(d,v);
 }
 return out;
}

// The export is GATED, not warned about.
//
// It used to ask "export anyway?" and export on OK, with the
// review step saying the app would refuse what was incoherent. That put
// the failure eleven steps and one import later, in an app that can only
// say no — and a half-configured space is worse than an unconfigured
// one, because it looks finished.
const blockers=()=>findings().filter(x=>x.lvl==='err');
function exportChecked(){if(blockers().length){go('review');return}exportXml()}

// ------------------------------------------------------------------ XML export
const esc=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
// ------------------------------------------------------------------ configuration (schema v3, #916)
// The typed tree the app's <configuration> section carries: object members
// sorted by name, strings in the value attribute (line breaks as &#10;), so
// the app's export of the imported space reads byte for byte the same.
const escAttr=s=>esc(s).replace(/\n/g,'&#10;').replace(/\r/g,'&#13;').replace(/\t/g,'&#9;');
function cfgField(push,ind,name,v){
 const n=name==null?'':` name="${esc(name)}"`;const pad=' '.repeat(ind);
 if(v===null||v===undefined){push(`${pad}<field${n} type="null"/>`);return}
 if(typeof v==='boolean'){push(`${pad}<field${n} type="boolean">${v}</field>`);return}
 if(typeof v==='number'){push(`${pad}<field${n} type="number">${String(v)}</field>`);return}
 if(typeof v==='string'){push(`${pad}<field${n} type="string" value="${escAttr(v)}"/>`);return}
 if(Array.isArray(v)){push(`${pad}<field${n} type="array">`);v.forEach(x=>cfgField(push,ind+2,null,x));push(`${pad}</field>`);return}
 push(`${pad}<field${n} type="object">`);Object.keys(v).sort().forEach(k=>cfgField(push,ind+2,k,v[k]));push(`${pad}</field>`);
}
// #2331 — the default rule (event type null) and the per-domain rules, as
// validation_policies rows inside the server's CHECKs (1–10 approvals, a
// validator scope it knows). They used to live in <setup> only — or carry
// 'service' and a 'named' scope, which the server refuses outright.
function validationPolicies(){
 const n=x=>Math.min(10,Math.max(1,parseInt(x)||1));
 const row=(eventType,required,owner,scope,auto)=>({event_type:eventType,required_count:n(required),admins_may_validate:true,owner_required:!!owner,
  auto_validate_admin:!!(auto&&auto.admin),auto_validate_owner:!!(auto&&auto.owner),validator_scope:scope==='members'?'members':'admins',owner_may_self_validate:false,sequential:false});
 const out=[row(null,S.validation.required,S.validation.ownerSignOff,'admins',null)];
 const auto=on('deletionRequests')?S.autoValidate:null;
 for(const k of DOMAINS){const d=S.domains[k],g=DOMAIN_GATE[k];if(g&&!on(g))continue;
  if(d&&d.on)out.push(row(DOMAIN_EVENT_TYPE[k]||k,d.required,d.ownerSignOff,on('validationScopes')?d.validators:'admins',k==='reservation_delete'?auto:null));
  else if(k==='reservation_delete'&&auto&&(auto.admin||auto.owner))out.push(row(k,S.validation.required,S.validation.ownerSignOff,'admins',auto))}
 return out}
// The tree's numbers: cents from a decimal answer, an integer or a fallback.
const cents=x=>Math.round((parseFloat(x)||0)*100);
const int=(x,d)=>{const n=parseInt(x);return isNaN(n)?d:n};
// #1559 — the working day and the three booking policies below used to
// be answered here and exported ONLY inside <setup>, which the app
// ignores by design. The import REPLACES booking_rules with this tree,
// so every key missing from it read as the app's fallback: 08:00–17:00,
// boundary 12:00, 4h/8h, past bookings and admin check-out off, one
// simultaneous reservation — silently, and over hours the workspace had
// already configured. They belong here, in the app's own wire keys and
// types (WorkHours / BookingPolicies).
//
// WorkHours.fromRules discards the WHOLE triple unless
// start < boundary < end, and treats a half day above the full day the
// same way, so what goes out is kept coherent rather than exported as a
// value that would put the app back on its defaults.
function workHours(){
 const hm=(t,d)=>{const m=mins(t);return m==null?d:m};
 const start=hm(S.dayStart,480),end=hm(S.dayEnd,1020),boundary=hm(S.boundary,720);
 const half=Math.max(1,int(S.halfDayHours,4));
 return {start,end,boundary:boundary>start&&boundary<end?boundary:Math.floor((start+end)/2),half,full:Math.max(half,int(S.fullDayHours,8))};
}
function bookingRules(){const w=workHours(),policies=on('bookingPolicies');
 return {granularity:S.granularity,open_weekdays:S.weekdays.map(d=>int(d,1)),legend_profile:S.policies.legendProfile||'full',
  advance_horizon_days:int(S.horizonDays,90),min_duration_minutes:int(S.minDuration,30),max_duration_minutes:int(S.maxDuration,1440),
  work_start_minutes:w.start,half_boundary_minutes:w.boundary,work_end_minutes:w.end,half_day_hours:w.half,full_day_hours:w.full,
  // Without the booking policies switch, the policies' documented off-values.
  outside_hours_mode:policies?(S.policies.outsideHours||'charged'):'charged',
  allow_past_bookings:policies&&!!S.policies.allowPast,admin_check_out:policies&&!!S.policies.adminCheckout,
  simultaneous_reservations:policies?Math.max(1,int(S.policies.simultaneous,1)):1};
}
// The invoice_legal column: the mentions, the seller, the tax point and
// what a registered seller's country adds.
function legalConfig(){const m=S.mentions,lt=S.landTax,reg=registered();
 const out={legal_form:m.legalForm||'',registration:m.register||'',payment_terms:m.terms||'',late_penalty:m.penalty||'',
  recovery_indemnity:m.recovery||'',escompte:m.escompte||'',insurance:m.insurance||'',special_mentions:m.special||'',
  seller_kind:S.org==='company'?'':'association',customer_capacity:S.customerCapacity||'',vat_tax_point:S.vatExigibility};
 if(S.vatExigibility==='invoice')out.vat_exigibility='invoice';
 if(S.vatExigibility==='cash')out.vat_exigibility='payment';
 // #2357 — how often the return is filed: a stored parameter now.
 if(on('vatDeclarations')&&reg)out.vat_declaration_period=S.vatPeriod;
 if(reg&&S.country==='CA'&&lt.quick)out.quick_method=true;
 if(reg&&S.country==='CH'){const opted=!!(lt.bare&&lt.option);Object.assign(out,{letting_kind:lt.bare?'bare':'',option_to_tax:opted,option_to_tax_date:opted?lt.date:''})}
 if(reg&&S.country==='GB')Object.assign(out,{option_to_tax:!!lt.option,option_to_tax_date:lt.option?lt.date:'',option_to_tax_reference:lt.option?lt.ref.trim():'',facilities_package:!!lt.facilities});
 return out;
}
function workspaceConfig(){
 // #2331 — the app's SubscriptionLevels: 25/50/75/100 are presets, any
 // other step (80) is an extra level, and "free value" is allow_custom.
 const SUB_PRESETS=[25,50,75,100],levels=[...new Set((S.subLevels||[]).map(x=>int(x,0)).filter(x=>x>0))].sort((a,b)=>a-b);
 // A registered seller in Quebec is identified by its QST number.
 const qst=registered()&&S.country==='CA'?S.landTax.qst.trim():'';
 const ws={
  address:S.address||'',street:S.street||'',postal_code:S.postal||'',city:S.city||'',
  default_locale:S.language||'',whatsapp_group:on('whatsappIntegration')?(S.whatsapp||''):'',desk_opacity:Math.min(100,Math.max(20,int(S.deskOpacity,100))),
  invitation_templates:Object.fromEntries(Object.entries(S.invites).filter(([,v])=>String(v).trim()).map(([k,v])=>[k,String(v).trim()])),
  // #2331 — the column's own words: the page says "registered", the
  // workspaces row (and every issuing guard) says "vat_registered". The
  // page's word made the whole import fail on its CHECK constraint.
  vat_regime:({registered:'vat_registered',exempt:'exempt'})[S.vatRegime]||'not_subject',vat_id:S.vatId||'',legal_id:qst||S.regNumber||'',tax_exemption_reason:S.exemption||'',
  booking_rules:bookingRules(),
  subscription_levels:{enabled_presets:levels.filter(x=>SUB_PRESETS.includes(x)),extra_levels:levels.filter(x=>!SUB_PRESETS.includes(x)),allow_custom:!!S.freeLevel},
  invoice_legal:legalConfig(),
 };
 // #2331 — the role matrix, in the column's shape (role -> permission
 // names). Written only while the page asks for it; a role row REPLACES
 // the app's defaults for that role, which is why the page offers all of them.
 if(on('roleManagement'))ws.role_permissions=Object.fromEntries(Object.keys(PERM_DEFAULTS).map(role=>[role,PERMS.filter(p=>(S.perms[role]||[]).includes(p))]));
 if(on('dunning'))ws.dunning_rules={levels:int(S.reminders.levels,1),first_after_days:int(S.reminders.firstDays,14),between_days:int(S.reminders.betweenDays,14),automatic:on('paymentReminders')&&S.reminders.automatic===true};
 return ws;
}
// #2331 — the two series the page asks for (only while invoicing as a
// VAT-registered seller, where the step shows them), in the server's
// shape and inside its CHECKs: 1–9 digits, a prefix of at most 16, a
// restart no more often than the date it prints (0217 refuses the pair
// and, with it, the whole configuration).
function numberSequences(){const nb=S.numbering,mb=S.memberNumbering,dig=x=>Math.min(9,Math.max(1,int(x,4))),pre=x=>String(x??'').slice(0,16);
 const dp=['none','year','year_month'].includes(nb.datePart)?nb.datePart:'year',ok=RESETS_FOR[dp];
 return [{journal:'invoice',prefix:pre(nb.prefix),suffix:'',date_part:dp,digits:dig(nb.digits),reset:ok.includes(nb.reset)?nb.reset:ok[ok.length-1],gapless:true},
  {journal:'member',prefix:pre(mb.prefix),suffix:'',date_part:'none',digits:dig(mb.digits),reset:'never',gapless:true}];
}
function tablesConfig(){
 const vatLabel=pct=>{if(pct===''||pct==null)return null;const r=(S.vatRates||[]).find(r=>parseFloat(r.percent)===parseFloat(pct));return r?String(r.label).trim():null};
 const t={
  fee_bands:S.tiers.filter(x=>x.fee!=='').map(x=>({from_pct:int(x.from,0),to_pct:int(x.to,100),fee_cents:cents(x.fee),overage_fee_cents:cents(x.over)})),
  packages:S.packages.filter(p=>p.name.trim()).map(p=>({name:p.name.trim(),days:int(p.days,0),price_cents:cents(p.price),active:true,vat_rate:null})),
  closure_days:S.closures.filter(Boolean).map(d=>({day:d,reason:''})),
  validation_policies:validationPolicies(),
 };
 if(on('invoicing')&&registered())t.number_sequences=numberSequences();
 const supplyClass=registered()&&on('vatManagement')&&on('supplyClassification');
 if(on('services'))t.services=S.services.filter(x=>x.name.trim()).map(x=>({name:x.name.trim(),price_cents:cents(x.price),active:true,stock:null,vat_rate:vatLabel(x.vat),...(supplyClass?{supply_class:x.supply==='general'?'general':'property'}:{})}));
 // #2331 — group and exemption are NOT NULL columns (defaults 'standard'
 // and ''): a null made the import refuse the whole configuration.
 if(on('vatManagement')&&registered())t.vat_rates=S.vatRates.filter(r=>String(r.label).trim()&&r.percent!==''&&r.percent!=null).map((r,i)=>({label:String(r.label).trim(),percent:parseFloat(r.percent),
   category:parseFloat(r.percent)>0?'S':'Z',is_default:i===0,active:true,group_key:on('vatGroups')&&r.group?r.group:'standard',outside_base:false,exemption_reason:'',valid_from:on('vatRateHistory')&&r.validFrom?r.validFrom:'1900-01-01',valid_to:null,supersedes:null}));
 if(on('multiSite'))t.sites=S.sites.filter(x=>String(x.name).trim()).map((x,i)=>({name:x.name.trim(),street:x.street||'',postal_code:x.postal||'',city:x.city||'',country_code:S.country||'',
   legal_id:x.legalId||'',is_default:i===0,sort_order:i,vat_id:'',tax_exemption_reason:''}));
 return t;
}
const configurationTree=()=>({workspace:workspaceConfig(),tables:tablesConfig()});
// #2925 — what of the answers the <setup> block carries for the page's own
// round trip: all of them but what the sections the app imports already
// carry (and are read back from: the identity in <settings>, the switches,
// the payment details, the accessories and the plan) and the journey (its
// <profile>). The e-invoicing endpoints (DEST 'file') travel, as before,
// only while invoicing in the EU with one of them filled in.
const CARRIED_ELSEWHERE=['name','country','currency','timezone','environment','brandColor','features','pay','accessories','levels','journey'];
function exportable(s){const out=Object.fromEntries(Object.entries(s).filter(([k])=>!CARRIED_ELSEWHERE.includes(k)));
 if(!(on('invoicing',s)&&EU.has(s.country)&&Object.values(s.einvoice).some(v=>String(v).trim())))delete out.einvoice;
 return out}
// buildXml is the export itself (the WebMCP tool returns its text);
// exportXml hands that same text to the browser as a download.
function exportXml(){
 const text=buildXml();if(text==null)return;
 const blob=new Blob([text],{type:'application/xml'});
 const a=document.createElement('a');a.href=URL.createObjectURL(blob);
 a.download='deskilo-setup-'+S.name.trim().toLowerCase().replace(/[^a-z0-9]+/g,'-')+'.xml';a.click();
}
function buildXml(){
 if(!S.name.trim()){alert(T('exportNeedsName'));return null}
 const x=[];const push=s=>x.push(s);
 push('<?xml version="1.0" encoding="UTF-8"?>');
 push('<deskilo-workspace version="3">');
 // settings — app-importable
 push(`  <settings name="${esc(S.name)}" country="${esc(S.country)}" currency="${esc(S.currency)}" timezone="${esc(S.timezone)}" environment="${esc(S.environment)}"${S.brandColor.trim()?` brand-color="${esc(S.brandColor.trim().toUpperCase())}"`:''}>`);
 for(const[k]of FEATURES)push(`    <feature key="${k}" enabled="${!!S.features[k]}"/>`);
 for(const[k,v]of Object.entries(S.pay))if(String(v).trim())push(`    <payment-instruction key="${k}" value="${esc(v.trim())}"/>`);
 push('  </settings>');
 // accessories — app-importable
 push('  <accessories>');
 if(on('accessorySupplements'))S.accessories.filter(a=>a.name.trim()).forEach((a,i)=>push(`    <accessory name="${esc(a.name.trim())}" supplement-cents="${Math.round((parseFloat(a.supp)||0)*100)}" active="true" sort-order="${i}"/>`));
 push('  </accessories>');
 // floor plan — app-importable, auto-layout (seat footprint 6x4, ADR 0005)
 push('  <floor-plan>');
 S.levels.forEach((lv,li)=>{
  // #2331 — whole-space booking travels in the plan (schema v3): the level's
  // flag, and each bookable room's price.
  push(`    <level name="${esc(lv.name||(XML_LEVEL_FALLBACK+' '+(li+1)))}" sort-order="${li}"${lv.site?` site="${esc(lv.site)}"`:``}${on('levelBooking')&&lv.bookable?` bookable-as-whole="true"`:``}>`);
  let ox=1;
  lv.offices.forEach(of=>{
   const desks=of.desks.filter(d=>(parseInt(d.seats)||0)>0);
   let dw=0,dh=0;const geo=desks.map(d=>{const n=parseInt(d.seats)||1;const cols=Math.ceil(n/2);const w=cols*6;const hgt=n>cols?8:4;dw=Math.max(dw,w);dh+=hgt+1;return{d,n,cols,w,hgt}});
   const ow=dw+2,oh=Math.max(dh+1,5);
   const whole=on('levelBooking')&&!!of.bookable,price=whole&&num(of.price)>=0?Math.round(num(of.price)*100):0;
   push(`      <office name="${esc(of.name)}" color="4288585374" bookable-as-whole="${whole}" x="${ox}" y="1" w="${ow}" h="${oh}"${price?` price-cents="${price}"`:``}>`);
   let dy=2;
   geo.forEach(({d,n,cols,w,hgt})=>{
    push(`        <desk name="${esc(d.name)}" x="${ox+1}" y="${dy}" w="${w}" h="${hgt}">`);
    for(let i=0;i<n;i++){const col=i%cols,row=Math.floor(i/cols);
     push(`          <seat name="${esc((d.prefix||XML_SEAT_FALLBACK)+' '+(i+1))}" x="${ox+1+col*6}" y="${dy+row*4}" orientation="${row===0?'s':'n'}" chair=""/>`)}
    push('        </desk>');dy+=hgt+1});
   push('      </office>');ox+=ow+2;
  });
  push('    </level>');
 });
 push('  </floor-plan>');
 // configuration — app-importable (schema v3, #916): what the <setup> block
 // below says, in the shape the app stores, so the import applies it.
 // #2331 — ALWAYS. It used to be written only with the configuration
 // transfer ticked, so a page left on its defaults produced a file whose
 // tariffs, legal identity, rules and roles nothing could ever apply. The
 // app now asks before applying it to a space that has the feature off.
 {const tree=configurationTree();push('  <configuration>');Object.keys(tree).sort().forEach(k=>cfgField(push,4,k,tree[k]));push('  </configuration>')}
 // #2925 — the page's own round trip: its answers, written once with the
 // typed-tree writer the <configuration> uses and read back by readTree().
 // The app ignores them; it reads only the <profile> below.
 push('  <setup>');
 cfgField(push,4,'answers',exportable(S));
 // #2868 — the answers and the levels the switches above reach; only once
 // the questions step was used, so a file made without it is as before.
 if(on('setupGuide')&&S.journey.used){const now=levelsNow(),preset=presetOf(now);
  push(`    <profile${preset?` preset="${preset}"`:''}>`);
  for(const q of LEVELS.questions)push(`      <answer question="${q}" value="${S.journey.answers[q]===true}"/>`);
  for(const pr of LEVELS.processes)push(`      <level of="${pr.key}" value="${now[pr.key]}"/>`);
  push('    </profile>')}
 push('  </setup>');
 push('</deskilo-workspace>');
 return x.join('\n');
}
// ------------------------------------------------------------------ load back
function loadFile(f){if(!f)return;const r=new FileReader();r.onload=()=>{try{parseBack(r.result);save();render();alert(T('loadOk'))}catch(e){alert(T('loadError',{error:e.message}))}};r.readAsText(f)}
const childOf=(el,tag)=>el?[...el.children].find(c=>c.tagName===tag)||null:null;
// #2925 — the reader of the <field type=…> grammar cfgField writes: the
// page's mirror of the app's _readValue (workspace_xml_configuration.dart).
function readTree(f){const fields=()=>[...f.children].filter(c=>c.tagName==='field');const text=()=>f.textContent.trim();
 switch(f.getAttribute('type')){
  case 'null':return null;
  case 'boolean':if(text()!=='true'&&text()!=='false')break;return text()==='true';
  case 'number':if(text()===''||isNaN(Number(text())))break;return Number(text());
  case 'string':if(!f.hasAttribute('value'))break;return f.getAttribute('value');
  case 'array':return fields().map(readTree);
  case 'object':return Object.fromEntries(fields().map(c=>[c.getAttribute('name'),readTree(c)]));
 }
 throw new Error(T('loadMalformed'))}
// A file's answers: the page's own <answers> tree, or — from a page before
// #2925 — its per-section <setup> blocks, read onto the answers loaded now
// as that page did. Either way the sections the app imports (settings,
// accessories, the plan) and the <profile> are read as they always were,
// then migrate() and normalize() run once over the whole.
function parseBack(text){
 const doc=new DOMParser().parseFromString(text,'application/xml');
 if(doc.getElementsByTagName('parsererror').length)throw new Error(T('loadMalformed'));
 const root=doc.documentElement;if(root.tagName!=='deskilo-workspace')throw new Error(T('loadWrongRoot'));
 const su=childOf(root,'setup'),answers=su&&[...su.children].find(c=>c.tagName==='field'&&c.getAttribute('name')==='answers');
 const ans=merged(answers?readTree(answers):parseLegacySetup(su,JSON.parse(JSON.stringify(S))));
 const st=root.querySelector('settings');if(st){ans.name=st.getAttribute('name')||'';ans.country=st.getAttribute('country')||'FR';ans.currency=st.getAttribute('currency')||'EUR';ans.timezone=st.getAttribute('timezone')||'Europe/Paris';ans.environment=st.getAttribute('environment')||'dev';ans.brandColor=st.getAttribute('brand-color')||'';
  st.querySelectorAll('feature').forEach(f=>ans.features[f.getAttribute('key')]=f.getAttribute('enabled')==='true');
  Object.keys(ans.pay).forEach(k=>ans.pay[k]='');st.querySelectorAll('payment-instruction').forEach(p=>{ans.pay[p.getAttribute('key')]=p.getAttribute('value')||''});}
 ans.accessories=[...root.querySelectorAll('accessories > accessory')].map(a=>({name:a.getAttribute('name'),supp:String((parseInt(a.getAttribute('supplement-cents'))||0)/100)}));
 const lvls=[...root.querySelectorAll('floor-plan > level')];
 if(lvls.length)ans.levels=lvls.map(l=>({name:l.getAttribute('name'),site:l.getAttribute('site')||'',bookable:l.getAttribute('bookable-as-whole')==='true',offices:[...l.querySelectorAll('office')].map(o=>({name:o.getAttribute('name'),bookable:o.getAttribute('bookable-as-whole')==='true',price:o.hasAttribute('price-cents')?String((parseInt(o.getAttribute('price-cents'))||0)/100):'',desks:[...o.querySelectorAll('desk')].map(d=>{const seats=[...d.querySelectorAll('seat')];const first=seats[0]?.getAttribute('name')||XML_SEAT_FALLBACK+' 1';return{name:d.getAttribute('name'),seats:seats.length,prefix:first.replace(/\s*\d+$/,'')||XML_SEAT_FALLBACK}})}))}));
 // #2868 — the answers come back as given; the levels are the switches
 // the file already carries.
 if(su){const pf=childOf(su,'profile');ans.journey=pf?{used:true,answers:Object.fromEntries([...pf.children].filter(a=>a.tagName==='answer').map(a=>[a.getAttribute('question'),a.getAttribute('value')==='true']))}:{used:false,answers:{}}}
 S=normalize(ans);
}
// The <setup> blocks a page before #2925 wrote, read onto `ans` exactly as
// that page read them. Frozen: it is never extended — a new answer travels
// in the <answers> tree. The answer-level rules (permissions-version, the
// retired grid-within-hours, 'payment') are migrate()'s; only the old
// attribute spellings (admin-checkout, vat-exigibility) are read here.
function parseLegacySetup(su,ans){if(!su)return ans;
 const av=su.querySelector('availability');if(av){ans.granularity=av.getAttribute('granularity')||ans.granularity;ans.dayStart=av.getAttribute('day-start')||ans.dayStart;ans.boundary=av.getAttribute('half-boundary')||ans.boundary;ans.dayEnd=av.getAttribute('day-end')||ans.dayEnd;ans.weekdays=(av.getAttribute('open-weekdays')||'1,2,3,4,5').split(',');ans.closures=[...av.querySelectorAll('closure')].map(c=>c.getAttribute('day'));ans.policies={allowPast:av.getAttribute('allow-past-bookings')==='true',adminCheckout:(av.getAttribute('admin-check-out')??av.getAttribute('admin-checkout'))==='true',...(av.hasAttribute('outside-hours-mode')?{outsideHours:av.getAttribute('outside-hours-mode')}:{}),...(av.hasAttribute('grid-within-hours')?{gridHours:av.getAttribute('grid-within-hours')==='true'}:{}),simultaneous:av.getAttribute('simultaneous-reservations')||'1',legendProfile:av.getAttribute('legend-profile')||'full'};
  ans.horizonDays=av.getAttribute('advance-horizon-days')||ans.horizonDays;
  ans.minDuration=av.getAttribute('min-duration-minutes')||ans.minDuration;
  ans.maxDuration=av.getAttribute('max-duration-minutes')||ans.maxDuration;
  const he=av.querySelector('hour-equivalents');if(he){ans.halfDayHours=he.getAttribute('half-day')||ans.halfDayHours;ans.fullDayHours=he.getAttribute('full-day')||ans.fullDayHours}}
 const id=su.querySelector('identity');if(id){ans.language=id.getAttribute('language')||'';ans.address=id.getAttribute('address')||'';ans.whatsapp=id.getAttribute('whatsapp-group')||'';ans.deskOpacity=id.getAttribute('desk-opacity')||ans.deskOpacity;
  Object.keys(ans.invites).forEach(k=>ans.invites[k]='');id.querySelectorAll('invitation').forEach(iv=>{const k=iv.getAttribute('lang');if(k in ans.invites)ans.invites[k]=iv.getAttribute('text')||''})}
 const bi=su.querySelector('billing');if(bi){ans.tiers=[...bi.querySelectorAll('tier')].map(t=>({from:t.getAttribute('from-pct'),to:t.getAttribute('to-pct'),fee:String((parseInt(t.getAttribute('fee-cents'))||0)/100),over:String((parseInt(t.getAttribute('overage-cents'))||0)/100)}));const sl=bi.querySelector('subscription-levels');if(sl){ans.subLevels=(sl.getAttribute('values')||'').split(',').filter(Boolean);ans.freeLevel=sl.getAttribute('free-value')==='true'}ans.packages=[...bi.querySelectorAll('package')].map(p=>({name:p.getAttribute('name'),days:p.getAttribute('days'),price:String((parseInt(p.getAttribute('price-cents'))||0)/100)}))}
 ans.services=[...su.querySelectorAll('services > service')].map(s=>({name:s.getAttribute('name'),price:String((parseInt(s.getAttribute('price-cents'))||0)/100),vat:s.getAttribute('vat-percent')??'',supply:s.getAttribute('supply')==='general'?'general':'property'}));
 const le=su.querySelector('legal');if(le){ans.org=le.getAttribute('organization')||ans.org;ans.vatRegime=le.getAttribute('vat-regime')||ans.vatRegime;ans.vatExigibility=le.getAttribute('vat-tax-point')||le.getAttribute('vat-exigibility')||ans.vatExigibility;le.querySelectorAll('numbering').forEach(nu=>{const j=nu.getAttribute('journal')||'invoice';if(j==='member'){ans.memberNumbering={prefix:nu.getAttribute('prefix')||'M-',digits:nu.getAttribute('digits')||'4'}}else if(j==='invoice'){ans.numbering={prefix:nu.getAttribute('prefix')||'INV-',datePart:nu.getAttribute('date-part')||'year',digits:nu.getAttribute('digits')||'4',reset:nu.getAttribute('reset')||'yearly'}}});ans.regNumber=le.getAttribute('registration')||'';ans.vatId=le.getAttribute('vat-id')||'';ans.exemption=le.getAttribute('exemption-reason')||'';ans.street=le.getAttribute('street')||'';ans.postal=le.getAttribute('postal-code')||'';ans.city=le.getAttribute('city')||'';ans.vatRates=[...le.querySelectorAll('vat-rate')].map(r=>({group:r.getAttribute('group')||'standard',label:r.getAttribute('label')||'',percent:r.getAttribute('percent')||''}));le.querySelectorAll('mention').forEach(m=>ans.mentions[m.getAttribute('key')]=m.getAttribute('value')||'');const rm=le.querySelector('reminders');if(rm){ans.reminders={levels:rm.getAttribute('levels'),firstDays:rm.getAttribute('first-days'),betweenDays:rm.getAttribute('between-days'),automatic:rm.getAttribute('automatic')==='true'}}
ans.sites=[...le.querySelectorAll('site')].map(st=>({name:st.getAttribute('name')||'',street:st.getAttribute('street')||'',postal:st.getAttribute('postal-code')||'',city:st.getAttribute('city')||'',legalId:st.getAttribute('legal-id')||''}));
  const vd=le.querySelector('vat-declaration');if(vd)ans.vatPeriod=vd.getAttribute('period')||ans.vatPeriod;
  const ca=le.querySelector('canada-tax');if(ca){ans.landTax.qst=ca.getAttribute('qst-number')||'';ans.landTax.quick=ca.getAttribute('quick-method')==='true'}
  const lt=le.querySelector('land-taxation');if(lt)ans.landTax={qst:ans.landTax.qst,quick:ans.landTax.quick,option:lt.getAttribute('option-to-tax')==='true',date:lt.getAttribute('date')||'',ref:lt.getAttribute('reference')||'',facilities:lt.getAttribute('facilities-package')==='true',bare:lt.getAttribute('letting')==='bare'};
  const ei=le.querySelector('einvoice');if(ei)ans.einvoice={url:ei.getAttribute('url')||'',token:ei.getAttribute('token')||'',header:ei.getAttribute('auth-header')||'',field:ei.getAttribute('file-field')||'',uatUrl:ei.getAttribute('uat-url')||'',uatToken:ei.getAttribute('uat-token')||'',devUrl:ei.getAttribute('dev-url')||'',devToken:ei.getAttribute('dev-token')||'',customerUrl:ei.getAttribute('customer-url')||'',customerToken:ei.getAttribute('customer-token')||'',customerHeader:ei.getAttribute('customer-auth-header')||'',customerField:ei.getAttribute('customer-file-field')||''}}
 su.querySelectorAll('roles > role').forEach(r=>ans.perms[r.getAttribute('name')]=(r.getAttribute('permissions')||'').split(',').filter(Boolean));
 // #2331 — a file from before the page offered every permission says so
 // by its missing version; migrate() adds the ten.
 if(su.querySelector('roles')?.getAttribute('permissions-version')!=='2')delete ans.permsV;
 const va=su.querySelector('roles > validation');if(va){ans.validation={required:va.getAttribute('required'),ownerSignOff:va.getAttribute('owner-sign-off')==='true'};
  DOMAINS.forEach(k=>{ans.domains[k]={on:false,required:1,ownerSignOff:false}});
  ans.autoValidate={admin:false,owner:false};
  va.querySelectorAll('domain').forEach(d=>{const k=d.getAttribute('event-type');if(!(k in ans.domains))return;
   if(d.hasAttribute('required'))ans.domains[k]={on:true,required:d.getAttribute('required'),ownerSignOff:d.getAttribute('owner-sign-off')==='true',validators:d.getAttribute('validators')||'admins'};
   if(k==='reservation_delete'){ans.autoValidate={admin:d.getAttribute('auto-validate-admin')==='true',owner:d.getAttribute('auto-validate-owner')==='true'}}})}
 ans.members=[...su.querySelectorAll('members > member')].map(m=>({name:m.getAttribute('name'),email:m.getAttribute('email'),role:m.getAttribute('role'),pct:m.getAttribute('subscription-pct'),overage:m.getAttribute('overage-policy')||'blocked',wholeSpaces:m.getAttribute('may-reserve-whole-spaces')==='true',simultaneous:m.getAttribute('simultaneous-reservations')||'',limit:m.getAttribute('reservation-limit')||''}));
 return ans;
}
