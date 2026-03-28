import { useState } from "react";

const BLUE = "#2244EE";
const NAV_BLUE = "#1133BB";

// ── Dot-ring badge ────────────────────────────────────────
function DotRing({ status, size = 68 }) {
  const n = 12, r = size * 0.37, cx = size / 2, cy = size / 2, dr = size * 0.076;
  const MAP = {
    "PACKED!":  { c: "#EE1E1E", f: 12 },
    "BUSY":     { c: "#4433EE", f: 9  },
    "MODERATE": { c: "#3355CC", f: 7  },
    "MEDIUM":   { c: "#3366BB", f: 6  },
    "LIGHT":    { c: "#3377AA", f: 3  },
    "EMPTY":    { c: "#777",    f: 0  },
  };
  const { c, f } = MAP[status] || MAP["EMPTY"];
  const fs = status.length > 5 ? size * 0.114 : size * 0.15;
  return (
    <svg width={size} height={size} style={{ display: "block", filter: "drop-shadow(0 1px 5px rgba(0,0,0,0.9))" }}>
      {[...Array(n)].map((_, i) => {
        const a = (i / n) * 2 * Math.PI - Math.PI / 2;
        return (
          <circle key={i}
            cx={cx + r * Math.cos(a)} cy={cy + r * Math.sin(a)} r={dr}
            fill={i < f ? c : "rgba(220,220,220,0.18)"}
            stroke="rgba(0,0,0,0.2)" strokeWidth={0.5} />
        );
      })}
      <text x={cx} y={cy} textAnchor="middle" dominantBaseline="middle"
        fill="#fff" fontSize={fs} fontWeight="900" fontFamily="-apple-system,system-ui,sans-serif">
        {status}
      </text>
    </svg>
  );
}

// ── Phone shell ───────────────────────────────────────────
function Phone({ children }) {
  return (
    <div style={{ width: 260, background: "#111", borderRadius: 40, padding: "10px 8px 14px", boxShadow: "0 22px 65px rgba(0,0,0,0.65), inset 0 0 0 1px #2a2a2a" }}>
      <div style={{ display: "flex", justifyContent: "center", marginBottom: 6 }}>
        <div style={{ width: 54, height: 5, background: "#2a2a2a", borderRadius: 3 }} />
      </div>
      <div style={{ borderRadius: 24, overflow: "hidden", height: 504 }}>
        <div style={{ height: "100%", overflowY: "auto", overflowX: "hidden", scrollbarWidth: "none" }}>
          {children}
        </div>
      </div>
      <div style={{ display: "flex", justifyContent: "center", marginTop: 8 }}>
        <div style={{ width: 80, height: 4, background: "#333", borderRadius: 2 }} />
      </div>
    </div>
  );
}

// ── Shared header ─────────────────────────────────────────
function Hdr({ left = "Get Peeps", right = "Peep!" }) {
  return (
    <div style={{ background: BLUE, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "5px 12px 4px", flexShrink: 0 }}>
      <span style={{ color: "#fff", fontSize: 10, fontWeight: 600, width: 52 }}>{left}</span>
      <span style={{ color: "#fff", fontSize: 15, fontWeight: 900, fontStyle: "italic", letterSpacing: -0.5 }}>peepl</span>
      <span style={{ color: "#fff", fontSize: 10, fontWeight: 700, width: 52, textAlign: "right" }}>{right}</span>
    </div>
  );
}

function Strip({ text }) {
  return (
    <div style={{ background: NAV_BLUE, padding: "2px 10px", flexShrink: 0 }}>
      <span style={{ color: "#fff", fontSize: 10, fontWeight: 700 }}>{text}</span>
    </div>
  );
}

// ── Bottom app nav (main screens) ────────────────────────
function AppNav({ active = "getpeeps" }) {
  return (
    <div style={{ background: BLUE, display: "flex", justifyContent: "space-around", padding: "3px 0 4px", flexShrink: 0, borderTop: "1px solid rgba(255,255,255,0.12)" }}>
      {[
        { id: "deals",    label: "Deals",     node: <span style={{ fontSize: 13 }}>💲</span> },
        { id: "getpeeps", label: "Get Peeps", node: (
          <div style={{ width: 16, height: 16, borderRadius: "50%", background: active === "getpeeps" ? "#22CC22" : "rgba(255,255,255,0.25)", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 1px" }}>
            <span style={{ color: "#fff", fontSize: 10, fontWeight: 900, fontStyle: "italic" }}>p</span>
          </div>
        )},
        { id: "profile",  label: "Profile",   node: <span style={{ fontSize: 13 }}>👤</span> },
      ].map(t => (
        <div key={t.id} style={{ textAlign: "center" }}>
          {t.node}
          <div style={{ color: active === t.id ? "#22CC22" : "#bbb", fontSize: 7, fontWeight: 600 }}>{t.label}</div>
        </div>
      ))}
    </div>
  );
}

function TabBar() {
  return (
    <div style={{ background: BLUE, padding: "3px 8px 4px", display: "flex", gap: 3, flexShrink: 0 }}>
      {["Deals", "Peeps", "Profiles"].map(t => (
        <div key={t} style={{ flex: 1, background: "rgba(255,255,255,0.1)", border: "1px solid rgba(100,160,255,0.4)", borderRadius: 3, padding: "4px 0", textAlign: "center" }}>
          <span style={{ color: "#88aaff", fontSize: 9, fontWeight: 700 }}>{t}</span>
        </div>
      ))}
    </div>
  );
}

// ── Feed card ─────────────────────────────────────────────
function NativeAd({ bg, headline, sub }) {
  return (
    <div style={{ flexShrink: 0, marginBottom: 3, position: "relative" }}>
      <div style={{ height: 72, overflow: "hidden", position: "relative", background: bg }}>
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right,rgba(0,0,0,0.62) 0%,rgba(0,0,0,0.18) 100%)" }} />
        <div style={{ position: "absolute", top: 4, left: 7 }}>
          <div style={{ background: "rgba(255,255,255,0.18)", border: "1px solid rgba(255,255,255,0.35)", borderRadius: 2, padding: "1px 5px", display: "inline-block", marginBottom: 3 }}>
            <span style={{ color: "#fff", fontSize: 7.5, fontWeight: 700, letterSpacing: 0.5 }}>SPONSORED</span>
          </div>
          <div style={{ color: "#fff", fontSize: 13, fontWeight: 800, textShadow: "0 1px 4px rgba(0,0,0,0.9)", lineHeight: 1.2 }}>{headline}</div>
          <div style={{ color: "rgba(255,255,255,0.8)", fontSize: 9.5, textShadow: "0 1px 3px rgba(0,0,0,0.9)" }}>{sub}</div>
        </div>
      </div>
    </div>
  );
}

const ADS = [
  // Stella Artois — dark amber bar, beer glass warm glow (photo 3)
  { bg: "linear-gradient(135deg, #0d0802 0%, #2a1505 25%, #6b3d12 50%, #c8820a 65%, #4a2008 82%, #0d0802 100%)", headline: "Stella Artois", sub: "She's a thing of beauty" },
  // American Express — warm golden living room (photo 5)
  { bg: "linear-gradient(135deg, #7a5018 0%, #c89040 30%, #e8b850 55%, #c07828 78%, #7a5018 100%)", headline: "American Express", sub: "Don't live life without it" },
  // Stella again rotated
  { bg: "linear-gradient(135deg, #0d0802 0%, #2a1505 25%, #6b3d12 50%, #c8820a 65%, #4a2008 82%, #0d0802 100%)", headline: "Stella Artois", sub: "She's a thing of beauty" },
  // Amex again
  { bg: "linear-gradient(135deg, #7a5018 0%, #c89040 30%, #e8b850 55%, #c07828 78%, #7a5018 100%)", headline: "American Express", sub: "Don't live life without it" },
];

function interleavedAds(posts, adList) {
  const out = [];
  posts.forEach((p, i) => {
    out.push({ type: "post", data: p });
    if ((i + 1) % 2 === 0) out.push({ type: "ad", data: adList[Math.floor(i / 2) % adList.length] });
  });
  return out;
}

function Card({ venue, user, date, dist, status, mf, wait, ak, ages, pets, bg, hasVideo }) {
  return (
    <div style={{ flexShrink: 0, marginBottom: 3 }}>
      <div style={{ height: 74, position: "relative", overflow: "hidden", background: bg || "#334" }}>
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom,rgba(0,0,0,0.08) 0%,rgba(0,0,0,0) 40%,rgba(0,0,0,0.7) 100%)" }} />

        {/* "Crowd Size" label */}
        <div style={{ position: "absolute", top: 3, right: 6, color: "#fff", fontSize: 7, fontWeight: 700, textShadow: "0 1px 3px #000", letterSpacing: 0.2 }}>Crowd Size</div>

        {/* Dot ring badge — right side */}
        <div style={{ position: "absolute", top: 10, right: 3 }}>
          <DotRing status={status} size={36} />
        </div>

        {/* Demographics overlay — left of badge on right side */}
        {(pets || mf || wait || ak || ages) && (
          <div style={{ position: "absolute", top: 10, right: 42 }}>
            {pets && <D t={`Pets: ${pets}`} />}
            {mf   && <D t={`M/F: ${mf}`} />}
            {wait && <D t={`Wait: ${wait}`} />}
            {ak   && <D t={`A/K: ${ak}`} />}
            {ages && <D t={`Ages: ${ages}`} />}
          </div>
        )}

        {/* Video play button — center */}
        {hasVideo && (
          <div style={{ position: "absolute", right: 48, top: "50%", transform: "translateY(-50%)", width: 24, height: 24, borderRadius: "50%", background: "rgba(18,152,168,0.88)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ borderTop: "5px solid transparent", borderBottom: "5px solid transparent", borderLeft: "9px solid #fff", marginLeft: 2 }} />
          </div>
        )}

        {/* Venue name — bottom left */}
        {venue && (
          <div style={{ position: "absolute", bottom: 4, left: 6, right: 44 }}>
            <div style={{ color: "#fff", fontSize: 11, fontWeight: 800, textShadow: "0 1px 5px rgba(0,0,0,1)", lineHeight: 1.1 }}>{venue}</div>
          </div>
        )}
      </div>

      {/* Info strip */}
      <div style={{ background: "rgba(6,6,6,0.9)", padding: "2px 8px", display: "flex", justifyContent: "space-between" }}>
        <span style={{ color: "#aaa", fontSize: 7.5 }}>{user}</span>
        <span style={{ color: "#aaa", fontSize: 7.5 }}>{date}</span>
        <span style={{ color: "#aaa", fontSize: 7.5 }}>{dist}</span>
      </div>
    </div>
  );
}

function D({ t }) {
  return <div style={{ color: "#fff", fontSize: 7.5, fontWeight: 700, textShadow: "0 1px 3px rgba(0,0,0,1)", lineHeight: 1.3 }}>{t}</div>;
}

// ── Screen data ───────────────────────────────────────────
// bg values are CSS gradients matched to uploaded venue photos
const GYM        = "linear-gradient(160deg, #dce8f2 0%, #b8cede 25%, #a0bcd0 50%, #c0d4e4 75%, #e0eaf4 100%)";
const PURE       = "linear-gradient(135deg, #3d2408 0%, #7a4a1a 22%, #c87830 45%, #e09848 60%, #8b5520 80%, #4a2c0a 100%)";
const FOOD_TERM  = "linear-gradient(160deg, #0e0e08 0%, #1c1c10 30%, #282814 55%, #1e1e0c 78%, #0e0e08 100%)";
const JOEY_D     = "linear-gradient(135deg, #b8d0a8 0%, #d8e8c8 28%, #e8f0d8 50%, #c8dab8 72%, #90b888 100%)";
const CONVENTION = "linear-gradient(135deg, #16091e 0%, #28103a 28%, #3a1852 50%, #241040 72%, #16091e 100%)";
const OSTERIA    = "linear-gradient(135deg, #180b04 0%, #3a1c0c 28%, #582c14 50%, #3c1e0e 72%, #180b04 100%)";
const PIEDMONT   = "linear-gradient(160deg, #2d6a1f 0%, #4a8a32 25%, #72aa50 50%, #a8d080 65%, #90c8e8 82%, #5090c0 100%)";

const S1 = [
  { venue: "Joey D's Oak Room",                  user: "anon-7b888", date: "5/19/2017 8:29 PM",  dist: "3 miles away",   status: "PACKED!",  mf: "50/50", wait: "Minutes", bg: JOEY_D },
  { venue: "Georgia Intl Convention Center",     user: "anon-91703", date: "5/15/2017 6:36 PM",  dist: "19 miles away",  status: "BUSY",     hasVideo: true, bg: CONVENTION },
  { venue: "Osteria 832",                        user: "anon-7b888", date: "5/14/2017 7:05 PM",  dist: "8 miles away",   status: "BUSY",     wait: "None", bg: OSTERIA },
  { venue: "Piedmont Park",                      user: "anon-7b888", date: "5/13/2017 4:15 PM",  dist: "2 miles away",   status: "MODERATE", mf: "50/50", ak: "30/70", pets: "A few", bg: PIEDMONT },
];

const S2 = [
  { venue: "Atlanta Airport TSA North Terminal", user: "LordByron",  date: "10/11/2017 9:23 AM", dist: "68 miles away",  status: "PACKED!",  bg: "linear-gradient(135deg,#2a2a2a 0%,#484848 30%,#606060 55%,#404040 80%,#2a2a2a 100%)" },
  { venue: "Monday Night Brewing",               user: "LordByron",  date: "10/7/2017 5:24 PM",  dist: "74 miles away",  status: "BUSY",     bg: "linear-gradient(135deg,#1a0f04 0%,#3a2010 30%,#6a3a18 55%,#3a2010 80%,#1a0f04 100%)" },
  { venue: "Hartsfield Jackson Airport",         user: "LordByron",  date: "10/6/2017 8:43 PM",  dist: "68 miles away",  status: "PACKED!",  bg: "linear-gradient(135deg,#303030 0%,#505050 30%,#686868 55%,#484848 80%,#303030 100%)" },
];

const S3 = [
  { venue: "Sivas Tavern",       user: "chazz26",   date: "11/4/2017 9:21 PM",  dist: "16 miles away", status: "LIGHT",    mf: "50/50", wait: "None",       bg: "linear-gradient(135deg,#1c1008 0%,#3a2010 30%,#5a3420 55%,#3a2412 80%,#1c1008 100%)" },
  { venue: "Chomp & Stomp",      user: "LordByron", date: "11/4/2017 1:58 PM",  dist: "10 miles away", status: "PACKED!",  mf: "50/50", ak: "70/30", pets: "A few", bg: "linear-gradient(135deg,#1a2808 0%,#2e4010 30%,#4a6020 55%,#385018 80%,#1a2808 100%)" },
  { venue: "Starbucks",          user: "jeff",      date: "10/25/2017 9:05 AM", dist: "5 miles away",  status: "MODERATE", wait: "A minute",   bg: "linear-gradient(135deg,#0f1a08 0%,#1e3010 30%,#2a4018 55%,#1e3010 80%,#0f1a08 100%)" },
  { venue: "Two Birds Taphouse", user: "chazz26",   date: "10/24/2017 6:53 PM", dist: "13 miles away", status: "BUSY",     wait: "None", mf: "50/50", ages: "40-50, 30-40", bg: PURE },
];

const S4 = [
  { venue: "LA Fitness",               user: "LordByron", date: "6/12/2017 5:12 PM", dist: "2 miles away",   status: "MEDIUM",  bg: GYM },
  { venue: "Pure Taqueria Brookhaven", user: "LordByron", date: "6/7/2017 8:46 PM",  dist: "5246 feet away", status: "BUSY",    wait: "None", bg: PURE },
  { venue: "Food Terminal",            user: "jc",        date: "6/3/2017 8:24 PM",  dist: "1 mile away",    status: "PACKED!", hasVideo: true, bg: FOOD_TERM },
  { venue: "",                         user: "",          date: "",                   dist: "",               status: "EMPTY",   hasVideo: true, bg: PURE },
];

// ── Screens ───────────────────────────────────────────────
function Feed({ posts }) {
  const items = interleavedAds(posts, ADS);
  return (
    <div>
      {items.map((item, i) =>
        item.type === "ad"
          ? <NativeAd key={i} {...item.data} />
          : <Card key={i} {...item.data} />
      )}
    </div>
  );
}

function Screen1() {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#000" }}>
      <Hdr left="Get Peeps" />
      <Strip text="What's happening" />
      <div style={{ flex: 1, overflowY: "auto", overflowX: "hidden", scrollbarWidth: "none" }}><Feed posts={S1} /></div>
      <AppNav active="getpeeps" />
    </div>
  );
}

function Screen2() {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#000" }}>
      <Hdr left="Cancel" />
      <div style={{ background: BLUE, padding: "4px 10px 5px", display: "flex", alignItems: "center", gap: 6, flexShrink: 0 }}>
        <span style={{ color: "#fff", fontSize: 11, fontWeight: 700 }}>≡↓</span>
        <div style={{ flex: 1, background: "rgba(255,255,255,0.2)", borderRadius: 8, padding: "5px 10px", display: "flex", alignItems: "center", gap: 5 }}>
          <span style={{ color: "rgba(255,255,255,0.55)", fontSize: 10 }}>🔍</span>
          <span style={{ color: "rgba(255,255,255,0.55)", fontSize: 10 }}>Search for a place</span>
        </div>
      </div>
      <Strip text="What's happening" />
      <div style={{ flex: 1, overflowY: "auto", overflowX: "hidden", scrollbarWidth: "none" }}><Feed posts={S2} /></div>
      <TabBar />
    </div>
  );
}

function Screen3() {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#000" }}>
      <Hdr left="Cancel" />
      <div style={{ flex: 1, overflowY: "auto", overflowX: "hidden", scrollbarWidth: "none" }}><Feed posts={S3} /></div>
      <TabBar />
    </div>
  );
}

function Screen4() {
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "#000" }}>
      <Hdr left="Get Peeps" />
      <Strip text="What's happening" />
      <div style={{ flex: 1, overflowY: "auto", overflowX: "hidden", scrollbarWidth: "none" }}><Feed posts={S4} /></div>
      <AppNav active="deals" />
    </div>
  );
}

// ── Root ──────────────────────────────────────────────────
const TABS = [
  { id: "s1", label: "Main Feed" },
  { id: "s2", label: "Search" },
  { id: "s3", label: "Browse / Post" },
  { id: "s4", label: "What's Happening" },
];

export default function App() {
  const [tab, setTab] = useState("s1");
  const screen = { s1: <Screen1/>, s2: <Screen2/>, s3: <Screen3/>, s4: <Screen4/> }[tab];
  return (
    <div style={{ minHeight: "100vh", background: "#d0d5e8", padding: "22px 12px 40px", fontFamily: "-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif" }}>
      <div style={{ textAlign: "center", marginBottom: 16 }}>
        <h1 style={{ fontSize: 28, fontWeight: 900, color: BLUE, margin: 0, fontStyle: "italic" }}>peepl</h1>
        <p style={{ color: "#888", fontSize: 12, margin: "4px 0 0" }}>Scroll inside the phone · Switch screens with tabs below</p>
      </div>

      {/* Legend */}
      <div style={{ display: "flex", justifyContent: "center", gap: 10, marginBottom: 16, flexWrap: "wrap" }}>
        {[["PACKED!", "#EE1E1E"], ["BUSY", "#4433EE"], ["MODERATE", "#3355CC"], ["MEDIUM", "#3366BB"], ["LIGHT", "#3377AA"], ["EMPTY", "#777"]].map(([s, c]) => (
          <div key={s} style={{ display: "flex", alignItems: "center", gap: 5 }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%", background: c }} />
            <span style={{ fontSize: 11, fontWeight: 700, color: "#444" }}>{s}</span>
          </div>
        ))}
      </div>

      <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: 6, marginBottom: 20 }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{ padding: "6px 16px", borderRadius: 20, border: "none", cursor: "pointer", fontSize: 12, fontWeight: 700, background: tab === t.id ? BLUE : "#c4cbe0", color: tab === t.id ? "#fff" : "#444" }}>{t.label}</button>
        ))}
      </div>

      <div style={{ display: "flex", justifyContent: "center" }}>
        <Phone>{screen}</Phone>
      </div>
    </div>
  );
}
