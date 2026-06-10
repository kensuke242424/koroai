/* fk-digest.jsx — Morning digest: lock-screen push + in-app briefing.
   Tone: batched once in the morning, action-proposal, never guilt-tripping. */

const FKdcat = window.FKD.fkCat;

// small app icon (rounded square, brand bg + check)
function FKAppMark({ size = 30, radius }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: radius || size * 0.28, flexShrink: 0,
      background: 'var(--fk-brand)', display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: '0 1px 3px rgba(0,0,0,0.18)',
    }}>
      <FKCheck color="#fff" size={size * 0.6} />
    </div>
  );
}

// derive the morning digest from inventory
function fkBuildDigest(items, tone) {
  const hero = items.filter(it => it.perishable && it.days <= 6).sort((a, b) => a.days - b.days);
  const today = hero.filter(it => it.days <= 0);
  const tmrw = hero.filter(it => it.days === 1);
  const soon = hero.filter(it => it.days >= 2 && it.days <= 3);
  const urgent = [...today, ...tmrw, ...soon];

  const verb = (d) => (
    tone === 'simple' ? (d <= 0 ? '今日中' : d === 1 ? '明日まで' : `あと${d}日`)
    : tone === 'cheer' ? (d <= 0 ? 'きょうが食べどき' : d === 1 ? 'そろそろ' : `あと${d}日`)
    : (d <= 0 ? '今日のうちに' : d === 1 ? 'あすまでに' : `あと${d}日`)
  );

  let lead, sub;
  if (today.length) {
    lead = tone === 'simple' ? `今日中：${today.length}品`
      : tone === 'cheer' ? `きょうが食べごろ、${today.length}品！`
      : `今日のうちに食べきりたいものが ${today.length}品`;
    sub = today.map(i => i.name).join('・');
  } else if (tmrw.length) {
    lead = tone === 'simple' ? `明日まで：${tmrw.length}品`
      : tone === 'cheer' ? `あすが食べごろ、${tmrw.length}品`
      : `あすが食べどきのものが ${tmrw.length}品`;
    sub = tmrw.map(i => i.name).join('・');
  } else if (soon.length) {
    lead = tone === 'cheer' ? `そろそろのものが ${soon.length}品` : `近いうちに食べたいものが ${soon.length}品`;
    sub = soon.map(i => i.name).join('・');
  } else {
    lead = tone === 'cheer' ? '急ぎはなし、上手に使えてます！' : '今日は急ぎの食材はありません';
    sub = 'ゆっくりどうぞ。';
  }

  // a single gentle cooking nudge (action proposal, not a command)
  let nudge = null;
  const pick = today[0] || tmrw[0];
  if (pick) {
    nudge = tone === 'simple' ? `${pick.name}を使い切る`
      : tone === 'cheer' ? `${pick.name}、今日おいしく食べきろう！`
      : `${pick.name}、今日のうちに使い切れます`;
  }
  return { hero, today, tmrw, soon, urgent, verb, lead, sub, nudge };
}

// ── Lock-screen push notification ────────────────────────────────
function FKLockScreen({ items, dark, tone, accent, onOpen, onClose }) {
  const dg = fkBuildDigest(items, tone);
  const now = new Date();
  const clock = dark ? '#f4ede1' : '#46402f';
  const wallpaper = dark
    ? 'linear-gradient(168deg, #322a1d 0%, #221c12 55%, #181309 100%)'
    : 'linear-gradient(168deg, #f6ecdb 0%, #ecdcc6 55%, #e0cdb2 100%)';
  const cardBg = dark ? 'rgba(58,52,43,0.72)' : 'rgba(252,249,243,0.82)';
  const cardText = dark ? '#f4ede1' : '#3a342b';
  const cardSec = dark ? 'rgba(244,237,225,0.7)' : 'rgba(58,52,43,0.62)';

  const title = tone === 'simple' ? dg.lead
    : `おはようございます。${dg.lead}`;

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 320, background: wallpaper, overflow: 'hidden' }}>
      {/* clock + date */}
      <div style={{ paddingTop: 92, textAlign: 'center', color: clock }}>
        <div style={{ fontSize: 18, fontWeight: 600, letterSpacing: 1, opacity: 0.85 }}>
          {now.getMonth() + 1}月{now.getDate()}日（{['日','月','火','水','木','金','土'][now.getDay()]}）
        </div>
        <div style={{ fontSize: 88, fontWeight: 700, lineHeight: 1.04, letterSpacing: 1, marginTop: 2 }}>7:30</div>
      </div>

      {/* notification stack */}
      <div style={{ position: 'absolute', left: 12, right: 12, bottom: 96 }}>
        {/* faint stacked card behind */}
        <div style={{
          position: 'absolute', left: 14, right: 14, top: -10, height: 40, borderRadius: 22,
          background: cardBg, opacity: 0.5,
        }} />
        <div style={{
          position: 'absolute', left: 7, right: 7, top: -5, height: 44, borderRadius: 22,
          background: cardBg, opacity: 0.75,
        }} />
        <button onClick={onOpen} style={{
          position: 'relative', width: '100%', textAlign: 'left', cursor: 'pointer',
          border: 'none', borderRadius: 24, padding: 16, background: cardBg,
          backdropFilter: 'blur(20px) saturate(150%)', WebkitBackdropFilter: 'blur(20px) saturate(150%)',
          boxShadow: '0 6px 22px rgba(20,14,6,0.18)',
          fontFamily: '"M PLUS Rounded 1c", system-ui',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 9 }}>
            <FKAppMark size={26} radius={7} />
            <span style={{ fontSize: 14, fontWeight: 800, color: cardText, letterSpacing: 0.3 }}>ころあい</span>
            <span style={{ marginLeft: 'auto', fontSize: 12.5, color: cardSec, fontWeight: 600 }}>今朝</span>
          </div>
          <div style={{ fontSize: 15.5, fontWeight: 800, color: cardText, lineHeight: 1.4, marginBottom: 4 }}>{title}</div>
          <div style={{ fontSize: 14, color: cardSec, fontWeight: 600, lineHeight: 1.45 }}>
            {dg.today.length === 1 && dg.nudge ? dg.nudge : dg.sub}
          </div>
        </button>
        <div style={{ textAlign: 'center', marginTop: 16, color: clock, opacity: 0.6, fontSize: 12.5, fontWeight: 600 }}>
          タップしてまとめを開く
        </div>
      </div>

      {/* dismiss (tap clock area) */}
      <button onClick={onClose} aria-label="閉じる" style={{
        position: 'absolute', top: 80, left: 0, right: 0, height: 200,
        background: 'transparent', border: 'none', cursor: 'pointer',
      }} />
    </div>
  );
}

// ── In-app morning briefing (rendered inside a sheet) ────────────
function FKDigest({ items, dark, tone, accent, onCook, onClose }) {
  const dg = fkBuildDigest(items, tone);
  const greeting = tone === 'cheer' ? 'おはよう！きょうも、いい一日に' : tone === 'simple' ? '今朝のまとめ' : 'おはようございます';
  const show = dg.urgent.slice(0, 4);

  return (
    <div style={{ padding: '8px 22px 26px', overflowY: 'auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '6px 0 4px' }}>
        <FKAppMark size={30} />
        <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--fk-text-sec)' }}>{greeting}</span>
        <span style={{ marginLeft: 'auto', fontSize: 12.5, fontWeight: 700, color: 'var(--fk-text-ter)' }}>今朝 7:30</span>
      </div>

      <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--fk-text)', lineHeight: 1.4, margin: '8px 0 4px', textWrap: 'pretty' }}>
        {dg.lead}{dg.today.length || dg.tmrw.length ? '。' : ''}
      </div>
      {dg.nudge && (
        <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--fk-brand-ink)', marginBottom: 16 }}>
          {dg.nudge}
        </div>
      )}

      {show.length > 0 ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginBottom: 20 }}>
          {show.map(it => {
            const cat = FKdcat(it.catId);
            const u = window.FKT.fkUrgency(it.days, dark);
            return (
              <div key={it.id} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px',
                background: 'var(--fk-surface)', borderRadius: 16,
              }}>
                <FKIcon cat={cat} size={40} dark={dark} />
                <span style={{ flex: 1, fontSize: 16, fontWeight: 700, color: 'var(--fk-text)' }}>{it.name}</span>
                <span style={{
                  fontSize: 13.5, fontWeight: 800, color: u.pillFg,
                  background: u.pillBg, borderRadius: 999, padding: '4px 11px',
                }}>{dg.verb(it.days)}</span>
              </div>
            );
          })}
        </div>
      ) : (
        <div style={{
          padding: '22px', textAlign: 'center', color: 'var(--fk-text-sec)',
          background: 'var(--fk-surface)', borderRadius: 18, marginBottom: 20, fontWeight: 600,
        }}>{dg.sub}</div>
      )}

      <button onClick={onCook} style={{
        width: '100%', border: 'none', cursor: 'pointer', borderRadius: 16, padding: '15px 0',
        background: accent, color: '#fff', fontWeight: 800, fontSize: 16,
        fontFamily: '"M PLUS Rounded 1c", system-ui', marginBottom: 10,
        boxShadow: `0 6px 18px color-mix(in oklab, ${accent} 35%, transparent)`,
      }}>{show.length ? '今日のごはんを考える' : 'リストを見る'}</button>
      <button onClick={onClose} style={{
        width: '100%', border: 'none', cursor: 'pointer', borderRadius: 16, padding: '12px 0',
        background: 'transparent', color: 'var(--fk-text-sec)', fontWeight: 700, fontSize: 14.5,
        fontFamily: '"M PLUS Rounded 1c", system-ui',
      }}>あとで</button>
    </div>
  );
}

Object.assign(window, { FKAppMark, fkBuildDigest, FKLockScreen, FKDigest });
