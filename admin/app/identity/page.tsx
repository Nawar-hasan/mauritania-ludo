'use client';
import { useEffect,useState } from 'react';
import { Shell } from '@/components/shell';
import { api, openAuthenticatedFile } from '@/lib/api';

export default function Identity(){
  const[items,setItems]=useState<any[]>([]);const[error,setError]=useState('');
  const load=()=>api<any[]>('/admin/identity/pending').then(setItems).catch(e=>setError(e.message));
  useEffect(()=>{void load()},[]);
  async function review(id:string,status:string){const note=prompt('Optional review note','')??'';try{await api(`/admin/users/${id}/identity`,{method:'PATCH',body:JSON.stringify({status,note})});await load()}catch(e:any){setError(e.message)}}
  function evidence(label:string,file:any){return file?<button className="btn secondary" onClick={()=>openAuthenticatedFile(file.publicUrl).catch((e:any)=>setError(e.message))}>{label}</button>:<span className="muted">{label}: —</span>}
  return <Shell><div className="top"><div><h1>Identity review</h1><p className="muted">Review the submitted identity images and profile data before verifying protected money features. Files open through an authenticated endpoint and are not public.</p></div><button className="btn secondary" onClick={load}>Refresh</button></div>{error&&<p className="error">{error}</p>}<div className="table-wrap"><table className="table"><thead><tr><th>User</th><th>Legal name</th><th>Date of birth</th><th>Country</th><th>Evidence</th><th>Status</th><th>Actions</th></tr></thead><tbody>{items.map(x=><tr key={x.userId}><td><b>@{x.user?.username||'—'}</b><small>{x.user?.email||x.user?.phone||x.userId}</small></td><td>{x.legalName||'—'}</td><td>{x.dateOfBirth?new Date(x.dateOfBirth).toLocaleDateString():'—'}</td><td>{x.countryCode||'—'}</td><td><div className="row">{evidence('Front',x.documentFront)}{evidence('Back',x.documentBack)}{evidence('Selfie',x.selfie)}</div></td><td><span className="badge">{x.status}</span><small>{x.note||''}</small></td><td><div className="row"><button className="btn" disabled={!x.documentFront||!x.selfie} onClick={()=>review(x.userId,'VERIFIED')}>Verify</button><button className="btn danger" onClick={()=>review(x.userId,'REJECTED')}>Reject</button></div></td></tr>)}</tbody></table></div></Shell>
}
