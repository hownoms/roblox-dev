"""Non-destructive export: existing house icon renderer + offline real-factory geometry previews.
Generated artwork is only resized/cropped for delivery; no painting or background removal.
"""
from pathlib import Path
import sys, math, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/expansion1'
sys.path.insert(0, str(ROOT / 'tools/icons'))
import generate_icons as g
g.CELL = 240  # renderer still draws at its original 512px supersampling resolution

def shovel(ic):
    with ic.frame(rot=35):
        ic.fill(ic.line([(50,15),(50,62)], 8), g.CREAM)
        ic.fill(ic.rrect(34,3,66,20,5), g.OCEAN_D)
        ic.fill(ic.rrect(42,8,58,15,2), g.INK, stroke=0, shade=0, rim=0)
        ic.fill(ic.rect(44,30,56,45), g.OCEAN)
        ic.fill(ic.rrect(22,58,78,92,10), g.OCEAN)
        ic.fill(ic.line([(26,62),(26,79)],4), g.OCEAN_D)
        ic.fill(ic.line([(74,62),(74,79)],4), g.OCEAN_D)
        ic.fill(ic.rect(43,52,57,59), g.GOLD)
        for x in [39,50,61]: ic.fill(ic.circ(x,72,3), g.CREAM, stroke=0)

def wave(ic):
    ic.fill(ic.poly([(5,78),(12,51),(24,29),(43,19),(62,26),(70,43),(55,46),(51,35),(40,35),(34,46),(43,61),(70,59),(95,74),(92,90),(17,92)]), g.OCEAN)
    ic.fill(ic.line([(17,46),(27,28),(43,23),(59,29),(65,40)],8), g.CREAM)
    ic.fill(ic.line([(28,77),(48,73),(71,77)],5), g.SKY)

def shared(ic):
    ic.fill(ic.rrect(10,38,90,91,9), g.OCEAN)
    ic.fill(ic.rrect(10,31,90,51,6), g.CORAL)
    ic.fill(ic.rect(43,44,57,65), g.GOLD)
    for x in [24,76]:
        ic.fill(ic.rrect(x-9,22,x+9,35,3), g.CREAM)
    for x,y in [(30,8),(70,8)]:
        ic.fill(ic.circ(x,y,7), g.CREAM)
        ic.fill(ic.rrect(x-11,y+10,x+11,y+20,5), g.CREAM)

def helping(ic):
    ic.fill(ic.poly([(4,65),(27,40),(48,56),(38,78),(18,91)]), g.CORAL)
    ic.fill(ic.poly([(96,65),(73,40),(52,56),(62,78),(82,91)]), g.OCEAN)
    ic.fill(ic.poly([(26,40),(36,30),(53,45),(67,35),(76,46),(59,68),(47,75),(34,63)]), g.CREAM)
    ic.fill(ic.line([(40,56),(53,65)],3), g.SAND_D)

def complete(ic):
    ic.fill(ic.rrect(16,15,80,93,7), g.CREAM)
    ic.fill(ic.rrect(34,6,63,26,5), g.GOLD)
    ic.fill(ic.line([(31,55),(45,70),(74,38)],11), g.PALM)

def reward(ic):
    ic.fill(ic.rect(30,80,70,91), g.OCEAN_D)
    ic.fill(ic.rect(44,65,56,84), g.GOLD)
    ic.fill(ic.circ(50,40,28), g.GOLD)
    ic.fill(ic.poly([(25,31),(44,19),(49,50),(30,59)]), g.OCEAN)
    ic.fill(ic.poly([(56,18),(74,31),(69,58),(55,50)]), g.CORAL)
    ic.fill(ic.ell(41,17,56,25), g.CREAM, stroke=0)
    ic.sparkle(84,19,9, g.CREAM)

drawers = {'tool_broadwave':shovel, 'ability_broadwave':wave, 'shared_discovery':shared,
           'helping':helping, 'objective_complete':complete, 'trophy_reward':reward}
for name, fn in drawers.items():
    ic = g.Icon(); fn(ic); im = ic.finish()
    for size in [32,120,240]:
        im.resize((size,size), Image.Resampling.LANCZOS).save(OUT / f'ui/{name}_{size}.png')
atlas = Image.new('RGBA',(720,480))
rects = {}
for i,name in enumerate(drawers):
    x,y = i%3*240,i//3*240
    atlas.alpha_composite(Image.open(OUT/f'ui/{name}_240.png'),(x,y))
    rects[name] = [x,y,240,240]
atlas.save(OUT/'ui/expansion1_atlas.png')
(OUT/'ui/atlas_rects.json').write_text(json.dumps(rects,indent=2)+'\n')

# PNG dialogue delivery sizes, sourced from generated portraits.
for id in ['npc_mara','npc_pip']:
    source = OUT/f'ui/{id}_portrait_source.png'
    if source.exists():
        im = Image.open(source).convert('RGBA')
        for size in [64,120,240]:
            im.resize((size,size),Image.Resampling.LANCZOS).save(OUT/f'ui/{id}_portrait_{size}.png')

font = ImageFont.truetype(str(ROOT/'tools/marketing/fonts/LilitaOne-Regular.ttf'),20)
small = ImageFont.truetype(str(ROOT/'tools/marketing/fonts/LilitaOne-Regular.ttf'),15)
sheet = Image.new('RGB',(1000,500),(29,42,68)); d=ImageDraw.Draw(sheet)
d.text((22,15),'FIRST EXPANSION / UI READABILITY',font=font,fill='white')
for row,bg in enumerate([(29,42,68),(255,250,232)]):
    d.rectangle((0,55+row*220,1000,275+row*220),fill=bg)
    for i,name in enumerate(drawers):
        x=i*164+8; y=65+row*220
        for size,dx in [(120,0),(32,126)]:
            im=Image.open(OUT/f'ui/{name}_{size}.png'); sheet.paste(im,(x+dx,y),im)
        d.text((x,y+135),name.replace('_',' '),font=small,fill='white' if row==0 else (27,27,36))
sheet.save(OUT/'previews/ui_readability.png')

# Orthographic renders from factory part transforms. Offline preview, not Roblox lighting.
parts = {}
for line in (OUT/'verification/model-geometry.tsv').read_text(encoding='utf-8-sig').splitlines():
    if not line.startswith('PART\t'): continue
    v=line.split('\t')[1:]; id,name,cls,shape,alpha=v[:5]
    a=np.array([float(n) for n in v[5:23]])
    if float(alpha)>=1: continue
    parts.setdefault(id,[]).append((name,cls,shape,float(alpha),a[:3],a[3:6],a[6:9],a[9:18].reshape(3,3),v[23]))

right=np.array([.8,0,-.6]); up=np.array([.3,.866,.4]); depth=-np.cross(right,up)
def geom(p):
    name,cls,shape,alpha,size,color,pos,rot,mesh=p
    polys=[]
    if shape=='Ball' or mesh=='Sphere':
        for j in range(8):
            for k in range(12):
                pts=[]
                for jj,kk in [(j,k),(j,k+1),(j+1,k+1),(j+1,k)]:
                    lat=-math.pi/2+jj*math.pi/8; lon=kk*math.pi/6
                    pts.append(np.array([math.cos(lat)*math.cos(lon),math.sin(lat),math.cos(lat)*math.sin(lon)])*size/2)
                polys.append(np.array(pts))
    elif shape=='Cylinder':
        # Roblox cylinder's length axis is X.
        rings=[np.array([[x,math.cos(t)*size[1]/2,math.sin(t)*size[2]/2] for t in np.arange(12)*math.pi/6]) for x in [-size[0]/2,size[0]/2]]
        polys.extend(rings)
        for i in range(12): polys.append(np.array([rings[0][i],rings[0][(i+1)%12],rings[1][(i+1)%12],rings[1][i]]))
    else:
        verts=np.array([[x,y,z] for x in [-.5,.5] for y in [-.5,.5] for z in [-.5,.5]])*size
        faces=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
        if cls=='WedgePart':
            verts=np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]])*size
            faces=[[0,1,3,2],[2,3,5,4],[0,4,5,1],[0,2,4],[1,5,3]]
        polys=[verts[f] for f in faces]
    return [(poly@rot.T+pos,color,alpha) for poly in polys]

def render(id,w=500,h=460):
    faces=[face for p in parts[id] for face in geom(p)]
    xyz=np.concatenate([f[0] for f in faces]); xy=np.column_stack([xyz@right,-xyz@up])
    lo,hi=xy.min(0),xy.max(0); scale=min((w-70)/(hi[0]-lo[0]),(h-95)/(hi[1]-lo[1]))
    center=(lo+hi)/2
    canvas=np.full((h,w,3),[238,231,209],dtype=np.uint8)
    zbuffer=np.full((h,w),-np.inf)
    for points,color,alpha in sorted(faces,key=lambda f: np.mean(f[0]@depth)):
        proj=(np.column_stack([points@right,-points@up])-center)*scale+[w/2,(h-35)/2]
        normal=np.cross(points[1]-points[0],points[2]-points[0]); n=np.linalg.norm(normal)
        shade=.76+.24*abs(np.dot(normal/n,np.array([.3,.85,-.4]))) if n>1e-8 else 1
        c=np.clip(color*255*shade,0,255); c=c*(1-alpha)+np.array([238,231,209])*alpha
        zs=points@depth
        for j in range(1,len(proj)-1):
            tri=proj[[0,j,j+1]]; zz=zs[[0,j,j+1]]
            x0,y0=np.maximum(np.floor(tri.min(0)).astype(int),[0,0]); x1,y1=np.minimum(np.ceil(tri.max(0)).astype(int),[w-1,h-1])
            if x1<x0 or y1<y0: continue
            xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
            a,b,cc=tri
            den=(b[1]-cc[1])*(a[0]-cc[0])+(cc[0]-b[0])*(a[1]-cc[1])
            if abs(den)<1e-8: continue
            u=((b[1]-cc[1])*(xx-cc[0])+(cc[0]-b[0])*(yy-cc[1]))/den
            v=((cc[1]-a[1])*(xx-cc[0])+(a[0]-cc[0])*(yy-cc[1]))/den
            ww=1-u-v; z=u*zz[0]+v*zz[1]+ww*zz[2]
            view=zbuffer[y0:y1+1,x0:x1+1]; mask=(u>=-1e-6)&(v>=-1e-6)&(ww>=-1e-6)&(z>view)
            view[mask]=z[mask]; canvas[y0:y1+1,x0:x1+1][mask]=c.astype(int)
    im=Image.fromarray(canvas); d=ImageDraw.Draw(im)
    d.text((16,h-33),id,font=small,fill=(29,42,68))
    return im

ids=['npc_mara_Idle','npc_pip_Idle','tool_broadwave','landmark_spring_vault_Covered','landmark_spring_vault_Partial','landmark_spring_vault_Opened','landmark_spring_vault_ball','camp_trophy_stand','landmark_spring_vault_trophy','tool_broadwave_effect','landmark_spring_vault_ball_effect']
parts['camp_trophy_display']=parts['camp_trophy_stand']+[(name,cls,shape,alpha,size,color,pos+np.array([0,1.75,0]),rot,mesh) for name,cls,shape,alpha,size,color,pos,rot,mesh in parts['landmark_spring_vault_trophy']]
render('camp_trophy_display').save(OUT/'previews/camp_trophy_display.png')
contact=Image.new('RGB',(1500,4*460+65),(29,42,68)); d=ImageDraw.Draw(contact)
d.text((22,18),'REAL MODEL FACTORIES / OFFLINE GEOMETRY PREVIEW / STUDIO CONTACT PENDING',font=font,fill='white')
for i,id in enumerate(ids):
    im=render(id); im.save(OUT/f'previews/{id}.png'); contact.paste(im,(i%3*500,65+i//3*460))
contact.save(OUT/'previews/model_contact_sheet.jpg',quality=90)
print('Exported six icons, atlas, available portraits, and real-factory geometry previews')
