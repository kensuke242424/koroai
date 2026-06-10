/* fk-data.js — FreshKeep theme tokens, urgency color logic, and food data.
   Plain JS. Exposes window.FKT (theme) and window.FKD (data). */

// ─────────────────────────────────────────────────────────────
// Palettes (warm kitchen neutrals + sage green → amber/terracotta)
// ─────────────────────────────────────────────────────────────
const FK_PALETTES = {
  // option 3 (default): warm neutral, sage, terracotta
  hinoki: {
    light: {
      bg: '#f3ede2', bg2: '#fbf7f0', surface: '#fffdf8', surface2: '#f1ebdf',
      text: '#3a342b', textSec: '#8c8273', textTer: '#b3aa98',
      hair: 'rgba(70,55,30,0.09)', shadow: 'rgba(80,65,40,0.10)',
      brand: '#6f8f6a', brandInk: '#41614a', brandSoft: '#e7eedd',
      accent: '#b8604a',
    },
    dark: {
      bg: '#2b251c', bg2: '#332c22', surface: '#3c352b', surface2: '#473f33',
      text: '#f3ede2', textSec: '#c2b69b', textTer: '#948871',
      hair: 'rgba(255,243,216,0.12)', shadow: 'rgba(0,0,0,0.24)',
      brand: '#a4c098', brandInk: '#dfebd5', brandSoft: '#3a442d',
      accent: '#e69a7c',
    },
    // ナイト：案4アンバー（琥珀寄りの夕暮れ・暖色ライトを一段沈める）
    night: {
      bg: '#ddc9a6', bg2: '#e5d3b3', surface: '#efe1c7', surface2: '#e3d2b0',
      text: '#3a342b', textSec: '#7b7059', textTer: '#a4977e',
      hair: 'rgba(70,55,30,0.13)', shadow: 'rgba(80,65,40,0.16)',
      brand: '#5e7c4e', brandInk: '#3c5a40', brandSoft: '#d6dcb2',
      accent: '#bd5e36',
    },
  },
  // warmer terracotta-leaning
  clay: {
    light: {
      bg: '#f4ece2', bg2: '#fbf6ee', surface: '#fffcf6', surface2: '#f1e8da',
      text: '#3c332a', textSec: '#8e8273', textTer: '#b6aa97',
      hair: 'rgba(80,50,25,0.10)', shadow: 'rgba(90,60,35,0.11)',
      brand: '#7a9a64', brandInk: '#4a6440', brandSoft: '#e9efdc',
      accent: '#c06a3f',
    },
    dark: {
      bg: '#2c251a', bg2: '#342d21', surface: '#3d352a', surface2: '#484033',
      text: '#f4eddf', textSec: '#c3b79a', textTer: '#95896f',
      hair: 'rgba(255,240,210,0.12)', shadow: 'rgba(0,0,0,0.24)',
      brand: '#aec894', brandInk: '#e2edd3', brandSoft: '#3c4529',
      accent: '#ec9e6f',
    },
    night: {
      bg: '#ddc8a2', bg2: '#e5d2af', surface: '#f0e1c4', surface2: '#e4d1ab',
      text: '#3c332a', textSec: '#7d7159', textTer: '#a6987d',
      hair: 'rgba(80,50,25,0.14)', shadow: 'rgba(90,60,35,0.16)',
      brand: '#66834e', brandInk: '#46603c', brandSoft: '#d8dcaf',
      accent: '#c2602f',
    },
  },
};

function fkTokens(paletteKey, mode) {
  const p = FK_PALETTES[paletteKey] || FK_PALETTES.hinoki;
  const key = mode === true ? 'dark' : mode === false || mode === undefined ? 'light' : mode;
  return p[key] || p.light;
}

// ─────────────────────────────────────────────────────────────
// Urgency → warm color temperature (sage green → amber → terracotta).
// NO red. hue runs 150 (calm green, lots of time) → 34 (terracotta, today).
// ─────────────────────────────────────────────────────────────
function fkUrgency(days, dark) {
  const d = Math.max(0, Math.min(7, days));
  const hue = 34 + (d / 7) * (150 - 34); // 34 (today) … 150 (a week+)
  if (dark) {
    return {
      hue,
      pillBg: `oklch(0.43 0.06 ${hue})`,
      pillFg: `oklch(0.90 0.085 ${hue})`,
      solid:  `oklch(0.72 0.115 ${hue})`,
      glow:   `oklch(0.72 0.115 ${hue} / 0.28)`,
      track:  `oklch(0.48 0.07 ${hue})`,
    };
  }
  return {
    hue,
    pillBg: `oklch(0.935 0.045 ${hue})`,
    pillFg: `oklch(0.46 0.105 ${hue})`,
    solid:  `oklch(0.69 0.135 ${hue})`,
    glow:   `oklch(0.69 0.135 ${hue} / 0.28)`,
    track:  `oklch(0.89 0.06 ${hue})`,
  };
}

// urgency tier for sorting / labels (0 = today, higher = calmer)
function fkTier(days) {
  if (days <= 0) return 0;
  if (days === 1) return 1;
  if (days <= 3) return 2;
  if (days <= 6) return 3;
  return 4;
}

// Day labels in 3 copy tones
function fkDayLabel(days, tone) {
  if (tone === 'simple') {
    if (days <= 0) return '今日';
    return `${days}日`;
  }
  if (tone === 'cheer') {
    if (days <= 0) return 'いま食べごろ';
    if (days === 1) return 'そろそろ';
    if (days <= 3) return `あと${days}日`;
    return `ゆっくりでOK`;
  }
  // gentle (default)
  if (days <= 0) return '今日中に';
  if (days === 1) return 'あすまで';
  return `あと${days}日`;
}

// Section / encouragement copy per tone
const FK_COPY = {
  gentle: {
    homeKicker: 'おはようございます',
    eatThisWeek: '今週、食べきりたい',
    plenty: 'ゆとりあり',
    plentyNote: 'まだ慌てなくて大丈夫',
    empty: 'いまは急ぎの食材はありません。ゆっくりどうぞ。',
    ate: 'ごちそうさま！',
    tossed: '記録しました',
    heroVerb: '今日のうちに、食べきろう',
    addTitle: '何を買ってきた？',
    addHint: 'カテゴリを選ぶだけ。日付は自動でつけておくね。',
  },
  simple: {
    homeKicker: '冷蔵庫',
    eatThisWeek: '今週食べきる',
    plenty: 'ゆとり',
    plentyNote: '余裕あり',
    empty: '急ぎの食材はありません。',
    ate: '食べた',
    tossed: '捨てた',
    heroVerb: '今日中に使い切る',
    addTitle: '追加',
    addHint: 'カテゴリを選択。日付は自動。',
  },
  cheer: {
    homeKicker: 'きょうもいい日に',
    eatThisWeek: 'いま食べごろの食材',
    plenty: 'まだ平気なもの',
    plentyNote: 'のんびりでだいじょうぶ',
    empty: '急ぎはなし！上手に使えてますね。',
    ate: 'ナイス完食！',
    tossed: 'つぎは食べきろう',
    heroVerb: 'きょうが食べどき！',
    addTitle: '買ってきたものは？',
    addHint: 'タップするだけ。日付はおまかせ。',
  },
};

// ─────────────────────────────────────────────────────────────
// Food categories — quick-register presets. もち日数 auto-set per category.
// glyph = single-char icon shown in a colored circle (no emoji).
// perishable: true = 生鮮 (foregrounded). false = 保存寄り (retreats to ゆとり).
// ─────────────────────────────────────────────────────────────
const FK_CATEGORIES = [
  { id: 'fish',   name: '魚・刺身',   glyph: '魚', days: 1,  perishable: true,  color: '#5f93a2' },
  { id: 'chicken',name: '鶏肉',       glyph: '鶏', days: 2,  perishable: true,  color: '#d98a66' },
  { id: 'meat',   name: '豚・牛肉',   glyph: '肉', days: 3,  perishable: true,  color: '#c06a5a' },
  { id: 'leafy',  name: '葉物野菜',   glyph: '菜', days: 3,  perishable: true,  color: '#7fa257' },
  { id: 'veg',    name: '野菜',       glyph: '野', days: 5,  perishable: true,  color: '#8aa86e' },
  { id: 'mush',   name: 'きのこ',     glyph: '茸', days: 4,  perishable: true,  color: '#ab8d68' },
  { id: 'fruit',  name: '果物',       glyph: '果', days: 5,  perishable: true,  color: '#d6a04f' },
  { id: 'dairy',  name: '牛乳・乳製品', glyph: '乳', days: 5,  perishable: true,  color: '#c9b487' },
  { id: 'tofu',   name: '豆腐・納豆', glyph: '豆', days: 4,  perishable: true,  color: '#b3ad74' },
  { id: 'deli',   name: '惣菜・弁当', glyph: '惣', days: 1,  perishable: true,  color: '#c98a4f' },
  { id: 'bread',  name: 'パン',       glyph: 'パ', days: 3,  perishable: true,  color: '#caa06a' },
  { id: 'egg',    name: '卵',         glyph: '卵', days: 14, perishable: false, color: '#cbb06f' },
];

function fkCat(id) { return FK_CATEGORIES.find(c => c.id === id); }

// default item name suggestions per category (for onboarding seeding + add placeholder)
const FK_CAT_DEFAULT_NAME = {
  fish: '刺身', chicken: '鶏むね肉', meat: '豚こま', leafy: 'ほうれん草',
  veg: 'トマト', mush: 'しめじ', fruit: 'バナナ', dairy: '牛乳',
  tofu: '絹ごし豆腐', deli: 'お惣菜', bread: '食パン', egg: '卵',
};

// Base fridge seed (always present so home feels alive)
let _fkId = 0;
const fkNewId = () => `it_${Date.now()}_${_fkId++}`;

// Default amount-mode per category: count-friendly foods get 'count', others 'amount'
const FK_CAT_AMT_MODE = {
  fish:'amount', chicken:'amount', meat:'amount', leafy:'amount',
  veg:'amount', mush:'amount', fruit:'count', dairy:'amount',
  tofu:'count', deli:'count', bread:'count', egg:'count',
};
const FK_CAT_UNIT = {
  fish:'切', chicken:'パック', meat:'パック', leafy:'束',
  veg:'個', mush:'パック', fruit:'個', dairy:'本',
  tofu:'丁', deli:'個', bread:'枚', egg:'個',
};

function fkMakeItem(catId, name, days, amtOpts) {
  const cat = fkCat(catId);
  const mode = (amtOpts && amtOpts.amtMode) || FK_CAT_AMT_MODE[catId] || 'amount';
  const unit = (amtOpts && amtOpts.unit) || FK_CAT_UNIT[catId] || '個';
  return {
    id: fkNewId(),
    catId,
    name: name || FK_CAT_DEFAULT_NAME[catId] || cat.name,
    days: (days === undefined ? cat.days : days),
    perishable: cat.perishable,
    addedAt: Date.now(),
    // remaining-amount fields
    amtMode: mode,           // 'amount' | 'count'
    amt: (amtOpts && amtOpts.amt != null) ? amtOpts.amt : 1,  // 0..1 fraction (for amount mode)
    qty: (amtOpts && amtOpts.qty != null) ? amtOpts.qty : 1,  // current count
    qtyTotal: (amtOpts && amtOpts.qtyTotal != null) ? amtOpts.qtyTotal : 1, // initial count (for edit pips)
    unit: unit,
  };
}

function fkSeedFridge() {
  return [
    fkMakeItem('fish', '刺身（まぐろ）', 0, { amt: 0.5 }),
    fkMakeItem('chicken', '鶏むね肉', 1, { amt: 0.72 }),
    fkMakeItem('leafy', 'ほうれん草', 2, { amt: 0.3 }),
    fkMakeItem('tofu', '絹ごし豆腐', 3, { qty: 1, qtyTotal: 3 }),
    fkMakeItem('dairy', '牛乳', 4, { amt: 0.72 }),
    fkMakeItem('veg', 'ミニトマト', 5, { qty: 4, qtyTotal: 6 }),
    fkMakeItem('egg', '卵（10個）', 12, { qty: 8, qtyTotal: 10 }),
  ];
}

window.FKT = { FK_PALETTES, fkTokens, fkUrgency, fkTier, fkDayLabel, FK_COPY };
window.FKD = {
  FK_CATEGORIES, fkCat, FK_CAT_DEFAULT_NAME, FK_CAT_AMT_MODE, FK_CAT_UNIT,
  fkMakeItem, fkSeedFridge, fkNewId,
};
