# Full Knesset-25 vote pool for "כסא או מעשה".
# Source: the Knesset's own OData tables (KNS_PlenumVote, KNS_PlenumVoteResult, KNS_Bill, KNS_PersonToPosition),
# read from the public Open Knesset mirror (storage.googleapis.com/knesset-data-pipelines) because knesset.gov.il
# is geo-blocked from the build machine. Vote and bill IDs are the Knesset's, so every row links back to knesset.gov.il.
# Usage: python3 build_full.py <download dir>   (downloads the tables there if missing)
import csv, json, os, sys, subprocess, collections
DL = sys.argv[1]; H = os.path.dirname(os.path.abspath(__file__))
G = 'https://storage.googleapis.com/knesset-data-pipelines/data/'
T = {'kns_plenumvote': 'knesset/kns_plenumvote', 'kns_plenumvoteresult': 'knesset/kns_plenumvoteresult',
     'kns_bill': 'bills/kns_bill', 'kns_persontoposition': 'members/kns_persontoposition', 'kns_person': 'members/kns_person'}
for n, p in T.items():
    f = os.path.join(DL, n + '.csv')
    if not os.path.exists(f): subprocess.run(['curl', '-sS', '-o', f, G + p + '/' + n + '.csv'], check=True)
rd = lambda n: csv.DictReader(open(os.path.join(DL, n + '.csv'), encoding='utf-8'))
K25 = '2022-11-15'
bills = {b['BillID']: b for b in rd('kns_bill') if b['KnessetNum'] == '25'}
pv = [x for x in rd('kns_plenumvote') if x['VoteDateTime'] >= K25]
whole = [x for x in pv if x['ItemID'] in bills and not x['VoteSubject'].strip()]
wid = {x['Id'] for x in whole}
res = collections.defaultdict(dict)
for r in rd('kns_plenumvoteresult'):
    if r['VoteID'] in wid: res[r['VoteID']][r['MkId']] = r['ResultDesc']
last = {}
for x in sorted(whole, key=lambda x: x['VoteDateTime']):
    if res[x['Id']]: last[x['ItemID']] = x
def counts(v): c = collections.Counter(res[v['Id']].values()); return c.get('בעד', 0), c.get('נגד', 0)
def voters(v): return sum(1 for r in res[v['Id']].values() if r in ('בעד', 'נגד', 'נמנע'))
proto = json.load(open(os.path.join(H, '..', 'game_data.json')))
proto_bills = {str(v['bill']): v for v in proto['votes']}
pool = {}
for b, v in last.items():
    f, a = counts(v)
    if 'התפזרות' in bills[b]['Name']: continue
    # rule (Lior 14.10): the last whole-bill vote, if at least 40 MKs voted (for, against or abstain); replaces the 10-for/10-against rule
    if voters(v) >= 40: pool[b] = v
for b, pvv in proto_bills.items():  # the curated prototype vote stands in for its bill's vote, when it passes the same rule
    x = next((y for y in whole if y['Id'] == str(pvv['id'])), None)
    if x and res[x['Id']] and voters(x) >= 40: pool[b] = x
    elif b in pool or (x and res[x['Id']]): print('prototype below 40:', b, x and voters(x))
# MKs: everyone with a Knesset-25 faction membership; serving dates decide '-' (not yet / no longer in the Knesset)
per = {p['PersonID']: p for p in rd('kns_person')}
mem = collections.defaultdict(list)
for r in rd('kns_persontoposition'):
    if r['KnessetNum'] == '25' and r['FactionID']:
        mem[r['PersonID']].append((r['StartDate'][:10], (r['FinishDate'] or '9999')[:10], r['FactionName']))
votes = sorted(pool.values(), key=lambda x: x['VoteDateTime'])
CODE = {'בעד': 'F', 'נגד': 'A', 'נמנע': 'B'}
mks = []
for pid, spans in mem.items():
    spans.sort(); s = ''
    for v in votes:
        d = v['VoteDateTime'][:10]; r = res[v['Id']].get(pid)
        if r: s += CODE.get(r, 'N')
        else: s += 'N' if any(a <= d <= b for a, b, _ in spans) else '-'
    if sum(c in 'FAB' for c in s) < 10: continue
    p = per[pid]
    mks.append({'id': int(pid), 'name': (p['FirstName'] + ' ' + p['LastName']).strip(), 'faction': spans[-1][2],
                'g': 'f' if p['GenderID'] == '250' else 'm', 'v': s})
out = []
for v in votes:
    b = bills[v['ItemID']]; f, a = counts(v)
    out.append({'id': int(v['Id']), 'bill': int(v['ItemID']), 'date': v['VoteDateTime'][:10], 'name': b['Name'],
                'type': b['SubTypeDesc'], 'for': f, 'against': a, 'summary': b['SummaryLaw'].strip()})
json.dump({'votes': out, 'mks': sorted(mks, key=lambda m: m['name'])}, open(os.path.join(H, 'full_raw.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(out), 'votes', len(mks), 'mks')
