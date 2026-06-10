/* fk-ui.jsx — shared FreshKeep UI primitives. Exports to window. */

// Colored category icon — soft tinted circle + single-char glyph (no emoji).
function FKIcon({ cat, size = 46, style = {}, dark = false }) {
  if (!cat) return null;
  const bg = dark ?
  `color-mix(in oklab, ${cat.color} 30%, transparent)` :
  `color-mix(in oklab, ${cat.color} 22%, transparent)`;
  const ring = dark ?
  `color-mix(in oklab, ${cat.color} 40%, transparent)` :
  `color-mix(in oklab, ${cat.color} 30%, transparent)`;
  const glyphColor = dark ?
  `color-mix(in oklab, ${cat.color} 58%, #fbf3e3)` :
  `color-mix(in oklab, ${cat.color} 78%, #4a3f2c)`;
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: bg,
      boxShadow: `inset 0 0 0 1.5px ${ring}`,
      ...style
    }}>
      <span style={{
        fontSize: size * 0.42, fontWeight: 800, lineHeight: 1,
        color: glyphColor,
        fontFamily: '"M PLUS Rounded 1c", system-ui'
      }}>{cat.glyph}</span>
    </div>);

}

// Soft urgency pill — warm color temperature, no harsh red.
function FKDayPill({ days, dark, tone, size = 'md' }) {
  const u = window.FKT.fkUrgency(days, dark);
  const label = window.FKT.fkDayLabel(days, tone);
  const pad = size === 'sm' ? '3px 9px' : '5px 12px';
  const fs = size === 'sm' ? 12.5 : 14;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: pad, borderRadius: 999, background: u.pillBg, color: u.pillFg,
      fontSize: fs, fontWeight: 700, whiteSpace: 'nowrap', letterSpacing: 0.2
    }}>
      <span style={{ width: 6, height: 6, borderRadius: 999, background: u.solid }} />
      {label}
    </span>);

}

// Segmented control (rounded), for layout concept / tone switching.
function FKSegmented({ value, options, onChange, dark, accent }) {
  return (
    <div style={{
      display: 'inline-flex', padding: 3, borderRadius: 999, gap: 2,
      background: dark ? 'rgba(255,255,255,0.07)' : 'rgba(70,55,30,0.06)'
    }}>
      {options.map((o) => {
        const on = o.value === value;
        return (
          <button key={o.value} onClick={() => onChange(o.value)} style={{
            border: 'none', cursor: 'pointer', borderRadius: 999,
            padding: '6px 13px', fontSize: 13.5, fontWeight: 700, whiteSpace: 'nowrap',
            fontFamily: '"M PLUS Rounded 1c", system-ui',
            background: on ? dark ? '#3a342a' : '#fffdf8' : 'transparent',
            color: on ? accent || 'var(--fk-text)' : 'var(--fk-text-sec)',
            boxShadow: on ? '0 1px 4px var(--fk-shadow)' : 'none',
            transition: 'all .18s ease'
          }}>{o.label}</button>);

      })}
    </div>);

}

// Swipeable row — drag right = 食べた, left = 捨てた, up (optional onCycle) = 次のカードへ.
function FKSwipe({ children, onAte, onToss, onCycle, onCyclePrev, onTap, accent, dark }) {
  const [dx, setDx] = React.useState(0);
  const [dy, setDy] = React.useState(0);
  const [anim, setAnim] = React.useState(false);
  const [gone, setGone] = React.useState(null); // 'ate' | 'toss'
  const [cycling, setCycling] = React.useState(false);
  const start = React.useRef(null);
  const axis = React.useRef(null);
  const moved = React.useRef(false);
  const downEl = React.useRef(null);
  const TH = 96;
  const THV = 64;

  const onDown = (e) => {
    start.current = { x: e.clientX, y: e.clientY };
    axis.current = null;
    moved.current = false;
    downEl.current = e.target;
    setAnim(false);
    e.currentTarget.setPointerCapture?.(e.pointerId);
  };
  const onMove = (e) => {
    if (!start.current) return;
    let ddx = e.clientX - start.current.x;
    let ddy = e.clientY - start.current.y;
    if (axis.current == null && (Math.abs(ddx) > 6 || Math.abs(ddy) > 6)) {
      axis.current = (onCycle || onCyclePrev) && Math.abs(ddy) > Math.abs(ddx) ? 'v' : 'h';
    }
    if (Math.abs(ddx) > 4 || Math.abs(ddy) > 4) moved.current = true;
    if (axis.current === 'h') {
      if (Math.abs(ddx) > TH) ddx = (ddx > 0 ? 1 : -1) * (TH + (Math.abs(ddx) - TH) * 0.35);
      setDx(ddx);setDy(0);
    } else if (axis.current === 'v') {
      let m = ddy;
      if (m < 0 && !onCycle) m = 0; // up needs onCycle
      if (m > 0 && !onCyclePrev) m = 0; // down needs onCyclePrev
      const abs = Math.abs(m);
      if (abs > THV) m = (m > 0 ? 1 : -1) * (THV + (abs - THV) * 0.4);
      setDy(m);setDx(0);
    }
  };
  const finishH = (dir) => {
    setAnim(true);
    setGone(dir);
    setDx(dir === 'ate' ? 520 : -520);
    setTimeout(() => {dir === 'ate' ? onAte?.() : onToss?.();}, 240);
  };
  const finishCycle = (dir) => {
    setAnim(true);
    setCycling(true);
    setDy(dir === 'next' ? -300 : 300);
    setTimeout(() => {dir === 'next' ? onCycle?.() : onCyclePrev?.();setCycling(false);setAnim(false);setDy(0);}, 280);
  };
  const onUp = () => {
    if (!start.current) return;
    start.current = null;
    setAnim(true);
    if (axis.current === 'h') {
      if (dx > TH) finishH('ate');else
      if (dx < -TH) finishH('toss');else
      setDx(0);
    } else if (axis.current === 'v') {
      if (dy < -THV && onCycle) finishCycle('next');else
      if (dy > THV && onCyclePrev) finishCycle('prev');else
      setDy(0);
    } else if (!moved.current && onTap) {
      // タップ（スワイプでない）— ボタン/入力上では発火させない
      const el = downEl.current;
      if (!(el && el.closest && el.closest('button, input, textarea'))) onTap();
    }
    axis.current = null;
  };

  const showAte = dx > 8;
  const reveal = Math.min(1, Math.abs(dx) / TH);
  const cycleReveal = Math.min(1, Math.abs(dy) / THV);

  return (
    <div style={{
      position: 'relative', borderRadius: 22, overflow: 'hidden',
      maxHeight: gone ? 0 : 360, opacity: gone ? 0 : 1,
      marginBottom: gone ? 0 : 12,
      transition: gone ? 'max-height .32s ease .18s, opacity .25s ease, margin-bottom .32s ease .18s' : 'none'
    }}>
      {/* action backdrops */}
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
        justifyContent: 'space-between', padding: '0 24px',
        background: showAte ?
        `color-mix(in oklab, ${accent} ${18 + reveal * 22}%, transparent)` :
        dark ? 'rgba(150,140,125,0.18)' : 'rgba(120,110,95,0.14)'
      }}>
        <span style={{
          display: 'flex', alignItems: 'center', gap: 8, fontWeight: 800, fontSize: 15,
          color: accent, opacity: showAte ? reveal : 0
        }}>
          <FKCheck color={accent} /> 食べた
        </span>
        <span style={{
          display: 'flex', alignItems: 'center', gap: 8, fontWeight: 700, fontSize: 15,
          color: 'var(--fk-text-sec)', opacity: !showAte && dx < -8 ? reveal : 0
        }}>
          そっと処分 <FKTrash color={'var(--fk-text-sec)'} />
        </span>
      </div>
      {/* up-cycle hint */}
      {(onCycle || onCyclePrev) && Math.abs(dy) > 6 &&
      <div style={{
        position: 'absolute', left: 0, right: 0, textAlign: 'center', zIndex: 3,
        top: dy < 0 ? 8 : 'auto', bottom: dy > 0 ? 8 : 'auto',
        fontSize: 12.5, fontWeight: 800, color: 'var(--fk-brand-ink)', opacity: cycleReveal,
        pointerEvents: 'none'
      }}>{dy < 0 ? '↑ 次の食材へ' : '↓ 前の食材へ'}</div>
      }
      {/* the card */}
      <div
        onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
        style={{
          position: 'relative', touchAction: onCycle || onCyclePrev ? 'none' : 'pan-y',
          transform: `translate(${dx}px, ${dy}px) scale(${cycling ? 0.92 : 1})`,
          opacity: cycling ? 0 : 1,
          transition: anim ? 'transform .27s cubic-bezier(.22,.61,.36,1), opacity .27s ease' : 'none',
          cursor: 'grab'
        }}>
        {children}
      </div>
    </div>);

}

function FKCheck({ color = '#fff', size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none">
      <circle cx="10" cy="10" r="9" fill={color} opacity="0.16" />
      <path d="M5.5 10.5l3 3 6-6.5" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>);

}
function FKTrash({ color = '#888', size = 17 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none">
      <path d="M4 6h12M8 6V4.5h4V6M6 6l.8 9.5h6.4L14 6" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
    </svg>);

}
function FKPlus({ color = '#fff', size = 26 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M12 5v14M5 12h14" stroke={color} strokeWidth="2.6" strokeLinecap="round" />
    </svg>);

}

// 食べた！の控えめな達成演出 — 広がるリング + チェック + 立ちのぼる粒
function FKEatBurst({ accent }) {
  const angles = [-58, -28, 0, 28, 58];
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 6, pointerEvents: 'none',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      animation: 'fkBurstFade .72s ease forwards'
    }}>
      <div style={{
        position: 'absolute', left: '50%', top: '50%', width: 84, height: 84, borderRadius: '50%',
        background: `radial-gradient(circle, color-mix(in oklab, ${accent} 45%, transparent), transparent 70%)`,
        transform: 'translate(-50%,-50%)', animation: 'fkRingPop .66s cubic-bezier(.2,.7,.3,1) forwards'
      }} />
      {angles.map((a, i) =>
      <div key={i} style={{
        position: 'absolute', left: '50%', top: '50%',
        transform: `translate(-50%,-50%) rotate(${a}deg)`, transformOrigin: 'center'
      }}>
          <div style={{
          width: 9, height: 9, borderRadius: '50%',
          background: i % 2 ? accent : 'var(--fk-brand)',
          animation: 'fkSpark .64s ease-out forwards', animationDelay: `${0.03 * i}s`
        }} />
        </div>
      )}
      <div style={{
        position: 'absolute', left: '50%', top: '50%', width: 54, height: 54, borderRadius: '50%',
        background: '#fff', boxShadow: `0 5px 16px color-mix(in oklab, ${accent} 40%, transparent)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        animation: 'fkCheckPop .5s cubic-bezier(.2,.8,.3,1.2) forwards'
      }}>
        <FKCheck color={accent} size={32} />
      </div>
    </div>);

}
function FKLeaf({ color = '#6f8f6a', size = 15 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none">
      <path d="M4 16c0-7 5-11 12-12-1 7-5 11-12 12z" fill={color} />
      <path d="M5 15c3-4 6-6 9-7" stroke="#fff" strokeWidth="1.1" strokeLinecap="round" opacity="0.55" />
    </svg>);

}

// Bottom sheet
// count-up burst (pop + sparkles)
function FKNumSparks({ accent }) {
  const n = 9;
  return (
    <React.Fragment>
      {Array.from({ length: n }).map((_, i) => {
        const a = Math.PI * 2 * i / n + (i % 2 ? 0.3 : 0);
        const dist = 26 + i % 3 * 8;
        const sz = 4 + i % 3 * 2;
        return (
          <span key={i} style={{
            position: 'absolute', left: '50%', top: '50%', width: sz, height: sz, borderRadius: '50%',
            background: i % 2 ? accent : 'var(--fk-brand)', pointerEvents: 'none',
            '--tx': `${Math.cos(a) * dist}px`, '--ty': `${Math.sin(a) * dist}px`,
            animation: `fkNumSpark .6s ease-out forwards`, animationDelay: `${i % 3 * 0.02}s`
          }} />);

      })}
    </React.Fragment>);

}

function FKCountUp({ value, accent, style = {} }) {
  const prev = React.useRef(value);
  const [pulse, setPulse] = React.useState(0);
  React.useEffect(() => {
    if (value > prev.current) setPulse((p) => p + 1);
    prev.current = value;
  }, [value]);
  return (
    <span style={{ position: 'relative', display: 'inline-flex', alignItems: 'baseline' }}>
      <span key={pulse} style={{
        display: 'inline-block', animation: pulse ? 'fkNumPop .5s cubic-bezier(.2,.8,.3,1.4)' : 'none',
        ...style
      }}>{value}</span>
      {pulse > 0 && <FKNumSparks key={'s' + pulse} accent={accent} />}
    </span>);

}

// Bottom sheet
function FKSheet({ open, onClose, children, dark, height = 'auto' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 200, pointerEvents: open ? 'auto' : 'none'
    }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.34)',
        opacity: open ? 1 : 0, transition: 'opacity .28s ease',
        backdropFilter: open ? 'blur(2px)' : 'none'
      }} />
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: 'var(--fk-bg2)', borderRadius: '28px 28px 0 0',
        boxShadow: '0 -8px 40px rgba(20,14,6,0.28)',
        transform: open ? 'translateY(0)' : 'translateY(110%)',
        transition: 'transform .34s cubic-bezier(.22,.7,.3,1)',
        maxHeight: '88%', height, display: 'flex', flexDirection: 'column',
        overflow: 'hidden'
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 10 }}>
          <div style={{ width: 40, height: 5, borderRadius: 99, background: 'var(--fk-hair)' }} />
        </div>
        {children}
      </div>
    </div>);

}

// Achievement / record toast
function FKToast({ toast, accent }) {
  if (!toast) return null;
  const positive = toast.kind === 'ate';
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 118, zIndex: 250,
      display: 'flex', justifyContent: 'center', pointerEvents: 'none'
    }}>
      <div key={toast.id} style={{
        display: 'flex', alignItems: 'center', gap: 11,
        padding: '12px 18px', borderRadius: 999,
        background: positive ? accent : 'var(--fk-surface)',
        color: positive ? '#fff' : 'var(--fk-text)',
        boxShadow: '0 10px 30px rgba(20,14,6,0.28)',
        fontWeight: 700, fontSize: 15,
        animation: 'fkToast 2.4s cubic-bezier(.2,.7,.3,1) forwards'
      }}>
        {positive ?
        <FKCheck color="#fff" size={20} /> :
        <FKTrash color="var(--fk-text-sec)" size={18} />}
        <span>{toast.msg}</span>
      </div>
    </div>);

}

// ── Remaining-amount controls ─────────────────────────────────────
const FK_AMT_STOPS = [
{ label: 'わずか', frac: 0.12 }, { label: '少し', frac: 0.3 }, { label: '半分', frac: 0.5 },
{ label: '多め', frac: 0.72 }, { label: '満タン', frac: 1 }];

function fkNearestStop(f) {return FK_AMT_STOPS.reduce((a, b) => Math.abs(b.frac - f) < Math.abs(a.frac - f) ? b : a);}
function fkFillColor(f) {return f <= 0.22 ? 'var(--fk-accent)' : f <= 0.45 ? 'color-mix(in oklab, var(--fk-accent) 55%, var(--fk-brand))' : 'var(--fk-brand)';}

function FKAmtModeToggle({ mode, setMode }) {
  const opts = [{ k: 'amount', t: 'ざっくり量' }, { k: 'count', t: '個数' }];
  return (
    <div style={{ display: 'flex', gap: 4, padding: 4, background: 'var(--fk-surface2)', borderRadius: 12 }}>
      {opts.map((o) => {
        const on = mode === o.k;
        return (
          <button key={o.k} onClick={() => setMode(o.k)} style={{
            border: 'none', cursor: 'pointer', borderRadius: 9, padding: '6px 14px', fontFamily: 'inherit',
            fontSize: 12.5, fontWeight: 800, color: on ? 'var(--fk-text)' : 'var(--fk-text-sec)',
            background: on ? 'var(--fk-surface)' : 'transparent',
            boxShadow: on ? '0 1px 3px var(--fk-shadow)' : 'none', transition: 'background-color .15s, color .15s'
          }}>{o.t}</button>);
      })}
    </div>);
}

function FKAmtSlider({ frac, setFrac }) {
  const ref = React.useRef(null);
  const snap = React.useCallback((f) => setFrac(fkNearestStop(f).frac), [setFrac]);
  const handle = React.useCallback((x) => {
    const el = ref.current;if (!el) return;
    const r = el.getBoundingClientRect();
    snap(Math.max(0, Math.min(1, (x - r.left) / r.width)));
  }, [snap]);
  const onDown = (e) => {
    e.currentTarget.setPointerCapture?.(e.pointerId);
    handle(e.clientX);
    const move = (ev) => handle(ev.clientX);
    const up = () => {window.removeEventListener('pointermove', move);window.removeEventListener('pointerup', up);};
    window.addEventListener('pointermove', move);window.addEventListener('pointerup', up);
  };
  const cur = fkNearestStop(frac);
  const fc = fkFillColor(frac);
  return (
    <div style={{ padding: '6px 4px 0' }}>
      <div ref={ref} onPointerDown={onDown} style={{ position: 'relative', height: 30, cursor: 'grab', touchAction: 'none', display: 'flex', alignItems: 'center' }}>
        <div style={{ position: 'absolute', left: 6, right: 6, height: 8, borderRadius: 999, background: 'var(--fk-surface2)' }} />
        <div style={{ position: 'absolute', left: 6, width: `calc(${frac} * (100% - 12px))`, height: 8, borderRadius: 999, background: fc, transition: 'width .22s cubic-bezier(.2,.8,.3,1), background .2s' }} />
        {FK_AMT_STOPS.map((s) =>
        <span key={s.label} style={{ position: 'absolute', left: `calc(6px + ${s.frac} * (100% - 12px))`, transform: 'translateX(-50%)', width: 5, height: 5, borderRadius: '50%', background: s.frac <= frac + 0.001 ? '#fff' : 'var(--fk-text-ter)', opacity: 0.7 }} />
        )}
        <div style={{ position: 'absolute', left: `calc(6px + ${frac} * (100% - 12px))`, transform: 'translateX(-50%)', width: 28, height: 28, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 7px rgba(0,0,0,0.22)', border: '2px solid ' + fc, transition: 'left .22s cubic-bezier(.2,.8,.3,1)' }} />
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12 }}>
        {FK_AMT_STOPS.map((s) =>
        <button key={s.label} onClick={() => setFrac(s.frac)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: 'inherit', padding: 0,
          fontSize: 12, fontWeight: cur.label === s.label ? 800 : 700, color: cur.label === s.label ? fc : 'var(--fk-text-ter)', transition: 'color .2s' }}>{s.label}</button>
        )}
      </div>
    </div>);
}

function FKAmtCount({ n, setN, unit, context, total }) {
  const sbtn = { width: 42, height: 42, borderRadius: 13, border: 'none', cursor: 'pointer', fontSize: 23, fontWeight: 700, color: 'var(--fk-text)', background: 'var(--fk-surface2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'inherit', flexShrink: 0 };
  const isEdit = context === 'edit';
  const added = isEdit ? Math.max(0, n - total) : 0;
  const consumed = isEdit ? Math.max(0, total - n) : 0;
  const pipCount = isEdit ? Math.min(Math.max(total, n), 12) : Math.min(n, 12);
  const overflow = n > 12;
  const pipFill = isEdit ? fkFillColor(total ? Math.min(1, n / total) : 1) : fkFillColor(0.7);
  return (
    <div style={{ padding: '4px 0 0' }}>
      <div style={{ display: 'flex', gap: 7, justifyContent: 'center', marginBottom: 14, flexWrap: 'wrap', maxWidth: 250, marginLeft: 'auto', marginRight: 'auto' }}>
        {Array.from({ length: pipCount }).map((_, i) => {
          const full = i < n;
          const isAdded = isEdit && i >= total;
          return (
            <button key={i} onClick={() => setN(i + 1 === n ? i : i + 1)} style={{ width: 26, height: 26, borderRadius: '50%', cursor: 'pointer', border: 'none', background: full ? isAdded ? fkFillColor(1) : pipFill : 'var(--fk-surface2)', boxShadow: full ? isAdded ? 'inset 0 0 0 2px color-mix(in oklab, ' + fkFillColor(1) + ' 65%, #fff)' : 'none' : 'inset 0 0 0 2px var(--fk-hair)', transition: 'background .15s' }} />);
        })}
        {overflow && <span style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-sec)', alignSelf: 'center' }}>…</span>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
        <button onClick={() => setN(Math.max(0, n - 1))} style={sbtn}>−</button>
        <div style={{ minWidth: 96, textAlign: 'center' }}>
          <span style={{ fontSize: 34, fontWeight: 800 }}>{n}</span>
          {isEdit && n <= total && <span style={{ fontSize: 17, fontWeight: 700, color: 'var(--fk-text-ter)' }}> / {total}</span>}
          <span style={{ fontSize: 16, fontWeight: 700, color: 'var(--fk-text-sec)' }}> {unit}</span>
        </div>
        <button onClick={() => setN(n + 1)} style={sbtn}>＋</button>
      </div>
      {isEdit &&
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, marginTop: 11, fontSize: 12, fontWeight: 700, color: added > 0 ? 'var(--fk-brand-ink)' : 'var(--fk-text-ter)' }}>
        <span style={{ width: 14, height: 14, borderRadius: '50%', background: added > 0 ? fkFillColor(1) : 'var(--fk-surface2)', boxShadow: added > 0 ? 'inset 0 0 0 2px color-mix(in oklab, ' + fkFillColor(1) + ' 65%, #fff)' : 'inset 0 0 0 2px var(--fk-hair)' }} />
        {added > 0 ? `＋${added}${unit}（初期 ${total}${unit}）` : consumed > 0 ? `使った分 ${consumed}${unit}` : 'まだ減っていません'}
      </div>}
    </div>);
}

// Composite: the full remaining-amount section for add/edit sheets
function FKAmtSection({ amtMode, setAmtMode, frac, setFrac, qty, setQty, unit, context, qtyTotal }) {
  const isAdd = context === 'add';
  const sub = amtMode === 'amount' ?
  isAdd ? 'だいたいでOK' : 'いま、どのくらい？' :
  isAdd ? 'いくつ買った？' : 'のこりはいくつ？';
  return (
    <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '14px 16px 16px', marginBottom: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 13 }}>
        <div>
          <div style={{ fontSize: 15.5, fontWeight: 700, color: 'var(--fk-text)' }}>残量</div>
          <div style={{ fontSize: 12.5, color: 'var(--fk-text-ter)', fontWeight: 600 }}>{sub}</div>
        </div>
        <FKAmtModeToggle mode={amtMode} setMode={setAmtMode} />
      </div>
      {amtMode === 'amount' ?
      <FKAmtSlider frac={frac} setFrac={setFrac} /> :
      <FKAmtCount n={qty} setN={setQty} unit={unit} context={context} total={qtyTotal} />}
    </div>);
}

// Tiny remaining-amount indicator for home list rows
function FKAmtIndicator({ item, size = 34 }) {
  if (!item.amtMode) return null;
  if (item.amtMode === 'amount') {
    const fc = fkFillColor(item.amt);
    return (
      <div style={{ width: size, height: 6, borderRadius: 999, background: 'var(--fk-surface2)', overflow: 'hidden', flexShrink: 0 }}>
        <div style={{ width: `${item.amt * 100}%`, height: '100%', borderRadius: 999, background: fc }} />
      </div>);
  }
  // count mode: mini pips
  const total = item.qtyTotal || item.qty;
  const show = Math.min(total, 6);
  return (
    <div style={{ display: 'flex', gap: 3, flexShrink: 0 }}>
      {Array.from({ length: show }).map((_, i) =>
      <span key={i} style={{ width: 6, height: 6, borderRadius: '50%', background: i < item.qty ? fkFillColor(total ? item.qty / total : 1) : 'var(--fk-surface2)', boxShadow: i < item.qty ? 'none' : 'inset 0 0 0 1px var(--fk-hair)' }} />
      )}
      {total > 6 && <span style={{ fontSize: 9, fontWeight: 800, color: 'var(--fk-text-ter)', lineHeight: 1 }}>…</span>}
    </div>);
}

Object.assign(window, {
  FKIcon, FKDayPill, FKSegmented, FKSwipe, FKCheck, FKTrash, FKPlus, FKLeaf, FKEatBurst, FKCountUp, FKSheet, FKToast,
  FKAmtModeToggle, FKAmtSlider, FKAmtCount, FKAmtSection, FKAmtIndicator, fkFillColor, fkNearestStop
});