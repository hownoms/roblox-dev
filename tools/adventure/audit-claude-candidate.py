#!/usr/bin/env python3
"""Audit the real Claude boot candidate plus current Adventure modules, without a resolver shim.

Creates only an ignored build fixture. Exit 2 means a required integration gate is blocked;
exit 1 means another check failed. No Studio, network, DataStore or tracked shared-file writes.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
ref = sys.argv[1] if len(sys.argv) > 1 else 'a9fb29b'
commit = subprocess.check_output(['git', 'rev-parse', ref], cwd=root, text=True).strip()
dst = root / 'build/adventure/claude-candidate-audit'
assert dst.resolve().is_relative_to((root / 'build/adventure').resolve())
if dst.exists():
    shutil.rmtree(dst)
dst.mkdir(parents=True)
archive = subprocess.check_output(['git', 'archive', '--format=zip', commit], cwd=root)
with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
    bundle.extractall(dst)
for name in ('src/server/Adventure', 'src/client/Adventure', 'src/shared/Adventure'):
    if (root / name).exists():
        shutil.copytree(root / name, dst / name, dirs_exist_ok=True)
for name in ('spring-vault-runtime', 'spring-vault-input', 'spring-vault-return', 'broadwave-dig'):
    shutil.copy2(root / ('tests/' + name + '.spec.luau'), dst / ('tests/' + name + '.spec.luau'))

# Instrument only fixture assertions; the actual Boot source is never changed.
spec = dst / 'tests/production-wiring.spec.luau'
s = spec.read_text(encoding='utf-8')
needle = 'check(type(opts.OnOrdinaryBroadwave) == "function", "bridge wired")'
assert s.count(needle) == 1
s = s.replace(needle, needle + '\nprint("AUDIT_RESOLVER=" .. tostring(type(opts.ResolveTool) == "function"))')
needle = 'local ok = opts.OnOrdinaryBroadwave(lic, CF.lookAt(root.Position, root.Position + look), 1)'
assert s.count(needle) == 1
s = s.replace(needle, '''runtime.Handle(lic, { action = "ChargeBegin" })
print("AUDIT_LICENSED_CHARGING=" .. tostring(runtime.ReviewPlayer(lic).Charging == true))
Mock.Advance(0.9)
runtime.Handle(lic, { action = "ChargeRelease" })
print("AUDIT_LICENSED_RUNTIME_SAND=" .. tostring(Data.Get(lic).TotalSandDug > dug0))
Mock.Advance(8.1)
''' + needle)
needle = 'check(Eligibility.CanUseBroadwave(lic, loan) == false, "adventure loan never satisfies CanUse")'
assert s.count(needle) == 1
s = s.replace(needle, needle + '''
local loanSand = Data.Get(lic).TotalSandDug
runtime.Handle(lic, { action = "ChargeBegin" })
check(runtime.ReviewPlayer(lic).Charging == false, "loan refuses ordinary runtime charging")
Mock.Advance(0.9)
runtime.Handle(lic, { action = "ChargeRelease" })
check(Data.Get(lic).TotalSandDug == loanSand, "loan runtime release never grants ordinary sand")''')
spec.write_text(s, encoding='utf-8')
os.environ.setdefault('ROBLOX_DEFS', str(root.parent / 'roblox-dev/.tools/globalTypes.d.luau'))
os.environ['PYTHONUTF8'] = '1'
luau = os.environ.get('LUAU_BIN', str(Path.home() / 'bin/luau.exe'))
log = []
results = []
def run(args):
    result = subprocess.run(args, cwd=dst, capture_output=True, text=True, encoding='utf-8')
    log.append('$ ' + ' '.join(args) + '\n' + result.stdout + result.stderr)
    return result
if run([sys.executable, 'tests/tools/bundle.py']).returncode:
    raise RuntimeError(log[-1])
for name, mode in [('production-wiring', ''), ('production-wiring', 'on'), ('production-wiring', 'client'), ('production-wiring', 'rejoin'), ('adventure-entry', 'off'), ('adventure-entry', 'on'), ('spring-vault-runtime', ''), ('spring-vault-input', ''), ('spring-vault-return', ''), ('broadwave-dig', '')]:
    r = run([luau, 'tests/' + name + '.spec.luau'] + (['-a', mode] if mode else []))
    results.append({'spec': name, 'mode': mode, 'exit': r.returncode})
combined = '\n'.join(log)
gates = {label: ('passed' if 'AUDIT_' + marker + '=true' in combined else 'blocked') for label, marker in [('authoritative_boot_resolver', 'RESOLVER'), ('licensed_runtime_charging', 'LICENSED_CHARGING'), ('licensed_runtime_ordinary_sand', 'LICENSED_RUNTIME_SAND')]}
manifest = {'claude_commit': commit, 'fixture': 'Claude archive plus current Adventure modules; no temporary ResolveTool injection', 'gates': gates, 'results': results, 'limitations': 'Automated headless mocks with in-memory stores; no networked Studio, real streaming, live persistence or physical device pass.', 'boot_sha256': hashlib.sha256((dst / 'src/server/Services/AdventureBoot.luau').read_bytes()).hexdigest()}
(root / 'build/adventure/claude-candidate-audit.log').write_text(combined, encoding='utf-8')
(root / 'build/adventure/claude-candidate-audit-results.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps(manifest, indent=2))
sys.exit(1 if any(r['exit'] for r in results) else 2 if 'blocked' in gates.values() else 0)
