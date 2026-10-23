// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup questionnaire's parameters (#2926): the options its questions
// offer, PARAM_META — how each answer is worded and checked, which
// normalize() and the WebMCP tools (setup_webmcp.js) read — and where each
// answer is explained (helpAnchorFor). Loaded after web/setup.html's own
// script.
'use strict';
// l10n-exempt-begin
// Not prose to translate. Each language's name in that language; the
// statutory VAT rate labels in each country's own language (they become the
// owner's data when proposed); and the two names the XML export and import
// fall back to, which must stay byte-identical whatever the page language.
const ENDONYMS={en:'English',fr:'Français',de:'Deutsch',es:'Español',it:'Italiano'};
const VAT_RATES={
 FR:[['Standard 20 %',20],['Intermédiaire 10 %',10],['Réduit 5,5 %',5.5],['Particulier 2,1 %',2.1]],
 DE:[['Regelsatz 19 %',19],['Ermäßigt 7 %',7]],
 BE:[['Standaard 21 %',21],['Verlaagd 12 %',12],['Verlaagd 6 %',6]],
 ES:[['General 21 %',21],['Reducido 10 %',10],['Superreducido 4 %',4]],
 IT:[['Ordinaria 22 %',22],['Ridotta 10 %',10],['Ridotta 5 %',5],['Minima 4 %',4]],
 LU:[['Normal 17 %',17],['Intermédiaire 14 %',14],['Réduit 8 %',8],['Super-réduit 3 %',3]],
 CH:[['Normal 8,1 %',8.1],['Hébergement 3,8 %',3.8],['Réduit 2,6 %',2.6]],
 AT:[['Normalsatz 20 %',20],['Ermäßigt 13 %',13],['Ermäßigt 10 %',10]],
 NL:[['Hoog 21 %',21],['Laag 9 %',9]],
 PT:[['Normal 23 %',23],['Intermédia 13 %',13],['Reduzida 6 %',6]],
 GB:[['Standard 20 %',20],['Reduced 5 %',5],['Zero 0 %',0]],
 NO:[['Alminnelig 25 %',25],['Næringsmidler 15 %',15],['Redusert 12 %',12]],
 CA:[['GST 5 % (AB/NT/NU/YT)',5],['HST 13 % (ON)',13],['HST 14 % (NS)',14],['HST 15 % (NB/NL/PE)',15],['GST+QST 14,975 % (QC)',14.975],['GST+PST 12 % (BC/MB)',12],['GST+PST 11 % (SK)',11]],
};
const XML_LEVEL_FALLBACK='Étage',XML_SEAT_FALLBACK='Place';
// l10n-exempt-end
// #711 — the currencies the app can format (decimal digits included) and the catalogue countries' time zones.
const CURRENCIES=['AUD','BGN','BRL','CAD','CHF','CNY','CZK','DKK','EUR','GBP','HKD','HRK','HUF','ILS','INR','ISK','JPY','KRW','MXN','NOK','NZD','PLN','RON','SEK','SGD','TRY','USD','ZAR'];
const TIMEZONES=[...new Set(COUNTRIES.map(c=>c[2]).concat(['America/Los_Angeles','America/Chicago','America/Denver','America/Vancouver','America/Montreal','Australia/Sydney','Asia/Tokyo','Asia/Singapore','Europe/Dublin','Atlantic/Canary','UTC']))].sort();
const HORIZON=[['7','optDays',{n:7}],['14','optDays',{n:14}],['30','optDays',{n:30}],['60','optDays',{n:60}],['90','optDaysDefault',{n:90}],['120','optDays',{n:120}],['180','optDays',{n:180}],['365','optOneYear'],['730','optYears',{n:2}]];
const DURATIONS=[['5','optMinutes',{n:5}],['10','optMinutes',{n:10}],['15','optMinutes',{n:15}],['30','optMinutesDefaultMin',{n:30}],['45','optMinutes',{n:45}],['60','optOneHour'],['90','optHourAndHalf'],['120','optHours',{n:2}],['180','optHours',{n:3}],['240','optHours',{n:4}],['300','optHours',{n:5}],['360','optHours',{n:6}],['480','optHours',{n:8}],['600','optHours',{n:10}],['720','optHours',{n:12}],['1440','optHoursDefaultMax',{n:24}]];
const VATPERIOD=[['month','vatPeriodMonth'],['quarter','vatPeriodQuarter'],['annual','vatPeriodAnnual']];
const ENVIRONMENTS=[['dev','envDev'],['prod','envProd']];
const NUMDATE=[['none','numDateNone'],['year','numDateYear'],['year_month','numDateYearMonth']];
const NUMRESET=[['never','numResetNever'],['yearly','numResetYearly'],['monthly','numResetMonthly']];
// #1320 — a number never restarts more often than it prints its date,
// or it would print a number already handed out (the server refuses these pairs).
const RESETS_FOR={none:['never'],year:['never','yearly'],year_month:['never','yearly','monthly']};
const resetsFor=s=>RESETS_FOR[s.numbering.datePart]||['never'];
function numResets(){const ok=resetsFor(S);return NUMRESET.filter(([v])=>ok.includes(v))}
function numResetHint(){return S.numbering.datePart==='year_month'?'':T('numResetHint')}
// #2355 — the VAT tax point: the country's legal rule, the invoice date
// (France's option for the debits) or cash. The app keeps only what the
// seller's country allows.
const VATEXIGIBILITY=[['standard','exigStandard'],['invoice','exigInvoice'],['cash','exigPayment']];
const OUTSIDE=[['charged','outsideCharged','outsideChargedDesc'],['free','outsideFree','outsideFreeDesc'],['walkup_only','outsideWalkup','outsideWalkupDesc'],['off','outsideOff','outsideOffDesc']];
const outsideOpts=()=>OUTSIDE.map(([v,n,d])=>[v,T(n)+' — '+T(d)]);
const outsideName=v=>{const o=OUTSIDE.find(x=>x[0]===v);return o?T(o[1]):''};
const GRAN=[['half_day','granHalfDay'],['full_day','granFullDay'],['hours','granHours'],['minutes_60','granMinutes60'],['minutes_30','granMinutes30'],['minutes_15','granMinutes15'],['minutes_5','granMinutes5'],['flexible','granFlexible']];
const granName=v=>{const g=GRAN.find(x=>x[0]===v);return g?T(g[1]):''};
const LANGS=[['','langSenderApp'],['fr'],['en'],['de'],['es'],['it']];
const langOpts=()=>LANGS.map(([v,k])=>[v,k?T(k):ENDONYMS[v]]);
const VAT_GROUPS=[['standard','vatGroupStandard'],['intermediate','vatGroupIntermediate'],['reduced','vatGroupReduced'],['super_reduced','vatGroupSuperReduced'],['zero','vatGroupZero'],['exempt','vatGroupExempt'],['not_subject','vatGroupNotSubject'],['deposit','vatGroupDeposit'],['excise','vatGroupExcise']];
// ISO weekday numbers; the short names come from the browser, in the page language.
const WD=['1','2','3','4','5','6','7'];
function weekdayName(v){try{return new Intl.DateTimeFormat(LANG,{weekday:'short',timeZone:'UTC'}).format(new Date(Date.UTC(2024,0,parseInt(v))))}catch(e){return v}}

// ------------------------------------------------------------------ parameters (WebMCP)
// What an agent may ask about and set: every scalar answer in DEFAULTS, plus
// every switch in FEATURES (those need no row: key, default, REQUIRES and
// words all come from FEATURES, REQUIRES and the catalogue). A row says how
// the answer is worded and checked: [path, label key, kind, options]. Kinds:
// text, bool, enum (options = answers => allowed values, the current
// answers when none are given), int / num (options =
// {min,max}), time, date, color, days, dates. `needs` names the switch that
// makes the question appear in the UI; `secret` hides the value from
// get_answers. A new scalar answer is a row here (or a reasoned entry in
// PARAM_EXCLUDED) — the harness fails otherwise — and no tool changes.
const PARAM_META=[
 ['name','identityName','text'],['environment','identityEnvironment','enum',()=>ENVIRONMENTS.map(x=>x[0])],
 ['country','identityCountry','enum',()=>COUNTRIES.map(c=>c[0])],['currency','identityCurrency','enum',()=>CURRENCIES.slice()],
 ['timezone','identityTimezone','enum',()=>TIMEZONES.slice()],['language','identityLanguage','enum',()=>LANGS.map(x=>x[0])],
 ['address','identityAddress','text'],['brandColor','identityBrandColor','color'],
 ['whatsapp','membersWhatsapp','text',null,{needs:'whatsappIntegration'}],
 ['weekdays','availOpenDays','days'],
 ['granularity','availGranularity','enum',(s=S)=>(on('workingHours',s)?GRAN:GRAN.filter(([v])=>v==='half_day'||v==='full_day')).map(x=>x[0])],
 ['dayStart','availDayStart','time'],['boundary','availBoundary','time'],['dayEnd','availDayEnd','time'],['closures','availClosures','dates'],
 ['halfDayHours','availHalfDayHours','num',{min:0}],['fullDayHours','availFullDayHours','num',{min:0}],
 ['deskOpacity','planDeskOpacity','int',{min:20,max:100}],
 ['horizonDays','availHorizon','enum',()=>HORIZON.map(x=>x[0])],['minDuration','availMinDuration','enum',()=>DURATIONS.map(x=>x[0])],['maxDuration','availMaxDuration','enum',()=>DURATIONS.map(x=>x[0])],
 ['policies.allowPast','availAllowPast','bool',null,{needs:'bookingPolicies'}],['policies.adminCheckout','availAdminCheckout','bool',null,{needs:'bookingPolicies'}],
 ['policies.outsideHours','availOutsideHours','enum',()=>OUTSIDE.map(x=>x[0]),{needs:'bookingPolicies'}],
 ['policies.simultaneous','availSimultaneous','int',{min:1},{needs:'bookingPolicies'}],
 ['policies.legendProfile','availLegendProfile','enum',()=>['full','simple'],{needs:'bookingPolicies'}],
 ['invites.fr','membersInvites','text'],['invites.en','membersInvites','text'],['invites.de','membersInvites','text'],['invites.es','membersInvites','text'],['invites.it','membersInvites','text'],
 ['einvoice.url','einvoiceUrl','text'],['einvoice.token','einvoiceToken','text',null,{secret:true}],['einvoice.header','einvoiceHeader','text'],['einvoice.field','einvoiceField','text'],
 ['einvoice.uatUrl','einvoiceUatUrl','text'],['einvoice.uatToken','einvoiceUatToken','text',null,{secret:true}],['einvoice.devUrl','einvoiceDevUrl','text'],['einvoice.devToken','einvoiceDevToken','text',null,{secret:true}],
 ['einvoice.customerUrl','einvoiceCustomerUrl','text'],['einvoice.customerToken','einvoiceCustomerToken','text',null,{secret:true}],['einvoice.customerHeader','einvoiceCustomerHeader','text'],['einvoice.customerField','einvoiceCustomerField','text'],
 ['vatPeriod','legalVatPeriod','enum',()=>VATPERIOD.map(x=>x[0])],
 ['landTax.option','legalOptionToTax','bool'],['landTax.date','legalOptionDate','date'],['landTax.ref','legalOptionRef','text'],['landTax.bare','legalBareLetting','bool'],['landTax.qst','legalQstNumber','text'],['landTax.quick','legalQuickMethod','bool'],
 ['freeLevel','billingFreeLevel','bool'],
 ['pay.iban','payIbanIntl','text'],['pay.qr_iban','payQrIban','text'],['pay.reference','payReference','text'],['pay.wero','payWero','text'],['pay.lydia','payLydia','text'],['pay.wise','payWise','text'],
 ['org','legalOrg','enum',()=>['association','company']],['customerCapacity','legalCustomerCapacity','enum',()=>['','business','consumer']],
 ['vatRegime','legalVatRegime','enum',()=>['not_subject','exempt','registered']],['vatExigibility','legalVatExigibility','enum',()=>VATEXIGIBILITY.map(x=>x[0])],
 ['numbering.prefix','fieldPrefix','text'],['numbering.datePart','colDate','enum',()=>NUMDATE.map(x=>x[0])],['numbering.digits','fieldDigits','int',{min:1}],
 ['numbering.reset','numReset','enum',(s=S)=>resetsFor(s)],
 ['memberNumbering.prefix','fieldPrefix','text'],['memberNumbering.digits','fieldDigits','int',{min:1}],
 ['regNumber','legalRegNumber','text'],['vatId','legalVatId','text'],['exemption','legalExemption','text'],['street','fieldStreet','text'],['postal','fieldPostal','text'],['city','fieldCity','text'],
 ['mentions.legalForm','mentionLegalForm','text'],['mentions.terms','mentionTerms','text'],['mentions.penalty','mentionPenalty','text'],['mentions.recovery','mentionRecovery','text'],['mentions.escompte','mentionEscompte','text'],['mentions.insurance','mentionInsurance','text'],['mentions.special','mentionSpecial','text'],
 ['reminders.levels','dunningLevels','int',{min:0},{needs:'dunning'}],['reminders.firstDays','dunningFirstDays','int',{min:0},{needs:'dunning'}],['reminders.betweenDays','dunningBetweenDays','int',{min:0},{needs:'dunning'}],
 ['reminders.automatic','dunningAutomatic','bool',null,{needs:'paymentReminders'}],
 ['validation.required','rolesRequired','int',{min:1}],['validation.ownerSignOff','rolesOwnerAlways','bool'],
 ['autoValidate.owner','rolesAutoOwner','bool'],['autoValidate.admin','rolesAutoAdmin','bool'],
];
// Answers the tools do not set one by one, and why. Lists of records
// (floor plan, members, tariffs, rates) and the permission matrix are
// edited in the UI; the VAT rates are offered through seedVatRates.
const PARAM_EXCLUDED={
 sites:'collection',levels:'collection',accessories:'collection',services:'collection',tiers:'collection',subLevels:'collection',packages:'collection',
 vatRates:'collection',members:'collection',perms:'collection',permsV:'internal',domains:'collection',features:'switches',
 journey:'the plain questions (#2868): one answer sets every level through its rules, which one answer at a time cannot express; the switches they tick are offered one by one',
 'mentions.register':'no question of its own in the UI (the registration number is regNumber)','landTax.facilities':'no question of its own in the UI yet','pay.paypal_me':'unlabelled in the UI','pay.bank_name':'unlabelled in the UI',
 'pay.account_number':'unlabelled in the UI','pay.bank_code':'unlabelled in the UI','pay.bic':'unlabelled in the UI',
};

// ------------------------------------------------------------------ help
// #2331 — where each answer lands. 'import': the app applies it when the
// file is imported. 'app': the import cannot carry it, so it is typed in the
// app. 'file': written into the file for your records and for this page,
// never read by the app (secrets never travel). Keyed by the answer's path;
// what is not listed is applied by the import. The review step lists every
// 'app' and 'file' answer as what remains to do in the app.
const DEST={name:'app',environment:'app',members:'app',einvoice:'file'};
const DEST_TEXT={import:['destImport','destImportHint'],app:['destApp','destAppHint'],file:['destFile','destFileHint']};
const destOf=path=>DEST[String(path||'').split('.')[0]]||'import';
// Where each answer lives in the app, and the guide section that explains it
// (an anchor id of docs/guide, which is the section's id on the guide site).
const HELP={
 identity:['helpAppIdentity','user.space.overview'],
 region:['helpAppRegion','user.workspace.settings.currency-timezone'],
 language:['helpAppLanguage','user.workspace.settings.language'],
 features:['helpAppFeatures','user.features.processes'],
 availability:['helpAppAvailability','user.workspace.availability.open-weekdays'],
 hours:['helpAppHours','user.workspace.availability.working-hours'],
 booking:['helpAppBooking','user.workspace.availability.policies'],
 limits:['helpAppLimits','user.workspace.availability.limits'],
 plan:['helpAppPlan','user.space.editor.rooms'],
 whole:['helpAppWhole','user.reserve.whole-space'],
 tags:['helpAppTags','user.badges.nfc'],
 billing:['helpAppBilling','user.money.billing.fee-bands'],
 packages:['helpAppPackages','user.money.billing.packages'],
 services:['helpAppServices','user.money.services.overview'],
 supplyClass:['helpAppServices','user.money.services.supply'],
 pay:['helpAppPay','user.money.payments.methods'],
 online:['helpAppOnline','user.money.payments.provider'],
 legal:['helpAppLegal','user.money.legal.identity'],
 vat:['helpAppVat','user.money.vat.regime'],
 einvoice:['helpAppEinvoice','user.money.einvoice.overview'],
 dunning:['helpAppDunning','user.money.reminders.rules'],
 roles:['helpAppRoles','user.roles.matrix'],
 validation:['helpAppValidation','user.validation.overview'],
 members:['helpAppMembers','user.members.list'],
 invites:['helpAppInvites','user.members.invite'],
 whatsapp:['helpAppWhatsapp','user.workspace.settings.whatsapp-group'],
 kiosk:['helpAppKiosk','user.kiosk.mode'],
 privacy:['helpAppPrivacy','user.privacy.visibility'],
 consent:['helpAppConsent','user.privacy.consent'],
 negotiations:['helpAppNegotiations','user.members.negotiation'],
 supplies:['helpAppSupplies','user.money.expense'],
 scheduled:['helpAppScheduled','user.money.expenses.schedule'],
 faces:['helpAppFaces','user.money.overview'],
 reminders_auto:['helpAppRemindersAuto','user.money.reminders.automatic'],
 documents:['helpAppDocuments','user.documents.add'],
 messages:['helpAppMessages','user.collaborate.messages'],
 calendar:['helpAppCalendar','user.reserve.calendar'],
 scopes:['helpAppScopes','user.validation.who-may'],
 template:['helpAppTemplate','user.money.reports.invoice-template'],
};
// A feature's own guide section, shown right on its row (features step + summary).
const FEATURE_HELP={calendarTab:'calendar',calendarHub:'calendar',eventsTab:'validation',moneyTab:'faces',financeFaces:'faces',
 services:'services',accessorySupplements:'services',onlinePayments:'online',invoicing:'dunning',invoicePdfTemplate:'template',
 dunning:'dunning',paymentReminders:'reminders_auto',supplyExpenses:'supplies',scheduledExpenses:'scheduled',priceNegotiations:'negotiations',
 validationScopes:'scopes',memberNotifications:'messages',membersDirectory:'whatsapp',whatsappIntegration:'whatsapp',
 documents:'documents',kioskMode:'kiosk',nfcBadges:'tags',qrBadges:'kiosk',badgeSignIn:'kiosk',kioskMemberPhotos:'kiosk',
 nfcSeatTags:'tags',spaceQrCodes:'whole',levelBooking:'whole',adminLevelAssign:'whole',bookingPolicies:'booking',
 workingHours:'availability',roleManagement:'roles',roleAssignment:'roles',coOwner:'roles',deletionRequests:'validation',
 vatManagement:'vat',vatDeclarations:'vat',einvoiceCustomerDelivery:'einvoice',memberReports:'faces',
 regionalFormats:'region',dataAccessLog:'privacy',memberDataExport:'privacy',planMemberPhotos:'plan',planObjectDelete:'plan'};
const STEP_HELP={identity:'identity',levels:'features',features:'features',availability:'availability',plan:'plan',billing:'billing',services:'services',pay:'pay',legal:'legal',roles:'validation',members:'members',summary:'features',review:'identity'};
// The guide section a ? or ⓘ opens, as [app location key, anchor]: the
// answer's own (HELP), else its feature's (FEATURE_HELP), else its step's
// (STEP_HELP).
function helpAnchorFor({step,feature,key}){const k=[key,FEATURE_HELP[feature],STEP_HELP[step]].find(x=>x&&HELP[x]);return k?HELP[k]:null}
