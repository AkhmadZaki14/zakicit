import { useState, useEffect, useRef } from 'react';

const BASE = '/api';
const POLL_MS = 5000;

const fmtM = (n) => n == null ? '—' : (n / 1e6).toFixed(2) + 'M';
const fmtNum = (n) => n == null ? '—' : Number(n).toLocaleString();
const fmtSec = (s) => {
  if (s == null || s < 0) return '—';
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
};

const STATE_STYLE = {
  ONLINE: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  STALE:  'bg-amber-500/10  text-amber-400  border-amber-500/20',
  OFFLINE:'bg-rose-500/10   text-rose-400   border-rose-500/20',
};
const DOT_STYLE = {
  ONLINE: 'bg-emerald-500',
  STALE:  'bg-amber-500',
  OFFLINE:'bg-rose-500',
};

export default function App() {
  const [fleet, setFleet]     = useState(null);
  const [lastSync, setLastSync] = useState(null);
  const [error, setError]     = useState(null);
  const timer = useRef(null);

  const fetchFleet = async () => {
    try {
      const res = await fetch(`${BASE}/fleet`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setFleet(data);
      setLastSync(new Date());
      setError(null);
    } catch (e) {
      setError(e.message);
    }
  };

  useEffect(() => {
    fetchFleet();
    timer.current = setInterval(fetchFleet, POLL_MS);
    return () => clearInterval(timer.current);
  }, []);

  const bots   = fleet?.bots  || [];
  const s      = fleet?.summary || {};
  const online  = s.online  || 0;
  const stale   = s.stale   || 0;
  const offline = s.offline || 0;
  const total   = s.totalBots || 0;

  return (
    <div className="min-h-screen bg-[#090a0f] text-zinc-100 flex flex-col antialiased">

      {/* Header */}
      <header className="border-b border-zinc-800/80 bg-[#090a0f]/80 backdrop-blur sticky top-0 z-50 px-6 py-3">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400 font-bold text-sm">GT</div>
            <div>
              <h1 className="text-sm font-semibold tracking-wide text-zinc-100 flex items-center gap-2">
                GT FLEET MONITOR
                <span className="text-[10px] font-mono uppercase bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 px-2 py-0.5 rounded-full">Live</span>
              </h1>
              <p className="text-xs text-zinc-500">Autonomous Remote Fleet Manager</p>
            </div>
          </div>
          <div className="flex items-center gap-4 text-xs font-mono text-zinc-400">
            {error
              ? <span className="text-rose-400">⚠ {error}</span>
              : <span className="flex items-center gap-1.5">
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                  </span>
                  Poll: {POLL_MS / 1000}s
                </span>
            }
            {lastSync && <span className="text-zinc-600 hidden md:inline">Synced {lastSync.toLocaleTimeString()}</span>}
          </div>
        </div>
      </header>

      <main className="max-w-7xl w-full mx-auto px-6 py-8 flex-1">

        {/* Summary Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <Card label="Fleet Status">
            <div className="text-2xl font-bold">
              <span className="text-zinc-100">{online}</span>
              <span className="text-xs text-zinc-500 font-normal"> / {total} online</span>
            </div>
            <div className="flex gap-2 text-xs mt-2 font-mono">
              <span className="text-amber-400">{stale} stale</span>
              <span className="text-zinc-600">·</span>
              <span className="text-rose-400">{offline} offline</span>
            </div>
            <div className="w-full bg-zinc-800 h-1 rounded-full mt-3 overflow-hidden">
              <div className="bg-emerald-500 h-full transition-all duration-500" style={{ width: `${total ? (online / total) * 100 : 0}%` }} />
            </div>
          </Card>

          <Card label="Total Kekayaan">
            <div className="text-xl font-bold text-indigo-300 font-mono">{fmtNum(s.totalWealthWl)} WL</div>
            <div className="text-xs text-zinc-500 mt-1">≈ {s.totalWealthWl ? (s.totalWealthWl / 100).toFixed(1) : 0} DL</div>
            <div className="text-xs text-zinc-400 mt-1">{fmtM(s.totalGems)} gems · {fmtNum(s.totalWlInv)} WL inv</div>
          </Card>

          <Card label="Laju Farming">
            <div className="text-xl font-bold text-emerald-400 font-mono">{fmtNum(s.totalWlPerHour)} WL/h</div>
            <div className="text-xs text-zinc-500 mt-1">≈ {s.totalDlPerHour || 0} DL/h</div>
            <div className="text-xs text-zinc-400 mt-1">{fmtM(s.totalGemsPerHour)} gems/h</div>
          </Card>

          <Card label="Proyeksi 24 Jam">
            <div className="text-xl font-bold text-amber-400 font-mono">{fmtNum(s.projection24hWl)} WL</div>
            <div className="text-xs text-zinc-500 mt-1">≈ {s.projection24hWl ? (s.projection24hWl / 100).toFixed(1) : 0} DL</div>
            <div className="text-xs text-zinc-400 mt-1">{fmtM(s.projection24h)} gems</div>
          </Card>
        </div>

        {/* Bot Grid */}
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">Connected Workers ({total})</h2>
          <div className="text-xs text-zinc-600 font-mono">Auto-refresh {POLL_MS / 1000}s</div>
        </div>

        {!fleet ? (
          <Empty loading>Menghubungkan ke backend...</Empty>
        ) : bots.length === 0 ? (
          <Empty>Belum ada bot terhubung. Bot akan muncul setelah kirim heartbeat.</Empty>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {bots.map((b) => <BotCard key={b.userId} b={b} />)}
          </div>
        )}
      </main>

      <footer className="border-t border-zinc-900 py-5 text-center text-xs text-zinc-600 font-mono">
        GT Fleet Monitor · {new Date().getFullYear()}
      </footer>
    </div>
  );
}

function Card({ label, children }) {
  return (
    <div className="bg-[#12131a] border border-zinc-800/80 rounded-xl p-4 shadow-sm hover:border-zinc-700 transition">
      <div className="text-[10px] text-zinc-500 font-medium uppercase tracking-wider mb-2">{label}</div>
      {children}
    </div>
  );
}

function Empty({ children, loading }) {
  return (
    <div className="h-64 flex flex-col items-center justify-center border border-dashed border-zinc-800 rounded-2xl bg-[#0f1015]/40 text-zinc-500 text-sm">
      {loading && <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin mb-3" />}
      <p>{children}</p>
    </div>
  );
}

function BotCard({ b }) {
  const state = b.state || 'OFFLINE';
  const isLive = state === 'ONLINE' || state === 'STALE';

  return (
    <div className="group relative bg-[#12131c] border border-zinc-800 hover:border-indigo-500/40 rounded-xl p-5 shadow-sm transition-all duration-200 flex flex-col gap-3 overflow-hidden">
      <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-indigo-500/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

      {/* Header row */}
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold text-zinc-100 text-base tracking-tight flex items-center gap-2">
            {b.name || b.userId}
            {b.stuck && <span className="text-[10px] font-mono bg-rose-500/10 text-rose-400 border border-rose-500/20 px-1.5 py-0.5 rounded">STUCK</span>}
            {b.duplicate && <span className="text-[10px] font-mono bg-amber-500/10 text-amber-400 border border-amber-500/20 px-1.5 py-0.5 rounded">DUP</span>}
          </div>
          <div className="text-xs font-mono text-indigo-400 mt-0.5">{b.world || '—'}</div>
        </div>
        <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium border ${STATE_STYLE[state] || STATE_STYLE.OFFLINE}`}>
          <span className={`h-1.5 w-1.5 rounded-full ${state === 'ONLINE' ? 'animate-ping' : ''} ${DOT_STYLE[state] || DOT_STYLE.OFFLINE}`} />
          {state}
        </span>
      </div>

      {/* Activity */}
      <div className="bg-[#0b0c10] border border-zinc-800/80 rounded-lg px-3 py-2 text-xs flex items-center justify-between">
        <span className="text-zinc-500 font-medium">Activity</span>
        <span className="font-mono text-zinc-300 truncate max-w-[180px]">{b.activity || 'Idle'}</span>
      </div>

      {/* Gems + Lock */}
      <div className="grid grid-cols-2 gap-2 text-xs">
        <div className="bg-[#171822] rounded-lg p-2.5 border border-zinc-800/60">
          <div className="text-zinc-500 text-[10px] uppercase font-mono mb-1">Gems</div>
          <div className="text-sm font-bold text-indigo-300 font-mono">{fmtM(b.gems)}</div>
          <div className="text-[10px] text-zinc-400 font-mono mt-0.5">≈ {fmtNum(Math.round(b.wlEquivalentFromGems || 0))} WL</div>
        </div>
        <div className="bg-[#171822] rounded-lg p-2.5 border border-zinc-800/60">
          <div className="text-zinc-500 text-[10px] uppercase font-mono mb-1">Inv (WL/DL/BGL)</div>
          <div className="text-sm font-bold text-amber-300 font-mono">{fmtNum(b.wlInv)} WL</div>
          <div className="text-[10px] text-zinc-400 font-mono mt-0.5">{fmtNum(b.dl)} DL · {fmtNum(b.bgl)} BGL</div>
        </div>
      </div>

      {/* Rate */}
      <div className="bg-[#0f1017] border border-zinc-800/60 rounded-lg p-2.5 text-xs font-mono">
        <div className="text-zinc-500 text-[10px] uppercase mb-1">Laju Farming</div>
        <div className="flex justify-between text-zinc-300">
          <span>Rate/Jam: <strong className={isLive ? 'text-emerald-400' : 'text-zinc-600'}>{fmtNum(b.ratePerHour)} gems</strong></span>
          <span><strong className={isLive ? 'text-indigo-400' : 'text-zinc-600'}>{fmtNum(b.wlPerHour)} WL/h</strong></span>
        </div>
      </div>

      {/* Rent info (jika ada) */}
      {(b.paywallRemSec >= 0 || b.rentRemSec >= 0) && (
        <div className="bg-[#0f1017] border border-zinc-800/60 rounded-lg p-2.5 text-xs font-mono">
          <div className="text-zinc-500 text-[10px] uppercase mb-1">Sewa / Paywall</div>
          <div className="flex justify-between text-zinc-300">
            {b.paywallRemSec >= 0 && <span>🚪 BFG: <strong className={b.paywallRemSec < 300 ? 'text-rose-400' : 'text-zinc-300'}>{fmtSec(b.paywallRemSec)}</strong></span>}
            {b.rentRemSec >= 0 && <span>🗡️ Sewa: <strong className={b.rentRemSec < 300 ? 'text-rose-400' : 'text-zinc-300'}>{fmtSec(b.rentRemSec)}</strong> {b.rentEquipped ? '✓' : '✗'}</span>}
          </div>
        </div>
      )}

      {/* Footer */}
      <div className="border-t border-zinc-800/70 pt-2 text-[11px] font-mono text-zinc-500 flex items-center justify-between">
        <span>Up: <span className="text-zinc-400">{b.uptime || '—'}</span></span>
        <span>Wealth: <span className="text-zinc-300">{fmtNum(b.wealthWl)} WL</span></span>
        <span>Health: <span className={b.healthScore >= 80 ? 'text-emerald-400' : b.healthScore >= 50 ? 'text-amber-400' : 'text-rose-400'}>{b.healthScore ?? '—'}</span></span>
      </div>
    </div>
  );
}
