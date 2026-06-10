/* fk-home.jsx — Home screen with 3 switchable layout concepts (案A/B/C). */

const FKcat = window.FKD.fkCat;

// shared: split inventory into 生鮮(主役) vs ゆとり(背景)
function fkSplit(items) {
  const hero = [],plenty = [];
  for (const it of items) {
    if (it.perishable && it.days <= 6) hero.push(it);else
    plenty.push(it);
  }
  hero.sort((a, b) => a.days - b.days || a.addedAt - b.addedAt);
  plenty.sort((a, b) => a.days - b.days);
  return { hero, plenty };
}

// "ゆとりあり" — 保存食・余裕ある物は静かに背景へ
function FKPlenty({ items, dark, tone, copy }) {
  const [open, setOpen] = React.useState(false);
  if (!items.length) return null;
  return (
    <div style={{ marginTop: 26 }}>
      <button onClick={() => setOpen((o) => !o)} style={{
        width: '100%', border: 'none', background: 'transparent', cursor: 'pointer',
        display: 'flex', alignItems: 'center', gap: 8, padding: '4px 4px 10px',
        fontFamily: '"M PLUS Rounded 1c", system-ui'
      }}>
        <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--fk-text-sec)' }}>{copy.plenty}</span>
        <span style={{
          fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-ter)',
          background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(70,55,30,0.06)',
          borderRadius: 999, padding: '2px 8px'
        }}>{items.length}</span>
        <span style={{ flex: 1, textAlign: 'left', fontSize: 12.5, color: 'var(--fk-text-ter)' }}>{copy.plentyNote}</span>
        <svg width="13" height="13" viewBox="0 0 12 12" style={{ transform: open ? 'rotate(90deg)' : 'none', transition: 'transform .2s' }}>
          <path d="M3 1l5 5-5 5" stroke="var(--fk-text-ter)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
      {open &&
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {items.map((it) => {
          const cat = FKcat(it.catId);
          return (
            <div key={it.id} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px',
              background: 'var(--fk-surface)', borderRadius: 16, opacity: 0.82
            }}>
                <FKIcon cat={cat} size={34} dark={dark} />
                <span style={{ flex: 1, fontSize: 15, fontWeight: 600, color: 'var(--fk-text)' }}>{it.name}</span>
                <FKAmtIndicator item={it} size={34} />
                <span style={{ fontSize: 13, color: 'var(--fk-text-ter)', fontWeight: 600 }}>
                  {it.days > 13 ? '当分OK' : `あと${it.days}日`}
                </span>
              </div>);

        })}
        </div>
      }
    </div>);

}

// 冷蔵庫に1品もない時（初回起動でスキップ／リセット後）— 責めない、迎え入れる空状態
function FKEmptyFridge({ tone, dark, accent, onAdd }) {
  const t = tone === 'simple' ? {
    title: '登録された食材はありません',
    sub: '買ってきた食材を ＋ から追加してください。',
    cta: '食材を追加'
  } : tone === 'cheer' ? {
    title: 'さあ、はじめましょう！',
    sub: '買ってきた食材を入れると、食べきりをやさしくお手伝いします。',
    cta: '最初の食材を追加'
  } : {
    title: '冷蔵庫は、まだ空っぽ',
    sub: '買ってきた食材を追加すると、傷んでしまう前にそっとお知らせします。',
    cta: '食材を追加する'
  };
  return (
    <div style={{ padding: '20px 4px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
      <div style={{
        width: 96, height: 96, borderRadius: '50%', background: 'var(--fk-brand-soft)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', marginTop: 26, marginBottom: 22
      }}>
        <svg width="46" height="46" viewBox="0 0 48 48" fill="none">
          <rect x="13" y="7" width="22" height="34" rx="6" fill="none" stroke="var(--fk-brand)" strokeWidth="2.4" opacity="0.55" />
          <path d="M13 21h22" stroke="var(--fk-brand)" strokeWidth="2.4" opacity="0.55" />
          <path d="M24 26v6.5M20.75 29.25h6.5" stroke="var(--fk-brand)" strokeWidth="2.4" strokeLinecap="round" />
        </svg>
      </div>
      <div style={{ fontSize: 21, fontWeight: 800, color: 'var(--fk-text)', letterSpacing: 0.3 }}>{t.title}</div>
      <div style={{ fontSize: 14.5, fontWeight: 600, color: 'var(--fk-text-sec)', marginTop: 10, lineHeight: 1.7, maxWidth: 280, textWrap: 'pretty' }}>{t.sub}</div>
      <button onClick={onAdd} style={{
        marginTop: 24, border: 'none', cursor: 'pointer', borderRadius: 16, padding: '14px 26px',
        background: accent, color: '#fff', fontWeight: 800, fontSize: 16,
        fontFamily: '"M PLUS Rounded 1c", system-ui', display: 'inline-flex', alignItems: 'center', gap: 8,
        boxShadow: `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)`
      }}>
        <FKPlus color="#fff" size={20} /> {t.cta}
      </button>
      <div style={{ marginTop: 30, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5, color: 'var(--fk-text-ter)' }}>
        <span style={{ fontSize: 12.5, fontWeight: 700 }}>下の ＋ ボタンからも追加できます</span>
        <svg width="16" height="16" viewBox="0 0 16 16" style={{ animation: 'fkBob 1.6s ease-in-out infinite' }}>
          <path d="M8 2v10M3.5 8L8 12.5 12.5 8" stroke="var(--fk-text-ter)" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
    </div>);

}

function FKEmpty({ copy }) {
  return (
    <div style={{
      padding: '38px 20px', textAlign: 'center', color: 'var(--fk-text-sec)',
      background: 'var(--fk-surface)', borderRadius: 22, lineHeight: 1.7
    }}>
      <div style={{ fontSize: 32, marginBottom: 6 }}>
        <span style={{
          display: 'inline-flex', width: 56, height: 56, borderRadius: '50%',
          background: 'var(--fk-brand-soft)', alignItems: 'center', justifyContent: 'center'
        }}><FKCheck color="var(--fk-brand)" size={30} /></span>
      </div>
      <div style={{ fontSize: 15.5, fontWeight: 600 }}>{copy.empty}</div>
    </div>);

}

// ── 案A : やさしいカード（写真/アイコン前面・大きめカード） ──────────
function FKHomeA({ hero, plenty, onAte, onToss, onEdit, dark, tone, accent, copy }) {
  return (
    <div>
      {hero.length === 0 ? <FKEmpty copy={copy} /> : hero.map((it) => {
        const cat = FKcat(it.catId);
        const u = window.FKT.fkUrgency(it.days, dark);
        return (
          <FKSwipe key={it.id} accent={accent} dark={dark}
          onAte={() => onAte(it)} onToss={() => onToss(it)} onTap={onEdit ? () => onEdit(it) : undefined}>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 15, padding: '15px 16px 15px 17px',
              background: 'var(--fk-surface)', borderRadius: 22,
              boxShadow: `0 1px 3px var(--fk-shadow)`, position: 'relative', overflow: 'hidden'
            }}>
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 5, background: u.solid }} />
              <FKIcon cat={cat} size={52} dark={dark} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17.5, fontWeight: 700, color: 'var(--fk-text)', marginBottom: 5 }}>{it.name}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <FKDayPill days={it.days} dark={dark} tone={tone} size="sm" />
                  <FKAmtIndicator item={it} size={34} />
                </div>
              </div>
              <span style={{ color: 'var(--fk-text-ter)', fontSize: 12.5, fontWeight: 600, textAlign: 'right', lineHeight: 1.4 }}>
                スワイプで<br />食べた / 処分
              </span>
            </div>
          </FKSwipe>);

      })}
      <FKPlenty items={plenty} dark={dark} tone={tone} copy={copy} />
    </div>);

}

// ── 案B : 今週のながれ（日付グルーピング + 色温度スパイン） ──────────
function FKHomeB({ hero, plenty, onAte, onToss, onEdit, dark, tone, accent, copy }) {
  const buckets = [
  { key: 't0', label: tone === 'cheer' ? 'いま食べごろ' : '今日中', test: (d) => d <= 0 },
  { key: 't1', label: 'あした', test: (d) => d === 1 },
  { key: 't2', label: '2〜3日', test: (d) => d >= 2 && d <= 3 },
  { key: 't3', label: '今週中', test: (d) => d >= 4 }];

  if (hero.length === 0) return <div><FKEmpty copy={copy} /><FKPlenty items={plenty} dark={dark} tone={tone} copy={copy} /></div>;
  return (
    <div>
      {buckets.map((b) => {
        const list = hero.filter((it) => b.test(it.days));
        if (!list.length) return null;
        const u = window.FKT.fkUrgency(list[0].days, dark);
        return (
          <div key={b.key} style={{ marginBottom: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '0 2px 9px' }}>
              <span style={{ width: 9, height: 9, borderRadius: 99, background: u.solid }} />
              <span style={{ fontSize: 15, fontWeight: 800, color: 'var(--fk-text)' }}>{b.label}</span>
              <span style={{ fontSize: 13, color: 'var(--fk-text-ter)', fontWeight: 600 }}>{list.length}品</span>
            </div>
            <div style={{
              position: 'relative', borderRadius: 20, overflow: 'hidden',
              background: 'var(--fk-surface)', boxShadow: '0 1px 3px var(--fk-shadow)'
            }}>
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: u.solid, zIndex: 2 }} />
              {list.map((it, i) => {
                const cat = FKcat(it.catId);
                return (
                  <FKSwipe key={it.id} accent={accent} dark={dark}
                  onAte={() => onAte(it)} onToss={() => onToss(it)} onTap={onEdit ? () => onEdit(it) : undefined}>
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: 12, padding: '12px 15px 12px 17px',
                      background: 'var(--fk-surface)',
                      borderTop: i ? '1px solid var(--fk-hair)' : 'none'
                    }}>
                      <FKIcon cat={cat} size={40} dark={dark} />
                      <span style={{ flex: 1, fontSize: 16, fontWeight: 700, color: 'var(--fk-text)' }}>{it.name}</span>
                      <FKAmtIndicator item={it} size={34} />
                      <FKDayPill days={it.days} dark={dark} tone={tone} size="sm" />
                    </div>
                  </FKSwipe>);

              })}
            </div>
          </div>);

      })}
      <FKPlenty items={plenty} dark={dark} tone={tone} copy={copy} />
    </div>);

}

// ── 案C : ひとめ（最優先1品をヒーロー + 静かなリスト） ──────────────
function FKHomeC({ hero, plenty, onAte, onToss, onEdit, dark, tone, accent, copy, labels }) {
  // ヒーローは「かなり迫っている」食材専用（今日〜あと2日）。余裕ある物は下の静かなリストへ。
  const URG = 2;
  const urgentAll = hero.filter((h) => h.days <= URG);
  const calm = hero.filter((h) => h.days > URG).slice().sort((a, b) => a.days - b.days);
  const urgentKey = urgentAll.map((h) => h.id).join(',');
  const [order, setOrder] = React.useState(() => urgentAll.map((h) => h.id));
  React.useEffect(() => {
    setOrder((prev) => {
      const ids = urgentAll.map((h) => h.id);
      const kept = prev.filter((id) => ids.includes(id));
      const added = ids.filter((id) => !kept.includes(id));
      return [...kept, ...added];
    });
  }, [urgentKey]);
  const deck = order.map((id) => urgentAll.find((h) => h.id === id)).filter(Boolean);
  const cycleNext = () => setOrder((o) => o.length > 1 ? [...o.slice(1), o[0]] : o);
  const cyclePrev = () => setOrder((o) => o.length > 1 ? [o[o.length - 1], ...o.slice(0, -1)] : o);
  // 食べた！の達成演出 → 演出後に消費
  const [burst, setBurst] = React.useState(false);
  const doAteHero = () => {
    if (burst) return;
    setBurst(true);
    setTimeout(() => {setBurst(false);onAte(top);}, 460);
  };

  if (hero.length === 0) return <div><FKEmpty copy={copy} /><FKPlenty items={plenty} dark={dark} tone={tone} copy={copy} /></div>;
  const canCycle = deck.length > 1;
  const top = deck[0];
  const cat = top && FKcat(top.catId);
  const u = window.FKT.fkUrgency(top ? top.days : 7, dark);
  const d = top ? top.days : 0;
  const heroVerb =
  tone === 'simple' ?
  d <= 0 ? '今日中に使い切る' : d === 1 ? '明日まで' : `あと${d}日` :
  tone === 'cheer' ?
  d <= 0 ? 'きょうが食べどき！' : d === 1 ? 'そろそろ食べごろ' : `あと${d}日、楽しみに` :
  d <= 0 ? '今日のうちに、食べきろう' : d === 1 ? 'あすまでに、食べきりたい' : `あと${d}日、おいしいうちに`;

  const moreUrgent = deck.length - 1;
  return (
    <div>
      {/* hero card — かなり迫っている食材専用。上=次へ / 下=前へ */}
      {top ?
      <div style={{ position: 'relative', marginBottom: canCycle ? 10 : 0 }}>
        {canCycle &&
        <React.Fragment>
            <div style={{ position: 'absolute', left: 26, right: 26, top: 20, bottom: -18, borderRadius: 24, background: 'var(--fk-surface)', opacity: 0.45, boxShadow: '0 4px 12px var(--fk-shadow)' }} />
            <div style={{ position: 'absolute', left: 14, right: 14, top: 10, bottom: -9, borderRadius: 25, background: 'var(--fk-surface)', opacity: 0.7, boxShadow: '0 4px 12px var(--fk-shadow)' }} />
          </React.Fragment>
        }
        <div style={{ position: 'relative', zIndex: 1 }}>
      <FKSwipe accent={accent} dark={dark} onAte={() => onAte(top)} onToss={() => onToss(top)} onTap={onEdit ? () => onEdit(top) : undefined} onCycle={canCycle ? cycleNext : undefined} onCyclePrev={canCycle ? cyclePrev : undefined}>
        <div style={{
              padding: '22px 22px 20px', borderRadius: 26, position: 'relative', overflow: 'hidden',
              background: `linear-gradient(160deg, color-mix(in oklab, ${u.solid} 16%, var(--fk-surface)), var(--fk-surface))`,
              boxShadow: '0 6px 22px var(--fk-shadow)',
              animation: burst ? 'fkEatCard .46s cubic-bezier(.3,.7,.3,1) forwards' : 'none'
            }}>
          {burst && <FKEatBurst accent={accent} />}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
            <FKIcon cat={cat} size={62} dark={dark} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <FKDayPill days={top.days} dark={dark} tone={tone} />
              <div style={{ fontSize: 24, fontWeight: 800, color: 'var(--fk-text)', marginTop: 8, lineHeight: 1.2 }}>{top.name}</div>
              <div style={{ marginTop: 8 }}><FKAmtIndicator item={top} size={40} /></div>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 9, marginBottom: 14, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 15, fontWeight: 700, color: u.pillFg }}>{heroVerb}</span>
            {moreUrgent > 0 &&
                <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-ter)' }}>急ぎはほかに{moreUrgent}品・スワイプで切替</span>
                }
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button onClick={doAteHero} style={{
                  flex: 1, border: 'none', cursor: 'pointer', borderRadius: 14, padding: '13px 0',
                  background: accent, color: '#fff', fontWeight: 800, fontSize: 15.5,
                  fontFamily: '"M PLUS Rounded 1c", system-ui',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7
                }}><FKCheck color="#fff" size={19} /> 食べた</button>
            <button style={{
                  border: 'none', cursor: 'pointer', borderRadius: 14, padding: '13px 18px',
                  background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(70,55,30,0.06)',
                  color: 'var(--fk-text)', fontWeight: 700, fontSize: 15.5,
                  fontFamily: '"M PLUS Rounded 1c", system-ui'
                }}>レシピ</button>
          </div>
        </div>
      </FKSwipe>
        </div>
      </div> :

      <div style={{
        padding: '20px 22px', borderRadius: 24, background: 'var(--fk-brand-soft)',
        display: 'flex', alignItems: 'center', gap: 14, marginBottom: 4
      }}>
        <span style={{ width: 46, height: 46, borderRadius: '50%', background: 'var(--fk-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <FKCheck color="var(--fk-brand)" size={26} />
        </span>
        <div>
          <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--fk-brand-ink)' }}>今日・明日の急ぎはありません</div>
          <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--fk-text-sec)', marginTop: 2 }}>下の食材を、ゆっくり使いきっていきましょう。</div>
        </div>
      </div>
      }

      {/* calm list — 余裕のある生鮮 */}
      {calm.length > 0 &&
      <div style={{ marginTop: 28 }}>
          <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fk-text-sec)', fontFamily: '"M PLUS Rounded 1c", system-ui', margin: '0 2px 10px' }}>{top ? (labels && labels.calm || '今週の食材') : (labels && labels.calmEmpty || '今週の食材')}</div>
          <div style={{ background: 'var(--fk-surface)', borderRadius: 20, overflow: 'hidden', boxShadow: '0 1px 3px var(--fk-shadow)' }}>
            {calm.map((it, i) => {
            const c = FKcat(it.catId);
            return (
              <FKSwipe key={it.id} accent={accent} dark={dark}
              onAte={() => onAte(it)} onToss={() => onToss(it)} onTap={onEdit ? () => onEdit(it) : undefined}>
                  <div style={{
                  display: 'flex', alignItems: 'center', gap: 12, padding: '12px 15px',
                  background: 'var(--fk-surface)', borderTop: i ? '1px solid var(--fk-hair)' : 'none'
                }}>
                    <FKIcon cat={c} size={38} dark={dark} />
                    <span style={{ flex: 1, fontSize: 15.5, fontWeight: 700, color: 'var(--fk-text)' }}>{it.name}</span>
                    <FKAmtIndicator item={it} size={34} />
                    <FKDayPill days={it.days} dark={dark} tone={tone} size="sm" />
                  </div>
                </FKSwipe>);

          })}
          </div>
        </div>
      }
      <FKPlenty items={plenty} dark={dark} tone={tone} copy={copy} />
    </div>);

}

Object.assign(window, { fkSplit, FKHomeA, FKHomeB, FKHomeC, FKPlenty, FKEmpty, FKEmptyFridge });