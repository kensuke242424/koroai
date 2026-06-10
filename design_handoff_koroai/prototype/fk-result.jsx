/* fk-result.jsx — 月替わりリザルト (monthly result overlay).
   Shown the moment the month rolls over and the 食べきりカウント resets.
   Celebrates last month's result in a "result screen" format and sends the
   user into the new month feeling encouraged. Exports to window. */

const FK_TIERS = [
  { min: 0,  name: 'はじめの一歩', note: '記録のはじまり' },
  { min: 5,  name: '食べきり上手', note: 'いい習慣が育っています' },
  { min: 12, name: 'ムダなしの達人', note: '冷蔵庫がいつもすっきり' },
  { min: 20, name: '食べきりマイスター', note: 'もう、ムダ知らず' },
];
function fkRankFor(count) {
  let t = FK_TIERS[0];
  for (const x of FK_TIERS) if (count >= x.min) t = x;
  return t;
}

// 0 → target をイージングで数え上げ（rAF が止まる環境でも最終値は必ず target に収束）
function useCountTo(target, delay = 240, dur = 1050) {
  const reduce = typeof window !== 'undefined' && window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const [v, setV] = React.useState(reduce ? target : 0);
  React.useEffect(() => {
    if (reduce) { setV(target); return; }
    let raf, t0;
    const startT = setTimeout(() => { raf = requestAnimationFrame(tick); }, delay);
    function tick(t) {
      if (t0 == null) t0 = t;
      const p = Math.min(1, (t - t0) / dur);
      const e = 1 - Math.pow(1 - p, 3);
      setV(Math.round(target * e));
      if (p < 1) raf = requestAnimationFrame(tick);
    }
    // 保険: rAF がスロットルされても最後は必ず確定値へ
    const settle = setTimeout(() => setV(target), delay + dur + 80);
    return () => { clearTimeout(startT); clearTimeout(settle); if (raf) cancelAnimationFrame(raf); };
  }, [target, delay, dur, reduce]);
  return v;
}

// 称号バッジ — リーフ＋ランク名のやわらかいピル
function FKRankBadge({ tier, accent }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '7px 15px 7px 12px', borderRadius: 999,
      background: 'var(--fk-brand-soft)', color: 'var(--fk-brand-ink)',
      boxShadow: 'inset 0 0 0 1.5px color-mix(in oklab, var(--fk-brand) 28%, transparent)',
      animation: 'fkResultBadge .5s cubic-bezier(.2,.8,.3,1.3) .5s both',
    }}>
      <span style={{
        width: 24, height: 24, borderRadius: '50%', flexShrink: 0,
        background: 'var(--fk-brand)', display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <FKLeaf color="#fff" size={14} />
      </span>
      <span style={{ fontSize: 15, fontWeight: 800, letterSpacing: 0.2 }}>{tier.name}</span>
    </div>
  );
}

// 落ち葉コンフェッティ（控えめ）
function FKLeafFall({ accent }) {
  const leaves = React.useMemo(() => {
    const greens = ['var(--fk-brand)', accent, 'color-mix(in oklab, var(--fk-brand) 70%, #c7d8a8)'];
    return Array.from({ length: 14 }).map((_, i) => ({
      left: 4 + Math.random() * 92,
      delay: Math.random() * 1.6,
      dur: 3.4 + Math.random() * 2.2,
      size: 13 + Math.random() * 12,
      color: greens[i % greens.length],
      drift: (Math.random() * 2 - 1) * 26,
    }));
  }, [accent]);
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none', zIndex: 1 }}>
      {leaves.map((l, i) => (
        <span key={i} style={{
          position: 'absolute', top: -28, left: l.left + '%',
          '--drift': l.drift + 'px',
          animation: `fkLeafFall ${l.dur}s linear ${l.delay}s infinite`,
          opacity: 0,
        }}>
          <span style={{ display: 'inline-block', animation: `fkLeafSpin ${l.dur * 0.5}s ease-in-out ${l.delay}s infinite` }}>
            <FKLeaf color={l.color} size={l.size} />
          </span>
        </span>
      ))}
    </div>
  );
}

// ── 月替わりリザルト本体 ──────────────────────────────────────────
// result = { month (0-idx), count, prevCount|null, streak }
function FKMonthResult({ result, dark, accent, tone, showRank = true, onStart }) {
  const { month, count, prevCount, streak } = result;
  const tier = fkRankFor(count);
  const shown = useCountTo(count);
  const m = month + 1;
  const nextM = (month + 1) % 12 + 1;

  const kicker = tone === 'simple' ? '月間レポート'
    : tone === 'cheer' ? 'ひと月、おつかれさま！'
    : 'ひと月、おつかれさまでした';
  const title = tone === 'simple' ? `${m}月のまとめ`
    : tone === 'cheer' ? `${m}月のがんばり`
    : `${m}月のふりかえり`;
  const heroSub = tone === 'simple' ? '今月の食べきり'
    : tone === 'cheer' ? 'ぜんぶ、おいしく食べきり！'
    : 'ムダにせず、使いきれました';
  const closing = tone === 'simple' ? `${nextM}月もこの調子で。`
    : tone === 'cheer' ? `最高の1ヶ月！${nextM}月も、いっしょに。`
    : `すてきな1ヶ月でした。${nextM}月も、いいペースで。`;
  const cta = tone === 'simple' ? `${nextM}月をはじめる` : `${nextM}月をはじめる`;

  // 先月比チップ
  let diffChip;
  if (prevCount == null) diffChip = { label: 'はじめての記録', tone: 'neutral' };
  else if (count > prevCount) diffChip = { label: `先月より ＋${count - prevCount}品`, tone: 'up' };
  else if (count === prevCount) diffChip = { label: '先月と同じペース', tone: 'neutral' };
  else diffChip = { label: 'マイペースで継続中', tone: 'neutral' };

  const Stat = ({ chip, idx }) => (
    <div style={{
      flex: 1, minWidth: 0, padding: '12px 8px', borderRadius: 16, textAlign: 'center',
      background: 'var(--fk-surface)', border: '1px solid var(--fk-hair)',
      animation: `fkResultChip .44s ease ${0.75 + idx * 0.1}s both`,
    }}>
      <div style={{
        fontSize: 17, fontWeight: 800, lineHeight: 1.25,
        color: chip.tone === 'up' ? 'var(--fk-brand-ink)' : 'var(--fk-text)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
      }}>
        {chip.tone === 'up' && (
          <svg width="13" height="13" viewBox="0 0 16 16" style={{ flexShrink: 0 }}>
            <path d="M8 13V3M8 3l-4 4M8 3l4 4" stroke="currentColor" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        )}
        {chip.big || chip.label}
      </div>
      {chip.sub && <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--fk-text-ter)', marginTop: 3 }}>{chip.sub}</div>}
    </div>
  );

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 330, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      background: dark
        ? 'radial-gradient(120% 80% at 50% 8%, color-mix(in oklab, var(--fk-brand) 24%, var(--fk-bg)) 0%, var(--fk-bg) 60%)'
        : 'radial-gradient(120% 80% at 50% 6%, color-mix(in oklab, var(--fk-brand) 26%, var(--fk-bg)) 0%, var(--fk-bg) 58%)',
    }}>
      <FKLeafFall accent={accent} />

      <div style={{ position: 'relative', zIndex: 2, flex: 1, overflowY: 'auto', padding: '70px 24px 16px', display: 'flex', flexDirection: 'column' }}>
        {/* header */}
        <div style={{ textAlign: 'center', animation: 'fkResultPop .5s cubic-bezier(.2,.8,.3,1) both' }}>
          <div style={{
            width: 52, height: 52, borderRadius: '50%', margin: '0 auto 14px',
            background: 'var(--fk-brand-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <FKAppMark size={30} />
          </div>
          <div style={{ fontSize: 13.5, fontWeight: 800, color: 'var(--fk-brand-ink)', letterSpacing: 0.6 }}>{kicker}</div>
          <div style={{ fontSize: 25, fontWeight: 800, color: 'var(--fk-text)', marginTop: 4, letterSpacing: 0.4 }}>{title}</div>
        </div>

        {/* hero number */}
        <div style={{
          marginTop: 22, padding: '26px 20px 22px', borderRadius: 26, textAlign: 'center',
          background: 'var(--fk-surface)', border: '1px solid var(--fk-hair)',
          boxShadow: '0 12px 36px var(--fk-shadow)',
          animation: 'fkResultPop .55s cubic-bezier(.2,.8,.3,1) .08s both',
        }}>
          {showRank && (
            <div style={{ marginBottom: 14 }}>
              <FKRankBadge tier={tier} accent={accent} />
            </div>
          )}
          <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'baseline', gap: 4, lineHeight: 1, color: 'var(--fk-brand-ink)' }}>
            <span style={{
              position: 'absolute', left: '50%', top: '54%', width: 132, height: 132,
              transform: 'translate(-50%,-50%)', borderRadius: '50%', zIndex: 0,
              background: 'radial-gradient(circle, color-mix(in oklab, var(--fk-brand) 26%, transparent), transparent 68%)',
            }} />
            <span style={{ position: 'relative', fontSize: 74, fontWeight: 800, letterSpacing: 1 }}>{shown}</span>
            <span style={{ position: 'relative', fontSize: 26, fontWeight: 800 }}>品</span>
          </div>
          <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--fk-text)', marginTop: 6 }}>{heroSub}</div>
          {showRank && <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-ter)', marginTop: 3 }}>{tier.note}</div>}
        </div>

        {/* stats */}
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <Stat idx={0} chip={diffChip} />
          <Stat idx={1} chip={{ big: `${streak}ヶ月`, sub: 'つづけて食べきり', tone: 'neutral' }} />
        </div>

        {/* closing line */}
        <div style={{
          textAlign: 'center', marginTop: 22, fontSize: 15, fontWeight: 700,
          color: 'var(--fk-text-sec)', lineHeight: 1.7, textWrap: 'pretty',
          animation: 'fkResultChip .5s ease 1s both',
        }}>{closing}</div>

        <div style={{ flex: 1 }} />

        {/* CTA */}
        <button onClick={onStart} style={{
          width: '100%', border: 'none', cursor: 'pointer', borderRadius: 18, padding: '16px 0',
          background: accent, color: '#fff', fontSize: 16.5, fontWeight: 800,
          fontFamily: '"M PLUS Rounded 1c", system-ui', marginTop: 20,
          boxShadow: `0 8px 22px color-mix(in oklab, ${accent} 38%, transparent)`,
          animation: 'fkResultChip .5s ease 1.12s both',
        }}>{cta}</button>
        <div style={{
          textAlign: 'center', fontSize: 12, fontWeight: 700, color: 'var(--fk-text-ter)',
          marginTop: 10, paddingBottom: 'env(safe-area-inset-bottom)',
        }}>カウントは{m}月のぶん。{nextM}月はゼロから、また気楽に。</div>
      </div>
    </div>
  );
}

Object.assign(window, { FKMonthResult });
