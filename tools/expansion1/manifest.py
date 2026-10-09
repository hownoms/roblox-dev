"""Asset manifest and image/geometry evidence; run after exporting and building."""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/expansion1'
source='src/shared/Models/Expansion1.luau'
bible=['docs/game-bible/'+p for p in ['02-future-game.md','03-future-content-catalog.md','04-mechanics-economy-and-production.md','05-roadmap-validation-and-handoff.md']]
imageqa=[]
for p in sorted(OUT.rglob('*.png')):
    im=Image.open(p); alpha=im.getchannel('A') if im.mode=='RGBA' else None
    row={'path':p.relative_to(ROOT).as_posix(),'size':list(im.size),'mode':im.mode}
    if alpha:
        row.update(alpha_extrema=list(alpha.getextrema()),alpha_bounds=list(alpha.getbbox() or (0,0,0,0)))
        if p.parent.name in ['ui','concepts']:
            assert alpha.getextrema()[0]==0 and alpha.getextrema()[1]>0, f'{p} lacks usable transparency'
    if p.parent.name=='ui' and p.stem.rsplit('_',1)[-1].isdigit():
        n=int(p.stem.rsplit('_',1)[-1]); assert im.size==(n,n)
    imageqa.append(row)
(OUT/'verification/image-audit.json').write_text(json.dumps(imageqa,indent=2)+'\n')

counts={}; bounds={}
for line in (OUT/'verification/model-geometry.tsv').read_text(encoding='utf-8-sig').splitlines():
    if line.startswith('PASS\t'):
        _,id,n=line.split('\t'); counts[id]=int(n)
    if not line.startswith('PART\t'): continue
    v=line.split('\t')[1:]; id=v[0]
    if float(v[4])>=1: continue
    a=np.array([float(n) for n in v[5:23]]); size=a[:3]; pos=a[6:9]; rot=a[9:18].reshape(3,3)
    # Conservative enclosing boxes, including ellipsoid decoration, rotated about the pivot.
    radius=np.abs(rot)@(size/2)
    lo,hi=pos-radius,pos+radius
    if id not in bounds: bounds[id]=[lo,hi]
    else: bounds[id]=[np.minimum(bounds[id][0],lo),np.maximum(bounds[id][1],hi)]
modelqa={id:{'base_parts':counts[id],'min':lo.tolist(),'max':hi.tolist(),'enclosing_size':(hi-lo).tolist()} for id,(lo,hi) in bounds.items()}
for id in ['landmark_spring_vault_Covered','landmark_spring_vault_Partial','landmark_spring_vault_Opened']:
    size=np.array(modelqa[id]['enclosing_size']); assert np.all(size<=np.array([12,10,8])+0.001),(id,size)
assert counts and 'ALL EXPANSION ASSET CONSTRUCTION CHECKS PASSED' in (OUT/'verification/model-geometry.tsv').read_text(encoding='utf-8-sig')
(OUT/'verification/model-audit.json').write_text(json.dumps({'method':'API-aware headless mock + conservative part envelopes; Studio pending','models':modelqa},indent=2)+'\n')

font=ImageFont.truetype(str(ROOT/'tools/marketing/fonts/LilitaOne-Regular.ttf'),28)
sm=ImageFont.truetype(str(ROOT/'tools/marketing/fonts/LilitaOne-Regular.ttf'),20)
sheet=Image.new('RGB',(1200,900),(29,42,68)); d=ImageDraw.Draw(sheet)
d.text((24,18),'MARA + PIP / GENERATED CHARACTER CONCEPTS AND UI PORTRAITS',font=font,fill='white')
for i,id in enumerate(['npc_mara','npc_pip']):
    design=Image.open(OUT/f'concepts/{id}_design.png').convert('RGBA')
    design.thumbnail((430,670),Image.Resampling.LANCZOS)
    sheet.paste(design,(i*600+25,90),design)
    for size,y in [(120,100),(64,310)]:
        portrait=Image.open(OUT/f'ui/{id}_portrait_{size}.png'); sheet.paste(portrait,(i*600+450,y),portrait)
        d.text((i*600+450,y+size+14),f'{size} px',font=sm,fill='white')
    d.text((i*600+30,795),'Mara the Lifeguard' if i==0 else 'Pip Pocket',font=font,fill='white')
d.text((24,850),'Concept art is separate from the simpler Roblox primitive models.',font=sm,fill=(255,222,140))
sheet.save(OUT/'previews/character_contact_sheet.jpg',quality=92)

def entity(path):
    s=path.stem
    for prefix in ['npc_mara','npc_pip','tool_broadwave','camp_trophy_stand']:
        if s.startswith(prefix): return prefix
    if 'vault' in s or 'ball' in s or 'trophy' in s: return 'landmark_spring_vault'
    return {'ability_broadwave':'tool_broadwave','shared_discovery':'event_vault','helping':'event_vault','objective_complete':'event_vault'}.get(s.rsplit('_',1)[0],'expansion1_visual_kit')

assets=[]
for p in sorted(OUT.rglob('*')):
    if not p.is_file() or p.name=='manifest.json' or p.suffix=='.lock': continue
    rel=p.relative_to(ROOT).as_posix(); category=p.parent.name
    status='reference_document'; origin='tools/expansion1/manifest.py'; target='local development handoff'
    purpose=p.stem.replace('_',' ')
    if category=='concepts':
        status='concept_art'; origin='built-in image_gen; PROMPTS.json'; target='NPC design reference only'
    elif category=='ui':
        status='local_raster_ready_upload_pending'
        origin='built-in image_gen; PROMPTS.json' if 'portrait' in p.stem else 'tools/expansion1/export_visuals.py; existing tools/icons/generate_icons.py house renderer'
        target='future NPC dialogue / contextual ability / event objective / settled result UI'
    elif category=='models':
        status='roblox_compatible_review_place_basic_studio_review_passed'; origin='expansion1.project.json + '+source; target='Studio isolated local review; Play builds models'
    elif category=='previews':
        status='review_preview_not_gameplay_screenshot'; origin='tools/expansion1/export_visuals.py / manifest.py'; target='local visual review'
    elif category=='verification':
        status='headless_or_build_evidence_not_studio_evidence'; origin='local Rojo / Luau / image inspection'; target='reviewer evidence only'
        if p.name=='STUDIO_REVIEW.md':
            status='studio_review_evidence_with_remaining_limits'; origin='Roblox Studio MCP isolated review'; target='Studio validation handoff'
    assets.append({'asset_id':p.relative_to(OUT).as_posix(),'entity_id':entity(p),'purpose':purpose,'status':status,'source':origin,'integration_location':target,'path':rel,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
factories=[('npc_mara','NPC("npc_mara", pose)','blocky lifeguard; Idle/Point/Celebrate'),('npc_pip','NPC("npc_pip", pose)','blocky shopkeeper; Idle/Point/Celebrate'),('tool_broadwave','Broadwave()','held welded shovel'),('landmark_spring_vault','SpringVault(state)','Covered/Partial/Opened 12x10x8 shared vault'),('landmark_spring_vault','BeachBall()','giant springy controlled cargo ball'),('camp_trophy_stand','TrophyStand()','2x2 cream camp pedestal'),('landmark_spring_vault','TrophyReplica()','first-adventure display replica'),('tool_broadwave','ChargeEffect(progress)','three filling charge dots'),('tool_broadwave','AbilityEffect(progress, reducedMotion)','local blue foam release cue'),('landmark_spring_vault','BallEffect(reducedMotion)','small bounce ground puffs')]
for id,api,purpose in factories:
    assets.append({'asset_id':'factory:'+api,'entity_id':id,'purpose':purpose,'status':'roblox_compatible_factory_integration_and_studio_pending','source':source,'path':source,'api':'Kit.'+api,'integration_location':'ReplicatedStorage.Shared.Models.Expansion1; future NPC/Ability/Event/Camp controllers','sha256':hashlib.sha256((ROOT/source).read_bytes()).hexdigest()})
manifest={'kit':'Dig to the Core! first expansion','version':1,'prepared_date':'2026-10-08','scope':'Mara, Pip, Broadwave, Spring Vault, controlled beach ball and first trophy; no future regions','source_specs':bible,'preserved_references':['docs/UI_STYLE.md','src/shared/Models/Build.luau','src/shared/Models/Shovels.luau','src/shared/Models/Props.luau','assets/icons/preview_32.png','marketing/publish-kit-bacon-v3/contact-sheet.jpg'],'ownership':'Original repo procedural assets and newly generated artwork; no third-party Roblox asset IDs','uploaded':False,'published':False,'studio_verified':False,'assets':assets}
manifest['source_specs_snapshot']='assets/expansion1/SPEC.md'
manifest['studio_review']={'status':'basic_visual_and_equip_review_passed_gameplay_pending','evidence':'assets/expansion1/verification/STUDIO_REVIEW.md','panel_polish_pending':True}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'{len(assets)} manifest entries; {len(imageqa)} PNG audits; {len(counts)} constructed model variants; vault envelopes passed')
