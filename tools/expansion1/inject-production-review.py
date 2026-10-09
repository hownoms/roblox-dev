#!/usr/bin/env python3
"""Serves the production-integration review sources to an open Roblox Studio (Edit mode).

docs/integration/production-review.md, "Inject into an open Expansion1Review place".

    python tools/expansion1/inject-production-review.py           serve on 127.0.0.1:34873
    python tools/expansion1/inject-production-review.py --port N  another port
    python tools/expansion1/inject-production-review.py --check   print the manifest, exit

Then paste tools/expansion1/install-production-review.luau into the Studio command bar (or GET
/installer.luau). The installer fetches /manifest.json and every /source/<id>, then creates the
instances and sets ModuleScript/Script.Source from the command bar's plugin context (loadstring is
not used anywhere).

Safety:
  * binds 127.0.0.1 only; GET only; no directory listing, no path parameters;
  * serves only the files mapped by expansion1-production-review.project.json, each of which must
    lie under src/ or tools/expansion1/production-review/ (checked at startup, re-checked per
    request), plus the installer;
  * read-only: nothing is written anywhere.
"""
import argparse
import http.server
import json
import os
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROJECT = "expansion1-production-review.project.json"
INSTALLER = os.path.join("tools", "expansion1", "install-production-review.luau")
ALLOWED = [os.path.join(REPO, "src"), os.path.join(REPO, "tools", "expansion1", "production-review")]
DEFAULT_PORT = 34873


def allowed(path):
    real = os.path.realpath(path)
    return any(real == root or real.startswith(root + os.sep) for root in map(os.path.realpath, ALLOWED))


class Manifest:
    def __init__(self):
        self.entries = []  # {path, class, source, properties, attributes}
        self.roots = []  # DataModel paths the installer replaces
        self.files = {}  # source id -> absolute path
        self.ignored = []  # service-level $properties the installer does not apply

    def add_file(self, abs_path):
        if not allowed(abs_path):
            raise SystemExit("refusing to serve %s: outside src/ and the review tools" % abs_path)
        sid = len(self.files) + 1
        self.files[sid] = abs_path
        return sid

    def entry(self, path, cls, abs_path=None, properties=None, attributes=None):
        self.entries.append(
            {
                "path": path,
                "class": cls,
                "source": self.add_file(abs_path) if abs_path else None,
                "properties": properties or {},
                "attributes": attributes or {},
            }
        )

    def add_fs(self, path, abs_path, properties, attributes):
        """Mirrors Rojo (and tests/tools/bundle.py) for .luau files and folders."""
        if os.path.isfile(abs_path):
            name = os.path.basename(abs_path)
            cls = "Script" if name.endswith(".server.luau") else "LocalScript" if name.endswith(".client.luau") else "ModuleScript"
            self.entry(path, cls, abs_path, properties, attributes)
            return
        files = sorted(os.listdir(abs_path))
        init = next((f for f in files if f in ("init.luau", "init.server.luau", "init.client.luau")), None)
        if init:
            cls = "Script" if ".server." in init else "LocalScript" if ".client." in init else "ModuleScript"
            self.entry(path, cls, os.path.join(abs_path, init), properties, attributes)
        else:
            self.entry(path, "Folder", None, properties, attributes)
        for f in files:
            full = os.path.join(abs_path, f)
            if os.path.isdir(full):
                self.add_fs(path + [f], full, None, None)
            elif f.endswith(".luau") and not f.startswith("init."):
                name = f[: -len(".luau")]
                for suffix in (".server", ".client"):
                    if name.endswith(suffix):
                        name = name[: -len(suffix)]
                self.add_fs(path + [name], full, None, None)

    def walk(self, node, path, inside_root):
        for name, child in node.items():
            if name.startswith("$"):
                continue
            here = path + [name]
            props = child.get("$properties")
            attrs = child.get("$attributes")
            if "$path" in child:
                if not inside_root:
                    self.roots.append(here)
                self.add_fs(here, os.path.join(REPO, child["$path"]), props, attrs)
                self.walk(child, here, True)
            elif "$className" in child:
                if not inside_root:
                    self.roots.append(here)
                self.entry(here, child["$className"], None, props, attrs)
                self.walk(child, here, True)
            else:
                # A service or an existing container (StarterPlayerScripts): never replaced.
                if props:
                    self.ignored.append({"path": here, "properties": props})
                self.walk(child, here, inside_root)

    def as_json(self):
        commit = ""
        try:
            commit = subprocess.run(
                ["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True, check=False
            ).stdout.strip()
        except OSError:
            pass
        return {
            "project": PROJECT,
            "commit": commit,
            "roots": self.roots,
            "entries": self.entries,
            "ignoredServiceProperties": self.ignored,
        }


def build_manifest():
    with open(os.path.join(REPO, PROJECT), encoding="utf-8") as f:
        project = json.load(f)
    m = Manifest()
    m.walk(project["tree"], [], False)
    return m


def make_handler(manifest):
    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "ProductionReviewInjector/1"

        def send(self, status, body, ctype):
            data = body.encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            route = self.path.split("?", 1)[0]
            if route == "/health":
                return self.send(200, "ok", "text/plain; charset=utf-8")
            if route == "/manifest.json":
                return self.send(200, json.dumps(manifest.as_json()), "application/json")
            if route == "/installer.luau":
                with open(os.path.join(REPO, INSTALLER), encoding="utf-8") as f:
                    return self.send(200, f.read(), "text/plain; charset=utf-8")
            if route.startswith("/source/"):
                tail = route[len("/source/") :]
                sid = int(tail) if tail.isdigit() else None
                path = manifest.files.get(sid)
                if path and allowed(path) and os.path.isfile(path):
                    with open(path, encoding="utf-8") as f:
                        return self.send(200, f.read(), "text/plain; charset=utf-8")
            return self.send(404, "not found", "text/plain; charset=utf-8")

        def refuse(self):
            self.send(405, "read-only", "text/plain; charset=utf-8")

        do_POST = do_PUT = do_DELETE = do_PATCH = refuse

        def log_message(self, fmt, *args):
            sys.stderr.write("[injector] " + (fmt % args) + "\n")

    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--check", action="store_true", help="print the manifest summary and exit")
    args = parser.parse_args()
    manifest = build_manifest()
    print("roots replaced by the installer:")
    for root in manifest.roots:
        print("  " + "/".join(root))
    print("%d instances, %d sources" % (len(manifest.entries), len(manifest.files)))
    for item in manifest.ignored:
        print("not applied (service properties): %s %s" % ("/".join(item["path"]), json.dumps(item["properties"])))
    if args.check:
        return 0
    httpd = http.server.HTTPServer(("127.0.0.1", args.port), make_handler(manifest))
    print("serving on http://127.0.0.1:%d (Ctrl+C to stop). Paste %s into the Studio command bar." % (args.port, INSTALLER))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
