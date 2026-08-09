'use client';
import { use, useEffect, useState } from 'react';
import Link from 'next/link';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';

export default function MatchDetails({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [match, setMatch] = useState<any>();
  const [error, setError] = useState('');
  useEffect(() => { api<any>(`/admin/matches/${id}`).then(setMatch).catch((e) => setError(e.message)); }, [id]);
  return <Shell>
    <div className="top"><div><h1>Match {match?.publicCode ?? ''}</h1><p>Authoritative server record.</p></div><Link className="btn secondary" href="/matches">Back</Link></div>
    {error && <p className="error">{error}</p>}
    {!match ? <div className="card">Loading…</div> : <>
      <div className="grid">
        <div className="card"><div>Status</div><div className="metric">{match.status}</div></div>
        <div className="card"><div>Mode / rules</div><div className="metric" style={{fontSize:20}}>{match.mode} / {match.ruleSet?.code}</div></div>
        <div className="card"><div>Stake</div><div className="metric">{match.stakeAmount} {match.currency}</div></div>
        <div className="card"><div>State version</div><div className="metric">{match.stateVersion}</div></div>
      </div>
      <div className="space"/><h2>Players</h2>
      <table className="table"><thead><tr><th>Seat</th><th>User</th><th>Color</th><th>Status</th><th>Inactive turns</th><th>Finish</th></tr></thead><tbody>{match.players.map((player:any)=><tr key={player.id}><td>{player.seat}</td><td>{player.user.profile?.displayName}<br/><span style={{color:'var(--muted)'}}>@{player.user.username}</span></td><td>{player.color}</td><td>{player.status}</td><td>{player.inactiveTurns}</td><td>{player.finishPosition ?? '—'}</td></tr>)}</tbody></table>
      <div className="space"/><h2>Events</h2>
      <table className="table"><thead><tr><th>#</th><th>Type</th><th>Actor</th><th>Payload</th><th>Date</th></tr></thead><tbody>{match.events.map((event:any)=><tr key={String(event.id)}><td>{event.sequence}</td><td>{event.type}</td><td style={{maxWidth:160,wordBreak:'break-all'}}>{event.actorUserId ?? 'system'}</td><td><pre style={{whiteSpace:'pre-wrap',maxWidth:440,margin:0}}>{JSON.stringify(event.payload ?? {}, null, 2)}</pre></td><td>{new Date(event.createdAt).toLocaleString()}</td></tr>)}</tbody></table>
      <div className="space"/><h2>Current state</h2><div className="card"><pre style={{whiteSpace:'pre-wrap',overflowX:'auto'}}>{JSON.stringify(match.currentState ?? {}, null, 2)}</pre></div>
    </>}
  </Shell>;
}
