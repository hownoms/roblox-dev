#!/usr/bin/env python3
"""Serves the local Spring Vault production candidate to an open Expansion1Review Studio (Edit mode).

docs/integration/production-candidate.md.

    python -X utf8 tools/expansion1/inject-production-candidate.py                    serve on 127.0.0.1:34874
    python -X utf8 tools/expansion1/inject-production-candidate.py --check            print the manifest, exit
    python -X utf8 tools/expansion1/inject-production-candidate.py --write-manifest F also write the
                                                                                      source/config/storage manifest

Then run tools/expansion1/install-production-candidate.luau in the Studio command bar (plugin
context). tools/expansion1/uninstall-production-candidate.luau restores the place.

Differences from the production-integration review injector (same Manifest walker):
  * production Main is mapped exactly as default.project.json maps it (enabled, no review boot);
  * the only non-production pieces are ServerScriptService.ProductionCandidate (CandidateConfig)
    and the client label; both live under tools/expansion1/production-candidate/;
  * the manifest names the dedicated review scripts the installer parks (never deletes), the
    service properties it applies (original values are recorded for the uninstaller), and a
    sha256 for every served file.

Safety: binds 127.0.0.1 only; GET only; serves only files mapped by the candidate project, each
under src/ or tools/expansion1/production-candidate/; read-only.
"""
import argparse
import hashlib
import http.server
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
PROJECT = "expansion1-production-candidate.project.json"
INSTALLER = os.path.join("tools", "expansion1", "install-production-candidate.luau")
UNINSTALLER = os.path.join("tools", "expansion1", "uninstall-production-candidate.luau")
DEFAULT_PORT = 34874

# Dedicated review boots that would add a second world / admission path. Moved to
# ServerStorage.PreProductionCandidateBackup by the installer and restored by the uninstaller.
PARK = [
    ["ServerScriptService", "AdventureReview"],
    ["ServerScriptService", "ExpansionReview"],
    ["ServerScriptService", "Adventure"],
    ["ServerScriptService", "ProductionReview"],
    ["ReplicatedStorage", "SpringVaultClient"],
    ["StarterPlayer", "StarterPlayerScripts", "AdventureReview"],
    ["StarterPlayer", "StarterPlayerScripts", "ProductionReviewClient"],
]

spec = importlib.util.spec_from_file_location("review_injector", os.path.join(HERE, "inject-production-review.py"))
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)
review.PROJECT = PROJECT
review.ALLOWED = [os.path.join(REPO, "src"), os.path.join(REPO, "tools", "expansion1", "production-candidate")]


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False).stdout.strip()
    except OSError:
        return ""


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def build():
    manifest = review.build_manifest()
    body = manifest.as_json()
    body["commit"] = git("rev-parse", "HEAD")
    body["branch"] = git("rev-parse", "--abbrev-ref", "HEAD")
    body["dirty"] = git("status", "--porcelain", "--", "src", "tools/expansion1", PROJECT) != ""
    body["park"] = PARK
    body["serviceProperties"] = body.pop("ignoredServiceProperties")
    body["files"] = {
        str(sid): {"path": os.path.relpath(path, REPO).replace(os.sep, "/"), "sha256": sha256(path)}
        for sid, path in manifest.files.items()
    }
    with open(os.path.join(REPO, "tools", "expansion1", "production-candidate", "CandidateConfig.luau"), encoding="utf-8") as f:
        body["candidateConfigSource"] = f.read()
    body["storageProfile"] = {
        "mode": "LocalOnly",
        "selectedBy": "CandidateProfile (src/server/Services), before Main creates remotes or initializes services",
        "consumers": [
            "DataService PlayerData_v1 (load, autosave, removal release, BindToClose)",
            "TrophyPendingStore TrophyPendingGrants_v1 (DurableOutbox)",
            "AdventureSettlement AdventureRewardIntents_v1 (DurableOutbox)",
            "MonetizationService PurchaseHistory_v1",
            "LeaderboardService all-time and weekly OrderedDataStores, request budget",
        ],
        "gate": "StorageGate is the only src/ module that references DataStoreService; LocalOnly never calls it",
    }
    return manifest, body


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write-manifest", metavar="FILE")
    args = parser.parse_args()
    manifest, body = build()
    print("commit %s (%s)%s" % (body["commit"], body["branch"], " DIRTY" if body["dirty"] else ""))
    print("roots installed:")
    for root in body["roots"]:
        print("  " + "/".join(root))
    print("parked if present:")
    for path in PARK:
        print("  " + "/".join(path))
    print("%d instances, %d sources" % (len(body["entries"]), len(body["files"])))
    for item in body["serviceProperties"]:
        print("service properties applied: %s %s" % ("/".join(item["path"]), json.dumps(item["properties"])))
    if args.write_manifest:
        slim = {k: v for k, v in body.items() if k != "entries"}
        slim["instances"] = [
            {"path": "/".join(e["path"]), "class": e["class"], "source": e["source"], "attributes": e["attributes"], "properties": e["properties"]}
            for e in body["entries"]
        ]
        with open(args.write_manifest, "w", encoding="utf-8") as f:
            json.dump(slim, f, indent=2)
        print("wrote " + args.write_manifest)
    if args.check:
        return 0

    base_handler = review.make_handler(manifest)

    class Handler(base_handler):
        def do_GET(self):
            route = self.path.split("?", 1)[0]
            if route == "/manifest.json":
                return self.send(200, json.dumps(body), "application/json")
            for name, rel in (("/installer.luau", INSTALLER), ("/uninstaller.luau", UNINSTALLER)):
                if route == name:
                    with open(os.path.join(REPO, rel), encoding="utf-8") as f:
                        return self.send(200, f.read(), "text/plain; charset=utf-8")
            return base_handler.do_GET(self)

    httpd = http.server.HTTPServer(("127.0.0.1", args.port), Handler)
    print("serving on http://127.0.0.1:%d (Ctrl+C to stop)" % args.port)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
