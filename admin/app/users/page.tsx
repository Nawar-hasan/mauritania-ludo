'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';

export default function Users() {
  const [q,setQ]=useState('');
  const [items,setItems]=useState<any[]>([]);
  const [message,setMessage]=useState('');
  const load=()=>api<any>(`/admin/users?q=${encodeURIComponent(q)}`).then(x=>setItems(x.items));
  useEffect(()=>{load()},[]);
  async function status(id:string,current:string){const next=prompt('New status: ACTIVE, SUSPENDED, BANNED',current);if(!next||!['ACTIVE','SUSPENDED','BANNED'].includes(next))return;const reason=prompt('Reason')??'Admin action';try{await api(`/admin/users/${id}/status`,{method:'PATCH',body:JSON.stringify({status:next,reason})});setMessage('User status updated');load()}catch(e:any){setMessage(e.message)}}
  return <Shell><div className="top"><div><h1>Users</h1><p>Search real registered users and copy their UUID for wallet tests.</p></div><div className="row"><input className="input" value={q} onChange={e=>setQ(e.target.value)} placeholder="Search"/><button className="btn" onClick={load}>Search</button></div></div>{message&&<p>{message}</p>}<table className="table"><thead><tr><th>User</th><th>UUID</th><th>Status</th><th>Roles</th><th>Cash</th><th>Created</th><th>Action</th></tr></thead><tbody>{items.map(u=><tr key={u.id}><td><b>{u.profile?.displayName}</b><br/><span style={{color:'var(--muted)'}}>@{u.username}</span></td><td style={{maxWidth:220,wordBreak:'break-all'}}>{u.id}</td><td><span className="badge">{u.status}</span></td><td>{u.roles.join(', ')}</td><td>{u.walletAccounts.find((a:any)=>a.type==='CASH')?.balance??0}</td><td>{new Date(u.createdAt).toLocaleDateString()}</td><td><button className="btn secondary" onClick={()=>status(u.id,u.status)}>Change status</button></td></tr>)}</tbody></table></Shell>
}
