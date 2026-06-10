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
  const startOfDay = (d) => { const x = new Date(d); x.setHours(0, 0, 0, 0); return x; };
  const today = startOfDay(new Date());
  const selected = new Date(today); selected.setDate(today.getDate() + Math.max(0, days));
  const [vm, setVm] = React.useState(new Date(selected.getFullYear(), selected.getMonth(), 1));
  const y = vm.getFullYear(), m = vm.getMonth();
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

// ── Add sheet : C+E + 登録詳細 — タイルタップで詳細→かごに追加 / リスト行タップで編集 ──
function FKAddSheet({ open, onClose, onAdd, onBatchDone, dark, tone, accent, copy }) {
  const [cart, setCart] = React.useState([]);
  const [expanded, setExpanded] = React.useState(false);
  const [confirmClose, setConfirmClose] = React.useState(false);
  const [view, setView] = React.useState('grid'); // 'grid' | 'detail'
  const [cat, setCat] = React.useState(null);
  const [name, setName] = React.useState('');
  const [days, setDays] = React.useState(3);
  const [amtMode, setAmtMode] = React.useState('amount');
  const [amt, setAmt] = React.useState(1);
  const [qty, setQty] = React.useState(5);
  const [unit, setUnit] = React.useState('個');
  const [editingId, setEditingId] = React.useState(null);
  const [calOpen, setCalOpen] = React.useState(false);

  React.useEffect(() => {if (open) {setCart([]);setExpanded(false);setConfirmClose(false);setView('grid');setEditingId(null);}}, [open]);

  const openAdd = (c) => {
    setEditingId(null);setCat(c);setName('');setDays(c.days);setCalOpen(false);
    const m = window.FKD.FK_CAT_AMT_MODE[c.id] || 'amount';
    setAmtMode(m);setAmt(1);setQty(5);setUnit(window.FKD.FK_CAT_UNIT[c.id] || '個');
    setView('detail');
  };
  const openEdit = (it) => {
    setEditingId(it.id);setCat(window.FKD.fkCat(it.catId));setName(it.name);setDays(it.days);setCalOpen(false);
    setAmtMode(it.amtMode || 'amount');setAmt(it.amt != null ? it.amt : 1);
    setQty(it.qty != null ? it.qty : 5);setUnit(it.unit || '個');
    setView('detail');
  };
  const saveDetail = () => {
    const nm = name.trim() || FKdefName[cat.id] || cat.name;
    if (editingId) {
      setCart((s) => s.map((x) => x.id === editingId ? { ...x, name: nm, days, amtMode, amt, qty, qtyTotal: qty, unit } : x));
    } else {
      setCart((s) => [...s, FKmake(cat.id, nm, days, { amtMode, amt, qty, qtyTotal: qty, unit })]);
    }
    setView('grid');
  };
  const deleteEditing = () => {setCart((s) => s.filter((x) => x.id !== editingId));setView('grid');};
  const removeRow = (id) => setCart((s) => s.filter((x) => x.id !== id));
  const countOf = (catId) => cart.reduce((n, x) => n + (x.catId === catId ? 1 : 0), 0);

  const commit = () => {
    cart.forEach((it) => onAdd(it));
    onBatchDone && onBatchDone(cart.length);
    onClose();
  };
  const requestClose = () => {cart.length ? setConfirmClose(true) : onClose();};

  return (
    <FKSheet open={open} onClose={requestClose} dark={dark} height="84%">
      {/* detail overlay — slides up OVER the grid; the cart list stays mounted underneath */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 8, pointerEvents: view === 'detail' ? 'auto' : 'none' }}>
        <div onClick={() => setView('grid')} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.30)', opacity: view === 'detail' ? 1 : 0, transition: 'opacity .26s ease' }} />
        <div style={{
          position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '94%', overflowY: 'auto',
          background: 'var(--fk-bg2)', borderRadius: '24px 24px 0 0', boxShadow: '0 -8px 30px rgba(20,14,6,0.28)',
          transform: view === 'detail' ? 'translateY(0)' : 'translateY(112%)',
          transition: 'transform .32s cubic-bezier(.22,.7,.3,1)'
        }}>
      {cat &&
          <div style={{ display: 'flex', flexDirection: 'column', padding: '20px 22px 24px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 15, marginBottom: 20 }}>
            <FKIcon cat={cat} size={64} dark={dark} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-ter)', marginBottom: 4 }}>{cat.name}</div>
              <input value={name} onChange={(e) => setName(e.target.value)}
                placeholder={`${FKdefName[cat.id]}（名前は任意）`} style={{
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
              <div style={{ fontSize: 12.5, color: 'var(--fk-text-ter)', fontWeight: 600 }}>必要なら調整</div>
            </div>
            <FKStepper value={days} onChange={setDays} dark={dark} />
          </div>
          <FKCalToggle open={calOpen} onToggle={() => setCalOpen((o) => !o)} />
          {calOpen && <FKDatePicker days={days} onPick={setDays} dark={dark} accent={accent} />}

          <div style={{ height: 6 }} />
          <FKAmtSection amtMode={amtMode} setAmtMode={setAmtMode} frac={amt} setFrac={setAmt}
            qty={qty} setQty={setQty} unit={unit} context="add" qtyTotal={qty} />

          <div style={{ height: 8 }} />
          <button onClick={saveDetail} style={{
              border: 'none', cursor: 'pointer', borderRadius: 16, padding: '16px 0',
              backgroundColor: accent, color: '#fff', fontWeight: 800, fontSize: 17,
              fontFamily: '"M PLUS Rounded 1c", system-ui', marginBottom: 10,
              boxShadow: `0 6px 18px ${accent}59`
            }}>{editingId ? '更新する' : 'かごに追加'}</button>
          <button onClick={editingId ? deleteEditing : () => setView('grid')} style={{
              border: 'none', cursor: 'pointer', borderRadius: 16, padding: '13px 0',
              background: 'transparent', color: editingId ? 'var(--fk-accent)' : 'var(--fk-text-sec)', fontWeight: 700, fontSize: 15,
              fontFamily: '"M PLUS Rounded 1c", system-ui'
            }}>{editingId ? 'かごから削除' : 'やめる'}</button>
        </div>
          }
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0 }}>
        {/* header */}
        <div style={{ padding: '10px 22px 6px', flexShrink: 0 }}>
          <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--fk-text)' }}>{copy.addTitle}</div>
          <div style={{ fontSize: 13.5, color: 'var(--fk-text-sec)', marginTop: 3, fontWeight: 600 }}>
            タイルを選ぶと登録画面へ。かごに溜めて、最後にまとめて登録。
          </div>
        </div>

        {/* cart counter + expandable list (C) — shown from 0 items */}
        <div style={{ flexShrink: 0, padding: '6px 18px 0' }}>
            <button onClick={() => cart.length && setExpanded((e) => !e)} style={{
            width: '100%', border: 'none', cursor: cart.length ? 'pointer' : 'default', borderRadius: 13,
            background: 'var(--fk-brand-soft)', color: 'var(--fk-brand-ink)',
            padding: '9px 14px', display: 'flex', alignItems: 'center', gap: 8, whiteSpace: 'nowrap',
            fontFamily: '"M PLUS Rounded 1c", system-ui', fontSize: 13.5, fontWeight: 800
          }}>
              <FKLeaf size={15} /> かごに {cart.length}品
              {cart.length > 0 &&
            <span style={{ marginLeft: 'auto', fontSize: 12, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap' }}>
                {expanded ? '折りたたむ' : '一覧'}
                <svg width="11" height="11" viewBox="0 0 12 12" style={{ transform: expanded ? 'rotate(-90deg)' : 'rotate(90deg)', transition: 'transform .2s' }}>
                  <path d="M3 1l5 5-5 5" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>
            }
              {cart.length === 0 &&
            <span style={{ marginLeft: 'auto', fontSize: 12, fontWeight: 700, color: 'var(--fk-brand-ink)', opacity: 0.6 }}>タイルを選んで追加</span>
            }
            </button>
            {expanded &&
          <div style={{ maxHeight: 168, overflowY: 'auto', marginTop: 7, display: 'flex', flexDirection: 'column', gap: 7 }}>
                {cart.map((it) => {
              const c = window.FKD.fkCat(it.catId);
              const u = window.FKT.fkUrgency(it.days, dark);
              return (
                <div key={it.id} onClick={() => openEdit(it)} style={{
                  display: 'flex', alignItems: 'center', gap: 9, padding: '8px 10px', cursor: 'pointer',
                  background: 'var(--fk-surface)', borderRadius: 13
                }}>
                      <span style={{
                    width: 26, height: 26, borderRadius: '50%', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 12, fontWeight: 800, background: `color-mix(in oklab, ${c.color} 22%, transparent)`,
                    color: `color-mix(in oklab, ${c.color} 78%, #4a3f2c)`
                  }}>{c.glyph}</span>
                      <span style={{ flex: 1, minWidth: 0, fontSize: 14.5, fontWeight: 700, color: 'var(--fk-text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.name}</span>
                      <span style={{
                    fontSize: 12.5, fontWeight: 800, color: u.pillFg, background: u.pillBg,
                    borderRadius: 999, padding: '3px 9px', flexShrink: 0
                  }}>{it.days <= 0 ? '今日' : 'あと' + it.days + '日'}</span>
                      <svg width="8" height="13" viewBox="0 0 8 14" style={{ flexShrink: 0, opacity: 0.5 }}>
                        <path d="M1 1l6 6-6 6" stroke="var(--fk-text-ter)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                      <button onClick={(e) => {e.stopPropagation();removeRow(it.id);}} aria-label="取り消し" style={{
                    width: 24, height: 24, borderRadius: 999, border: 'none', cursor: 'pointer', flexShrink: 0,
                    background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(70,55,30,0.07)',
                    color: 'var(--fk-text-sec)', fontSize: 11, lineHeight: 1,
                    display: 'flex', alignItems: 'center', justifyContent: 'center'
                  }}>✕</button>
                    </div>);

            })}
              </div>
          }
          </div>

        {/* category grid — 種類ごとにセクション分け */}
        <div style={{
          padding: '2px 18px 18px', overflowY: 'auto', flex: 1, minHeight: 0
        }}>
          {(() => {
            const grouped = new Set(FK_ADD_GROUPS.flatMap((g) => g.ids));
            const extras = FKcats.filter((c) => !grouped.has(c.id)).map((c) => c.id);
            const groups = extras.length ? [...FK_ADD_GROUPS, { key: 'other', label: 'その他', ids: extras }] : FK_ADD_GROUPS;
            return groups.map((g) =>
            <div key={g.key}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '14px 2px 9px' }}>
                  <span style={{ fontSize: 12.5, fontWeight: 800, color: 'var(--fk-brand-ink)', letterSpacing: 0.4 }}>{g.label}</span>
                  <span style={{ flex: 1, height: 1, background: 'var(--fk-hair)' }} />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 11 }}>
                  {g.ids.map((id) => {const c = window.FKD.fkCat(id);return c ? <FKCatTile key={id} cat={c} dark={dark} addMode count={countOf(c.id)} onClick={() => openAdd(c)} /> : null;})}
                </div>
              </div>
            );
          })()}
        </div>

        {/* cart CTA bar (E) */}
        <div style={{
          flexShrink: 0, borderTop: '1px solid var(--fk-hair)', background: 'var(--fk-surface)',
          padding: '11px 18px calc(13px + env(safe-area-inset-bottom))', display: 'flex', alignItems: 'center', gap: 12
        }}>
          <button onClick={() => cart.length && setExpanded((e) => !e)} disabled={!cart.length} style={{
            display: 'flex', alignItems: 'center', gap: 8, fontSize: 14.5, fontWeight: 800, color: 'var(--fk-text)',
            border: 'none', background: 'transparent', cursor: cart.length ? 'pointer' : 'default', padding: 0,
            fontFamily: '"M PLUS Rounded 1c", system-ui'
          }}>
            <span style={{
              minWidth: 25, height: 25, borderRadius: 999, padding: '0 6px', fontSize: 13, lineHeight: 1,
              background: cart.length ? 'var(--fk-brand)' : 'var(--fk-surface2)',
              color: cart.length ? '#fff' : 'var(--fk-text-ter)',
              display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>{cart.length}</span>
            かごの中
            {cart.length > 0 &&
            <svg width="11" height="11" viewBox="0 0 12 12" style={{ transform: expanded ? 'rotate(180deg)' : 'none', transition: 'transform .2s' }}>
              <path d="M1 8l5-5 5 5" stroke="var(--fk-text-sec)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            }
          </button>
          <button disabled={!cart.length} onClick={commit} style={{
            marginLeft: 'auto', border: 'none', cursor: cart.length ? 'pointer' : 'default',
            borderRadius: 13, padding: '11px 20px', fontSize: 15, fontWeight: 800,
            fontFamily: '"M PLUS Rounded 1c", system-ui',
            backgroundColor: cart.length ? accent : 'var(--fk-surface2)',
            color: cart.length ? '#fff' : 'var(--fk-text-ter)',
            boxShadow: cart.length ? `0 6px 18px ${accent}59` : 'none',
            transition: 'color .15s ease'
          }}>{cart.length ? 'まとめて登録' : 'カゴは空'}</button>
        </div>
      </div>

      {/* gentle confirm before discarding a non-empty cart */}
      {confirmClose &&
      <div style={{ position: 'absolute', inset: 0, zIndex: 10, display: 'flex', alignItems: 'flex-end' }}>
          <div onClick={() => setConfirmClose(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.28)', animation: 'fkScrimIn .22s ease' }} />
          <div style={{
          position: 'relative', width: '100%', background: 'var(--fk-bg2)', borderRadius: '22px 22px 0 0',
          padding: '20px 22px calc(18px + env(safe-area-inset-bottom))', boxShadow: '0 -6px 26px rgba(20,14,6,0.22)',
          animation: 'fkSheetPop .3s cubic-bezier(.22,.7,.3,1)'
        }}>
            <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--fk-text)' }}>かごに {cart.length}品 残っています</div>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--fk-text-sec)', marginTop: 4, lineHeight: 1.5 }}>
              登録するとホームに追加されます。どうしますか？
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginTop: 16 }}>
              <button onClick={commit} style={{
              border: 'none', cursor: 'pointer', borderRadius: 14, padding: '14px 0', fontSize: 15.5, fontWeight: 800,
              fontFamily: '"M PLUS Rounded 1c", system-ui', backgroundColor: accent, color: '#fff'
            }}>{cart.length}品を登録して閉じる</button>
              <button onClick={onClose} style={{
              border: 'none', cursor: 'pointer', borderRadius: 14, padding: '12px 0', fontSize: 14.5, fontWeight: 700,
              fontFamily: '"M PLUS Rounded 1c", system-ui', background: 'transparent', color: 'var(--fk-text-sec)'
            }}>かごを空にして閉じる</button>
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