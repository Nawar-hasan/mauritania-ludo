'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api, openAuthenticatedFile } from '@/lib/api';

export default function Transactions() {
  const [items, setItems] = useState<any[]>([]);
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [message, setMessage] = useState('');
  const load = async () => {
    try {
      const query = new URLSearchParams(); if (status) query.set('status', status); if (type) query.set('type', type);
      const result = await api<any>(`/admin/transactions${query.size ? `?${query}` : ''}`);
      setItems(result.items ?? []);
    } catch (error: any) { setMessage(error.message); }
  };
  useEffect(() => { void load(); }, []);

  async function approve(id: string) {
    if (!confirm('Approve this financial request after verifying its details?')) return;
    try { await api(`/admin/transactions/${id}/approve`, { method: 'POST' }); setMessage('Transaction approved'); await load(); }
    catch (error: any) { setMessage(error.message); }
  }
  async function reject(id: string) {
    const reason = prompt('Rejection reason'); if (!reason) return;
    try { await api(`/admin/transactions/${id}/reject`, { method: 'POST', body: JSON.stringify({ reason }) }); setMessage('Transaction rejected'); await load(); }
    catch (error: any) { setMessage(error.message); }
  }

  return <Shell>
    <div className="top"><div><h1>Transactions</h1><p>Review transfer evidence and withdrawal destination before processing.</p></div><div className="row">
      <select className="input" value={type} onChange={(e)=>setType(e.target.value)}><option value="">All types</option><option>DEPOSIT</option><option>WITHDRAWAL</option><option>WAGER_LOCK</option><option>WAGER_RELEASE</option><option>MATCH_PRIZE</option><option>REFUND</option><option>ADMIN_ADJUSTMENT</option></select>
      <select className="input" value={status} onChange={(e)=>setStatus(e.target.value)}><option value="">All statuses</option><option>PENDING</option><option>PROCESSING</option><option>COMPLETED</option><option>REJECTED</option></select>
      <button className="btn" onClick={load}>Load</button>
    </div></div>
    {message && <p className={message.toLowerCase().includes('error') ? 'error' : ''}>{message}</p>}
    <table className="table"><thead><tr><th>User</th><th>Request</th><th>Status</th><th>Amount</th><th>Transfer / destination details</th><th>Date</th><th>Actions</th></tr></thead><tbody>{items.map((transaction)=>{
      const metadata = transaction.metadata ?? {};
      return <tr key={transaction.id}>
        <td><b>{transaction.user.profile?.displayName}</b><br/><span style={{color:'var(--muted)'}}>@{transaction.user.username}</span></td>
        <td>{transaction.type}<br/><span style={{color:'var(--muted)'}}>{metadata.method ?? ''}</span></td>
        <td><span className="badge">{transaction.status}</span></td>
        <td>{transaction.amount} {transaction.currency}</td>
        <td style={{minWidth:240}}>
          {transaction.externalRef && <div>Reference: {transaction.externalRef}</div>}
          {metadata.receiptUrl && <div><button className="btn secondary" onClick={()=>openAuthenticatedFile(metadata.receiptUrl).catch((e:any)=>setMessage(e.message))}>Open receipt image</button></div>}
          {metadata.accountNumber && <div>Account: {metadata.accountNumber}</div>}
          {metadata.accountName && <div>Name: {metadata.accountName}</div>}
          {metadata.note && <div>Note: {metadata.note}</div>}
          {metadata.rejectionReason && <div className="error">Rejected: {metadata.rejectionReason}</div>}
        </td>
        <td>{new Date(transaction.createdAt).toLocaleString()}</td>
        <td>{['PENDING','PROCESSING'].includes(transaction.status) && ['DEPOSIT','WITHDRAWAL'].includes(transaction.type) ? <div className="row"><button className="btn" onClick={()=>approve(transaction.id)}>Approve</button><button className="btn secondary" onClick={()=>reject(transaction.id)}>Reject</button></div> : '—'}</td>
      </tr>;
    })}</tbody></table>
  </Shell>;
}
