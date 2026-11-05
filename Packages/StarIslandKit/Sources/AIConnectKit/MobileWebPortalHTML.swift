import Foundation

/// 内嵌免装 App 手机扫码互联响应式深色毛玻璃中文 Web 控制台
public enum MobileWebPortalHTML {
    public static func render(hostName: String) -> String {
        let escapedHost = escapeHTML(hostName)
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
          <meta name="apple-mobile-web-app-capable" content="yes" />
          <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
          <meta name="apple-mobile-web-app-title" content="星岛互联" />
          <title>星岛互联 · \(escapedHost)</title>
          <style>
            :root {
              color-scheme: dark;
              --bg: #070b14;
              --card: rgba(22, 29, 45, 0.76);
              --border: rgba(255, 255, 255, 0.11);
              --accent: #4f8cff;
              --accent-2: #7b61ff;
              --text: #f3f6fc;
              --muted: #93a1b8;
              --ok: #30d158;
              --danger: #ff5b6b;
            }
            * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
            body {
              margin: 0;
              min-height: 100vh;
              font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
              background:
                radial-gradient(circle at 15% 10%, rgba(79, 140, 255, 0.25), transparent 42%),
                radial-gradient(circle at 85% 15%, rgba(123, 97, 255, 0.22), transparent 40%),
                var(--bg);
              color: var(--text);
              padding: 18px 16px 42px;
            }
            .wrap { max-width: 520px; margin: 0 auto; }
            .hero {
              display: flex; align-items: center; justify-content: space-between;
              margin-bottom: 16px;
            }
            .brand { display: flex; align-items: center; gap: 10px; }
            .orb {
              width: 36px; height: 36px; border-radius: 11px;
              background: linear-gradient(135deg, var(--accent), var(--accent-2));
              display: grid; place-items: center; font-weight: 700; font-size: 17px;
              box-shadow: 0 8px 20px rgba(79, 140, 255, 0.35);
            }
            .title { font-size: 18px; font-weight: 700; margin: 0; }
            .sub { font-size: 12px; color: var(--muted); margin: 2px 0 0; }
            .badge {
              font-size: 12px; padding: 5px 10px; border-radius: 999px;
              background: rgba(48, 209, 88, 0.16); color: var(--ok);
              border: 1px solid rgba(48, 209, 88, 0.32);
            }
            .card {
              background: var(--card);
              backdrop-filter: blur(22px);
              -webkit-backdrop-filter: blur(22px);
              border: 1px solid var(--border);
              border-radius: 20px;
              padding: 16px;
              margin-bottom: 14px;
              box-shadow: 0 12px 32px rgba(0, 0, 0, 0.28);
            }
            .card h2 {
              margin: 0 0 6px; font-size: 15px; font-weight: 600;
              display: flex; align-items: center; justify-content: space-between;
            }
            .hint { margin: 0 0 12px; font-size: 12px; color: var(--muted); }
            input[type="text"], input[type="tel"], textarea {
              width: 100%; border-radius: 12px;
              border: 1px solid var(--border);
              background: rgba(8, 12, 22, 0.65);
              color: var(--text);
              padding: 11px 12px; font-size: 15px; outline: none;
            }
            textarea { min-height: 84px; resize: vertical; font-family: inherit; }
            .pin-input {
              text-align: center; font-size: 24px; letter-spacing: 8px; font-weight: 700;
            }
            .row { display: flex; gap: 10px; margin-top: 10px; flex-wrap: wrap; }
            button, .file-btn {
              flex: 1; min-width: 96px; border: none; border-radius: 12px;
              padding: 11px 14px; font-size: 14px; font-weight: 600;
              color: #fff; cursor: pointer; text-align: center;
              background: linear-gradient(135deg, var(--accent), var(--accent-2));
              transition: opacity 0.15s ease, transform 0.1s ease;
            }
            button.secondary, .file-btn.secondary {
              background: rgba(255, 255, 255, 0.08);
              border: 1px solid var(--border);
              color: var(--text);
            }
            button:active, .file-btn:active { transform: scale(0.98); opacity: 0.9; }
            .hidden { display: none !important; }
            .progress-box {
              margin-top: 10px; height: 7px; border-radius: 99px;
              background: rgba(255, 255, 255, 0.08); overflow: hidden;
            }
            .progress-bar {
              height: 100%; width: 0%;
              background: linear-gradient(90deg, var(--accent), var(--ok));
              transition: width 0.15s ease;
            }
            .file-list { list-style: none; padding: 0; margin: 8px 0 0; }
            .file-item {
              display: flex; align-items: center; justify-content: space-between;
              gap: 10px; padding: 10px 0;
              border-bottom: 1px solid rgba(255, 255, 255, 0.07);
            }
            .file-item:last-child { border-bottom: none; }
            .file-meta { overflow: hidden; }
            .file-name {
              font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
            }
            .file-size { font-size: 11px; color: var(--muted); margin-top: 2px; }
            .dl-btn { flex: 0 0 auto; min-width: 72px; padding: 7px 12px; font-size: 12px; }
            .media-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; }
            .media-grid button { min-width: 0; padding: 12px 0; font-size: 15px; }
            .toast {
              position: fixed; left: 50%; bottom: 20px; transform: translateX(-50%);
              background: rgba(18, 24, 38, 0.94); border: 1px solid var(--border);
              padding: 9px 16px; border-radius: 999px; font-size: 13px;
              box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4); z-index: 99;
            }
          </style>
        </head>
        <body>
          <div class="wrap">
            <div class="hero">
              <div class="brand">
                <div class="orb">星</div>
                <div>
                  <p class="title">星岛跨端互联</p>
                  <p class="sub">目标主机：\(escapedHost)</p>
                </div>
              </div>
              <span id="connBadge" class="badge hidden">已安全配对</span>
            </div>

            <div id="pairCard" class="card">
              <h2>输入 6 位安全配对码</h2>
              <p class="hint">请查看 Mac 顶部灵动岛「手机互联」面板上的 6 位动态配对码或直接重新扫码。</p>
              <input id="pinInput" class="pin-input" type="tel" maxlength="6" placeholder="000000" autocomplete="one-time-code" />
              <div class="row">
                <button onclick="submitPair()">立即连接 Mac</button>
              </div>
            </div>

            <div id="portalPanel" class="hidden">
              <div class="card">
                <h2>手机拍照 / 文件快传到 Mac</h2>
                <p class="hint">直传至 Mac「下载」文件夹并在灵动岛实时提醒，支持多选照片、视频与任意文档。</p>
                <input id="cameraInput" class="hidden" type="file" accept="image/*" capture="environment" onchange="uploadSelected(this.files)" />
                <input id="fileInput" class="hidden" type="file" multiple onchange="uploadSelected(this.files)" />
                <div class="row">
                  <label class="file-btn" for="cameraInput">拍照直传</label>
                  <label class="file-btn secondary" for="fileInput">选择相册 / 文件</label>
                </div>
                <div id="uploadBox" class="progress-box hidden">
                  <div id="uploadBar" class="progress-bar"></div>
                </div>
                <p id="uploadStatus" class="hint" style="margin-top:8px;margin-bottom:0;"></p>
              </div>

              <div class="card">
                <h2>
                  <span>Mac 共享文件列表</span>
                  <button class="secondary dl-btn" onclick="loadSharedFiles()">刷新</button>
                </h2>
                <p class="hint">在 Mac 灵动岛「手机互联」中拖入的文件可直接一键下载到手机。</p>
                <ul id="sharedList" class="file-list"></ul>
              </div>

              <div class="card">
                <h2>双向剪贴板同步</h2>
                <textarea id="clipText" placeholder="在此输入或粘贴文本，一键同步至 Mac 剪贴板…"></textarea>
                <div class="row">
                  <button onclick="pushClipboard()">发送到 Mac</button>
                  <button class="secondary" onclick="pullClipboard()">读取 Mac 剪贴板</button>
                </div>
              </div>

              <div class="card">
                <h2>遥控 Mac 媒体、音量与锁屏</h2>
                <p class="hint">远程控制 Mac 当前正在播放的音乐视频、系统音量或立即锁屏。</p>
                <div class="media-grid">
                  <button class="secondary" onclick="sendMedia('volumeDown')">音量-</button>
                  <button class="secondary" onclick="sendMedia('previous')">上一曲</button>
                  <button onclick="sendMedia('playPause')">播放/暂停</button>
                  <button class="secondary" onclick="sendMedia('next')">下一曲</button>
                  <button class="secondary" onclick="sendMedia('volumeUp')">音量+</button>
                  <button class="secondary" onclick="sendMedia('lockScreen')">锁定屏幕</button>
                </div>
              </div>
            </div>
          </div>

          <div id="toast" class="toast hidden"></div>

          <script>
            let token = sessionStorage.getItem('starisland_token') || '';

            function showToast(msg) {
              const el = document.getElementById('toast');
              el.textContent = msg;
              el.classList.remove('hidden');
              clearTimeout(window.__toastTimer);
              window.__toastTimer = setTimeout(() => el.classList.add('hidden'), 2400);
            }

            function enterPortal() {
              document.getElementById('pairCard').classList.add('hidden');
              document.getElementById('portalPanel').classList.remove('hidden');
              document.getElementById('connBadge').classList.remove('hidden');
              loadSharedFiles();
            }

            function requireReauth(msg) {
              token = '';
              sessionStorage.removeItem('starisland_token');
              document.getElementById('portalPanel').classList.add('hidden');
              document.getElementById('connBadge').classList.add('hidden');
              document.getElementById('pairCard').classList.remove('hidden');
              if (msg) showToast(msg);
            }

            async function apiFetch(path, options = {}) {
              const headers = Object.assign({}, options.headers || {}, {
                'Authorization': 'Bearer ' + token
              });
              const res = await fetch(path, Object.assign({}, options, { headers }));
              if (res.status === 401) {
                requireReauth('配对会话已失效，请重新输入 6 位配对码');
                throw new Error('unauthorized');
              }
              return res;
            }

            async function submitPair(pinOverride) {
              const pin = (pinOverride || document.getElementById('pinInput').value || '').trim();
              if (!/^\\d{6}$/.test(pin)) {
                showToast('请输入 6 位纯数字配对码');
                return;
              }
              const ua = navigator.userAgent || '';
              let deviceName = '手机浏览器';
              if (/iPhone/i.test(ua)) deviceName = 'iPhone';
              else if (/iPad/i.test(ua)) deviceName = 'iPad';
              else if (/Android/i.test(ua)) deviceName = 'Android 手机';

              try {
                const res = await fetch('/api/pair', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ pin, deviceName })
                });
                if (!res.ok) {
                  showToast('配对码错误或已刷新，请核对灵动岛显示的数字');
                  return;
                }
                const data = await res.json();
                token = data.token;
                sessionStorage.setItem('starisland_token', token);
                if (location.search) history.replaceState(null, '', '/');
                showToast('已与 Mac 建立安全连接');
                enterPortal();
              } catch (e) {
                showToast('网络连接异常，请确认与 Mac 处于同一局域网');
              }
            }

            function formatBytes(bytes) {
              if (bytes < 1024) return bytes + ' B';
              if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
              return (bytes / 1048576).toFixed(2) + ' MB';
            }

            async function uploadSelected(fileList) {
              if (!fileList || !fileList.length) return;
              const box = document.getElementById('uploadBox');
              const bar = document.getElementById('uploadBar');
              const status = document.getElementById('uploadStatus');
              box.classList.remove('hidden');

              for (let i = 0; i < fileList.length; i++) {
                const file = fileList[i];
                status.textContent = `正在上传 (${i + 1}/${fileList.length})：${file.name}`;
                bar.style.width = '0%';
                const ok = await new Promise((resolve) => {
                  const xhr = new XMLHttpRequest();
                  xhr.open('POST', '/api/upload', true);
                  xhr.setRequestHeader('Authorization', 'Bearer ' + token);
                  xhr.setRequestHeader('X-File-Name', encodeURIComponent(file.name));
                  xhr.upload.onprogress = (ev) => {
                    if (ev.lengthComputable) {
                      bar.style.width = Math.round((ev.loaded / ev.total) * 100) + '%';
                    }
                  };
                  xhr.onload = () => {
                    if (xhr.status === 401) {
                      requireReauth('会话已过期，请重新扫码');
                      resolve(false);
                    } else {
                      resolve(xhr.status >= 200 && xhr.status < 300);
                    }
                  };
                  xhr.onerror = () => resolve(false);
                  xhr.send(file);
                });
                if (!ok) {
                  status.textContent = '上传中断，请重试';
                  return;
                }
              }
              bar.style.width = '100%';
              status.textContent = `已完成 ${fileList.length} 个文件快传，已保存至 Mac 下载目录`;
              showToast('文件已快传至 Mac');
            }

            async function loadSharedFiles() {
              try {
                const res = await apiFetch('/api/files');
                const data = await res.json();
                const list = document.getElementById('sharedList');
                list.innerHTML = '';
                if (!data.files || data.files.length === 0) {
                  list.innerHTML = '<li class="hint" style="padding:6px 0;">Mac 端暂未添加共享文件</li>';
                  return;
                }
                for (const f of data.files) {
                  const li = document.createElement('li');
                  li.className = 'file-item';
                  const meta = document.createElement('div');
                  meta.className = 'file-meta';
                  const nameEl = document.createElement('div');
                  nameEl.className = 'file-name';
                  nameEl.textContent = f.name;
                  const sizeEl = document.createElement('div');
                  sizeEl.className = 'file-size';
                  sizeEl.textContent = formatBytes(f.sizeBytes || 0);
                  meta.appendChild(nameEl);
                  meta.appendChild(sizeEl);

                  const btn = document.createElement('button');
                  btn.className = 'dl-btn';
                  btn.textContent = '下载';
                  btn.onclick = () => downloadSharedFile(f.id, f.name);
                  li.appendChild(meta);
                  li.appendChild(btn);
                  list.appendChild(li);
                }
              } catch (_) {}
            }

            async function downloadSharedFile(id, name) {
              try {
                showToast('正在准备下载…');
                const res = await apiFetch('/api/files/' + encodeURIComponent(id));
                if (!res.ok) {
                  showToast('文件不存在或已被移除');
                  return;
                }
                const blob = await res.blob();
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = name || 'download';
                document.body.appendChild(a);
                a.click();
                a.remove();
                setTimeout(() => URL.revokeObjectURL(url), 10000);
              } catch (_) {}
            }

            async function pushClipboard() {
              const text = document.getElementById('clipText').value || '';
              if (!text.trim()) {
                showToast('请先输入要发送的剪贴板文本');
                return;
              }
              try {
                const res = await apiFetch('/api/clipboard', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ text })
                });
                if (res.ok) showToast('已同步到 Mac 剪贴板');
              } catch (_) {}
            }

            async function pullClipboard() {
              try {
                const res = await apiFetch('/api/clipboard');
                const data = await res.json();
                document.getElementById('clipText').value = data.text || '';
                if (data.text && navigator.clipboard && navigator.clipboard.writeText) {
                  navigator.clipboard.writeText(data.text).catch(() => {});
                }
                showToast(data.text ? '已读取 Mac 剪贴板' : 'Mac 剪贴板当前为空');
              } catch (_) {}
            }

            async function sendMedia(command) {
              try {
                const res = await apiFetch('/api/media', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ command })
                });
                if (res.ok) showToast('指令已发送');
              } catch (_) {}
            }

            (async function bootstrap() {
              const params = new URLSearchParams(location.search);
              const urlPIN = params.get('pin');
              if (urlPIN && /^\\d{6}$/.test(urlPIN)) {
                document.getElementById('pinInput').value = urlPIN;
                await submitPair(urlPIN);
                return;
              }
              if (token) {
                try {
                  const res = await apiFetch('/api/status');
                  if (res.ok) enterPortal();
                } catch (_) {}
              }
            })();
          </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
