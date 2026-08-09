'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';

const empty: any = {
  code: '', provider: 'MANUAL', nameAr: '', nameEn: '', status: 'INACTIVE',
  supportsDeposit: true, supportsWithdrawal: false, currency: 'MRU',
  minAmount: 100, maxAmount: 100000, feeFixed: 0, feeRate: 0,
  iconUrl: '', publicConfig: {}, secretEnvPrefix: '', sortOrder: 0,
};

export default function Payments() {
  const [items, setItems] = useState<any[]>([]);
  const [intents, setIntents] = useState<any[]>([]);
  const [form, setForm] = useState<any>(empty);
  const [editing, setEditing] = useState<string | null>(null);
  const [configText, setConfigText] = useState('{}');
  const [error, setError] = useState('');

  const load = async () => {
    const [methods, recentIntents] = await Promise.all([
      api<any[]>('/admin/payment-methods'),
      api<any[]>('/admin/payment-intents'),
    ]);
    setItems(methods);
    setIntents(recentIntents);
  };
  useEffect(() => { void load().catch((e) => setError(e.message)); }, []);
  const set = (key: string, value: any) => setForm((current: any) => ({ ...current, [key]: value }));

  async function save(event: React.FormEvent) {
    event.preventDefault();
    setError('');
    try {
      const body = {
        ...form,
        minAmount: Number(form.minAmount), maxAmount: Number(form.maxAmount),
        feeFixed: Number(form.feeFixed), feeRate: Number(form.feeRate),
        sortOrder: Number(form.sortOrder), publicConfig: JSON.parse(configText || '{}'),
      };
      await api(editing ? `/admin/payment-methods/${editing}` : '/admin/payment-methods', {
        method: editing ? 'PATCH' : 'POST', body: JSON.stringify(body),
      });
      setForm(empty); setEditing(null); setConfigText('{}'); await load();
    } catch (e: any) { setError(e.message); }
  }
  function edit(item: any) {
    setEditing(item.id);
    setForm({ ...item, minAmount: Number(item.minAmount), maxAmount: Number(item.maxAmount), feeFixed: Number(item.feeFixed), feeRate: Number(item.feeRate) });
    setConfigText(JSON.stringify(item.publicConfig || {}, null, 2));
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  return <Shell>
    <h1>Payment methods</h1>
    <p className="muted">Configure deposit and withdrawal methods, limits, fees and public transfer details. Manual requests are approved from Transactions. Online checkout remains disabled until official merchant credentials are configured.</p>
    {error && <p className="error">{error}</p>}
    <form className="card form-grid" onSubmit={save}>
      <label>Code<input className="input" value={form.code} disabled={editing !== null} onChange={e => set('code', e.target.value.toUpperCase())} required /></label>
      <label>Provider<select className="input" value={form.provider} onChange={e => set('provider', e.target.value)}>{['MANUAL', 'MOOSYL', 'CUSTOM'].map(x => <option key={x}>{x}</option>)}</select></label>
      <label>Arabic name<input className="input" value={form.nameAr} onChange={e => set('nameAr', e.target.value)} required /></label>
      <label>English name<input className="input" value={form.nameEn} onChange={e => set('nameEn', e.target.value)} required /></label>
      <label>Status<select className="input" value={form.status} onChange={e => set('status', e.target.value)}>{['ACTIVE', 'INACTIVE'].map(x => <option key={x}>{x}</option>)}</select></label>
      <label>Currency<input className="input" value={form.currency} onChange={e => set('currency', e.target.value.toUpperCase())} /></label>
      <label>Minimum<input className="input" type="number" min="0" value={form.minAmount} onChange={e => set('minAmount', e.target.value)} /></label>
      <label>Maximum<input className="input" type="number" min="0" value={form.maxAmount} onChange={e => set('maxAmount', e.target.value)} /></label>
      <label>Fixed fee<input className="input" type="number" min="0" step="0.01" value={form.feeFixed} onChange={e => set('feeFixed', e.target.value)} /></label>
      <label>Fee rate (0.05 = 5%)<input className="input" type="number" min="0" step="0.001" value={form.feeRate} onChange={e => set('feeRate', e.target.value)} /></label>
      <label>Icon URL<input className="input" value={form.iconUrl || ''} onChange={e => set('iconUrl', e.target.value)} /></label>
      <label>Secret env prefix<input className="input" value={form.secretEnvPrefix || ''} onChange={e => set('secretEnvPrefix', e.target.value)} /></label>
      <label>Sort order<input className="input" type="number" value={form.sortOrder} onChange={e => set('sortOrder', e.target.value)} /></label>
      <label className="check"><input type="checkbox" checked={!!form.supportsDeposit} onChange={e => set('supportsDeposit', e.target.checked)} /> Deposits</label>
      <label className="check"><input type="checkbox" checked={!!form.supportsWithdrawal} onChange={e => set('supportsWithdrawal', e.target.checked)} /> Withdrawals</label>
      <label className="full">Public configuration JSON<textarea className="input textarea" value={configText} onChange={e => setConfigText(e.target.value)} /></label>
      <div className="row full"><button className="btn">{editing ? 'Save method' : 'Create method'}</button>{editing && <button type="button" className="btn secondary" onClick={() => { setEditing(null); setForm(empty); setConfigText('{}'); }}>Cancel</button>}</div>
    </form>

    <h2>Configured methods</h2>
    <div className="table-wrap"><table className="table"><thead><tr><th>Method</th><th>Provider</th><th>Limits</th><th>Fees</th><th>Use</th><th>Status</th><th>Actions</th></tr></thead><tbody>{items.map(x => <tr key={x.id}><td>{x.nameEn}<small>{x.nameAr}</small></td><td>{x.provider}</td><td>{Number(x.minAmount)}–{Number(x.maxAmount)} {x.currency}</td><td>{Number(x.feeFixed)} + {Number(x.feeRate) * 100}%</td><td>{x.supportsDeposit ? 'Deposit ' : ''}{x.supportsWithdrawal ? 'Withdrawal' : ''}</td><td><span className="badge">{x.status}</span></td><td><button className="btn secondary" onClick={() => edit(x)}>Edit</button></td></tr>)}</tbody></table></div>

    <h2>Recent payment intents</h2>
    <p className="muted">This table links provider/manual requests to the financial transaction. Approve or reject pending manual deposits from Transactions.</p>
    <div className="table-wrap"><table className="table"><thead><tr><th>Created</th><th>Player</th><th>Method</th><th>Amount</th><th>Fee</th><th>Status</th><th>Provider reference</th></tr></thead><tbody>{intents.map(x => <tr key={x.id}><td>{new Date(x.createdAt).toLocaleString()}</td><td>{x.user?.profile?.displayName || x.user?.username}<small>@{x.user?.username}</small></td><td>{x.method?.code}<small>{x.method?.provider}</small></td><td>{Number(x.amount)} {x.currency}</td><td>{Number(x.fee)}</td><td><span className="badge">{x.status}</span></td><td>{x.providerRef || '—'}</td></tr>)}</tbody></table></div>
  </Shell>;
}
