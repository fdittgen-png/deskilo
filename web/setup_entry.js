// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup page's way in (#3075): the first screen asks the business
// question, so the badge legend lives with the file's explanation behind the
// header disclosure, the expert checkboxes wait for the second step, and the
// sticky bar's primary action is the next step — the export is the last
// step's. Loaded after the page's own script, whose render() calls it.
'use strict';
function renderLegend(){const box=document.getElementById('legend');box.textContent='';
 box.append(...Object.keys(DEST_TEXT).map(d=>h('span',{},h('span',{class:'dest '+d},T(DEST_TEXT[d][0])),' '+T(DEST_TEXT[d][1]))))}
// The next step ends the first screen; the whole-page view has no next.
function nextStep(){const list=applicable();return mode==='wizard'?list[list.findIndex(s=>s.id===cur)+1]:undefined}
function entryChrome(list,idx){const first=mode==='wizard'&&idx===0;
 document.getElementById('expertwrap').style.display=on('setupGuide')&&!first?'':'none';
 document.getElementById('allwrap').style.display=first?'none':'';
 const next=nextStep();document.getElementById('primary').textContent=next?T('setupNext')+' ›':'⬇ '+T('setupExportXml')}
function primaryAction(){const next=nextStep();next?go(next.id):exportChecked()}
