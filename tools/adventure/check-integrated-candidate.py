#!/usr/bin/env python3
"""Build an ignored mock candidate; never apply the shared patch to tracked source.

Set ROBLOX_DEFS and LUAU_BIN to override local tool locations. Use `focused` to run
only wiring/runtime/input/ordinary-dig checks. Production ResolveTool stays Claude-owned.
"""
from pathlib import Path
import shutil, subprocess, os, json, hashlib
root=Path(__file__).resolve().parents[2]
dst=root/'build/adventure/integrated-candidate'
if dst.exists():
    assert dst.resolve().is_relative_to((root/'build/adventure').resolve())
    shutil.rmtree(dst)
dst.mkdir(parents=True,exist_ok=True)
for name in ('src','tests'):
    shutil.copytree(root/name,dst/name,dirs_exist_ok=True)
for p in root.glob('*.project.json'): shutil.copy2(p,dst/p.name)
patch=root/'docs/integration/adventure-integration.patch'
# Keep all patch edits inside ignored fixture; no repository files are changed.
r=subprocess.run(['git','apply','--directory='+str(dst.relative_to(root)),str(patch)],cwd=root,capture_output=True,text=True)
if r.returncode: raise RuntimeError(r.stderr)
p=dst/'src/server/Services/AdventureBoot.luau'
s=p.read_text()
needle='\tif flags.BroadwaveOrdinary then\n'
assert s.count(needle)==1
adapter='''\tif flags.BroadwaveOrdinary then
        -- TEMPORARY FIXTURE ADAPTER: authoritative eligibility checks issued registry, loaded license, equipped tool and feature enablement.
        options.ResolveTool = function(player)
            local character = player.Character
            if not character then return nil end
            for _, tool in character:GetChildren() do
                if tool:IsA("Tool") and Eligibility.CanUseBroadwave(player, tool) then
                    return tool
                end
            end
            return nil
        end
'''
s=s.replace(needle,adapter)
p.write_text(s)
spec=dst/'tests/production-wiring.spec.luau'
t=spec.read_text()
t=t.replace('check(spawns >= 1 and enabledSpawns == 0, "arena spawn disabled (players never spawn in the pocket)")','check(spawns == 0 and enabledSpawns == 0, "production creates zero arena spawns (fixture updated for no-spawn runtime)")')
t=t.replace('check(Eligibility.CanUseBroadwave(lic, licensedTool) == true, "licensed, issued, equipped -> CanUse")','''check(Eligibility.CanUseBroadwave(lic, licensedTool) == true, "licensed, issued, equipped -> CanUse")
check(opts.ResolveTool(lic) == licensedTool, "fixture authoritative resolver returns registered equipped licensed instance")''')
t=t.replace('local ok = opts.OnOrdinaryBroadwave(lic, CF.lookAt(root.Position, root.Position + look), 1)','''runtime.Handle(lic, { action = "ChargeBegin" })
check(runtime.ReviewPlayer(lic).Charging == true, "integrated actual runtime accepts licensed charge via authoritative resolver")
Mock.Advance(0.9)
runtime.Handle(lic, { action = "ChargeRelease" })
check(runtime.ReviewPlayer(lic).Charging == false and Data.Get(lic).TotalSandDug > dug0, "integrated licensed runtime release produces validated ordinary scoop")
Mock.Advance(8.1)
local ok = opts.OnOrdinaryBroadwave(lic, CF.lookAt(root.Position, root.Position + look), 1)''')
t=t.replace('check(Eligibility.CanUseBroadwave(lic, loan) == false, "adventure loan never satisfies CanUse")','''check(Eligibility.CanUseBroadwave(lic, loan) == false, "adventure loan never satisfies CanUse")
check(opts.ResolveTool(lic) == nil, "fixture resolver refuses review loan despite loaded license")
local loanSand = Data.Get(lic).TotalSandDug
runtime.Handle(lic, { action = "ChargeBegin" })
check(runtime.ReviewPlayer(lic).Charging == false, "integrated runtime refuses ordinary loan charge away from trial/event")
Mock.Advance(0.9)
runtime.Handle(lic, { action = "ChargeRelease" })
check(Data.Get(lic).TotalSandDug == loanSand, "review loan never grants ordinary production digging")''')
t=t.replace('check(Eligibility.CanUseBroadwave(lic, fake) == false, "a tool with the right name/attribute but not issued is refused")','''check(Eligibility.CanUseBroadwave(lic, fake) == false, "a tool with the right name/attribute but not issued is refused")
check(opts.ResolveTool(lic) == nil, "fixture resolver refuses spoof tool")''')
spec.write_text(t)
os.environ.setdefault('ROBLOX_DEFS',str(root.parent/'roblox-dev/.tools/globalTypes.d.luau'))
os.environ['PYTHONUTF8']='1'
log=[]
def run(args):
    r=subprocess.run(args,cwd=dst,capture_output=True,text=True)
    log.append('$ '+' '.join(map(str,args))+'\n'+r.stdout+r.stderr+'\nEXIT '+str(r.returncode)+'\n')
    (root/'build/adventure/integrated-candidate.log').write_text('\n'.join(log),encoding='utf-8')
    return r.returncode
assert run([os.sys.executable,'tests/tools/bundle.py'])==0
luau=os.environ.get('LUAU_BIN',str(Path.home()/'bin/luau.exe'))
checks=[['util'],['smoke'],['smoke','studio'],['trophy'],['adventure-settlement'],['adventure-outcome'],['trophy-wired'],['production-wiring'],['production-wiring','on'],['production-wiring','client'],['production-wiring','rejoin'],['persistence-boot'],['persistence-boot','studio'],['client'],['spring-vault'],['spring-vault-runtime'],['spring-vault-input'],['broadwave-dig'],['adventure-trophy-contract']]
if 'focused' in os.sys.argv:
    checks=[c for c in checks if c[0] in ('production-wiring','spring-vault-runtime','spring-vault-input','broadwave-dig')]
results=[]
for spec,*mode in checks:
    args=[luau,'tests/'+spec+'.spec.luau']+(['-a']+mode if mode else [])
    results.append({'spec':spec,'mode':mode,'exit':run(args)})
manifest={'fixture':'ignored copy + consolidated shared integration patch + temporary authoritative ResolveTool adapter','limitations':'API-aware headless mock, in-memory stores; no actual clients, physical inputs, streaming, live DataStores, persistence or boot deployment','results':results,'source_hashes':{str(p.relative_to(dst)):hashlib.sha256(p.read_bytes()).hexdigest() for p in dst.rglob('*.luau') if 'build' not in p.relative_to(dst).parts}}
(root/'build/adventure/integrated-candidate-results.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(results,indent=2))
