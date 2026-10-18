"""Make the web version that GitHub Pages serves (web/), from index.html.

index.html is the whole program in one file (the apps and the download use it as it is).
For a site, the NMR shift tables (about 2 MB) are left out of the page: they go into
web/nmr-data.<hash>.json, which the page downloads on the first Predict, after asking,
and keeps in the browser. Run from the repository root:  python3 tools/make_web.py
"""
import hashlib, pathlib, re

root = pathlib.Path(__file__).resolve().parent.parent
page = (root / "index.html").read_text(encoding="utf-8")
m = re.search(r'<script type="application/json" id="nmrData">(.*?)</script>', page, re.S)
if not m:
    raise SystemExit("index.html has no NMR tables block")
data = m.group(1)
name = "nmr-data.%s.json" % hashlib.sha256(data.encode()).hexdigest()[:10]
mb = len(data.encode()) / 1e6
web = root / "web"
web.mkdir(exist_ok=True)
for old in web.glob("nmr-data.*.json"):
    old.unlink()
(web / name).write_text(data, encoding="utf-8")
meta = '<meta name="rd-nmr-pkg" content="%s" data-size="%.1f MB">' % (name, mb)
(web / "index.html").write_text(page[:m.start()] + meta + page[m.end():], encoding="utf-8")
print("web/index.html (%.1f MB) and web/%s (%.1f MB)" % ((m.start() + len(page) - m.end()) / 1e6, name, mb))
