"""从藏宝阁 H5「资产」页抓取游戏原图标。

用法：
    python tools/fetch_cbg_icons.py --url <藏宝阁角色页> --out assets/images/asset_icons_raw

原理：页面「资产」页签里每个条目的图标是 CSS background-image，
有的是 data:image/png;base64（内联），有的是 icon-asset-*.png 外链。
脚本用 Chrome DevTools Protocol 打开页面、点开「资产」，把每个图标
和同一行的文字（金币/勾玉/体力/…）配对后保存成 PNG。

依赖：pip install websockets
"""
import argparse
import base64
import json
import os
import re
import subprocess
import time
import urllib.parse
import urllib.request

from websockets.sync.client import connect

DEFAULT_CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

CLICK_ASSET_TAB = """
(() => {
  const tabs = [...document.querySelectorAll('*')]
    .filter(e => e.children.length === 0 && e.textContent.trim() === '资产');
  if (tabs.length) { tabs[0].click(); return 'ok'; }
  return 'not-found';
})()
"""

COLLECT_ICONS = r"""
(() => {
  const out = [];
  document.querySelectorAll('*').forEach(e => {
    const bg = getComputedStyle(e).backgroundImage;
    if (!bg || bg === 'none') return;
    if (!bg.includes('data:image/png') && !bg.includes('icon-asset')) return;
    let p = e, text = '';
    for (let i = 0; i < 4 && p; i++) {
      text = p.innerText || '';
      if (text.trim().length > 1) break;
      p = p.parentElement;
    }
    out.push({bg: bg, text: (text || '').replace(/\s+/g, ' ').trim().slice(0, 40)});
  });
  return JSON.stringify(out);
})()
"""


class Chrome:
    def __init__(self, chrome: str, port: int, profile: str):
        self.port = port
        os.makedirs(profile, exist_ok=True)
        self.proc = subprocess.Popen(
            [chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
             f"--remote-debugging-port={port}", f"--user-data-dir={profile}",
             "--window-size=1280,1000", "--hide-scrollbars", "about:blank"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def wait(self, timeout=20):
        for _ in range(timeout * 2):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{self.port}/json/version", timeout=1).read()
                return
            except Exception:
                time.sleep(0.5)
        raise RuntimeError("Chrome DevTools 没有就绪")

    def new_page(self, url: str) -> str:
        req = urllib.request.Request(
            f"http://127.0.0.1:{self.port}/json/new?{urllib.parse.quote(url, safe='')}",
            method="PUT")
        return json.load(urllib.request.urlopen(req, timeout=5))["webSocketDebuggerUrl"]

    def close(self):
        self.proc.terminate()


class Cdp:
    def __init__(self, ws_url: str):
        self.ws = connect(ws_url, max_size=80 * 1024 * 1024)
        self.seq = 0

    def send(self, method, params=None):
        self.seq += 1
        self.ws.send(json.dumps({"id": self.seq, "method": method, "params": params or {}}))
        return self.seq

    def wait(self, target_id, timeout=20):
        end = time.time() + timeout
        while time.time() < end:
            try:
                msg = json.loads(self.ws.recv(timeout=1))
            except TimeoutError:
                continue
            if msg.get("id") == target_id:
                return msg
        return None

    def eval(self, expression):
        res = self.wait(self.send("Runtime.evaluate", {"expression": expression, "returnByValue": True}))
        return res["result"]["result"].get("value") if res else None

    def close(self):
        self.ws.close()


def save_icon(bg: str, out_dir: str, index: int, text: str) -> str:
    m = re.search(r"url\(['\"]?(.*?)['\"]?\)", bg)
    if not m:
        return ""
    url = m.group(1)
    if url.startswith("data:image/png;base64,"):
        data = base64.b64decode(url.split(",", 1)[1])
    elif url.startswith("http"):
        data = urllib.request.urlopen(url, timeout=15).read()
    else:
        return ""
    safe = re.sub(r'[\\/:*?"<>|]', "_", text)[:24] or "unknown"
    path = os.path.join(out_dir, f"{index:03d}_{safe}.png")
    with open(path, "wb") as f:
        f.write(data)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="藏宝阁角色详情页 URL")
    parser.add_argument("--out", default="assets/images/asset_icons_raw")
    parser.add_argument("--chrome", default=os.environ.get("CHROME_PATH", DEFAULT_CHROME))
    parser.add_argument("--port", type=int, default=9231)
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    chrome = Chrome(args.chrome, args.port, os.path.join(os.environ.get("TEMP", "."), "oasx-cbg-icons"))
    chrome.wait()
    cdp = Cdp(chrome.new_page(args.url))
    try:
        cdp.send("Page.enable")
        cdp.send("Runtime.enable")
        time.sleep(10)
        print("click 资产:", cdp.eval(CLICK_ASSET_TAB))
        time.sleep(6)
        raw = cdp.eval(COLLECT_ICONS) or "[]"
        pairs = json.loads(raw)
        print("发现图标:", len(pairs))
        saved = []
        for i, item in enumerate(pairs):
            path = save_icon(item["bg"], args.out, i, item["text"])
            if path:
                saved.append((item["text"], path))
        for text, path in saved:
            print(f"  {text} -> {path}")
        print(f"共保存 {len(saved)} 个图标到 {args.out}")
    finally:
        cdp.close()
        chrome.close()


if __name__ == "__main__":
    main()
