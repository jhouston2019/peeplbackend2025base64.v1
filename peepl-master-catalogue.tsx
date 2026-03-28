import { useState } from "react";
const B="#2244EE",N="#1133BB",Y="#FFD700",C="#00BBDD",GN="#22CC44";
const G={
  gym:"linear-gradient(160deg,#c8dcea,#a8c4d8,#90b0c8)",
  pure:"linear-gradient(135deg,#5d3410,#9a6228,#d89040)",
  food:"linear-gradient(160deg,#1a1a10,#2c2c18,#3a3a20)",
  joey:"linear-gradient(135deg,#c8e0b0,#e0f0c8,#a8c898)",
  conv:"linear-gradient(135deg,#281038,#401858,#582070)",
  ost:"linear-gradient(135deg,#2a1208,#501e0c,#783020)",
  park:"linear-gradient(160deg,#3a7a28,#5a9a3a,#88c060,#a8d890,#88c0e0)",
  b1:"linear-gradient(135deg,#280c0c,#582828,#903838)",
  b2:"linear-gradient(135deg,#0e2038,#204870,#3068b0)",
  b3:"linear-gradient(135deg,#102010,#285828,#409840)",
  cafe:"linear-gradient(135deg,#281608,#503020,#a07040,#c8a060)",
  crd:"linear-gradient(135deg,#281848,#402870,#5838a0)",
  apt:"linear-gradient(135deg,#383838,#585858,#787878)",
  brew:"linear-gradient(135deg,#281408,#503018,#885028)",
  tav:"linear-gradient(135deg,#201408,#402818,#684030)",
  out:"linear-gradient(135deg,#203010,#385820,#587838)",
  rest:"linear-gradient(135deg,#182010,#304020,#485830)",
  sta:"linear-gradient(135deg,#120a02,#381c08,#8a5018,#d89018)",
  amx:"linear-gradient(135deg,#906020,#c89040,#f0b860,#c07830)",
  taq:"linear-gradient(135deg,#602800,#a04810,#d07028)",
  ngt:"linear-gradient(135deg,#0c0c28,#202050,#343470)",
  mrc:"linear-gradient(135deg,#203020,#386838,#509050)",
};

// ── Shared UI ─────────────────────────────────────────────
function Ph({children}){
  return(
    <div style={{width:252,background:"#1a1a1a",borderRadius:40,padding:"10px 8px 14px",boxShadow:"0 22px 65px rgba(0,0,0,0.65)"}}>
      <div style={{display:"flex",justifyContent:"center",marginBottom:6}}>
        <div style={{width:54,height:5,background:"#2a2a2a",borderRadius:3}}/>
      </div>
      <div style={{borderRadius:24,overflow:"hidden",height:504,position:"relative"}}>
        <div style={{position:"absolute",inset:0,display:"flex",flexDirection:"column"}}>
          {children}
        </div>
      </div>
      <div style={{display:"flex",justifyContent:"center",marginTop:8}}>
        <div style={{width:80,height:4,background:"#333",borderRadius:2}}/>
      </div>
    </div>
  );
}
const Hdr=({l="Peep!",r="Get Peeps!"})=>(
  <div style={{background:B,display:"flex",alignItems:"center",justifyContent:"space-between",padding:"5px 12px 4px",flexShrink:0}}>
    <span style={{color:"#fff",fontSize:10,fontWeight:600,width:56}}>{l}</span>
    <span style={{color:"#fff",fontSize:15,fontWeight:900,fontStyle:"italic",letterSpacing:-0.5}}>peepl</span>
    <span style={{color:"#fff",fontSize:10,fontWeight:700,width:56,textAlign:"right"}}>{r}</span>
  </div>
);
const Strp=({t})=><div style={{background:N,padding:"2px 10px",flexShrink:0}}><span style={{color:"#fff",fontSize:10,fontWeight:700}}>{t}</span></div>;
const SHdr=({t})=><div style={{background:C,padding:"3px 10px",flexShrink:0}}><span style={{color:"#fff",fontSize:10,fontWeight:800}}>{t}</span></div>;
const VBB=()=>(
  <div style={{background:B,padding:"5px 8px",display:"flex",justifyContent:"center",gap:7,flexShrink:0}}>
    {["DEALS","*","Map","*","Menu","*","SHARE"].map((t,i)=><span key={i} style={{color:(t==="DEALS"||t==="SHARE")?Y:"#fff",fontSize:10,fontWeight:700}}>{t}</span>)}
  </div>
);
const HNav=()=>(
  <div style={{background:B,padding:"4px 0 5px",display:"flex",justifyContent:"space-around",flexShrink:0}}>
    {["Home","Menu","Search","Profile"].map((t,i)=><span key={t} style={{color:"#fff",fontSize:9,fontWeight:700}}>{t}{i<3?<span style={{color:"rgba(255,255,255,0.4)"}}> /</span>:""}</span>)}
  </div>
);
const ANv=({a="feed"})=>(
  <div style={{background:B,display:"flex",justifyContent:"space-around",padding:"3px 0 5px",flexShrink:0,borderTop:"1px solid rgba(255,255,255,0.15)"}}>
    {[{id:"deals",ic:"💲",lb:"Deals"},{id:"feed",ic:"p",lb:"Get Peeps"},{id:"profile",ic:"👤",lb:"Profile"}].map(t=>(
      <div key={t.id} style={{textAlign:"center"}}>
        {t.id==="feed"
          ?<div style={{width:18,height:18,borderRadius:"50%",background:a==="feed"?GN:"rgba(255,255,255,0.2)",display:"flex",alignItems:"center",justifyContent:"center",margin:"0 auto 1px"}}><span style={{color:"#fff",fontSize:10,fontWeight:900,fontStyle:"italic"}}>p</span></div>
          :<span style={{fontSize:14}}>{t.ic}</span>}
        <div style={{color:a===t.id?GN:"#bbb",fontSize:7,fontWeight:600}}>{t.lb}</div>
      </div>
    ))}
  </div>
);
const Tick=()=>(
  <div style={{background:"#1a88cc",padding:"2px 8px",flexShrink:0,display:"flex",gap:10}}>
    {[["Establishment",4],["Twain's",3],["Noche",3]].map(([n,v])=>(
      <span key={n} style={{color:"#fff",fontSize:8,fontWeight:700}}>{n} - <span style={{color:Y}}>{v}</span></span>
    ))}
  </div>
);
function DR({st,sz=36}){
  const n=12,r=sz*0.37,cx=sz/2,cy=sz/2,dr=sz*0.076;
  const M={"PACKED!":{c:"#EE2222",f:12},"BUSY":{c:"#4444EE",f:9},"MODERATE":{c:"#3366CC",f:7},"MEDIUM":{c:"#3377BB",f:6},"LIGHT":{c:"#3388AA",f:3},"EMPTY":{c:"#888",f:0}};
  const {c,f}=M[st]||{c:"#888",f:0};
  return(
    <svg width={sz} height={sz} style={{display:"block",filter:"drop-shadow(0 1px 5px rgba(0,0,0,0.9))"}}>
      {[...Array(n)].map((_,i)=>{const a=(i/n)*2*Math.PI-Math.PI/2;return<circle key={i} cx={cx+r*Math.cos(a)} cy={cy+r*Math.sin(a)} r={dr} fill={i<f?c:"rgba(255,255,255,0.15)"}/>;})  }
      <text x={cx} y={cy+1} textAnchor="middle" dominantBaseline="middle" fill="white" fontSize={st.length>5?sz*0.114:sz*0.15} fontWeight="900">{st}</text>
    </svg>
  );
}
const PBan=({nm="Rick Flair",sb="+Follow"})=>(
  <div style={{position:"relative",height:72,flexShrink:0}}>
    <div style={{position:"absolute",inset:0,background:G.cafe}}/>
    <div style={{position:"absolute",right:0,top:0,bottom:0,width:"55%",background:G.crd,opacity:0.7}}/>
    <div style={{position:"absolute",left:10,bottom:6,width:44,height:44,borderRadius:4,background:"linear-gradient(135deg,#8a6040,#c09060)",border:"2px solid #fff",display:"flex",alignItems:"center",justifyContent:"center",fontSize:22}}>🤼</div>
    <div style={{position:"absolute",left:62,bottom:14}}>
      <div style={{color:"#fff",fontSize:13,fontWeight:900,textShadow:"0 1px 4px rgba(0,0,0,0.9)"}}>{nm}</div>
      <div style={{color:C,fontSize:8,fontWeight:700}}>{sb}</div>
    </div>
  </div>
);
function Crd({venue,user,date,dist,status,mf,wait,ak,bg,hasVideo}){
  return(
    <div style={{flexShrink:0,marginBottom:3}}>
      <div style={{height:74,position:"relative",overflow:"hidden",background:bg||G.b1}}>
        <div style={{position:"absolute",inset:0,background:"linear-gradient(to bottom,rgba(0,0,0,0.05),rgba(0,0,0,0.6))"}}/>
        <div style={{position:"absolute",top:3,right:6,color:"#fff",fontSize:7,fontWeight:700}}>Crowd Size</div>
        <div style={{position:"absolute",top:10,right:3}}><DR st={status} sz={36}/></div>
        {(mf||wait||ak)&&<div style={{position:"absolute",top:10,right:42}}>
          {mf&&<div style={{color:"#fff",fontSize:7.5,fontWeight:700,textShadow:"0 1px 3px rgba(0,0,0,1)"}}>M/F: {mf}</div>}
          {wait&&<div style={{color:"#fff",fontSize:7.5,fontWeight:700,textShadow:"0 1px 3px rgba(0,0,0,1)"}}>Wait: {wait}</div>}
          {ak&&<div style={{color:"#fff",fontSize:7.5,fontWeight:700,textShadow:"0 1px 3px rgba(0,0,0,1)"}}>A/K: {ak}</div>}
        </div>}
        {hasVideo&&<div style={{position:"absolute",right:46,top:"50%",transform:"translateY(-50%)",width:24,height:24,borderRadius:"50%",background:"rgba(18,152,168,0.88)",display:"flex",alignItems:"center",justifyContent:"center"}}><div style={{borderTop:"5px solid transparent",borderBottom:"5px solid transparent",borderLeft:"9px solid #fff",marginLeft:2}}/></div>}
        {venue&&<div style={{position:"absolute",bottom:4,left:6,right:44}}><div style={{color:"#fff",fontSize:11,fontWeight:800,textShadow:"0 1px 5px rgba(0,0,0,1)",lineHeight:1.1}}>{venue}</div></div>}
      </div>
      <div style={{background:"rgba(20,20,20,0.92)",padding:"2px 8px",display:"flex",justifyContent:"space-between"}}>
        <span style={{color:"#ccc",fontSize:7.5}}>{user}</span>
        <span style={{color:"#ccc",fontSize:7.5}}>{date}</span>
        <span style={{color:"#ccc",fontSize:7.5}}>{dist}</span>
      </div>
    </div>
  );
}
function AdCrd({bg,headline,sub}){
  return(
    <div style={{height:72,position:"relative",background:bg,marginBottom:3}}>
      <div style={{position:"absolute",inset:0,background:"linear-gradient(to right,rgba(0,0,0,0.65),rgba(0,0,0,0.15))"}}/>
      <div style={{position:"absolute",top:4,left:7}}>
        <div style={{background:"rgba(255,255,255,0.2)",border:"1px solid rgba(255,255,255,0.4)",borderRadius:2,padding:"1px 5px",marginBottom:3,display:"inline-block"}}><span style={{color:"#fff",fontSize:7,fontWeight:700,letterSpacing:0.5}}>SPONSORED</span></div>
        <div style={{color:"#fff",fontSize:13,fontWeight:800,textShadow:"0 1px 4px rgba(0,0,0,0.9)"}}>{headline}</div>
        <div style={{color:"rgba(255,255,255,0.85)",fontSize:9}}>{sub}</div>
      </div>
    </div>
  );
}
function MixFeed({posts}){
  const ads=[{bg:G.sta,headline:"Stella Artois",sub:"She's a thing of beauty"},{bg:G.amx,headline:"American Express",sub:"Don't live life without it"}];
  const items=[];
  posts.forEach((p,i)=>{items.push({t:"p",d:p});if((i+1)%2===0)items.push({t:"a",d:ads[Math.floor(i/2)%2]});});
  return <div>{items.map((x,i)=>x.t==="a"?<AdCrd key={i} {...x.d}/>:<Crd key={i} {...x.d}/>)}</div>;
}
const Rw=({label,val})=>(
  <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",padding:"5px 12px",borderBottom:"1px solid #eee",background:"#fff"}}>
    <span style={{fontSize:10,color:"#222"}}>{label}</span>
    {val!==undefined&&<span style={{fontSize:10,color:B,fontWeight:800}}>{val}</span>}
  </div>
);
const Btn=({label,bg=B,tc="#fff",onTap})=>(
  <div onClick={onTap} style={{background:bg,borderRadius:20,padding:"10px 32px",textAlign:"center",cursor:"pointer",display:"inline-block"}}>
    <span style={{color:tc,fontSize:12,fontWeight:700}}>{label}</span>
  </div>
);

// ════════════════════════════════════════════════════════
// SCREENS
// ════════════════════════════════════════════════════════

// 1
function Splash(){
  return(
    <div style={{flex:1,background:B,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center"}}>
      <div style={{fontSize:68,fontWeight:900,fontStyle:"italic",color:"#fff",letterSpacing:-3}}>peepl</div>
      <div style={{color:"rgba(255,255,255,0.7)",fontSize:11,marginTop:8,letterSpacing:2}}>KNOW BEFORE YOU GO</div>
      <div style={{marginTop:60,width:40,height:40,borderRadius:"50%",background:"rgba(255,255,255,0.15)",display:"flex",alignItems:"center",justifyContent:"center"}}>
        <div style={{width:0,height:0,borderTop:"8px solid transparent",borderBottom:"8px solid transparent",borderLeft:"14px solid rgba(255,255,255,0.8)",marginLeft:3}}/>
      </div>
    </div>
  );
}
// 2–4
function OB({step}){
  const s=[
    {ic:"👥",ti:"Know Before You Go",bo:"See real-time crowd levels from real people at bars, restaurants, parks, and events near you."},
    {ic:"📍",ti:"Real People, Real Time",bo:"Every Peep is posted by someone there right now. See crowd size, vibe, and wait times before you leave."},
    {ic:"🏆",ti:"Become a Pioneer",bo:"Be first to Peep a new venue and earn Pioneer status. Climb the leaderboard and unlock VIPeeps."},
  ][step-1];
  return(
    <div style={{flex:1,background:"#fff",display:"flex",flexDirection:"column"}}>
      <div style={{background:B,height:220,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",flexShrink:0}}>
        <div style={{fontSize:64}}>{s.ic}</div>
        <div style={{color:"#fff",fontSize:16,fontWeight:900,marginTop:12,textAlign:"center",padding:"0 20px"}}>{s.ti}</div>
      </div>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"space-between",padding:"24px 20px 20px"}}>
        <div style={{color:"#444",fontSize:12,textAlign:"center",lineHeight:1.6}}>{s.bo}</div>
        <div style={{width:"100%"}}>
          <div style={{display:"flex",gap:8,justifyContent:"center",marginBottom:18}}>
            {[1,2,3].map(d=><div key={d} style={{width:8,height:8,borderRadius:"50%",background:d===step?B:"#ddd"}}/>)}
          </div>
          <div style={{background:B,borderRadius:24,padding:"11px 0",textAlign:"center"}}><span style={{color:"#fff",fontSize:13,fontWeight:700}}>{step===3?"Get Started →":"Next →"}</span></div>
        </div>
      </div>
    </div>
  );
}
// 5
function SignIn(){
  return(
    <div style={{flex:1,background:G.out,position:"relative",display:"flex",flexDirection:"column"}}>
      <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.45)"}}/>
      <div style={{position:"relative",zIndex:1,display:"flex",flexDirection:"column",alignItems:"center",padding:"40px 24px 0",flex:1}}>
        <div style={{fontSize:50,fontWeight:900,fontStyle:"italic",color:B,textShadow:"0 2px 8px rgba(255,255,255,0.4)",marginBottom:48}}>peepl</div>
        {[["Email Address","user@example.com"],["Password","••••••••"]].map(([l,ph],ti)=>(
          <div key={l} style={{width:"100%",marginBottom:18}}>
            <div style={{color:"#eee",fontSize:12,fontWeight:700,marginBottom:4}}>{l}</div>
            <div style={{background:"rgba(255,255,255,0.92)",borderRadius:8,padding:"10px 12px",fontSize:12,color:ti===1?"#bbb":"#555"}}>{ph}</div>
          </div>
        ))}
        <div style={{background:"#111",color:"#fff",borderRadius:8,padding:"13px",textAlign:"center",fontWeight:700,fontSize:14,width:"100%",marginBottom:16}}>Log In</div>
        <span style={{background:"rgba(255,255,255,0.9)",color:B,fontSize:11,fontWeight:700,borderRadius:16,padding:"5px 14px"}}>Don't have an account? Sign Up</span>
      </div>
    </div>
  );
}
// 6
function SignUp(){
  return(
    <div style={{flex:1,background:"#fff",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back" r=""/>
      <Strp t="Create Your Account"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"14px"}}>
        {[["Your Name","e.g. Rick Flair"],["Username","e.g. rickflair"],["Email","you@email.com"],["Password","min. 6 chars"],["Confirm Password","repeat password"]].map(([l,ph])=>(
          <div key={l} style={{marginBottom:12}}>
            <div style={{fontSize:10,fontWeight:700,color:"#333",marginBottom:3}}>{l}</div>
            <div style={{background:"#f4f4f4",borderRadius:8,padding:"8px 12px",fontSize:11,color:"#aaa",border:"1px solid #e0e0e0"}}>{ph}</div>
          </div>
        ))}
        <div style={{background:B,borderRadius:8,padding:"12px",textAlign:"center"}}><span style={{color:"#fff",fontSize:13,fontWeight:700}}>Create Account</span></div>
        <div style={{textAlign:"center",marginTop:10}}><span style={{color:B,fontSize:10}}>Already have an account? Sign In</span></div>
      </div>
    </div>
  );
}
// 7
function Confirmed(){
  return(
    <div style={{flex:1,background:B,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
      <div style={{fontSize:56}}>🎉</div>
      <div style={{color:"#fff",fontSize:20,fontWeight:900,marginTop:16,textAlign:"center"}}>Welcome to Peepl!</div>
      <div style={{color:"rgba(255,255,255,0.8)",fontSize:12,textAlign:"center",marginTop:12,lineHeight:1.6}}>You're all set. Start exploring what's happening near you — or Peep your first spot and become a Pioneer.</div>
      <div style={{background:"#fff",borderRadius:24,padding:"12px 40px",marginTop:32}}><span style={{color:B,fontSize:13,fontWeight:800}}>Let's Go →</span></div>
    </div>
  );
}
// 8
function LocPerm(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 20px"}}>
        <div style={{fontSize:48}}>📍</div>
        <div style={{color:"#111",fontSize:15,fontWeight:900,marginTop:16,textAlign:"center"}}>Allow Location Access</div>
        <div style={{color:"#555",fontSize:11,textAlign:"center",marginTop:8,lineHeight:1.6,maxWidth:200}}>Peepl needs your location to show crowd reports near you and let others know where you're Peepling from.</div>
        <div style={{background:"#fff",borderRadius:14,padding:"14px 18px",marginTop:24,width:"100%",boxShadow:"0 4px 20px rgba(0,0,0,0.12)"}}>
          <div style={{color:"#111",fontSize:11,fontWeight:700,textAlign:"center",marginBottom:10}}>Allow "Peepl" to use your location?</div>
          {["Allow While Using App","Allow Once","Don't Allow"].map((t,i)=>(
            <div key={t} style={{padding:"8px",borderTop:i>0?"1px solid #eee":"none",textAlign:"center"}}><span style={{color:i<2?B:"#e53935",fontSize:12,fontWeight:700}}>{t}</span></div>
          ))}
        </div>
      </div>
    </div>
  );
}
// 9
function PushPerm(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 20px"}}>
        <div style={{fontSize:48}}>🔔</div>
        <div style={{color:"#111",fontSize:15,fontWeight:900,marginTop:16,textAlign:"center"}}>Stay in the Know</div>
        <div style={{color:"#555",fontSize:11,textAlign:"center",marginTop:8,lineHeight:1.6,maxWidth:200}}>Get notified when your favorite spots get crowded, when someone Peeps a venue you Pioneer, or when friends check in.</div>
        <div style={{background:"#fff",borderRadius:14,padding:"14px 18px",marginTop:24,width:"100%",boxShadow:"0 4px 20px rgba(0,0,0,0.12)"}}>
          <div style={{color:"#111",fontSize:11,fontWeight:700,textAlign:"center",marginBottom:6}}>"Peepl" Would Like to Send Notifications</div>
          <div style={{color:"#777",fontSize:9,textAlign:"center",marginBottom:10}}>Crowd alerts, Pioneer updates, friend activity.</div>
          {["Allow","Don't Allow"].map((t,i)=>(
            <div key={t} style={{padding:"9px",borderTop:i>0?"1px solid #eee":"none",textAlign:"center"}}><span style={{color:i===0?B:"#e53935",fontSize:12,fontWeight:700}}>{t}</span></div>
          ))}
        </div>
      </div>
    </div>
  );
}
// 10
function MainFeed(){
  const posts=[
    {venue:"Joey D's Oak Room",user:"anon-7b888",date:"5/19 8:29PM",dist:"3 mi",status:"PACKED!",mf:"50/50",wait:"Minutes",bg:G.joey},
    {venue:"Georgia Intl Conv Ctr",user:"anon-91703",date:"5/15 6:36PM",dist:"19 mi",status:"BUSY",hasVideo:true,bg:G.conv},
    {venue:"Osteria 832",user:"anon-7b888",date:"5/14 7:05PM",dist:"8 mi",status:"BUSY",wait:"None",bg:G.ost},
    {venue:"Piedmont Park",user:"anon-7b888",date:"5/13 4:15PM",dist:"2 mi",status:"MODERATE",mf:"50/50",ak:"30/70",bg:G.park},
  ];
  return(
    <div style={{flex:1,background:"#181818",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <Strp t="What's happening"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}><MixFeed posts={posts}/></div>
      <ANv a="feed"/>
    </div>
  );
}
// 11
function SearchScr(){
  const posts=[
    {venue:"Sivas Tavern",user:"chazz26",date:"11/4 9:21PM",dist:"16 mi",status:"LIGHT",mf:"50/50",bg:G.tav},
    {venue:"Chomp and Stomp",user:"LordByron",date:"11/4 1:58PM",dist:"10 mi",status:"PACKED!",mf:"50/50",bg:G.out},
    {venue:"Starbucks",user:"jeff",date:"10/25 9:05AM",dist:"5 mi",status:"MODERATE",wait:"A minute",bg:G.rest},
    {venue:"Two Birds Taphouse",user:"chazz26",date:"10/24 6:53PM",dist:"13 mi",status:"BUSY",mf:"50/50",bg:G.pure},
  ];
  return(
    <div style={{flex:1,background:"#181818",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel"/>
      <div style={{background:B,padding:"4px 10px 5px",display:"flex",alignItems:"center",gap:6,flexShrink:0}}>
        <span style={{color:"#fff",fontSize:11,fontWeight:700}}>≡↓</span>
        <div style={{flex:1,background:"rgba(255,255,255,0.2)",borderRadius:8,padding:"5px 10px"}}>
          <span style={{color:"rgba(255,255,255,0.55)",fontSize:10}}>🔍 Search for a place</span>
        </div>
      </div>
      <Strp t="What's happening"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}><MixFeed posts={posts}/></div>
      <div style={{background:B,padding:"3px 8px 4px",display:"flex",gap:3,flexShrink:0}}>
        {["Deals","Peeps","Profiles"].map(t=><div key={t} style={{flex:1,background:"rgba(255,255,255,0.1)",border:"1px solid rgba(100,160,255,0.4)",borderRadius:3,padding:"4px 0",textAlign:"center"}}><span style={{color:"#88aaff",fontSize:9,fontWeight:700}}>{t}</span></div>)}
      </div>
    </div>
  );
}
// 12 — Search Results
function SearchResults(){
  const results=[
    {nm:"Piedmont Park",bg:G.park,st:"MODERATE",dist:"2 mi",cnt:8},
    {nm:"Joey D's Oak Room",bg:G.joey,st:"PACKED!",dist:"3 mi",cnt:15},
    {nm:"Osteria 832",bg:G.ost,st:"BUSY",dist:"8 mi",cnt:5},
    {nm:"Monday Night Brewing",bg:G.brew,st:"BUSY",dist:"12 mi",cnt:9},
    {nm:"Establishment",bg:G.b1,st:"MODERATE",dist:"4 mi",cnt:11},
  ];
  return(
    <div style={{flex:1,background:"#f4f4f4",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel"/>
      <div style={{background:B,padding:"4px 10px 5px",display:"flex",alignItems:"center",gap:6,flexShrink:0}}>
        <div style={{flex:1,background:"rgba(255,255,255,0.9)",borderRadius:8,padding:"5px 10px",display:"flex",gap:5}}>
          <span style={{fontSize:10}}>🔍</span><span style={{color:"#333",fontSize:10,fontWeight:600}}>Piedmont</span>
        </div>
        <span style={{color:"rgba(255,255,255,0.7)",fontSize:9}}>Cancel</span>
      </div>
      <div style={{background:"#eee",padding:"3px 10px",flexShrink:0}}><span style={{fontSize:9,color:"#888"}}>{results.length} results near Atlanta, GA</span></div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {results.map((r,i)=>(
          <div key={i} style={{display:"flex",marginBottom:2,alignItems:"stretch"}}>
            <div style={{width:52,height:44,background:r.bg,flexShrink:0}}/>
            <div style={{flex:1,padding:"5px 10px",background:"#fff",borderBottom:"1px solid #eee"}}>
              <div style={{fontSize:11,fontWeight:700}}>{r.nm}</div>
              <div style={{fontSize:8,color:"#888",marginTop:1}}>{r.dist} · {r.cnt} reports</div>
            </div>
            <div style={{width:44,height:44,background:r.bg,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
              <DR st={r.st} sz={30}/>
            </div>
          </div>
        ))}
      </div>
      <div style={{background:B,padding:"3px 8px 4px",display:"flex",gap:3,flexShrink:0}}>
        {["Deals","Peeps","Profiles"].map(t=><div key={t} style={{flex:1,background:"rgba(255,255,255,0.1)",border:"1px solid rgba(100,160,255,0.4)",borderRadius:3,padding:"4px 0",textAlign:"center"}}><span style={{color:"#88aaff",fontSize:9,fontWeight:700}}>{t}</span></div>)}
      </div>
    </div>
  );
}
// 13
function Trending(){
  const venues=[
    {nm:"Piedmont Park",st:"PACKED!",bg:G.park,cnt:12,dist:"2 mi",trend:"↑ Getting busier"},
    {nm:"Monday Night Brewing",st:"BUSY",bg:G.brew,cnt:8,dist:"5 mi",trend:"→ Steady"},
    {nm:"Pure Taqueria",st:"BUSY",bg:G.taq,cnt:5,dist:"1 mi",trend:"↓ Clearing out"},
    {nm:"LA Fitness",st:"MEDIUM",bg:G.gym,cnt:4,dist:"3 mi",trend:"→ Steady"},
  ];
  return(
    <div style={{flex:1,background:"#181818",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <Strp t="🔥 Trending Now"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {venues.map((v,i)=>(
          <div key={i} style={{height:80,background:v.bg,position:"relative",marginBottom:3}}>
            <div style={{position:"absolute",inset:0,background:"linear-gradient(to bottom,rgba(0,0,0,0.05),rgba(0,0,0,0.6))"}}/>
            <div style={{position:"absolute",top:3,right:6,color:"#fff",fontSize:7,fontWeight:700}}>Crowd Size</div>
            <div style={{position:"absolute",top:10,right:3}}><DR st={v.st} sz={36}/></div>
            <div style={{position:"absolute",bottom:5,left:8}}>
              <div style={{color:"#fff",fontSize:12,fontWeight:800,textShadow:"0 1px 5px rgba(0,0,0,1)"}}>{v.nm}</div>
              <div style={{display:"flex",gap:8,marginTop:2}}>
                <span style={{color:"rgba(255,255,255,0.8)",fontSize:8}}>{v.cnt} peeps today · {v.dist}</span>
                <span style={{color:C,fontSize:8,fontWeight:700}}>{v.trend}</span>
              </div>
            </div>
          </div>
        ))}
      </div>
      <ANv a="feed"/>
    </div>
  );
}
// 14
function NoConn(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
        <div style={{fontSize:48}}>📵</div>
        <div style={{color:"#222",fontSize:15,fontWeight:900,marginTop:16,textAlign:"center"}}>No Connection</div>
        <div style={{color:"#666",fontSize:11,textAlign:"center",marginTop:8,lineHeight:1.6}}>Peepl needs internet to show live crowd data. Check your Wi-Fi or cellular signal.</div>
        <div style={{marginTop:24}}><Btn label="Try Again"/></div>
      </div>
    </div>
  );
}
// 15
function VenuePg(){
  const posts=[
    {venue:"Piedmont Park",user:"LordByron",date:"11/4 1:58PM",dist:"10 mi",status:"PACKED!",mf:"50/50",ak:"70/30",bg:G.park},
    {venue:"Piedmont Park",user:"Messi",date:"11/3 3:12PM",dist:"10 mi",status:"BUSY",mf:"60/40",bg:G.park},
    {venue:"Piedmont Park",user:"RickFlair",date:"11/2 5:00PM",dist:"10 mi",status:"MODERATE",bg:G.park},
  ];
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{background:G.park,height:80,position:"relative",flexShrink:0}}>
        <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.3)"}}/>
        <div style={{position:"absolute",bottom:8,left:10}}>
          <div style={{color:"#fff",fontSize:15,fontWeight:900,textShadow:"0 1px 6px rgba(0,0,0,1)"}}>Piedmont Park</div>
          <div style={{color:"rgba(255,255,255,0.85)",fontSize:8}}>1342 Worchester Dr NE, Atlanta GA</div>
        </div>
        <div style={{position:"absolute",top:8,right:8,textAlign:"right"}}>
          <div style={{color:"#fff",fontSize:8,fontWeight:700}}>Avg now: <span style={{color:Y}}>7</span></div>
          <div style={{color:"rgba(255,255,255,0.8)",fontSize:7}}>All-time: 4.2</div>
        </div>
      </div>
      <div style={{background:"#fff",border:"2px solid #e53935",margin:"4px 6px",borderRadius:2,padding:"3px 6px",textAlign:"center",flexShrink:0}}>
        <span style={{color:"#e53935",fontWeight:900,fontSize:10}}>*** FREE DASANI ALL DAY ***</span>
      </div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>{posts.map((p,i)=><Crd key={i} {...p}/>)}</div>
      <VBB/>
    </div>
  );
}
// 16 — Venue with inline ad
function VenueWithAd(){
  const posts=[
    {venue:"Piedmont Park",user:"LordByron",date:"11/4 1:58PM",dist:"10 mi",status:"PACKED!",mf:"50/50",bg:G.park},
    {venue:"Piedmont Park",user:"Messi",date:"11/3 3:12PM",dist:"10 mi",status:"BUSY",bg:G.park},
  ];
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{background:G.park,height:70,position:"relative",flexShrink:0}}>
        <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.3)"}}/>
        <div style={{position:"absolute",bottom:6,left:10}}><div style={{color:"#fff",fontSize:14,fontWeight:900,textShadow:"0 1px 5px rgba(0,0,0,1)"}}>Piedmont Park</div></div>
      </div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        <Crd {...posts[0]}/>
        <Crd {...posts[1]}/>
        <AdCrd bg={G.sta} headline="Stella Artois" sub="She's a thing of beauty"/>
      </div>
      <VBB/>
    </div>
  );
}
// 17
function NoPeeps(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{background:G.park,height:72,position:"relative",flexShrink:0}}>
        <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.3)"}}/>
        <div style={{position:"absolute",bottom:8,left:10}}><div style={{color:"#fff",fontSize:14,fontWeight:900,textShadow:"0 1px 5px rgba(0,0,0,1)"}}>Chastain Park</div></div>
      </div>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
        <div style={{fontSize:40}}>👀</div>
        <div style={{color:"#222",fontSize:14,fontWeight:900,marginTop:12,textAlign:"center"}}>No Peeps Yet</div>
        <div style={{color:"#666",fontSize:11,textAlign:"center",marginTop:8,lineHeight:1.6}}>Be the first to Peep this spot and earn Pioneer status!</div>
        <div style={{marginTop:20}}><Btn label="Peep Here →"/></div>
      </div>
      <VBB/>
    </div>
  );
}
// 18
function PeepDetail(){
  const [liked,setLiked]=useState(false);
  const [likes,setLikes]=useState(37);
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{background:B,padding:"8px 12px",display:"flex",justifyContent:"space-between",flexShrink:0}}>
        <div>
          <div style={{color:"#fff",fontWeight:900,fontSize:13}}>Piedmont Park</div>
          <div style={{color:"#ccc",fontSize:8,marginTop:2}}>Crowd Size</div>
          <DR st="BUSY" sz={56}/>
          <div style={{color:"#ddd",fontSize:8,marginTop:2}}>M/F: 50/50 · A/K: 70/30</div>
          <div style={{color:"#ddd",fontSize:8}}>Vibe: Laid Back</div>
        </div>
        <div style={{textAlign:"right"}}>
          <div style={{color:"#ddd",fontSize:9}}>11/12 3:45pm</div>
          <div style={{width:38,height:38,borderRadius:"50%",background:G.cafe,marginTop:6,display:"flex",alignItems:"center",justifyContent:"center",fontSize:20,marginLeft:"auto"}}>🤼</div>
          <div style={{color:"#fff",fontWeight:700,fontSize:10,marginTop:2}}>Rick Flair</div>
          <div style={{color:C,fontSize:9}}>+Follow</div>
        </div>
      </div>
      <div style={{padding:"5px 10px 3px",background:"#fff",flexShrink:0}}><span style={{fontSize:12,fontWeight:700}}>Sax Man!</span></div>
      <div style={{height:100,background:G.park,flexShrink:0}}/>
      <div style={{background:"#e0e0e0",padding:"6px 14px",display:"flex",justifyContent:"space-between",flexShrink:0}}>
        <span onClick={()=>{setLiked(!liked);setLikes(l=>liked?l-1:l+1);}} style={{color:liked?"#e53935":B,fontSize:12,fontWeight:700,cursor:"pointer"}}>+ Like</span>
        <span style={{color:B,fontSize:12,fontWeight:700}}>+ Comment</span>
        <span style={{color:"#c8a000",fontSize:12,fontWeight:700}}>+ Share</span>
      </div>
      <div style={{padding:"2px 10px",background:"#e0e0e0",flexShrink:0}}><span style={{fontSize:9,fontWeight:700}}>{likes} Likes</span></div>
      <div style={{flex:1,overflowY:"auto",padding:"6px 10px",background:"#fff",scrollbarWidth:"none"}}>
        <div style={{fontSize:11,fontWeight:900,marginBottom:4,textDecoration:"underline"}}>Comments</div>
        {[["Rick James","Enjoy yourself!"],["Parker Posey","I love grass."],["Oprah","I'll show you how to blow."]].map(([u,t])=>(
          <div key={u} style={{fontSize:10,marginBottom:4}}><span style={{fontWeight:800,color:B}}>{u}:</span><span style={{color:"#333"}}> {t}</span></div>
        ))}
      </div>
      <VBB/>
    </div>
  );
}
// 19 — Likers page
function LikersPage(){
  const likers=[{ic:"👩",nm:"Doris Day",tm:"2m ago"},{ic:"⚽",nm:"Messi",tm:"5m ago"},{ic:"🤼",nm:"Rick Flair",tm:"8m ago"},{ic:"🦜",nm:"Big Blo",tm:"12m ago"},{ic:"🐦",nm:"Toucan Sam",tm:"20m ago"},{ic:"👤",nm:"anon-91703",tm:"1h ago"}];
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back"/>
      <Strp t="Liked by"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {likers.map((p,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"8px 12px",borderBottom:"1px solid #eee",gap:10,background:"#fff"}}>
            <div style={{width:34,height:34,borderRadius:"50%",background:G.crd,display:"flex",alignItems:"center",justifyContent:"center",fontSize:18,flexShrink:0}}>{p.ic}</div>
            <span style={{fontSize:11,fontWeight:700,flex:1}}>{p.nm}</span>
            <span style={{fontSize:8,color:"#aaa"}}>{p.tm}</span>
          </div>
        ))}
      </div>
      <VBB/>
    </div>
  );
}
// 20
function PeepCreate(){
  const [crowd,setCrowd]=useState(7);
  const [vibe,setVibe]=useState("Trendy");
  const [wait,setWait]=useState("5-10m");
  const [music,setMusic]=useState(false);
  const [wc,setWc]=useState(false);
  const cc=crowd<=3?GN:crowd<=6?Y:"#EE2222";
  return(
    <div style={{flex:1,background:"#f5f5f5",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel" r="Peep!"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{display:"flex",alignItems:"center",gap:6,marginBottom:8}}>
            <span>📍</span><span style={{fontSize:11,fontWeight:700,width:48}}>Location</span>
            <div style={{flex:1,border:"1px solid #ddd",borderRadius:6,padding:"5px 8px",fontSize:11,color:"#333"}}>Central Park</div>
          </div>
          <div style={{display:"flex",alignItems:"center",gap:6}}>
            <span>📸</span><span style={{fontSize:11,fontWeight:700,width:48}}>Photo</span>
            <div style={{flex:1,height:50,background:G.park,borderRadius:6,display:"flex",alignItems:"center",justifyContent:"center"}}>
              <span style={{color:"rgba(255,255,255,0.85)",fontSize:10}}>+ Add Photo</span>
            </div>
          </div>
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{display:"flex",alignItems:"center",gap:6,marginBottom:4}}>
            <span>👥</span><span style={{fontSize:11,fontWeight:700,flex:1}}>Crowd Level</span>
            <span style={{fontWeight:900,fontSize:13,color:cc}}>{crowd}</span>
          </div>
          <input type="range" min={0} max={10} value={crowd} onChange={e=>setCrowd(+e.target.value)} style={{width:"100%",accentColor:B}}/>
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{display:"flex",gap:5,flexWrap:"wrap",marginBottom:7}}>
            <span style={{fontSize:10,fontWeight:700}}>✨ Vibe:</span>
            {["Cozy","Casual","Trendy","Upscale"].map(v=>(
              <span key={v} onClick={()=>setVibe(v)} style={{padding:"2px 8px",borderRadius:10,background:vibe===v?B:"#eee",color:vibe===v?"#fff":"#333",fontSize:9,cursor:"pointer",fontWeight:vibe===v?700:400}}>{v}</span>
            ))}
          </div>
          <div style={{display:"flex",gap:5,flexWrap:"wrap"}}>
            <span style={{fontSize:10,fontWeight:700}}>⏱️ Wait:</span>
            {["No wait","5-10m","15-20m","30m+"].map(w=>(
              <span key={w} onClick={()=>setWait(w)} style={{padding:"2px 8px",borderRadius:10,background:wait===w?B:"#eee",color:wait===w?"#fff":"#333",fontSize:9,cursor:"pointer",fontWeight:wait===w?700:400}}>{w}</span>
            ))}
          </div>
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          {[["🎵","Music/Entertainment",music,setMusic],["♿","Wheelchair Access",wc,setWc]].map(([em,lb,val,set])=>(
            <div key={lb} style={{display:"flex",alignItems:"center",marginBottom:4}}>
              <span style={{fontSize:13,marginRight:6}}>{em}</span><span style={{flex:1,fontSize:10}}>{lb}</span>
              <div onClick={()=>set(!val)} style={{width:32,height:18,borderRadius:9,background:val?B:"#ccc",cursor:"pointer",position:"relative"}}>
                <div style={{width:14,height:14,borderRadius:"50%",background:"#fff",position:"absolute",top:2,left:val?16:2,transition:"left 0.2s"}}/>
              </div>
            </div>
          ))}
        </div>
        <div style={{background:"#FFC107",borderRadius:10,padding:"12px",textAlign:"center",fontWeight:700,fontSize:13,cursor:"pointer"}}>📤 Submit Peep</div>
      </div>
    </div>
  );
}
// 21 — Peep with photo selected
function PeepWithPhoto(){
  const [crowd,setCrowd]=useState(8);
  const cc=crowd<=3?GN:crowd<=6?Y:"#EE2222";
  return(
    <div style={{flex:1,background:"#f5f5f5",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel" r="Peep!"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{display:"flex",alignItems:"center",gap:6,marginBottom:8}}>
            <span>📍</span><span style={{fontSize:11,fontWeight:700,width:48}}>Location</span>
            <div style={{flex:1,border:"1px solid #ddd",borderRadius:6,padding:"5px 8px",fontSize:11,color:"#333"}}>Piedmont Park</div>
          </div>
          <div style={{display:"flex",alignItems:"center",gap:6}}>
            <span>📸</span><span style={{fontSize:11,fontWeight:700,width:48}}>Photo</span>
            <div style={{flex:1,height:64,background:G.park,borderRadius:6,position:"relative",overflow:"hidden"}}>
              <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.15)"}}/>
              <div style={{position:"absolute",bottom:4,right:6,background:"rgba(0,0,0,0.6)",borderRadius:4,padding:"2px 6px"}}><span style={{color:"#fff",fontSize:8}}>✎ Change</span></div>
              <div style={{position:"absolute",bottom:4,left:6}}><span style={{color:"#fff",fontSize:8,fontWeight:700}}>Photo selected ✓</span></div>
            </div>
          </div>
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{display:"flex",alignItems:"center",gap:6,marginBottom:4}}>
            <span>👥</span><span style={{fontSize:11,fontWeight:700,flex:1}}>Crowd Level</span>
            <span style={{fontWeight:900,fontSize:13,color:cc}}>{crowd}</span>
          </div>
          <input type="range" min={0} max={10} value={crowd} onChange={e=>setCrowd(+e.target.value)} style={{width:"100%",accentColor:B}}/>
        </div>
        <div style={{background:"#FFC107",borderRadius:10,padding:"12px",textAlign:"center",fontWeight:700,fontSize:13,cursor:"pointer"}}>📤 Submit Peep</div>
      </div>
    </div>
  );
}
// 22
function PeepSubmit(){
  return(
    <div style={{flex:1,background:"#fff",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
      <div style={{fontSize:52}}>✅</div>
      <div style={{color:B,fontSize:18,fontWeight:900,marginTop:16,textAlign:"center"}}>Peep Submitted!</div>
      <div style={{color:"#555",fontSize:11,textAlign:"center",marginTop:10,lineHeight:1.6}}>Your crowd report is live. Checking if you're the first to Peep this spot...</div>
      <div style={{marginTop:24,display:"flex",gap:4}}>{[1,0.5,0.2].map((o,i)=><div key={i} style={{width:8,height:8,borderRadius:"50%",background:B,opacity:o}}/>)}</div>
    </div>
  );
}
// 23
function Pioneer(){
  return(
    <div style={{flex:1,background:G.ngt,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
      <div style={{fontSize:64}}>🏆</div>
      <div style={{color:Y,fontSize:22,fontWeight:900,marginTop:12,textAlign:"center"}}>You're a Pioneer!</div>
      <div style={{color:"rgba(255,255,255,0.85)",fontSize:12,textAlign:"center",marginTop:10,lineHeight:1.6}}>You were the first to Peep Piedmont Park. You've earned Pioneer status and 500 points!</div>
      <div style={{background:Y,borderRadius:24,padding:"12px 36px",marginTop:28}}><span style={{color:"#111",fontSize:13,fontWeight:900}}>Claim Your Badge 🏅</span></div>
    </div>
  );
}
// 24
function Deals(){
  const d=[
    {nm:"Monday Night Brewing",offer:"$2 off all pints",ends:"2h 14m",dist:"3 mi",bg:G.brew,live:true},
    {nm:"Osteria 832",offer:"Happy Hour: 50% off apps",ends:"45m",dist:"8 mi",bg:G.ost,live:true},
    {nm:"Pure Taqueria",offer:"Free chips and salsa",ends:"3h 30m",dist:"1 mi",bg:G.taq,live:false},
  ];
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="💰 Active Deals Near You"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {d.map((x,i)=>(
          <div key={i} style={{marginBottom:3}}>
            <div style={{height:90,background:x.bg,position:"relative"}}>
              <div style={{position:"absolute",inset:0,background:"linear-gradient(to bottom,rgba(0,0,0,0.05),rgba(0,0,0,0.7))"}}/>
              <div style={{position:"absolute",top:6,right:8,background:x.live?"#e53935":"#555",borderRadius:10,padding:"2px 8px"}}><span style={{color:"#fff",fontSize:8,fontWeight:700}}>{x.live?"LIVE":"UPCOMING"}</span></div>
              <div style={{position:"absolute",bottom:6,left:8,right:8}}>
                <div style={{color:"#fff",fontSize:12,fontWeight:900,textShadow:"0 1px 3px rgba(0,0,0,1)"}}>{x.nm}</div>
                <div style={{color:Y,fontSize:10,fontWeight:700}}>{x.offer}</div>
                <div style={{display:"flex",justifyContent:"space-between",marginTop:3}}>
                  <span style={{color:"rgba(255,255,255,0.75)",fontSize:8}}>⏱ Ends in {x.ends} · {x.dist}</span>
                  <div style={{background:B,borderRadius:10,padding:"2px 10px"}}><span style={{color:"#fff",fontSize:8,fontWeight:700}}>Claim</span></div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
      <ANv a="deals"/>
    </div>
  );
}
// 25
function DealClaimed(){
  return(
    <div style={{flex:1,background:GN,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
      <div style={{fontSize:56}}>🎟️</div>
      <div style={{color:"#fff",fontSize:20,fontWeight:900,marginTop:16,textAlign:"center"}}>Deal Claimed!</div>
      <div style={{background:"rgba(255,255,255,0.2)",borderRadius:12,padding:"16px",marginTop:16,width:"100%",textAlign:"center"}}>
        <div style={{color:"#fff",fontSize:12,fontWeight:700}}>Monday Night Brewing</div>
        <div style={{color:"rgba(255,255,255,0.9)",fontSize:11,marginTop:4}}>$2 off all pints</div>
        <div style={{color:"rgba(255,255,255,0.7)",fontSize:9,marginTop:6}}>Show this screen to your server</div>
        <div style={{color:"#fff",fontSize:28,fontWeight:900,marginTop:8,letterSpacing:4}}>MNB-4829</div>
      </div>
      <div style={{color:"rgba(255,255,255,0.7)",fontSize:10,marginTop:16}}>Expires in 45 minutes</div>
    </div>
  );
}
// 26
function GetPeeps(){
  const [mode,setMode]=useState("near");
  const venues=[
    {nm:"Piedmont Park",st:"PACKED!",bg:G.park,cnt:12,dist:"2 mi"},
    {nm:"Monday Night Brewing",st:"BUSY",bg:G.brew,cnt:8,dist:"5 mi"},
    {nm:"Pure Taqueria",st:"BUSY",bg:G.taq,cnt:5,dist:"1 mi"},
    {nm:"LA Fitness",st:"MEDIUM",bg:G.gym,cnt:4,dist:"3 mi"},
  ];
  return(
    <div style={{flex:1,background:"#181818",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{background:B,padding:"4px 8px",display:"flex",gap:3,flexShrink:0}}>
        {[["near","Near Me"],["city","New City"],["venue","Venue"]].map(([k,l])=>(
          <div key={k} onClick={()=>setMode(k)} style={{flex:1,background:mode===k?"rgba(255,255,255,0.25)":"rgba(255,255,255,0.08)",borderRadius:6,padding:"4px 0",textAlign:"center",cursor:"pointer"}}>
            <span style={{color:mode===k?"#fff":"rgba(255,255,255,0.6)",fontSize:8,fontWeight:700}}>{l}</span>
          </div>
        ))}
      </div>
      <Strp t="What's happening near you"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {venues.map((v,i)=>(
          <div key={i} style={{height:74,background:v.bg,position:"relative",marginBottom:3}}>
            <div style={{position:"absolute",inset:0,background:"linear-gradient(to bottom,rgba(0,0,0,0.05),rgba(0,0,0,0.6))"}}/>
            <div style={{position:"absolute",top:3,right:6,color:"#fff",fontSize:7,fontWeight:700}}>Crowd Size</div>
            <div style={{position:"absolute",top:10,right:3}}><DR st={v.st} sz={36}/></div>
            <div style={{position:"absolute",bottom:4,left:6}}>
              <div style={{color:"#fff",fontSize:11,fontWeight:800,textShadow:"0 1px 5px rgba(0,0,0,1)"}}>{v.nm}</div>
              <div style={{color:"rgba(255,255,255,0.75)",fontSize:7}}>{v.cnt} peeps · {v.dist}</div>
            </div>
          </div>
        ))}
      </div>
      <ANv a="feed"/>
    </div>
  );
}
// 27
function MapScr(){
  const dots=[{x:60,y:80,s:"PACKED!",n:"Piedmont"},{x:120,y:130,s:"BUSY",n:"Joey D's"},{x:180,y:90,s:"MODERATE",n:"Osteria"},{x:90,y:180,s:"LIGHT",n:"Starbucks"},{x:160,y:200,s:"PACKED!",n:"Airport"}];
  const sc=s=>s==="PACKED!"?"#EE2222":s==="BUSY"?"#4444EE":s==="MODERATE"?"#3366CC":"#3388AA";
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr l="Get Peeps"/>
      <div style={{flex:1,background:"#dde8d0",position:"relative",overflow:"hidden"}}>
        <svg width="100%" height="100%" style={{position:"absolute",inset:0}}>
          <rect width="100%" height="100%" fill="#dde8d0"/>
          {[0,60,120,180,240,300].map(y=><line key={y} x1={0} y1={y} x2={300} y2={y} stroke="#c8d8b8" strokeWidth={0.5}/>)}
          {[0,60,120,180,240].map(x=><line key={x} x1={x} y1={0} x2={x} y2={400} stroke="#c8d8b8" strokeWidth={0.5}/>)}
          <rect x={20} y={120} width={60} height={30} rx={4} fill="#c0cca8" stroke="#a8b890" strokeWidth={1}/>
          <rect x={140} y={60} width={80} height={50} rx={4} fill="#c0cca8" stroke="#a8b890" strokeWidth={1}/>
          <path d="M0,200 Q100,185 252,215" stroke="#a0b8e0" strokeWidth={8} fill="none" opacity={0.65}/>
        </svg>
        {dots.map((d,i)=>(
          <div key={i} style={{position:"absolute",left:d.x,top:d.y,transform:"translate(-50%,-50%)"}}>
            <div style={{width:26,height:26,borderRadius:"50%",background:sc(d.s),border:"2px solid #fff",display:"flex",alignItems:"center",justifyContent:"center",boxShadow:"0 2px 8px rgba(0,0,0,0.4)"}}><span style={{color:"#fff",fontSize:9,fontWeight:900}}>●</span></div>
            <div style={{background:"rgba(0,0,0,0.75)",borderRadius:4,padding:"1px 4px",marginTop:2,whiteSpace:"nowrap"}}><span style={{color:"#fff",fontSize:7,fontWeight:700}}>{d.n}</span></div>
          </div>
        ))}
        <div style={{position:"absolute",bottom:12,right:8,background:"rgba(255,255,255,0.93)",borderRadius:8,padding:"6px 10px"}}>
          {[["PACKED!","#EE2222"],["BUSY","#4444EE"],["MODERATE","#3366CC"],["LIGHT","#3388AA"]].map(([s,c])=>(
            <div key={s} style={{display:"flex",alignItems:"center",gap:4,marginBottom:2}}>
              <div style={{width:8,height:8,borderRadius:"50%",background:c}}/><span style={{fontSize:7,fontWeight:700,color:"#333"}}>{s}</span>
            </div>
          ))}
        </div>
      </div>
      <VBB/>
    </div>
  );
}
// 28
function SharePeep(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <div style={{height:90,background:G.park,position:"relative",flexShrink:0}}>
        <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.4)"}}/>
        <div style={{position:"absolute",bottom:8,left:10}}>
          <div style={{color:"#fff",fontSize:13,fontWeight:900}}>Piedmont Park is PACKED!</div>
          <div style={{color:"rgba(255,255,255,0.85)",fontSize:9}}>Peepled by Rick Flair · 2m ago</div>
        </div>
      </div>
      <div style={{background:"#fff",borderRadius:"16px 16px 0 0",marginTop:-10,flex:1,overflow:"hidden"}}>
        <div style={{padding:"12px 16px 8px",borderBottom:"1px solid #eee",textAlign:"center"}}><span style={{color:"#111",fontSize:12,fontWeight:800}}>Share this Peep</span></div>
        <div style={{display:"flex",flexWrap:"wrap",padding:"10px",gap:10,justifyContent:"center"}}>
          {[["📱","Text"],["✉️","Email"],["📘","Facebook"],["📸","Instagram"],["👻","Snapchat"],["🐦","Twitter"],["🔗","Copy"]].map(([ic,lb])=>(
            <div key={lb} style={{display:"flex",flexDirection:"column",alignItems:"center",width:44}}>
              <div style={{width:38,height:38,borderRadius:"50%",background:"#f0f0f0",display:"flex",alignItems:"center",justifyContent:"center",fontSize:18,marginBottom:3}}>{ic}</div>
              <span style={{fontSize:8,color:"#555",fontWeight:600}}>{lb}</span>
            </div>
          ))}
        </div>
        <div style={{margin:"0 14px",background:"#f4f4f4",borderRadius:8,padding:"6px 10px",fontSize:10,color:"#555"}}>Piedmont Park is PACKED right now! 🔴 via @peepl</div>
      </div>
    </div>
  );
}
// 29
function InviteFriends(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="Invite Friends"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"12px"}}>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",marginBottom:10,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:700,marginBottom:6}}>Share your invite link</div>
          <div style={{background:"#f0f4ff",border:"1px solid #c0d0ff",borderRadius:8,padding:"7px 10px",fontSize:9,color:B,marginBottom:8}}>peepl.app/invite/rickflair</div>
          <div style={{background:B,borderRadius:8,padding:"8px",textAlign:"center"}}><span style={{color:"#fff",fontSize:11,fontWeight:700}}>Copy Link</span></div>
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"10px",boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:700,marginBottom:6}}>Invite from contacts</div>
          {[["👩","Doris Day","Not on Peepl"],["🐦","Toucan Sam","Not on Peepl"],["⚽","Messi","Already on Peepl"],["🐤","Big Bird","Not on Peepl"]].map(([ic,nm,st])=>(
            <div key={nm} style={{display:"flex",alignItems:"center",padding:"5px 0",borderBottom:"1px solid #f0f0f0",gap:8}}>
              <div style={{width:28,height:28,borderRadius:"50%",background:G.crd,display:"flex",alignItems:"center",justifyContent:"center",fontSize:14,flexShrink:0}}>{ic}</div>
              <div style={{flex:1}}><div style={{fontSize:10,fontWeight:700}}>{nm}</div><div style={{fontSize:8,color:"#aaa"}}>{st}</div></div>
              {st!=="Already on Peepl"&&<div style={{background:B,borderRadius:8,padding:"3px 8px"}}><span style={{color:"#fff",fontSize:8,fontWeight:700}}>Invite</span></div>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
// 30
function Notifs(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="Notifications"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{ic:"🔴",tx:"Piedmont Park just hit PACKED!",sb:"3 min ago",nw:true},{ic:"🏅",tx:"You're a Pioneer at Turner Field!",sb:"12 min ago",nw:true},{ic:"👤",tx:"Messi started following you",sb:"1 hr ago",nw:false},{ic:"💬",tx:"Rick James liked your Peep",sb:"2 hr ago",nw:false},{ic:"🔴",tx:"Establishment is BUSY",sb:"3 hr ago",nw:false},{ic:"🎟️",tx:"New deal: Monday Night Brewing",sb:"4 hr ago",nw:false}].map((n,i)=>(
          <div key={i} style={{display:"flex",alignItems:"flex-start",padding:"8px 12px",borderBottom:"1px solid #eee",gap:10,background:n.nw?"#f0f4ff":"#fff"}}>
            <div style={{fontSize:20,width:28,textAlign:"center",flexShrink:0}}>{n.ic}</div>
            <div style={{flex:1}}><div style={{fontSize:10,fontWeight:600,color:"#222"}}>{n.tx}</div><div style={{fontSize:8,color:"#aaa",marginTop:2}}>{n.sb}</div></div>
            {n.nw&&<div style={{width:8,height:8,borderRadius:"50%",background:B,flexShrink:0,marginTop:4}}/>}
          </div>
        ))}
      </div>
      <ANv a="feed"/>
    </div>
  );
}
// 31
function PushAlert(){
  return(
    <div style={{flex:1,background:G.park,position:"relative",display:"flex",flexDirection:"column"}}>
      <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.55)"}}/>
      <div style={{position:"relative",zIndex:1,flex:1,display:"flex",flexDirection:"column"}}>
        <Hdr/>
        <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 20px"}}>
          <div style={{background:"rgba(255,255,255,0.96)",borderRadius:16,padding:"20px",width:"100%"}}>
            <div style={{display:"flex",alignItems:"center",gap:10,marginBottom:10}}>
              <div style={{width:36,height:36,borderRadius:8,background:B,display:"flex",alignItems:"center",justifyContent:"center"}}><span style={{color:"#fff",fontSize:18,fontStyle:"italic",fontWeight:900}}>p</span></div>
              <div><div style={{fontSize:11,fontWeight:800}}>peepl</div><div style={{fontSize:8,color:"#aaa"}}>now</div></div>
            </div>
            <div style={{fontSize:12,fontWeight:800,marginBottom:4}}>🔴 Piedmont Park is PACKED!</div>
            <div style={{fontSize:10,color:"#555",lineHeight:1.5}}>3 people just reported crowd level 9 at your favorite spot. Heads up!</div>
            <div style={{display:"flex",gap:8,marginTop:12}}>
              <div style={{flex:1,background:"#f0f0f0",borderRadius:8,padding:"7px",textAlign:"center"}}><span style={{fontSize:10,fontWeight:700,color:"#555"}}>Dismiss</span></div>
              <div style={{flex:1,background:B,borderRadius:8,padding:"7px",textAlign:"center"}}><span style={{fontSize:10,fontWeight:700,color:"#fff"}}>View</span></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
// 32
function Report(){
  const [sel,setSel]=useState(null);
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel"/>
      <Strp t="Report This Peep"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"12px"}}>
        <div style={{color:"#555",fontSize:10,marginBottom:10,lineHeight:1.5}}>Why are you reporting this peep?</div>
        {["Inaccurate crowd size","Inappropriate content","Spam or fake peep","Wrong location","Offensive language","Other"].map((o,i)=>(
          <div key={i} onClick={()=>setSel(i)} style={{display:"flex",alignItems:"center",padding:"9px 12px",borderRadius:8,marginBottom:6,background:sel===i?B+"18":"#fff",border:"1px solid "+(sel===i?B:"#eee"),cursor:"pointer",gap:8}}>
            <div style={{width:16,height:16,borderRadius:"50%",border:"2px solid "+(sel===i?B:"#ccc"),display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
              {sel===i&&<div style={{width:8,height:8,borderRadius:"50%",background:B}}/>}
            </div>
            <span style={{fontSize:10,color:sel===i?B:"#333",fontWeight:sel===i?700:400}}>{o}</span>
          </div>
        ))}
        {sel!==null&&<div style={{background:"#e53935",borderRadius:8,padding:"10px",textAlign:"center"}}><span style={{color:"#fff",fontSize:12,fontWeight:700}}>Submit Report</span></div>}
      </div>
    </div>
  );
}
// 33
function Lboard(){
  const top3=[{r:2,n:"50 Cent",p:"11,456",ic:"🎤"},{r:1,n:"Rick Flair",p:"12,384",ic:"🤼"},{r:3,n:"LoisLane",p:"11,432",ic:"👩"}];
  const rest=[["4","Madonna","11,396"],["5","Lucy Lui","11,378"],["6","Hulk","11,325"],["7","Marky Mark","11,312"],["8","LutherV33","11,273"],["9","SuzeQ","11,269"],["10","TrixxxieSpanks","11,254"],["11","BobcatSlim","11,211"],["12","George","11,183"]];
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="← PEEPL Leaderboard"/>
      <div style={{background:"#e8eeff",padding:"5px 12px",display:"flex",justifyContent:"space-between",alignItems:"center",flexShrink:0,borderBottom:"1px solid #ccd"}}>
        <div style={{display:"flex",alignItems:"center",gap:8}}>
          <span style={{fontSize:10,fontWeight:700,color:"#555"}}>725</span>
          <div style={{width:28,height:28,borderRadius:4,background:G.cafe,display:"flex",alignItems:"center",justifyContent:"center",fontSize:14}}>🐻</div>
        </div>
        <div style={{textAlign:"center"}}><div style={{fontSize:9,color:"#555"}}>You (Huggy Bear)</div><div style={{fontSize:13,fontWeight:900,color:B}}>6,453</div></div>
        <div style={{display:"flex",gap:3}}>{["Friends","Everyone"].map((t,i)=><div key={t} style={{background:i===1?B:"#dde",borderRadius:3,padding:"2px 6px"}}><span style={{color:i===1?"#fff":"#555",fontSize:8,fontWeight:700}}>{t}</span></div>)}</div>
      </div>
      <div style={{display:"flex",justifyContent:"space-around",alignItems:"flex-end",padding:"8px 10px 4px",flexShrink:0}}>
        {top3.map((p,i)=>(
          <div key={i} style={{textAlign:"center",order:[1,0,2][i]}}>
            <div style={{fontSize:8,fontWeight:700,color:"#888"}}>#{p.r}</div>
            <div style={{width:[28,36,28][i],height:[28,36,28][i],borderRadius:4,background:G.cafe,margin:"2px auto",display:"flex",alignItems:"center",justifyContent:"center",fontSize:[14,18,14][i],border:i===1?"2px solid "+Y:"1px solid #ccc"}}>{p.ic}</div>
            <div style={{fontSize:8,fontWeight:800}}>{p.n}</div>
            <div style={{fontSize:9,fontWeight:900,color:B}}>{p.p}</div>
          </div>
        ))}
      </div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {rest.map(([r,n,p])=>(
          <div key={r} style={{display:"flex",padding:"3px 10px",borderBottom:"1px solid #eee",background:"#fff",alignItems:"center"}}>
            <span style={{fontSize:9,color:"#888",width:18}}>{r}</span>
            <span style={{fontSize:10,flex:1}}>{n}</span>
            <span style={{fontSize:10,color:B,fontWeight:700}}>{p}</span>
          </div>
        ))}
      </div>
      <VBB/>
    </div>
  );
}
// 34
function PioneersList(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="🏅 Pioneers"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{nm:"Piedmont Park",pi:"Rick Flair",dt:"3/12/15",cnt:42,ic:"🤼"},{nm:"Establishment",pi:"Big Blo",dt:"4/2/15",cnt:38,ic:"🦜"},{nm:"Monday Night Brewing",pi:"Messi",dt:"5/15/15",cnt:29,ic:"⚽"},{nm:"Tongue-n-Groove",pi:"LoisLane",dt:"6/1/15",cnt:24,ic:"👩"},{nm:"Osteria 832",pi:"Tootsie",dt:"6/8/15",cnt:18,ic:"🎭"},{nm:"Joey D's Oak Room",pi:"50 Cent",dt:"7/4/15",cnt:15,ic:"🎤"}].map((v,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"7px 10px",borderBottom:"1px solid #eee",background:"#fff",gap:8}}>
            <div style={{width:30,height:30,borderRadius:"50%",background:G.b2,display:"flex",alignItems:"center",justifyContent:"center",fontSize:16,flexShrink:0}}>{v.ic}</div>
            <div style={{flex:1}}><div style={{fontSize:10,fontWeight:800}}>{v.nm}</div><div style={{fontSize:8,color:"#888"}}>First: {v.pi} · {v.dt}</div></div>
            <div style={{textAlign:"right"}}><div style={{fontSize:9,fontWeight:700,color:B}}>{v.cnt}</div><div style={{fontSize:7,color:"#aaa"}}>peeps</div></div>
          </div>
        ))}
      </div>
      <VBB/>
    </div>
  );
}
// 35
function VIPeeps(){
  return(
    <div style={{flex:1,background:G.ngt,display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"0 16px 16px",display:"flex",flexDirection:"column",alignItems:"center"}}>
        <div style={{textAlign:"center",padding:"20px 0 10px"}}>
          <div style={{fontSize:40}}>⭐</div>
          <div style={{color:Y,fontSize:18,fontWeight:900,marginTop:8}}>VIPeeps</div>
          <div style={{color:"rgba(255,255,255,0.7)",fontSize:10,marginTop:4}}>Upgrade for the full experience</div>
        </div>
        {[["📊","Crowd History","24-hr trend graphs per venue"],["🔔","Priority Alerts","First to know when spots hit 8+"],["📍","Unlimited Saves","Save unlimited favorite venues"],["🎯","Deal Priority","Early access to merchant deals"],["🏆","VIP Badge","Stand out on the leaderboard"]].map(([ic,f,d])=>(
          <div key={f} style={{background:"rgba(255,255,255,0.12)",borderRadius:10,padding:"10px 14px",marginBottom:6,width:"100%"}}>
            <div style={{color:"#fff",fontSize:11,fontWeight:700}}>{ic} {f}</div>
            <div style={{color:"rgba(255,255,255,0.65)",fontSize:9,marginTop:2}}>{d}</div>
          </div>
        ))}
        <div style={{background:Y,borderRadius:24,padding:"12px 0",marginTop:12,width:"100%",textAlign:"center"}}><span style={{color:"#111",fontSize:13,fontWeight:900}}>Subscribe — $4.99 / month</span></div>
        <div style={{color:"rgba(255,255,255,0.45)",fontSize:9,marginTop:8}}>Cancel anytime.</div>
      </div>
    </div>
  );
}
// 36
function VIPeepsActive(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="Profile"/>
      <PBan/>
      <div style={{background:"linear-gradient(135deg,#281848,#4a3080)",padding:"8px 12px",margin:"4px 8px",borderRadius:8,display:"flex",alignItems:"center",gap:8,flexShrink:0}}>
        <span style={{fontSize:18}}>⭐</span>
        <div><div style={{color:Y,fontSize:11,fontWeight:900}}>VIPeeps Active</div><div style={{color:"rgba(255,255,255,0.7)",fontSize:8}}>Renews 12/1/2025 · Manage</div></div>
      </div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[["Peeps",78],["Favorites","Unlimited"],["Points/Leaderboard",675],["Likes",68],["Peeps You've Liked",56],["Pioneers",13],["Groups",6],["Followers",73],["Following",34]].map(([l,v])=><Rw key={l} label={l} val={v}/>)}
      </div>
      <VBB/>
    </div>
  );
}
// 37
function ProfileStats(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="Profile"/>
      <PBan/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[["Peeps",78],["Favorites",34],["Your Points/Leaderboard",675],["Likes",68],["Peeps You've Liked",56],["Places You've Pioneered",13],["Groups",6],["Followers",73],["Following",34],["Account Info, Settings & Log In",undefined]].map(([l,v])=><Rw key={l} label={l} val={v}/>)}
      </div>
      <VBB/>
    </div>
  );
}
// 38
function OtherProfile(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back"/>
      <Strp t="Profile"/>
      <PBan nm="LordByron" sb="+Follow"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[["Peeps",124],["Pioneers",8],["Likes",203],["Followers",312],["Following",89]].map(([l,v])=><Rw key={l} label={l} val={v}/>)}
        <SHdr t="Recent Peeps"/>
        <Crd venue="Atlanta Airport" user="LordByron" date="Recent" dist="" status="PACKED!" bg={G.apt}/>
        <Crd venue="Monday Night Brewing" user="LordByron" date="Recent" dist="" status="BUSY" bg={G.brew}/>
      </div>
      <VBB/>
    </div>
  );
}
// 39
function MyHistory(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="My History — Peeps Place"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{venue:"Righteous Room",status:"PACKED!",bg:G.b1},{venue:"Loca Luna",status:"BUSY",bg:G.b2},{venue:"Noche",status:"MODERATE",bg:G.b3},{venue:"Park Tavern",status:"BUSY",bg:G.brew},{venue:"Waffle House",status:"LIGHT",bg:G.tav},{venue:"Smash",status:"MODERATE",bg:G.ost}].map((p,i)=><Crd key={i} {...p} user="Rick Flair" date="Recent" dist=""/>)}
      </div>
      <HNav/>
    </div>
  );
}
// 40 — Peeps Received
function PeepsReceived(){
  const posts=[
    {venue:"Establishment",caption:"Good looking crowd!",user:"Big Blo",crowd:"PACKED!",bg:G.b2,mf:"40/60"},
    {venue:"Tongue-n-Groove",caption:"Goomba City!",user:"Tootsie",crowd:"BUSY",bg:G.b3,mf:"50/50"},
    {venue:"Piedmont Park",caption:"Easy going peeps!",user:"Messi",crowd:"MODERATE",bg:G.park,mf:"30/10"},
  ];
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="My History — Peeps Received"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {posts.map((p,i)=>(
          <div key={i} style={{height:64,background:p.bg,position:"relative",marginBottom:3}}>
            <div style={{position:"absolute",inset:0,background:"linear-gradient(to bottom,rgba(0,0,0,0.1),rgba(0,0,0,0.55))"}}/>
            <div style={{position:"absolute",top:4,left:8,color:"rgba(255,255,255,0.9)",fontSize:7,fontWeight:700}}>M/F: {p.mf}</div>
            <div style={{position:"absolute",top:10,left:4}}><DR st={p.crowd} sz={28}/></div>
            <div style={{position:"absolute",bottom:5,left:40}}>
              <div style={{color:"#fff",fontSize:9,fontWeight:800,textShadow:"0 1px 3px rgba(0,0,0,1)"}}>{p.caption}</div>
              <div style={{color:"rgba(255,255,255,0.8)",fontSize:8,fontWeight:700}}>{p.venue}</div>
            </div>
            <div style={{position:"absolute",bottom:5,right:8,color:"#ddd",fontSize:8,fontWeight:700}}>{p.user}</div>
          </div>
        ))}
      </div>
      <HNav/>
    </div>
  );
}
// 41
function Followers(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="Followers"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{nm:"Doris Day",st:"Following",ic:"👩"},{nm:"Big Blo",st:"",ic:"🦜"},{nm:"Toucan Sam",st:"Following",ic:"🐦"},{nm:"Messi",st:"Following",ic:"⚽"},{nm:"Big Bird",st:"",ic:"🐤"}].map((p,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"6px 10px",borderBottom:"1px solid #eee",gap:10,background:"#fff"}}>
            <div style={{width:34,height:34,borderRadius:4,background:G.crd,display:"flex",alignItems:"center",justifyContent:"center",fontSize:18,flexShrink:0}}>{p.ic}</div>
            <span style={{fontSize:11,fontWeight:700,flex:1}}>{p.nm}</span>
            {p.st&&<span style={{fontSize:9,color:B,fontWeight:700}}>{p.st}</span>}
          </div>
        ))}
      </div>
      <HNav/>
    </div>
  );
}
// 42
function Following(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="Following"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{nm:"Doris Day",ic:"👩"},{nm:"Toucan Sam",ic:"🐦"},{nm:"Messi",ic:"⚽"}].map((p,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"6px 10px",borderBottom:"1px solid #eee",gap:10,background:"#fff"}}>
            <div style={{width:34,height:34,borderRadius:4,background:G.b2,display:"flex",alignItems:"center",justifyContent:"center",fontSize:18,flexShrink:0}}>{p.ic}</div>
            <span style={{fontSize:11,fontWeight:700,flex:1}}>{p.nm}</span>
            <span style={{fontSize:9,color:"#888"}}>Follows You</span>
          </div>
        ))}
      </div>
      <HNav/>
    </div>
  );
}
// 43
function Favorites(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="Favorites"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{nm:"Establishment",bg:G.b1},{nm:"Piedmont Park",bg:G.park},{nm:"Noche",bg:G.b2},{nm:"Ecco",bg:G.ost},{nm:"Apres Diem",bg:G.tav},{nm:"Chastain Park",bg:G.out},{nm:"The DMV",bg:G.apt},{nm:"Turner Field",bg:G.b3}].map((p,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"5px 10px",borderBottom:"1px solid #eee",gap:8,background:"#fff"}}>
            <div style={{width:28,height:22,borderRadius:2,background:p.bg,flexShrink:0}}/>
            <span style={{fontSize:10,fontWeight:600}}>{p.nm}</span>
          </div>
        ))}
      </div>
      <HNav/>
    </div>
  );
}
// 44 — Scoreboard
function Scoreboard(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="Scoreboard"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:10,padding:"12px",marginBottom:10,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:800,marginBottom:8,color:"#222"}}>Your Stats</div>
          {[["Total Peeps","78"],["Pioneers","13"],["Points","6,453"],["Rank","#725"],["Likes Given","56"],["Likes Received","203"]].map(([l,v])=>(
            <div key={l} style={{display:"flex",justifyContent:"space-between",padding:"3px 0",borderBottom:"1px solid #f5f5f5"}}>
              <span style={{fontSize:9,color:"#555"}}>{l}</span>
              <span style={{fontSize:9,color:B,fontWeight:800}}>{v}</span>
            </div>
          ))}
        </div>
        <div style={{background:"#fff",borderRadius:10,padding:"12px",boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:800,marginBottom:8}}>Friends Leaderboard</div>
          {[["🤼","Rick Flair","12,384","#1"],["🎤","50 Cent","11,456","#2"],["👩","LoisLane","11,432","#3"],["⚽","Messi","9,821","#4"],["🐻","You","6,453","#5"]].map(([ic,nm,pts,rk])=>(
            <div key={nm} style={{display:"flex",alignItems:"center",padding:"4px 0",borderBottom:"1px solid #f5f5f5",gap:8}}>
              <span style={{fontSize:8,color:"#888",width:18}}>{rk}</span>
              <span style={{fontSize:14}}>{ic}</span>
              <span style={{fontSize:10,flex:1,fontWeight:nm==="You"?700:400,color:nm==="You"?B:"#333"}}>{nm}</span>
              <span style={{fontSize:9,color:B,fontWeight:700}}>{pts}</span>
            </div>
          ))}
        </div>
      </div>
      <HNav/>
    </div>
  );
}
// 45 — Photo Gallery
function PhotoGallery(){
  const grads=["linear-gradient(135deg,#8a3030,#c05050)","linear-gradient(135deg,#304080,#5060c0)","linear-gradient(135deg,#306030,#50a050)","linear-gradient(135deg,#805030,#c08050)","linear-gradient(135deg,#603080,#9050c0)","linear-gradient(135deg,#308060,#50c090)","linear-gradient(135deg,#804040,#c07060)","linear-gradient(135deg,#408040,#60c060)","linear-gradient(135deg,#204060,#4060a0)","linear-gradient(135deg,#602020,#a04040)","linear-gradient(135deg,#206040,#40a060)","linear-gradient(135deg,#606020,#a0a040)","linear-gradient(135deg,#402060,#8040a0)","linear-gradient(135deg,#204040,#408080)","linear-gradient(135deg,#602040,#a04080)","linear-gradient(135deg,#406020,#80a040)","linear-gradient(135deg,#203060,#4050a0)","linear-gradient(135deg,#502020,#904040)","linear-gradient(135deg,#205040,#4090a0)","linear-gradient(135deg,#504020,#908040)"];
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Tick/>
      <PBan/>
      <SHdr t="Personal Photo Gallery"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:4}}>
        <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:3}}>
          {grads.map((g,i)=><div key={i} style={{height:40,borderRadius:2,background:g}}/>)}
        </div>
      </div>
      <HNav/>
    </div>
  );
}
// 46
function Groups(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="Your Groups"/>
      <PBan/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{nm:"Rowdy's",bg:G.b1},{nm:"Brookhaven Social Club",bg:G.park},{nm:"Atlanta Masters",bg:G.b2},{nm:"V-Players of Georgia",bg:G.out},{nm:"Greek Lovers",bg:G.brew}].map((g,i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"5px 10px",borderBottom:"1px solid #eee",background:"#fff",gap:8}}>
            <div style={{width:28,height:22,borderRadius:2,background:g.bg,flexShrink:0}}/>
            <span style={{fontSize:10,fontWeight:600}}>{g.nm}</span>
          </div>
        ))}
        {[...Array(3)].map((_,i)=><div key={i} style={{height:32,borderBottom:"1px solid #eee",background:"#fff"}}/>)}
        <div style={{padding:"10px",textAlign:"center"}}><div style={{background:B,borderRadius:8,padding:"8px",display:"inline-block"}}><span style={{color:"#fff",fontSize:11,fontWeight:700}}>+ Create / Join Group</span></div></div>
      </div>
      <VBB/>
    </div>
  );
}
// 47 — Menu Nav
function MenuNav(){
  const items=[["🏠","Home / Feed"],["🔍","Search Places"],["📍","Get Peeps Near Me"],["💰","Deals"],["🗺️","Map View"],["👤","My Profile"],["📸","My Photos"],["⭐","Favorites"],["🏆","Leaderboard"],["🏅","Pioneers"],["👥","Groups"],["💬","Invite Friends"],["⭐","VIPeeps"],["⚙️","Settings"],["🚪","Sign Out"]];
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="✕ Close"/>
      <PBan/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {items.map(([ic,lb],i)=>(
          <div key={i} style={{display:"flex",alignItems:"center",padding:"8px 14px",borderBottom:"1px solid #eee",gap:12,background:"#fff"}}>
            <span style={{fontSize:16,width:22,textAlign:"center"}}>{ic}</span>
            <span style={{fontSize:11,color:"#222",fontWeight:500}}>{lb}</span>
            <span style={{color:"#ddd",fontSize:14,marginLeft:"auto"}}>›</span>
          </div>
        ))}
      </div>
    </div>
  );
}
// 48
function Settings(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back"/>
      <Strp t="Settings"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[{sec:"Appearance",items:[{ic:"☀️",l:"Dark Mode",sub:"Switch between light and dark"}]},{sec:"Notifications",items:[{ic:"🔔",l:"Push Notifications",sub:"Crowd alerts and friend activity"},{ic:"📍",l:"Location Alerts",sub:"When favorites get busy"}]},{sec:"Privacy",items:[{ic:"👁️",l:"Profile Visibility",sub:"Who can see your profile"},{ic:"📍",l:"Location Sharing",sub:"Control your location data"}]},{sec:"Account",items:[{ic:"👤",l:"Edit Profile",sub:""},{ic:"🚪",l:"Log Out",sub:"",red:true}]}].map(g=>(
          <div key={g.sec}>
            <div style={{padding:"8px 12px 4px",fontSize:10,fontWeight:800,color:B}}>{g.sec}</div>
            {g.items.map(item=>(
              <div key={item.l} style={{display:"flex",alignItems:"center",padding:"8px 12px",borderBottom:"1px solid #eee",gap:10,background:"#fff"}}>
                <span style={{fontSize:16}}>{item.ic}</span>
                <div style={{flex:1}}><div style={{fontSize:11,fontWeight:600,color:item.red?"#e53935":"#222"}}>{item.l}</div>{item.sub&&<div style={{fontSize:8,color:"#aaa"}}>{item.sub}</div>}</div>
                {!item.red&&<span style={{color:"#ccc",fontSize:14}}>›</span>}
              </div>
            ))}
          </div>
        ))}
        <div style={{textAlign:"center",padding:"16px",color:"#bbb",fontSize:9}}>Peepl v2.1.0</div>
      </div>
    </div>
  );
}
// 49
function AccountInfo(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back"/>
      <Strp t="Account Info"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none"}}>
        {[["Name","Rick Flair"],["Username","rickflair"],["Email","Rflair@gmail.com"],["Phone","(404) 555-0191"],["Password","••••••••"],["Member Since","March 2015"]].map(([l,v])=>(
          <div key={l} style={{display:"flex",padding:"8px 12px",borderBottom:"1px solid #eee",alignItems:"center",background:"#fff"}}>
            <span style={{fontSize:9,color:"#555",width:80,fontWeight:600}}>{l}</span>
            <span style={{fontSize:9,color:"#333",flex:1}}>{v}</span>
            <span style={{fontSize:9,color:B,fontWeight:700}}>(edit)</span>
          </div>
        ))}
        <SHdr t="Account"/>
        {[["Peepl Rating","4.8 ⭐"],["Pioneer Status","13 venues"],["VIPeeps","Active ⭐"],["Linked Accounts","Facebook, Google"]].map(([l,v])=><Rw key={l} label={l} val={v}/>)}
      </div>
    </div>
  );
}
// 50 — How to Advertise
function HowToAd(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back" r=""/>
      <Strp t="How to Advertise on Peepl"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"12px"}}>
        <div style={{background:G.mrc,borderRadius:10,padding:"14px",marginBottom:10,textAlign:"center"}}>
          <div style={{color:"#fff",fontSize:14,fontWeight:900}}>Reach real people</div>
          <div style={{color:"rgba(255,255,255,0.8)",fontSize:10,marginTop:4}}>at the moment they're deciding where to go</div>
        </div>
        {[["📍","Hyper-local targeting","Your ad appears in feeds near your venue — reaching people already in your neighborhood."],["🕐","Time-slot buying","Pick the exact hours your deal runs. Friday happy hour? Saturday night? You control it."],["📊","Real-time analytics","See impressions, clicks, and CTR as they happen. Pause or adjust anytime."],["💰","Starting at $9.99/hr","Three tiers: Basic, Standard, and Premium placement. No minimum spend."]].map(([ic,ti,bo])=>(
          <div key={ti} style={{background:"#fff",borderRadius:10,padding:"12px",marginBottom:8,display:"flex",gap:10,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
            <span style={{fontSize:22,flexShrink:0}}>{ic}</span>
            <div><div style={{fontSize:11,fontWeight:800,marginBottom:3}}>{ti}</div><div style={{fontSize:9,color:"#555",lineHeight:1.5}}>{bo}</div></div>
          </div>
        ))}
        <div style={{background:B,borderRadius:10,padding:"12px",textAlign:"center",marginTop:4}}><span style={{color:"#fff",fontSize:13,fontWeight:700}}>Create Your First Ad →</span></div>
      </div>
    </div>
  );
}
// 51
function MSignIn(){
  return(
    <div style={{flex:1,background:G.mrc,position:"relative",display:"flex",flexDirection:"column"}}>
      <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.5)"}}/>
      <div style={{position:"relative",zIndex:1,display:"flex",flexDirection:"column",alignItems:"center",padding:"36px 24px 0",flex:1}}>
        <div style={{fontSize:46,fontWeight:900,fontStyle:"italic",color:"#fff",letterSpacing:-2,marginBottom:6}}>peepl</div>
        <div style={{color:Y,fontSize:11,fontWeight:700,marginBottom:40}}>FOR MERCHANTS</div>
        {[["Business Email","owner@mybusiness.com"],["Password","••••••••"]].map(([l,ph],ti)=>(
          <div key={l} style={{width:"100%",marginBottom:14}}>
            <div style={{color:"#eee",fontSize:11,fontWeight:700,marginBottom:3}}>{l}</div>
            <div style={{background:"rgba(255,255,255,0.9)",borderRadius:8,padding:"9px 12px",fontSize:11,color:ti===1?"#bbb":"#555"}}>{ph}</div>
          </div>
        ))}
        <div style={{background:Y,borderRadius:8,padding:"12px",textAlign:"center",width:"100%",marginBottom:10}}><span style={{color:"#111",fontSize:13,fontWeight:800}}>Sign In</span></div>
        <span style={{color:"rgba(255,255,255,0.7)",fontSize:10}}>New merchant? <span style={{color:Y,fontWeight:700}}>Create account</span></span>
      </div>
    </div>
  );
}
// 52–54 — Merchant steps
function MStep({step}){
  const bodies=[
    <div>
      <div style={{fontSize:10,fontWeight:700,marginBottom:4,color:"#333"}}>Your offer or message</div>
      <div style={{background:"#f4f4f4",borderRadius:8,padding:"8px",fontSize:10,color:"#555",height:60,border:"1px solid #ddd"}}>Free appetizer with any entree tonight!</div>
      <div style={{textAlign:"right",fontSize:8,color:"#aaa",marginTop:2}}>47/120</div>
      <div style={{marginTop:10,fontSize:10,fontWeight:700,color:"#333"}}>Venue Name</div>
      <div style={{background:"#f4f4f4",borderRadius:8,padding:"8px",fontSize:10,color:"#555",border:"1px solid #ddd",marginTop:3}}>Osteria 832</div>
    </div>,
    <div>
      {[["Basic","$9.99/hr","2hr min",false],["Standard","$19.99/hr","Boosted reach",true],["Premium","$39.99/hr","Top placement",false]].map(([t,p,d,sel])=>(
        <div key={t} style={{border:"2px solid "+(sel?B:"#eee"),borderRadius:8,padding:"8px",marginBottom:6,background:sel?B+"10":"#fff",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div><div style={{fontSize:10,fontWeight:700,color:sel?B:"#333"}}>{t}</div><div style={{fontSize:8,color:"#888"}}>{d}</div></div>
          <div style={{color:B,fontSize:11,fontWeight:900}}>{p}</div>
        </div>
      ))}
      <div style={{marginTop:8,fontSize:10,fontWeight:700,color:"#333"}}>Run Time</div>
      <div style={{display:"flex",gap:6,marginTop:4}}>{["Tonight 8–10PM","Tomorrow 7–9PM","Custom"].map(t=><div key={t} style={{flex:1,background:"#f0f0f0",borderRadius:6,padding:"5px 2px",textAlign:"center"}}><span style={{fontSize:8,fontWeight:600}}>{t}</span></div>)}</div>
    </div>,
    <div>
      <div style={{background:"#f8f8f8",borderRadius:8,padding:"10px",marginBottom:8}}>
        <div style={{fontSize:10,fontWeight:800,marginBottom:6}}>Order Summary</div>
        {[["Venue","Osteria 832"],["Ad type","Standard"],["Time slot","Tonight 8–10PM"],["Duration","2 hours"],["Total cost","$39.98"]].map(([l,v])=>(
          <div key={l} style={{display:"flex",justifyContent:"space-between",marginBottom:3}}>
            <span style={{fontSize:9,color:"#555"}}>{l}</span>
            <span style={{fontSize:9,fontWeight:700,color:l==="Total cost"?B:"#333"}}>{v}</span>
          </div>
        ))}
      </div>
      <div style={{background:B,borderRadius:8,padding:"10px",textAlign:"center"}}><span style={{color:"#fff",fontSize:12,fontWeight:700}}>Confirm and Pay</span></div>
    </div>,
  ];
  const titles=["Write Your Ad","Choose Time Slot","Review & Submit"];
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Peep!" r=""/>
      <div style={{background:B,padding:"5px 12px",display:"flex",alignItems:"center",gap:8,flexShrink:0}}>
        {[1,2,3].map(n=>(
          <div key={n} style={{display:"flex",alignItems:"center",gap:4}}>
            <div style={{width:18,height:18,borderRadius:"50%",background:n<=step?"#fff":"rgba(255,255,255,0.3)",display:"flex",alignItems:"center",justifyContent:"center"}}>
              <span style={{fontSize:8,fontWeight:900,color:n<=step?B:"rgba(255,255,255,0.6)"}}>{n}</span>
            </div>
            {n<3&&<div style={{width:20,height:1,background:n<step?"#fff":"rgba(255,255,255,0.3)"}}/>}
          </div>
        ))}
        <span style={{color:"#fff",fontSize:10,fontWeight:700,marginLeft:4}}>{titles[step-1]}</span>
      </div>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"12px"}}>{bodies[step-1]}</div>
    </div>
  );
}
// 55
function MDash(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Peep!" r=""/>
      <Strp t="Merchant Dashboard"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{display:"flex",gap:8,marginBottom:10}}>
          {[["Impressions","2,841"],["Clicks","234"],["CTR","8.2%"]].map(([l,v])=>(
            <div key={l} style={{flex:1,background:"#fff",borderRadius:8,padding:"8px",textAlign:"center",boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
              <div style={{fontSize:14,fontWeight:900,color:B}}>{v}</div>
              <div style={{fontSize:8,color:"#888"}}>{l}</div>
            </div>
          ))}
        </div>
        <SHdr t="Active Ads"/>
        {[{nm:"Osteria 832",offer:"Free apps",ends:"1h 22m",bg:G.ost},{nm:"Monday Night Brewing",offer:"$2 off pints",ends:"3h 10m",bg:G.brew}].map((a,i)=>(
          <div key={i} style={{marginBottom:6}}>
            <div style={{height:50,background:a.bg,position:"relative",borderRadius:"6px 6px 0 0"}}>
              <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.45)",borderRadius:"6px 6px 0 0"}}/>
              <div style={{position:"absolute",bottom:4,left:8}}><div style={{color:"#fff",fontSize:10,fontWeight:800}}>{a.nm}</div><div style={{color:Y,fontSize:8}}>{a.offer}</div></div>
              <div style={{position:"absolute",top:4,right:6,background:"#e53935",borderRadius:8,padding:"1px 6px"}}><span style={{color:"#fff",fontSize:7,fontWeight:700}}>LIVE</span></div>
            </div>
            <div style={{background:"#fff",padding:"4px 8px",borderRadius:"0 0 6px 6px",display:"flex",justifyContent:"space-between"}}><span style={{fontSize:8,color:"#888"}}>Ends in {a.ends}</span><span style={{fontSize:8,color:B,fontWeight:700}}>Edit</span></div>
          </div>
        ))}
        <SHdr t="Scheduled"/>
        <div style={{background:"#fff",borderRadius:8,padding:"10px",textAlign:"center",color:"#aaa",fontSize:10,marginTop:2}}>No scheduled ads. <span style={{color:B,fontWeight:700}}>Create one →</span></div>
      </div>
    </div>
  );
}
// 56
function MActivity(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back" r=""/>
      <Strp t="Ad Performance"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:8,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:800,marginBottom:6}}>Osteria 832 · Last 7 days</div>
          <div style={{display:"flex",gap:6}}>
            {[["Impressions","2,841"],["Clicks","234"],["CTR","8.2%"],["Cost","$79.96"]].map(([l,v])=>(
              <div key={l} style={{flex:1,textAlign:"center"}}><div style={{fontSize:12,fontWeight:900,color:B}}>{v}</div><div style={{fontSize:7,color:"#888"}}>{l}</div></div>
            ))}
          </div>
        </div>
        <div style={{background:"#fff",borderRadius:8,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:800,marginBottom:6}}>By Time Slot</div>
          {[["Fri 8–10PM","840","68","8.1%"],["Sat 7–9PM","1,120","98","8.7%"],["Sun 6–8PM","881","68","7.7%"]].map(([t,im,cl,r])=>(
            <div key={t} style={{display:"flex",padding:"4px 0",borderBottom:"1px solid #f0f0f0",alignItems:"center"}}>
              <span style={{fontSize:9,fontWeight:700,width:80,color:"#555"}}>{t}</span>
              <span style={{fontSize:8,color:"#888",flex:1}}>{im} impr</span>
              <span style={{fontSize:8,color:"#888",flex:1}}>{cl} clicks</span>
              <span style={{fontSize:9,color:B,fontWeight:700}}>{r}</span>
            </div>
          ))}
        </div>
        <div style={{background:B,borderRadius:8,padding:"10px",textAlign:"center"}}><span style={{color:"#fff",fontSize:11,fontWeight:700}}>Create New Ad →</span></div>
      </div>
    </div>
  );
}
// 57
function MAccount(){
  return(
    <div style={{flex:1,background:"#f8f8f8",display:"flex",flexDirection:"column"}}>
      <Hdr l="Back" r=""/>
      <Strp t="Merchant Account"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:8,padding:"10px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:10,fontWeight:800,marginBottom:6}}>Business Info</div>
          {[["Business","Osteria 832"],["Contact","John Smith"],["Email","john@osteria832.com"],["Phone","(404) 555-0192"],["Account #","MRC-00291-A"]].map(([l,v])=>(
            <div key={l} style={{display:"flex",padding:"4px 0",borderBottom:"1px solid #f5f5f5"}}>
              <span style={{fontSize:9,color:"#888",width:72}}>{l}</span>
              <span style={{fontSize:9,color:"#333",flex:1,fontWeight:600}}>{v}</span>
            </div>
          ))}
        </div>
        <SHdr t="Billing"/>
        {[["Payment Method","Visa ···4242"],["Billing Cycle","Monthly"],["Next Charge","Dec 1, 2025"],["Total Spent","$239.88"]].map(([l,v])=><Rw key={l} label={l} val={v}/>)}
        <div style={{padding:"10px",background:"#fff",marginTop:2,textAlign:"center"}}><div style={{border:"1px solid "+B,borderRadius:8,padding:"8px",display:"inline-block"}}><span style={{color:B,fontSize:11,fontWeight:700}}>Update Payment Method</span></div></div>
      </div>
    </div>
  );
}
// 58 — Merchant Account Number
function MAccountNum(){
  return(
    <div style={{flex:1,background:G.mrc,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px",position:"relative"}}>
      <div style={{position:"absolute",inset:0,background:"rgba(0,0,0,0.4)"}}/>
      <div style={{position:"relative",zIndex:1,width:"100%",textAlign:"center"}}>
        <div style={{fontSize:48,marginBottom:12}}>🏢</div>
        <div style={{color:"#fff",fontSize:16,fontWeight:900}}>Account Created!</div>
        <div style={{color:"rgba(255,255,255,0.8)",fontSize:11,marginTop:8,lineHeight:1.5}}>Welcome to Peepl for Merchants. Your account number is:</div>
        <div style={{background:"rgba(255,255,255,0.15)",borderRadius:12,padding:"16px",marginTop:16,border:"2px solid rgba(255,255,255,0.3)"}}>
          <div style={{color:"rgba(255,255,255,0.7)",fontSize:9,marginBottom:6}}>MERCHANT ACCOUNT NUMBER</div>
          <div style={{color:Y,fontSize:24,fontWeight:900,letterSpacing:3}}>MRC-00291-A</div>
        </div>
        <div style={{color:"rgba(255,255,255,0.6)",fontSize:9,marginTop:12}}>Keep this number for your records</div>
        <div style={{background:Y,borderRadius:24,padding:"12px 36px",marginTop:20,display:"inline-block"}}><span style={{color:"#111",fontSize:13,fontWeight:900}}>Go to Dashboard →</span></div>
      </div>
    </div>
  );
}
// 59 — Age Range Selector
function AgeRangeSelector(){
  const [sel,setSel]=useState("25-35");
  return(
    <div style={{flex:1,background:"#f5f5f5",display:"flex",flexDirection:"column"}}>
      <Hdr l="Cancel" r="Peep!"/>
      <div style={{flex:1,overflowY:"auto",scrollbarWidth:"none",padding:"10px"}}>
        <div style={{background:"#fff",borderRadius:10,padding:"14px",marginBottom:8,boxShadow:"0 1px 4px rgba(0,0,0,0.06)"}}>
          <div style={{fontSize:11,fontWeight:800,marginBottom:12,color:"#222"}}>Crowd Age Range</div>
          <div style={{fontSize:10,color:"#555",marginBottom:10}}>Select all that apply</div>
          {[["18-24","Mostly younger crowd"],["25-35","Late 20s to mid-30s"],["35-50","Mature crowd"],["50+","Older crowd"],["Mixed","All ages"]].map(([rng,desc])=>(
            <div key={rng} onClick={()=>setSel(rng)} style={{display:"flex",alignItems:"center",padding:"10px 12px",borderRadius:8,marginBottom:6,background:sel===rng?B+"10":"#f8f8f8",border:"1px solid "+(sel===rng?B:"#eee"),cursor:"pointer",gap:10}}>
              <div style={{width:18,height:18,borderRadius:"50%",border:"2px solid "+(sel===rng?B:"#ccc"),display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}>
                {sel===rng&&<div style={{width:10,height:10,borderRadius:"50%",background:B}}/>}
              </div>
              <div>
                <div style={{fontSize:11,fontWeight:700,color:sel===rng?B:"#333"}}>{rng}</div>
                <div style={{fontSize:9,color:"#888"}}>{desc}</div>
              </div>
            </div>
          ))}
        </div>
        <div style={{background:"#FFC107",borderRadius:10,padding:"12px",textAlign:"center",fontWeight:700,fontSize:13,cursor:"pointer"}}>Continue →</div>
      </div>
    </div>
  );
}
// 60 — No Connection empty state (different flavor)
function EmptyState(){
  return(
    <div style={{flex:1,background:"#f0f0f0",display:"flex",flexDirection:"column"}}>
      <Hdr/>
      <Strp t="What's happening"/>
      <div style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:"0 24px"}}>
        <div style={{fontSize:56,marginBottom:16}}>📭</div>
        <div style={{color:"#222",fontSize:15,fontWeight:900,textAlign:"center"}}>No Peeps Today</div>
        <div style={{color:"#888",fontSize:11,textAlign:"center",marginTop:8,lineHeight:1.6}}>What's it like where you are? Be the first to Peep your area today.</div>
        <div style={{marginTop:24,display:"flex",gap:10}}>
          <Btn label="Peep Now 📍"/>
        </div>
      </div>
      <ANv a="feed"/>
    </div>
  );
}

// ── Wrapper components for parameterised screens ──────────
const OB1=()=><OB step={1}/>;
const OB2=()=><OB step={2}/>;
const OB3=()=><OB step={3}/>;
const MStep1=()=><MStep step={1}/>;
const MStep2=()=><MStep step={2}/>;
const MStep3=()=><MStep step={3}/>;

// ── Master catalogue ──────────────────────────────────────
const CAT=[
  {sec:"Onboarding",screens:[
    {id:"splash",lb:"1. Splash",Comp:Splash},
    {id:"ob1",lb:"2. Onboard 1 — Know",Comp:OB1},
    {id:"ob2",lb:"3. Onboard 2 — Real Time",Comp:OB2},
    {id:"ob3",lb:"4. Onboard 3 — Pioneer",Comp:OB3},
    {id:"signin",lb:"5. Sign In",Comp:SignIn},
    {id:"signup",lb:"6. Sign Up",Comp:SignUp},
    {id:"confirmed",lb:"7. Sign Up Confirmed",Comp:Confirmed},
    {id:"locperm",lb:"8. Location Permission",Comp:LocPerm},
    {id:"pushperm",lb:"9. Push Permission",Comp:PushPerm},
  ]},
  {sec:"Feed & Discovery",screens:[
    {id:"mainfeed",lb:"10. Main Feed",Comp:MainFeed},
    {id:"search",lb:"11. Search",Comp:SearchScr},
    {id:"searchresults",lb:"12. Search Results",Comp:SearchResults},
    {id:"trending",lb:"13. Trending",Comp:Trending},
    {id:"emptystate",lb:"14. No Peeps Today",Comp:EmptyState},
    {id:"noconn",lb:"15. No Connection",Comp:NoConn},
  ]},
  {sec:"Venue & Peeps",screens:[
    {id:"venue",lb:"16. Venue Page",Comp:VenuePg},
    {id:"venuewithed",lb:"17. Venue + Ad Injected",Comp:VenueWithAd},
    {id:"nopeeps",lb:"18. No Peeps Yet",Comp:NoPeeps},
    {id:"peepdetail",lb:"19. Peep Detail",Comp:PeepDetail},
    {id:"likers",lb:"20. Likers Page",Comp:LikersPage},
    {id:"peepcreate",lb:"21. Create Peep",Comp:PeepCreate},
    {id:"peepwithphoto",lb:"22. Peep w/ Photo",Comp:PeepWithPhoto},
    {id:"agerange",lb:"23. Age Range Selector",Comp:AgeRangeSelector},
    {id:"peepsubmit",lb:"24. Peep Submitted",Comp:PeepSubmit},
    {id:"pioneer",lb:"25. Pioneer Congrats",Comp:Pioneer},
  ]},
  {sec:"Deals & Map",screens:[
    {id:"deals",lb:"26. Deals",Comp:Deals},
    {id:"dealclaimed",lb:"27. Deal Claimed",Comp:DealClaimed},
    {id:"getpeeps",lb:"28. Get Peeps",Comp:GetPeeps},
    {id:"map",lb:"29. Map",Comp:MapScr},
  ]},
  {sec:"Social",screens:[
    {id:"share",lb:"30. Share Peep",Comp:SharePeep},
    {id:"invite",lb:"31. Invite Friends",Comp:InviteFriends},
    {id:"notifs",lb:"32. Notifications",Comp:Notifs},
    {id:"push",lb:"33. Crowd Push Alert",Comp:PushAlert},
    {id:"report",lb:"34. Report Peep",Comp:Report},
  ]},
  {sec:"Gamification",screens:[
    {id:"lboard",lb:"35. Leaderboard",Comp:Lboard},
    {id:"pioneers",lb:"36. Pioneers List",Comp:PioneersList},
    {id:"scoreboard",lb:"37. Scoreboard",Comp:Scoreboard},
    {id:"vipeeps",lb:"38. VIPeeps Upsell",Comp:VIPeeps},
    {id:"vipeepsactive",lb:"39. VIPeeps Active",Comp:VIPeepsActive},
  ]},
  {sec:"Profile",screens:[
    {id:"profile",lb:"40. Profile Stats",Comp:ProfileStats},
    {id:"otherprofile",lb:"41. Other User Profile",Comp:OtherProfile},
    {id:"myhistory",lb:"42. My Peeps History",Comp:MyHistory},
    {id:"peepsreceived",lb:"43. Peeps Received",Comp:PeepsReceived},
    {id:"followers",lb:"44. Followers",Comp:Followers},
    {id:"following",lb:"45. Following",Comp:Following},
    {id:"favorites",lb:"46. Favorites",Comp:Favorites},
    {id:"scoreboard2",lb:"47. Scoreboard",Comp:Scoreboard},
    {id:"gallery",lb:"48. Photo Gallery",Comp:PhotoGallery},
    {id:"groups",lb:"49. Groups",Comp:Groups},
    {id:"menu",lb:"50. Menu / Nav",Comp:MenuNav},
  ]},
  {sec:"Settings",screens:[
    {id:"settings",lb:"51. Settings",Comp:Settings},
    {id:"accountinfo",lb:"52. Account Info",Comp:AccountInfo},
  ]},
  {sec:"Merchant Portal",screens:[
    {id:"msignin",lb:"53. Merchant Sign In",Comp:MSignIn},
    {id:"mstep1",lb:"54. Ad Step 1 — Write",Comp:MStep1},
    {id:"mstep2",lb:"55. Ad Step 2 — Time Slot",Comp:MStep2},
    {id:"mstep3",lb:"56. Ad Step 3 — Review",Comp:MStep3},
    {id:"mdash",lb:"57. Merchant Dashboard",Comp:MDash},
    {id:"mactivity",lb:"58. Ad Performance",Comp:MActivity},
    {id:"maccount",lb:"59. Merchant Account",Comp:MAccount},
    {id:"maccountnum",lb:"60. Merchant Acct # Issued",Comp:MAccountNum},
    {id:"howtoad",lb:"How to Advertise",Comp:HowToAd},
  ]},
];

const ALL=CAT.flatMap(s=>s.screens);

export default function App(){
  const [active,setActive]=useState("splash");
  const cur=ALL.find(s=>s.id===active)||ALL[0];
  const idx=ALL.findIndex(s=>s.id===active);
  const CurComp=cur.Comp;
  return(
    <div style={{minHeight:"100vh",background:"#c8d0e4",fontFamily:"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif"}}>
      <div style={{background:B,padding:"10px 16px",position:"sticky",top:0,zIndex:100,boxShadow:"0 2px 12px rgba(0,0,0,0.3)"}}>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",maxWidth:1100,margin:"0 auto"}}>
          <div>
            <span style={{color:"#fff",fontSize:20,fontWeight:900,fontStyle:"italic",letterSpacing:-1}}>peepl</span>
            <span style={{color:"rgba(255,255,255,0.5)",fontSize:10,marginLeft:10}}>Master Screen Catalogue</span>
          </div>
          <div style={{background:"rgba(255,255,255,0.15)",borderRadius:8,padding:"4px 12px"}}>
            <span style={{color:Y,fontSize:12,fontWeight:900}}>{ALL.length} screens</span>
          </div>
        </div>
      </div>
      <div style={{display:"flex",maxWidth:1100,margin:"0 auto"}}>
        <div style={{width:192,flexShrink:0,padding:"10px 0",position:"sticky",top:52,height:"calc(100vh - 52px)",overflowY:"auto",scrollbarWidth:"thin",background:"rgba(255,255,255,0.6)"}}>
          {CAT.map(section=>(
            <div key={section.sec}>
              <div style={{padding:"7px 10px 2px",fontSize:8,fontWeight:900,color:B,letterSpacing:0.5,textTransform:"uppercase"}}>{section.sec}</div>
              {section.screens.map(s=>(
                <div key={s.id} onClick={()=>setActive(s.id)}
                  style={{padding:"4px 10px",fontSize:10,cursor:"pointer",fontWeight:active===s.id?700:400,color:active===s.id?B:"#444",background:active===s.id?"rgba(34,68,238,0.1)":"transparent",borderLeft:"3px solid "+(active===s.id?B:"transparent")}}>
                  {s.lb}
                </div>
              ))}
            </div>
          ))}
        </div>
        <div style={{flex:1,padding:"20px 24px",display:"flex",flexDirection:"column",alignItems:"center"}}>
          <div style={{color:"#555",fontSize:12,marginBottom:14,fontWeight:600}}>{cur.lb}</div>
          <Ph><CurComp/></Ph>
          <div style={{display:"flex",gap:10,marginTop:16,alignItems:"center"}}>
            <button onClick={()=>{if(idx>0)setActive(ALL[idx-1].id);}} disabled={idx===0}
              style={{padding:"7px 22px",borderRadius:20,border:"none",background:idx===0?"#bbb":B,color:"#fff",fontSize:12,fontWeight:700,cursor:idx===0?"default":"pointer"}}>
              ← Prev
            </button>
            <span style={{color:"#888",fontSize:11,minWidth:50,textAlign:"center"}}>{idx+1} / {ALL.length}</span>
            <button onClick={()=>{if(idx<ALL.length-1)setActive(ALL[idx+1].id);}} disabled={idx===ALL.length-1}
              style={{padding:"7px 22px",borderRadius:20,border:"none",background:idx===ALL.length-1?"#bbb":B,color:"#fff",fontSize:12,fontWeight:700,cursor:idx===ALL.length-1?"default":"pointer"}}>
              Next →
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
