'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api, assetUrl } from '@/lib/api';

export default function InventoryAdmin() {
  const [users,setUsers]=useState<any[]>([]); const [catalog,setCatalog]=useState<any[]>([]); const [inventory,setInventory]=useState<any[]>([]);
  const [userId,setUserId]=useState(''); const [itemId,setItemId]=useState(''); const [quantity,setQuantity]=useState(1); const [equip,setEquip]=useState(false); const [message,setMessage]=useState('');
  useEffect(()=>{Promise.all([api<any>('/admin/users'),api<any[]>('/admin/catalog')]).then(([u,c])=>{setUsers(u.items);setCatalog(c);if(u.items?.[0])setUserId(u.items[0].id);if(c?.[0])setItemId(c[0].id)}).catch(e=>setMessage(e.message))},[]);
  useEffect(()=>{if(userId)void load()},[userId]);
  async function load(){try{setInventory(await api<any[]>(`/admin/users/${userId}/inventory`))}catch(e:any){setMessage(e.message)}}
  async function grant(e:React.FormEvent){e.preventDefault();try{await api(`/admin/users/${userId}/inventory`,{method:'POST',body:JSON.stringify({itemId,quantity:Number(quantity),equip})});setMessage('Item granted');await load()}catch(e:any){setMessage(e.message)}}
  async function revoke(id:string){if(!confirm('Revoke this item from the player?'))return;try{await api(`/admin/users/${userId}/inventory/${id}`,{method:'DELETE'});await load()}catch(e:any){setMessage(e.message)}}
  return <Shell><h1>Player inventory</h1><p className="muted">Grant promotional items, compensation rewards or test cosmetics to a player. Every action is recorded in the audit log.</p>{message&&<p>{message}</p>}
  <form className="card form-grid" onSubmit={grant}><label>Player<select className="input" value={userId} onChange={e=>setUserId(e.target.value)}>{users.map(u=><option key={u.id} value={u.id}>{u.profile?.displayName||u.username} (@{u.username})</option>)}</select></label><label>Catalog item<select className="input" value={itemId} onChange={e=>setItemId(e.target.value)}>{catalog.filter(x=>!['COIN_PACK','GEM_PACK'].includes(x.type)).map(x=><option key={x.id} value={x.id}>{x.code} · {x.nameEn}</option>)}</select></label><label>Quantity<input className="input" type="number" min="1" max="9999" value={quantity} onChange={e=>setQuantity(Number(e.target.value))}/></label><label className="check"><input type="checkbox" checked={equip} onChange={e=>setEquip(e.target.checked)}/> Equip immediately</label><div className="full"><button className="btn">Grant item</button></div></form>
  <div className="grid">{inventory.map(x=><div className="card" key={x.id}>{x.item?.imageUrl&&<img className="campaign-cover" src={assetUrl(x.item.imageUrl)} alt=""/>}<h3>{x.item?.nameEn}</h3><p>{x.item?.nameAr}</p><p className="muted">{x.item?.type} · quantity {x.quantity} · {x.source}</p><span className="badge">{x.equipped?'EQUIPPED':'OWNED'}</span><div><button className="btn danger" onClick={()=>revoke(x.itemId)}>Revoke</button></div></div>)}</div></Shell>
}
