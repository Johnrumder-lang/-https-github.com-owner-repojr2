#!/usr/bin/env python3
"""Bundle Shared modules + stubs + a test script and run it with the Luau CLI.

    python3 tools/test/run.py tools/test/beasts_test.luau [path/to/luau]
Modules are exposed as `script.Parent.<Name>` (ReplicatedStorage/Shared)."""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHARED = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared")
HERE = os.path.dirname(os.path.abspath(__file__))

def bundle(test_path):
    parts = [open(os.path.join(HERE, "stubs.luau")).read()]
    parts.append("local __mods, __cache = {}, {}")
    parts.append("local Shared = setmetatable({}, { __index = function(_, k) return { __mod = k } end })")
    parts.append("local __realrequire = require")
    parts.append("function require(m) local n = m.__mod; if __cache[n] == nil then __cache[n] = __mods[n]() end; return __cache[n] end")
    for f in sorted(os.listdir(SHARED)):
        if f.endswith(".lua"):
            name = f[:-4]
            src = open(os.path.join(SHARED, f)).read().replace("--!nonstrict", "")
            parts.append(f'__mods["{name}"] = function()\nlocal script = {{ Parent = Shared }}\n{src}\nend')
    parts.append("local script = { Parent = Shared }")
    parts.append(open(test_path).read())
    return "\n".join(parts)

if __name__ == "__main__":
    test = sys.argv[1]
    luau = sys.argv[2] if len(sys.argv) > 2 else "luau"
    out = os.path.join(os.environ.get("TMPDIR", "/tmp"), "trs_bundle.luau")
    open(out, "w").write(bundle(test))
    r = subprocess.run([luau, out], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    sys.exit(r.returncode)
