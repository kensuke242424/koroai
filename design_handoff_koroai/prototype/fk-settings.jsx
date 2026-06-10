/* fk-settings.jsx — 設定画面。FKApp から overlay として開く。
   通知・表示・データ・アプリ情報の4セクション。Exports FKSettings to window. */

function FKSettingsRow({ icon, label, sub, right, onClick, danger }) {
  return (
    <button onClick={onClick} style={{
      width: '100%', border: 'none', cursor: onClick ? 'pointer' : 'default',
      background: 'transparent', padding: '14px 4px', display: 'flex', alignItems: 'center', gap: 13,
      fontFamily: '"M PLUS Rounded 1c", system-ui', textAlign: 'left',
      borderBottom: '1px solid var(--fk-hair)',
    }}>
      {icon && <span style={{ width: 34, height: 34, borderRadius: 10, flexShrink: 0,
        background: danger ? 'color-mix(in oklab, var(--fk-accent) 16%, transparent)' : 'var(--fk-surface2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: danger ? 'var(--fk-accent)' : 'var(--fk-text-sec)',
      }}>{icon}</span>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: danger ? 'var(--fk-accent)' : 'var(--fk-text)' }}>{label}</div>
        {sub && <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--fk-text-ter)', marginTop: 1 }}>{sub}</div>}
      </div>
      {right || (onClick && <svg width="8" height="14" viewBox="0 0 8 14" style={{ flexShrink: 0, opacity: 0.4 }}>
        <path d="M1 1l6 6-6 6" stroke="var(--fk-text-ter)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>)}
    </button>
  );
}

function FKSettingsToggle({ icon, label, sub, value, onChange, danger }) {
  return (
    <div style={{
      width: '100%', padding: '14px 4px', display: 'flex', alignItems: 'center', gap: 13,
      borderBottom: '1px solid var(--fk-hair)',
    }}>
      {icon && <span style={{ width: 34, height: 34, borderRadius: 10, flexShrink: 0,
        background: danger ? 'color-mix(in oklab, var(--fk-accent) 16%, transparent)' : 'var(--fk-surface2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', color: danger ? 'var(--fk-accent)' : 'var(--fk-text-sec)',
      }}>{icon}</span>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fk-text)' }}>{label}</div>
        {sub && <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--fk-text-ter)', marginTop: 1 }}>{sub}</div>}
      </div>
      <button onClick={() => onChange(!value)} style={{
        width: 50, height: 30, borderRadius: 999, border: 'none', cursor: 'pointer', padding: 2,
        background: value ? 'var(--fk-brand)' : 'var(--fk-surface2)', transition: 'background .2s',
        display: 'flex', alignItems: 'center',
      }}>
        <span style={{
          width: 26, height: 26, borderRadius: '50%', background: '#fff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
          transform: value ? 'translateX(20px)' : 'translateX(0)', transition: 'transform .2s',
        }} />
      </button>
    </div>
  );
}

function FKSettingsSelect({ icon, label, value, options, onChange }) {
  return (
    <div style={{
      width: '100%', padding: '14px 4px', display: 'flex', alignItems: 'center', gap: 13,
      borderBottom: '1px solid var(--fk-hair)',
    }}>
      {icon && <span style={{ width: 34, height: 34, borderRadius: 10, flexShrink: 0,
        background: 'var(--fk-surface2)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: 'var(--fk-text-sec)',
      }}>{icon}</span>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--fk-text)' }}>{label}</div>
      </div>
      <div style={{ display: 'flex', gap: 4, padding: 3, background: 'var(--fk-surface2)', borderRadius: 10 }}>
        {options.map((o) => {
          const on = value === o;
          return (
            <button key={o} onClick={() => onChange(o)} style={{
              border: 'none', cursor: 'pointer', borderRadius: 8, padding: '5px 11px', fontFamily: 'inherit',
              fontSize: 12, fontWeight: 800, color: on ? 'var(--fk-text)' : 'var(--fk-text-ter)',
              background: on ? 'var(--fk-surface)' : 'transparent',
              boxShadow: on ? '0 1px 3px var(--fk-shadow)' : 'none', transition: 'all .15s',
            }}>{o}</button>
          );
        })}
      </div>
    </div>
  );
}

// SVG icon helpers
const IcBell = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><path d="M10 2a5 5 0 0 0-5 5v3l-1.5 2.5h13L15 10V7a5 5 0 0 0-5-5z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /><path d="M8 16.5a2 2 0 0 0 4 0" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
const IcClock = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="10" r="8" stroke="currentColor" strokeWidth="1.7" /><path d="M10 5.5V10l3 2" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
const IcPalette = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="10" r="8" stroke="currentColor" strokeWidth="1.7" /><circle cx="7" cy="8" r="1.5" fill="currentColor" /><circle cx="13" cy="8" r="1.5" fill="currentColor" /><circle cx="10" cy="13" r="1.5" fill="currentColor" /></svg>;
const IcMoon = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><path d="M17 11.5A7.5 7.5 0 1 1 8.5 3a5.5 5.5 0 0 0 8.5 8.5z" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" /></svg>;
const IcTone = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><path d="M3 14h14M3 10h10M3 6h6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
const IcTrash = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><path d="M4 6h12M8 6V4h4v2M6 6v10a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2V6" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
const IcInfo = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="10" r="8" stroke="currentColor" strokeWidth="1.7" /><path d="M10 9v5M10 6.5v.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>;
const IcMail = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><rect x="2" y="4" width="16" height="12" rx="3" stroke="currentColor" strokeWidth="1.7" /><path d="M2 7l8 5 8-5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
const IcHelp = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="10" r="8" stroke="currentColor" strokeWidth="1.7" /><path d="M7.5 7.5a2.5 2.5 0 0 1 4.6 1.3c0 1.7-2.6 1.7-2.6 3.2M10 15v.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;
const IcLeaf = () => <FKLeaf size={17} />;
const IcCalendar = () => <svg width="17" height="17" viewBox="0 0 20 20" fill="none"><rect x="3" y="4" width="14" height="13" rx="3" stroke="currentColor" strokeWidth="1.7" /><path d="M3 9h14M7 2v4M13 2v4" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" /></svg>;

function FKSettings({ dark, accent, tone, theme, palette, showSaved, showMonthly, onChangeSetting, onReset, onReplayOnboarding, onClose }) {
  const [confirmReset, setConfirmReset] = React.useState(false);

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 310, background: 'var(--fk-bg)', display: 'flex', flexDirection: 'column' }}>
      {/* top bar */}
      <div style={{ flexShrink: 0, padding: '52px 12px 8px', display: 'flex', alignItems: 'center', gap: 4 }}>
        <button onClick={onClose} aria-label="戻る" style={{
          width: 38, height: 38, border: 'none', background: 'transparent', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fk-text)',
        }}>
          <svg width="17" height="17" viewBox="0 0 12 14">
            <path d="M9 1L3 7l6 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </button>
        <span style={{ fontSize: 17, fontWeight: 800, color: 'var(--fk-text)' }}>設定</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 40px' }}>
        {/* 通知 */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', letterSpacing: 0.6, margin: '18px 4px 8px' }}>通知</div>
        <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '2px 14px' }}>
          <FKSettingsToggle icon={<IcBell />} label="プッシュ通知" sub="期限が近づいたらお知らせ" value={true} onChange={() => {}} />
          <FKSettingsRow icon={<IcClock />} label="朝のまとめ通知" sub="毎朝 8:00" onClick={() => {}} right={<span style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-sec)' }}>8:00</span>} />
          <FKSettingsRow icon={<IcCalendar />} label="通知のタイミング" sub="期限の何日前に知らせるか" onClick={() => {}} right={<span style={{ fontSize: 13, fontWeight: 700, color: 'var(--fk-text-sec)' }}>1日前</span>} />
        </div>

        {/* 表示 */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', letterSpacing: 0.6, margin: '24px 4px 8px' }}>表示</div>
        <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '2px 14px' }}>
          <FKSettingsSelect icon={<IcMoon />} label="テーマ" value={theme || 'OS設定'} options={['OS設定', 'ライト', 'ナイト']} onChange={(v) => onChangeSetting('theme', v)} />
        </div>

        {/* ふりかえり */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', letterSpacing: 0.6, margin: '24px 4px 8px' }}>ふりかえり</div>
        <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '2px 14px' }}>
          <FKSettingsToggle icon={<IcLeaf />} label="食べきり記録を表示" sub="ホームに達成カードを出す" value={showSaved} onChange={(v) => onChangeSetting('showSaved', v)} />
          <FKSettingsToggle label="月替わりリザルトを表示" sub="月初に先月の結果をポップアップ" value={showMonthly} onChange={(v) => onChangeSetting('showMonthly', v)} />
        </div>

        {/* データ */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', letterSpacing: 0.6, margin: '24px 4px 8px' }}>データ</div>
        <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '2px 14px' }}>
          <FKSettingsRow icon={<IcTrash />} label="冷蔵庫をリセット" sub="すべての食材と記録を消去" danger onClick={() => setConfirmReset(true)} />
        </div>

        {/* サポート */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--fk-text-ter)', letterSpacing: 0.6, margin: '24px 4px 8px' }}>サポート</div>
        <div style={{ background: 'var(--fk-surface)', borderRadius: 18, padding: '2px 14px' }}>
          <FKSettingsRow icon={<IcHelp />} label="使い方ガイド" sub="オンボーディングをもう一度" onClick={onReplayOnboarding} />
          <FKSettingsRow icon={<IcMail />} label="フィードバックを送る" onClick={() => {}} />
          <FKSettingsRow icon={<IcInfo />} label="このアプリについて" sub="ころあい v0.1" onClick={() => {}} />
        </div>

        <div style={{ textAlign: 'center', fontSize: 12, fontWeight: 700, color: 'var(--fk-text-ter)', marginTop: 30, lineHeight: 1.6 }}>
          ころあい v0.1<br />食品ロスを、やさしく減らす
        </div>
      </div>

      {/* リセット確認 */}
      {confirmReset &&
      <div style={{ position: 'absolute', inset: 0, zIndex: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 26 }}>
        <div onClick={() => setConfirmReset(false)} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,6,0.42)', backdropFilter: 'blur(2px)' }} />
        <div style={{
          position: 'relative', width: '100%', maxWidth: 300, borderRadius: 24, padding: '26px 24px 22px',
          background: 'var(--fk-bg2)', textAlign: 'center', boxShadow: '0 18px 50px rgba(20,14,6,0.4)',
        }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', margin: '0 auto 16px',
            background: 'color-mix(in oklab, var(--fk-accent) 16%, transparent)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><IcTrash /></div>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--fk-text)' }}>本当にリセットしますか？</div>
          <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--fk-text-sec)', marginTop: 6, lineHeight: 1.6 }}>
            すべての食材と食べきり記録が消去されます。この操作は取り消せません。
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginTop: 20 }}>
            <button onClick={() => { onReset(); setConfirmReset(false); onClose(); }} style={{
              border: 'none', cursor: 'pointer', borderRadius: 14, padding: '14px 0', fontSize: 15.5, fontWeight: 800,
              fontFamily: '"M PLUS Rounded 1c", system-ui', background: 'var(--fk-accent)', color: '#fff',
            }}>リセットする</button>
            <button onClick={() => setConfirmReset(false)} style={{
              border: 'none', cursor: 'pointer', borderRadius: 14, padding: '12px 0', fontSize: 14.5, fontWeight: 700,
              fontFamily: '"M PLUS Rounded 1c", system-ui', background: 'transparent', color: 'var(--fk-text-sec)',
            }}>やめる</button>
          </div>
        </div>
      </div>
      }
    </div>
  );
}

Object.assign(window, { FKSettings });
