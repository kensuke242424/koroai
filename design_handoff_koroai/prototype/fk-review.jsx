/* fk-review.jsx — ふりかえり (review) surface + 序盤の報酬 (early-reward).
   - FKReview:        常設のプル型「現状の評価」画面。中心は“ごほうびの道のり”。
   - FKMilestoneCelebrate: 節目（特に初日）の小さな祝祭。離脱前にハマる報酬。
   - FKWeeklyCard:    ホームにそっと出る週次の入口（軽いプッシュ）。
   Reuses fkRankFor / FKRankBadge / FKLeafFall from fk-result.jsx (global scope). */

// 通算（lifetime）での到達バッジ。序盤に密、後半はゆるやかに。
const FK_MILESTONES = [
  { id: 'first',  at: 1,  name: 'はじめての食べきり', note: '最初の一品。ここから。' },
  { id: 'three',  at: 3,  name: '3品 食べきり',        note: 'いい入りかた' },
  { id: 'week',   at: 7,  name: 'ムダなし、1週間',     note: '1週間ぶんを使いきり' },
  { id: 'twelve', at: 12, name: '食べきり上手',        note: '習慣になってきた' },
  { id: 'twenty', at: 20, name: 'ムダなしの達人',      note: '冷蔵庫がいつもすっきり' },
  { id: 'forty',  at: 40, name: '食べきりマイスター',  note: 'もう、ムダ知らず' },
];
// prev→next で新たに跨いだ最上位マイルストーン（なければ null）
function fkCrossedMilestone(prev, next) {
  let hit = null;
  for (const m of FK_MILESTONES) if (m.at > prev && m.at <= next) hit = m;
  return hit;
}

// ── 小パーツ ──────────────────────────────────────────────────────
function FKChevron({ dir = 'right', color = 'var(--fk-text-ter)', size = 14 }) {
  const d = dir === 'left' ? 'M9 1L3 7l6 6' : dir === 'right' ? 'M3 1l6 6-6 6' : 'M1 4l6 6 6-6';
  return <svg width={size} height={size} viewBox="0 0 12 14" style={{ flexShrink: 0 }}>
    <path d={d} stroke={color} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}
function FKLock({ color = 'var(--fk-text-ter)', size = 15 }) {
  return <svg width={size} height={size} viewBox="0 0 20 20" fill="none">
    <rect x="4.5" y="8.5" width="11" height="8" rx="2" stroke={color} strokeWidth="1.7" />
    <path d="M7 8.5V6.5a3 3 0 0 1 6 0v2" stroke={color} strokeWidth="1.7" strokeLinecap="round" /></svg>;
}

// ── 週次カード（ホームにそっと） ───────────────────────────────────
function FKWeeklyCard({ count, tone, accent, onOpen, onDismiss }) {
  const label = tone === 'simple' ? '先週のふりかえり' : tone === 'cheer' ? '先週もおつかれさま！' : '先週のふりかえり';
  return (
    <div onClick={onOpen} style={{
      position: 'relative', cursor: 'pointer', marginBottom: 14,
      display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px 14px 18px',
      borderRadius: 20, background: 'linear-gradient(135deg, var(--fk-brand-soft), var(--fk-surface))',
      border: '1px solid var(--fk-hair)',
    }}>
      <span style={{
        width: 42, height: 42, borderRadius: '50%', flexShrink: 0, background: 'var(--fk-brand)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}><FKLeaf color="#fff" size={20} /></span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12.5, fontWeight: 800, color: 'var(--fk-brand-ink)', letterSpacing: 0.3 }}>{label}</div>
        <div style={{ fontSize: 16.5, fontWeight: 800, color: 'var(--fk-text)', marginTop: 1 }}>
          {count}品 食べきり<span style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-sec)' }}>　タップで見る</span>
        </div>
      </div>
      <FKChevron />
      <button onClick={(e) => { e.stopPropagation(); onDismiss(); }} aria-label="閉じる" style={{
        position: 'absolute', top: 8, right: 8, width: 24, height: 24, border: 'none', cursor: 'pointer',
        background: 'transparent', color: 'var(--fk-text-ter)', display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 2l8 8M10 2l-8 8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
      </button>
    </div>
  );
}

// ── 節目の祝祭（特に初日に効く報酬） ───────────────────────────────
function FKMilestoneCelebrate({ milestone, dark, accent, tone, onClose }) {
  const first = milestone.id === 'first';
  const head = first
    ? (tone === 'cheer' ? 'やったね、はじめての一品！' : tone === 'simple' ? 'はじめての食べきり' : 'はじめての食べきり！')
    : (tone === 'cheer' ? 'たっせい！' : tone === 'simple' ? '達成' : 'あたらしい記録');
  const cta = tone === 'simple' ? 'OK' : first ? 'この調子でいく' : 'つづける';
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 340, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 26 }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.42)', backdropFilter: 'blur(2px)', animation: 'fkScrimIn .25s ease' }} />
      <FKLeafFall accent={accent} />
      <div style={{
        position: 'relative', width: '100%', maxWidth: 320, borderRadius: 28, padding: '30px 26px 24px',
        background: 'var(--fk-bg2)', textAlign: 'center', boxShadow: '0 18px 50px rgba(20,14,6,0.4)',
        animation: 'fkResultPop .5s cubic-bezier(.2,.8,.3,1.2) both',
      }}>
        <div style={{
          width: 84, height: 84, borderRadius: '50%', margin: '0 auto 18px', position: 'relative',
          background: 'var(--fk-brand-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <span style={{
            position: 'absolute', inset: 0, borderRadius: '50%',
            background: `radial-gradient(circle, color-mix(in oklab, ${accent} 30%, transparent), transparent 70%)`,
            animation: 'fkRingPop .7s cubic-bezier(.2,.7,.3,1) .15s both',
          }} />
          <span style={{
            width: 58, height: 58, borderRadius: '50%', background: 'var(--fk-brand)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            animation: 'fkResultBadge .55s cubic-bezier(.2,.8,.3,1.3) .1s both',
          }}><FKLeaf color="#fff" size={30} /></span>
        </div>
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-brand-ink)', letterSpacing: 0.6, animation: 'fkResultChip .4s ease .25s both' }}>{head}</div>
        <div style={{ fontSize: 23, fontWeight: 800, color: 'var(--fk-text)', marginTop: 5, animation: 'fkResultChip .45s ease .32s both' }}>{milestone.name}</div>
        <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--fk-text-sec)', marginTop: 8, lineHeight: 1.6, animation: 'fkResultChip .45s ease .4s both' }}>
          {first ? 'ムダにせず食べきれました。\nこの小さな積み重ねが、続いていきます。' : milestone.note}
        </div>
        <button onClick={onClose} style={{
          width: '100%', border: 'none', cursor: 'pointer', borderRadius: 16, padding: '14px 0', marginTop: 22,
          background: accent, color: '#fff', fontSize: 15.5, fontWeight: 800, fontFamily: '"M PLUS Rounded 1c", system-ui',
          boxShadow: `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)`,
          animation: 'fkResultChip .45s ease .5s both',
        }}>{cta}</button>
      </div>
    </div>
  );
}

// ── ふりかえり画面（常設・プル型）────────────────────────────────
function FKReview({ savedCount, lifetime, streak, weeklyCount = 6, prevWeekCount = 4, showWeekly = true, dark, accent, tone, onClose }) {
  const rank = fkRankFor(lifetime);
  const nextIdx = FK_MILESTONES.findIndex((m) => lifetime < m.at);
  const allDone = nextIdx === -1;

  const Step = ({ m, idx }) => {
    const done = lifetime >= m.at;
    const isNext = !done && idx === nextIdx;
    const prevAt = idx === 0 ? 0 : FK_MILESTONES[idx - 1].at;
    const prog = isNext ? Math.max(0, Math.min(1, (lifetime - prevAt) / (m.at - prevAt))) : 0;
    const last = idx === FK_MILESTONES.length - 1;
    return (
      <div style={{ display: 'flex', gap: 13, alignItems: 'flex-start' }}>
        {/* rail */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
          <div style={{
            width: 34, height: 34, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: done ? 'var(--fk-brand)' : isNext ? 'var(--fk-brand-soft)' : 'var(--fk-surface2)',
            boxShadow: isNext ? `inset 0 0 0 2px ${accent}` : 'none',
          }}>
            {done ? <FKCheck color="#fff" size={19} /> : isNext ? <FKLeaf color="var(--fk-brand-ink)" size={16} /> : <FKLock />}
          </div>
          {!last && <div style={{ width: 2, flex: 1, minHeight: 30, background: done ? 'var(--fk-brand)' : 'var(--fk-hair)', marginTop: 2 }} />}
        </div>
        {/* body */}
        <div style={{ flex: 1, paddingBottom: 18, opacity: done || isNext ? 1 : 0.5 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--fk-text)' }}>{m.name}</span>
            {done && <span style={{ fontSize: 11, fontWeight: 800, color: 'var(--fk-brand-ink)', background: 'var(--fk-brand-soft)', borderRadius: 999, padding: '2px 8px' }}>達成</span>}
          </div>
          <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-sec)', marginTop: 2 }}>
            {isNext ? `あと${m.at - lifetime}品で達成` : m.note}
          </div>
          {isNext && (
            <div style={{ marginTop: 8, height: 7, borderRadius: 99, background: 'var(--fk-surface2)', overflow: 'hidden' }}>
              <div style={{ width: `${prog * 100}%`, height: '100%', borderRadius: 99, background: accent, transition: 'width .5s ease' }} />
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 320, background: 'var(--fk-bg)', display: 'flex', flexDirection: 'column' }}>
      {/* top bar */}
      <div style={{ flexShrink: 0, padding: '52px 12px 8px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <button onClick={onClose} aria-label="戻る" style={{
          width: 38, height: 38, border: 'none', background: 'transparent', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fk-text)',
        }}><FKChevron dir="left" color="var(--fk-text)" size={17} /></button>
        <span style={{ fontSize: 17, fontWeight: 800, color: 'var(--fk-text)' }}>ふりかえり</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 28px' }}>
        {/* 現状の評価 hero */}
        <div style={{
          padding: '20px 20px 22px', borderRadius: 24, textAlign: 'center',
          background: 'linear-gradient(160deg, var(--fk-brand-soft), var(--fk-surface))',
          border: '1px solid var(--fk-hair)',
        }}>
          <FKRankBadge tier={rank} accent={accent} />
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--fk-text-sec)', marginTop: 14 }}>いまの記録</div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 3, color: 'var(--fk-brand-ink)', marginTop: 2 }}>
            <span style={{ fontSize: 46, fontWeight: 800, letterSpacing: 0.5 }}>{lifetime}</span>
            <span style={{ fontSize: 18, fontWeight: 800 }}>品 食べきり</span>
          </div>
          <div style={{ display: 'flex', gap: 9, justifyContent: 'center', marginTop: 14 }}>
            <span style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text)', background: 'var(--fk-surface)', borderRadius: 999, padding: '6px 13px', border: '1px solid var(--fk-hair)' }}>今月 {savedCount}品</span>
            <span style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text)', background: 'var(--fk-surface)', borderRadius: 999, padding: '6px 13px', border: '1px solid var(--fk-hair)' }}>連続 {streak}ヶ月</span>
          </div>
        </div>

        {/* 先週のふりかえり（ホームから移設） */}
        {showWeekly && (
          <React.Fragment>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', margin: '26px 2px 14px' }}>
              <span style={{ fontSize: 16.5, fontWeight: 800, color: 'var(--fk-text)' }}>先週のふりかえり</span>
              <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-ter)' }}>6/1 – 6/7</span>
            </div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 15, padding: '16px 18px',
              borderRadius: 22, background: 'var(--fk-surface)', border: '1px solid var(--fk-hair)',
            }}>
              <span style={{
                width: 46, height: 46, borderRadius: '50%', flexShrink: 0, background: 'var(--fk-brand)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}><FKLeaf color="#fff" size={22} /></span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, color: 'var(--fk-brand-ink)' }}>
                  <span style={{ fontSize: 26, fontWeight: 800, letterSpacing: 0.3 }}>{weeklyCount}</span>
                  <span style={{ fontSize: 15, fontWeight: 800 }}>品 食べきり</span>
                </div>
                <div style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-sec)', marginTop: 1 }}>
                  {weeklyCount > prevWeekCount
                    ? `先々週より ＋${weeklyCount - prevWeekCount}品。いいリズムです`
                    : tone === 'cheer' ? 'マイペースでつづいています！' : 'マイペースでつづいています'}
                </div>
              </div>
              {weeklyCount > prevWeekCount &&
                <span style={{
                  display: 'inline-flex', alignItems: 'center', gap: 3, flexShrink: 0,
                  fontSize: 12.5, fontWeight: 800, color: 'var(--fk-brand-ink)',
                  background: 'var(--fk-brand-soft)', borderRadius: 999, padding: '5px 11px',
                }}>
                  <svg width="11" height="11" viewBox="0 0 16 16"><path d="M8 13V3M8 3l-4 4M8 3l4 4" stroke="currentColor" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
                  ＋{weeklyCount - prevWeekCount}
                </span>
              }
            </div>
          </React.Fragment>
        )}

        {/* ごほうびの道のり */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', margin: '26px 2px 14px' }}>
          <span style={{ fontSize: 16.5, fontWeight: 800, color: 'var(--fk-text)' }}>つぎのごほうび</span>
          <span style={{ fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-ter)' }}>
            {allDone ? 'ぜんぶ達成！' : `${FK_MILESTONES.filter((m) => lifetime >= m.at).length} / ${FK_MILESTONES.length}`}
          </span>
        </div>
        <div style={{ padding: '20px 18px 6px', borderRadius: 22, background: 'var(--fk-surface)', border: '1px solid var(--fk-hair)' }}>
          {FK_MILESTONES.map((m, i) => <Step key={m.id} m={m} idx={i} />)}
        </div>

        <div style={{ textAlign: 'center', fontSize: 13, fontWeight: 700, color: 'var(--fk-text-ter)', marginTop: 22, lineHeight: 1.7, textWrap: 'pretty' }}>
          {tone === 'cheer' ? 'ひとつ食べきるたび、ここが進みます。今日もいい調子！'
            : tone === 'simple' ? '食べきるたびに進みます。'
            : 'ひとつ食べきるたび、少しずつ進みます。あせらず、気楽に。'}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { FK_MILESTONES, fkCrossedMilestone, FKReview, FKMilestoneCelebrate, FKWeeklyCard });
