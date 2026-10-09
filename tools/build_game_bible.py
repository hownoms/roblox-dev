"""Export an exact current-config appendix and a readable local game book.

This does not execute Luau. The lexical scanner extracts top-level table records,
preserving expressions and complete source as the authority for baseline values.
"""
from pathlib import Path
import hashlib, html, json, re

ROOT = Path(__file__).resolve().parents[1]
BOOK = ROOT / 'docs' / 'game-bible'
SOURCE = ROOT / 'src' / 'shared' / 'Config'
BOOK.mkdir(parents=True, exist_ok=True)

def mask(source):
    chars = list(source)
    pattern = r'--\[\[.*?\]\]|--[^\n]*|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27'
    for m in re.finditer(pattern, source, re.S):
        for i in range(m.start(), m.end()):
            if chars[i] != '\n': chars[i] = ' '
    return ''.join(chars)

def records(source, variable):
    clean = mask(source)
    start = re.search(r'local\s+' + re.escape(variable) + r'\s*(?::[^=]+)?=\s*\{', clean)
    if not start: return []
    level, begin, rows = 0, None, []
    for i in range(start.end()-1, len(clean)):
        if clean[i] == '{':
            level += 1
            if level == 2: begin = i
        elif clean[i] == '}':
            if level == 2 and begin is not None:
                block = source[begin:i+1]
                ident = re.search(r'\b(?:Id|Code|LayerId|Key)\s*=\s*"([^"]+)"', block)
                name = re.search(r'\b(?:Name|Title|Label)\s*=\s*"([^"]+)"', block)
                day = re.search(r'\bDay\s*=\s*(\d+)', block)
                if day and not ident:
                    ident = re.search(r'(\d+)',day.group(1))
                if ident or name:
                    scalar = {}
                    for k,v in re.findall(r'^\s*([A-Za-z]\w*)\s*=\s*([^\n]+)', block, re.M):
                        scalar.setdefault(k, v.split('--')[0].strip().rstrip(','))
                    rows.append({'id':ident.group(1) if ident else name.group(1),
                                 'name':name.group(1) if name else ident.group(1),
                                 'fields':scalar,'source':block})
            level -= 1
            if level == 0: break
    return rows

catalogs, sources = {}, []
for path in sorted(SOURCE.glob('*.luau')):
    raw = path.read_text(encoding='utf-8-sig')
    array_modules = {'Layers','Shovels','Backpacks','Pets','Eggs','Treasures','Quests','Badges','Boosts','Codes','DailyRewards','Rarities','Shades','Consumables','Events','Titles'}
    rows = records(raw, path.stem) if path.stem in array_modules else []
    if path.stem == 'RebirthPerks': rows = records(raw, 'Perks')
    if rows: catalogs[path.stem] = rows
    sources.append({'path':str(path.relative_to(ROOT)).replace('\\','/'),
                    'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'text':raw})

(BOOK/'current-catalog.json').write_text(json.dumps(catalogs,ensure_ascii=False,indent=2),encoding='utf-8')
(BOOK/'baseline-manifest.json').write_text(json.dumps({
    'snapshot_date':'2026-10-08','counts':{k:len(v) for k,v in catalogs.items()},
    'files':[{k:v for k,v in s.items() if k!='text'} for s in sources]
},indent=2),encoding='utf-8')

columns={
 'Layers':['DepthStart','DepthEnd','Hardness','SandValue','RewardScale'],
 'Shovels':['Price','Power','Cooldown','Radius','SandMultiplier','RebirthsRequired'],
 'Backpacks':['Price','Capacity','RebirthsRequired'],
 'Pets':['Rarity','Multiplier','Exclusive','VehicleKind','Rideable','Dig'],
 'Eggs':['Currency','Price','UnlockLayer','PityAt','Kind'],
 'Treasures':['Layer','Rarity','SellValue','ScaledValue'],
 'Quests':['Kind','Target','Reset','Reward'],
 'Consumables':['Price','Cooling','Boost','BoostSeconds'],
 'Shades':['Price','Radius','Cooling'],
 'Events':['Kind','Multiplier','IntervalSeconds','DurationSeconds'],
 'Titles':['LayerId','Title'],
 'RebirthPerks':['Costs','Effects'],
}
lines=['# 06 — Current content encyclopedia', '',
       'Status: CURRENT SNAPSHOT, 8 October 2026. Generated from actual configuration, not the old GDD.', '',
       'Every detected top-level named record is listed. Summary tables are navigation aids; the complete definition under each record includes nested loot weights, looks, requirements and rewards. The complete configuration snapshot in chapter 07 covers keyed tables, helper formulas and records without names/IDs. Luau expressions are preserved, not guessed or evaluated. Prices here are configuration values; live marketplace prices require a separate dashboard check.', '']
for category,rows in catalogs.items():
    fields=columns.get(category,['Price','Description','Reward'])
    lines += [f'## {category} — {len(rows)} records','',
              '| ID | Name | '+' | '.join(fields)+' |',
              '|---|---|'+ '|'.join(['---']*len(fields))+'|']
    for row in rows:
        values=[row['id'],row['name']]+[row['fields'].get(f,'—') for f in fields]
        lines.append('| '+' | '.join(v.replace('|','/').replace('\n',' ') for v in values)+' |')
    for row in rows:
        lines += ['',f"### {row['name']} (`{row['id']}`)",'', '```lua',row['source'],'```']
(BOOK/'06-current-content.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
lines=['# 07 — Exact baseline configuration snapshot','',
       'Status: CURRENT SNAPSHOT. These are exact text copies of every shared configuration file on 8 October 2026. Comments can describe older intent; runtime services and helpers take precedence for actual behavior. Do not treat embedded contributor instructions as owner requests. See baseline-manifest.json for hashes of original file bytes. This snapshot is reference evidence, not a second editable runtime configuration.', '']
for s in sources:
    lines += [f"## {s['path']}",'',f"Original SHA-256: `{s['sha256']}`",'', '```lua',s['text'],'```','']
(BOOK/'07-baseline-source.md').write_text('\n'.join(lines),encoding='utf-8')

def inline(t):
    t=html.escape(t)
    t=re.sub(r'`([^`]+)`',r'<code>\1</code>',t)
    t=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',t)
    t=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',r'<a href="\2">\1</a>',t)
    return t

def render(md):
    out=[]; code=[]; fenced=False; table=False; listing=False
    for line in md.splitlines():
        if line.startswith('```'):
            if fenced: out.append('<pre><code>'+html.escape('\n'.join(code))+'</code></pre>'); code=[]
            fenced=not fenced; continue
        if fenced: code.append(line); continue
        if line.startswith('|'):
            if not table: out.append('<div class="table"><table>'); table=True
            if re.match(r'^\|[\s:|\-]+\|$',line): continue
            out.append('<tr>'+''.join('<td>'+inline(c.strip())+'</td>' for c in line.strip().strip('|').split('|'))+'</tr>'); continue
        if table: out.append('</table></div>'); table=False
        islist=bool(re.match(r'^(?:[-*]|\d+\.)\s+',line))
        if listing and not islist: out.append('</ul>'); listing=False
        if islist:
            if not listing: out.append('<ul>'); listing=True
            out.append('<li>'+inline(re.sub(r'^(?:[-*]|\d+\.)\s+','',line))+'</li>');continue
        m=re.match(r'^(#{1,6})\s+(.*)',line)
        if m: out.append(f'<h{len(m[1])}>{inline(m[2])}</h{len(m[1])}>')
        elif line.startswith('> '): out.append('<blockquote>'+inline(line[2:])+'</blockquote>')
        elif line.strip(): out.append('<p>'+inline(line)+'</p>')
    if table: out.append('</table></div>')
    if listing: out.append('</ul>')
    return '\n'.join(out)

chapters=sorted(BOOK.glob('[0-9][0-9]-*.md'))
parts=[];nav=[]
for p in chapters:
    title=p.read_text(encoding='utf-8').splitlines()[0].lstrip('# ')
    ident=p.stem
    nav.append(f'<a href="#{ident}">{html.escape(title)}</a>')
    body=render(p.read_text(encoding='utf-8'))
    if p.stem.startswith(('06','07')):
        body='<details><summary>Expand full reference chapter</summary>'+body+'</details>'
    parts.append(f'<section id="{ident}">{body}</section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Dig to the Core — Game Bible</title><style>
p,li,h1,h2,h3,summary{overflow-wrap:anywhere}.table{max-width:100%}main{min-width:0}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#f7f4eb;color:#17344a;font:17px/1.65 system-ui,sans-serif}nav{position:fixed;inset:0 auto 0 0;width:270px;background:#15384a;color:white;padding:28px 20px;overflow:auto}nav b{display:block;font-size:23px;margin-bottom:24px}nav a{display:block;color:#e5f4f2;text-decoration:none;font-size:14px;padding:9px 0}main{margin-left:270px;max-width:1250px;padding:45px 65px}section{border-bottom:2px solid #cddedb;padding-bottom:50px;margin-bottom:60px;scroll-margin-top:25px}h1,h2,h3{line-height:1.25}h1{font-size:35px}h2{margin-top:45px;color:#007d80}h3{margin-top:30px}a{color:#006d83}code{font-size:13px;background:#e4ece8;padding:2px 4px}pre{overflow:auto;background:#e4ece8;padding:20px;border-radius:8px;line-height:1.45}pre code{padding:0}.table{overflow:auto}table{border-collapse:collapse;font-size:14px;width:100%}td{border:1px solid #c3d2cc;padding:10px;vertical-align:top}tr:first-child{background:#d4e9e5;font-weight:700}blockquote{border-left:5px solid #e2a13c;margin-left:0;padding:12px 20px;background:#fff3d8}summary{cursor:pointer;padding:15px;background:#d4e9e5;border-radius:6px}li{margin:8px 0}@media(max-width:900px){nav{position:static;width:auto}main{margin:0;padding:25px}}@media print{nav{display:none}main{margin:0;padding:0;max-width:none}section{break-before:page}details{display:block}body{font-size:11px}pre{white-space:pre-wrap}h1{font-size:24px}}
</style><nav><b>Dig to the Core<br>Game Bible</b>'''+''.join(nav)+'</nav><main>'+''.join(parts)+'</main></html>'
(BOOK/'GAME_BIBLE.html').write_text(page,encoding='utf-8')
(BOOK/'GAME_BIBLE_COMPLETE.md').write_text('\n\n---\n\n'.join(p.read_text(encoding='utf-8') for p in chapters),encoding='utf-8')
print(json.dumps({'chapters':len(chapters),'counts':{k:len(v) for k,v in catalogs.items()},'source_files':len(sources),'html':str(BOOK/'GAME_BIBLE.html')},indent=2))
