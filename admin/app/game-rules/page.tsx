'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';

const defaults: any = {
  code: '', name: '', descriptionAr: '', descriptionEn: '', sortOrder: 0,
  piecesPerPlayer: 4, requiresSixToExit: true, extraTurnOnSix: true,
  extraTurnOnCapture: true, extraTurnOnFinish: false,
  threeSixesLoseTurn: true, exactRollToFinish: true, blockadeEnabled: true,
  rollSeconds: 12, moveSeconds: 15, maxInactiveTurns: 3,
  reconnectSeconds: 30, finishAllPlayers: false, enabled: true,
};

const toggles: [string, string][] = [
  ['requiresSixToExit', 'Six required to leave base'],
  ['extraTurnOnSix', 'Extra turn after six'],
  ['extraTurnOnCapture', 'Extra turn after capture'],
  ['extraTurnOnFinish', 'Extra turn after finishing'],
  ['threeSixesLoseTurn', 'Three consecutive sixes lose turn'],
  ['exactRollToFinish', 'Exact roll to finish'],
  ['blockadeEnabled', 'Blockades enabled'],
  ['finishAllPlayers', 'Continue until all players finish'],
  ['enabled', 'Enabled'],
];

const lockedClassicFields = new Set([
  'piecesPerPlayer', 'requiresSixToExit', 'extraTurnOnSix', 'extraTurnOnCapture',
  'extraTurnOnFinish', 'threeSixesLoseTurn', 'exactRollToFinish',
  'blockadeEnabled', 'finishAllPlayers', 'enabled',
]);

export default function Rules() {
  const [items, setItems] = useState<any[]>([]);
  const [form, setForm] = useState<any>(defaults);
  const [error, setError] = useState('');
  const load = () => api<any[]>('/admin/game-rules').then(setItems).catch(e => setError(e.message));
  useEffect(() => { void load(); }, []);
  const setItem = (i: number, k: string, v: any) => setItems(xs => xs.map((x, j) => j === i ? { ...x, [k]: v } : x));
  const set = (k: string, v: any) => setForm((x: any) => ({ ...x, [k]: v }));

  async function create(e: React.FormEvent) {
    e.preventDefault(); setError('');
    try {
      await api('/admin/game-rules', { method: 'POST', body: JSON.stringify(form) });
      setForm(defaults); await load();
    } catch (e: any) { setError(e.message); }
  }

  async function save(x: any) {
    try {
      const { id, code, createdAt, updatedAt, matches, ...body } = x;
      await api(`/admin/game-rules/${id}`, { method: 'PATCH', body: JSON.stringify(body) });
      await load();
    } catch (e: any) { setError(e.message); }
  }

  return <Shell>
    <h1>Ludo rules & game modes</h1>
    <p className="muted">The server validates every roll and move. CLASSIC is the protected baseline: its core Ludo mechanics cannot be disabled or changed from the dashboard. Timers, labels and ordering remain configurable.</p>
    {error && <p className="error">{error}</p>}

    <form className="card form-grid" onSubmit={create}>
      <h2 className="full">Add a custom game mode</h2>
      <p className="muted full">Custom modes are variants. The protected CLASSIC mode remains available as the canonical ruleset.</p>
      <label>Code<input className="input" value={form.code} onChange={e => set('code', e.target.value.toUpperCase())} placeholder="CLASSIC_PLUS" required /></label>
      <label>Name<input className="input" value={form.name} onChange={e => set('name', e.target.value)} required /></label>
      <label>Arabic description<textarea className="input textarea" value={form.descriptionAr} onChange={e => set('descriptionAr', e.target.value)} /></label>
      <label>English description<textarea className="input textarea" value={form.descriptionEn} onChange={e => set('descriptionEn', e.target.value)} /></label>
      <label>Sort order<input className="input" type="number" value={form.sortOrder} onChange={e => set('sortOrder', Number(e.target.value))} /></label>
      <label>Pieces per player<input className="input" type="number" min="1" max="4" value={form.piecesPerPlayer} onChange={e => set('piecesPerPlayer', Number(e.target.value))} /></label>
      <label>Roll seconds<input className="input" type="number" min="5" max="60" value={form.rollSeconds} onChange={e => set('rollSeconds', Number(e.target.value))} /></label>
      <label>Move seconds<input className="input" type="number" min="5" max="60" value={form.moveSeconds} onChange={e => set('moveSeconds', Number(e.target.value))} /></label>
      <label>Reconnect seconds<input className="input" type="number" min="5" max="180" value={form.reconnectSeconds} onChange={e => set('reconnectSeconds', Number(e.target.value))} /></label>
      <label>Inactive turns<input className="input" type="number" min="1" max="5" value={form.maxInactiveTurns} onChange={e => set('maxInactiveTurns', Number(e.target.value))} /></label>
      <div className="full toggle-grid">{toggles.map(([k, l]) => <label className="check" key={k}><input type="checkbox" checked={!!form[k]} onChange={e => set(k, e.target.checked)} />{l}</label>)}</div>
      <div className="full"><button className="btn">Create mode</button></div>
    </form>

    <div className="grid">{items.map((x, i) => {
      const locked = x.code === 'CLASSIC';
      return <div className="card" key={x.id}>
        <div className="row"><h2>{x.code}</h2><span className="badge">{locked ? 'CORE LOCKED' : (x.enabled ? 'ENABLED' : 'DISABLED')}</span></div>
        {locked && <p className="muted">Protected mechanics: 4 pieces, six to leave base, extra turn after six/capture, no extra turn for finishing, three-sixes penalty, exact finish, blockades and first-player victory.</p>}
        <label>Name<input className="input" value={x.name} onChange={e => setItem(i, 'name', e.target.value)} /></label>
        <label>Arabic description<textarea className="input textarea" value={x.descriptionAr || ''} onChange={e => setItem(i, 'descriptionAr', e.target.value)} /></label>
        <label>English description<textarea className="input textarea" value={x.descriptionEn || ''} onChange={e => setItem(i, 'descriptionEn', e.target.value)} /></label>
        <div className="form-grid compact">
          <label>Order<input className="input" type="number" value={x.sortOrder || 0} onChange={e => setItem(i, 'sortOrder', Number(e.target.value))} /></label>
          <label>Pieces<input className="input" type="number" min="1" max="4" disabled={locked} value={x.piecesPerPlayer} onChange={e => setItem(i, 'piecesPerPlayer', Number(e.target.value))} /></label>
          <label>Roll seconds<input className="input" type="number" min="5" max="60" value={x.rollSeconds} onChange={e => setItem(i, 'rollSeconds', Number(e.target.value))} /></label>
          <label>Move seconds<input className="input" type="number" min="5" max="60" value={x.moveSeconds} onChange={e => setItem(i, 'moveSeconds', Number(e.target.value))} /></label>
          <label>Reconnect seconds<input className="input" type="number" min="5" max="180" value={x.reconnectSeconds} onChange={e => setItem(i, 'reconnectSeconds', Number(e.target.value))} /></label>
          <label>Inactive turns<input className="input" type="number" min="1" max="5" value={x.maxInactiveTurns} onChange={e => setItem(i, 'maxInactiveTurns', Number(e.target.value))} /></label>
        </div>
        {toggles.map(([k, l]) => <label className="check" key={k}><input type="checkbox" disabled={locked && lockedClassicFields.has(k)} checked={!!x[k]} onChange={e => setItem(i, k, e.target.checked)} />{l}{locked && lockedClassicFields.has(k) ? ' 🔒' : ''}</label>)}
        <div className="row"><button className="btn" onClick={() => save(x)}>Save rules</button>{!locked && <button className="btn danger" onClick={async () => { if (confirm('Disable this game mode?')) { await api(`/admin/game-rules/${x.id}`, { method: 'DELETE' }); load(); } }}>Disable</button>}</div>
      </div>;
    })}</div>
  </Shell>;
}
