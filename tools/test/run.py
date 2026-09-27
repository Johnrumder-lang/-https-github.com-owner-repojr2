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
    # extra stub files named in a "--@stubs a, b" header line (e.g. world_stubs)
    for line in open(test_path).read().split("\n")[:5]:
        if line.startswith("--@stubs"):
            for name in [n.strip() for n in line[len("--@stubs"):].split(",") if n.strip()]:
                parts.append(open(os.path.join(HERE, name + ".luau")).read())
    parts.append("local __mods, __cache = {}, {}")
    parts.append("local Shared = setmetatable({}, { __index = function(_, k) return { __mod = k } end })")
    parts.append("local __realrequire = require")
    parts.append("function require(m) local n = m.__mod; if __cache[n] == nil then __cache[n] = __mods[n]() end; return __cache[n] end")
    for f in sorted(os.listdir(SHARED)):
        if f.endswith(".lua"):
            name = f[:-4]
            src = open(os.path.join(SHARED, f)).read().replace("--!nonstrict", "")
            parts.append(f'__mods["{name}"] = function()\nlocal script = {{ Parent = Shared }}\n{src}\nend')
    # server modules named in a "--@server A, B" header line are bundled too
    # (their `script.Parent.X` resolves to other server modules, `.S` to the
    # test's own S stub registered as __mods["srv:S"])
    test_src = open(test_path).read()
    first = next((l for l in test_src.split("\n")[:5] if l.startswith("--@server")), "")
    if first.startswith("--@server"):
        parts.append('local Server = setmetatable({}, { __index = function(_, k) return { __mod = "srv:" .. k } end })')
        for name in [n.strip() for n in first[len("--@server"):].split(",") if n.strip()]:
            path = os.path.join(ROOT, "src", "ServerScriptService", "Server", name + ".lua")
            src = open(path).read().replace("--!nonstrict", "")
            src = src.replace('game:GetService("ReplicatedStorage"):WaitForChild("Shared")', "Shared")
            parts.append(f'__mods["srv:{name}"] = function()\nlocal script = {{ Parent = Server }}\n{src}\nend')
    parts.append("local script = { Parent = Shared }")
    parts.append(test_src)
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
