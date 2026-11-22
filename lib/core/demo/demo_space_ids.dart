// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 — the ids of the Demo's spaces, apart from their seed data.
//
// The demo link, the setup card and the entry flow only need to NAME a
// space; the seed that fills it is part of the Demo's deferred library and
// must not be pulled into the first download by a constant.
const demoFirstSpaceId = 'ws-1';
const demoSecondSpaceId = 'ws-2';
const demoLondonSpaceId = 'ws-3';
const demoNewYorkSpaceId = 'ws-4';
const demoZurichSpaceId = 'ws-5';
const demoMilanSpaceId = 'ws-6';

/// #3863 — the practice: a business without places.
const demoPracticeSpaceId = 'ws-7';

/// #4005 — the house abroad the Demo adds: dormant until the visitor adds
/// it from Settings › Organisation.
const demoHouseSpaceId = 'ws-9';

/// #4168 -- Kessler Conseil, a freelancer's business: no places, owned by Bruno.
const demoFreelancerSpaceId = 'ws-10';

/// #4365 -- the Épicerie du Marché, a shop: no places to book, owned by Bruno, keeping stock.
const demoShopSpaceId = 'ws-11';
