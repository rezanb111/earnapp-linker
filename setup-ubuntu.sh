#!/usr/bin/env bash
# EarnApp Linker - one-shot installer for a fresh Ubuntu server (20.04 / 22.04 / 24.04).
# Run as root:
#     bash setup-ubuntu.sh
# Optional settings (environment variables):
#     DOMAIN=earn.v2rei.surf   domain to serve (default). Use DOMAIN="" to serve on the server IP only.
#     EMAIL=you@example.com    email for Let's Encrypt expiry notices (optional)
#     FORCE_SSL=1              request the certificate even if DNS does not point here yet
set -euo pipefail

DOMAIN="${DOMAIN-earn.v2rei.surf}"
EMAIL="${EMAIL:-}"
FORCE_SSL="${FORCE_SSL:-0}"
WEBROOT=/var/www/earnapp-linker

log() { printf '\n==> %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root (use: sudo bash setup-ubuntu.sh)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log "Installing nginx and certbot"
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx curl ca-certificates

log "Writing the page to $WEBROOT"
mkdir -p "$WEBROOT"
cat > "$WEBROOT/index.html" <<'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>EarnApp Linker</title>
<style>
:root {
  --bg: #f3f5f4; --surface: #ffffff; --fg: #16221f; --muted: #5d6d68; --line: #d6dedb;
  --accent: #0b7a6b; --accent-fg: #ffffff; --done-bg: #e3efe9; --warn: #9a5b00;
  --font: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) {
  :root { --bg: #0f1816; --surface: #17231f; --fg: #e4efeb; --muted: #94a8a1; --line: #29403a;
          --accent: #3fc3ad; --accent-fg: #06201b; --done-bg: #173229; --warn: #e3a64a; color-scheme: dark; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font-family: var(--font); font-size: 15px; line-height: 1.6;
  padding: 24px max(16px, env(safe-area-inset-right, 0px)) 40px max(16px, env(safe-area-inset-left, 0px)); }
main { max-width: 580px; margin: 0 auto; display: flex; flex-direction: column; gap: 18px; }
h1 { font-size: 1.5rem; margin: 0; }
.lead { margin: 4px 0 0; color: var(--muted); }
label { font-weight: 600; display: block; margin-bottom: 6px; }
textarea { width: 100%; min-height: 130px; resize: vertical; font-family: var(--mono); font-size: 13px; line-height: 1.6;
  background: var(--surface); color: var(--fg); border: 1px solid var(--line); border-radius: 6px; padding: 10px 12px; }
textarea:focus-visible, a:focus-visible, button:focus-visible, input:focus-visible { outline: 3px solid var(--accent); outline-offset: 2px; }
.hint { color: var(--muted); font-size: 13px; margin: 6px 0 0; }
.row { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; flex-wrap: wrap; }
.count { font-weight: 600; font-variant-numeric: tabular-nums; }
.warn { color: var(--warn); font-size: 13px; }
.next { display: block; text-align: center; text-decoration: none; font-weight: 700; font-size: 1.05rem;
  background: var(--accent); color: var(--accent-fg); border-radius: 8px; padding: 14px 16px; }
.next[aria-disabled="true"] { background: var(--line); color: var(--muted); pointer-events: none; }
.bar { height: 6px; background: var(--line); border-radius: 3px; overflow: hidden; }
.bar > i { display: block; height: 100%; width: 0; background: var(--accent); transition: width .2s; }
.auto { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 12px 14px; display: flex; flex-direction: column; gap: 8px; }
.autorow { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.autorow label { margin: 0; font-weight: 400; }
.autorow input { width: 6em; font-family: var(--mono); background: var(--bg); color: var(--fg); border: 1px solid var(--line); border-radius: 6px; padding: 5px 8px; text-align: center; }
.timer { font-variant-numeric: tabular-nums; color: var(--muted); font-size: 13px; }
ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
li { display: flex; align-items: center; gap: 12px; background: var(--surface); border: 1px solid var(--line); border-radius: 6px; padding: 8px 12px; min-width: 0; }
li.done { background: var(--done-bg); }
.idx { font-variant-numeric: tabular-nums; color: var(--muted); width: 1.6em; }
.uid { flex: 1; min-width: 0; font-family: var(--mono); font-size: 12.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.open { font-size: 13px; color: var(--accent); font-weight: 600; text-decoration: none; white-space: nowrap; }
.tag { font-size: 12px; color: var(--muted); white-space: nowrap; }
.actions { display: flex; gap: 10px; flex-wrap: wrap; }
button { font-family: var(--font); font-size: 13px; background: transparent; color: var(--fg); border: 1px solid var(--line); border-radius: 6px; padding: 6px 12px; cursor: pointer; }
#auto { font-weight: 600; background: var(--surface); }
#auto.on { border-color: var(--accent); color: var(--accent); }
.empty { color: var(--muted); border: 1px dashed var(--line); border-radius: 6px; padding: 16px; text-align: center; }
.notes { color: var(--muted); font-size: 13px; border-top: 1px solid var(--line); padding-top: 14px; }
.notes p { margin: 0 0 6px; }
</style>
</head>
<body>
<main>
  <header>
    <h1>EarnApp Linker</h1>
    <p class="lead">Paste your EarnApp claim links or device IDs. The page opens them one at a time, so each device is linked to the EarnApp account this browser is signed in to.</p>
  </header>

  <section>
    <label for="input">Claim links or device IDs (one per line)</label>
    <textarea id="input" spellcheck="false" placeholder="https://earnapp.com/r/sdk-node-0123456789abcdef0123456789abcdef&#10;sdk-node-fedcba9876543210fedcba9876543210"></textarea>
    <p class="hint">Full links and bare sdk-node-... IDs both work. Duplicates are counted once. The list is remembered in this browser.</p>
  </section>

  <section class="row">
    <span class="count" id="count">Nothing pasted yet</span>
    <span class="warn" id="warn" hidden></span>
  </section>

  <section class="auto">
    <div class="autorow">
      <label for="interval">Seconds between devices</label>
      <input id="interval" type="number" min="5" max="3600" value="120" inputmode="numeric">
      <button type="button" id="auto">Start auto mode</button>
      <span class="timer" id="timer"></span>
    </div>
    <p class="hint" id="automsg">Auto mode opens the next device every 120 seconds in one reused tab. Keep this page open and the screen awake until it finishes.</p>
  </section>

  <a class="next" id="next" href="#" target="_blank" rel="noopener noreferrer" aria-disabled="true">No links to open</a>
  <div class="bar" aria-hidden="true"><i id="fill"></i></div>

  <ul id="list"></ul>
  <div class="empty" id="empty">Pasted devices will be listed here.</div>

  <div class="actions">
    <button type="button" id="reset">Mark all as not opened</button>
    <button type="button" id="clear">Clear list</button>
  </div>

  <section class="notes">
    <p>Sign in to earnapp.com in this same browser first. A claim link links the device to whichever account is signed in.</p>
    <p>If EarnApp says "device not found", that device's container has not started yet. Wait a few minutes and open its link again from the list.</p>
    <p>Pop-up blockers may stop auto mode after the first tab. If that happens, allow pop-ups for this site, or use the big button to open devices one by one.</p>
  </section>
</main>

<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var input = $('input'), list = $('list'), empty = $('empty'), count = $('count'), warn = $('warn');
  var next = $('next'), fill = $('fill'), autoBtn = $('auto'), autoMsg = $('automsg'), timerEl = $('timer');
  var items = [], done = {}, timer = null, tick = null, remaining = 0;

  function load() { try { return JSON.parse(localStorage.getItem('earnapp-linker') || '{}'); } catch (e) { return {}; } }
  function save() { try { localStorage.setItem('earnapp-linker', JSON.stringify({ text: input.value, done: done, interval: $('interval').value })); } catch (e) {} }
  function short(id) { return id.slice(0, 13) + '...' + id.slice(-4); }

  function parse() {
    var text = input.value;
    var found = text.match(/sdk-node-[0-9a-f]{32}/gi) || [];
    var seen = {}, out = [];
    found.forEach(function (m) {
      var id = m.toLowerCase();
      if (!seen[id]) { seen[id] = 1; out.push({ id: id, url: 'https://earnapp.com/r/' + id }); }
    });
    items = out;
    var lines = text.split(/\n+/).map(function (s) { return s.trim(); }).filter(Boolean);
    var bad = lines.filter(function (l) { return !/sdk-node-[0-9a-f]{32}/i.test(l); }).length;
    warn.hidden = bad === 0;
    warn.textContent = bad ? bad + ' line(s) had no valid ID and were ignored' : '';
    render();
    save();
  }

  function firstPending() {
    for (var i = 0; i < items.length; i++) if (!done[items[i].id]) return items[i];
    return null;
  }

  function render() {
    list.innerHTML = '';
    empty.hidden = items.length > 0;
    var doneCount = 0;
    items.forEach(function (it, i) {
      var isDone = !!done[it.id];
      if (isDone) doneCount++;
      var li = document.createElement('li');
      if (isDone) li.className = 'done';
      var idx = document.createElement('span'); idx.className = 'idx'; idx.textContent = i + 1;
      var uid = document.createElement('span'); uid.className = 'uid'; uid.textContent = short(it.id); uid.title = it.id;
      var tag = document.createElement('span'); tag.className = 'tag'; tag.textContent = isDone ? 'opened' : '';
      var a = document.createElement('a'); a.className = 'open'; a.href = it.url; a.target = '_blank'; a.rel = 'noopener noreferrer';
      a.textContent = isDone ? 'Open again' : 'Open';
      a.addEventListener('click', function () { setTimeout(function () { done[it.id] = true; render(); save(); }, 0); });
      li.appendChild(idx); li.appendChild(uid); li.appendChild(tag); li.appendChild(a);
      list.appendChild(li);
    });
    var total = items.length;
    count.textContent = total ? doneCount + ' of ' + total + ' devices opened' : 'Nothing pasted yet';
    fill.style.width = total ? (doneCount / total * 100) + '%' : '0';
    var p = firstPending();
    if (p) {
      next.href = p.url; next.setAttribute('aria-disabled', 'false');
      next.textContent = 'Open device ' + (items.indexOf(p) + 1) + ' of ' + total;
    } else {
      next.href = '#'; next.setAttribute('aria-disabled', 'true');
      next.textContent = total ? 'All devices opened' : 'No links to open';
    }
  }

  next.addEventListener('click', function (e) {
    var p = firstPending();
    if (!p) { e.preventDefault(); return; }
    setTimeout(function () { done[p.id] = true; render(); save(); }, 0);
  });

  function stopAuto(msg) {
    if (timer) { clearInterval(timer); timer = null; }
    if (tick) { clearInterval(tick); tick = null; }
    timerEl.textContent = '';
    autoBtn.textContent = 'Start auto mode';
    autoBtn.className = '';
    if (msg) autoMsg.textContent = msg;
  }

  function openNext() {
    var p = firstPending();
    if (!p) { stopAuto('All devices opened.'); return false; }
    var w = null;
    try { w = window.open(p.url, 'earnapp-linker-tab'); } catch (e) { w = null; }
    if (!w) {
      stopAuto('The browser blocked the new tab. Allow pop-ups for this site, or use the big button to open devices one by one.');
      return false;
    }
    done[p.id] = true;
    render(); save();
    var left = items.filter(function (x) { return !done[x.id]; }).length;
    autoMsg.textContent = left ? 'Device ' + (items.indexOf(p) + 1) + ' opened. ' + left + ' to go.' : 'All devices opened.';
    if (!left) stopAuto();
    return true;
  }

  autoBtn.addEventListener('click', function () {
    if (timer) { stopAuto('Stopped.'); return; }
    if (!firstPending()) { autoMsg.textContent = 'Paste some links first.'; return; }
    var sec = Math.max(5, Math.min(3600, parseInt($('interval').value, 10) || 120));
    if (!openNext()) return;
    if (!firstPending()) return;
    autoBtn.textContent = 'Stop';
    autoBtn.className = 'on';
    remaining = sec;
    timerEl.textContent = 'next in ' + remaining + 's';
    timer = setInterval(function () { remaining = sec; openNext(); }, sec * 1000);
    tick = setInterval(function () { remaining = Math.max(0, remaining - 1); if (timer) timerEl.textContent = 'next in ' + remaining + 's'; }, 1000);
  });

  $('reset').addEventListener('click', function () { done = {}; render(); save(); });
  $('clear').addEventListener('click', function () { stopAuto(); input.value = ''; done = {}; parse(); });
  $('interval').addEventListener('change', save);
  input.addEventListener('input', parse);

  var s = load();
  if (s.text) input.value = s.text;
  if (s.done) done = s.done;
  if (s.interval) $('interval').value = s.interval;
  parse();
})();
</script>
</body>
</html>
HTMLEOF
chmod -R a+rX "$WEBROOT"

log "Configuring nginx"
if [ -n "$DOMAIN" ]; then
  SERVER_NAME="$DOMAIN"
  LISTEN_OPTS=""
else
  SERVER_NAME="_"
  LISTEN_OPTS=" default_server"
fi
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/earnapp-linker <<NGINXEOF
server {
    listen 80${LISTEN_OPTS};
    listen [::]:80${LISTEN_OPTS};
    server_name ${SERVER_NAME};
    root ${WEBROOT};
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINXEOF
ln -sf /etc/nginx/sites-available/earnapp-linker /etc/nginx/sites-enabled/earnapp-linker
nginx -t
systemctl enable nginx
systemctl restart nginx

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Opening ports 80 and 443 in ufw"
  ufw allow 80/tcp
  ufw allow 443/tcp
fi

PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"

if [ -z "$DOMAIN" ]; then
  log "Done"
  echo "Open: http://${PUBLIC_IP:-YOUR_SERVER_IP}"
  exit 0
fi

DNS_IP="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"

if [ "$FORCE_SSL" = "1" ] || { [ -n "$PUBLIC_IP" ] && [ "$DNS_IP" = "$PUBLIC_IP" ]; }; then
  log "Requesting a free HTTPS certificate for $DOMAIN"
  CERTBOT_ARGS=(--nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect)
  if [ -n "$EMAIL" ]; then
    CERTBOT_ARGS+=(-m "$EMAIL")
  else
    CERTBOT_ARGS+=(--register-unsafely-without-email)
  fi
  if certbot "${CERTBOT_ARGS[@]}"; then
    log "Done"
    echo "Open: https://$DOMAIN"
    exit 0
  fi
  echo "Certbot failed. Check the messages above." >&2
fi

log "Page is live over HTTP, but HTTPS is not set up yet"
echo "Open now: http://${PUBLIC_IP:-YOUR_SERVER_IP}"
echo
echo "To use https://$DOMAIN :"
echo "  1. In your DNS settings add an A record: name '${DOMAIN%%.*}' -> ${PUBLIC_IP:-YOUR_SERVER_IP}"
echo "     (Cloudflare: set the cloud to grey, 'DNS only')"
echo "  2. Wait a minute, then run this script again:  bash setup-ubuntu.sh"
echo "DNS currently resolves $DOMAIN to: ${DNS_IP:-nothing}"
