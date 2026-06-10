/* fk-return.jsx — Re-entry flow for users coming back after a lapse.
   Never blames stale inventory; offers a gentle reset or quick re-入れ直す. */

const FKrCats = window.FKD.FK_CATEGORIES;
const FKrMake = window.FKD.fkMakeItem;

// ── Welcome-back screen (full overlay over home) ─────────────────
function FKReturn({ daysAway, dark, accent, tone, onReset, onReenter, onKeep }) {
  const head = tone === 'simple' ? 'おかえり' : tone === 'cheer' ? 'おかえりなさい！' : 'おかえりなさい';
  const sub = tone === 'simple' ?
  `前回から${daysAway}日。` :
  tone === 'cheer' ?
  `${daysAway}日ぶり。サッと整えて、また気持ちよく再スタート。` :
  `前回から${daysAway}日空きました。いまの冷蔵庫に合わせて、軽く整えましょう。`;

  const Option = ({ title, note, onClick, primary }) =>
  <button onClick={onClick} style={{
    width: '100%', textAlign: 'left', border: primary ? 'none' : '1.5px solid var(--fk-hair)',
    cursor: 'pointer', borderRadius: 20, padding: '16px 18px',
    background: primary ? 'var(--fk-surface)' : 'transparent',
    boxShadow: primary ? '0 4px 16px var(--fk-shadow)' : 'none',
    fontFamily: '"M PLUS Rounded 1c", system-ui',
    display: 'flex', alignItems: 'center', gap: 14, position: 'relative'
  }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 16.5, fontWeight: 800, color: 'var(--fk-text)', marginBottom: 3 }}>{title}</div>
        <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--fk-text-sec)', lineHeight: 1.45 }}>{note}</div>
      </div>
      {primary &&
    <span style={{
      fontSize: 11.5, fontWeight: 800, color: '#fff', background: accent,
      borderRadius: 999, padding: '3px 9px', flexShrink: 0
    }}>おすすめ</span>
    }
      <svg width="9" height="15" viewBox="0 0 8 14" style={{ flexShrink: 0 }}>
        <path d="M1 1l6 6-6 6" stroke="var(--fk-text-ter)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </button>;


  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 300, background: 'var(--fk-bg)',
      display: 'flex', flexDirection: 'column'
    }}>
      <div style={{ flex: 1, overflowY: 'auto', padding: '78px 24px 20px' }}>
        <div style={{
          width: 64, height: 64, borderRadius: '50%', background: 'var(--fk-brand-soft)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 22
        }}>
          <FKAppMark size={34} />
        </div>
        <div style={{ fontSize: 30, fontWeight: 800, color: 'var(--fk-text)', letterSpacing: 0.4 }}>{head}</div>
        <div style={{ fontSize: 15.5, color: 'var(--fk-text-sec)', marginTop: 12, lineHeight: 1.75, fontWeight: 600, textWrap: 'pretty' }}>{sub}</div>
        <div style={{
          fontSize: 13, color: 'var(--fk-text-ter)', fontWeight: 700, marginTop: 16,
          background: dark ? 'rgba(255,255,255,0.05)' : 'rgba(70,55,30,0.05)',
          borderRadius: 14, padding: '11px 14px', lineHeight: 1.5
        }}>
          少し前の食材は、そっと片付けておきました。いつでも、好きなところから再開できます。
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 26 }}>
          <Option primary title="今ある物だけ入れ直す" note="冷蔵庫にある物をタップで選ぶだけ。30秒で再開。" onClick={onReenter} />
          <Option title="リセットしてまっさらに" note="今の在庫をクリアして、ゼロから始めます。" onClick={onReset} />
        </div>
      </div>
      <div style={{ padding: '8px 24px calc(20px + env(safe-area-inset-bottom))', textAlign: 'center' }}>
        <button onClick={onKeep} style={{
          border: 'none', background: 'transparent', cursor: 'pointer',
          color: 'var(--fk-text-sec)', fontSize: 14.5, fontWeight: 700,
          fontFamily: '"M PLUS Rounded 1c", system-ui'
        }}>このまま続ける</button>
      </div>
    </div>);

}

// ── Quick re-入れ直す sheet (tap what's in the fridge now) ────────
function FKReenterSheet({ open, onClose, onConfirm, dark, accent }) {
  const [sel, setSel] = React.useState([]);
  const cats = FKrCats.filter((c) => c.perishable);
  React.useEffect(() => {if (open) setSel([]);}, [open]);
  const toggle = (id) => setSel((s) => s.includes(id) ? s.filter((x) => x !== id) : [...s, id]);

  return (
    <FKSheet open={open} onClose={onClose} dark={dark}>
      <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ padding: '12px 22px 4px' }}>
          <div style={{ fontSize: 21, fontWeight: 800, color: 'var(--fk-text)' }}>いま冷蔵庫にある物は？</div>
          <div style={{ fontSize: 13.5, color: 'var(--fk-text-sec)', marginTop: 3, fontWeight: 600 }}>
            あてはまるものをタップ。日数は自動でつけ直します。
          </div>
        </div>
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 11,
          padding: '14px 18px 12px', overflowY: 'auto'
        }}>
          {cats.map((c) => <FKCatTile key={c.id} cat={c} dark={dark} selected={sel.includes(c.id)} onClick={() => toggle(c.id)} />)}
        </div>
        <div style={{ padding: '8px 22px calc(20px + env(safe-area-inset-bottom))' }}>
          <button disabled={sel.length === 0} onClick={() => onConfirm(sel)} style={{
            width: '100%', border: 'none', cursor: sel.length ? 'pointer' : 'default',
            borderRadius: 16, padding: '16px 0', fontSize: 16.5, fontWeight: 800,
            fontFamily: '"M PLUS Rounded 1c", system-ui',
            background: sel.length ? accent : 'var(--fk-surface2)',
            color: sel.length ? '#fff' : 'var(--fk-text-ter)',
            boxShadow: sel.length ? `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)` : 'none',
            transition: 'all .2s ease'
          }}>
            {sel.length === 0 ? '食材を選んでね' : `これで入れ直す（${sel.length}品）`}
          </button>
        </div>
      </div>
    </FKSheet>);

}

function fkReenterItems(catIds) {
  return catIds.map((cid) => FKrMake(cid, window.FKD.FK_CAT_DEFAULT_NAME[cid], window.FKD.fkCat(cid).days));
}

Object.assign(window, { FKReturn, FKReenterSheet, fkReenterItems });