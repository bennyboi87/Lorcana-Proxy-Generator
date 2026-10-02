<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lorcana Image Cache Builder</title>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
  <style>
    :root {
      --bg: #121824;
      --card-bg: #1c2436;
      --accent: #dca842;
      --text: #f0f4f8;
      --text-muted: #94a3b8;
      --border: #2e3a52;
      --success: #22c55e;
      --error: #ef4444;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      display: flex;
      justify-content: center;
      padding: 40px 16px;
      margin: 0;
    }
    .container {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      width: 100%;
      max-width: 680px;
      padding: 24px;
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.4);
    }
    h1 {
      margin-top: 0;
      color: var(--accent);
      font-size: 1.5rem;
    }
    p {
      color: var(--text-muted);
      font-size: 0.9rem;
      margin-bottom: 16px;
    }
    .tab-group {
      display: flex;
      gap: 8px;
      margin-bottom: 16px;
      border-bottom: 1px solid var(--border);
      padding-bottom: 8px;
    }
    .tab-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      font-weight: 600;
      cursor: pointer;
      padding: 8px 16px;
      border-radius: 6px;
      transition: all 0.2s;
    }
    .tab-btn.active {
      background: var(--border);
      color: var(--accent);
    }
    textarea, select {
      width: 100%;
      background: #0f141d;
      border: 1px solid var(--border);
      color: #fff;
      padding: 12px;
      border-radius: 8px;
      font-family: monospace;
      font-size: 0.95rem;
      box-sizing: border-box;
      margin-bottom: 16px;
    }
    textarea {
      height: 160px;
      resize: vertical;
    }
    .btn-row {
      display: flex;
      gap: 12px;
    }
    button.action-btn {
      background: var(--accent);
      color: #121824;
      font-weight: 700;
      border: none;
      padding: 12px 20px;
      border-radius: 6px;
      cursor: pointer;
      flex: 1;
      font-size: 1rem;
      transition: opacity 0.2s;
    }
    button.action-btn:hover:not(:disabled) {
      opacity: 0.9;
    }
    button.action-btn:disabled {
      background: #475569;
      cursor: not-allowed;
      color: #94a3b8;
    }
    button.clear-btn {
      background: transparent;
      border: 1px solid var(--border);
      color: var(--text-muted);
      padding: 12px 16px;
      border-radius: 6px;
      cursor: pointer;
    }
    button.clear-btn:hover {
      color: var(--error);
      border-color: var(--error);
    }
    .progress-bar-container {
      margin-top: 20px;
      background: #0f141d;
      border: 1px solid var(--border);
      height: 12px;
      border-radius: 6px;
      overflow: hidden;
      display: none;
    }
    .progress-bar {
      height: 100%;
      background: var(--accent);
      width: 0%;
      transition: width 0.15s ease-in-out;
    }
    #status {
      margin-top: 16px;
      font-size: 0.85rem;
      color: var(--text-muted);
      white-space: pre-wrap;
      font-family: monospace;
      max-height: 180px;
      overflow-y: auto;
      background: #0f141d;
      padding: 12px;
      border-radius: 8px;
      border: 1px solid var(--border);
    }
  </style>
</head>
<body>

<div class="container">
  <h1>Image Cache Builder</h1>
  <p>Download card artwork directly from the API, pre-cache it in browser memory, and download an <code>images.zip</code> archive ready to extract straight into your GitHub repository.</p>

  <div class="tab-group">
    <button class="tab-btn active" id="tabCustomBtn" onclick="switchMode('custom')">Custom List</button>
    <button class="tab-btn" id="tabSetBtn" onclick="switchMode('set')">Entire Set</button>
  </div>

  <div id="customMode">
    <textarea id="cardListInput" placeholder="Paste card names or a decklist here...&#10;Strength of a Raging Fire&#10;Max Goof - Rebellious Teen&#10;You Broke My Smolder"></textarea>
  </div>

  <div id="setMode" style="display: none;">
    <select id="setSelect">
      <option value="1">Set 1: The First Chapter</option>
      <option value="2">Set 2: Rise of the Floodborn</option>
      <option value="3">Set 3: Into the Inklands</option>
      <option value="4">Set 4: Ursula's Return</option>
      <option value="5">Set 5: Shimmering Skies</option>
      <option value="6">Set 6: Azurite Sea</option>
    </select>
  </div>

  <div class="btn-row">
    <button class="action-btn" id="buildBtn" onclick="startBuild()">Download &amp; Build ZIP</button>
    <button class="clear-btn" onclick="clearLocalDB()">Purge DB</button>
  </div>

  <div class="progress-bar-container" id="progressWrap">
    <div class="progress-bar" id="progressBar"></div>
  </div>

  <div id="status">Ready. Paste cards or pick a set, then click Build.</div>
</div>

<script>
  let activeMode = 'custom';

  function switchMode(mode) {
    activeMode = mode;
    document.getElementById('customMode').style.display = mode === 'custom' ? 'block' : 'none';
    document.getElementById('setMode').style.display = mode === 'set' ? 'block' : 'none';
    document.getElementById('tabCustomBtn').classList.toggle('active', mode === 'custom');
    document.getElementById('tabSetBtn').classList.toggle('active', mode === 'set');
  }

  function log(msg) {
    const el = document.getElementById("status");
    el.textContent += `\n${msg}`;
    el.scrollTop = el.scrollHeight;
  }

  function setStatus(msg) {
    const el = document.getElementById("status");
    el.textContent = msg;
    el.scrollTop = el.scrollHeight;
  }

  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  function slugify(text) {
    return text
      .toLowerCase()
      .trim()
      .replace(/\s*-\s*/g, "-")
      .replace(/[^a-z0-9\-]/g, "")
      .replace(/\-+/g, "-");
  }

  // --- IndexedDB Management ---
  function openCacheDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open("LorcanaProxyCache", 1);
      request.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains("card_images")) {
          db.createObjectStore("card_images");
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function setCachedImage(key, buffer) {
    try {
      const db = await openCacheDB();
      const tx = db.transaction("card_images", "readwrite");
      const store = tx.objectStore("card_images");
      store.put(buffer, key);
    } catch (e) {
      console.warn("IndexedDB put failed", e);
    }
  }

  async function clearLocalDB() {
    if (!confirm("Clear all locally stored card images from browser storage?")) return;
    const req = indexedDB.deleteDatabase("LorcanaProxyCache");
    req.onsuccess = () => setStatus("Browser cache cleared successfully.");
    req.onerror = () => setStatus("Failed to clear browser cache.");
  }

  // --- Network Helpers ---
  async function fetchWithTimeout(url, timeoutMs = 8000) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(id);
      return response;
    } catch (err) {
      clearTimeout(id);
      throw err;
    }
  }

  async function downloadBufferWithFallback(url) {
    try {
      const res = await fetchWithTimeout(url, 7000);
      if (res.ok) return await res.arrayBuffer();
    } catch {}

    try {
      const proxyUrl = `https://corsproxy.io/?${encodeURIComponent(url)}`;
      const res = await fetchWithTimeout(proxyUrl, 9000);
      if (res.ok) return await res.arrayBuffer();
    } catch {}

    return null;
  }

  // --- Builders ---
  async function startBuild() {
    const buildBtn = document.getElementById("buildBtn");
    const progressWrap = document.getElementById("progressWrap");
    const progressBar = document.getElementById("progressBar");

    buildBtn.disabled = true;
    progressWrap.style.display = "block";
    progressBar.style.width = "0%";
    setStatus("Initializing build pipeline...");

    const zip = new JSZip();
    const folder = zip.folder("images");
    let cardsToProcess = [];

    if (activeMode === 'custom') {
      const text = document.getElementById("cardListInput").value;
      const lines = text.split("\n");
      const cardMap = new Map();

      for (let raw of lines) {
        let line = raw.trim();
        if (!line) continue;
        // Strip out count prefixes like "4x " or "2 "
        const m = line.match(/^(\d+)x?\s+(.*)$/i);
        const name = m ? m[2].trim() : line;
        const slug = slugify(name);
        if (!cardMap.has(slug)) {
          cardMap.set(slug, name);
        }
      }
      cardsToProcess = Array.from(cardMap.values());
    } else {
      const setId = document.getElementById("setSelect").value;
      log(`Fetching card index for Set ${setId}...`);
      try {
        const setRes = await fetchWithTimeout(`https://api.lorcast.com/v0/cards/search?q=set:${setId}`);
        if (!setRes.ok) throw new Error("Could not retrieve set info");
        const setData = await setRes.json();
        cardsToProcess = (setData.results || []).map(c => c.name);
      } catch (err) {
        setStatus(`Failed to fetch set index: ${err.message}`);
        buildBtn.disabled = false;
        return;
      }
    }

    if (cardsToProcess.length === 0) {
      setStatus("No cards found to process.");
      buildBtn.disabled = false;
      return;
    }

    setStatus(`Processing ${cardsToProcess.length} card(s)...`);
    let completed = 0;

    for (let i = 0; i < cardsToProcess.length; i++) {
      const cardName = cardsToProcess[i];
      const slug = slugify(cardName);
      log(`[${i + 1}/${cardsToProcess.length}] Searching: ${cardName}...`);

      try {
        const queryUrl = `https://api.lorcast.com/v0/cards/search?q=${encodeURIComponent(cardName)}`;
        const res = await fetchWithTimeout(queryUrl, 6000);
        if (res.ok) {
          const data = await res.json();
          if (data && data.results && data.results.length > 0) {
            const card = data.results[0];
            const imgUrl = card.image_uris?.digital?.large || card.image_uris?.digital?.normal;
            if (imgUrl) {
              const buffer = await downloadBufferWithFallback(imgUrl);
              if (buffer) {
                // Add to zip under images/
                folder.file(`${slug}.jpg`, buffer);
                // Also write directly to the browser's IndexedDB
                await setCachedImage(slug, buffer);
                completed++;
                log(`✓ Saved: ${slug}.jpg`);
              } else {
                log(`✗ Failed to download bytes for ${cardName}`);
              }
            }
          } else {
            log(`✗ Not found on API: ${cardName}`);
          }
        }
      } catch (err) {
        log(`✗ Network error for ${cardName}`);
      }

      const percent = Math.round(((i + 1) / cardsToProcess.length) * 100);
      progressBar.style.width = `${percent}%`;
      await delay(120); // API-safe pace
    }

    if (completed === 0) {
      setStatus("Build finished, but no images could be downloaded.");
      buildBtn.disabled = false;
      return;
    }

    log(`Generating images.zip (${completed} files)...`);
    const zipBlob = await zip.generateAsync({ type: "blob" });
    const downloadUrl = URL.createObjectURL(zipBlob);

    const a = document.createElement("a");
    a.href = downloadUrl;
    a.download = "lorcana-image-cache.zip";
    a.click();

    setStatus(`Complete! Downloaded ${completed} images inside lorcana-image-cache.zip and pre-cached them to browser storage.`);
    buildBtn.disabled = false;
  }
</script>
</body>
</html>
