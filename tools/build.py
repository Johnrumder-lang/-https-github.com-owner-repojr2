#!/usr/bin/env python3
"""Pack src/ into a Roblox place file (.rbxlx) - no Rojo or Studio needed.

    python3 tools/build.py                 -> build/TheRandomStory.rbxlx
    python3 tools/build.py out.rbxlx

File naming follows Rojo: Foo.lua = ModuleScript, Foo.server.lua = Script,
Foo.client.lua = LocalScript, directories = Folder. Service properties that
the game relies on (gravity, lighting, no auto-loaded characters, ...) are
written below; everything else is built at runtime by the scripts.
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

# (class, properties, children-from-src?)
SERVICES = [
    ("Workspace", [
        ("bool", "StreamingEnabled", "false"),
        ("float", "FallenPartsDestroyHeight", "-4000"),
        # lower, Ultrakill-like gravity (Config.Player.gravity is applied at runtime too)
        ("float", "Gravity", "196.2"),
    ]),
    ("Players", [
        ("bool", "CharacterAutoLoads", "false"),
        ("float", "RespawnTime", "3"),
    ]),
    ("Lighting", [
        ("token", "Technology", "4"),
        ("bool", "GlobalShadows", "true"),
        ("float", "Brightness", "2.2"),
        ("float", "ClockTime", "14"),
        ("float", "EnvironmentDiffuseScale", "1"),
        ("float", "EnvironmentSpecularScale", "1"),
        ("float", "ShadowSoftness", "0.15"),
        ("float", "ExposureCompensation", "0"),
        ("Color3", "Ambient", (0.28, 0.28, 0.32)),
        ("Color3", "OutdoorAmbient", (0.5, 0.5, 0.55)),
    ]),
    ("ReplicatedFirst", []),
    ("ReplicatedStorage", []),
    ("ServerScriptService", []),
    ("ServerStorage", []),
    ("StarterGui", []),
    ("StarterPack", []),
    ("StarterPlayer", [
        ("token", "CameraMode", "0"),
        ("bool", "EnableMouseLockOption", "false"),
        ("bool", "CharacterUseJumpPower", "true"),
        ("bool", "LoadCharacterAppearance", "false"),
        ("bool", "AutoJumpEnabled", "false"),
    ]),
    ("SoundService", [("bool", "RespectFilteringEnabled", "true")]),
    ("Chat", []),
    ("TextChatService", []),
]
NESTED_SERVICES = {"StarterPlayer": ["StarterPlayerScripts", "StarterCharacterScripts"]}

_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%032X" % _ref[0]


def prop(kind, name, value):
    if kind == "Color3":
        r, g, b = value
        return f'<Color3 name="{name}"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>'
    return f'<{kind} name="{name}">{escape(str(value))}</{kind}>'


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, props, children, source=None, depth=1):
    tab = "\t" * depth
    out = [f'{tab}<Item class="{cls}" referent="{ref()}">', f"{tab}\t<Properties>"]
    out.append(f"{tab}\t\t" + prop("string", "Name", name))
    for p in props:
        out.append(f"{tab}\t\t" + prop(*p))
    if source is not None:
        out.append(f'{tab}\t\t<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    out.append(f"{tab}\t</Properties>")
    out.extend(children)
    out.append(f"{tab}</Item>")
    return "\n".join(out)


def script_class(fname):
    if fname.endswith(".server.lua"):
        return "Script", fname[: -len(".server.lua")]
    if fname.endswith(".client.lua"):
        return "LocalScript", fname[: -len(".client.lua")]
    if fname.endswith(".lua"):
        return "ModuleScript", fname[: -len(".lua")]
    return None, None


def tree(path, depth):
    """Items for everything inside directory `path`."""
    items = []
    if not os.path.isdir(path):
        return items
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            items.append(item("Folder", entry, [], tree(full, depth + 1), depth=depth))
        else:
            cls, name = script_class(entry)
            if cls:
                with open(full, encoding="utf-8") as f:
                    src = f.read()
                items.append(item(cls, name, [], [], source=src, depth=depth))
    return items


def build(out_path):
    parts = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        "\t<External>null</External>",
        "\t<External>nil</External>",
    ]
    count = 0
    for cls, props in SERVICES:
        children = []
        if cls == "Workspace":
            children.append(item("Terrain", "Terrain", [], [], depth=2))
        if cls in NESTED_SERVICES:
            for sub in NESTED_SERVICES[cls]:
                children.append(item(sub, sub, [], tree(os.path.join(SRC, cls, sub), 3), depth=2))
        else:
            children.extend(tree(os.path.join(SRC, cls), 2))
        parts.append(item(cls, cls, props, children, depth=1))
    parts.append("</roblox>")
    xml = "\n".join(parts) + "\n"
    count = xml.count('name="Source"')
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"wrote {out_path}: {count} scripts, {len(xml) // 1024} KB")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "TheRandomStory.rbxlx")
    build(out)
