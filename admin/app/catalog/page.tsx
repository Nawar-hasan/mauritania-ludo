'use client';
import { useEffect, useState } from 'react';
import { Shell } from '@/components/shell';
import { api, assetUrl, uploadFile } from '@/lib/api';

const empty:any={code:'',type:'BOARD',nameAr:'',nameEn:'',descriptionAr:'',descriptionEn:'',imageUrl:'',previewUrl:'',price:0,priceWallet:'COINS',minLevel:1,rarity:'COMMON',status:'ACTIVE',isFeatured:false,isDefault:false,sortOrder:0,metadata:{}};
export default function CatalogPage(){
 const[items,setItems]=useState<any[]>([]); const[form,setForm]=useState<any>(empty); const[editing,setEditing]=useState<string|null>(null); const[error,setError]=useState(''); const[metadataText,setMetadataText]=useState('{}');
 const load=()=>api<any[]>('/admin/catalog').then(setItems).catch(e=>setError(e.message)); useEffect(()=>{void load()},[]);
 const set=(k:string,v:any)=>setForm((x:any)=>({...x,[k]:v})); const meta=(k:string,v:any)=>{const next={...(form.metadata||{}),[k]:v};set('metadata',next);setMetadataText(JSON.stringify(next,null,2))};
 async function upload(file?:File){if(!file)return;try{const result=await uploadFile('/admin/uploads/assets',file);set('imageUrl',result.url)}catch(e:any){setError(e.message)}}
 async function save(e:React.FormEvent){e.preventDefault();setError('');try{const metadata=JSON.parse(metadataText||'{}');const body={...form,price:Number(form.price),minLevel:Number(form.minLevel),sortOrder:Number(form.sortOrder),metadata};await api(editing?`/admin/catalog/${editing}`:'/admin/catalog',{method:editing?'PATCH':'POST',body:JSON.stringify(body)});setForm(empty);setMetadataText('{}');setEditing(null);await load()}catch(e:any){setError(e.message)}}
 function edit(x:any){setEditing(x.id);setForm({...x,price:Number(x.price),metadata:x.metadata||{}});setMetadataText(JSON.stringify(x.metadata||{},null,2));window.scrollTo({top:0,behavior:'smooth'})}
 async function archive(id:string){if(!confirm('Archive this item?'))return;await api(`/admin/catalog/${id}`,{method:'DELETE'});await load()}
 const m=form.metadata||{};
 return <Shell><div className="top"><div><h1>Store & visual items</h1><p className="muted">Create boards, dice, frames, backgrounds, limited items, skills and currency packs. Players purchase and equip them from the app.</p></div></div>
 {error&&<p className="error">{error}</p>}
 <form className="card form-grid" onSubmit={save}>
  <h2 className="full">{editing?'Edit item':'Add item'}</h2>
  <label>Code<input className="input" value={form.code} disabled={editing!==null} onChange={e=>set('code',e.target.value.toUpperCase())} required/></label>
  <label>Type<select className="input" value={form.type} onChange={e=>set('type',e.target.value)}>{['BOARD','DICE','DICE_FRAME','BACKGROUND','AVATAR_FRAME','EMOTE','SKILL','COIN_PACK','GEM_PACK'].map(x=><option key={x}>{x}</option>)}</select></label>
  <label>Arabic name<input className="input" value={form.nameAr} onChange={e=>set('nameAr',e.target.value)} required/></label>
  <label>English name<input className="input" value={form.nameEn} onChange={e=>set('nameEn',e.target.value)} required/></label>
  <label>Arabic description<textarea className="input textarea" value={form.descriptionAr||''} onChange={e=>set('descriptionAr',e.target.value)}/></label>
  <label>English description<textarea className="input textarea" value={form.descriptionEn||''} onChange={e=>set('descriptionEn',e.target.value)}/></label>
  <label>Image / visual asset<input className="input" value={form.imageUrl||''} onChange={e=>set('imageUrl',e.target.value)}/><input className="input" type="file" accept="image/png,image/jpeg,image/webp" onChange={e=>upload(e.target.files?.[0])}/></label>
  <label>Preview URL<input className="input" value={form.previewUrl||''} onChange={e=>set('previewUrl',e.target.value)}/></label>
  <label>Price<input className="input" type="number" min="0" step="0.01" value={form.price} onChange={e=>set('price',e.target.value)}/></label>
  <label>Wallet<select className="input" value={form.priceWallet} onChange={e=>set('priceWallet',e.target.value)}>{['COINS','GEMS','CASH','BONUS'].map(x=><option key={x}>{x}</option>)}</select></label>
  <label>Minimum level<input className="input" type="number" min="1" value={form.minLevel} onChange={e=>set('minLevel',e.target.value)}/></label>
  <label>Rarity<select className="input" value={form.rarity} onChange={e=>set('rarity',e.target.value)}>{['COMMON','RARE','EPIC','LEGENDARY','LIMITED'].map(x=><option key={x}>{x}</option>)}</select></label>
  <label>Status<select className="input" value={form.status} onChange={e=>set('status',e.target.value)}>{['DRAFT','ACTIVE','ARCHIVED'].map(x=><option key={x}>{x}</option>)}</select></label>
  <label>Sort order<input className="input" type="number" value={form.sortOrder} onChange={e=>set('sortOrder',e.target.value)}/></label>
  <label className="check"><input type="checkbox" checked={!!form.isFeatured} onChange={e=>set('isFeatured',e.target.checked)}/> Featured</label>
  <label className="check"><input type="checkbox" checked={!!form.isDefault} onChange={e=>set('isDefault',e.target.checked)}/> Default/free</label>
  {form.type==='BOARD'&&<fieldset className="full style-box"><legend>Board visual style</legend><div className="form-grid compact"><label>Render mode<select className="input" value={m.renderMode||'PALETTE'} onChange={e=>meta('renderMode',e.target.value)}><option>PALETTE</option><option>IMAGE</option></select></label><ColorField label="Background" value={m.backgroundColor||'#F2F0E8'} onChange={v=>meta('backgroundColor',v)}/><ColorField label="Track" value={m.trackColor||'#F6F6F6'} onChange={v=>meta('trackColor',v)}/><ColorField label="Grid" value={m.gridColor||'#616161'} onChange={v=>meta('gridColor',v)}/><ColorField label="Safe star" value={m.safeColor||'#777777'} onChange={v=>meta('safeColor',v)}/><ColorField label="Glow" value={m.glowColor||'#FFD54F'} onChange={v=>meta('glowColor',v)}/></div></fieldset>}
  {form.type==='DICE'&&<fieldset className="full style-box"><legend>Dice visual style</legend><div className="form-grid compact"><ColorField label="Face" value={m.faceColor||'#FFFFFF'} onChange={v=>meta('faceColor',v)}/><ColorField label="Pips" value={m.pipColor||'#120A20'} onChange={v=>meta('pipColor',v)}/><ColorField label="Border" value={m.borderColor||'#FFD54F'} onChange={v=>meta('borderColor',v)}/><label>Corner radius<input className="input" type="number" min="4" max="28" value={m.radius||15} onChange={e=>meta('radius',Number(e.target.value))}/></label></div></fieldset>}
  {form.type==='DICE_FRAME'&&<fieldset className="full style-box"><legend>Dice frame style</legend><div className="form-grid compact"><ColorField label="Frame" value={m.frameColor||'#FFD54F'} onChange={v=>meta('frameColor',v)}/><ColorField label="Glow" value={m.glowColor||'#FFD54F'} onChange={v=>meta('glowColor',v)}/><label>Border width<input className="input" type="number" min="1" max="8" value={m.borderWidth||3} onChange={e=>meta('borderWidth',Number(e.target.value))}/></label></div></fieldset>}
  {(form.type==='COIN_PACK'||form.type==='GEM_PACK')&&<fieldset className="full style-box"><legend>Currency pack</legend><div className="form-grid compact"><label>Amount granted per pack<input className="input" type="number" min="1" value={m.grantAmount||100} onChange={e=>meta('grantAmount',Number(e.target.value))}/></label><p className="muted">The purchase price is deducted from the selected wallet, then this amount is credited to the player&apos;s {form.type==='COIN_PACK'?'COINS':'GEMS'} wallet.</p></div></fieldset>}
  <label className="full">Advanced metadata JSON<textarea className="input textarea" value={metadataText} onChange={e=>{setMetadataText(e.target.value);try{set('metadata',JSON.parse(e.target.value||'{}'))}catch{}}}/></label>
  <div className="row full"><button className="btn" type="submit">{editing?'Save changes':'Create item'}</button>{editing&&<button type="button" className="btn secondary" onClick={()=>{setEditing(null);setForm(empty);setMetadataText('{}')}}>Cancel</button>}</div>
 </form>
 <div className="table-wrap"><table className="table"><thead><tr><th>Preview</th><th>Code</th><th>Type</th><th>Name</th><th>Price</th><th>Level</th><th>Status</th><th>Actions</th></tr></thead><tbody>{items.map(x=><tr key={x.id}><td>{x.imageUrl?<img className="thumb" src={assetUrl(x.imageUrl)} alt=""/>:'—'}</td><td>{x.code}</td><td>{x.type}</td><td>{x.nameEn}<small>{x.nameAr}</small></td><td>{Number(x.price)} {x.priceWallet}</td><td>{x.minLevel}</td><td><span className="badge">{x.status}</span></td><td><div className="row"><button className="btn secondary" onClick={()=>edit(x)}>Edit</button><button className="btn danger" onClick={()=>archive(x.id)}>Archive</button></div></td></tr>)}</tbody></table></div>
 </Shell>
}
function ColorField({label,value,onChange}:{label:string,value:string,onChange:(v:string)=>void}){return <label>{label}<input className="input" type="color" value={value} onChange={e=>onChange(e.target.value)}/></label>}
