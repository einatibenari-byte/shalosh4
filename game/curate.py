# Curation layer for the shorter game (Lior, 12.10.2026). Run after merge_full.py; safe to run twice.
# Adds to game_data_full.json:
#   votes[].p    rank of the vote inside its topic among the ~5 picked ones (missing = not picked, shown under "עוד")
#   votes[].topic  "עובדים" folded into "כלכלה ויוקר המחיה"; the disengagement vote moves to "ביטחון וטרור"
#   mks[].s      'c' coalition / 'o' opposition, by the MK's last faction (static; Lior to verify)
#   mks[].fam    order among the well-known MKs listed first in the picker
#   fac[]        factions as players: v = the majority of the members who voted on that day (F/A/B),
#                'S' tie, 'N' no member voted, '-' the faction did not exist yet; n = "for-against-abstain" counts
# Faction members by date come from KNS_PersonToPosition; individual votes from KNS_PlenumVoteResult
# (vote_results_607.json = [vote id, PersonID, result] for the 607 game votes, all MKs, not only the 139 in the game).
import csv, json, os, collections
H = os.path.dirname(os.path.abspath(__file__)); P = os.path.join(H, 'game_data_full.json')
D = json.load(open(P))
PICKS = {'משפט ושלטון החוק': [39785, 37885, 41283, 44612, 46015], 'ממשל ובחירות': [42296, 38407, 38567, 37689, 44580],
         'גיוס ושירות': [46670, 41147, 44785, 42689, 44572], 'תקציב, מסים וקצבאות': [40722, 42759, 42577, 42651, 44554],
         'ביטחון וטרור': [45858, 41336, 38256, 43103, 42820, 38260], 'קצבאות ורווחה': [42149, 44173, 44850, 44664, 38667],
         'חינוך וילדים': [42381, 39288, 41237, 39319, 46004], 'בריאות': [46152, 43241, 39403, 39284, 46364],
         'דת ומדינה': [44754, 39317, 38310, 46248, 45441], 'נשים ומשפחה': [39630, 42708, 41276, 38316, 44820],
         'כלכלה ויוקר המחיה': [44107, 39629, 38723, 40440, 44224, 41130, 44158, 45838, 42911, 44104],
         'תקשורת': [40884, 42251, 39431, 46611, 42910], 'דיור': [39313, 39323, 45105, 43255, 41006],
         'סביבה, תחבורה ותשתיות': [40922, 39626, 44635, 44604, 38687]}
MOVE = {38260: 'ביטחון וטרור'}
for v in D['votes']:
    if v['topic'] == 'עובדים': v['topic'] = 'כלכלה ויוקר המחיה'
    v['topic'] = MOVE.get(v['id'], v['topic']); v.pop('p', None)
rank = {i: k + 1 for ids in PICKS.values() for k, i in enumerate(ids)}
for v in D['votes']:
    if v['id'] in rank: assert v['topic'] in PICKS and v['id'] in PICKS[v['topic']], v; v['p'] = rank[v['id']]
assert sum('p' in v for v in D['votes']) == sum(map(len, PICKS.values()))

COAL = {'הליכוד', 'ש"ס', 'יהדות התורה', 'הציונות הדתית', 'עוצמה יהודית', 'נעם', 'הימין הממלכתי'}
FAM = ('בנימין נתניהו,איתמר בן גביר,יריב לוין,ישראל כץ,אריה מכלוף דרעי,משה גפני,יצחק גולדקנופ,טלי גוטליב,שלמה קרעי,מאי גולן,'
       'ניסים ואטורי,אבי מעוז,אורית מלכה סטרוק,שמחה רוטמן,גדעון סער,דוד ביטן,יולי יואל אדלשטיין,גלית דיסטל אטבריאן,ניר ברקת,'
       'אמיר אוחנה,יואב גלנט,עמיחי אליהו,צביקה פוגל,אופיר כץ,דוד אמסלם,יאיר לפיד,בנימין גנץ,אביגדור ליברמן,גדי איזנקוט,מרב מיכאלי,'
       'גלעד קריב,נעמה לזימי,איימן עודה,אחמד טיבי,מנסור עבאס,עופר כסיף,חילי טרופר,מירב בן ארי,קארין אלהרר,מירב כהן,יוליה מלינובסקי,'
       'עודד פורר,מתן כהנא,פנינה תמנו,עידן רול,אורנה ברביבאי').split(',')
names = {m['name'] for m in D['mks']}; assert all(n in names for n in FAM), [n for n in FAM if n not in names]
for m in D['mks']:
    m['s'] = 'c' if m['faction'] in COAL else 'o'; m.pop('fam', None)
    if m['name'] in FAM: m['fam'] = FAM.index(m['name'])

# factions (Knesset FactionIDs; the joint-list days and the National Unity rename are folded into one line each)
FAC = [('הליכוד', 'c', ['1096']), ('ש"ס', 'c', ['1095']), ('יהדות התורה', 'c', ['1101']), ('הציונות הדתית', 'c', ['1105', '1097']),
       ('עוצמה יהודית', 'c', ['1106']), ('הימין הממלכתי', 'c', ['1108']), ('יש עתיד', 'o', ['1102']),
       ('כחול לבן – המחנה הממלכתי', 'o', ['1098', '1110']), ('ישראל ביתנו', 'o', ['1104']), ('העבודה', 'o', ['1100']),
       ('חד"ש-תע"ל', 'o', ['1103']), ('רע"ם', 'o', ['1099'])]
spans = collections.defaultdict(list)   # FactionID -> [(PersonID, start, end)]
for r in csv.DictReader(open(os.path.join(H, 'kns_persontoposition.csv'), encoding='utf-8')):
    if r['KnessetNum'] == '25' and r['FactionID']:
        spans[r['FactionID']].append((int(r['PersonID']), r['StartDate'][:10], (r['FinishDate'] or '9999')[:10]))
res = collections.defaultdict(dict)
for vid, pid, d in json.load(open(os.path.join(H, 'vote_results_607.json'))): res[vid][pid] = {'בעד': 'F', 'נגד': 'A', 'נמנע': 'B'}.get(d)
D['fac'] = []
for k, (name, side, fids) in enumerate(FAC):
    v = ''; n = []
    for x in D['votes']:
        d = x['date']; members = {p for f in fids for p, a, b in spans[f] if a <= d < b or (a <= d and b == d)}
        if not members: v += '-'; n.append(''); continue
        c = collections.Counter(res[x['id']].get(p) for p in members); c.pop(None, None)
        n.append(f"{c['F']}-{c['A']}-{c['B']}")
        top = c.most_common()
        v += 'N' if not top else 'S' if len(top) > 1 and top[0][1] == top[1][1] else top[0][0]
    D['fac'].append({'id': f'f{k + 1}', 'name': name, 's': side, 'g': 'f', 'fac': True, 'v': v, 'n': n})
json.dump(D, open(P, 'w'), ensure_ascii=False, separators=(',', ':'))
print(sum('p' in v for v in D['votes']), 'picked;', len(D['fac']), 'factions;', sum('fam' in m for m in D['mks']), 'well-known MKs')
for f in D['fac']: print(f['name'], collections.Counter(f['v']))
