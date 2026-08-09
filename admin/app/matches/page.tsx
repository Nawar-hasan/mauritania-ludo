'use client';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';

export default function Matches() {
  const [items, setItems] = useState<any[]>([]);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const load = async () => {
    setError('');
    try {
      const result = await api<any>(`/admin/matches${status ? `?status=${status}` : ''}`);
      setItems(result.items ?? []);
    } catch (e: any) { setError(e.message); }
  };
  useEffect(() => { void load(); }, []);

  return <Shell>
    <div className="top">
      <div><h1>Matches</h1><p>Open a match to inspect players, authoritative state, dice rolls and moves.</p></div>
      <div className="row">
        <select className="input" value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="">All statuses</option><option>WAITING</option><option>READY</option><option>ACTIVE</option><option>COMPLETED</option><option>CANCELLED</option><option>REFUNDED</option>
        </select>
        <button className="btn" onClick={load}>Load</button>
      </div>
    </div>
    {error && <p className="error">{error}</p>}
    <table className="table"><thead><tr><th>Code</th><th>Mode</th><th>Status</th><th>Players</th><th>Stake</th><th>Created</th></tr></thead><tbody>{items.map((match) => <tr key={match.id}>
      <td><Link href={`/matches/${match.id}`} style={{color:'var(--gold)',fontWeight:800}}>{match.publicCode}</Link></td>
      <td>{match.mode}</td><td><span className="badge">{match.status}</span></td><td>{match.players.length}/{match.maxPlayers}</td><td>{match.stakeAmount} {match.currency}</td><td>{new Date(match.createdAt).toLocaleString()}</td>
    </tr>)}</tbody></table>
  </Shell>;
}
