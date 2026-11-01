// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup questionnaire's levels (#2868, #2926): the plain questions, the
// level of each process, the quick starts and the rules that turn answers
// into levels, with what the law of a country asks. Loaded before the steps
// that draw them (setup_steps.js), after the page's own script, whose state
// and helpers it uses; it never writes but through set()/setMany().
'use strict';
// The level of each process, the quick starts
// and the rules that turn answers into levels: generated from the app's
// setup_levels.dart (setup_catalogue.js), so this page recommends exactly
// what the app's levels screen does; the words are the app's own. What the
// law of a country asks comes from the bundled tax reference rows.
const LEVELS=window.SETUP_LEVELS||{questions:[],processes:[],presets:{},rules:{},evidence:{}};
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
// #3076 — the questions open from what the space already does: a question
// is yes where its evidence level is reached (setupQuestionEvidence) until
// the owner has answered; "not sure yet" is no for now, and says so.
function answersFromLevels(now){const out={};for(const q of LEVELS.questions){const e=LEVELS.evidence[q];out[q]=!!e&&levelRank(e.process,now[e.process])>=levelRank(e.process,e.level)}return out}
const shownAnswers=()=>S.journey.used?S.journey.answers:answersFromLevels(levelsNow());
const unknownQs=new Set();
function markUnknown(q){answerQuestion(q,false);unknownQs.add(q)}
function unknownNote(q){if(!unknownQs.has(q))return'';const a=shownAnswers(),yes=recommendLevels({...a,[q]:true}),no=recommendLevels({...a,[q]:false});
 return JT('setupAnswerUnknownNote',{list:LEVELS.processes.filter(pr=>yes[pr.key].level!==no[pr.key].level).map(pr=>jw('process',pr.key)+': '+jw('level',pr.key+'_'+no[pr.key].level)).join(T('listSep'))})}
function questionRows(){return LEVELS.questions.flatMap(q=>[checkbox(jw('question',q),null,shownAnswers()[q]===true,v=>answerQuestion(q,v)),
 chip(JT('setupAnswerUnknown'),unknownQs.has(q),o=>{if(o)markUnknown(q);else unknownQs.delete(q)}),
 ...(unknownQs.has(q)?[h('p',{class:'hint'},unknownNote(q))]:[])])}
function answerQuestion(q,v){unknownQs.delete(q);const a={...shownAnswers(),[q]:v},rec=recommendLevels(a);
 applyLevels(Object.entries(rec).map(([p,r])=>[p,r.level]),[['journey.answers',Object.fromEntries(Object.entries(a).filter(([,x])=>x))]])}
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
 s.onchange=()=>{applyLevel(pr.key,s.value);render()};s.setAttribute('aria-label',jw('process',pr.key));
 const why=S.journey.used&&rec[pr.key]&&rec[pr.key].level===now[pr.key]?jw('reason',rec[pr.key].reason):'';
 return h('div',{},h('label',{},jw('process',pr.key)),s,why?h('p',{class:'hint'},why):null)}

