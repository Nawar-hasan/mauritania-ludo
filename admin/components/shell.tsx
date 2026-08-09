'use client';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';
const links = [['/','Dashboard'],['/users','Users'],['/wallets','Wallets'],['/matches','Matches'],['/transactions','Transactions'],['/catalog','Store items'],['/inventory','Player inventory'],['/appearance','Appearance'],['/levels','Levels'],['/stages','Stages'],['/game-rules','Game rules'],['/payments','Payments'],['/settings','Settings'],['/audit','Audit log']];
export function Shell({ children }: { children: React.ReactNode }) { const router=useRouter(); const path=usePathname(); useEffect(()=>{ if(!localStorage.getItem('admin_access_token')) router.replace('/login'); },[router]); return <div className="layout"><aside className="sidebar"><div className="brand">MAURITANIA LUDO</div><nav className="nav">{links.map(([href,label])=><Link key={href} href={href} style={path===href?{background:'#2b1745'}:{}}>{label}</Link>)}</nav><div className="space"/><button className="btn secondary" onClick={()=>{localStorage.clear();router.replace('/login')}}>Log out</button></aside><main className="main">{children}</main></div> }
