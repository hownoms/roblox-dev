"""Check generated baseline fidelity and target-catalog references."""
from pathlib import Path
import hashlib, json, re

ROOT=Path(__file__).resolve().parents[1]
BOOK=ROOT/'docs'/'game-bible'
manifest=json.loads((BOOK/'baseline-manifest.json').read_text(encoding='utf-8'))
catalog=json.loads((BOOK/'current-catalog.json').read_text(encoding='utf-8'))
expected={'Layers':15,'Shovels':14,'Backpacks':13,'Pets':56,'Eggs':13,
          'Treasures':53,'Quests':12,'Rarities':7,'Shades':7,'Consumables':7,
          'RebirthPerks':8,'Boosts':6,'Events':2,'Badges':15,'Codes':4,
          'DailyRewards':7,'Titles':15}
assert manifest['counts']==expected,(manifest['counts'],expected)
assert len(manifest['files'])==len(list((ROOT/'src'/'shared'/'Config').glob('*.luau')))==27
for source in manifest['files']:
    data=(ROOT/source['path']).read_bytes()
    assert hashlib.sha256(data).hexdigest()==source['sha256'],source['path']
for category,rows in catalog.items():
    assert len({r['id'] for r in rows})==len(rows),category
    source=(ROOT/'src'/'shared'/'Config'/f'{category}.luau').read_text(encoding='utf-8-sig')
    assert all(r['source'] in source for r in rows),category
    if category in {'Layers','Shovels','Backpacks','Pets','Eggs','Treasures','Quests','Shades','Consumables','Events','Boosts'}:
        ids=set(re.findall(r'\bId\s*=\s*"([^"]+)"',source))
        assert ids=={r['id'] for r in rows},(category,ids-{r['id'] for r in rows})

future=(BOOK/'03-future-content-catalog.md').read_text(encoding='utf-8')
definitions=set(re.findall(r'^\|\s*((?:tool|gadget|mount|npc|landmark|event|festival|q|paint|decal|camp|banner|trail)_[a-z0-9_]+)\b',future,re.M))
# IDs defined in prose rather than a table row.
definitions.update({'landmark_core_observatory','finale_first_ball'})
festival_rewards=set(re.findall(r'cosmetic_[a-z0-9_]+',future))
definitions.update(festival_rewards)
target_text='\n'.join((BOOK/f'{n}').read_text(encoding='utf-8') for n in [
    '02-future-game.md','03-future-content-catalog.md','04-mechanics-economy-and-production.md','05-roadmap-validation-and-handoff.md'])
refs=set(re.findall(r'\b(?:tool|gadget|mount|npc|landmark|event|festival|q|paint|decal|camp|banner|trail|cosmetic)_[a-z0-9_]+\b',target_text))
assert refs<=definitions,sorted(refs-definitions)
target_counts={prefix:len([x for x in definitions if x.startswith(prefix+'_')])
               for prefix in ['tool','gadget','mount','npc','event','festival','q']}
assert target_counts=={'tool':10,'gadget':4,'mount':8,'npc':13,'event':12,'festival':6,'q':14},target_counts
assert len(festival_rewards)==6

html=(BOOK/'GAME_BIBLE.html').read_text(encoding='utf-8')
assert html.count('<section id=')==8
for ident in re.findall(r'href="#([^"]+)"',html):
    assert f'id="{ident}"' in html,ident
chapters=sorted(BOOK.glob('[0-9][0-9]-*.md'))
summary={'baseline_source_files':27,'baseline_named_records':sum(expected.values()),
         'target_counts':target_counts,'chapters':len(chapters),
         'authored_design_words':sum(len(p.read_text(encoding='utf-8').split()) for p in chapters if int(p.name[:2])<6),
         'complete_book_bytes':(BOOK/'GAME_BIBLE_COMPLETE.md').stat().st_size,
         'checks':'PASS: source hashes, complete named catalogs, target ID references, counts and chapter navigation'}
(BOOK/'verification.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary,indent=2))
