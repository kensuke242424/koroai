/* fk-app.jsx — orchestrator: state, theme, screens, tweaks. Mounts to #root. */

const TONE_MAP = { 'やさしい': 'gentle', 'シンプル': 'simple', 'はげまし': 'cheer' };
const PAL_MAP = { 'ナチュラル': 'hinoki', 'あたたか': 'clay' };
const CONCEPT_MAP = { 'A': 'a', 'B': 'b', 'C': 'c' };

// ヘッダー見出しの言い回しパターン（トーンとは独立した軸）
const FK_HEADLINES = [
'トーンにあわせる',
'今週、食べきりたい',
'そろそろ、食べごろ',
'おいしいうちに',
'きょうの食べきり',
'冷蔵庫の主役たち'];

// 日替わり＋季節連動のタイトル（食欲をそそる・やさしい一言）
const FK_DAILY_HEADLINES = [
{ s: 'all', t: '今日は何を食べきろう' },
{ s: 'all', t: 'おいしく、むだなく' },
{ s: 'all', t: 'きょうの一皿を、大切に' },
{ s: 'all', t: '冷蔵庫と、なかよく' },
{ s: 'all', t: '食べきりは小さなごちそう' },
{ s: 'all', t: 'いただきますの前に' },
{ s: 'spring', t: '春の芽吹きを食卓に' },
{ s: 'spring', t: 'やわらかな旬、いまだけ' },
{ s: 'spring', t: 'あたらしい季節の味' },
{ s: 'summer', t: '夏野菜、いまが食べごろ' },
{ s: 'summer', t: '暑い日は、さっぱりと' },
{ s: 'summer', t: 'みずみずしい旬を食卓へ' },
{ s: 'summer', t: '冷たい一品で涼もう' },
{ s: 'autumn', t: '実りの秋、よくばりに' },
{ s: 'autumn', t: '秋の味覚、こんがりと' },
{ s: 'autumn', t: '食欲の秋、上手に' },
{ s: 'winter', t: 'あたたかい一皿で、ほっと' },
{ s: 'winter', t: '寒い日は、ことこと煮込み' },
{ s: 'winter', t: '鍋で、あたたまろう' }];

function fkSeason(m) {return m <= 2 || m === 12 ? 'winter' : m <= 5 ? 'spring' : m <= 8 ? 'summer' : 'autumn';}
function fkDailyHeadline(date, offset) {
  const pool = FK_DAILY_HEADLINES.filter((h) => h.s === 'all' || h.s === fkSeason(date.getMonth() + 1)).map((h) => h.t);
  const doy = Math.floor((date - new Date(date.getFullYear(), 0, 0)) / 86400000);
  return pool[(doy + (offset || 0)) % pool.length];
}

// 「今月救った数」の言い回しパターン（サンプルは12、レンダー時に実数へ置換）
const FK_SAVED_FMTS = [
'たべきり 12',
'食べきり 12',
'ぺろり 12',
'つかいきり 12',
'ごちそうさま 12',
'ムダなし 12',
'完食 12',
'今月 12'];

// 達成カードの一文パターン（12 はレンダー時に実数へ置換）
const FK_ACHIEVE_LINES = [
'今月、ムダなく食べきれました',
'今月、12品を使いきれました',
'上手に使いきれています',
'食品ロス、今月もゼロ',
'その調子、食べきり上手',
'今月のがんばり'];

// 達成カードのサブ一文パターン
const FK_ACHIEVE_SUBS = [
'腐らせず使いきれた食材の数です',
'期限切れにする前に食べた数',
'捨てずに済んだ食材です',
'今月の「食べきり」記録',
'ちゃんと消費できた食材',
'表示しない'];

// 案C「つづけて、こちらも」セクション見出し（top=緊急カードあり / empty=緊急なし）
const FK_CALM_LABELS = [
'まだ余裕があります',
'つづけて、こちらも',
'次に使いたい食材',
'こちらもお早めに',
'今週中に食べたい',
'まだ余裕あり'];
const FK_CALM_EMPTY_LABELS = [
'まだ余裕があります',
'今週の食材',
'今ある食材',
'ゆっくり使えます',
'今週の生鮮'];

// カウントが増えるたびにランダムで出る、励まし・褐めのメッセージ（{n}=今月の数）
const FK_PRAISE = [
'その調子、食べきり上手！',
'上手に使いきれています',
'ナイス！ムダなしキープ中',
'今月{n}品、いいペースです',
'食材を活かす達人ですね',
'おみごと、また1品すくえた',
'コツコツ続いていますね',
'冷蔵庫が喜んでいます',
'今日もきれいに使えました',
'いい習慣、育っています',
'すばらしい、{n}品達成！',
'むだなく、かしこく。さすが'];

function fkPickPraise(prev) {
  const pool = FK_PRAISE.filter((m) => m !== prev);
  return pool[Math.floor(Math.random() * pool.length)] || FK_PRAISE[0];
}


const FK_TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "concept": "C",
  "tone": "やさしい",
  "headline": "トーンにあわせる",
  "dailyTitle": true,
  "savedFmt": "食べきり 12",
  "achieveLine": "上手に使いきれています",
  "achieveSub": "今月の「食べきり」記録",
  "calmLabel": "今週の食材",
  "calmEmptyLabel": "今週の食材",
  "praiseRandom": true,
  "palette": "ナチュラル",
  "theme": "OS設定",
  "showSaved": true,
  "showRank": true,
  "showMonthly": true,
  "weeklyCard": true
} /*EDITMODE-END*/;

const LS_KEY = 'freshkeep_v1';
function loadState() {
  try {return JSON.parse(localStorage.getItem(LS_KEY)) || null;} catch {return null;}
}
function saveState(s) {
  try {localStorage.setItem(LS_KEY, JSON.stringify(s));} catch {}
}

function applyVars(el, c) {
  if (!el) return;
  el.style.setProperty('--fk-bg', c.bg);
  el.style.setProperty('--fk-bg2', c.bg2);
  el.style.setProperty('--fk-surface', c.surface);
  el.style.setProperty('--fk-surface2', c.surface2);
  el.style.setProperty('--fk-text', c.text);
  el.style.setProperty('--fk-text-sec', c.textSec);
  el.style.setProperty('--fk-text-ter', c.textTer);
  el.style.setProperty('--fk-hair', c.hair);
  el.style.setProperty('--fk-shadow', c.shadow);
  el.style.setProperty('--fk-brand', c.brand);
  el.style.setProperty('--fk-brand-ink', c.brandInk);
  el.style.setProperty('--fk-brand-soft', c.brandSoft);
  el.style.setProperty('--fk-accent', c.accent);
}

function FKApp() {
  const [t, setTweak] = useTweaks(FK_TWEAK_DEFAULTS);
  const saved = loadState();

  const [screen, setScreen] = React.useState(saved?.onboarded ? 'home' : 'onboard');
  const [items, setItems] = React.useState(saved?.items || window.FKD.fkSeedFridge());
  const [savedCount, setSavedCount] = React.useState(saved?.savedCount || 11);
  const [praiseTpl, setPraiseTpl] = React.useState(() => fkPickPraise(null));
  const [addOpen, setAddOpen] = React.useState(false);
  const [digestOpen, setDigestOpen] = React.useState(false);
  const [lockOpen, setLockOpen] = React.useState(false);
  const awayDays = saved?.lastOpened ? Math.floor((Date.now() - saved.lastOpened) / 86400000) : 0;
  const [returnOpen, setReturnOpen] = React.useState(saved?.onboarded && awayDays >= 5);
  const [reenterOpen, setReenterOpen] = React.useState(false);
  const [monthResult, setMonthResult] = React.useState(null);
  const [monthMeta, setMonthMeta] = React.useState({
    month: saved?.month ?? new Date().getMonth(),
    prevMonthCount: saved?.prevMonthCount ?? null,
    streak: saved?.streak ?? 3
  });
  // ふりかえり & 序盤の報酬
  const [reviewOpen, setReviewOpen] = React.useState(false);
  const [settingsOpen, setSettingsOpen] = React.useState(false);
  const [milestone, setMilestone] = React.useState(null);
  const [lifetime, setLifetime] = React.useState(saved?.lifetime ?? saved?.savedCount ?? 11);
  const [weeklyShown, setWeeklyShown] = React.useState(true);
  const weeklyCount = 6; // デモ：先週の食べきり数
  const [editItem, setEditItem] = React.useState(null);
  const [daysAway, setDaysAway] = React.useState(awayDays || 9);
  const [toast, setToast] = React.useState(null);
  const [scrollY, setScrollY] = React.useState(0);
  const [titlePreview, setTitlePreview] = React.useState(0);
  // テーマは OS 設定に追従（製品想定）。Tweaks でプレビュー切替も可能。
  const [osDark, setOsDark] = React.useState(
    () => typeof window !== 'undefined' && window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)').matches : false
  );
  React.useEffect(() => {
    if (!window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const h = (e) => setOsDark(e.matches);
    mq.addEventListener ? mq.addEventListener('change', h) : mq.addListener(h);
    return () => {mq.removeEventListener ? mq.removeEventListener('change', h) : mq.removeListener(h);};
  }, []);
  const rootRef = React.useRef(null);
  const toastTimer = React.useRef(null);
  const clamp01 = (x) => Math.max(0, Math.min(1, x));

  const mode = t.theme === 'ナイト' ? 'night' :
  t.theme === 'ライト' ? 'light' :
  t.theme === 'ダーク' ? 'dark' :
  osDark ? 'night' : 'light';
  const dark = mode === 'dark';
  const dim = mode === 'night';
  const palKey = PAL_MAP[t.palette] || 'hinoki';
  const tone = TONE_MAP[t.tone] || 'gentle';
  const concept = CONCEPT_MAP[t.concept] || 'a';
  const colors = window.FKT.fkTokens(palKey, mode);
  const copy = window.FKT.FK_COPY[tone];
  const accent = colors.accent;

  React.useEffect(() => {applyVars(rootRef.current, colors);}, [colors]);
  React.useEffect(() => {
    saveState({ onboarded: screen !== 'onboard', items, savedCount, lifetime, lastOpened: Date.now(),
      month: monthMeta.month, prevMonthCount: monthMeta.prevMonthCount, streak: monthMeta.streak });
  }, [screen, items, savedCount, lifetime, monthMeta]);

  // 月替わり検知（製品想定）：前回起動の月と今月が違えば、先月分のリザルトを表示
  React.useEffect(() => {
    const cur = new Date().getMonth();
    if (saved?.onboarded && saved?.month != null && saved.month !== cur && (saved.savedCount || 0) > 0) {
      setMonthResult({ month: saved.month, count: saved.savedCount,
        prevCount: saved.prevMonthCount ?? null, streak: (saved.streak || 0) + 1 });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const showToast = (kind, msg) => {
    const id = Date.now();
    setToast({ id, kind, msg });
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2400);
  };

  const onAte = (it) => {
    setItems((list) => list.filter((x) => x.id !== it.id));
    const n = savedCount + 1;
    setSavedCount(n);
    // 通算（lifetime）を進め、節目を跨いだら序盤の祝祭を出す
    const lifeNext = lifetime + 1;
    setLifetime(lifeNext);
    const crossed = window.fkCrossedMilestone(lifetime, lifeNext);
    if (crossed) setTimeout(() => setMilestone(crossed), 540);
    if (t.praiseRandom !== false) setPraiseTpl((prev) => fkPickPraise(prev));
    const msgs = {
      gentle: `${copy.ate} 今月 ${n} 品を使いきれました`,
      simple: `${copy.ate}（今月 ${n}）`,
      cheer: `${copy.ate} 今月${n}品め、その調子！`
    };
    showToast('ate', msgs[tone]);
  };
  const onToss = (it) => {
    setItems((list) => list.filter((x) => x.id !== it.id));
    showToast('toss', copy.tossed);
  };
  const onAdd = (item) => setItems((list) => [...list, item]);
  const onEdit = (it) => setEditItem(it);
  const onEditSave = (patch) => {
    setItems((list) => list.map((x) => x.id === editItem.id ? { ...x, ...patch } : x));
    setEditItem(null);
    showToast('ate', '更新しました');
  };

  const onboardDone = (catIds) => {
    if (!catIds || catIds.length === 0) {
      // スキップ：空の冷蔵庫でホームへ（空状態を見せる）
      setItems([]);
      setScreen('home');
      return;
    }
    let next = window.FKD.fkSeedFridge();
    catIds.forEach((cid, i) => {
      const nm = window.FKD.FK_CAT_DEFAULT_NAME[cid];
      next.push(window.FKD.fkMakeItem(cid, nm, window.FKD.fkCat(cid).days));
    });
    setItems(next);
    setScreen('home');
  };

  const replayOnboarding = () => {setScreen('onboard');};
  const onReset = () => {setItems([]);setReturnOpen(false);showToast('toss', 'リセットしました。ゆっくり始めましょう');};
  const onReenter = () => {setReturnOpen(false);setReenterOpen(true);};
  const onKeep = () => setReturnOpen(false);
  const onReenterConfirm = (sel) => {
    setItems(window.fkReenterItems(sel));
    setReenterOpen(false);
    showToast('ate', `${sel.length}品で再開。おかえりなさい`);
  };
  const demoReturn = () => {setDaysAway(9);setReturnOpen(true);};

  // リザルトの「来月をはじめる」：カウントをゼロに戻し、先月分を記録して新しい月へ
  const startNewMonth = () => {
    const c = monthResult ? monthResult.count : savedCount;
    const st = monthResult ? monthResult.streak : monthMeta.streak;
    setMonthMeta({ month: new Date().getMonth(), prevMonthCount: c, streak: st });
    setSavedCount(0);
    setMonthResult(null);
    showToast('ate', '今月もはじめましょう。いいペースで');
  };
  // デモ用：いまのカウントを先月の結果として表示
  const demoMonthResult = () => {
    const lastMonth = (new Date().getMonth() + 11) % 12;
    setMonthResult({ month: lastMonth, count: savedCount,
      prevCount: Math.max(0, savedCount - 4), streak: monthMeta.streak });
  };
  // デモ：新規ユーザー（序盤）を再現して、最初の食べきり体験を見せる
  const demoNewUser = () => {
    setLifetime(0);setSavedCount(0);setItems(window.FKD.fkSeedFridge());
    setWeeklyShown(false);setReviewOpen(false);setMilestone(null);
    showToast('ate', '序盤の状態にしました。最初の一品を「食べた」してみて');
  };

  const { hero, plenty } = window.fkSplit(items);
  const HomeComp = concept === 'b' ? window.FKHomeB : concept === 'c' ? window.FKHomeC : window.FKHomeA;
  const today = new Date();
  const headlineText = t.dailyTitle !== false && (!t.headline || t.headline === 'トーンにあわせる') ?
  fkDailyHeadline(today, titlePreview) :
  t.headline && t.headline !== 'トーンにあわせる' ? t.headline : copy.eatThisWeek;
  // scroll-linked header collapse: 大タイトル→ナビバーの小タイトルへ、救った数ピルは達成カードが流れた後に
  const titleP = clamp01((scrollY - 26) / 34); // 26–60px で小タイトルへ
  const pillP = t.showSaved ? clamp01((scrollY - 172) / 40) : 0; // 達成カードが隠れてから
  const savedLabel = (t.savedFmt || 'ムダなし 12').replaceAll('12', String(savedCount));

  return (
    <div ref={rootRef} style={{
      minHeight: '100vh', width: '100%', display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', gap: 16, padding: '24px 0',
      background: dark ? '#1e1a13' : dim ? '#cabda2' : '#e8e1d4',
      fontFamily: '"M PLUS Rounded 1c", system-ui, sans-serif',
      transition: 'background .3s ease'
    }}>
      <IOSDevice dark={dark}>
        <div style={{
          position: 'relative', height: '100%', background: 'var(--fk-bg)',
          display: 'flex', flexDirection: 'column', overflow: 'hidden'
        }}>
          {screen === 'onboard' ?
          <FKOnboarding onDone={onboardDone} dark={dark} accent={accent} /> :

          <React.Fragment>
              {/* compact nav bar — always present, title fades in on scroll */}
              <div style={{
              flexShrink: 0, padding: '52px 16px 8px 20px', background: 'var(--fk-bg)',
              position: 'relative', zIndex: 50,
              borderBottom: `1px solid ${titleP > 0.6 ? 'var(--fk-hair)' : 'transparent'}`,
              transition: 'border-color .2s ease'
            }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 34, gap: 10 }}>
                  <div style={{ position: 'relative', flex: 1, minWidth: 0, height: 24 }}>
                    <span style={{
                    position: 'absolute', left: 0, top: 2, fontSize: 14, fontWeight: 700, color: 'var(--fk-text-sec)',
                    whiteSpace: 'nowrap', opacity: clamp01(1 - titleP * 1.4),
                    transform: `translateY(${titleP * -6}px)`, transition: 'opacity .1s linear', pointerEvents: 'none'
                  }}>{copy.homeKicker}</span>
                    <span style={{
                    position: 'absolute', left: 0, top: 0, fontSize: 17, fontWeight: 800, color: 'var(--fk-text)', letterSpacing: 0.2,
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '100%',
                    opacity: titleP, transform: `translateY(${(1 - titleP) * 7}px)`,
                    transition: 'opacity .1s linear', pointerEvents: 'none'
                  }}>{headlineText}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                    {/* 設定ボタン（常設） */}
                    <button onClick={() => setSettingsOpen(true)} aria-label="設定" style={{
                      width: 34, height: 34, borderRadius: '50%', border: 'none', cursor: 'pointer',
                      background: 'var(--fk-surface2)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: 'var(--fk-text-sec)', flexShrink: 0
                    }}>
                      <svg width="18" height="18" viewBox="0 0 20 20" fill="none">
                        <circle cx="10" cy="10" r="2.5" stroke="currentColor" strokeWidth="1.8" />
                        <path d="M10 1.5v2M10 16.5v2M1.5 10h2M16.5 10h2M4.1 4.1l1.4 1.4M14.5 14.5l1.4 1.4M15.9 4.1l-1.4 1.4M5.5 14.5l-1.4 1.4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>

              {/* body */}
              <div
              onScroll={(e) => {const y = e.target.scrollTop;setScrollY((p) => Math.abs(p - y) > 1 ? y : p);}}
              style={{ flex: 1, overflowY: 'auto', padding: '0 0 130px' }}>

                {/* large title (greeting + headline) — scrolls away, freeing space */}
                <div style={{
                padding: '6px 20px 10px',
                opacity: clamp01(1 - titleP * 1.15),
                transform: `scale(${1 - titleP * 0.04})`, transformOrigin: 'left top'
              }}>
                  <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--fk-text)', letterSpacing: 0.3 }}>
                    {headlineText}
                  </div>
                </div>

                {/* meta row — STICKY, always visible: 日付・生鮮N品・今朝のまとめ */}
                <div style={{
                position: 'sticky', top: 0, zIndex: 20, background: 'var(--fk-bg)',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '8px 20px 10px',
                borderBottom: `1px solid ${scrollY > 64 ? 'var(--fk-hair)' : 'transparent'}`,
                transition: 'border-color .2s ease'
              }}>
                  <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-ter)' }}>
                    {today.getMonth() + 1}月{today.getDate()}日（{['日', '月', '火', '水', '木', '金', '土'][today.getDay()]}）・冷蔵庫に{hero.length + plenty.length}品
                  </span>
                  <button onClick={() => setDigestOpen(true)} style={{
                  border: 'none', cursor: 'pointer', borderRadius: 999,
                  padding: '5px 12px 5px 10px', display: 'flex', alignItems: 'center', gap: 6,
                  background: 'var(--fk-brand-soft)', color: 'var(--fk-brand-ink)',
                  fontFamily: '"M PLUS Rounded 1c", system-ui', fontSize: 12.5, fontWeight: 800
                }}>
                    <span style={{ position: 'relative', display: 'inline-flex' }}>
                      <svg width="14" height="14" viewBox="0 0 20 20"><circle cx="10" cy="10" r="4" fill="currentColor" /><g stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"><path d="M10 2v2M10 16v2M2 10h2M16 10h2M4.5 4.5l1.4 1.4M14.1 14.1l1.4 1.4M15.5 4.5l-1.4 1.4M5.9 14.1l-1.4 1.4" /></g></svg>
                      {hero.filter((it) => it.days <= 0).length > 0 &&
                    <span style={{ position: 'absolute', top: -2, right: -2, width: 7, height: 7, borderRadius: 999, background: accent, boxShadow: '0 0 0 1.5px var(--fk-brand-soft)' }} />
                    }
                    </span>
                    今朝のまとめ
                  </button>
                </div>

                {/* scrolling content */}
                <div style={{ padding: '14px 16px 0' }}>
                {items.length === 0 ?
                <FKEmptyFridge tone={tone} dark={dark} accent={accent} onAdd={() => setAddOpen(true)} /> :
                <React.Fragment>
                {t.showSaved && hero.length > 0 &&
                  <div onClick={() => setReviewOpen(true)} style={{
                    display: 'flex', alignItems: 'center', gap: 15, marginBottom: 16, cursor: 'pointer',
                    padding: '15px 18px', borderRadius: 20,
                    background: 'linear-gradient(150deg, var(--fk-brand-soft), var(--fk-surface))',
                    border: '1px solid var(--fk-hair)'
                  }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 2, lineHeight: 1, color: 'var(--fk-brand-ink)' }}>
                    <FKCountUp value={savedCount} accent={accent} style={{ fontSize: 38, fontWeight: 800, letterSpacing: 0.5 }} />
                    <span style={{ fontSize: 16, fontWeight: 800 }}>品</span>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--fk-text)', display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span key={t.praiseRandom !== false ? praiseTpl : t.achieveLine} style={{ animation: 'fkPraiseIn .32s ease' }}>
                        {(t.praiseRandom !== false ? praiseTpl : t.achieveLine || '上手に使いきれています').replaceAll('{n}', String(savedCount)).replaceAll('12', String(savedCount))}
                      </span> <FKLeaf size={16} />
                    </div>
                    {(t.achieveSub === undefined ? '今月の「食べきり」記録' : t.achieveSub) !== '表示しない' &&
                      <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-sec)', marginTop: 2 }}>
                      {(t.achieveSub === undefined ? '今月の「食べきり」記録' : t.achieveSub).replaceAll('12', String(savedCount))}
                    </div>
                      }
                  </div>
                  <FKChevron color="var(--fk-brand-ink)" />
                </div>
                  }
                <HomeComp hero={hero} plenty={plenty} onAte={onAte} onToss={onToss} onEdit={onEdit}
                  dark={dark} tone={tone} accent={accent} copy={copy}
                  labels={{ calm: t.calmLabel || '今週の食材', calmEmpty: t.calmEmptyLabel || '今週の食材' }} />
                </React.Fragment>
                }
                </div>
              </div>

              {/* FAB */}
              <button onClick={() => setAddOpen(true)} aria-label="追加" style={{
              position: 'absolute', bottom: 30, left: '50%', transform: 'translateX(-50%)',
              width: 66, height: 66, borderRadius: '50%', border: 'none', cursor: 'pointer', zIndex: 120,
              background: accent, color: '#fff',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: `0 8px 22px color-mix(in oklab, ${accent} 45%, transparent), 0 2px 6px rgba(0,0,0,0.2)`
            }}>
                <FKPlus color="#fff" size={30} />
              </button>

              <FKAddSheet open={addOpen} onClose={() => setAddOpen(false)} onAdd={onAdd}
            onBatchDone={(n) => n && showToast('ate', n + '品を追加しました')}
            dark={dark} tone={tone} accent={accent} copy={copy} />
              <FKSheet open={digestOpen} onClose={() => setDigestOpen(false)} dark={dark}>
                <FKDigest items={items} dark={dark} tone={tone} accent={accent}
              onCook={() => setDigestOpen(false)} onClose={() => setDigestOpen(false)} />
              </FKSheet>
              {lockOpen &&
            <FKLockScreen items={items} dark={dark} tone={tone} accent={accent}
            onOpen={() => {setLockOpen(false);setDigestOpen(true);}}
            onClose={() => setLockOpen(false)} />
            }
              <FKReenterSheet open={reenterOpen} onClose={() => setReenterOpen(false)}
            onConfirm={onReenterConfirm} dark={dark} accent={accent} />
              <FKEditSheet open={!!editItem} item={editItem} onSave={onEditSave}
            onClose={() => setEditItem(null)} dark={dark} accent={accent} />
              {returnOpen &&
            <FKReturn daysAway={daysAway} dark={dark} accent={accent} tone={tone}
            onReset={onReset} onReenter={onReenter} onKeep={onKeep} />
            }
              {monthResult && t.showMonthly !== false &&
            <FKMonthResult result={monthResult} dark={dark} accent={accent} tone={tone}
            showRank={t.showRank !== false} onStart={startNewMonth} />
            }
              {settingsOpen &&
            <FKSettings dark={dark} accent={accent}
              tone={t.tone} theme={t.theme || 'OS設定'} palette={t.palette || 'ナチュラル'}
              showSaved={t.showSaved} showMonthly={t.showMonthly !== false}
              onChangeSetting={(k, v) => setTweak(k, v)}
              onReset={() => { setItems([]); setSavedCount(0); setLifetime(0); }}
              onReplayOnboarding={() => { setSettingsOpen(false); setScreen('onboard'); }}
              onClose={() => setSettingsOpen(false)} />
            }
              {reviewOpen &&
            <FKReview savedCount={savedCount} lifetime={lifetime} streak={monthMeta.streak}
            weeklyCount={weeklyCount} showWeekly={t.weeklyCard !== false}
            dark={dark} accent={accent} tone={tone} onClose={() => setReviewOpen(false)} />
            }
              {milestone &&
            <FKMilestoneCelebrate milestone={milestone} dark={dark} accent={accent} tone={tone}
            onClose={() => setMilestone(null)} />
            }
              <FKToast toast={toast} accent={accent} />
            </React.Fragment>
          }
        </div>
      </IOSDevice>

      <TweaksPanel>
        <TweakSection label="レイアウト" />
        <TweakRadio label="ホーム案" value={t.concept} options={['A', 'B', 'C']}
        onChange={(v) => setTweak('concept', v)} />
        {t.concept === 'C' &&
        <TweakSelect label="続く食材の見出し（緊急あり）" value={t.calmLabel || '今週の食材'} options={FK_CALM_LABELS}
        onChange={(v) => setTweak('calmLabel', v)} />}
        {t.concept === 'C' &&
        <TweakSelect label="続く食材の見出し（緊急なし）" value={t.calmEmptyLabel || '今週の食材'} options={FK_CALM_EMPTY_LABELS}
        onChange={(v) => setTweak('calmEmptyLabel', v)} />}
        <TweakSection label="トーン & 配色" />
        <TweakRadio label="文面トーン" value={t.tone} options={['やさしい', 'シンプル', 'はげまし']}
        onChange={(v) => setTweak('tone', v)} />
        <TweakSelect label="ヘッダー文言" value={t.headline || 'トーンにあわせる'} options={FK_HEADLINES}
        onChange={(v) => setTweak('headline', v)} />
        <TweakToggle label="タイトルを日替わりに（季節連動）" value={t.dailyTitle !== false} onChange={(v) => setTweak('dailyTitle', v)} />
        {t.dailyTitle !== false && (!t.headline || t.headline === 'トーンにあわせる') &&
        <TweakButton label="別の日の文言を見る" onClick={() => setTitlePreview((p) => p + 1)} />}
        <div style={{ fontSize: 11.5, color: 'var(--tw-muted, #8a8a8a)', padding: '2px 2px 6px', lineHeight: 1.5 }}>
          日替わりは「ヘッダー文言＝トーンにあわせる」の時に有効。特定の文言を選ぶと固定されます。
        </div>
        <TweakRadio label="パレット" value={t.palette} options={['ナチュラル', 'あたたか']}
        onChange={(v) => setTweak('palette', v)} />
        <TweakRadio label="テーマ" value={t.theme || 'OS設定'} options={['OS設定', 'ライト', 'ナイト']}
        onChange={(v) => setTweak('theme', v)} />
        <div style={{ fontSize: 11.5, color: 'var(--tw-muted, #8a8a8a)', padding: '2px 2px 6px', lineHeight: 1.5 }}>
          ナイト＝暖色ライトを一段沈めた夕暮れ色。OS設定がダークの端末では自動でナイトになります。
        </div>
        <TweakToggle label="「今月救った数」を表示" value={t.showSaved} onChange={(v) => setTweak('showSaved', v)} />
        {t.showSaved &&
        <TweakSelect label="救った数の表現" value={t.savedFmt || '今月 12'} options={FK_SAVED_FMTS}
        onChange={(v) => setTweak('savedFmt', v)} />}
        {t.showSaved &&
        <TweakToggle label="達成メッセージをランダムに" value={t.praiseRandom !== false} onChange={(v) => setTweak('praiseRandom', v)} />}
        {t.showSaved && t.praiseRandom === false &&
        <TweakSelect label="達成カードの文言" value={t.achieveLine || '上手に使いきれています'} options={FK_ACHIEVE_LINES}
        onChange={(v) => setTweak('achieveLine', v)} />}
        {t.showSaved &&
        <TweakSelect label="達成カードのサブ文" value={t.achieveSub === undefined ? '今月の「食べきり」記録' : t.achieveSub} options={FK_ACHIEVE_SUBS}
        onChange={(v) => setTweak('achieveSub', v)} />}
        <TweakToggle label="月替わりリザルトに称号を表示" value={t.showRank !== false} onChange={(v) => setTweak('showRank', v)} />
        <TweakToggle label="ふりかえり画面に週次サマリーを表示" value={t.weeklyCard !== false} onChange={(v) => setTweak('weeklyCard', v)} />
        <TweakSection label="デモ" />
        <TweakButton label="ふりかえり画面を見る" onClick={() => setReviewOpen(true)} />
        <TweakButton label="「はじめての食べきり」演出" onClick={() => setMilestone(window.FK_MILESTONES[0])} />
        <TweakButton label="新規ユーザー（序盤）を再現" onClick={demoNewUser} />
        <TweakButton label="月替わりリザルトを見る" onClick={demoMonthResult} />
        <TweakButton label="今朝の通知（ロック画面）を見る" onClick={() => setLockOpen(true)} />
        <TweakButton label="離脱から戻る（復帰画面）を見る" onClick={demoReturn} />
        <TweakButton label="オンボーディングを見る" onClick={replayOnboarding} />
        <TweakButton label="空の冷蔵庫を見る" onClick={() => {setItems([]);}} />
        <TweakButton label="冷蔵庫をリセット" onClick={() => {setItems(window.FKD.fkSeedFridge());setSavedCount(11);}} />
      </TweaksPanel>
    </div>);

}

ReactDOM.createRoot(document.getElementById('root')).render(<FKApp />);