"""Build the game page for the site: site/kise/index.html.

The game's sources are game/src/head.html (styles) and game/src/body.html (markup and script);
the data is game/data/game_data_full.json (bills and votes) and game/data/initiators.json.
Run from the repo root:  python3 game/build.py
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
G = ROOT / 'game'
URL = 'https://shalosh4.org/kise/'
TITLE = 'כסא או מעשה'
DESC = 'שני חברי כנסת על הבמה. הם עונים רק לפי מה שהצביעו בפועל במליאת הכנסת ה־25.'

head = (G / 'src/head.html').read_text()
body = (G / 'src/body.html').read_text()
data = json.loads((G / 'data/game_data_full.json').read_text())
init = json.loads((G / 'data/initiators.json').read_text())

meta = f'''<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="{DESC}">
<link rel="canonical" href="{URL}">
<meta property="og:type" content="website">
<meta property="og:locale" content="he_IL">
<meta property="og:site_name" content="שלוש ארבע">
<meta property="og:title" content="{TITLE}">
<meta property="og:description" content="{DESC}">
<meta property="og:url" content="{URL}">
<meta property="og:image" content="{URL}og.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
'''
# head.html holds <title>, fonts and <style>; the rest of the page is the body
page = (meta + head + '\n</head>\n<body>\n'
        + body.replace('__DATA__', json.dumps(data, ensure_ascii=False, separators=(',', ':')))
              .replace('__INIT__', json.dumps(init, separators=(',', ':')))
              .replace("'__BACKEND__'", "'site'")
        + '\n</body>\n</html>\n')
out = ROOT / 'site/kise/index.html'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(page)
print(out.relative_to(ROOT), round(len(page.encode()) / 1e6, 2), 'MB')

# the private stats page (/stats/) names bills by their game label
labels = {v['id']: v['label'] for v in data['votes']}
(ROOT / 'site/stats').mkdir(parents=True, exist_ok=True)
(ROOT / 'site/stats/labels.js').write_text('const LABELS = ' + json.dumps(labels, ensure_ascii=False, separators=(',', ':')) + ';\n')
