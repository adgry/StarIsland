//
//  StarIslandLANPortalHTML.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation

enum StarIslandLANPortalHTML {
    static func render(hostName: String) -> String {
        let escaped = hostName
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
          <title>星岛跨端互联 · \(escaped)</title>
          <style>
            :root { color-scheme: dark; --bg:#080c16; --card:rgba(24,31,48,0.82); --border:rgba(255,255,255,0.12); --accent:#4f8cff; --ok:#30d158; --text:#f4f7fd; --muted:#95a3ba; }
            * { box-sizing:border-box; }
            body { margin:0; font-family:-apple-system,"PingFang SC",sans-serif; background:radial-gradient(circle at 20% 10%,rgba(79,140,255,0.22),transparent 45%),var(--bg); color:var(--text); padding:18px 16px 40px; }
            .wrap { max-width:500px; margin:0 auto; }
            .card { background:var(--card); backdrop-filter:blur(20px); border:1px solid var(--border); border-radius:18px; padding:16px; margin-bottom:14px; }
            h1 { font-size:18px; margin:0 0 4px; }
            h2 { font-size:15px; margin:0 0 8px; display:flex; justify-content:space-between; align-items:center; }
            .sub { font-size:12px; color:var(--muted); margin:0 0 12px; }
            input, textarea { width:100%; border-radius:12px; border:1px solid var(--border); background:rgba(8,12,22,0.7); color:var(--text); padding:10px 12px; font-size:15px; }
            .pin { text-align:center; font-size:24px; letter-spacing:8px; font-weight:700; }
            textarea { min-height:80px; font-family:inherit; }
            .row { display:flex; gap:8px; margin-top:10px; flex-wrap:wrap; }
            button, .btn { flex:1; border:none; border-radius:12px; padding:10px 12px; font-size:14px; font-weight:600; color:#fff; background:linear-gradient(135deg,#4f8cff,#7b61ff); cursor:pointer; text-align:center; }
            button.sec, .btn.sec { background:rgba(255,255,255,0.08); border:1px solid var(--border); }
            .hidden { display:none!important; }
            .list { list-style:none; padding:0; margin:8px 0 0; }
            .item { display:flex; justify-content:space-between; align-items:center; padding:8px 0; border-bottom:1px solid rgba(255,255,255,0.07); }
            .toast { position:fixed; left:50%; bottom:18px; transform:translateX(-50%); background:#141c2e; border:1px solid var(--border); padding:8px 16px; border-radius:999px; font-size:13px; }
          </style>
        </head>
        <body>
          <div class="wrap">
            <div class="card">
              <h1>星岛跨端互联</h1>
              <p class="sub">主机：\(escaped)</p>
              <div id="pairBox">
                <p class="sub">请输入灵动岛或设置页显示的 6 位安全配对码：</p>
                <input id="pinInput" class="pin" type="tel" maxlength="6" placeholder="000000" />
                <div class="row"><button onclick="pair()">连接 Mac</button></div>
              </div>
              <div id="okBadge" class="hidden" style="color:var(--ok);font-size:13px;font-weight:600;">已建立局域网加密会话</div>
            </div>
            <div id="portal" class="hidden">
              <div class="card">
                <h2>手机快传文件到 Mac</h2>
                <p class="sub">文件直接存入 Mac「下载」目录。</p>
                <input id="fIn" class="hidden" type="file" multiple onchange="upload(this.files)" />
                <div class="row"><label class="btn" for="fIn">选择照片 / 文件上传</label></div>
                <p id="upMsg" class="sub" style="margin-top:8px;margin-bottom:0;"></p>
              </div>
              <div class="card">
                <h2><span>Mac 共享文件</span><button class="sec" style="flex:0 0 auto;padding:5px 10px;font-size:12px;" onclick="loadFiles()">刷新</button></h2>
                <ul id="fList" class="list"></ul>
              </div>
              <div class="card">
                <h2>双向剪贴板</h2>
                <textarea id="clip" placeholder="输入文本发送到 Mac，或读取 Mac 剪贴板…"></textarea>
                <div class="row">
                  <button onclick="pushClip()">发送到 Mac</button>
                  <button class="sec" onclick="pullClip()">读取 Mac</button>
                </div>
              </div>
              <div class="card">
                <h2>远程媒体与锁屏</h2>
                <div class="row">
                  <button class="sec" onclick="media('previous')">上一曲</button>
                  <button onclick="media('playPause')">播放/暂停</button>
                  <button class="sec" onclick="media('next')">下一曲</button>
                </div>
                <div class="row">
                  <button class="sec" onclick="media('volumeDown')">音量 -</button>
                  <button class="sec" onclick="media('volumeUp')">音量 +</button>
                  <button class="sec" onclick="media('lockScreen')">锁屏</button>
                </div>
              </div>
            </div>
          </div>
          <div id="toast" class="toast hidden"></div>
          <script>
            let token = sessionStorage.getItem('si_tok') || '';
            function toast(m){const e=document.getElementById('toast');e.textContent=m;e.classList.remove('hidden');clearTimeout(window._t);window._t=setTimeout(()=>e.classList.add('hidden'),2200);}
            function showPortal(){document.getElementById('pairBox').classList.add('hidden');document.getElementById('okBadge').classList.remove('hidden');document.getElementById('portal').classList.remove('hidden');loadFiles();}
            async function api(p,o={}){const h=Object.assign({},o.headers||{},{'Authorization':'Bearer '+token});const r=await fetch(p,Object.assign({},o,{headers:h}));if(r.status===401){token='';sessionStorage.removeItem('si_tok');location.reload();throw new Error('401');}return r;}
            async function pair(p){
              const pin=(p||document.getElementById('pinInput').value||'').trim();
              if(!/^\\d{6}$/.test(pin)){toast('请输入 6 位数字配对码');return;}
              const ua=navigator.userAgent||'';
              const dev=/iPhone/i.test(ua)?'iPhone':(/iPad/i.test(ua)?'iPad':(/Android/i.test(ua)?'Android':'移动浏览器'));
              const r=await fetch('/api/pair',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pin,deviceName:dev})});
              if(!r.ok){toast('配对码无效或已刷新');return;}
              const d=await r.json();token=d.token;sessionStorage.setItem('si_tok',token);if(location.search)history.replaceState(null,'','/');showPortal();
            }
            async function upload(files){
              if(!files||!files.length)return;
              const msg=document.getElementById('upMsg');
              for(let i=0;i<files.length;i++){
                msg.textContent='正在上传 '+files[i].name+'…';
                const r=await api('/api/upload',{method:'POST',headers:{'X-File-Name':encodeURIComponent(files[i].name)},body:files[i]});
                if(!r.ok){msg.textContent='上传失败';return;}
              }
              msg.textContent='已成功快传 '+files.length+' 个文件至 Mac 下载目录';toast('上传完成');
            }
            async function loadFiles(){
              const r=await api('/api/files');const d=await r.json();const ul=document.getElementById('fList');ul.innerHTML='';
              if(!d.files||!d.files.length){ul.innerHTML='<li class="sub">Mac 暂未拖入共享文件</li>';return;}
              for(const f of d.files){
                const li=document.createElement('li');li.className='item';
                const sp=document.createElement('span');sp.textContent=f.name;sp.style.fontSize='13px';
                const b=document.createElement('button');b.style.flex='0 0 auto';b.style.padding='6px 12px';b.textContent='下载';
                b.onclick=async()=>{const res=await api('/api/files/'+encodeURIComponent(f.id));if(!res.ok)return;const bl=await res.blob();const u=URL.createObjectURL(bl);const a=document.createElement('a');a.href=u;a.download=f.name;a.click();};
                li.appendChild(sp);li.appendChild(b);ul.appendChild(li);
              }
            }
            async function pushClip(){const t=document.getElementById('clip').value||'';if(!t)return;const r=await api('/api/clipboard',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:t})});if(r.ok)toast('已发送到 Mac 剪贴板');}
            async function pullClip(){const r=await api('/api/clipboard');const d=await r.json();document.getElementById('clip').value=d.text||'';toast('已读取 Mac 剪贴板');}
            async function media(c){const r=await api('/api/media',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({command:c})});if(r.ok)toast('指令已执行');}
            (async()=>{const u=new URLSearchParams(location.search).get('pin');if(u&&/^\\d{6}$/.test(u)){document.getElementById('pinInput').value=u;await pair(u);return;}if(token){try{const r=await api('/api/status');if(r.ok)showPortal();}catch(_){}}})();
          </script>
        </body>
        </html>
        """
    }
}
#endif
