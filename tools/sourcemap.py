#!/usr/bin/env python3
"""Write sourcemap.json (Rojo format) for luau-lsp: python3 tools/sourcemap.py"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

def node(path, rel):
    out = []
    for e in sorted(os.listdir(path)):
        full = os.path.join(path, e)
        r = os.path.join(rel, e)
        if os.path.isdir(full):
            out.append({"name": e, "className": "Folder", "children": node(full, r)})
        elif e.endswith(".server.lua"):
            out.append({"name": e[:-11], "className": "Script", "filePaths": [r]})
        elif e.endswith(".client.lua"):
            out.append({"name": e[:-11], "className": "LocalScript", "filePaths": [r]})
        elif e.endswith(".lua"):
            out.append({"name": e[:-4], "className": "ModuleScript", "filePaths": [r]})
    return out

services = []
for svc in ["ReplicatedFirst", "ReplicatedStorage", "ServerScriptService"]:
    services.append({"name": svc, "className": svc, "children": node(os.path.join(SRC, svc), os.path.join("src", svc))})
sp = {"name": "StarterPlayer", "className": "StarterPlayer", "children": [
    {"name": "StarterPlayerScripts", "className": "StarterPlayerScripts", "children": node(os.path.join(SRC, "StarterPlayer/StarterPlayerScripts"), "src/StarterPlayer/StarterPlayerScripts")},
    {"name": "StarterCharacterScripts", "className": "StarterCharacterScripts", "children": []},
]}
services.append(sp)
json.dump({"name": "TheRandomStory", "className": "DataModel", "children": services}, open(os.path.join(ROOT, "sourcemap.json"), "w"), indent=1)
print("sourcemap.json written")
