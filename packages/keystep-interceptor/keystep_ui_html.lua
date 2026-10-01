local HTML = [[
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>KeyStep Monitor</title>
  <style>
    :root {
      color-scheme: dark;
      --canvas: #111216;
      --panel: #1a1c23;
      --edge: #30333e;
      --text: #f4f5f8;
      --muted: #969cab;
      --accent: #7ce2bd;
      --warning: #ffc86b;
      --danger: #ff7b8a;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      min-height: 100vh;
      background: var(--canvas);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    .monitor {
      display: grid;
      gap: 16px;
      min-height: 100vh;
      padding: 20px;
    }

    .header, .status, .metric, .activity {
      border: 1px solid var(--edge);
      border-radius: 12px;
      background: var(--panel);
    }

    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 16px;
    }

    .eyebrow, .label {
      margin: 0;
      color: var(--muted);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
    }

    h1 {
      margin: 4px 0 0;
      font-size: 20px;
      line-height: 1.1;
    }

    .connection {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      color: var(--muted);
      font-size: 12px;
      font-weight: 650;
    }

    .dot {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      background: var(--danger);
      box-shadow: 0 0 0 4px rgba(255, 123, 138, 0.12);
    }

    .connection.connected { color: var(--accent); }
    .connection.connected .dot {
      background: var(--accent);
      box-shadow: 0 0 0 4px rgba(124, 226, 189, 0.12);
    }

    .status { padding: 14px 16px; }
    .status-value { margin: 7px 0 0; font-size: 15px; font-weight: 650; }

    .metrics {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 10px;
    }

    .metric { min-height: 106px; padding: 14px; }
    .value { margin: 10px 0 0; font-size: 27px; font-weight: 750; letter-spacing: -0.04em; }
    .hint { margin: 5px 0 0; color: var(--muted); font-size: 12px; }

    .activity { padding: 14px 16px; }
    .activity-row { display: flex; justify-content: space-between; gap: 16px; margin-top: 8px; font-size: 13px; }
    .activity-value { overflow: hidden; color: var(--text); font-weight: 600; text-overflow: ellipsis; white-space: nowrap; }
    .activity-age { flex: 0 0 auto; color: var(--warning); }
  </style>
</head>
<body>
  <main class="monitor" data-ui="keystep-monitor">
    <header class="header">
      <div>
        <p class="eyebrow">Side-channel parser</p>
        <h1>Arturia KeyStep</h1>
      </div>
      <div class="connection" id="connection">
        <span class="dot"></span>
        <span id="connection-text">Waiting for device</span>
      </div>
    </header>

    <section class="status">
      <p class="label">Input</p>
      <p class="status-value" id="device-name">No matching MIDI device</p>
      <p class="hint" id="output-device">Output: waiting for QWERTY MIDI device</p>
    </section>

    <section class="metrics">
      <article class="metric">
        <p class="label">Seq / Arp mode</p>
        <p class="value" id="mode">—</p>
        <p class="hint">C8–G8 at velocity 1</p>
      </article>
      <article class="metric">
        <p class="label">Time division</p>
        <p class="value" id="division">—</p>
        <p class="hint">Straight or triplet</p>
      </article>
      <article class="metric">
        <p class="label">Rate</p>
        <p class="value" id="bpm">—</p>
        <p class="hint">BPM from 24 PPQN clock</p>
      </article>
    </section>

    <section class="activity">
      <p class="label">Live activity</p>
      <div class="activity-row">
        <span class="activity-value" id="last-event">Awaiting MIDI</span>
        <span class="activity-age" id="event-age">—</span>
      </div>
      <div class="activity-row">
        <span class="label">Marker rule</span>
        <span class="activity-value" id="channel">C8–G8 · velocity 1</span>
      </div>
      <div class="activity-row">
        <span class="label">Last note received</span>
        <span class="activity-value" id="raw-note">Awaiting note</span>
      </div>
    </section>
  </main>

  <script>
    const text = (value, fallback = "—") => value === null || value === undefined ? fallback : String(value);

    window.updateKeyStepMonitor = (state) => {
      const connected = state.connected === true;
      const connection = document.getElementById("connection");
      connection.classList.toggle("connected", connected);
      document.getElementById("connection-text").textContent = connected ? "Connected" : "Waiting for device";
      document.getElementById("device-name").textContent = connected ? text(state.deviceName) : "No matching MIDI device";
      document.getElementById("output-device").textContent = state.outputDeviceName
        ? `Output: ${state.outputDeviceName}`
        : "Output: QWERTY MIDI device unavailable";
      document.getElementById("mode").textContent = state.mode ? `Position ${state.mode}` : "—";
      document.getElementById("division").textContent = text(state.division);
      document.getElementById("bpm").textContent = state.bpm ? `${state.bpm} BPM` : "—";
      document.getElementById("last-event").textContent = text(state.lastEvent, "Awaiting MIDI");
      document.getElementById("event-age").textContent = Number.isFinite(state.eventAge) ? `${state.eventAge}s ago` : "—";
      document.getElementById("channel").textContent = `C8–G8 · velocity 1 · ${state.clockPulseCount || 0} clocks`;
      document.getElementById("raw-note").textContent = Number.isFinite(state.lastRawNote)
        ? `Note ${state.lastRawNote} on MIDI ${(state.lastRawNoteChannel || 0) + 1}`
        : "Awaiting note";
    };
  </script>
</body>
</html>
]]

return HTML
