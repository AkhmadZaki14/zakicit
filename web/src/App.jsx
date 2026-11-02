import { useState, useEffect } from 'react';

const num = (v) => Number(v || 0).toLocaleString();

export default function App() {
  const [bots, setBots] = useState({});
  const [lastSync, setLastSync] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchStatus = async () => {
    try {
      const res = await fetch('/api/status');
      if (res.ok) {
        const data = await res.json();
        setBots(data);
        setLastSync(new Date());
      }
    } catch (e) {
      console.error('Fetch error:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 2000);
    return () => clearInterval(interval);
  }, []);

  const botList = Object.entries(bots).map(([id, b]) => {
    const diffSec = Math.floor((Date.now() - (b.last_seen || 0)) / 1000);
    // Toleransi 120 detik (2 menit) sebelum dianggap offline
    const isOnline = diffSec < 120;
    return { id, ...b, diffSec, isOnline };
  });

  const totalBots = botList.length;
  const onlineBots = botList.filter((b) => b.isOnline).length;
  const offlineBots = totalBots - onlineBots;
  const totalGems = botList.reduce((acc, b) => acc + Number(b.gems || 0), 0);
  const totalDL = botList.reduce((acc, b) => acc + Number(b.dl || 0), 0);
  const totalBGL = botList.reduce((acc, b) => acc + Number(b.bgl || 0), 0);
  const totalWLFromGems = (totalGems / 1100).toFixed(1);

  return (
    <div className="min-h-screen bg-[#090a0f] text-zinc-100 flex flex-col antialiased">
      <header className="border-b border-zinc-800/80 bg-[#090a0f]/80 backdrop-blur sticky top-0 z-50 px-6 py-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="h-8 w-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400 font-bold">
              GT
            </div>
            <div>
              <h1 className="text-sm font-semibold tracking-wide text-zinc-100 flex items-center gap-2">
                GT BOT MONITOR
                <span className="text-[10px] font-mono uppercase bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 px-2 py-0.5 rounded-full">
                  Live
                </span>
              </h1>
              <p className="text-xs text-zinc-500">Autonomous Remote Fleet Manager</p>
            </div>
          </div>

          <div className="flex items-center space-x-4 text-xs font-mono text-zinc-400">
            <div className="flex items-center space-x-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              <span className="hidden sm:inline">Poll: 2s</span>
            </div>
            {lastSync && (
              <span className="text-zinc-600 hidden md:inline">
                Synced {lastSync.toLocaleTimeString()}
              </span>
            )}
          </div>
        </div>
      </header>

      <main className="max-w-7xl w-full mx-auto px-6 py-8 flex-1">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <div className="bg-[#12131a] border border-zinc-800/80 rounded-xl p-4 shadow-sm hover:border-zinc-700 transition">
            <div className="text-xs text-zinc-500 font-medium uppercase tracking-wider mb-1">Fleet Status</div>
            <div className="text-2xl font-bold flex items-baseline gap-2">
              <span className="text-zinc-100">{onlineBots}</span>
              <span className="text-xs text-zinc-500 font-normal">/ {totalBots} online</span>
            </div>
            <div className="w-full bg-zinc-800 h-1.5 rounded-full mt-3 overflow-hidden">
              <div
                className="bg-emerald-500 h-full transition-all duration-500"
                style={{ width: `${totalBots ? (onlineBots / totalBots) * 100 : 0}%` }}
              />
            </div>
          </div>

          <div className="bg-[#12131a] border border-zinc-800/80 rounded-xl p-4 shadow-sm hover:border-zinc-700 transition">
            <div className="text-xs text-zinc-500 font-medium uppercase tracking-wider mb-1">Total Gems</div>
            <div className="text-2xl font-bold text-indigo-400 tracking-tight">{num(totalGems)}</div>
            <div className="text-xs text-zinc-500 mt-2">≈ {totalWLFromGems} WL (11k = 10 WL)</div>
          </div>

          <div className="bg-[#12131a] border border-zinc-800/80 rounded-xl p-4 shadow-sm hover:border-zinc-700 transition">
            <div className="text-xs text-zinc-500 font-medium uppercase tracking-wider mb-1">DL / BGL Reserve</div>
            <div className="text-2xl font-bold text-amber-400 tracking-tight">
              {num(totalDL)} <span className="text-zinc-500 text-sm font-normal">DL</span> · {num(totalBGL)}{' '}
              <span className="text-zinc-500 text-sm font-normal">BGL</span>
            </div>
            <div className="text-xs text-zinc-500 mt-2">Locked asset inventory</div>
          </div>

          <div className="bg-[#12131a] border border-zinc-800/80 rounded-xl p-4 shadow-sm hover:border-zinc-700 transition">
            <div className="text-xs text-zinc-500 font-medium uppercase tracking-wider mb-1">Network Health</div>
            <div className="text-2xl font-bold text-zinc-200">
              {offlineBots === 0 && totalBots > 0 ? (
                <span className="text-emerald-400">100% OK</span>
              ) : totalBots === 0 ? (
                <span className="text-zinc-500">IDLE</span>
              ) : (
                <span className="text-rose-400">{offlineBots} Offline</span>
              )}
            </div>
            <div className="text-xs text-zinc-500 mt-2 font-mono">
              Real-time Delta Engine
            </div>
          </div>
        </div>

        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">
            Connected Workers ({totalBots})
          </h2>
          <div className="text-xs text-zinc-500">Auto-refresh active</div>
        </div>

        {loading && botList.length === 0 ? (
          <div className="h-64 flex flex-col items-center justify-center border border-dashed border-zinc-800 rounded-2xl bg-[#0f1015]/40 text-zinc-500 text-sm">
            <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin mb-3"></div>
            Connecting to backend...
          </div>
        ) : botList.length === 0 ? (
          <div className="h-64 flex flex-col items-center justify-center border border-dashed border-zinc-800 rounded-2xl bg-[#0f1015]/40 text-zinc-500 text-sm">
            <div className="p-3 bg-zinc-900 rounded-full mb-3 text-zinc-400 font-mono text-xs">POST /api/update</div>
            <p className="font-medium text-zinc-300">Belum ada bot yang terhubung.</p>
            <p className="text-xs text-zinc-500 mt-1">Bot script akan otomatis muncul di panel saat mengirim webhook update.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {botList.map((bot) => (
              <div
                key={bot.id}
                className="group relative bg-[#12131c] border border-zinc-800 hover:border-indigo-500/40 rounded-xl p-5 shadow-sm transition-all duration-200 animate-fade-in flex flex-col justify-between overflow-hidden"
              >
                <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-indigo-500/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />

                <div>
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <div className="font-semibold text-zinc-100 text-base tracking-tight flex items-center gap-2">
                        {bot.name || bot.id}
                        {bot.name && bot.name !== bot.id && (
                          <span className="text-[11px] font-mono text-zinc-500">({bot.id})</span>
                        )}
                      </div>
                      <div className="text-xs font-mono text-indigo-400 mt-0.5">
                        {bot.world ? `World: ${bot.world}` : 'World: -'}
                      </div>
                    </div>

                    {bot.isOnline ? (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                        <span className="relative flex h-1.5 w-1.5">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                          <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500"></span>
                        </span>
                        ONLINE
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium bg-rose-500/10 text-rose-400 border border-rose-500/20">
                        <span className="h-1.5 w-1.5 rounded-full bg-rose-500" />
                        OFFLINE
                      </span>
                    )}
                  </div>

                  <div className="bg-[#0b0c10] border border-zinc-800/80 rounded-lg px-3 py-2 text-xs flex items-center justify-between mb-4">
                    <span className="text-zinc-500 font-medium">Activity</span>
                    <span className="font-mono text-zinc-300 truncate max-w-[180px]">
                      {bot.status || 'Idle / Waiting'}
                    </span>
                  </div>

                  <div className="grid grid-cols-2 gap-3 text-xs mb-3">
                    <div className="bg-[#171822] rounded-lg p-2.5 border border-zinc-800/60">
                      <div className="text-zinc-500 text-[10px] uppercase font-mono mb-1">Gems</div>
                      <div className="text-sm font-bold text-indigo-300 font-mono">
                        {num(bot.gems)}
                      </div>
                      <div className="text-[10px] text-zinc-400 font-mono mt-0.5">
                        ≈ {bot.equivalent_wl || (bot.gems / 1100).toFixed(1)} WL
                      </div>
                    </div>

                    <div className="bg-[#171822] rounded-lg p-2.5 border border-zinc-800/60">
                      <div className="text-zinc-500 text-[10px] uppercase font-mono mb-1">DL / BGL</div>
                      <div className="text-sm font-bold text-amber-300 font-mono">
                        {num(bot.dl)} / {num(bot.bgl)}
                      </div>
                    </div>
                  </div>

                  {/* Estimation Rate asli dari moving average 20 push data */}
                  <div className="bg-[#0f1017] border border-zinc-800/60 rounded-lg p-2.5 text-xs mb-4 font-mono">
                    <div className="text-zinc-500 text-[10px] uppercase mb-1">Real-Time Yield (20 Pushes Avg)</div>
                    <div className="flex justify-between text-zinc-300">
                      <span>Rate/Min: <strong className="text-indigo-400">{num(bot.gems_per_min)}</strong></span>
                      <span>Rate/Hour: <strong className="text-emerald-400">{num(bot.gems_per_hour)}</strong></span>
                    </div>
                  </div>

                  <div className="space-y-1 mb-4">
                    <div className="flex justify-between text-[10px] text-zinc-500 font-mono">
                      <span>Worker Loop</span>
                      <span>{bot.isOnline ? 'Active' : 'Stalled'}</span>
                    </div>
                    <div className="w-full bg-zinc-900 rounded-full h-1 overflow-hidden">
                      <div
                        className={`h-full ${bot.isOnline ? 'animate-shimmer' : 'bg-zinc-800'}`}
                      />
                    </div>
                  </div>
                </div>

                <div className="border-t border-zinc-800/70 pt-3 text-[11px] font-mono text-zinc-500 flex items-center justify-between">
                  <div className="flex items-center gap-1">
                    <span className="text-zinc-600">Up:</span>
                    <span className="text-zinc-400">{bot.uptime || '-'}</span>
                  </div>
                  <div>
                    <span className="text-zinc-600">Ping: </span>
                    <span className={bot.diffSec < 10 ? 'text-emerald-400' : 'text-zinc-400'}>
                      {bot.diffSec}s ago
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>

      <footer className="border-t border-zinc-900 py-6 text-center text-xs text-zinc-600 font-mono">
        GT Remote Fleet Dashboard · Linear Minimalist Dark · Express Engine
      </footer>
    </div>
  );
}
