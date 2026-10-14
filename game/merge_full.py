# Merges full_raw.json (Knesset data) with label/topic drafts (batches/out*.json) and the curated
# prototype votes (../game_data.json) into game_data_full.json, the data the game is built with.
# Drafts are marked draft:true until Lior approves them; "ex" comes only from official texts.
import json, os, re
H = os.path.dirname(os.path.abspath(__file__))
raw = json.load(open(os.path.join(H, 'full_raw.json')))
proto = json.load(open(os.path.join(H, '..', 'game_data.json')))
pv = {v['bill']: v for v in proto['votes']}
dr = {x['bill']: x for i in range(5) for x in json.load(open(os.path.join(H, 'batches', f'out{i}.json')))}
# explanation lines written from the official דברי הסבר (docs_text/), with label/topic fixes made while reading them
for i in range(6):
    f = os.path.join(H, 'batches', f'ex_out{i}.json')
    if not os.path.exists(f): continue
    for x in json.load(open(f)):
        d = dr.setdefault(x['bill'], {})
        if x.get('ex'): d['ex'] = x['ex']
        if x.get('label'): d['label'] = x['label']
        if x.get('topic'): d['topic'] = x['topic']
# the bills added by the 40-voter rule (Lior 14.10): label/topic drafts, and explanation lines once the official texts are read
for f in ('drafts.json', 'ex.json'):
    f = os.path.join(H, 'new40', f)
    if os.path.exists(f):
        for x in json.load(open(f)): dr.setdefault(x['bill'], {}).update({k: v for k, v in x.items() if k != 'bill' and v})
SHORT = {'התאחדות הספרדים שומרי תורה תנועתו של מרן הרב עובדיה יוסף זצ"ל': 'ש"ס',
         "הציונות הדתית בראשות בצלאל סמוטריץ'": 'הציונות הדתית', 'עוצמה יהודית בראשות איתמר בן גביר': 'עוצמה יהודית',
         'נעם - בראשות אבי מעוז': 'נעם', 'כחול לבן - המחנה הממלכתי': 'כחול לבן', 'חה"כ עידן רול': 'סיעת יחיד'}
votes = []
for v in raw['votes']:
    p = pv.get(v['bill']); d = dr.get(v['bill'], {})
    o = {'id': v['id'], 'bill': v['bill'], 'date': v['date']}
    if p: o.update(topic=p['topic'], label=p['label'], key=p['key']); p.get('ex') and o.update(ex=p['ex'])
    else:
        o.update(topic=d.get('topic', 'אחר'), label=d.get('label') or re.sub(r',?\s*התש\S+$', '', v['name']), key=False, draft=True)
        if d.get('ex'): o['ex'] = d['ex']
        if d.get('self'): o['self'] = True
    votes.append(o)
# corrections of the rows the second check flagged (review/fixes.json); fixed:true marks them for one more look before launch
fx = os.path.join(H, 'review', 'fixes.json')
if os.path.exists(fx):
    F = {x['bill']: x for x in json.load(open(fx))}
    for o in votes:
        x = F.get(o['bill'])
        if not x: continue
        o['label'], o['topic'], o['fixed'] = x['label'], x['topic'], True
        if x.get('ex'): o['ex'] = x['ex']
        else: o.pop('ex', None)
        if x.get('self'): o['self'] = True
        else: o.pop('self', None)
mks = [dict(m, faction=SHORT.get(m['faction'].strip(), m['faction'].strip())) for m in raw['mks']]
out = {'votes': votes, 'mks': mks, 'headline': proto['headline']}
json.dump(out, open(os.path.join(H, 'game_data_full.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(votes), 'votes', sum('ex' in v for v in votes), 'with ex', len(mks), 'mks')
