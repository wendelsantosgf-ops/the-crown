"use client";
import {useEffect,useState,useCallback} from "react";
import {Crown,House,Target,Trophy,Coins,Users,Mail,Folder,Info,Bell,Menu,X,Clock,CheckCircle,LogOut} from "lucide-react";
const nav=[["Início",House],["Desafios",Target],["Ranking",Trophy],["Apostas",Coins],["Audiência",Users],["Mensagens",Mail],["Arquivos",Folder],["Regras",Info]];
const base=process.env.NEXT_PUBLIC_SUPABASE_URL;
const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
async function api(path,{method="GET",token,body}={}){
 const response=await fetch(base+path,{method,headers:{"apikey":key,"Content-Type":"application/json",...(token?{Authorization:"Bearer "+token}:{}),...(method==="POST"?{Prefer:"return=representation"}:{})},...(body?{body:JSON.stringify(body)}:{})});
 const data=await response.json().catch(()=>null);
 if(!response.ok)throw Error(data?.msg||data?.message||data?.error_description||data?.hint||"Falha na operação");
 return data;
}
const fmt=n=>Number(n||0).toLocaleString("pt-BR");
export default function Home(){
 const [tab,setTab]=useState("Início"),[open,setOpen]=useState(false),[session,setSession]=useState(null),[profile,setProfile]=useState(null),[admin,setAdmin]=useState(false),[challenges,setChallenges]=useState([]),[entries,setEntries]=useState([]),[leaders,setLeaders]=useState([]),[notice,setNotice]=useState(""),[busy,setBusy]=useState(false),[mode,setMode]=useState("login"),[email,setEmail]=useState(""),[password,setPassword]=useState(""),[username,setUsername]=useState(""),[title,setTitle]=useState(""),[description,setDescription]=useState(""),[reward,setReward]=useState(100),[deadline,setDeadline]=useState(""),[submission,setSubmission]=useState({}),[pending,setPending]=useState([]);
 const notify=msg=>setNotice(msg);
 const [profileLoading,setProfileLoading]=useState(true);
 const [profileError,setProfileError]=useState("");
 const refresh=useCallback(async(s)=>{
  if(!s?.access_token){setProfileLoading(false);return;}
  const t=s.access_token;
  setProfileLoading(true);setProfileError("");
  try{
   const p=await api("/rest/v1/crown_profiles?select=*&id=eq."+encodeURIComponent(s.user.id),{token:t});
   setProfile(p[0]||null);
  }catch(err){
   setProfileError(err.message||"Não foi possível consultar seu perfil.");
   setProfileLoading(false);
   return;
  }
  setProfileLoading(false);
  const results=await Promise.allSettled([
   api("/rest/v1/crown_admins?select=user_id&user_id=eq."+encodeURIComponent(s.user.id),{token:t}),
   api("/rest/v1/crown_challenges?select=*&order=created_at.desc",{token:t}),
   api("/rest/v1/crown_entries?select=*&order=created_at.desc",{token:t}),
   api("/rest/v1/crown_profiles?select=username,points&order=points.desc,created_at.asc&limit=50",{token:t})
  ]);
  const [admins,challengeRows,entryRows,leaderRows]=results;
  if(admins.status==="fulfilled"){
   const isAdmin=admins.value.length>0;setAdmin(isAdmin);
   if(isAdmin){
    try{setPending(await api("/rest/v1/crown_entries?select=*,crown_challenges(title)&status=eq.submitted&order=created_at.asc",{token:t}));}
    catch(err){notify("Não foi possível carregar avaliações: "+err.message);}
   }else setPending([]);
  }else setAdmin(false);
  if(challengeRows.status==="fulfilled")setChallenges(challengeRows.value);
  if(entryRows.status==="fulfilled")setEntries(entryRows.value);
  if(leaderRows.status==="fulfilled")setLeaders(leaderRows.value);
  const failures=results.filter(r=>r.status==="rejected");
  if(failures.length)notify("Alguns dados não carregaram. Atualize a página para tentar novamente.");
 },[]);
 useEffect(()=>{
  let cancelled=false;
  try{
   const saved=JSON.parse(localStorage.getItem("crown_session")||"null");
   if(!saved?.access_token){setProfileLoading(false);return;}
   api("/auth/v1/user",{token:saved.access_token}).then(user=>{
    if(cancelled)return;
    const s={...saved,user};setSession(s);refresh(s);
   }).catch(async()=>{
    if(cancelled)return;
    if(saved.refresh_token){
     try{
      const result=await api("/auth/v1/token?grant_type=refresh_token",{method:"POST",body:{refresh_token:saved.refresh_token}});
      if(cancelled)return;
      const s={access_token:result.access_token,refresh_token:result.refresh_token,user:result.user};
      localStorage.setItem("crown_session",JSON.stringify(s));setSession(s);refresh(s);return;
     }catch{}
    }
    localStorage.removeItem("crown_session");setProfileLoading(false);
   });
  }catch{setProfileLoading(false);}
  return()=>{cancelled=true};
 },[refresh]);
 async function auth(ev){
  ev.preventDefault();setBusy(true);
  try{
   if(!base||!key)throw Error("Configure as variáveis públicas do Supabase na Vercel.");
   if(mode==="register"){
    if(!/^[a-zA-Z0-9_]{3,30}$/.test(username))throw Error("Nome de usuário: 3 a 30 letras, números ou _.");
    const result=await api("/auth/v1/signup",{method:"POST",body:{email,password}});
    if(!result.access_token){notify("Cadastro criado. Confirme seu e-mail e faça login.");setMode("login");return;}
    const s={access_token:result.access_token,refresh_token:result.refresh_token,user:result.user};
    try{await api("/rest/v1/crown_profiles",{method:"POST",token:s.access_token,body:{id:s.user.id,username}});}catch(err){if(!/duplicate key|23505/i.test(err.message))throw err;}
    localStorage.setItem("crown_session",JSON.stringify(s));setSession(s);await refresh(s);
   }else{
    const result=await api("/auth/v1/token?grant_type=password",{method:"POST",body:{email,password}});
    const s={access_token:result.access_token,refresh_token:result.refresh_token,user:result.user};
    localStorage.setItem("crown_session",JSON.stringify(s));setSession(s);await refresh(s);
   }
  }catch(err){notify(err.message)}finally{setBusy(false)}
 }
 async function run(fn){setBusy(true);try{await fn();await refresh(session)}catch(err){notify(err.message)}finally{setBusy(false)}}
 function logout(){setProfileLoading(false);setProfileError("");localStorage.removeItem("crown_session");setSession(null);setProfile(null);setAdmin(false);setEntries([]);setLeaders([]);setChallenges([])}
 const active=challenges.find(c=>c.status==="published"&&(!c.deadline||new Date(c.deadline)>new Date()));
 const ownEntry=active&&entries.find(e=>e.challenge_id===active.id&&e.user_id===session?.user?.id);
 const position=profile?leaders.findIndex(l=>l.username===profile.username)+1:0;
 const choose=t=>{setTab(t);setOpen(false)};
 const challengeCard=c=><article className="mission panel" key={c.id}><div className="statue" style={c.image_url?{backgroundImage:"linear-gradient(90deg,transparent,#150d0d),url("+JSON.stringify(c.image_url)+")"}:{backgroundImage:"none",display:"grid",placeItems:"center",color:"#8e7268"}}>{!c.image_url&&<span>THE CROWN</span>}</div><div className="mission-copy"><div className="eyebrow">DESAFIO ATUAL</div><h2>{c.title}</h2><p>{c.description}</p><div className="details"><span><Coins/> {fmt(c.reward_points)} pts</span><span><Clock/> {c.deadline?new Date(c.deadline).toLocaleString("pt-BR"):"Sem prazo"}</span></div><div className="actions">{ownEntry?<span>Status: {ownEntry.status}</span>:<button disabled={busy} onClick={()=>run(()=>api("/rest/v1/crown_entries",{method:"POST",token:session.access_token,body:{challenge_id:c.id,user_id:session.user.id}}))}>ACEITAR DESAFIO</button>}</div>{ownEntry?.status==="accepted"&&<form onSubmit={ev=>{ev.preventDefault();run(()=>api("/rest/v1/rpc/crown_submit_entry",{method:"POST",token:session.access_token,body:{p_entry:ownEntry.id,p_submission:submission[ownEntry.id]||""}}))}}><textarea required minLength={3} maxLength={3000} placeholder="Descreva sua participação" value={submission[ownEntry.id]||""} onChange={ev=>setSubmission({...submission,[ownEntry.id]:ev.target.value})}/><button disabled={busy}>ENVIAR PARA AVALIAÇÃO</button></form>}</div></article>;
 return <div className="shell"><aside className={open?"sidebar opened":"sidebar"}><div className="brand"><Crown size={43}/><span>THE<br/>CROWN</span></div><nav>{nav.map(([name,Icon])=><button key={name} className={tab===name?"active":""} onClick={()=>choose(name)}><Icon size={23}/>{name}</button>)}{admin&&<button className={tab==="Admin"?"active":""} onClick={()=>choose("Admin")}><Crown size={23}/>Administração</button>}</nav><div className="sidebar-foot">♛</div></aside><main><header className="top"><button className="mobile-menu" onClick={()=>setOpen(!open)}>{open?<X/>:<Menu/>}</button><div className="top-right"><Bell/><div className="avatar">♛</div><div className="identity">{profile?.username||"VISITANTE"}<br/><span>{fmt(profile?.points)} pts</span></div>{session&&<button className="logout" onClick={logout} title="Sair"><LogOut size={20}/></button>}</div></header><div className="content"><section className="hero"><div><h1>Bem-vindo ao The Crown.</h1><p>DESAFIE. CONQUISTE. EXPONHA.</p></div></section>{!base||!key?<section className="section panel"><h2>Configuração pendente</h2><p>Adicione NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY na Vercel para ativar o sistema.</p></section>:!session?<section className="section panel auth"><h2>{mode==="login"?"Entrar no The Crown":"Criar conta"}</h2><form onSubmit={auth}><input type="email" placeholder="E-mail" required value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" minLength={6} placeholder="Senha" required value={password} onChange={e=>setPassword(e.target.value)}/>{mode==="register"&&<input placeholder="Nome de usuário" value={username} required onChange={e=>setUsername(e.target.value)}/>}<button disabled={busy}>{busy?"Aguarde...":mode==="login"?"ENTRAR":"CADASTRAR"}</button></form><button className="text-button" onClick={()=>setMode(mode==="login"?"register":"login")}>{mode==="login"?"Criar conta":"Já tenho uma conta"}</button></section>:profileLoading?<section className="section panel auth"><h2>Carregando perfil...</h2><p>Aguarde enquanto verificamos seu cadastro.</p></section>:profileError?<section className="section panel auth"><h2>Não foi possível carregar o perfil</h2><p>{profileError}</p><button onClick={()=>refresh(session)}>TENTAR NOVAMENTE</button></section>:!profile?<section className="section panel auth"><h2>Concluir perfil</h2><form onSubmit={ev=>{ev.preventDefault();run(async()=>{try{await api("/rest/v1/crown_profiles",{method:"POST",token:session.access_token,body:{id:session.user.id,username}})}catch(err){if(!/duplicate key|23505/i.test(err.message))throw err;}})}}><input placeholder="Nome de usuário" required value={username} onChange={e=>setUsername(e.target.value)}/><button disabled={busy}>CRIAR PERFIL</button></form></section>:<>{tab==="Início"?<><div className="feature-grid">{active?challengeCard(active):<article className="section panel empty"><div className="eyebrow">DESAFIO ATUAL</div><h2>Nenhum desafio publicado</h2><p>Novos desafios aparecerão aqui quando forem publicados.</p></article>}<article className="live panel"><div className="live-heading"><span>AO VIVO</span><span>0 espectadores</span></div><div className="live-image empty-live">Nenhuma transmissão disponível</div><div className="live-caption">Aguardando publicação</div></article></div><div className="metrics"><div className="metric panel"><small>SUA POSIÇÃO</small><strong>{position?"#"+position:"—"}</strong><span>{fmt(profile.points)} pts</span></div><div className="metric panel"><small>PARTICIPAÇÕES</small><strong>{entries.filter(e=>e.user_id===session.user.id).length}</strong></div><div className="metric panel"><small>AUDIÊNCIA</small><strong>0</strong></div></div></>:tab==="Desafios"?<section className="section panel"><h2>Desafios</h2><div className="challenge-list">{challenges.length?challenges.map(challengeCard):<p>Nenhum desafio publicado ainda.</p>}</div></section>:tab==="Ranking"?<section className="section panel"><h2>Ranking</h2><div className="rank-list">{leaders.length?leaders.map((l,i)=><div key={l.username}><span>{i+1}. {l.username}</span><span>{fmt(l.points)} pts</span></div>):<p>Não há participantes no ranking.</p>}</div></section>:tab==="Admin"&&admin?<section className="section panel admin"><h2>Administração</h2><h3>Publicar desafio</h3><form onSubmit={ev=>{ev.preventDefault();run(async()=>{await api("/rest/v1/crown_challenges",{method:"POST",token:session.access_token,body:{title,description,reward_points:Number(reward),deadline:deadline?new Date(deadline).toISOString():null}});setTitle("");setDescription("");setDeadline("");notify("Desafio publicado")})}}><input required minLength={3} maxLength={120} placeholder="Título do desafio" value={title} onChange={e=>setTitle(e.target.value)}/><textarea required maxLength={3000} placeholder="Descrição" value={description} onChange={e=>setDescription(e.target.value)}/><label>Recompensa (pontos)</label><input type="number" min="0" max="100000" value={reward} onChange={e=>setReward(e.target.value)}/><label>Prazo (opcional)</label><input type="datetime-local" value={deadline} onChange={e=>setDeadline(e.target.value)}/><button disabled={busy}>PUBLICAR DESAFIO</button></form><h3>Envios para avaliação</h3>{pending.length?pending.map(e=><div className="review" key={e.id}><strong>{e.crown_challenges?.title}</strong><p>{e.submission}</p><button disabled={busy} onClick={()=>run(()=>api("/rest/v1/rpc/crown_review_entry",{method:"POST",token:session.access_token,body:{p_entry:e.id,p_approve:true}}))}>APROVAR</button><button disabled={busy} onClick={()=>run(()=>api("/rest/v1/rpc/crown_review_entry",{method:"POST",token:session.access_token,body:{p_entry:e.id,p_approve:false}}))}>REJEITAR</button></div>):<p>Sem envios pendentes.</p>}</section>:<section className="section panel"><h2>{tab}</h2><p>{tab==="Apostas"?"Nenhuma aposta disponível. Esta funcionalidade ainda não foi ativada.":tab==="Audiência"?"Nenhuma transmissão ativa.":tab==="Mensagens"?"Mensagens ainda não disponíveis.":tab==="Arquivos"?"Nenhum arquivo publicado.":"As regras serão publicadas pela administração."}</p></section>}</>}</div></main>{notice&&<div className="toast"><CheckCircle size={18}/>{notice}<button onClick={()=>setNotice("")}>×</button></div>}</div>;
}