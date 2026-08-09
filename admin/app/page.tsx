'use client';
import { useEffect,useState } from 'react';
import { Shell } from '@/components/shell';
import { api } from '@/lib/api';
export default function Dashboard(){
  const [d,setD]=useState<any>();
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(true);
  async function load(){setLoading(true);setError('');try{setD(await api('/admin/dashboard'))}catch(e:any){setError(e.message)}finally{setLoading(false)}}
  useEffect(()=>{void load()},[]);
  return <Shell>
    <div className="top"><div><h1>Dashboard</h1><p>Live operational overview</p></div><button className="btn secondary" onClick={()=>void load()}>Refresh</button></div>
    {error&&<div className="card"><p className="error">{error}</p><p style={{color:'var(--muted)'}}>The dashboard remains open; restart the API or disable VPN, then press Refresh.</p></div>}
    <div className="grid">{[['Users',d?.users],['Active users (24h)',d?.activeUsers24h],['Active matches',d?.activeMatches],['Waiting matches',d?.waitingMatches],['Pending transactions',d?.pendingTransactions],['Completed volume',d?.completedVolume]].map(([x,v])=><div className="card" key={x as string}><div>{x}</div><div className="metric">{loading?'…':String(v??'—')}</div></div>)}</div>
  </Shell>
}
