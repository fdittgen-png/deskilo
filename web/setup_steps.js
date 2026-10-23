// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup questionnaire's steps (#2926): the levels step's helpers and
// the STEPS web/setup.html walks through — what each asks, why, when it
// applies and what it checks — with the findings they add up to. Loaded
// after the page's own script, whose state, helpers and words it uses; it
// draws, it never writes but through set()/setMany().
'use strict';
// #2868 — the plain questions, the level of each process, the quick starts
// and the rules that turn answers into levels: generated from the app's
// setup_levels.dart (setup_catalogue.js), so this page recommends exactly
// what the app's levels screen does; the words are the app's own. What the
// law of a country asks comes from the bundled tax reference rows.
const LEVELS=window.SETUP_LEVELS||{questions:[],processes:[],presets:{},rules:{}};
const OBLIGATIONS=window.SETUP_OBLIGATIONS||{};
const jw=(group,key)=>L10N[LANG]?.journey?.[group]?.[key]??L10N.en?.journey?.[group]?.[key]??key;
const JT=(key,params)=>{const s=jw('s',key);return params?s.replace(/\{(\w+)\}/g,(m,k)=>k in params?String(params[k]):m):s};
const VAT_NOTES={US:'vatNoteUS',CA:'vatNoteCA',CH:'vatNoteCH'};
// ------------------------------------------------------------------ levels (#2868)
const levelIds=p=>(LEVELS.processes.find(x=>x.key===p)?.levels||[]).map(l=>l.id);
const levelRank=(p,id)=>levelIds(p).indexOf(id);
// The first rule of each process that holds: a rule without questions
// always does — recommendSetupLevels, read from the same rules.
function recommendLevels(answers){const out={};for(const[p,rules]of Object.entries(LEVELS.rules)){const r=rules.find(x=>!x.any.length||x.any.some(q=>answers[q]===true));out[p]={level:r.level,reason:r.reason}}return out}
// Each process's level as the switches say: the highest whose switches and
// every lower level's are all ticked — currentSetupLevels.
function levelsNow(){const out={};for(const pr of LEVELS.processes){let reached=pr.levels[0].id;for(const l of pr.levels){if(!l.features.every(k=>S.features[k]))break;reached=l.id}out[pr.key]=reached}return out}
// A level ticks its switches and every lower level's, and unticks the
// higher ones' — setupFeatureDelta. The expert view keeps every switch.
// applyLevels sets the switches of each [process, level] pair in a copy of
// them and writes it once, with `also`.
function applyLevels(pairs,also=[]){const f={...S.features};let used=false;
 for(const[p,id]of pairs){const pr=LEVELS.processes.find(x=>x.key===p);if(!pr)continue;const r=levelRank(p,id);pr.levels.forEach((l,i)=>l.features.forEach(k=>{if(k in f)f[k]=i<=r}));used=true}
 setMany([...also,['features',f],...(used?[['journey.used',true]]:[])])}
function applyLevel(p,id){applyLevels([[p,id]])}
function answerQuestion(q,v){const rec=recommendLevels({...S.journey.answers,[q]:v});applyLevels(Object.entries(rec).map(([p,r])=>[p,r.level]),[[`journey.answers.${q}`,v]])}
function applyPreset(name){applyLevels(Object.entries(LEVELS.presets[name]||{}))}
const presetOf=now=>Object.keys(LEVELS.presets).find(n=>LEVELS.processes.every(pr=>LEVELS.presets[n][pr.key]===now[pr.key]))||'';
// What a vector lacks: each chosen level (and those below it) whose needs
// another process does not meet — setupVectorGaps.
function levelGaps(now){const out=[];for(const pr of LEVELS.processes){pr.levels.slice(0,levelRank(pr.key,now[pr.key])+1).forEach(l=>{for(const[np,min]of Object.entries(l.needs||{}))if(levelRank(np,now[np]??'')<levelRank(np,min))out.push(JT('setupLevelsGap',{level:jw('process',pr.key)+': '+jw('level',pr.key+'_'+l.id),needed:jw('process',np)+': '+jw('level',np+'_'+min)}))})}return out}
function obligationText(o){
 if(o.kind==='vatThreshold'){let limit=String(o.cents/100);try{limit=new Intl.NumberFormat(LANG,{style:'currency',currency:o.currency}).format(o.cents/100)}catch(e){limit=String(o.cents/100)}
  const s=L10N[LANG]?.journey?.threshold?.[o.detail]??jw('threshold','other');return s.replace(/\{limit\}/g,limit)}
 let date=o.from;try{date=new Intl.DateTimeFormat(LANG,{year:'numeric',month:'short',day:'numeric',timeZone:'UTC'}).format(new Date(o.from+'T00:00:00Z'))}catch(e){date=o.from}
 return JT(o.from<=new Date().toISOString().slice(0,10)?'eInvoiceMandateSince':'eInvoiceMandateFrom',{date,duty:jw('duty',o.detail)})}
// What the law of the country asks, from the reviewed reference rows; a
// row nobody confirmed, or no row, says to ask an accountant.
function obligationsCard(lbl){const rows=OBLIGATIONS[S.country]||[];
 const kids=[lbl(JT('setupObligationsTitle',{country:countryName(S.country)}))];
 if(!rows.length)kids.push(h('p',{class:'hint'},JT('setupObligationNone')));
 for(const o of rows)kids.push(h('p',{},obligationText(o)),h('p',{class:'hint'},(o.confirmed?'':JT('setupObligationUnconfirmed')+' ')+JT('setupObligationSource',{source:o.source})));
 return h('div',{class:'card'},...kids)}
function levelSelect(pr,now,rec){const s=h('select');for(const l of pr.levels)s.append(h('option',{value:l.id},jw('level',pr.key+'_'+l.id)));s.value=now[pr.key];
 s.onchange=()=>{applyLevel(pr.key,s.value);render()};
 const why=S.journey.used&&rec[pr.key]&&rec[pr.key].level===now[pr.key]?JT('setupLevelsBecause',{reason:jw('reason',rec[pr.key].reason)}):'';
 return h('div',{},h('label',{},jw('process',pr.key)),s,why?h('p',{class:'hint'},why):null)}

// ------------------------------------------------------------------ steps
// Each step: what it asks, why, whether it applies at all given earlier
// answers, and what it checks. Order IS the dependency order: a later
// step only reads answers from earlier ones. Titles and explanations are
// getters, so switching the language re-reads them. build(step) draws with
// the helpers bound to its step (ui), whose ? opens the step's own guide
// section when a question has none.
const STEPS=[
{id:'identity',get title(){return T('identityTitle')},get why(){return T('identityWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);return[
  input(T('identityName'),'name',T('identityNameHint'),'text','','identity'),
  selectEl(T('identityEnvironment'),'environment',opts(ENVIRONMENTS),T('identityEnvironmentHint'),null,'identity'),
  h('div',{class:'row'},selectEl(T('identityCountry'),'country',COUNTRIES.map(c=>[c[0],countryName(c[0])+(INVOICING_COUNTRIES.includes(c[0])?' · '+T('identityCountryInvoices'):'')]),T('identityCountryHint')+' '+T('identityCountryInvoicesHint',{list:INVOICING_COUNTRIES.map(countryName).join(T('listSep'))}),onCountry,'region'),
   selectEl(T('identityCurrency'),'currency',CURRENCIES.map(c=>[c,c]),T('identityCurrencyHint'),null,'region')),
  selectEl(T('identityTimezone'),'timezone',TIMEZONES.map(t=>[t,t]),T('identityTimezoneHint'),null,'region'),
  selectEl(T('identityLanguage'),'language',langOpts(),T('identityLanguageHint'),null,'language'),
  input(T('identityAddress'),'address',T('identityAddressHint'),'text',T('identityAddressPlaceholder'),'identity'),
  // #1289 — the brand seed; the app derives its themes from it and
  // refuses one that cannot be read, so the page only checks the shape.
  input(T('identityBrandColor'),'brandColor',T('identityBrandColorHint'),'text','#C2410C','identity'),
 ]},
 check(){const f=[];if(!S.name.trim())f.push(F.err(T('identityErrName'),'identity'));if(S.brandColor.trim()&&!/^#[0-9a-f]{6}$/i.test(S.brandColor.trim()))f.push(F.err(T('identityErrBrandColor'),'identity'));else f.push(F.ok(T('identityOk',{name:S.name.trim(),country:countryName(country()[0]),currency:S.currency,timezone:S.timezone})));if(S.currency!==country()[1])f.push(F.warn(T('identityWarnCurrency',{currency:S.currency,expected:country()[1]}),'identity'));
  // #2331 — the server refuses to issue for any other seller country.
  if(on('invoicing')&&!INVOICING_COUNTRIES.includes(S.country))f.push(F.warn(T('identityWarnInvoicingCountry',{country:countryName(S.country),list:INVOICING_COUNTRIES.map(countryName).join(T('listSep'))}),'identity'));return f}},

// #2868 — the plain questions, right after the country: each answer sets
// the level of every process through the app's own rules. The page works
// offline and never claims what the space is ready for.
{id:'levels',applies(){return on('setupGuide')},get title(){return JT('setupLevelsTitle')},get why(){return T('levelsWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const now=levelsNow(),rec=recommendLevels(S.journey.answers),preset=S.journey.used?presetOf(now):'';
  return[h('p',{class:'hint'},T('levelsOffline')),
   lbl(JT('setupLevelsQuestions')),
   ...LEVELS.questions.map(q=>checkbox(jw('question',q),null,S.journey.answers[q]===true,v=>answerQuestion(q,v))),
   obligationsCard(lbl),
   lbl(JT('setupLevelsPresets')),
   h('div',{class:'chips'},...Object.keys(LEVELS.presets).map(n=>chip(jw('preset',n),n===preset,()=>applyPreset(n)))),
   lbl(JT('setupLevelsChoice')),
   ...LEVELS.processes.map(pr=>levelSelect(pr,now,rec)),
   ...levelGaps(now).map(g=>h('div',{class:'dep'},g)),
   h('p',{class:'hint'},T('levelsExpertHint')),
   h('button',{class:'btn ghost',type:'button',onclick:()=>go('features')},T('levelsExpertOpen'))]},
 check(){const now=levelsNow(),gaps=levelGaps(now);const f=gaps.map(g=>F.warn(g,'levels'));
  if(!gaps.length)f.push(F.ok(S.journey.used?T('levelsOk',{list:LEVELS.processes.map(pr=>jw('process',pr.key)+': '+jw('level',pr.key+'_'+now[pr.key])).join(T('listSep'))}):T('levelsUnanswered')));
  return f}},

// #2868 — every switch: the expert view once the questions are the way in.
{id:'features',expertOnly:true,get title(){return T('featuresTitle')},get why(){return T('featuresWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const kids=[h('p',{class:'hint'},T('featuresIndentHint')),help('features')];
  const row=k=>{const name=featureTitle(k),d=featureDesc(k);const parent=REQUIRES[k];const also=alsoEnabled(k);
   const note=!availableHere(k)?T('featuresUnavailableIn',{desc:d,country:countryName(S.country),list:AVAILABLE_IN[k].map(c=>c==='@eu'?T('featuresAvailabilityEu'):countryName(c)).join(T('listSep'))}):(!S.features[k]&&also.length)?T('featuresAlsoEnables',{desc:d,list:quotedList(also)}):(S.features[k]&&parent&&!on(parent)?T('featuresWaitingFor',{desc:d,feature:quoted(featureTitle(waitsFor(k)))}):d);
   const c=checkbox(name,note,S.features[k],v=>applyFeature(k,v),(parent?'child':''));
   const fh=helpIcon(null,k);if(fh)c.querySelector('span').insertBefore(fh,c.querySelector('span div'));return c};
  // #1330 — one card per business process, the same switches underneath;
  // a switch no process lists yet (a reserved flag) is offered last.
  const placed=new Set();
  for(const p of PROCESSES){const feats=p.subprocesses.flatMap(sp=>sp.features).filter(k=>FEATURE_KEYS.has(k));if(!feats.length)continue;
   kids.push(h('div',{class:'card'},lbl(processTitle(p.key)),h('p',{class:'hint'},processDesc(p.key)),
    ...p.subprocesses.flatMap(sp=>{const own=sp.features.filter(k=>FEATURE_KEYS.has(k));return own.length?[h('div',{class:'subhead'},subprocessTitle(sp.key)),...own.map(k=>{placed.add(k);return row(k)})]:[]})))}
  const rest=FEATURES.map(([k])=>k).filter(k=>!placed.has(k));
  if(rest.length)kids.push(h('div',{class:'card'},lbl(T('featuresTechnical')),h('p',{class:'hint'},T('featuresTechnicalHint')),...rest.map(row)));
  return kids},
 check(){const f=[];const n=FEATURES.filter(([k])=>on(k)).length;f.push(F.ok(T('featuresOkCount',{n,total:FEATURES.length})));
  if(!on('moneyTab'))f.push(F.warn(T('featuresWarnMoney'),'features'));
  if(on('onlinePayments'))f.push(F.warn(T('featuresWarnOnline'),'features'),F.warn(T('featuresWarnOnlineProvider'),'features'));
  if(on('kioskMode')&&!on('nfcBadges')&&!on('qrBadges'))f.push(F.warn(T('featuresWarnKiosk'),'features'));
  return f}},

{id:'availability',get title(){return T('availabilityTitle')},get why(){return T('availabilityWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const wd=h('div',{class:'chips'},...WD.map(v=>chip(weekdayName(v),S.weekdays.includes(v),o=>set('weekdays',o?[...S.weekdays,v]:S.weekdays.filter(x=>x!==v)))));
  const gran=opts(on('workingHours')?GRAN:GRAN.filter(([v])=>v==='half_day'||v==='full_day'));
  const halfUsed=['half_day','hours','flexible'].includes(S.granularity);
  const k=[lbl(T('availOpenDays'),'availability','weekdays'),wd,help('availability'),
   selectEl(T('availGranularity'),'granularity',gran,on('workingHours')?'':T('availGranularityHint'),null,'availability'),
   on('workingHours')?null:needs('workingHours'),
   h('div',{class:'row'},input(T('availDayStart'),'dayStart','','time','','hours'),halfUsed?input(T('availBoundary'),'boundary',T('availBoundaryHint'),'time','','hours'):null,input(T('availDayEnd'),'dayEnd','','time','','hours')),
   ...(S.granularity==='hours'?[lbl(T('availHourEquivalents'),'availability'),h('p',{class:'hint'},T('availHourEquivalentsHint')),
     h('div',{class:'row'},input(T('availHalfDayHours'),'halfDayHours','','number','4','availability'),input(T('availFullDayHours'),'fullDayHours','','number','8','availability'))]:[]),
   lbl(T('availClosures'),'availability','closures'),tableRows([T('colDate')],'closures',(r,rp)=>[cell(rp,'date')],()=>'','+ '+T('availAddClosure'))];
  if(on('bookingPolicies')){k.push(lbl(T('availPolicies'),'booking','policies'),help('booking'),
   checkbox(T('availAllowPast'),T('availAllowPastDesc'),S.policies.allowPast,v=>set('policies.allowPast',v),'','booking'),
   checkbox(T('availAdminCheckout'),T('availAdminCheckoutDesc'),S.policies.adminCheckout,v=>set('policies.adminCheckout',v),'','booking'),
   selectEl(T('availOutsideHours'),'policies.outsideHours',outsideOpts(),T('availOutsideHoursHint'),null,'booking'),
   // #1281 — the legend and the plan's colours follow one choice.
   selectEl(T('availLegendProfile'),'policies.legendProfile',[['full',T('availLegendFull')],['simple',T('availLegendSimple')]],T('availLegendProfileHint'),null,'booking'),
   input(T('availSimultaneous'),'policies.simultaneous',T('availSimultaneousHint'),'number','1','booking'))}
  else k.push(needs('bookingPolicies'),h('p',{class:'hint'},T('availNoPoliciesHint')));
  k.push(lbl(T('availLimits'),'limits'),help('limits'),
   h('div',{class:'row'},selectEl(T('availHorizon'),'horizonDays',opts(HORIZON),T('availHorizonHint'),null,'limits'),selectEl(T('availMinDuration'),'minDuration',opts(DURATIONS),T('availMinDurationHint'),null,'limits'),selectEl(T('availMaxDuration'),'maxDuration',opts(DURATIONS),T('availMaxDurationHint'),null,'limits')),
   h('details',{},h('summary',{},T('availMatrixSummary')),
    h('div',{class:'matrix',html:T('availMatrixBookingHtml')}),
    h('div',{class:'matrix',html:T('availMatrixCheckinHtml')})));
  return k},
 check(){const f=[];if(!S.weekdays.length)f.push(F.err(T('availErrNoDays'),'availability'));
  const a=mins(S.dayStart),b=mins(S.boundary),c=mins(S.dayEnd);
  if(a==null||c==null||a>=c)f.push(F.err(T('availErrStartEnd'),'availability'));
  else if(['half_day','hours','flexible'].includes(S.granularity)&&(b==null||b<=a||b>=c))f.push(F.err(T('availErrBoundary'),'availability'));
  else f.push(F.ok(T('availOk',{days:S.weekdays.length,start:S.dayStart,end:S.dayEnd,granularity:granName(S.granularity)})));
  if((parseInt(S.minDuration)||0)>(parseInt(S.maxDuration)||0))f.push(F.err(T('availErrMinMax'),'availability'));
  if(S.granularity==='hours'&&((num(S.halfDayHours)||0)<=0||(num(S.fullDayHours)||0)<=(num(S.halfDayHours)||0)))f.push(F.err(T('availErrHours'),'availability'));
  if(on('bookingPolicies')&&(parseInt(S.policies.simultaneous)||0)<1)f.push(F.err(T('availErrSimultaneous'),'availability'));
  return f}},

{id:'plan',get title(){return T('planTitle')},get why(){return T('planWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const body=[help('plan'),input(T('planDeskOpacity'),'deskOpacity',T('planDeskOpacityHint'),'number','100','plan')];
  if(on('nfcSeatTags'))body.push(h('p',{class:'hint'},T('planNfcHint')),help('tags'));
  const whole=on('levelBooking');
  const yesNoAt=(path,value,redraw)=>{const s=yesNo();s.value=value?'yes':'no';s.onchange=()=>{set(path,s.value==='yes');if(redraw)render()};return s};
  S.levels.forEach((lv,li)=>{const offices=[],lp=`levels.${li}`;
   lv.offices.forEach((of,oi)=>{const op=`${lp}.offices.${oi}`;const desks=tableRows([T('planDeskName'),T('planSeats'),T('planSeatPrefix')],`${op}.desks`,(d,dp)=>[cell(`${dp}.name`),cell(`${dp}.seats`,'number'),cell(`${dp}.prefix`)],()=>({name:T('defaultDesk',{n:get(`${op}.desks`).length+1}),seats:4,prefix:T('defaultSeatPrefix')}),'+ '+T('planAddDesk'));
    offices.push(h('div',{class:'card'},h('div',{class:'row'},h('div',{},lbl(T('planOfficeName'),'plan'),cell(`${op}.name`)),
     whole?h('div',{},lbl(T('planOfficeWhole'),'whole','levels'),yesNoAt(`${op}.bookable`,of.bookable,true)):null,
     whole&&of.bookable?h('div',{},lbl(T('planOfficePrice',{currency:S.currency}),'whole'),cell(`${op}.price`,'number')):h('div')),desks,
     h('button',{class:'del',type:'button',onclick:()=>{set(`${lp}.offices`,get(`${lp}.offices`).filter((_,j)=>j!==oi));render()}},'✕ '+T('planRemoveOffice'))))});
   body.push(h('div',{class:'card'},h('div',{class:'row'},h('div',{},lbl(T('planLevelName'),'plan','levels'),cell(`${lp}.name`)),on('multiSite')&&S.sites.length?h('div',{},lbl(T('planSite'),'plan'),pick(`${lp}.site`,[['',T('planDefaultSite')],...S.sites.map(st=>[st.name,st.name])],lv.site||'')):h('div'),
    whole?h('div',{},lbl(T('planLevelWhole'),'whole','levels'),yesNoAt(`${lp}.bookable`,lv.bookable,false)):null),
    ...offices,h('button',{class:'add',type:'button',onclick:()=>{const list=get(`${lp}.offices`);set(`${lp}.offices`,[...list,newOffice(list.length+1)]);render()}},'+ '+T('planAddOffice')),
    h('button',{class:'del',type:'button',onclick:()=>{set('levels',S.levels.filter((_,j)=>j!==li));render()}},'✕ '+T('planRemoveLevel'))))});
  if(on('multiSite')){body.push(lbl(T('planSites'),'plan','sites'),h('p',{class:'hint'},T('planSitesHint')));
   S.sites.forEach((st,si)=>{const sp=`sites.${si}`;body.push(h('div',{class:'card'},h('div',{class:'row'},h('div',{},lbl(T('planSiteName'),'plan'),cell(`${sp}.name`)),h('div',{},lbl(T('fieldStreet'),'plan'),cell(`${sp}.street`)),h('div',{},lbl(T('fieldPostal'),'plan'),cell(`${sp}.postal`)),h('div',{},lbl(T('fieldCity'),'plan'),cell(`${sp}.city`)),h('div',{},lbl(T('planSiteLegalId'),'plan'),cell(`${sp}.legalId`))),
    // The levels on the removed site move to the default one.
    h('button',{class:'del',type:'button',onclick:()=>{const name=get(`${sp}.name`);setMany([['sites',S.sites.filter((_,j)=>j!==si)],...S.levels.flatMap((l,i)=>l.site===name?[[`levels.${i}.site`,'']]:[])]);render()}},'✕ '+T('planRemoveSite'))))});
   body.push(h('button',{class:'add',type:'button',onclick:()=>{set('sites',[...S.sites,{name:T('defaultSite',{n:S.sites.length+2}),street:'',postal:'',city:'',legalId:''}]);render()}},'+ '+T('planAddSite')));}
  body.push(h('button',{class:'add',type:'button',onclick:()=>{set('levels',[...S.levels,{name:T('defaultLevel',{n:S.levels.length+1}),offices:[newOffice(1)]}]);render()}},'+ '+T('planAddLevel')));
  if(!whole)body.push(needs('levelBooking'),h('p',{class:'hint'},T('planNoWholeHint')),help('whole'));
  return body},
 check(){const seats=S.levels.reduce((n,lv)=>n+lv.offices.reduce((m,of)=>m+of.desks.reduce((k,d)=>k+(parseInt(d.seats)||0),0),0),0);
  const f=[];if(!S.levels.length||seats===0)f.push(F.err(T('planErrNoSeats'),'plan'));else f.push(F.ok(T('planOk',{levels:S.levels.length,seats})));
  if(on('levelBooking'))S.levels.forEach(lv=>lv.offices.forEach(of=>{if(of.bookable&&!(num(of.price)>=0))f.push(F.warn(T('planWarnOfficeNoPrice',{office:quoted(of.name)}),'plan'))}));
  return f}},

{id:'billing',get title(){return T('billingTitle')},get why(){return T('billingWhy')},applies(){return on('moneyTab')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);return[help('billing'),lbl(T('billingTiers'),'billing','tiers'),h('p',{class:'hint'},T('billingTiersHint')),
  tableRows([T('billingFrom'),T('billingTo'),T('billingFee',{currency:S.currency}),T('billingOverage',{currency:S.currency})],'tiers',(t,tp)=>[cell(`${tp}.from`,'number'),cell(`${tp}.to`,'number'),cell(`${tp}.fee`,'number'),cell(`${tp}.over`,'number')],()=>({from:'',to:'',fee:'',over:''}),'+ '+T('billingAddTier')),
  lbl(T('billingLevels'),'billing','subLevels'),h('div',{class:'chips'},...['25','50','75','80','100'].map(v=>chip(v+' %',S.subLevels.includes(v),o=>set('subLevels',o?[...S.subLevels,v]:S.subLevels.filter(x=>x!==v))))),
  checkbox(T('billingFreeLevel'),'',S.freeLevel,v=>set('freeLevel',v),'','billing'),
  lbl(T('billingPackages'),'packages','packages'),h('p',{class:'hint'},T('billingPackagesHint')),help('packages'),
  tableRows([T('colName'),T('colDays'),T('colPrice',{currency:S.currency})],'packages',(p,pp)=>[cell(`${pp}.name`),cell(`${pp}.days`,'number'),cell(`${pp}.price`,'number')],()=>({name:'',days:'',price:''}),'+ '+T('billingAddPackage'))]},
 check(){const f=[];
  // Same shape: a palier with a bracket and no fee is dropped by the
  // filter below, so the owner sees a row on screen that never reaches
  // the app.
  S.tiers.filter(t=>t.fee===''&&(String(t.from).trim()!==''||String(t.to).trim()!==''))
   .forEach(t=>f.push(F.err(T('billingErrTierNoFee',{from:t.from,to:t.to}),'billing')));
  const tiers=S.tiers.filter(t=>t.fee!=='').map(t=>({from:num(t.from)||0,to:num(t.to)??100,fee:num(t.fee),over:num(t.over)})).sort((a,b)=>a.from-b.from);
  if(!tiers.length)f.push(F.warn(T('billingWarnNoTiers'),'billing'));
  else{let cover=0,gap=false;for(const t of tiers){if(t.from>cover)gap=true;cover=Math.max(cover,t.to)}if(gap||cover<100)f.push(F.err(T('billingErrGap'),'billing'));else f.push(F.ok(T('billingOk',{n:tiers.length})));
   for(const lv of S.subLevels){const p=parseInt(lv);if(!tiers.some(t=>p>t.from&&p<=t.to))f.push(F.err(T('billingErrLevel',{n:p}),'billing'))}}
  if(!S.subLevels.length&&!S.freeLevel)f.push(F.err(T('billingErrNoLevels'),'billing'));
  S.packages.filter(p=>p.name.trim()).forEach(p=>{if(!(num(p.days)>0)||!(num(p.price)>=0))f.push(F.err(T('billingErrPackage',{name:quoted(p.name)}),'billing'))});
  return f}},

{id:'legal',get title(){return T('legalTitle')},get why(){return T('legalWhy')},applies(){return on('invoicing')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const k=[help('legal'),selectEl(T('legalOrg'),'org',[['association',T('legalOrgAssociation')],['company',T('legalOrgCompany')]],'',null,'legal'),
  selectEl(T('legalCustomerCapacity'),'customerCapacity',[['',T('capacityNotStated')],['business',T('capacityBusiness')],['consumer',T('capacityConsumer')]],T('legalCustomerCapacityHint'),null,'legal'),
  selectEl(T('legalVatRegime'),'vatRegime',[['not_subject',T('regimeNotSubject')],['exempt',T('regimeExempt')],['registered',T('regimeRegistered')]],T('legalVatRegimeHint'),null,'vat'),
  h('div',{class:'row'},input(T('legalRegNumber'),'regNumber',T(S.org==='association'?'legalRegNumberHintAssociation':'legalRegNumberHintCompany'),'text','','legal'),S.vatRegime!=='not_subject'?input(T('legalVatId'),'vatId','','text','','vat'):null),
  !registered()?input(T('legalExemption'),'exemption',T('legalExemptionHint'),'text','','vat'):null];
  if(registered()){if(on('vatManagement')){const history=on('vatRateHistory')?[T('colValidFrom')]:[];k.push(lbl(T('legalVatRates'),'vat','vatRates'),h('p',{class:'hint'},T('legalVatRatesHint')),help('vat'),
    ...(VAT_NOTES[S.country]?[h('p',{class:'hint'},T(VAT_NOTES[S.country]))]:[]),
    tableRows(on('vatGroups')?[T('colLabel'),T('colRate'),T('colGroup'),...history]:[T('colLabel'),T('colRate'),...history],'vatRates',(r,rp)=>[cell(`${rp}.label`),cell(`${rp}.percent`,'number'),...(on('vatGroups')?[pick(`${rp}.group`,opts(VAT_GROUPS),r.group||'standard')]:[]),...(on('vatRateHistory')?[cell(`${rp}.validFrom`,'date')]:[])],()=>({label:'',percent:'',group:'standard',validFrom:''}),'+ '+T('legalAddRate')),
    VAT_RATES[S.country]?(()=>{const b=h('button',{class:'chip',type:'button'},T('legalSuggestRates',{country:countryName(country()[0]),rates:VAT_RATES[S.country].map(r=>r[1]).join(', ')}));b.onclick=()=>{seedVatRates();render()};return b})():null)}
   else k.push(needs('vatManagement'),h('p',{class:'hint'},T('legalNoVatManagementHint')));
   k.push(selectEl(T('legalVatExigibility'),'vatExigibility',opts(VATEXIGIBILITY),T('legalVatExigibilityHint'),null,'vat'));
   k.push(lbl(T('legalInvoiceNumbering'),'legal','numbering'),h('p',{class:'hint'},T('legalInvoiceNumberingHint')),
    h('div',{class:'row'},input(T('fieldPrefix'),'numbering.prefix','','text','INV-'),selectEl(T('colDate'),'numbering.datePart',opts(NUMDATE),'',null,'legal'),input(T('fieldDigits'),'numbering.digits','','number','4'),selectEl(T('numReset'),'numbering.reset',opts(numResets()),numResetHint(),null,'legal')));
   k.push(lbl(T('legalMemberNumbering'),'legal','memberNumbering'),h('p',{class:'hint'},T('legalMemberNumberingHint')),
    h('div',{class:'row'},input(T('fieldPrefix'),'memberNumbering.prefix','','text','M-'),input(T('fieldDigits'),'memberNumbering.digits','','number','4')));
   if(on('vatDeclarations'))k.push(selectEl(T('legalVatPeriod'),'vatPeriod',opts(VATPERIOD),T('legalVatPeriodHint'),null,'vat'));else k.push(needs('vatDeclarations'));
   if(S.country==='CA'&&registered())k.push(lbl(T('legalCaTax'),'vat'),h('p',{class:'hint'},T('legalCaTaxHint')),input(T('legalQstNumber'),'landTax.qst','1234567890 TQ0001','text','','vat'),checkbox(T('legalQuickMethod'),T('legalQuickMethodDesc'),S.landTax.quick,v=>set('landTax.quick',v),'','vat'));
   if(S.country==='CH')k.push(lbl(T('legalLetting'),'vat'),h('p',{class:'hint'},T('legalLettingHint')),checkbox(T('legalBareLetting'),T('legalBareLettingDesc'),S.landTax.bare,v=>set('landTax.bare',v),'','vat'),S.landTax.bare?checkbox(T('legalChOption'),'',S.landTax.option,v=>set('landTax.option',v),'','vat'):null,S.landTax.bare&&S.landTax.option?input(T('legalOptionDate'),'landTax.date','','date','','vat'):null);
   if(S.country==='GB')k.push(lbl(T('legalLandTax'),'vat'),h('p',{class:'hint'},T('legalLandTaxHint')),checkbox(T('legalOptionToTax'),'',S.landTax.option,v=>set('landTax.option',v),'','vat'),S.landTax.option?h('div',{class:'row'},input(T('legalOptionDate'),'landTax.date','','date','','vat'),input(T('legalOptionRef'),'landTax.ref','','text','','vat')):null,checkbox(T('legalFacilitiesPackage'),T('legalFacilitiesPackageDesc'),S.landTax.facilities,v=>set('landTax.facilities',v),'','vat'))}
  k.push(lbl(T('legalBillingAddress'),'legal'),h('div',{class:'row'},input(T('fieldStreet'),'street','','text','','legal'),input(T('fieldPostal'),'postal','','text','','legal'),input(T('fieldCity'),'city','','text','','legal')),
   lbl(T('legalMentions'),'legal','mentions'),help('legal'),
   input(T('mentionLegalForm'),'mentions.legalForm',T('mentionLegalFormHint')),input(T('mentionTerms'),'mentions.terms',T('mentionTermsHint')),
   h('div',{class:'row'},input(T('mentionPenalty'),'mentions.penalty',''),input(T('mentionRecovery'),'mentions.recovery','')),
   h('div',{class:'row'},input(T('mentionEscompte'),'mentions.escompte',''),input(T('mentionInsurance'),'mentions.insurance','')),input(T('mentionSpecial'),'mentions.special',''));
  if(on('dunning')){k.push(lbl(T('legalDunning'),'dunning','reminders'),help('dunning'),h('p',{class:'hint'},T('legalDunningHint')),h('div',{class:'row'},input(T('dunningLevels'),'reminders.levels','','number'),input(T('dunningFirstDays'),'reminders.firstDays','','number'),input(T('dunningBetweenDays'),'reminders.betweenDays','','number')));
   if(on('paymentReminders'))k.push(help('reminders_auto'),checkbox(T('dunningAutomatic'),T('dunningAutomaticDesc'),S.reminders.automatic===true,v=>set('reminders.automatic',v),'','reminders_auto'));else k.push(needs('paymentReminders'))}
  else k.push(needs('dunning'));
  if(isEU()){k.push(lbl(T('einvoicePlatform'),'einvoice','einvoice'),help('einvoice'),h('p',{class:'hint'},T('einvoiceHint')),
    input(T('einvoiceUrl'),'einvoice.url','','text','https://…'),h('div',{class:'row'},input(T('einvoiceToken'),'einvoice.token',''),input(T('einvoiceHeader'),'einvoice.header',T('einvoiceHeaderHint'),'text','Authorization')),input(T('einvoiceField'),'einvoice.field',T('einvoiceFieldHint'),'text','file'),
    h('details',{},h('summary',{},T('einvoiceTestEnvs')),h('p',{class:'hint'},T('einvoiceTestEnvsHint')),h('div',{class:'row'},input(T('einvoiceUatUrl'),'einvoice.uatUrl',''),input(T('einvoiceUatToken'),'einvoice.uatToken','')),h('div',{class:'row'},input(T('einvoiceDevUrl'),'einvoice.devUrl',''),input(T('einvoiceDevToken'),'einvoice.devToken',''))));
   if(on('einvoiceCustomerDelivery'))k.push(lbl(T('einvoiceCustomer'),'einvoice','einvoice'),h('p',{class:'hint'},T('einvoiceCustomerHint')),input(T('einvoiceCustomerUrl'),'einvoice.customerUrl',''),h('div',{class:'row'},input(T('einvoiceCustomerToken'),'einvoice.customerToken',''),input(T('einvoiceCustomerHeader'),'einvoice.customerHeader','','text','Authorization')),input(T('einvoiceCustomerField'),'einvoice.customerField','','text','file'));else k.push(needs('einvoiceCustomerDelivery'))}
  else k.push(dep(T('legalNonEu',{country:countryName(country()[0])}),'identity'),help('einvoice'));
  return k},
 check(){const f=[];if(!S.regNumber.trim())f.push(F.warn(T('legalWarnNoRegNumber'),'legal'));
  if(S.vatRegime!=='not_subject'&&!S.vatId.trim())f.push(F.err(T(registered()?'legalErrVatIdRegistered':'legalErrVatIdExempt'),'legal'));
  if(!registered()&&!S.exemption.trim())f.push(F.warn(T('legalWarnNoExemption'),'legal'));
  if(registered()&&on('vatManagement')&&!S.vatRates.some(r=>String(r.label).trim()&&r.percent!==''))f.push(F.err(T('legalErrNoRates'),'legal'));
  // #2331 — a registered seller with no rate the app can resolve: the
  // server refuses every invoice (vat_rate_unresolved).
  if(registered()&&!on('vatManagement'))f.push(F.err(T('legalErrRegisteredNoVatManagement',{feature:quoted(featureTitle('vatManagement'))}),'features'));
  if(!S.street.trim()||!S.postal.trim()||!S.city.trim())f.push(F.err(T('legalErrAddress'),'legal'));
  const ei=S.einvoice;if(isEU()&&ei.url.trim()&&!ei.token.trim())f.push(F.warn(T('legalWarnEinvoiceToken'),'legal'));
  if(on('einvoiceCustomerDelivery')&&ei.customerUrl.trim()&&!ei.customerToken.trim())f.push(F.warn(T('legalWarnCustomerToken'),'legal'));
  if(on('dunning')&&((parseInt(S.reminders.levels)||0)<1||(parseInt(S.reminders.firstDays)||0)<1))f.push(F.err(T('legalErrDunning'),'legal'));
  if(!f.some(x=>x.lvl==='err'))f.unshift(F.ok(T('legalOk',{org:T(S.org==='association'?'legalOkAssociation':'legalOkCompany'),regime:T(({not_subject:'legalOkNotSubject',exempt:'legalOkExempt',registered:'legalOkRegistered'})[S.vatRegime]),eu:isEU()?T('legalOkEu'):''})));
  return f}},

{id:'services',get title(){return T('servicesTitle')},get why(){return T('servicesWhy')},applies(){return on('services')||on('accessorySupplements')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const k=[help('services')];const vatCol=registered()&&on('vatManagement');const supplyCol=vatCol&&on('supplyClassification');
  if(on('services'))k.push(lbl(T('servicesServices'),'services','services'),tableRows([T('colName'),T('colPrice',{currency:S.currency}),...(vatCol?[T('servicesVatCol')]:[]),...(supplyCol?[h('span',{},T('servicesSupplyCol'),helpIcon('supplyClass'))]:[])],'services',(s,sp)=>[cell(`${sp}.name`),cell(`${sp}.price`,'number'),...(vatCol?[cell(`${sp}.vat`,'number')]:[]),...(supplyCol?[pick(`${sp}.supply`,[['property',T('servicesSupplyProperty')],['general',T('servicesSupplyGeneral')]],s.supply==='general'?'general':'property')]:[])],()=>({name:'',price:'',vat:'',supply:'property'}),'+ '+T('servicesAdd')));else k.push(needs('services'));
  if(on('accessorySupplements'))k.push(lbl(T('servicesAccessories'),'services','accessories'),h('p',{class:'hint'},T('servicesAccessoriesHint')),tableRows([T('colName'),T('servicesSupplement',{currency:S.currency})],'accessories',(a,ap)=>[cell(`${ap}.name`),cell(`${ap}.supp`,'number')],()=>({name:'',supp:'0'}),'+ '+T('servicesAddAccessory')));else k.push(needs('accessorySupplements'));
  if(!vatCol&&on('services'))k.push(dep(registered()?T('servicesVatHiddenFeature',{feature:quoted(featureTitle('vatManagement'))}):T('servicesVatHiddenNotSubject'),registered()?'features':'legal'));
  return k},
 check(){const f=[];if(on('services')){const n=S.services.filter(s=>s.name.trim()).length;if(!n)f.push(F.err(T('servicesErrNone'),'services'));else f.push(F.ok(T('servicesOk',{n})));S.services.filter(s=>s.name.trim()&&!(num(s.price)>=0)).forEach(s=>f.push(F.err(T('servicesErrNoPrice',{name:quoted(s.name)}),'services')))}
  if(on('accessorySupplements')){const n=S.accessories.filter(a=>a.name.trim()).length;if(!n)f.push(F.err(T('accessoriesErrNone'),'services'));else f.push(F.ok(T('accessoriesOk',{n})))}return f}},

{id:'pay',get title(){return T('payTitle')},get why(){return T('payWhy')},applies(){return on('moneyTab')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const sc=scheme();const k=[help('pay'),h('p',{class:'hint'},T('payHint'))];
  if(sc==='sepa')k.push(h('div',{class:'row'},input('IBAN','pay.iban',''),input('BIC / SWIFT','pay.bic',T('payBicHint'))),input(T('payBankName'),'pay.bank_name',T('optional')));
  if(sc==='ch')k.push(h('div',{class:'row'},input('IBAN','pay.iban',''),input(T('payQrIban'),'pay.qr_iban',T('payQrIbanHint'))),h('div',{class:'row'},input('BIC / SWIFT','pay.bic',T('payBicHint')),input(T('payBankName'),'pay.bank_name',T('optional'))));
  if(sc==='uk')k.push(h('div',{class:'row'},input(T('payAccountNumber'),'pay.account_number',''),input(T('paySortCode'),'pay.bank_code','')),input(T('payBankName'),'pay.bank_name',''),input(T('payIbanIntl'),'pay.iban',T('optional')));
  if(sc==='us')k.push(h('div',{class:'row'},input(T('payAccountNumber'),'pay.account_number',''),input(T('payRoutingNumber'),'pay.bank_code','')),input(T('payBankName'),'pay.bank_name',''));
  if(sc==='ca')k.push(h('div',{class:'row'},input(T('payAccountNumber'),'pay.account_number',''),input(T('payTransit'),'pay.bank_code',T('payTransitHint'))),input(T('payBankName'),'pay.bank_name',''));
  k.push(lbl(T('payMobile'),'pay','pay'),h('div',{class:'row'},input(T('payPaypal'),'pay.paypal_me',''),isEU()?input(T('payWero'),'pay.wero',T('payWeroHint')):null),
   h('div',{class:'row'},S.country==='FR'?input(T('payLydia'),'pay.lydia',''):null,input(T('payWise'),'pay.wise','')),input(T('payReference'),'pay.reference',T('payReferenceHint')));
  if(on('onlinePayments'))k.push(dep(T('payOnlineDep'),'features'),help('online'));
  return k},
 check(){const any=Object.values(S.pay).some(v=>String(v).trim());const f=[];if(!any&&!on('onlinePayments'))f.push(F.warn(T('payWarnNone'),'pay'));else f.push(F.ok(T(any?'payOkInstructions':'payOkOnlineOnly')));
  if((scheme()==='sepa'||scheme()==='ch')&&S.pay.iban.trim()&&!/^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/.test(S.pay.iban.replace(/\s+/g,'').toUpperCase()))f.push(F.err(T('payErrIban'),'pay'));
  if(scheme()==='ch'&&S.pay.qr_iban.trim()&&!/^(CH|LI)\d{2}3[01]\d{3}[A-Z0-9]{12}$/.test(S.pay.qr_iban.replace(/\s+/g,'').toUpperCase()))f.push(F.err(T('payErrQrIban'),'pay'));return f}},

{id:'roles',get title(){return T('rolesTitle')},get why(){return T('rolesWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const k=[];
  if(on('roleManagement')){k.push(help('roles'));for(const[role,label]of[['co_owner','roleCoOwner'],['admin','roleAdmin'],['member','roleEveryMember']]){if(role==='co_owner'&&!on('coOwner'))continue;
    k.push(h('div',{class:'card'},lbl(T(label),'roles','perms'),...PERMS.filter(p=>p!=='issueInvoices'||on('invoicing')).filter(p=>p!=='manageServices'||on('services')).filter(p=>(p!=='manageDocuments'&&p!=='viewDocuments')||on('documents')).filter(p=>!['deployToProd','deployToDev','accessProd'].includes(p)||on('environmentPairs')).filter(p=>(p!=='viewNegotiations'&&p!=='manageNegotiations')||on('priceNegotiations')).map(p=>checkbox(permName(p),'',S.perms[role].includes(p),v=>set(`perms.${role}`,v?[...S.perms[role],p]:S.perms[role].filter(x=>x!==p)),'',p.endsWith('Negotiations')?'negotiations':'roles'))))}}
  else k.push(needs('roleManagement'),h('p',{class:'hint'},T('rolesDefaultMatrixHint')),help('roles'));
  if(on('adminInvoicing'))k.push(dep(T('rolesAdminInvoicingDep',{feature:quoted(featureTitle('adminInvoicing'))}),'features'));
  k.push(lbl(T('rolesDefaultRule'),'validation','validation'),help('validation'),h('p',{class:'hint'},T('rolesDefaultRuleHint')),
   h('div',{class:'row'},input(T('rolesRequired'),'validation.required','','number'),checkbox(T('rolesOwnerAlways'),'',S.validation.ownerSignOff,v=>set('validation.ownerSignOff',v),'','validation')),
   lbl(T('rolesDomains'),'validation','domains'),h('p',{class:'hint'},T('rolesDomainsHint')));
  // A card whose switch is off is not offered (normalize() keeps it off).
  for(const dk of DOMAINS){const g=DOMAIN_GATE[dk];if(g&&!on(g))continue;const d=S.domains[dk],dp=`domains.${dk}`;
   const head=checkbox(domainName(dk),'',d.on,v=>set(`${dp}.on`,v),'','validation');if(!d.on){k.push(head);continue}
   const row=[h('div',{},lbl(T('rolesRequired'),'validation'),cell(`${dp}.required`,'number')),h('div',{},h('label',{},' '),checkbox(T('rolesOwnerSignOff'),'',d.ownerSignOff,v=>set(`${dp}.ownerSignOff`,v),'','validation'))];
   if(on('validationScopes'))row.unshift(h('div',{},lbl(T('rolesWhoValidates'),'scopes'),pick(`${dp}.validators`,[['admins',T('scopeAdmins')],['members',T('scopeMembers')]],d.validators||'admins'),help('scopes'),h('p',{class:'hint'},T('rolesWhoValidatesHint'))));
   k.push(h('div',{class:'card'},head,h('div',{class:'row'},...row)))}
  if(on('deletionRequests'))k.push(lbl(T('rolesAutoDelete'),'validation','autoValidate'),h('p',{class:'hint'},T('rolesAutoDeleteHint')),
   checkbox(T('rolesAutoOwner'),'',S.autoValidate.owner,v=>set('autoValidate.owner',v),'','validation'),checkbox(T('rolesAutoAdmin'),'',S.autoValidate.admin,v=>set('autoValidate.admin',v),'','validation'));
  else k.push(needs('deletionRequests'));
  return k},
 check(){const f=[];if((parseInt(S.validation.required)||0)<1)f.push(F.err(T('rolesErrDefault'),'roles'));
  for(const dk of DOMAINS){const d=S.domains[dk];if(d.on&&(parseInt(d.required)||0)<1)f.push(F.err(T('rolesErrDomain',{domain:quoted(domainName(dk))}),'roles'))}
  const admins=S.members.filter(m=>m.role==='admin').length;if((parseInt(S.validation.required)||0)>1+admins)f.push(F.warn(T('rolesWarnValidators',{required:S.validation.required,possible:1+admins}),'members'));
  if(!f.length)f.push(F.ok(T('rolesOk',{n:S.validation.required,owner:S.validation.ownerSignOff?T('ownerSignOffSuffix'):''})));return f}},

{id:'members',get title(){return T('membersTitle')},get why(){return T('membersWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const pk=S.packages.some(p=>p.name.trim());const whole=on('levelBooking');const sim=on('bookingPolicies');
  const cols=[T('colName'),T('colEmail'),T('colRole'),T('colSubscription'),T('colOverage'),...(whole?[T('colWholeSpaces')]:[]),...(sim?[T('colSimultaneous')]:[]),T('colLimit')];
  const hint=[T('membersHint',{packages:pk?T('membersHintPackages'):''}),whole?T('membersHintWhole'):null,sim?T('membersHintSimultaneous'):null].filter(Boolean).join(' ');
  const k=[help('members'),h('p',{class:'hint'},hint,destBadge('members')),
   // The level and the overage policy are kept among what is offered by
   // normalize(); the selects only show them.
   tableRows(cols,'members',(m,mp)=>[cell(`${mp}.name`),cell(`${mp}.email`,'email'),
    pick(`${mp}.role`,[['member',T('roleMember')],['admin',T('roleAdmin')]],m.role||'member'),
    S.freeLevel?cell(`${mp}.pct`,'number'):pick(`${mp}.pct`,(S.subLevels.length?S.subLevels:['100']).map(v=>[v,v+' %']),m.pct||'100'),
    pick(`${mp}.overage`,[['blocked',T('overageBlocked')],['payg',T('overagePayg')],...(pk?[['packages',T('overagePackages')]]:[])],m.overage||'blocked'),
    ...(whole?[(()=>{const c=h('input',{type:'checkbox'});c.title=T('membersWholeTitle');c.checked=!!m.wholeSpaces;c.onchange=()=>set(`${mp}.wholeSpaces`,c.checked);return c})()]:[]),
    ...(sim?[cell(`${mp}.simultaneous`,'number')]:[]),cell(`${mp}.limit`,'number')],
    ()=>({name:'',email:'',role:'member',pct:S.subLevels[0]||'100',overage:'blocked',wholeSpaces:false,simultaneous:'',limit:''}),'+ '+T('membersAdd')),
   !pk&&on('moneyTab')?dep(T('membersPackagesHidden'),'billing'):null,
   lbl(T('membersInvites'),'invites','invites'),help('invites'),h('p',{class:'hint'},T('membersInvitesHint')),
   ...['fr','en','de','es','it'].map(c=>input(ENDONYMS[c],'invites.'+c,''))];
  if(on('whatsappIntegration'))k.push(input(T('membersWhatsapp'),'whatsapp',T('membersWhatsappHint'),'text','','whatsapp'));else k.push(needs('whatsappIntegration'));
  k.push(dep(T('membersConsent')),help('consent'));
  return k},
 check(){const f=[];const ms=S.members.filter(m=>m.email.trim());const seen=new Set();
  ms.forEach(m=>{const e=m.email.trim().toLowerCase();if(!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e))f.push(F.err(T('membersErrEmail',{email:m.email}),'members'));if(seen.has(e))f.push(F.err(T('membersErrDuplicate',{email:m.email}),'members'));seen.add(e);
   if(!S.freeLevel&&S.subLevels.length&&!S.subLevels.includes(String(m.pct)))f.push(F.err(T('membersErrLevel',{who:m.name||m.email,pct:m.pct}),'members'))});
  // A row with a name and no address is not "no member" — it is a member
  // the export silently drops, which the owner only discovers when the
  // invitation never arrives.
  S.members.filter(m=>String(m.name||'').trim()&&!String(m.email||'').trim())
   .forEach(m=>f.push(F.err(T('membersErrNoEmail',{name:quoted(m.name.trim())}),'members')));
  if(!ms.length)f.push(F.warn(T('membersWarnNone'),'members'));else f.push(F.ok(T('membersOk',{n:ms.length,admins:ms.filter(m=>m.role==='admin').length})));
  if(on('whatsappIntegration')&&S.whatsapp.trim()&&!/^https:\/\/chat\.whatsapp\.com\//.test(S.whatsapp.trim()))f.push(F.warn(T('membersWarnWhatsapp'),'members'));return f}},

{id:'summary',get title(){return T('summaryTitle')},get why(){return T('summaryWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const money=v=>(parseFloat(v)||0).toFixed(2)+' '+S.currency;const n=x=>x.filter(r=>String(r.name||r.label||'').trim()).length;
  const cfg={
   calendarTab:()=>T('cfgCalendarTab'),
   eventsTab:()=>T('cfgEventsTab',{required:S.validation.required,owner:S.validation.ownerSignOff?T('ownerSignOffSuffix'):'',domains:Object.values(S.domains).filter(d=>d.on).length}),
   moneyTab:()=>{const t=S.tiers.filter(x=>x.fee!=='');return T('cfgMoneyTab',{tiers:t.length?T('cfgMoneyTiers',{n:t.length,list:t.map(x=>T('cfgMoneyTierItem',{from:x.from,to:x.to,fee:money(x.fee)})).join(', ')}):T('cfgMoneyNoTiers'),levels:S.subLevels.join(', ')||'—',free:S.freeLevel?T('cfgMoneyFree'):'',packages:n(S.packages)})},
   services:()=>n(S.services)?T('cfgServices',{n:n(S.services),list:S.services.filter(x=>x.name.trim()).map(x=>x.name+' '+money(x.price)).join(', ')}):T('cfgServicesNone'),
   accessorySupplements:()=>n(S.accessories)?T('cfgAccessories',{n:n(S.accessories),list:S.accessories.filter(x=>x.name.trim()).map(x=>T('cfgPerHalfDayItem',{name:x.name,price:money(x.supp)})).join(', ')}):T('cfgAccessoriesNone'),
   onlinePayments:()=>T('cfgOnlinePayments'),
   invoicing:()=>[T(({not_subject:'cfgRegimeNotSubject',exempt:'cfgRegimeExempt',registered:'cfgRegimeRegistered'})[S.vatRegime]),registered()?T(({standard:'cfgExigStandard',invoice:'cfgExigInvoice',cash:'cfgExigPayment'})[S.vatExigibility]):null,S.regNumber?T('cfgRegNumber',{n:S.regNumber}):null,S.street||S.city?[S.street,S.postal,S.city].filter(Boolean).join(' '):null,isEU()?T(S.einvoice.url?'cfgEinvoiceConfigured':'cfgEinvoiceTodo'):T('cfgNonEu')].filter(Boolean).join(' · '),
   adminInvoicing:()=>T('cfgAdminInvoicing'),
   pdfExport:()=>T('cfgPdfExport'),
   seriesBooking:()=>T('cfgSeriesBooking'),
   bookForOthers:()=>T('cfgBookForOthers'),
   pushNotifications:()=>T('cfgPushNotifications'),
   adminSeatBlocking:()=>T('cfgAdminSeatBlocking'),
   levelBooking:()=>{const o=S.levels.flatMap(l=>l.offices).filter(x=>x.bookable);return o.length?T('cfgLevelBooking',{n:o.length,list:o.map(x=>T('cfgPerHalfDayItem',{name:x.name,price:money(x.price)})).join(', ')}):T('cfgLevelBookingNone')},
   adminLevelAssign:()=>T('cfgAdminLevelAssign'),
   kioskMode:()=>[T('cfgKiosk'),on('nfcBadges')?T('cfgKioskNfc'):null,on('qrBadges')?T('cfgKioskQr'):null,on('badgeSignIn')?T('cfgKioskBadgeSignIn'):null].filter(Boolean).join(' · ')+'.',
   nfcBadges:()=>T('cfgNfcBadges'),qrBadges:()=>T('cfgQrBadges'),badgeSignIn:()=>T('cfgBadgeSignIn'),kioskMemberPhotos:()=>T('cfgKioskMemberPhotos'),
   membersDirectory:()=>[T('cfgMembersDirectory'),on('whatsappIntegration')&&S.whatsapp?T('cfgWhatsappLinked'):null].filter(Boolean).join(' · ')+'.',
   whatsappIntegration:()=>S.whatsapp?T('cfgWhatsappGroup',{url:S.whatsapp}):T('cfgWhatsappTodo'),
   spaceQrCodes:()=>T('cfgSpaceQrCodes'),
   coOwner:()=>T('cfgCoOwner',{n:(S.perms.co_owner||[]).length}),
   autoCheckInOut:()=>T('cfgAutoCheckInOut'),
   dataExport:()=>T('cfgDataExport'),
   workingHours:()=>granName(S.granularity)+' · '+S.dayStart+'–'+S.dayEnd+(S.granularity==='hours'?' · '+T('cfgHourEquivalents',{half:S.halfDayHours,full:S.fullDayHours}):'')+'.',
   invoicePdfTemplate:()=>T('cfgInvoicePdfTemplate'),
   memberNotifications:()=>T('cfgMemberNotifications'),
   documents:()=>T('cfgDocuments'),
   dunning:()=>T('cfgDunning',{levels:S.reminders.levels,first:S.reminders.firstDays,between:S.reminders.betweenDays}),
   paymentReminders:()=>T(S.reminders.automatic===true?'cfgRemindersAuto':'cfgRemindersManual'),
   memberReports:()=>T('cfgMemberReports'),
   deletionRequests:()=>{const who=[S.autoValidate.owner?T('cfgOwners'):null,S.autoValidate.admin?T('cfgAdmins'):null].filter(Boolean);return [T('cfgDeletionRequests'),who.length?T('cfgAutoValidation',{list:who.join(', ')}):null].filter(Boolean).join(' · ')+'.'},
   roleManagement:()=>T('cfgRoleManagement',{coOwner:(S.perms.co_owner||[]).length,admin:(S.perms.admin||[]).length,member:(S.perms.member||[]).length}),
   vatManagement:()=>registered()?T('cfgVatRates',{n:n(S.vatRates),list:S.vatRates.filter(r=>String(r.label).trim()).map(r=>r.percent+' %').join(', ')}):T('cfgNotRegistered'),
   vatDeclarations:()=>registered()?T(({month:'cfgVatDeclMonthly',annual:'cfgVatDeclAnnual'})[S.vatPeriod]||'cfgVatDeclQuarterly'):T('cfgNotRegistered'),
   einvoiceCustomerDelivery:()=>S.einvoice.customerUrl?T('cfgCustomerService',{url:S.einvoice.customerUrl}):T('cfgCustomerServiceTodo'),
   planObjectDelete:()=>T('cfgPlanObjectDelete'),
   notificationGrouping:()=>T('cfgNotificationGrouping'),
   bookingPolicies:()=>[T('cfgOutsideHours',{mode:outsideName(S.policies.outsideHours)}),T('cfgSimultaneous',{n:S.policies.simultaneous||1}),S.policies.allowPast?T('cfgPastAllowed'):null,S.policies.adminCheckout?T('cfgAdminCheckout'):null].filter(Boolean).join(' · ')+'.',
   nfcSeatTags:()=>T('cfgNfcSeatTags'),
   formHelpHints:()=>T('cfgFormHelpHints'),
   planMemberPhotos:()=>T('cfgPlanMemberPhotos'),
   regionalFormats:()=>T('cfgRegionalFormats',{currency:S.currency,timezone:S.timezone}),
   calendarHub:()=>T('cfgCalendarHub'),
   dataAccessLog:()=>T('cfgDataAccessLog'),
   memberDataExport:()=>T('cfgMemberDataExport'),
   financeFaces:()=>T('cfgFinanceFaces'),
   supplyExpenses:()=>T('cfgSupplyExpenses'),
   validationScopes:()=>{const s=Object.entries(S.domains).filter(([,d])=>d.on&&d.validators&&d.validators!=='admins');return s.length?T('cfgScopes',{list:s.map(([dk,d])=>domainName(dk)+' → '+T(d.validators==='members'?'cfgScopeMembers':'cfgScopeNamed')).join(', ')}):T('cfgScopesNone')},
   memberEnvironments:()=>T('cfgMemberEnvironments'),
   workspaceLibrary:()=>T('cfgWorkspaceLibrary'),
   memberOrigin:()=>T('cfgMemberOrigin'),
   uiAnimations:()=>T('cfgUiAnimations'),
   scheduledExpenses:()=>T('cfgScheduledExpenses'),
   priceNegotiations:()=>T('cfgPriceNegotiations'),
  };
  const active=FEATURES.filter(([k])=>on(k)),inactive=FEATURES.filter(([k])=>!on(k));
  const children=k=>Object.entries(REQUIRES).filter(([,p])=>p===k).map(([c])=>c).filter(c=>on(c));
  const k=[help('features'),h('p',{class:'hint'},T('summaryCountHint',{active:active.length,inactive:inactive.length}))];
  for(const[key]of active){let conf='';try{conf=cfg[key]?cfg[key]():''}catch(e){conf=''}
   const kids=children(key);
   const c=h('input',{type:'checkbox'});c.checked=true;c.onchange=()=>{applyFeature(key,false);render()};
   k.push(h('div',{class:'card'},h('label',{class:'check',style:'margin:0'},c,h('span',{},h('b',{},featureTitle(key)),h('div',{class:'d'},featureDesc(key)),conf?h('div',{class:'d',style:'margin-top:4px;color:var(--ink)'},T('summaryConfigured',{conf})):null,
     kids.length?h('div',{class:'d',style:'margin-top:4px'},T('summaryUncheckAlso',{list:kids.map(c=>featureTitle(c)).join(', ')})):null,
     help(FEATURE_HELP[key])))))}
  if(inactive.length)k.push(h('details',{},h('summary',{},T('summaryInactive',{n:inactive.length})),
   ...inactive.map(([key])=>{const also=alsoEnabled(key);const d=featureDesc(key);
    // Ticking a child MUST bring its chain, or the row says "on" while
    // `on()` reads it as off — a contradiction the page used to allow.
    return checkbox(featureTitle(key),also.length?T('featuresAlsoEnables',{desc:d,list:quotedList(also)}):d,false,
     v=>applyFeature(key,v))})));
  return k},
 check(){const active=FEATURES.filter(([k])=>on(k)).length;return[F.ok(T('summaryOk',{active,inactive:FEATURES.length-active}))]}},
{id:'review',get title(){return T('reviewTitle')},get why(){return T('reviewWhy')},
 build(st=this){const{lbl,input,selectEl,helpIcon}=ui(st);const all=findings();const c={ok:0,warn:0,err:0};all.forEach(x=>c[x.lvl]++);
  const k=[h('div',{class:'summary'},h('b',{class:'ok'},'✓ '+T('reviewChecked',{n:c.ok})),h('b',{class:'warn'},'⚠ '+T('reviewWarnings',{n:c.warn})),h('b',{class:'err'},'✕ '+T('reviewBlockers',{n:c.err})))];
  // #1330 — what the answers mean in business terms: each process, the
  // subprocesses in use, and a ticked switch that waits for a prerequisite.
  k.push(h('div',{class:'card'},lbl(T('reviewProcesses')),...PROCESSES.map(p=>{
   const feats=p.subprocesses.flatMap(sp=>sp.features).filter(k=>FEATURE_KEYS.has(k));const n=feats.filter(k=>on(k)).length;
   const subs=p.subprocesses.filter(sp=>sp.features.some(k=>FEATURE_KEYS.has(k)&&on(k))).map(sp=>subprocessTitle(sp.key));
   const waiting=feats.filter(k=>S.features[k]&&!on(k)).map(k=>T('reviewWaitingFor',{feature:featureTitle(k),parent:featureTitle(waitsFor(k))}));
   return h('div',{class:'finding '+(n?'ok':'off')},h('span',{class:'lvl'},n?'✓':'–'),h('span',{},processTitle(p.key)+' — '+(n?T('reviewProcessCount',{n,total:feats.length,list:subs.join(T('listSep'))}):T('reviewProcessOff')),...waiting.map(w=>h('div',{class:'d'},w))))})));
  for(const st of STEPS){if(st.id==='review')continue;const rows=all.filter(x=>x.from===st.id);if(!rows.length)continue;
   k.push(h('div',{class:'card'},h('label',{},(STEPS.indexOf(st)+1)+' · '+st.title+(st.applies&&!st.applies()?' — '+T('reviewNotApplicable'):'')),...rows.map(x=>h('div',{class:'finding '+x.lvl},h('span',{class:'lvl'},x.lvl==='ok'?'✓':x.lvl==='warn'?'⚠':'✕'),h('span',{},x.t),x.lvl!=='ok'&&x.step?h('button',{class:'chip',type:'button',onclick:()=>go(x.step)},T('reviewFix')):null))))}
  // #2331 — what the import does NOT do, said before the owner finds out.
  const todo=toDoInApp();
  k.push(h('div',{class:'card'},lbl(T('reviewToDoTitle')),h('p',{class:'hint'},T('reviewToDoHint')),
   ...todo.map(t=>h('div',{class:'finding warn'},h('span',{class:'lvl'},'→'),h('span',{},t)))));
  const gate=h('div',{class:'gate'+(c.err?'':' ok')});
  if(c.err){gate.append(h('b',{},T('reviewGateBlocked',{n:c.err})),
    h('ul',{},...all.filter(x=>x.lvl==='err').map(x=>{const li=h('li',{},x.t+' ');
     if(x.step)li.append((()=>{const a=h('a',{href:'#'},'→ '+T('reviewFixLink'));a.onclick=e=>{e.preventDefault();go(x.step)};return a})());return li})),
    h('p',{class:'hint'},T('reviewNothingLost')))}
  else{gate.append(h('b',{},'✓ '+T('reviewComplete')),
    h('span',{},T('reviewImportHint')))}
  k.push(gate);
  const xb=h('button',{class:'btn primary',type:'button',onclick:exportChecked},'⬇ '+(c.err?T('setupExportBlocked',{n:c.err}):T('setupExportXml')));
  if(c.err)xb.disabled=true;
  k.push(xb,help('identity'));
  return k},check(){return[]}},
];
// #2331 — every answer the import cannot apply (DEST 'app' / 'file'), and
// what nothing in the page asks for but the space needs, in the order the
// owner meets them in the app.
function toDoInApp(){const out=[T('todoCreateSpace',{name:S.name.trim()||'—'})];
 const ms=S.members.filter(m=>String(m.email||'').trim());
 out.push(ms.length?T('todoInviteMembers',{n:ms.length}):T('todoInviteNobody'));
 if(on('onlinePayments'))out.push(T('todoOnlineProvider'));
 if(on('invoicing')&&isEU())out.push(T('todoEinvoice'));
 if(on('invoicing')&&!INVOICING_COUNTRIES.includes(S.country))out.push(T('todoInvoiceOutside',{country:countryName(S.country)}));
 out.push(T('todoImportFile'));
 return out}
function findings(){const out=[];for(const st of STEPS){if(st.id==='review')continue;if(st.applies&&!st.applies()){continue}for(const x of st.check())out.push({...x,from:st.id})}return out}
function stepStatus(st){if(st.applies&&!st.applies())return 'na';if(st.id==='review')return '';const f=st.check();if(f.some(x=>x.lvl==='err'))return 'err';if(f.some(x=>x.lvl==='warn'))return 'warn';return 'ok'}
