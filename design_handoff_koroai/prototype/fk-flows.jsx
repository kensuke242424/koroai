/* fk-flows.jsx — Add flow (quick register) + Onboarding. */

const FKcats = window.FKD.FK_CATEGORIES;

// 追加フロー：カテゴリを種類ごとにセクション分け
const FK_ADD_GROUPS = [
{ key: 'meat', label: '肉・魚介', ids: ['fish', 'chicken', 'meat'] },
{ key: 'veg', label: '野菜・きのこ', ids: ['leafy', 'veg', 'mush'] },
{ key: 'fruit', label: '果物・乳製品', ids: ['fruit', 'dairy'] },
{ key: 'soy', label: '大豆製品・卵', ids: ['tofu', 'egg'] },
{ key: 'staple', label: '主食・惣菜', ids: ['bread', 'deli'] }];

const FKmake = window.FKD.fkMakeItem;
const FKdefName = window.FKD.FK_CAT_DEFAULT_NAME;

function fkDateLabel(days) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

// big category tile
function FKCatTile({ cat, onClick, selected, dark, addMode, count = 0 }) {
  const active = selected || addMode && count > 0;
  return (
    <button onClick={onClick} style={{
      border: active ? `2px solid ${cat.color}` : '2px solid transparent',
      background: active ?
      `color-mix(in oklab, ${cat.color} 14%, var(--fk-surface))` :
      'var(--fk-surface)',
      borderRadius: 20, cursor: 'pointer', padding: '16px 8px 13px',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 9,
      fontFamily: '"M PLUS Rounded 1c", system-ui',
      boxShadow: '0 1px 3px var(--fk-shadow)', transition: 'all .15s ease',
      position: 'relative'
    }}>
      {addMode ?
      count > 0 ?
      <span style={{
        position: 'absolute', top: 7, right: 7, minWidth: 21, height: 21, borderRadius: 999,
        background: cat.color, color: '#fff', fontSize: 12.5, fontWeight: 800, padding: '0 6px',
        display: 'flex', alignItems: 'center', justifyContent: 'center', lineHeight: 1
      }}>{count}</span> :

      <span style={{
        position: 'absolute', top: 7, right: 7, width: 21, height: 21, borderRadius: 999,
        background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(70,55,30,0.07)',
        color: 'var(--fk-text-ter)', fontSize: 16, fontWeight: 700, lineHeight: 1,
        display: 'flex', alignItems: 'center', justifyContent: 'center'
      }}>＋</span> :

      selected ?
      <span style={{ position: 'absolute', top: 7, right: 7 }}><FKCheck color={cat.color} size={18} /></span> :
      null}
      <FKIcon cat={cat} size={52} dark={dark} />
      <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--fk-text)', textAlign: 'center', lineHeight: 1.2 }}>{cat.name}</span>
    </button>);

}

function fkTodayStr() {
  const d = new Date();
  return `${d.getMonth() + 1}/${d.getDate()}（${['日', '月', '火', '水', '木', '金', '土'][d.getDay()]}）`;
}

function FKStepper({ value, onChange, dark }) {
  const btn = {
    width: 44, height: 44, borderRadius: 14, border: 'none', cursor: 'pointer',
    background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(70,55,30,0.06)',
    color: 'var(--fk-text)', fontSize: 24, fontWeight: 700, lineHeight: 1,
    display: 'flex', alignItems: 'center', justifyContent: 'center'
  };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
      <button style={btn} onClick={() => onChange(Math.max(0, value - 1))}>−</button>
      <div style={{ minWidth: 92, textAlign: 'center', display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 2 }}>
        {value <= 0 ?
        <span style={{ fontSize: 22, fontWeight: 800, color: 'var(--fk-text)' }}>今日</span> :
        <React.Fragment>
            <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--fk-text-sec)' }}>あと</span>
            <span style={{ fontSize: 30, fontWeight: 800, color: 'var(--fk-text)' }}>{value}</span>
            <span style={{ fontSize: 16, fontWeight: 700, color: 'var(--fk-text-sec)' }}>日</span>
          </React.Fragment>}
      </div>
      <button style={btn} onClick={() => onChange(value + 1)}>+</button>
    </div>);

}

// 小さなカレンダーアイコン
function FKCalIcon({ size = 15, color = 'currentColor' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none">
      <rect x="2.5" y="4" width="15" height="13.5" rx="3" stroke={color} strokeWidth="1.6" />
      <path d="M2.5 8H17.5" stroke={color} strokeWidth="1.6" />
      <path d="M6.5 2.5V5M13.5 2.5V5" stroke={color} strokeWidth="1.6" strokeLinecap="round" />
    </svg>);
}

// もち日数をカレンダーで設定（日付 → 日数に変換）
function FKDatePicker({ days, onPick, dark, accent }) {
  const startOfDay = (d) => {const x = new Date(d);x.setHours(0, 0, 0, 0);return x;};
  const today = startOfDay(new Date());
  const selected = new Date(today);selected.setDate(today.getDate() + Math.max(0, days));
  const [vm, setVm] = React.useState(new Date(selected.getFullYear(), selected.getMonth(), 1));
  const y = vm.getFullYear(),m = vm.getMonth();
  const startWd = new Date(y, m, 1).getDay();
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < startWd; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(y, m, d));
  const sameDay = (a, b) => a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  const diffDays = (d) => Math.round((startOfDay(d) - today) / 86400000);
  const WD = ['日', '月', '火', '水', '木', '金', '土'];
  const navBtn = { width: 30, height: 30, borderRadius: 9, border: 'none', cursor: 'pointer', background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(70,55,30,0.06)', color: 'var(--fk-text)', fontSize: 16, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'inherit' };
  return (
    <div style={{ background: 'var(--fk-surface)', borderRadius: 16, padding: '12px 14px 13px', marginBottom: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <button style={navBtn} onClick={() => setVm(new Date(y, m - 1, 1))}>‹</button>
        <span style={{ fontSize: 14.5, fontWeight: 800, color: 'var(--fk-text)' }}>{y}年 {m + 1}月</span>
        <button style={navBtn} onClick={() => setVm(new Date(y, m + 1, 1))}>›</button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 2, marginBottom: 3 }}>
        {WD.map((w, i) => <div key={w} style={{ textAlign: 'center', fontSize: 10.5, fontWeight: 700, color: i === 0 ? 'var(--fk-accent)' : i === 6 ? '#5f93a2' : 'var(--fk-text-ter)', padding: '2px 0' }}>{w}</div>)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 2 }}>
        {cells.map((d, i) => {
          if (!d) return <div key={i} />;
          const past = diffDays(d) < 0;
          const isToday = sameDay(d, today);
          const isSel = sameDay(d, selected);
          return (
            <button key={i} disabled={past} onClick={() => onPick(diffDays(d))} style={{
              aspectRatio: '1', border: 'none', borderRadius: 10, cursor: past ? 'default' : 'pointer',
              background: isSel ? accent : 'transparent',
              color: isSel ? '#fff' : past ? 'var(--fk-text-ter)' : 'var(--fk-text)',
              opacity: past ? 0.32 : 1, fontSize: 13, fontWeight: isSel || isToday ? 800 : 600,
              fontFamily: '"M PLUS Rounded 1c", system-ui',
              boxShadow: !isSel && isToday ? 'inset 0 0 0 1.5px var(--fk-accent)' : 'none'
            }}>{d.getDate()}</button>);
        })}
      </div>
      <div style={{ textAlign: 'center', marginTop: 8, fontSize: 12, fontWeight: 700, color: 'var(--fk-text-sec)' }}>
        {days <= 0 ? '今日まで' : `${selected.getMonth() + 1}/${selected.getDate()}（${WD[selected.getDay()]}）まで・あと${days}日`}
      </div>
    </div>);
}

// もち日数行に挟む「カレンダーで日付を選ぶ」トグル
function FKCalToggle({ open, onToggle }) {
  return (
    <button onClick={onToggle} style={{
      width: '100%', border: 'none', cursor: 'pointer', borderRadius: 13,
      background: 'transparent', color: 'var(--fk-brand-ink)',
      padding: '7px 4px', marginBottom: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
      fontFamily: '"M PLUS Rounded 1c", system-ui', fontSize: 13.5, fontWeight: 800
    }}>
      <FKCalIcon size={15} /> {open ? 'カレンダーを閉じる' : 'カレンダーで日付を選ぶ'}
    </button>);
}

// ── 確認画面の各カード（名前・もち日数＋カレンダー・残量モード切替）──
function FKConfirmItem({ item, onChange, onRemove, dark, accent }) {
  const c = window.FKD.fkCat(item.catId);
  const [calOpen, setCalOpen] = React.useState(false);
  const patch = (k) => (v) => onChange({ ...item, [k]: typeof v === 'function' ? v(item[k]) : v });
  return (
    <div style={{ background: 'var(--fk-surface)', borderRadius: 16, padding: '12px 14px', marginBottom: 10, boxShadow: '0 1px 3px rgba(80,65,40,0.10)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, marginBottom: 12 }}>
        <FKIcon cat={c} size={44} dark={dark} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--fk-text-ter)' }}>{c.name}</div>
          <input value={item.name} onChange={(e) => onChange({ ...item, name: e.target.value })}
          placeholder={`${FKdefName[c.id] || c.name}（任意）`} style={{
            width: '100%', border: 'none', background: 'transparent', outline: 'none',
            fontSize: 18, fontWeight: 800, color: 'var(--fk-text)', fontFamily: '"M PLUS Rounded 1c", system-ui', padding: 0
          }} />
          <div style={{ height: 2, background: 'var(--fk-hair)', borderRadius: 2, marginTop: 3 }} />
        </div>
        <span onClick={onRemove} style={{ width: 28, height: 28, borderRadius: '50%', flexShrink: 0, background: 'rgba(70,55,30,0.06)', color: 'var(--fk-text-ter)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, cursor: 'pointer' }}>✕</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--fk-text)' }}>もち日数</span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span onClick={() => setCalOpen((o) => !o)} title="カレンダーで指定" style={{
            width: 34, height: 34, borderRadius: 11, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: calOpen ? `color-mix(in oklab, ${accent} 14%, transparent)` : 'rgba(70,55,30,0.06)'
          }}>
            <svg width="16" height="16" viewBox="0 0 20 20" fill="none"><rect x="2.5" y="4" width="15" height="13.5" rx="3" stroke={calOpen ? accent : 'var(--fk-text-sec)'} strokeWidth="1.6" /><path d="M2.5 8H17.5" stroke={calOpen ? accent : 'var(--fk-text-sec)'} strokeWidth="1.6" /><path d="M6.5 2.5V5M13.5 2.5V5" stroke={calOpen ? accent : 'var(--fk-text-sec)'} strokeWidth="1.6" strokeLinecap="round" /></svg>
          </span>
          <FKStepper value={item.days} onChange={(v) => onChange({ ...item, days: v })} dark={dark} />
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateRows: calOpen ? '1fr' : '0fr', opacity: calOpen ? 1 : 0, transition: 'grid-template-rows .3s cubic-bezier(.3,.85,.3,1), opacity .26s ease', overflow: 'hidden' }}>
        <div style={{ minHeight: 0, overflow: 'hidden', paddingTop: 10 }}>
          <FKDatePicker days={item.days} onPick={(d) => onChange({ ...item, days: d })} dark={dark} accent={accent} />
        </div>
      </div>
      <div style={{ height: 10 }} />
      <FKAmtSection amtMode={item.amtMode} setAmtMode={patch('amtMode')} frac={item.amt} setFrac={patch('amt')}
      qty={item.qty} setQty={patch('qty')} unit={item.unit} context="add" qtyTotal={item.qty} />
    </div>);
}

// ── Add sheet : 二段プッシュ（選ぶ → 確認・編集）+ カゴのカウントチップ ──
function FKAddSheet({ open, onClose, onAdd, onBatchDone, dark, tone, accent, copy }) {
  const [cart, setCart] = React.useState([]);
  const [screen, setScreen] = React.useState('select'); // 'select' | 'confirm'
  const [confirmClose, setConfirmClose] = React.useState(false);

  React.useEffect(() => {if (open) {setCart([]);setScreen('select');setConfirmClose(false);}}, [open]);

  const addOne = (c) => {
    const mode = window.FKD.FK_CAT_AMT_MODE[c.id] || 'amount';
    const unit = window.FKD.FK_CAT_UNIT[c.id] || '個';
    setCart((s) => [...s, FKmake(c.id, '', c.days, { amtMode: mode, amt: 0.72, qty: 1, qtyTotal: 1, unit })]);
  };
  const removeOneOfCat = (catId) => setCart((s) => {
    const ids = s.filter((i) => i.catId === catId).map((i) => i.id);
    if (!ids.length) return s;
    const last = Math.max(...ids);
    return s.filter((i) => i.id !== last);
  });
  const countOf = (catId) => cart.reduce((n, x) => n + (x.catId === catId ? 1 : 0), 0);
  const updateItem = (id, next) => setCart((s) => s.map((x) => x.id === id ? next : x));
  const removeItem = (id) => setCart((s) => s.filter((x) => x.id !== id));

  const grouped = (() => {
    const m = new Map();
    cart.forEach((it) => {const g = m.get(it.catId) || { catId: it.catId, count: 0, lastId: 0 };g.count++;g.lastId = Math.max(g.lastId, it.id);m.set(it.catId, g);});
    return [...m.values()].sort((a, b) => b.lastId - a.lastId);
  })();

  const sectionGroups = (() => {
    const inSet = new Set(FK_ADD_GROUPS.flatMap((g) => g.ids));
    const extras = FKcats.filter((c) => !inSet.has(c.id)).map((c) => c.id);
    return extras.length ? [...FK_ADD_GROUPS, { key: 'other', label: 'その他', ids: extras }] : FK_ADD_GROUPS;
  })();

  const commit = () => {
    cart.forEach((it) => onAdd({ ...it, name: (it.name || '').trim() || FKdefName[it.catId] || window.FKD.fkCat(it.catId).name, qtyTotal: Math.max(it.qtyTotal || it.qty, it.qty) }));
    onBatchDone && onBatchDone(cart.length);
    onClose();
  };
  const requestClose = () => {cart.length ? setConfirmClose(true) : onClose();};

  return (
    <FKSheet open={open} onClose={requestClose} dark={dark} height="88%">
      <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
        <div style={{ position: 'absolute', inset: 0, display: 'flex', width: '200%', transform: `translateX(${screen === 'confirm' ? '-50%' : '0'})`, transition: 'transform .32s cubic-bezier(.3,.8,.3,1)' }}>

          {/* ── 選ぶ ── */}
          <div style={{ width: '50%', position: 'relative', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <div style={{ padding: '10px 22px 6px', flexShrink: 0 }}>
              <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--fk-text)' }}>{copy.addTitle}</div>
              <div style={{ fontSize: 13.5, color: 'var(--fk-text-sec)', marginTop: 3, fontWeight: 600 }}>カテゴリを選んでカゴへ。最後にまとめて確認します。</div>
            </div>
            <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '2px 18px 124px' }}>
              {sectionGroups.map((g) =>
              <div key={g.key}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '14px 2px 9px' }}>
                    <span style={{ fontSize: 12.5, fontWeight: 800, color: 'var(--fk-brand-ink)', letterSpacing: 0.4 }}>{g.label}</span>
                    <span style={{ flex: 1, height: 1, background: 'var(--fk-hair)' }} />
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 11 }}>
                    {g.ids.map((id) => {const c = window.FKD.fkCat(id);return c ? <FKCatTile key={id} cat={c} dark={dark} addMode count={countOf(c.id)} onClick={() => addOne(c)} /> : null;})}
                  </div>
                </div>
              )}
            </div>
            <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, paddingBottom: 'calc(13px + env(safe-area-inset-bottom))', background: 'var(--fk-surface2)', borderTop: '1px solid var(--fk-hair)', borderRadius: '18px 18px 0 0', boxShadow: '0 -3px 14px rgba(80,65,40,0.07)' }}>
              {cart.length > 0 &&
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 18px 10px' }}>
                  <span style={{ fontSize: 16, flexShrink: 0, lineHeight: '24px' }}>🧺</span>
                  <div className="fkChipTray" style={{ display: 'flex', alignItems: 'center', gap: 7, overflowX: 'auto', flex: 1, minWidth: 0, paddingTop: 5, paddingBottom: 5 }}>
                    {grouped.map((g) => {const c = window.FKD.fkCat(g.catId);return (
                      <span key={g.catId} style={{ display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0, overflow: 'hidden', whiteSpace: 'nowrap', background: 'var(--fk-surface)', border: `1px solid ${c.color}55`, borderRadius: 999, padding: '4px 6px 4px 5px', boxShadow: '0 1px 2px rgba(80,65,40,0.10)', animation: 'fkChipIn .36s cubic-bezier(.25,.85,.3,1)' }}>
                        <span key={g.count} style={{ minWidth: 17, height: 17, borderRadius: '50%', flexShrink: 0, background: c.color, color: '#fff', fontSize: 10.5, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '0 4px', animation: 'fkPop .22s cubic-bezier(.3,1.3,.5,1)' }}>{g.count}</span>
                        <span style={{ fontSize: 12, fontWeight: 800, color: 'var(--fk-text)' }}>{c.name}</span>
                        <span onClick={() => removeOneOfCat(g.catId)} style={{ width: 17, height: 17, borderRadius: '50%', background: 'rgba(70,55,30,0.08)', color: 'var(--fk-text-sec)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, cursor: 'pointer', flexShrink: 0 }}>✕</span>
                      </span>);})}
                  </div>
                </div>
              }
              <div style={{ padding: '0 18px' }}>
                <button onClick={cart.length ? () => setScreen('confirm') : undefined} style={{
                  width: '100%', border: 'none', cursor: cart.length ? 'pointer' : 'default', borderRadius: 16, padding: '15px 0',
                  backgroundColor: cart.length ? accent : 'var(--fk-surface2)', color: cart.length ? '#fff' : 'var(--fk-text-ter)',
                  fontWeight: 800, fontSize: 16, fontFamily: '"M PLUS Rounded 1c", system-ui',
                  boxShadow: cart.length ? `0 6px 18px ${accent}59` : 'none', transition: 'color .15s ease'
                }}>確認する{cart.length ? `（${cart.length}品）` : ''}</button>
              </div>
            </div>
          </div>

          {/* ── 確認・編集 ── */}
          <div style={{ width: '50%', position: 'relative', display: 'flex', flexDirection: 'column', minHeight: 0, background: 'var(--fk-bg2)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 14px 4px', flexShrink: 0 }}>
              <span onClick={() => setScreen('select')} style={{ display: 'flex', alignItems: 'center', gap: 3, color: accent, fontSize: 14.5, fontWeight: 800, cursor: 'pointer' }}>‹ 選び直す</span>
              <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--fk-text)' }}>内容を確認</span>
              <span style={{ width: 62 }} />
            </div>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--fk-text-sec)', padding: '0 20px 6px', flexShrink: 0 }}>名前・もち日数・残量を確認して追加できます。</div>
            <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '4px 18px 104px' }}>
              {screen === 'confirm' && sectionGroups.map((g) => {
                const items = cart.filter((it) => g.ids.includes(it.catId));
                if (!items.length) return null;
                return (
                  <div key={g.key}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '10px 2px 9px' }}>
                      <span style={{ fontSize: 12, fontWeight: 800, color: 'var(--fk-brand-ink)' }}>{g.label}</span>
                      <span style={{ flex: 1, height: 1, background: 'var(--fk-hair)' }} />
                    </div>
                    {items.map((it) => <FKConfirmItem key={it.id} item={it} dark={dark} accent={accent} onChange={(n) => updateItem(it.id, n)} onRemove={() => {removeItem(it.id);if (cart.length <= 1) setScreen('select');}} />)}
                  </div>);
              })}
              <button onClick={() => setScreen('select')} style={{ width: '100%', border: '1.5px dashed var(--fk-hair)', cursor: 'pointer', borderRadius: 14, padding: '12px 0', background: 'transparent', color: 'var(--fk-text-sec)', fontWeight: 800, fontSize: 13.5, fontFamily: '"M PLUS Rounded 1c", system-ui', marginTop: 6 }}>＋ 食べものを選び直す</button>
            </div>
            <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 18px calc(13px + env(safe-area-inset-bottom))', background: 'var(--fk-surface2)', borderTop: '1px solid var(--fk-hair)', borderRadius: '18px 18px 0 0', boxShadow: '0 -3px 14px rgba(80,65,40,0.07)' }}>
              <button onClick={commit} style={{ width: '100%', border: 'none', cursor: 'pointer', borderRadius: 16, padding: '15px 0', backgroundColor: accent, color: '#fff', fontWeight: 800, fontSize: 16, fontFamily: '"M PLUS Rounded 1c", system-ui', boxShadow: `0 6px 18px ${accent}59` }}>冷蔵庫に追加（{cart.length}品）</button>
            </div>
          </div>

        </div>
      </div>

      {/* gentle confirm before discarding a non-empty cart */}
      {confirmClose &&
      <div style={{ position: 'absolute', inset: 0, zIndex: 10, display: 'flex', alignItems: 'flex-end' }}>
          <div onClick={() => setConfirmClose(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.28)', animation: 'fkScrimIn .22s ease' }} />
          <div style={{ position: 'relative', width: '100%', background: 'var(--fk-bg2)', borderRadius: '22px 22px 0 0', padding: '20px 22px calc(18px + env(safe-area-inset-bottom))', boxShadow: '0 -6px 26px rgba(20,14,6,0.22)', animation: 'fkSheetPop .3s cubic-bezier(.22,.7,.3,1)' }}>
            <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--fk-text)' }}>かごに {cart.length}品 残っています</div>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--fk-text-sec)', marginTop: 4, lineHeight: 1.5 }}>登録するとホームに追加されます。どうしますか？</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginTop: 16 }}>
              <button onClick={commit} style={{ border: 'none', cursor: 'pointer', borderRadius: 14, padding: '14px 0', fontSize: 15.5, fontWeight: 800, fontFamily: '"M PLUS Rounded 1c", system-ui', backgroundColor: accent, color: '#fff' }}>{cart.length}品を登録して閉じる</button>
              <button onClick={onClose} style={{ border: 'none', cursor: 'pointer', borderRadius: 14, padding: '12px 0', fontSize: 14.5, fontWeight: 700, fontFamily: '"M PLUS Rounded 1c", system-ui', background: 'transparent', color: 'var(--fk-text-sec)' }}>かごを空にして閉じる</button>
            </div>
          </div>
        </div>
      }
    </FKSheet>);
}

// ── Onboarding : よく無駄にしがちな食材を3つだけ ──────────────────
function FKOnboarding({ onDone, dark, accent }) {
  const [sel, setSel] = React.useState([]);
  const toggle = (id) => setSel((s) => s.includes(id) ? s.filter((x) => x !== id) : [...s, id]);
  const obCats = FKcats;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--fk-bg)' }}>
      <div style={{ flex: 1, overflowY: 'auto', padding: '70px 24px 20px' }}>
        <div style={{
          width: 60, height: 60, borderRadius: '50%', background: 'var(--fk-brand-soft)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 22
        }}>
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
            <path d="M16 27c7-3 10-8 10-14V7l-10-3-10 3v6c0 6 3 11 10 14z" fill="var(--fk-brand)" opacity="0.18" />
            <path d="M11 16l3.5 3.5L22 12" stroke="var(--fk-brand)" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--fk-text)', lineHeight: 1.35, letterSpacing: 0.3 }}>
          腐らせる前に、<br />そっとお知らせします。
        </div>
        <div style={{ fontSize: 15.5, color: 'var(--fk-text-sec)', marginTop: 14, lineHeight: 1.7, fontWeight: 600 }}>
          いま冷蔵庫にある食べものを選んでください。<br /><b style={{ color: 'var(--fk-text)' }}>いくつでもOK</b>、あとから増やせます。
        </div>

        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 11, marginTop: 26
        }}>
          {obCats.map((c) => <FKCatTile key={c.id} cat={c} dark={dark} selected={sel.includes(c.id)} onClick={() => toggle(c.id)} />)}
        </div>
      </div>

      <div style={{
        padding: '14px 24px calc(20px + env(safe-area-inset-bottom))',
        background: 'linear-gradient(to top, var(--fk-bg) 70%, transparent)'
      }}>
        <button disabled={sel.length === 0} onClick={() => onDone(sel)} style={{
          width: '100%', border: 'none', cursor: sel.length ? 'pointer' : 'default',
          borderRadius: 16, padding: '17px 0', fontSize: 17, fontWeight: 800,
          fontFamily: '"M PLUS Rounded 1c", system-ui',
          background: sel.length ? accent : 'var(--fk-surface2)',
          color: sel.length ? '#fff' : 'var(--fk-text-ter)',
          boxShadow: sel.length ? `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)` : 'none',
          transition: 'all .2s ease'
        }}>
          {sel.length === 0 ? '食べものを選んでね' : `${sel.length}品ではじめる`}
        </button>
        <div style={{ textAlign: 'center', marginTop: 10 }}>
          <button onClick={() => onDone([])} style={{
            border: 'none', background: 'transparent', cursor: 'pointer',
            color: 'var(--fk-text-ter)', fontSize: 13.5, fontWeight: 700,
            fontFamily: '"M PLUS Rounded 1c", system-ui'
          }}>スキップ</button>
        </div>
      </div>
    </div>);

}

// ── 編集シート：ホームのカードタップで名前・もち日数を調整 ────────
function FKEditSheet({ open, item, onSave, onRemove, onClose, dark, accent }) {
  const [name, setName] = React.useState('');
  const [days, setDays] = React.useState(3);
  const [amtMode, setAmtMode] = React.useState('amount');
  const [amt, setAmt] = React.useState(1);
  const [qty, setQty] = React.useState(1);
  const [qtyTotal, setQtyTotal] = React.useState(1);
  const [unit, setUnit] = React.useState('個');
  const [calOpen, setCalOpen] = React.useState(false);
  React.useEffect(() => {
    if (open && item) {
      setName(item.name);setDays(item.days);setCalOpen(false);
      setAmtMode(item.amtMode || 'amount');setAmt(item.amt != null ? item.amt : 1);
      setQty(item.qty != null ? item.qty : 1);setQtyTotal(item.qtyTotal != null ? item.qtyTotal : item.qty || 1);
      setUnit(item.unit || '個');
    }
  }, [open, item]);
  if (!item) return <FKSheet open={open} onClose={onClose} dark={dark} />;
  const cat = window.FKD.fkCat(item.catId);
  return (
    <FKSheet open={open} onClose={onClose} dark={dark}>
      <div style={{ display: 'flex', flexDirection: 'column', padding: '14px 22px 26px' }}>
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', marginBottom: 14 }}>アイテムを編集</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 15, marginBottom: 20 }}>
          <FKIcon cat={cat} size={64} dark={dark} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-ter)', marginBottom: 4 }}>{cat.name}</div>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder={cat.name} style={{
              width: '100%', border: 'none', background: 'transparent', outline: 'none',
              fontSize: 21, fontWeight: 800, color: 'var(--fk-text)',
              fontFamily: '"M PLUS Rounded 1c", system-ui', padding: 0
            }} />
            <div style={{ height: 2, background: 'var(--fk-hair)', borderRadius: 2, marginTop: 4 }} />
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, margin: '0 2px 8px' }}>
          <span style={{ width: 7, height: 7, borderRadius: 2, background: 'var(--fk-accent)' }} />
          <span style={{ fontSize: 15, fontWeight: 800, color: 'var(--fk-text)' }}>今日 {fkTodayStr()}</span>
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          background: 'var(--fk-surface)', borderRadius: 18, padding: '14px 16px', marginBottom: 10
        }}>
          <div>
            <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--fk-text)' }}>もち日数</div>
            <div style={{ fontSize: 12.5, color: 'var(--fk-text-ter)', fontWeight: 600 }}>残りを調整</div>
          </div>
          <FKStepper value={days} onChange={setDays} dark={dark} />
        </div>
        <FKCalToggle open={calOpen} onToggle={() => setCalOpen((o) => !o)} />
        {calOpen && <FKDatePicker days={days} onPick={setDays} dark={dark} accent={accent} />}
        <FKAmtSection amtMode={amtMode} setAmtMode={setAmtMode} frac={amt} setFrac={setAmt}
        qty={qty} setQty={setQty} unit={unit} context="edit" qtyTotal={qtyTotal} />
        <button onClick={() => onSave({ name: name.trim() || cat.name, days, amtMode, amt, qty, qtyTotal: Math.max(qtyTotal, qty), unit })} style={{
          border: 'none', cursor: 'pointer', borderRadius: 16, padding: '15px 0',
          background: accent, color: '#fff', fontWeight: 800, fontSize: 16.5,
          fontFamily: '"M PLUS Rounded 1c", system-ui', marginBottom: 10,
          boxShadow: `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)`
        }}>保存</button>
        <button onClick={onClose} style={{
          border: 'none', cursor: 'pointer', borderRadius: 16, padding: '12px 0',
          background: 'transparent', color: 'var(--fk-text-sec)', fontWeight: 700, fontSize: 15,
          fontFamily: '"M PLUS Rounded 1c", system-ui'
        }}>キャンセル</button>
      </div>
    </FKSheet>);

}

Object.assign(window, { FKAddSheet, FKOnboarding, FKEditSheet, fkDateLabel, FKCatTile, FKStepper });