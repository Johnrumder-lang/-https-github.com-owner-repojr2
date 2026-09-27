--!nonstrict
-- Weapon generation (loot), stats and cubic weapon models.
-- Model convention: PrimaryPart "Grip" at the hand (the origin), blade along +Y,
-- attachments "Base"/"Tip" on the grip, model attributes "TipY"/"BaseY".
-- The leading (cutting) edge of a swing faces -X, the blade flats face +-Z.
local Palette = require(script.Parent.Palette)
local Util = require(script.Parent.Util)

local Weapons = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local PI = math.pi

Weapons.TYPES = {
	Sword = { dmg = 1.0, interval = 0.42, reach = 8.5, arc = 125, posture = 12, noun = { "Sword", "Longsword", "Blade", "Shortsword", "Sabre" } },
	Katana = { dmg = 0.84, interval = 0.33, reach = 9, arc = 115, posture = 9, noun = { "Katana", "Odachi", "Tachi", "Edge" } },
	Greatsword = { dmg = 1.75, interval = 0.72, reach = 11, arc = 155, posture = 26, noun = { "Greatsword", "Claymore", "Zweihander", "Cleaver" } },
	Axe = { dmg = 1.35, interval = 0.55, reach = 8.5, arc = 120, posture = 18, noun = { "Axe", "Hatchet", "Greataxe", "Reaver" } },
	Spear = { dmg = 1.05, interval = 0.46, reach = 12.5, arc = 60, posture = 12, noun = { "Spear", "Halberd", "Glaive", "Pike" } },
	Scythe = { dmg = 1.22, interval = 0.56, reach = 11, arc = 210, posture = 14, noun = { "Scythe", "Reaper", "Harvester" } },
	Dagger = { dmg = 0.64, interval = 0.24, reach = 7, arc = 95, posture = 6, crit = 0.15, noun = { "Dagger", "Kris", "Stiletto", "Fang" } },
	Hammer = { dmg = 1.6, interval = 0.7, reach = 9.5, arc = 135, posture = 32, noun = { "Hammer", "Maul", "Warhammer", "Mace" } },
}
Weapons.TYPE_LIST = { "Sword", "Katana", "Greatsword", "Axe", "Spear", "Scythe", "Dagger", "Hammer" }

Weapons.RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Divine" }
Weapons.RARITY = {
	Common = { mult = 1.0, affixes = 0, weight = 60 },
	Uncommon = { mult = 1.16, affixes = 1, weight = 26 },
	Rare = { mult = 1.34, affixes = 2, weight = 10 },
	Epic = { mult = 1.58, affixes = 2, element = true, weight = 3.2 },
	Legendary = { mult = 1.9, affixes = 3, element = true, weight = 0.75 },
	Divine = { mult = 2.35, affixes = 4, element = true, weight = 0.05 },
}

local PREFIX = {
	Common = { "Rusted", "Chipped", "Old", "Iron", "Plain", "Worn", "Bent" },
	Uncommon = { "Steel", "Sharp", "Tempered", "Hunter's", "Soldier's", "Balanced" },
	Rare = { "Moonfang", "Silverleaf", "Kingsguard", "Stormforged", "Bloodied", "Ashen" },
	Epic = { "Nightbloom", "Wyrmbone", "Starfall", "Grave-Kissed", "Hollowheart", "Emberveil" },
	Legendary = { "Worldsplitter", "Chronoblade", "Sunderer's", "Eclipse", "Oathbreaker", "Titanfell" },
	Divine = { "Heaven-Rending", "Godslayer", "Primordial", "Unwritten" },
}
local SUFFIX = {
	Fire = { "of Cinders", "of the Pyre", "of Burning Oaths" },
	Frost = { "of Winter", "of the Pale Moon", "of Stillness" },
	Void = { "of the Void", "of Nothing", "of the Abyss" },
	Holy = { "of Dawn", "of the Choir", "of Mercy" },
	Blood = { "of Hunger", "of the Red Tide", "of Thirst" },
	Storm = { "of Thunder", "of the Gale", "of Storms" },
}
Weapons.ELEMENTS = { "Fire", "Frost", "Void", "Holy", "Blood", "Storm" }

Weapons.AFFIXES = {
	crit = { "Crit chance", function(rng, lv) return rng:float(0.05, 0.14) end },
	lifesteal = { "Lifesteal", function(rng, lv) return rng:float(0.02, 0.06) end },
	speed = { "Attack speed", function(rng, lv) return rng:float(0.05, 0.16) end },
	posture = { "Posture damage", function(rng, lv) return rng:float(0.15, 0.4) end },
	reach = { "Reach", function(rng, lv) return rng:float(0.6, 1.6) end },
	chrono = { "Frozen-time damage", function(rng, lv) return rng:float(0.15, 0.4) end },
	execute = { "Damage vs. wounded", function(rng, lv) return rng:float(0.1, 0.3) end },
}
local AFFIX_KEYS = { "crit", "lifesteal", "speed", "posture", "reach", "chrono", "execute" }

-- ------------------------------------------------------------------ bases
-- Named variants inside the 8 combat TYPES. Each has its own model and small
-- stat tweaks (mods: dmg/interval/posture are fractions, reach/arc/crit add).
-- Saved items without `base` fall back to their type's classic base.
Weapons.BASES = {}
Weapons.BASE_ORDER = {}
Weapons.KIND_BASES = {}
local CLASSIC = {}
local function wbase(id: string, kind: string, noun: { string }, minL: number, mods, opts)
	opts = opts or {}
	local b = { id = id, kind = kind, name = noun[1], noun = noun, minL = minL, mods = mods or {}, weight = opts.weight or 2, unique = opts.unique, desc = opts.desc }
	Weapons.BASES[id] = b
	table.insert(Weapons.BASE_ORDER, id)
	if not opts.unique then
		Weapons.KIND_BASES[kind] = Weapons.KIND_BASES[kind] or {}
		table.insert(Weapons.KIND_BASES[kind], b)
	end
	if opts.classic then
		CLASSIC[kind] = id
		b.weight = opts.weight or 3
	end
	return b
end
-- swords
wbase("Longsword", "Sword", { "Longsword", "Sword", "Blade" }, 1, nil, { classic = true })
wbase("ArmingSword", "Sword", { "Arming Sword", "Shortsword" }, 1, { interval = -0.08, reach = -0.5, dmg = -0.04 }, { desc = "Quick, light blade" })
wbase("Falchion", "Sword", { "Falchion", "Chopper" }, 3, { dmg = 0.08, interval = 0.06, posture = 0.1 }, { desc = "Heavy chopping edge" })
wbase("Sabre", "Sword", { "Sabre", "Cutlass" }, 5, { interval = -0.1, dmg = -0.05, arc = 15 }, { desc = "Curved, sweeping cuts" })
wbase("BastardSword", "Sword", { "Bastard Sword", "Hand-and-a-Half" }, 8, { dmg = 0.1, interval = 0.1, reach = 0.6, posture = 0.1 }, { desc = "Long grip, longer reach" })
wbase("Estoc", "Sword", { "Estoc", "Tuck" }, 12, { reach = 1.2, dmg = -0.06, arc = -25, crit = 0.05 }, { desc = "Armour-piercing thrusts" })
-- katanas
wbase("Katana", "Katana", { "Katana", "Tachi", "Edge" }, 1, nil, { classic = true })
wbase("Wakizashi", "Katana", { "Wakizashi", "Kodachi" }, 2, { interval = -0.12, reach = -1.0, dmg = -0.08, crit = 0.03 }, { desc = "Short and swift" })
wbase("Nodachi", "Katana", { "Nodachi", "Odachi" }, 9, { dmg = 0.12, interval = 0.12, reach = 1.2, arc = 15 }, { desc = "Towering field blade" })
-- greatswords
wbase("Zweihander", "Greatsword", { "Zweihander", "Greatsword" }, 1, nil, { classic = true })
wbase("Claymore", "Greatsword", { "Claymore", "Highland Blade" }, 4, { interval = -0.06, dmg = -0.03 }, { desc = "Balanced for a greatsword" })
wbase("Executioner", "Greatsword", { "Executioner's Blade", "Headsman's Sword" }, 10, { dmg = 0.14, interval = 0.12, reach = -0.6, posture = 0.15 }, { desc = "No point. Only verdicts." })
wbase("Flamberge", "Greatsword", { "Flamberge", "Flame-Blade" }, 15, { dmg = 0.05, posture = 0.2, arc = 10 }, { desc = "Wavy edge tears posture" })
-- axes
wbase("WarAxe", "Axe", { "War Axe", "Axe", "Hatchet" }, 1, nil, { classic = true })
wbase("BeardedAxe", "Axe", { "Bearded Axe", "Skeggox" }, 2, { posture = 0.12, reach = 0.3 }, { desc = "Hooking beard" })
wbase("Cleaver", "Axe", { "Cleaver", "Butcher's Axe" }, 5, { interval = -0.1, dmg = -0.06, reach = -0.6, crit = 0.03 }, { desc = "Short, fast hacks" })
wbase("DoubleAxe", "Axe", { "Double Axe", "Labrys", "Reaver" }, 11, { dmg = 0.12, interval = 0.12, arc = 20, posture = 0.1 }, { desc = "Two heads, no mercy" })
-- spears
wbase("Spear", "Spear", { "Spear", "Lance" }, 1, nil, { classic = true })
wbase("Partisan", "Spear", { "Partisan", "Boar Spear" }, 3, { posture = 0.2, dmg = 0.05, interval = 0.04 }, { desc = "Broad head with flukes" })
wbase("Glaive", "Spear", { "Glaive", "Fauchard" }, 6, { arc = 30, dmg = 0.05, interval = 0.06, reach = -0.4 }, { desc = "Pole-mounted cleaving blade" })
wbase("Halberd", "Spear", { "Halberd", "Poleaxe" }, 9, { dmg = 0.12, interval = 0.12, arc = 25, posture = 0.15 }, { desc = "Axe, spike and hook" })
wbase("Pike", "Spear", { "Pike", "Ranseur" }, 13, { reach = 1.8, dmg = -0.08, interval = 0.04, arc = -15 }, { desc = "Outreaches everything" })
-- scythes
wbase("Scythe", "Scythe", { "Scythe", "Reaper", "Harvester" }, 1, nil, { classic = true })
wbase("WarScythe", "Scythe", { "War Scythe", "Bill" }, 7, { reach = 0.8, arc = -30, interval = -0.06 }, { desc = "Straightened for war" })
wbase("GraveScythe", "Scythe", { "Grave Scythe", "Twin Reaper" }, 14, { dmg = 0.12, interval = 0.12, posture = 0.1 }, { desc = "It has taken many" })
-- daggers
wbase("Seax", "Dagger", { "Seax", "Dagger", "Fang" }, 1, nil, { classic = true })
wbase("Stiletto", "Dagger", { "Stiletto", "Needle" }, 2, { crit = 0.05, dmg = -0.08, reach = 0.3 }, { desc = "Finds the gaps" })
wbase("ParryingDagger", "Dagger", { "Parrying Dagger", "Main-Gauche" }, 5, { posture = 0.3, interval = 0.05 }, { desc = "Built to catch blades" })
wbase("Kris", "Dagger", { "Kris", "Serpent Blade" }, 9, { dmg = 0.06, crit = 0.03, interval = 0.04 }, { desc = "Wavy, wicked wounds" })
-- hammers
wbase("Warhammer", "Hammer", { "Warhammer", "Hammer" }, 1, nil, { classic = true })
wbase("FlangedMace", "Hammer", { "Flanged Mace", "Mace" }, 2, { interval = -0.08, dmg = -0.06, posture = 0.15 }, { desc = "Flanges bite into plate" })
wbase("MorningStar", "Hammer", { "Morning Star", "Holy Water Sprinkler" }, 5, { dmg = 0.06, crit = 0.02 }, { desc = "Spiked head" })
wbase("Warpick", "Hammer", { "Warpick", "Crowbill" }, 8, { crit = 0.06, posture = -0.1, dmg = 0.04, reach = 0.3 }, { desc = "Punches through armour" })
wbase("Maul", "Hammer", { "Great Maul", "Maul" }, 14, { dmg = 0.14, interval = 0.14, posture = 0.2, reach = 0.4 }, { desc = "A wall on a stick" })
-- story weapons (never rolled randomly)
wbase("PitBlade", "Sword", { "Old Sword" }, 999, nil, { unique = true })
wbase("CrownOfDawn", "Sword", { "Crown of Dawn" }, 999, nil, { unique = true })
wbase("TitanFang", "Greatsword", { "Titan Fang" }, 999, nil, { unique = true })
wbase("HollowEdge", "Katana", { "Hollow Edge" }, 999, nil, { unique = true })
Weapons.CLASSIC = CLASSIC
local UNIQUE_BASE = { PitBlade = "PitBlade", RoyalRelic = "CrownOfDawn", TitanFang = "TitanFang", HollowEdge = "HollowEdge" }

-- The base an item uses (works for saved items without the field).
function Weapons.baseOf(item)
	local kind = item.kind or "Sword"
	local b = item.base and Weapons.BASES[item.base]
	if b and b.kind == kind then
		return b
	end
	local u = item.unique and UNIQUE_BASE[item.unique]
	if u and Weapons.BASES[u].kind == kind then
		return Weapons.BASES[u]
	end
	return Weapons.BASES[CLASSIC[kind] or "Longsword"]
end

function Weapons.pickBase(rng, kind: string, level: number)
	local entries = {}
	for _, b in Weapons.KIND_BASES[kind] or {} do
		if b.minL <= (level or 1) + 2 then
			table.insert(entries, { b, b.weight })
		end
	end
	if #entries == 0 then
		return Weapons.BASES[CLASSIC[kind] or "Longsword"]
	end
	return rng:weighted(entries)
end

local counter = 0
local function newId(rng)
	counter += 1
	return string.format("w%x%x%x", rng:int(0, 0xFFFFFF), counter, math.floor(os.clock() * 1000) % 0xFFFF)
end

-- Rolls a random weapon. opts: {type, base, rarity, minRarity, element, unique, name}
function Weapons.roll(rng, level: number, opts)
	opts = opts or {}
	local rarity = opts.rarity
	if not rarity then
		local entries = {}
		local minIdx = table.find(Weapons.RARITIES, opts.minRarity or "Common") or 1
		for i, r in Weapons.RARITIES do
			if i >= minIdx then
				local w = Weapons.RARITY[r].weight
				-- deeper content shifts the odds upward a bit
				w *= 1 + math.max(0, level - 1) * 0.02 * (i - 1)
				table.insert(entries, { r, w })
			end
		end
		rarity = rng:weighted(entries)
	end
	local b = opts.base and Weapons.BASES[opts.base]
	local kind = (b and b.kind) or opts.type or rng:pick(Weapons.TYPE_LIST)
	if not b or b.kind ~= kind then
		b = Weapons.pickBase(rng, kind, level)
	end
	local R = Weapons.RARITY[rarity]
	local T = Weapons.TYPES[kind]
	local item = {
		id = newId(rng),
		kind = kind,
		base = b.id,
		rarity = rarity,
		level = level,
		dmg = T.dmg * R.mult * (1 + 0.085 * (level - 1)),
		affix = {},
		shape = rng:int(1, 1000000),
	}
	local keys = rng:shuffle(table.clone(AFFIX_KEYS))
	for i = 1, R.affixes do
		local k = keys[i]
		item.affix[k] = Weapons.AFFIXES[k][2](rng, level)
	end
	if R.element or opts.element then
		item.element = opts.element or rng:pick(Weapons.ELEMENTS)
	end
	-- colours
	local metal = rng:pick({ Palette.metal.iron, Palette.metal.steel, Palette.metal.silver, Palette.metal.dark, Palette.metal.bronze })
	if rarity == "Legendary" or rarity == "Divine" then
		metal = rng:pick({ Palette.metal.silver, Palette.metal.gold, rgb(30, 30, 36), rgb(240, 240, 250) })
	end
	local accent = if item.element then Palette.element[item.element] else Palette.rarity[rarity]
	item.colors = {
		blade = Util.arr(metal),
		guard = Util.arr(rng:pick({ Palette.metal.gold, Palette.metal.iron, Palette.metal.bronze, Palette.metal.dark, Palette.metal.silver })),
		grip = Util.arr(rng:pick({ rgb(70, 44, 30), rgb(30, 26, 26), rgb(110, 30, 30), rgb(40, 50, 90), rgb(90, 70, 50) })),
		accent = Util.arr(accent),
	}
	local prefix = rng:pick(PREFIX[rarity])
	local noun = rng:pick(b.noun)
	item.name = prefix .. " " .. noun
	if item.element and rng:chance(0.8) then
		item.name ..= " " .. rng:pick(SUFFIX[item.element])
	end
	if opts.unique then
		item.unique = opts.unique
	end
	if opts.name then
		item.name = opts.name
	end
	return item
end

-- Hand-made story weapons.
function Weapons.unique(id: string, level: number)
	local rng = (require(script.Parent.RNG)).new(#id * 7919 + level)
	if id == "PitBlade" then
		local w = Weapons.roll(rng, level, { type = "Sword", base = "PitBlade", rarity = "Uncommon", name = "Blade of the Forgotten Pit" })
		w.colors.blade = Util.arr(rgb(150, 110, 90))
		w.colors.accent = Util.arr(rgb(200, 170, 255))
		w.affix = { chrono = 0.2 }
		w.unique = id
		w.desc = "Found beside a nameless skeleton at the bottom of the Abyss."
		return w
	elseif id == "RoyalRelic" then
		local w = Weapons.roll(rng, level, { type = "Sword", base = "CrownOfDawn", rarity = "Legendary", element = "Holy", name = "Crown of Dawn" })
		w.colors.blade = Util.arr(rgb(250, 240, 210))
		w.colors.guard = Util.arr(Palette.metal.gold)
		w.unique = id
		w.desc = "The spared king's gift. It remembers mercy."
		return w
	elseif id == "TitanFang" then
		local w = Weapons.roll(rng, level, { type = "Greatsword", base = "TitanFang", rarity = "Epic", element = "Blood", name = "Fang of the Kingdom-Eater" })
		w.colors.blade = Util.arr(rgb(235, 225, 200))
		w.unique = id
		w.desc = "Carved from the titan that stepped on you."
		return w
	elseif id == "HollowEdge" then
		local w = Weapons.roll(rng, level, { type = "Katana", base = "HollowEdge", rarity = "Divine", element = "Void", name = "Hollow Edge" })
		w.colors.blade = Util.arr(rgb(18, 16, 22))
		w.colors.accent = Util.arr(rgb(255, 30, 40))
		w.unique = id
		w.desc = "It was always yours. It just wasn't facing the right way."
		return w
	end
	return Weapons.roll(rng, level)
end

-- Effective numbers used by the server combat code.
function Weapons.stats(item)
	local T = Weapons.TYPES[item.kind] or Weapons.TYPES.Sword
	local m = (Weapons.baseOf(item) or {}).mods or {}
	local a = item.affix or {}
	return {
		dmg = (item.dmg or 1) * (1 + (m.dmg or 0)) * (1 + 0.08 * (item.up or 0)),
		interval = T.interval * (1 + (m.interval or 0)) / (1 + (a.speed or 0)),
		reach = T.reach + (m.reach or 0) + (a.reach or 0),
		arc = T.arc + (m.arc or 0),
		posture = T.posture * (1 + (m.posture or 0)) * (1 + (a.posture or 0)),
		crit = 0.05 + (T.crit or 0) + (m.crit or 0) + (a.crit or 0),
		lifesteal = a.lifesteal or 0,
		chrono = a.chrono or 0,
		execute = a.execute or 0,
		element = item.element,
	}
end

local function modLine(b): string?
	local m = b.mods or {}
	local parts = {}
	local function pct(k, label, invert)
		local v = m[k]
		if v and math.abs(v) > 0.001 then
			local shown = if invert then -v else v
			table.insert(parts, string.format("%s %s%d%%", label, if shown > 0 then "+" else "-", math.floor(math.abs(shown) * 100 + 0.5)))
		end
	end
	pct("dmg", "Damage")
	pct("interval", "Speed", true)
	if m.reach and math.abs(m.reach) > 0.01 then
		table.insert(parts, string.format("Reach %s%.1f", if m.reach > 0 then "+" else "-", math.abs(m.reach)))
	end
	pct("posture", "Posture")
	if m.crit and m.crit > 0 then
		table.insert(parts, string.format("Crit +%d%%", math.floor(m.crit * 100 + 0.5)))
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, "  ")
end

function Weapons.describe(item): { string }
	local s = Weapons.stats(item)
	local b = Weapons.baseOf(item)
	local label = item.kind or "Sword"
	if b and b.name ~= label and not b.unique then
		label = b.name .. " (" .. label .. ")"
	end
	local lines = {
		string.format("%s %s  ·  Lv %d%s", item.rarity, label, item.level, if (item.up or 0) > 0 then "  ·  +" .. item.up else ""),
		string.format("Power %.0f   Speed %.2fs   Reach %.1f", s.dmg * 100, s.interval, s.reach),
	}
	if b and not b.unique then
		local ml = modLine(b)
		if ml then
			table.insert(lines, (b.desc or b.name) .. ": " .. ml)
		end
	end
	for k, v in item.affix or {} do
		local def = Weapons.AFFIXES[k]
		if def then
			table.insert(lines, string.format("+%s %s", if k == "reach" then string.format("%.1f", v) else string.format("%d%%", math.floor(v * 100 + 0.5)), def[1]))
		end
	end
	if item.element then
		table.insert(lines, item.element .. " infused")
	end
	if item.desc then
		table.insert(lines, "\"" .. item.desc .. "\"")
	end
	return lines
end

function Weapons.score(item): number
	local s = Weapons.stats(item)
	return s.dmg / s.interval * (1 + s.crit * 0.75) * (1 + s.lifesteal) * (1 + s.chrono * 0.3)
end

-- ------------------------------------------------------------------ model kit
local RUST = rgb(124, 78, 50)
local GOLD = Palette.metal.gold
local SILVER = Palette.metal.silver
local WOODS = { rgb(92, 62, 40), rgb(70, 48, 32), rgb(110, 76, 48), rgb(60, 42, 32), rgb(84, 58, 44) }
local ELEMENT_TINT = {
	Fire = { rgb(70, 42, 36), 0.25 },
	Frost = { rgb(205, 228, 244), 0.25 },
	Void = { rgb(36, 26, 52), 0.5 },
	Holy = { rgb(250, 240, 214), 0.3 },
	Blood = { rgb(92, 26, 30), 0.3 },
	Storm = { rgb(150, 170, 205), 0.2 },
}
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local ELEMENT_FX = {
	Fire = { tex = "rbxasset://textures/particles/fire_main.dds", rate = 9, life = { 0.25, 0.55 }, speed = { 0.2, 0.8 }, acc = V(0, 3.5, 0), size = 0.26, emit = 1 },
	Frost = { tex = SPARK, rate = 5, life = { 0.7, 1.3 }, speed = { 0.05, 0.25 }, acc = V(0, -0.8, 0), size = 0.14, emit = 0.8 },
	Void = { tex = SPARK, rate = 7, life = { 0.5, 1.0 }, speed = { 0.1, 0.4 }, acc = V(0, 0.6, 0), size = 0.2, emit = 0.5 },
	Holy = { tex = SPARK, rate = 7, life = { 0.5, 1.0 }, speed = { 0.2, 0.6 }, acc = V(0, 1.2, 0), size = 0.16, emit = 1 },
	Blood = { tex = SPARK, rate = 5, life = { 0.4, 0.8 }, speed = { 0, 0.1 }, acc = V(0, -7, 0), size = 0.1, emit = 0.3 },
	Storm = { tex = SPARK, rate = 10, life = { 0.06, 0.18 }, speed = { 1.5, 3.5 }, acc = V(0, 0, 0), size = 0.2, emit = 1 },
}

local function grey(c: Color3, k: number): Color3
	local g = (c.R + c.G + c.B) / 3
	return c:Lerp(Color3.new(g, g, g), k)
end
local function warm(c: Color3): boolean
	return c.R > c.B * 1.35 and c.R > 0.35
end
local shade = Util.shade

local function basePart(cls: string, model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, mat)
	local p = Instance.new(cls)
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = V(math.max(size.X, 0.01), math.max(size.Y, 0.01), math.max(size.Z, 0.01))
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.Metal
	p.CastShadow = false
	p.Parent = model
	return p
end

-- A builder context: colours/materials resolved from rarity + element, and
-- primitive helpers that all work in unscaled model space (grip at origin).
local function newKit(model: Model, item)
	local K: any = { model = model, zones = {}, n = 0 }
	local rare = table.find(Weapons.RARITIES, item.rarity or "Common") or 1
	K.rare = rare
	K.el = item.element
	local shape = item.shape or 1
	K.v = shape % 3
	K.h = math.floor(shape / 3) % 8
	local c = item.colors or {}
	local blade = Util.c3(c.blade or { 0.7, 0.72, 0.76 })
	local guard = Util.c3(c.guard or { 0.6, 0.5, 0.3 })
	local gripC = Util.c3(c.grip or { 0.3, 0.2, 0.15 })
	local accent = Util.c3(c.accent or { 1, 1, 1 })
	local bladeMat, guardMat = M.Metal, M.Metal
	if rare <= 2 and not item.unique then
		blade = grey(blade, 0.85)
		guard = grey(guard, 0.45)
	end
	if rare == 1 then
		-- rusty, chipped commons
		blade = shade(blade:Lerp(RUST, 0.4), 0.8)
		guard = shade(guard:Lerp(RUST, 0.5), 0.72)
		bladeMat, guardMat = M.CorrodedMetal, M.CorrodedMetal
	end
	if K.el and rare >= 4 and ELEMENT_TINT[K.el] then
		local t = ELEMENT_TINT[K.el]
		blade = blade:Lerp(t[1], t[2])
	end
	K.blade = blade
	K.bladeMat = bladeMat
	K.edge = if rare == 1 then blade:Lerp(rgb(176, 170, 162), 0.35) else shade(blade, 1.28):Lerp(rgb(250, 250, 255), 0.12)
	K.dark = shade(blade, 0.62)
	K.guard = guard
	K.guardMat = guardMat
	K.guardDark = shade(guard, 0.72)
	K.gripC = gripC
	K.wood = WOODS[(K.h % #WOODS) + 1]
	if rare == 1 then
		K.wood = shade(K.wood, 0.85)
	end
	K.accent = accent
	K.inlay = if warm(guard) then GOLD else SILVER
	K.glow = accent
	K.glowing = rare >= 4 or K.el ~= nil
	-- divine bevels are light itself
	K.edgeMat = if rare >= 6 then M.Neon else bladeMat
	if rare >= 6 then
		K.edge = accent:Lerp(rgb(255, 255, 255), 0.55)
	end
	K.chipped = rare == 1

	function K.box(name, size, cf, col, mat)
		K.n += 1
		return basePart("Part", model, name, size, cf, col or K.blade, mat or K.bladeMat)
	end
	function K.wedge(name, size, cf, col, mat)
		K.n += 1
		return basePart("WedgePart", model, name, size, cf, col or K.blade, mat or K.bladeMat)
	end
	-- cylinder whose axis follows cf's Y axis
	function K.cyl(name, len, dia, cf, col, mat)
		local p = K.box(name, V(len, dia, dia), cf * ANG(0, 0, PI / 2), col, mat)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	function K.ball(name, d, cf, col, mat)
		local p = K.box(name, V(d, d, d), cf, col, mat)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- Triangle plate in the frame's XY plane: base on y = 0 from x0..x1, apex at (xa, h).
	function K.tri(name, frame: CFrame, x0: number, x1: number, xa: number, h: number, t: number, col, mat)
		if h < 0 then
			frame = frame * ANG(0, 0, PI)
			x0, x1, xa, h = -x1, -x0, -xa, -h
		end
		if x0 > x1 then
			x0, x1 = x1, x0
		end
		xa = math.clamp(xa, x0, x1)
		if xa - x0 > 0.005 then
			local w = xa - x0
			K.wedge(name, V(t, h, w), frame * CF(xa - w / 2, h / 2, 0) * ANG(0, PI / 2, 0), col, mat)
		end
		if x1 - xa > 0.005 then
			local w = x1 - xa
			K.wedge(name, V(t, h, w), frame * CF(xa + w / 2, h / 2, 0) * ANG(0, -PI / 2, 0), col, mat)
		end
	end
	-- Sharp bevelled edge along frame Y (y0..y1): thickness t at x = xIn, sharp at x = xOut.
	function K.edgeBevel(name, frame: CFrame, xIn: number, xOut: number, y0: number, y1: number, t: number, col, mat, zc: number?)
		local sx = if xOut > xIn then 1 else -1
		local b = math.abs(xOut - xIn)
		if b < 0.005 then
			return
		end
		for _, sz in { 1, -1 } do
			local Y = V(sx, 0, 0)
			local Z = V(0, 0, -sz)
			local X = Y:Cross(Z)
			local pos = V(xIn + sx * b / 2, (y0 + y1) / 2, (zc or 0) + sz * t / 4)
			K.wedge(name, V(y1 - y0, b, t / 2), frame * CFrame.fromMatrix(pos, X, Y, Z), col or K.edge, mat or K.edgeMat)
		end
	end
	-- Register a flat area on both faces that can carry engraving / glowing runes.
	function K.zone(cf: CFrame, len: number, w: number, z: number)
		table.insert(K.zones, { cf = cf, len = len, w = w, z = z })
	end
	function K.setFx(p: BasePart)
		K.fx = p
	end

	-- Straight blade (or one segment of a curved one) along frame Y.
	-- o: frame, y0, len, w, t, b (bevel width), fuller (fraction of len), fw, fx,
	--    single (1 = spine on +X / edge on -X, -1 = the reverse), point (height),
	--    apex (x of the point), noZone, col, mat, zoneK
	function K.forge(o)
		local fr = o.frame or CF()
		local y0, L, w, t = o.y0 or 0, o.len, o.w, o.t
		local hw = w / 2
		local b = math.min(o.b or 0.1, hw)
		local col, mat = o.col or K.blade, o.mat or K.bladeMat
		local cL, cR = -(hw - b), hw - b
		if o.single == 1 then
			cR = hw
		elseif o.single == -1 then
			cL = -hw
		end
		local coreW = cR - cL
		local main
		local Lf = L * (o.fuller or 0)
		if Lf > 0.1 and coreW > 0.12 then
			local fw = math.min(o.fw or coreW * 0.3, coreW * 0.6)
			local fx = o.fx or (cL + cR) / 2
			local f0 = y0 + (o.fullerStart or 0.1)
			local f1 = math.min(f0 + Lf, y0 + L - 0.05)
			local tf = t * 0.55
			main = K.box("Fuller", V(fw + 0.02, f1 - f0, tf), fr * CF(fx, (f0 + f1) / 2, 0), shade(col, 0.74), mat)
			local l1, r1 = (fx - fw / 2) - cL, cR - (fx + fw / 2)
			if l1 > 0.01 then
				K.box("Blade", V(l1, f1 - f0, t), fr * CF(cL + l1 / 2, (f0 + f1) / 2, 0), col, mat)
			end
			if r1 > 0.01 then
				K.box("Blade", V(r1, f1 - f0, t), fr * CF(cR - r1 / 2, (f0 + f1) / 2, 0), col, mat)
			end
			if f0 > y0 + 0.01 then
				K.box("Blade", V(coreW, f0 - y0, t), fr * CF((cL + cR) / 2, (y0 + f0) / 2, 0), col, mat)
			end
			if y0 + L > f1 + 0.01 then
				K.box("Blade", V(coreW, y0 + L - f1, t), fr * CF((cL + cR) / 2, (f1 + y0 + L) / 2, 0), col, mat)
			end
			if not o.noZone then
				K.zone(fr * CF(fx, (f0 + f1) / 2, 0), (f1 - f0) * (o.zoneK or 0.86), fw, tf / 2)
			end
		elseif coreW > 0.01 then
			main = K.box("Blade", V(coreW, L, t), fr * CF((cL + cR) / 2, y0 + L / 2, 0), col, mat)
			if not o.noZone then
				K.zone(fr * CF((cL + cR) / 2, y0 + L * 0.42, 0), L * 0.55 * (o.zoneK or 1), coreW * 0.5, t / 2)
			end
		end
		-- bevelled edges (commons get a chipped, uneven bevel)
		local function edge(xIn, xOut)
			if K.chipped and L > 0.8 then
				local cuts = { 0, 0.34, 0.58, 1 }
				for i = 1, 3 do
					local k = if i == 2 then 0.55 else 1
					K.edgeBevel("Edge", fr, xIn, xIn + (xOut - xIn) * k, y0 + L * cuts[i], y0 + L * cuts[i + 1], t)
				end
			else
				K.edgeBevel("Edge", fr, xIn, xOut, y0, y0 + L, t)
			end
		end
		if o.single ~= 1 then
			edge(cL, -hw)
		end
		if o.single ~= -1 then
			edge(cR, hw)
		end
		if main and not K.fx then
			K.fx = main
		end
		local top = y0 + L
		local ph = o.point or 0
		if ph > 0 then
			if K.chipped and not o.keepPoint then
				ph *= 0.8
			end
			local xa = o.apex or 0
			local tip = if K.rare >= 6 then K.edge else col:Lerp(K.edge, 0.4)
			K.tri("Tip", fr * CF(0, top, 0), -hw, hw, xa, ph, t * 0.5, tip, if K.rare >= 6 then M.Neon else mat)
			-- raised centre ridge on the point (stepped bevel)
			local ix0, ix1 = -hw + b * 0.8, hw - b * 0.8
			if o.single == 1 then
				ix1 = hw
			elseif o.single == -1 then
				ix0 = -hw
			end
			local ia = math.clamp(xa, ix0 + 0.01, ix1 - 0.01)
			K.tri("Tip", fr * CF(0, top - 0.01, 0), ix0, ix1, ia, ph * 0.72, t * 0.9, col, mat)
		end
		return top + ph
	end

	-- Leather wrap bands along the grip (y0..y1).
	function K.wraps(y0: number, y1: number, n: number, w: number, col: Color3?, mat)
		col = col or K.gripC
		local c2 = shade(col, 0.8)
		local pitch = (y1 - y0) / n
		for i = 0, n - 1 do
			local y = y0 + pitch * (i + 0.5)
			-- overlapping diagonal leather bands, alternating lean and tone
			K.box("Wrap", V(w, pitch * 0.62, w - 0.02), CF(0, y, 0) * ANG(0, 0, if i % 2 == 0 then 0.13 else -0.13), if i % 2 == 0 then col else c2, mat or M.Leather)
		end
	end

	-- A gem in a metal setting, facing the frame's -Z (and +Z when both).
	function K.gem(cf: CFrame, size: number, both: boolean?)
		if K.rare < 2 then
			return
		end
		local setting = if K.rare >= 3 then K.inlay else K.guardDark
		local stone = if K.rare >= 4 then M.Neon else M.Glass
		local col = if K.rare >= 3 then K.accent else shade(K.accent, 0.8)
		local sides = if both then { -1, 1 } else { -1 }
		for _, sz in sides do
			K.box("Setting", V(size * 1.35, size * 1.35, 0.05), cf * CF(0, 0, sz * 0.012) * ANG(0, 0, PI / 4), setting, M.Metal)
			K.box("Gem", V(size, size, 0.07), cf * CF(0, 0, sz * 0.03) * ANG(0, 0, PI / 4), col, stone)
		end
	end

	-- Pommels hang below y (the bottom of the handle).
	function K.pommel(style: string, y: number, size: number)
		local g, gm, gd = K.guard, K.guardMat, K.guardDark
		if style == "wheel" then
			K.box("Pommel", V(size * 0.5, size * 0.12, size * 0.5), CF(0, y - size * 0.06, 0), gd, gm)
			local disc = K.cyl("Pommel", size * 0.38, size, CF(0, y - size * 0.62, 0) * ANG(PI / 2, 0, 0), g, gm)
			K.cyl("Pommel", size * 0.5, size * 0.46, CF(0, y - size * 0.62, 0) * ANG(PI / 2, 0, 0), gd, gm)
			K.box("Pommel", V(size * 0.3, size * 0.18, size * 0.3), CF(0, y - size * 1.17, 0), gd, gm)
			if K.rare >= 3 then
				K.gem(CF(0, y - size * 0.62, -size * 0.25), size * 0.26, true)
			end
			return disc
		elseif style == "nut" then
			K.box("Pommel", V(size * 0.45, size * 0.14, size * 0.45), CF(0, y - size * 0.07, 0), gd, gm)
			K.box("Pommel", V(size * 0.62, size * 0.62, size * 0.5), CF(0, y - size * 0.5, 0) * ANG(0, 0, PI / 4), g, gm)
			K.box("Pommel", V(size * 0.25, size * 0.2, size * 0.25), CF(0, y - size * 0.98, 0), gd, gm)
			if K.rare >= 3 then
				K.gem(CF(0, y - size * 0.5, -size * 0.25), size * 0.24, true)
			end
		elseif style == "scent" then
			K.box("Pommel", V(size * 0.42, size * 0.2, size * 0.42), CF(0, y - size * 0.1, 0), gd, gm)
			K.box("Pommel", V(size * 0.7, size * 0.42, size * 0.7), CF(0, y - size * 0.4, 0), g, gm)
			K.box("Pommel", V(size * 0.62, size * 0.3, size * 0.62), CF(0, y - size * 0.4, 0) * ANG(0, PI / 4, 0), gd, gm)
			K.box("Pommel", V(size * 0.42, size * 0.3, size * 0.42), CF(0, y - size * 0.75, 0), g, gm)
			K.box("Pommel", V(size * 0.2, size * 0.16, size * 0.2), CF(0, y - size * 0.98, 0), gd, gm)
			if K.rare >= 3 then
				K.gem(CF(0, y - size * 0.4, -size * 0.36), size * 0.2)
			end
		elseif style == "ball" then
			K.box("Pommel", V(size * 0.4, size * 0.16, size * 0.4), CF(0, y - size * 0.08, 0), gd, gm)
			K.ball("Pommel", size * 0.72, CF(0, y - size * 0.5, 0), g, gm)
			if K.rare >= 3 then
				K.gem(CF(0, y - size * 0.5, -size * 0.36), size * 0.2)
			end
		elseif style == "cap" then
			K.box("Pommel", V(size, size * 0.3, size), CF(0, y - size * 0.15, 0), g, gm)
			K.box("Pommel", V(size * 0.7, size * 0.14, size * 0.7), CF(0, y - size * 0.36, 0), gd, gm)
		elseif style == "ring" then
			K.box("Pommel", V(size * 0.4, size * 0.16, size * 0.3), CF(0, y - size * 0.08, 0), gd, gm)
			for i = 0, 3 do
				local a = i * PI / 2 + PI / 4
				K.box("Ring", V(size * 0.62, size * 0.13, size * 0.16), CF(0, y - size * 0.55, 0) * ANG(0, 0, a) * CF(0, size * 0.3, 0), g, gm)
			end
		elseif style == "spike" then
			K.box("Pommel", V(size * 0.5, size * 0.2, size * 0.5), CF(0, y - size * 0.1, 0), g, gm)
			K.tri("Spike", CF(0, y - size * 0.2, 0), -size * 0.22, size * 0.22, 0, -size * 0.7, size * 0.2, gd, gm)
			K.tri("Spike", CF(0, y - size * 0.2, 0) * ANG(0, PI / 2, 0), -size * 0.22, size * 0.22, 0, -size * 0.7, size * 0.2, gd, gm)
		end
		return nil
	end

	-- Wooden haft (pole) along Y with a leather grip where the hand is.
	function K.haft(y0: number, y1: number, w: number, opts)
		opts = opts or {}
		local wood = opts.col or K.wood
		K.box("Haft", V(w, y1 - y0, w), CF(0, (y0 + y1) / 2, 0), wood, M.Wood)
		if not opts.noWrap then
			K.wraps(-0.46, 0.46, 4, w + 0.06)
		end
		for _, y in opts.rings or {} do
			K.box("Ring", V(w + 0.07, 0.1, w + 0.07), CF(0, y, 0), K.guardDark, K.guardMat)
		end
		if opts.langets then
			local l0, l1 = opts.langets[1], opts.langets[2]
			for _, sx in { 1, -1 } do
				K.box("Langet", V(0.04, l1 - l0, w * 0.55), CF(sx * (w / 2 + 0.02), (l0 + l1) / 2, 0), K.guardDark, K.guardMat)
			end
			for i = 0, 2 do
				local y = l0 + (l1 - l0) * (0.2 + i * 0.3)
				K.box("Rivet", V(w + 0.1, 0.05, 0.05), CF(0, y, 0), K.inlay, M.Metal)
			end
		end
		if opts.butt ~= false then
			K.box("Butt", V(w + 0.06, 0.2, w + 0.06), CF(0, y0 - 0.06, 0), K.guardDark, K.guardMat)
			K.box("Butt", V(w * 0.6, 0.14, w * 0.6), CF(0, y0 - 0.22, 0), K.guard, K.guardMat)
		end
	end

	-- Decorations that depend on rarity and element, applied to registered zones.
	function K.decorate()
		local zones = K.zones
		if K.rare < 3 and not K.el and not K.forceGlow then
			return
		end
		local glow = K.glowing or K.forceGlow
		local col = if glow then K.glow else K.inlay
		local mat = if glow then M.Neon else M.Metal
		local el = if glow then K.el else nil
		local max = if K.rare >= 5 then 2 else 1
		for zi, zn in zones do
			if zi > max or K.n > 54 then
				break
			end
			local L, W = zn.len, math.max(zn.w, 0.06)
			local d = 0.035
			for _, sz in { -1, 1 } do
				local z = sz * (zn.z + d / 2 - 0.012)
				local function strip(x, y, w, h, rot, c)
					K.box("Rune", V(w, h, d), zn.cf * CF(x, y, z) * ANG(0, 0, rot or 0), c or col, mat)
				end
				local lw = math.clamp(W * 0.32, 0.03, 0.06)
				if el == "Void" or el == "Storm" then
					local n = if el == "Storm" then 3 else 4
					local amp = W * (if el == "Storm" then 0.7 else 0.5)
					local sl = L / n
					local len = math.sqrt(sl * sl + amp * amp)
					local ang = math.atan2(amp, sl)
					for i = 0, n - 1 do
						strip(0, -L / 2 + sl * (i + 0.5), lw * 0.85, len + lw * 0.6, if i % 2 == 0 then ang else -ang)
					end
				elseif el == "Fire" then
					for i = -1, 1 do
						strip(W * 0.14 * i, L * 0.3 * i, lw, L * 0.3, 0.14 * (if i == 0 then -1 else 1))
					end
					strip(0, L * 0.47, lw * 0.8, L * 0.08, 0)
				elseif el == "Frost" then
					strip(0, 0, lw * 0.8, L * 0.9)
					for _, y in { -0.22, 0.18 } do
						strip(W * 0.2, L * y, lw * 0.7, W * 0.9, 0.9)
						strip(-W * 0.2, L * y, lw * 0.7, W * 0.9, -0.9)
					end
				elseif el == "Blood" then
					strip(0, L * 0.06, lw, L * 0.84)
					for i = 0, 2 do
						strip(0, -L * 0.44 - i * 0.07, lw * 1.2, lw * 1.2, PI / 4)
					end
				else
					-- engraving / holy light: a line with lozenge nodes
					strip(0, 0, lw * 0.75, L * 0.92)
					local nodes = if K.rare >= 4 then { -0.32, 0, 0.32 } else { -0.3, 0.3 }
					for _, y in nodes do
						strip(0, L * y, W * 0.7, W * 0.7, PI / 4)
					end
				end
			end
		end
	end

	-- Divine halo: a ring of light tilted so it reads from the side and from behind.
	function K.halo(y: number, r: number)
		local n = 8
		local seg = 2 * PI * r / n * 1.1
		local frame = CF(0, y, 0)
		local col = K.glow:Lerp(rgb(255, 255, 255), 0.45)
		for i = 0, n - 1 do
			local a = i / n * 2 * PI
			K.box("Halo", V(seg, 0.08, 0.05), frame * ANG(0, 0, a) * CF(0, r, 0), col, M.Neon)
			if i % 2 == 0 then
				-- rays pointing outward
				K.box("Halo", V(0.05, 0.16, 0.04), frame * ANG(0, 0, a) * CF(0, r + 0.12, 0), col, M.Neon)
			end
		end
	end
	return K
end

-- ------------------------------------------------------------------ builders
-- Each returns baseY, tipY (the span the swing trail follows).
local BUILD = {}
local GY = 0.74 -- one-handed guard height (clears the first-person fist)

-- swords ------------------------------------------------------------
local function swordGuard(K, gy: number, span: number, style: string)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	K.box("Guard", V(0.3, 0.22, 0.28), CF(0, gy, 0), g, gm)
	K.box("Guard", V(span, 0.12, 0.18), CF(0, gy, 0), gd, gm)
	if style == "upturned" then
		for _, sx in { 1, -1 } do
			K.box("Quillon", V(0.15, 0.32, 0.2), CF(sx * (span / 2 - 0.02), gy + 0.08, 0) * ANG(0, 0, -sx * 0.4), g, gm)
			if K.rare >= 3 then
				K.box("Quillon", V(0.11, 0.11, 0.22), CF(sx * (span / 2 + 0.05), gy + 0.24, 0) * ANG(0, 0, PI / 4), K.inlay, M.Metal)
			end
		end
	elseif style == "straight" then
		for _, sx in { 1, -1 } do
			K.box("Quillon", V(0.14, 0.18, 0.22), CF(sx * (span / 2), gy, 0), g, gm)
		end
	elseif style == "drooped" then
		for _, sx in { 1, -1 } do
			K.box("Quillon", V(0.14, 0.3, 0.2), CF(sx * (span / 2 - 0.02), gy - 0.08, 0) * ANG(0, 0, sx * 0.45), g, gm)
		end
	elseif style == "forward" then
		for _, sx in { 1, -1 } do
			K.box("Quillon", V(0.36, 0.13, 0.18), CF(sx * (span / 2 + 0.1), gy + 0.1, 0) * ANG(0, 0, sx * 0.45), g, gm)
			K.box("Quillon", V(0.16, 0.16, 0.22), CF(sx * (span / 2 + 0.26), gy + 0.22, 0), gd, gm)
		end
	end
	if K.rare >= 3 then
		-- inlaid bands on both faces of the bar
		for _, sz in { -1, 1 } do
			K.box("Inlay", V(span * 0.62, 0.04, 0.03), CF(0, gy, sz * 0.1), K.inlay, M.Metal)
		end
	end
	if K.rare >= 5 then
		-- dramatic swept wings rising along the blade
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(0, gy + 0.06, 0), sx * 0.14, sx * (span / 2 + 0.05), sx * 0.2, 0.62, 0.08, g, gm)
			K.tri("Wing", CF(0, gy + 0.06, 0), sx * 0.24, sx * (span / 2 + 0.12), sx * (span / 2 + 0.05), 0.4, 0.06, K.inlay, M.Metal)
		end
		K.tri("Spike", CF(0, gy - 0.1, 0), -0.12, 0.12, 0, -0.34, 0.12, g, gm)
	end
end

BUILD.Longsword = function(K)
	local L = 2.95 + K.v * 0.2
	K.wraps(-0.46, GY - 0.1, 5, 0.26)
	K.pommel("wheel", -0.5, 0.4)
	swordGuard(K, GY, 1.2, if K.v == 1 then "straight" else "upturned")
	K.box("Chape", V(0.2, 0.26, 0.19), CF(0, GY + 0.2, 0), K.guardDark, K.guardMat)
	local top = K.forge({ y0 = GY + 0.12, len = L, w = 0.38, t = 0.11, b = 0.1, fuller = 0.72, fw = 0.09, point = 0.6 })
	if K.rare >= 6 then
		K.halo(GY + 0.9, 0.62)
	end
	return GY + 0.2, top
end

BUILD.ArmingSword = function(K)
	K.wraps(-0.46, GY - 0.1, 4, 0.25)
	K.pommel(if K.v == 2 then "wheel" else "nut", -0.5, 0.36)
	swordGuard(K, GY, 1.34, "straight")
	local y = GY + 0.08
	y = K.forge({ y0 = y, len = 1.35, w = 0.44, t = 0.11, b = 0.1, fuller = 0.9, fullerStart = 0.08, fw = 0.1 })
	local top = K.forge({ y0 = y - 0.01, len = 1.05, w = 0.36, t = 0.1, b = 0.09, fuller = 0.62, fullerStart = 0, fw = 0.1, point = 0.62, noZone = true })
	if K.rare >= 6 then
		K.halo(GY + 0.8, 0.6)
	end
	return GY + 0.2, top
end

BUILD.PitBlade = function(K)
	K.chipped = true
	K.forceGlow = true
	K.glowing = true
	K.edgeMat = M.CorrodedMetal
	K.bladeMat = M.CorrodedMetal
	local top = BUILD.ArmingSword(K)
	return top
end

BUILD.Falchion = function(K)
	K.wraps(-0.46, GY - 0.1, 4, 0.25)
	K.pommel("wheel", -0.5, 0.34)
	swordGuard(K, GY, 0.95, "drooped")
	-- spine straight on +X, belly widening toward the tip, clipped point
	local spine = 0.17
	local y = GY + 0.08
	local ws = { 0.34, 0.44, 0.54 }
	local ls = { 0.95, 0.85, 0.75 }
	for i = 1, 3 do
		local w = ws[i]
		y = K.forge({ frame = CF(spine - w / 2, 0, 0), y0 = y - (if i > 1 then 0.01 else 0), len = ls[i], w = w, t = 0.11, b = 0.11, single = 1, fuller = if i < 3 then 0.95 else 0, fullerStart = if i == 1 then 0.1 else 0, fw = 0.07, fx = w / 2 - 0.1, noZone = i > 1 })
	end
	local w = ws[3]
	K.tri("Tip", CF(spine - w / 2, y, 0), -w / 2, w / 2, -w / 2 + 0.06, 0.5, 0.06, K.edge, K.edgeMat)
	K.tri("Tip", CF(spine - w / 2, y - 0.01, 0), -w / 2 + 0.09, w / 2, -w / 2 + 0.12, 0.38, 0.11, K.blade, K.bladeMat)
	-- spine chamfer (false edge)
	K.box("Spine", V(0.04, y - GY - 0.1, 0.07), CF(spine + 0.01, (GY + 0.1 + y) / 2, 0), K.edge, K.bladeMat)
	if K.rare >= 5 then
		for i = 0, 2 do
			K.tri("Tooth", CF(spine, GY + 0.9 + i * 0.36, 0) * ANG(0, 0, -PI / 2), -0.1, 0.1, 0, 0.14, 0.06, K.edge, K.edgeMat)
		end
	end
	if K.rare >= 6 then
		K.halo(GY + 0.8, 0.62)
	end
	return GY + 0.2, y + 0.5
end

BUILD.Sabre = function(K)
	K.wraps(-0.42, GY - 0.1, 4, 0.24)
	-- D-shaped knuckle bow on the edge side
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	K.box("Guard", V(0.86, 0.12, 0.22), CF(-0.14, GY, 0), gd, gm)
	K.box("Guard", V(0.26, 0.18, 0.26), CF(0, GY, 0), g, gm)
	K.box("Bow", V(0.1, 1.24, 0.12), CF(-0.5, 0.14, 0) * ANG(0, 0, -0.08), g, gm)
	K.box("Bow", V(0.4, 0.1, 0.12), CF(-0.3, -0.5, 0) * ANG(0, 0, 0.35), g, gm)
	K.box("Quillon", V(0.12, 0.24, 0.18), CF(0.32, GY + 0.08, 0) * ANG(0, 0, -0.5), g, gm)
	K.pommel("cap", -0.48, 0.3)
	-- curved single-edged blade: segments bend toward the spine (+X)
	local frame = CF(0, GY + 0.07, 0)
	local seg = { 0.72, 0.7, 0.66, 0.6 }
	local w = 0.34
	for i, L in seg do
		local ww = w - (i - 1) * 0.02
		K.forge({ frame = frame, y0 = 0, len = L + 0.04, w = ww, t = 0.1, b = 0.1, single = 1, fuller = if i <= 2 then 0.9 else 0, fullerStart = if i == 1 then 0.08 else 0, fw = 0.06, fx = ww / 2 - 0.08, noZone = i > 1 })
		frame = frame * CF(0, L, 0) * ANG(0, 0, -0.085)
	end
	local ww = w - #seg * 0.02
	K.tri("Tip", frame, -ww / 2, ww / 2, ww / 2 - 0.04, 0.5, 0.06, K.edge, K.edgeMat)
	K.tri("Tip", frame * CF(0, -0.01, 0), -ww / 2 + 0.08, ww / 2, ww / 2 - 0.04, 0.36, 0.1, K.blade, K.bladeMat)
	if K.rare >= 5 then
		K.tri("Wing", CF(0.1, GY + 0.06, 0), 0.05, 0.42, 0.14, 0.5, 0.07, g, gm)
	end
	if K.rare >= 6 then
		K.halo(GY + 0.8, 0.6)
	end
	local tip = (frame * CF(0, 0.5, 0)).Position
	return GY + 0.2, tip.Y
end

BUILD.BastardSword = function(K)
	-- hand-and-a-half grip continues below the fist
	K.box("Handle", V(0.22, 0.5, 0.22), CF(0, -0.72, 0), shade(K.gripC, 0.7), M.Leather)
	K.wraps(-0.96, GY - 0.1, 7, 0.26)
	K.pommel("scent", -0.97, 0.42)
	swordGuard(K, GY, 1.32, "forward")
	K.box("Ricasso", V(0.32, 0.36, 0.13), CF(0, GY + 0.26, 0), shade(K.blade, 0.9), K.bladeMat)
	for _, sx in { 1, -1 } do
		K.box("Langet", V(0.1, 0.3, 0.17), CF(sx * 0.05, GY + 0.2, 0), K.guardDark, K.guardMat)
	end
	local top = K.forge({ y0 = GY + 0.44, len = 3.25 + K.v * 0.15, w = 0.4, t = 0.12, b = 0.11, fuller = 0.55, fw = 0.1, point = 0.66 })
	if K.rare >= 6 then
		K.halo(GY + 1.1, 0.66)
	end
	return GY + 0.4, top
end

BUILD.Estoc = function(K)
	K.wraps(-0.46, GY - 0.1, 5, 0.24)
	K.pommel("scent", -0.5, 0.38)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	K.box("Guard", V(1.42, 0.1, 0.16), CF(0, GY, 0), gd, gm)
	K.box("Guard", V(0.28, 0.22, 0.28), CF(0, GY, 0), g, gm)
	for _, sx in { 1, -1 } do
		K.box("Quillon", V(0.13, 0.13, 0.13), CF(sx * 0.72, GY, 0) * ANG(PI / 4, 0, PI / 4), g, gm)
	end
	-- finger ring below the guard on the -Z side
	for i = 0, 3 do
		K.box("Ring", V(0.4, 0.07, 0.07), CF(0, GY - 0.02, -0.2) * ANG(PI / 2, 0, 0) * ANG(0, 0, i * PI / 2 + PI / 4) * CF(0, 0.18, 0) * ANG(PI / 2, 0, 0), g, gm)
	end
	-- long square ricasso, then a diamond-section blade with no core
	K.box("Ricasso", V(0.17, 0.62, 0.17), CF(0, GY + 0.36, 0), shade(K.blade, 0.85), K.bladeMat)
	K.box("Ricasso", V(0.2, 0.06, 0.2), CF(0, GY + 0.66, 0), gd, gm)
	local y0 = GY + 0.66
	local L = 3.35 + K.v * 0.15
	local core = K.box("Blade", V(0.05, L, 0.16), CF(0, y0 + L / 2, 0), K.blade, K.bladeMat)
	K.edgeBevel("Edge", CF(), 0.025, 0.13, y0, y0 + L, 0.16)
	K.edgeBevel("Edge", CF(), -0.025, -0.13, y0, y0 + L, 0.16)
	K.setFx(core)
	K.tri("Tip", CF(0, y0 + L, 0), -0.13, 0.13, 0, 0.75, 0.1, K.edge, K.edgeMat)
	K.tri("Tip", CF(0, y0 + L, 0) * ANG(0, PI / 2, 0), -0.08, 0.08, 0, 0.62, 0.06, K.blade, K.bladeMat)
	K.zone(CF(0, GY + 0.36, 0), 0.5, 0.12, 0.085)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(0, GY + 0.05, 0), sx * 0.12, sx * 0.62, sx * 0.14, 0.5, 0.06, g, gm)
		end
	end
	if K.rare >= 6 then
		K.halo(GY + 1.1, 0.55)
	end
	return y0, y0 + L + 0.75
end

BUILD.CrownOfDawn = function(K)
	-- the spared king's sword: sun-crown guard, sun-disc pommel
	K.wraps(-0.46, GY - 0.1, 5, 0.26, rgb(236, 230, 214), M.Fabric)
	local g, gd = GOLD, shade(GOLD, 0.75)
	K.cyl("Pommel", 0.12, 0.5, CF(0, -0.78, 0) * ANG(PI / 2, 0, 0), g, M.Metal)
	for i = 0, 3 do
		K.box("Ray", V(0.72, 0.07, 0.08), CF(0, -0.78, 0) * ANG(0, 0, i * PI / 4), gd, M.Metal)
	end
	K.box("Pommel", V(0.18, 0.2, 0.18), CF(0, -0.5, 0), gd, M.Metal)
	K.gem(CF(0, -0.78, -0.08), 0.14, true)
	K.box("Guard", V(1.3, 0.14, 0.2), CF(0, GY, 0), g, M.Metal)
	K.box("Guard", V(0.4, 0.26, 0.3), CF(0, GY, 0), gd, M.Metal)
	-- five crown spikes rising from the guard
	for i = -2, 2 do
		local x = i * 0.27
		local h = if i == 0 then 0.5 else (if math.abs(i) == 1 then 0.34 else 0.42)
		if i ~= 0 then
			K.tri("Crown", CF(x, GY + 0.07, 0), -0.08, 0.08, 0, h, 0.08, g, M.Metal)
		end
	end
	for _, sx in { 1, -1 } do
		K.tri("Wing", CF(0, GY + 0.07, 0), sx * 0.66, sx * 0.9, sx * 0.9, 0.36, 0.08, g, M.Metal)
	end
	K.gem(CF(0, GY, -0.16), 0.16, true)
	local top = K.forge({ y0 = GY + 0.12, len = 3.2, w = 0.42, t = 0.11, b = 0.1, fuller = 0.75, fw = 0.12, point = 0.62 })
	K.halo(GY + 0.95, 0.66)
	return GY + 0.2, top
end

-- katanas -----------------------------------------------------------
local function tsuka(K, bottom: number, n: number)
	local same = rgb(222, 216, 200)
	local top = GY - 0.12
	K.box("Tsuka", V(0.23, top - bottom, 0.23), CF(0, (bottom + top) / 2, 0), same, M.Fabric)
	local step = (top - bottom) / n
	for i = 0, n - 1 do
		local y = bottom + step * (i + 0.5)
		for _, a in { 0.5, -0.5 } do
			K.box("Ito", V(0.27, 0.07, 0.27), CF(0, y, 0) * ANG(0, 0, a), K.gripC, M.Fabric)
		end
	end
	K.box("Kashira", V(0.27, 0.12, 0.27), CF(0, bottom - 0.05, 0), K.guardDark, K.guardMat)
	K.box("Fuchi", V(0.27, 0.1, 0.27), CF(0, top + 0.02, 0), K.guardDark, K.guardMat)
end

local function tsuba(K, y: number, size: number, square: boolean?)
	local g, gm = K.guard, K.guardMat
	K.box("Tsuba", V(size, 0.07, size), CF(0, y, 0), g, gm)
	if not square then
		K.box("Tsuba", V(size, 0.07, size), CF(0, y, 0) * ANG(0, PI / 4, 0), g, gm)
	else
		K.box("Tsuba", V(size * 0.86, 0.09, size * 0.86), CF(0, y, 0), K.guardDark, gm)
	end
	K.box("Seppa", V(0.3, 0.12, 0.3), CF(0, y, 0), K.inlay, M.Metal)
	if K.rare >= 5 then
		for i = 0, 3 do
			K.box("Tsuba", V(0.12, 0.09, 0.12), CF(0, y, 0) * ANG(0, i * PI / 2 + PI / 4, 0) * CF(0, 0, size * 0.62), K.inlay, M.Metal)
		end
	end
end

-- Curved single-edged katana blade from y0. dir = 1: edge on -X (normal),
-- -1: reversed edge. Returns the tip height.
local function katanaBlade(K, y0: number, segs: number, segL: number, w: number, dir: number, curve: number)
	K.box("Habaki", V(0.2, 0.2, 0.15), CF(0, y0 + 0.08, 0), GOLD, M.Metal)
	local frame = CF(0, y0 + 0.02, 0)
	local hamon = if K.glowing then K.glow else K.edge:Lerp(rgb(255, 255, 255), 0.3)
	local hmat = if K.glowing then M.Neon else M.Metal
	for i = 1, segs do
		local ww = w - (i - 1) * 0.012
		K.forge({ frame = frame, y0 = 0, len = segL + 0.04, w = ww, t = 0.1, b = 0.1, single = dir, noZone = i ~= 2, zoneK = 1.2 })
		if K.rare >= 3 then
			-- hamon: temper line where the flat meets the edge bevel
			local x = -dir * (ww / 2 - 0.1)
			for _, sz in { -1, 1 } do
				K.box("Hamon", V(0.035, segL * 0.94, 0.02), frame * CF(x + dir * 0.012, segL / 2, sz * 0.05) * ANG(0, 0, (if i % 2 == 0 then 0.03 else -0.03)), hamon, hmat)
			end
		end
		frame = frame * CF(0, segL, 0) * ANG(0, 0, -dir * curve)
	end
	local ww = w - segs * 0.012
	-- kissaki: the edge sweeps up to meet the spine
	K.tri("Tip", frame, -ww / 2, ww / 2, dir * (ww / 2 - 0.03), 0.4, 0.06, K.edge, K.edgeMat)
	K.tri("Tip", frame * CF(0, -0.01, 0), -ww / 2 + (if dir == 1 then 0.08 else 0), ww / 2 - (if dir == -1 then 0.08 else 0), dir * (ww / 2 - 0.03), 0.28, 0.1, K.blade, K.bladeMat)
	return (frame * CF(0, 0.4, 0)).Position.Y
end

BUILD.Katana = function(K)
	tsuka(K, -0.95, 5)
	tsuba(K, GY, 0.64)
	local top = katanaBlade(K, GY + 0.04, 5, 0.72 + K.v * 0.04, 0.27, 1, 0.045)
	if K.rare >= 6 then
		K.halo(GY + 0.9, 0.55)
	end
	return GY + 0.2, top
end

BUILD.Wakizashi = function(K)
	tsuka(K, -0.55, 3)
	tsuba(K, GY, 0.5)
	local top = katanaBlade(K, GY + 0.04, 3, 0.66 + K.v * 0.04, 0.25, 1, 0.05)
	if K.rare >= 6 then
		K.halo(GY + 0.7, 0.45)
	end
	return GY + 0.2, top
end

BUILD.Nodachi = function(K)
	tsuka(K, -1.45, 5)
	tsuba(K, GY, 0.7, true)
	local top = katanaBlade(K, GY + 0.04, 5, 0.96 + K.v * 0.05, 0.3, 1, 0.048)
	K.box("Cord", V(0.3, 0.1, 0.3), CF(0, -1.2, 0), K.accent:Lerp(rgb(120, 30, 30), 0.5), M.Fabric)
	if K.rare >= 6 then
		K.halo(GY + 1.0, 0.6)
	end
	return GY + 0.2, top
end

BUILD.HollowEdge = function(K)
	tsuka(K, -0.95, 5)
	-- a broken ring for a guard
	local g = rgb(24, 20, 26)
	for i = 0, 6 do
		K.box("Tsuba", V(0.24, 0.08, 0.16), CF(0, GY, 0) * ANG(0, i * PI / 4, 0) * CF(0, 0, 0.3), g, M.Metal)
	end
	K.box("Seppa", V(0.3, 0.12, 0.3), CF(0, GY, 0), K.glow, M.Neon)
	-- reversed edge: it was never facing the right way
	local top = katanaBlade(K, GY + 0.04, 5, 0.74, 0.28, -1, 0.045)
	K.halo(GY + 0.9, 0.55)
	return GY + 0.2, top
end

-- greatswords -------------------------------------------------------
local function twoHandle(K, bottom: number, n: number)
	K.box("Handle", V(0.25, -0.5 - bottom, 0.25), CF(0, (bottom - 0.5) / 2, 0), shade(K.gripC, 0.7), M.Leather)
	K.box("Handle", V(0.25, 0.2, 0.25), CF(0, 0.55, 0), shade(K.gripC, 0.7), M.Leather)
	K.wraps(bottom + 0.04, 0.6, n, 0.3)
end

BUILD.Zweihander = function(K)
	twoHandle(K, -1.3, 6)
	K.pommel("scent", -1.3, 0.5)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	local gy = 0.7
	K.box("Guard", V(0.5, 0.36, 0.36), CF(0, gy, 0), gd, gm)
	K.box("Guard", V(2.0, 0.16, 0.24), CF(0, gy, 0), g, gm)
	for _, sx in { 1, -1 } do
		K.box("Quillon", V(0.2, 0.42, 0.26), CF(sx * 1.02, gy + 0.08, 0) * ANG(0, 0, -sx * 0.35), g, gm)
		K.box("Quillon", V(0.2, 0.2, 0.28), CF(sx * 1.1, gy + 0.3, 0) * ANG(0, 0, PI / 4), gd, gm)
		-- side rings
		K.box("Ring", V(0.34, 0.08, 0.08), CF(sx * 0.4, gy - 0.02, -0.22) * ANG(0, 0, sx * 0.4), g, gm)
	end
	-- leather-wrapped ricasso with parrying lugs
	K.box("Ricasso", V(0.46, 0.66, 0.14), CF(0, gy + 0.5, 0), shade(K.blade, 0.9), K.bladeMat)
	K.wraps(gy + 0.24, gy + 0.76, 2, 0.2, shade(K.gripC, 1.15))
	for _, sx in { 1, -1 } do
		K.tri("Lug", CF(sx * 0.23, gy + 0.9, 0) * ANG(0, 0, -sx * PI / 2), -0.11, 0.11, 0, 0.24, 0.12, g, gm)
	end
	local y0 = gy + 0.83
	local top = K.forge({ y0 = y0, len = 4.0 + K.v * 0.2, w = 0.64, t = 0.14, b = 0.14, fuller = 0.66, fw = 0.14, point = 0.85 })
	if K.rare >= 3 then
		K.gem(CF(0, gy, -0.19), 0.16, true)
	end
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(0, gy + 0.08, 0), sx * 0.3, sx * 1.1, sx * 0.35, 0.8, 0.1, g, gm)
			if K.rare == 5 then
				K.tri("Wing", CF(0, gy + 0.08, 0), sx * 0.5, sx * 1.2, sx * 1.1, 0.5, 0.08, K.inlay, M.Metal)
			end
		end
	end
	if K.rare >= 6 then
		K.halo(y0 + 0.4, 0.95)
	end
	return y0, top
end

BUILD.Claymore = function(K)
	twoHandle(K, -1.2, 7)
	K.pommel("wheel", -1.2, 0.5)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	local gy = 0.7
	K.box("Guard", V(0.42, 0.3, 0.3), CF(0, gy, 0), gd, gm)
	for _, sx in { 1, -1 } do
		-- quillons sweep forward (up toward the blade) and end in quatrefoils
		local arm = CF(sx * 0.2, gy, 0) * ANG(0, 0, sx * 0.6) * CF(sx * 0.45, 0, 0)
		K.box("Quillon", V(0.95, 0.14, 0.2), arm, g, gm)
		local tip = arm * CF(sx * 0.5, 0, 0)
		K.box("Quatrefoil", V(0.3, 0.1, 0.22), tip, gd, gm)
		K.box("Quatrefoil", V(0.1, 0.3, 0.22), tip, gd, gm)
		if K.rare >= 3 then
			K.box("Quatrefoil", V(0.12, 0.12, 0.25), tip, K.inlay, M.Metal)
		end
	end
	-- langets over the blade base
	K.box("Langet", V(0.26, 0.42, 0.18), CF(0, gy + 0.3, 0), gd, gm)
	local y0 = gy + 0.16
	local top = K.forge({ y0 = y0, len = 4.2 + K.v * 0.15, w = 0.58, t = 0.14, b = 0.13, fuller = 0.55, fw = 0.13, point = 0.8, fullerStart = 0.35 })
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.3, gy + 0.2, 0), -0.08, 0.08, 0, 0.9, 0.08, g, gm)
		end
	end
	if K.rare >= 6 then
		K.halo(y0 + 0.9, 0.95)
	end
	return y0 + 0.3, top
end

BUILD.Executioner = function(K)
	twoHandle(K, -1.1, 6)
	K.pommel("ball", -1.1, 0.46)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	local gy = 0.7
	K.box("Guard", V(1.3, 0.22, 0.3), CF(0, gy, 0), g, gm)
	K.box("Guard", V(0.5, 0.3, 0.34), CF(0, gy, 0), gd, gm)
	for _, sx in { 1, -1 } do
		K.box("Quillon", V(0.2, 0.36, 0.3), CF(sx * 0.62, gy - 0.1, 0), gd, gm)
	end
	local y0 = gy + 0.1
	local L = 3.55 + K.v * 0.15
	local W = 0.84
	local top = K.forge({ y0 = y0, len = L, w = W, t = 0.14, b = 0.14, fuller = 0.42, fw = 0.2, fullerStart = 0.3 })
	-- square, rounded end instead of a point
	K.box("End", V(W - 0.2, 0.12, 0.12), CF(0, top + 0.05, 0), K.blade, K.bladeMat)
	for _, sx in { 1, -1 } do
		K.tri("End", CF(sx * (W / 2 - 0.1), top, 0), -0.1, 0.1, -sx * 0.1, 0.1, 0.1, K.edge, K.edgeMat)
	end
	-- the hole near the end, and an engraved band
	local hy = top - 0.42
	for _, sz in { -1, 1 } do
		K.box("Hole", V(0.2, 0.2, 0.02), CF(0, hy, sz * 0.07), rgb(12, 10, 10), M.Metal)
		K.box("Rim", V(0.3, 0.3, 0.02), CF(0, hy, sz * 0.064), K.guardDark, K.guardMat)
	end
	K.zone(CF(0, top - 1.1, 0), 0.8, 0.3, 0.07)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.66, gy - 0.28, 0), -0.1, 0.1, 0, -0.5, 0.12, g, gm)
			K.tri("Wing", CF(sx * 0.4, gy + 0.1, 0), -0.08, 0.14, 0.14 * sx, 0.46, 0.1, K.inlay, M.Metal)
		end
	end
	if K.rare >= 6 then
		K.halo(y0 + 0.8, 1.0)
	end
	return y0 + 0.3, top + 0.1
end

BUILD.Flamberge = function(K)
	twoHandle(K, -1.3, 5)
	K.pommel("scent", -1.3, 0.48)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	local gy = 0.7
	K.box("Guard", V(0.46, 0.32, 0.32), CF(0, gy, 0), gd, gm)
	K.box("Guard", V(1.8, 0.14, 0.22), CF(0, gy, 0), g, gm)
	for _, sx in { 1, -1 } do
		K.box("Quillon", V(0.18, 0.46, 0.22), CF(sx * 0.92, gy - 0.04, 0) * ANG(0, 0, sx * 0.5), g, gm)
		K.box("Ring", V(0.3, 0.07, 0.3), CF(sx * 0.42, gy - 0.08, 0) * ANG(0, 0, sx * 0.3), g, gm)
	end
	K.box("Ricasso", V(0.4, 0.5, 0.14), CF(0, gy + 0.42, 0), shade(K.blade, 0.88), K.bladeMat)
	for _, sx in { 1, -1 } do
		K.tri("Lug", CF(sx * 0.2, gy + 0.72, 0) * ANG(0, 0, -sx * PI / 2), -0.09, 0.09, 0, 0.2, 0.1, g, gm)
	end
	-- wavy flame edge: bevels alternate width and lean
	local y0 = gy + 0.67
	local L = 4.0
	local W = 0.56
	local cw = W - 0.2
	local body = K.box("Blade", V(cw, L, 0.14), CF(0, y0 + L / 2, 0), K.blade, K.bladeMat)
	K.setFx(body)
	K.box("Fuller", V(0.1, L * 0.62, 0.17), CF(0, y0 + L * 0.36, 0), K.dark, K.bladeMat)
	K.zone(CF(0, y0 + L * 0.36, 0), L * 0.5, 0.1, 0.085)
	local n = 4
	local sl = L / n
	for i = 0, n - 1 do
		local bw = if i % 2 == 0 then 0.1 else 0.2
		local lean = if i % 2 == 0 then 0.12 else -0.12
		for _, sx in { 1, -1 } do
			local fr = CF(0, y0 + sl * (i + 0.5), 0) * ANG(0, 0, sx * lean) * CF(0, -(y0 + sl * (i + 0.5)), 0)
			K.edgeBevel("Edge", fr, sx * (cw / 2 - 0.02), sx * (cw / 2 - 0.02 + bw), y0 + sl * i - 0.02, y0 + sl * (i + 1) + 0.02, 0.14)
		end
	end
	K.tri("Tip", CF(0, y0 + L, 0), -cw / 2 - 0.06, cw / 2 + 0.06, 0, 0.75, 0.08, K.edge, K.edgeMat)
	K.tri("Tip", CF(0, y0 + L - 0.01, 0), -cw / 2 + 0.04, cw / 2 - 0.04, 0, 0.55, 0.14, K.blade, K.bladeMat)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(0, gy + 0.08, 0), sx * 0.26, sx * 0.95, sx * 0.3, 0.7, 0.1, g, gm)
		end
	end
	if K.rare >= 6 then
		K.halo(y0 + 0.4, 0.9)
	end
	return y0, y0 + L + 0.75
end

BUILD.TitanFang = function(K)
	-- a giant tooth: ivory, stepped taper with a curve, root bound in leather and iron
	twoHandle(K, -1.2, 6)
	local bone = K.blade:Lerp(rgb(236, 226, 200), 0.6)
	local root = shade(bone, 0.78)
	K.box("Root", V(0.5, 0.5, 0.5), CF(0, -1.35, 0) * ANG(0, 0.3, 0.2), root, M.Marble)
	K.box("Root", V(0.4, 0.3, 0.4), CF(0.06, -1.65, 0) * ANG(0.3, 0, 0.5), shade(root, 0.9), M.Marble)
	local gy = 0.72
	K.box("Collar", V(0.8, 0.4, 0.5), CF(0, gy, 0), root, M.Marble)
	for i = 0, 2 do
		K.box("Strap", V(0.86, 0.1, 0.56), CF(0, gy - 0.12 + i * 0.12, 0) * ANG(0, 0, (i - 1) * 0.12), rgb(60, 40, 30), M.Leather)
	end
	K.box("Band", V(0.9, 0.08, 0.6), CF(0, gy + 0.22, 0), K.guardDark, K.guardMat)
	-- the tooth: segments narrowing and bending toward +X
	local frame = CF(0, gy + 0.2, 0)
	local ws = { 0.9, 0.8, 0.68, 0.54, 0.4 }
	for i, w in ws do
		local L = 0.95
		local p = K.box("Tooth", V(w - 0.2, L + 0.05, 0.22), frame * CF(0, L / 2, 0), if i % 2 == 0 then bone else shade(bone, 0.95), M.Marble)
		if i == 2 then
			K.setFx(p)
		end
		K.edgeBevel("Edge", frame, -(w / 2 - 0.1), -w / 2, 0, L + 0.05, 0.22, shade(bone, 1.06), M.Marble)
		K.edgeBevel("Edge", frame, w / 2 - 0.1, w / 2, 0, L + 0.05, 0.22, shade(bone, 0.9), M.Marble)
		if i <= 3 then
			-- blood veins
			for _, sz in { -1, 1 } do
				K.box("Vein", V(0.04, L * 0.8, 0.02), frame * CF((i % 2 - 0.5) * 0.14, L / 2, sz * 0.11) * ANG(0, 0, 0.2 * (i % 2 * 2 - 1)), K.glow, M.Neon)
			end
		end
		frame = frame * CF(0, L, 0) * ANG(0, 0, -0.07)
	end
	K.tri("Tip", frame, -0.2, 0.2, 0.12, 0.8, 0.2, shade(bone, 1.05), M.Marble)
	local tip = (frame * CF(0, 0.8, 0)).Position
	return gy + 0.3, tip.Y
end

-- axes (edge faces -X, the leading side) --------------------------------
local function axeEye(K, y: number, h: number)
	K.box("Eye", V(0.36, h, 0.36), CF(0, y, 0), shade(K.blade, 0.85), K.bladeMat)
	K.box("Eye", V(0.4, 0.08, 0.4), CF(0, y + h / 2 - 0.02, 0), K.guardDark, K.guardMat)
	K.box("Eye", V(0.4, 0.08, 0.4), CF(0, y - h / 2 + 0.02, 0), K.guardDark, K.guardMat)
	K.box("Wedge", V(0.1, 0.06, 0.12), CF(0, y + h / 2 + 0.02, 0), K.wood, M.Wood)
end

-- Stepped flaring axe blade toward sx (-1 = -X). Segments: {x0, x1, yBottom, yTop}.
local function axeBlade(K, sx: number, segs, edgeB: number, t: number)
	local x1last, yb, yt
	for i, s in segs do
		local w = s[2] - s[1]
		local p = K.box("Bit", V(w + 0.02, s[4] - s[3], t - (i - 1) * 0.01), CF(sx * (s[1] + w / 2), (s[3] + s[4]) / 2, 0), if i % 2 == 0 then K.blade else shade(K.blade, 0.94), K.bladeMat)
		if i == #segs then
			K.setFx(p)
		end
		x1last, yb, yt = s[2], s[3], s[4]
	end
	local tl = t - (#segs - 1) * 0.01
	K.edgeBevel("Edge", CF(), sx * x1last, sx * (x1last + edgeB), yb - 0.08, yt + 0.08, tl)
	-- horns at the ends of the edge
	K.tri("Horn", CF(sx * (x1last + edgeB * 0.5), yt + 0.08, 0), -edgeB * 0.5 - 0.08, edgeB * 0.5, sx * edgeB * 0.5, 0.12, tl * 0.6, K.edge, K.edgeMat)
	K.tri("Horn", CF(sx * (x1last + edgeB * 0.5), yb - 0.08, 0), -edgeB * 0.5 - 0.08, edgeB * 0.5, sx * edgeB * 0.5, -0.12, tl * 0.6, K.edge, K.edgeMat)
	local mid = CF(sx * (x1last - 0.12), (yb + yt) / 2, 0)
	K.zone(mid * ANG(0, 0, PI / 2), (yt - yb) * 0.6, 0.12, tl / 2)
	return x1last + edgeB
end

BUILD.WarAxe = function(K)
	local hy = 2.55
	K.haft(-0.75, hy + 0.4, 0.22, { rings = { hy - 0.62 }, langets = { hy - 0.6, hy - 0.3 } })
	axeEye(K, hy, 0.62)
	K.box("Poll", V(0.26, 0.4, 0.3), CF(0.3, hy, 0), shade(K.blade, 0.8), K.bladeMat)
	K.box("Poll", V(0.08, 0.44, 0.34), CF(0.44, hy, 0), K.dark, K.bladeMat)
	axeBlade(K, -1, { { 0.16, 0.44, hy - 0.2, hy + 0.2 }, { 0.44, 0.74, hy - 0.38, hy + 0.32 }, { 0.74, 1.0, hy - 0.58, hy + 0.44 } }, 0.16, 0.13)
	if K.rare >= 5 then
		K.tri("Spike", CF(0.48, hy, 0) * ANG(0, 0, -PI / 2), -0.16, 0.16, 0, 0.45, 0.12, K.guard, K.guardMat)
		K.tri("Spike", CF(0, hy + 0.31, 0), -0.12, 0.12, 0, 0.5, 0.12, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy, 0.8)
	end
	return hy - 0.5, hy + 0.4
end

BUILD.BeardedAxe = function(K)
	local hy = 2.7
	K.haft(-0.85, hy + 0.36, 0.22, { rings = { hy - 0.8 }, langets = { hy - 0.8, hy - 0.3 } })
	axeEye(K, hy, 0.6)
	K.box("Poll", V(0.18, 0.4, 0.3), CF(0.26, hy, 0), shade(K.blade, 0.8), K.bladeMat)
	local sx = -1
	local t = 0.12
	-- straight top, long beard hooking down toward the haft
	K.box("Bit", V(0.72, 0.36, t), CF(sx * 0.5, hy + 0.1, 0), K.blade, K.bladeMat)
	local beard = K.box("Bit", V(0.28, 0.9, t - 0.01), CF(sx * 0.73, hy - 0.4, 0), shade(K.blade, 0.94), K.bladeMat)
	K.setFx(beard)
	K.tri("Beard", CF(sx * 0.59, hy - 0.08, 0) * ANG(0, 0, PI), -0.0, 0.3, 0, 0.62, t - 0.02, shade(K.blade, 0.9), K.bladeMat)
	K.tri("Beard", CF(sx * 0.73, hy - 0.85, 0), -0.14, 0.14, 0.14 * -sx, -0.3, t - 0.02, shade(K.blade, 0.9), K.bladeMat)
	K.edgeBevel("Edge", CF(), sx * 0.86, sx * 1.0, hy - 0.95, hy + 0.28, t)
	K.box("Edge", V(0.14, 0.05, t * 0.6), CF(sx * 0.93, hy + 0.3, 0), K.edge, K.edgeMat)
	K.zone(CF(sx * 0.5, hy + 0.1, 0) * ANG(0, 0, PI / 2), 0.5, 0.12, t / 2)
	if K.rare >= 3 then
		for _, sz in { -1, 1 } do
			K.box("Knot", V(0.16, 0.16, 0.02), CF(sx * 0.73, hy - 0.45, sz * (t / 2 + 0.005)) * ANG(0, 0, PI / 4), K.inlay, M.Metal)
		end
	end
	if K.rare >= 5 then
		K.tri("Spike", CF(0.35, hy, 0) * ANG(0, 0, -PI / 2), -0.15, 0.15, 0, 0.5, 0.12, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy - 0.2, 0.85)
	end
	return hy - 0.8, hy + 0.3
end

BUILD.Cleaver = function(K)
	-- full-tang wooden handle with rivets, huge rectangular blade
	K.box("Scale", V(0.2, 1.06, 0.26), CF(0, -0.02, 0), K.wood, M.Wood)
	K.box("Tang", V(0.21, 1.1, 0.06), CF(0, -0.02, 0), K.guardDark, K.guardMat)
	for _, y in { -0.35, 0.05, 0.4 } do
		K.box("Rivet", V(0.09, 0.09, 0.3), CF(0, y, 0), K.inlay, M.Metal)
	end
	K.box("Pommel", V(0.26, 0.12, 0.3), CF(0, -0.58, 0), K.guardDark, K.guardMat)
	K.box("Bolster", V(0.3, 0.16, 0.3), CF(0, 0.58, 0), K.guard, K.guardMat)
	local y0, L, W, sp = 0.64, 1.8, 1.02, 0.16
	local top = K.forge({ frame = CF(sp - W / 2, 0, 0), y0 = y0, len = L, w = W, t = 0.11, b = 0.16, single = 1, fuller = 0.8, fw = 0.1, fx = W / 2 - 0.14 })
	K.box("Spine", V(0.05, L, 0.13), CF(sp, y0 + L / 2, 0), K.dark, K.bladeMat)
	-- slanted top corner
	K.tri("Tip", CF(sp - W / 2, top, 0), -W / 2, W / 2, -W / 2, 0.24, 0.1, K.blade, K.bladeMat)
	-- hanging hole
	for _, sz in { -1, 1 } do
		K.box("Hole", V(0.16, 0.16, 0.02), CF(sp - 0.2, top - 0.15, sz * 0.056), rgb(14, 12, 12), M.Metal)
	end
	if K.chipped then
		for i = 0, 1 do
			K.box("Stain", V(0.2, 0.14, 0.12), CF(-0.5 + i * 0.3, y0 + 0.5 + i * 0.6, 0) * ANG(0, 0, 0.5), rgb(70, 30, 26), M.CorrodedMetal)
		end
	end
	if K.rare >= 5 then
		for i = 0, 3 do
			K.tri("Tooth", CF(sp + 0.02, y0 + 0.2 + i * 0.42, 0) * ANG(0, 0, -PI / 2), -0.09, 0.09, 0, 0.16, 0.08, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(y0 + 0.9, 0.9)
	end
	return y0 + 0.2, top + 0.24
end

BUILD.DoubleAxe = function(K)
	local hy = 2.75
	K.haft(-0.9, hy + 0.5, 0.22, { rings = { hy - 0.8, hy - 1.2 }, langets = { hy - 1.2, hy - 0.5 } })
	axeEye(K, hy, 0.9)
	for _, sx in { -1, 1 } do
		axeBlade(K, sx, { { 0.16, 0.4, hy - 0.22, hy + 0.22 }, { 0.4, 0.64, hy - 0.4, hy + 0.4 }, { 0.64, 0.84, hy - 0.6, hy + 0.6 } }, 0.14, 0.12)
	end
	K.tri("Spike", CF(0, hy + 0.45, 0), -0.14, 0.14, 0, 0.5, 0.14, K.guard, K.guardMat)
	K.tri("Spike", CF(0, hy + 0.45, 0) * ANG(0, PI / 2, 0), -0.1, 0.1, 0, 0.42, 0.1, K.guardDark, K.guardMat)
	if K.rare >= 5 then
		for _, sx in { -1, 1 } do
			K.tri("Horn", CF(sx * 0.95, hy + 0.66, 0), -0.08, 0.08, sx * 0.08, 0.3, 0.08, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy, 1.15)
	end
	return hy - 0.6, hy + 0.9
end

-- spears ------------------------------------------------------------
local function socket(K, y0: number, y1: number, w: number)
	K.box("Socket", V(w, y1 - y0, w), CF(0, (y0 + y1) / 2, 0), shade(K.blade, 0.82), K.bladeMat)
	K.box("Socket", V(w + 0.06, 0.08, w + 0.06), CF(0, y0 + 0.06, 0), K.guardDark, K.guardMat)
	K.box("Socket", V(w + 0.04, 0.08, w + 0.04), CF(0, y1 - 0.08, 0), K.guardDark, K.guardMat)
	if K.rare >= 3 then
		K.box("Inlay", V(w + 0.02, 0.05, w + 0.02), CF(0, (y0 + y1) / 2, 0) * ANG(0, PI / 4, 0), K.inlay, M.Metal)
	end
end

BUILD.Spear = function(K)
	local hy = 4.6
	K.haft(-1.35, hy + 0.1, 0.2, { rings = { 2.2 } })
	socket(K, hy - 0.1, hy + 0.5, 0.25)
	for _, sx in { 1, -1 } do
		K.tri("Lug", CF(sx * 0.12, hy + 0.05, 0) * ANG(0, 0, -sx * PI / 2), -0.08, 0.08, 0.04 * sx, 0.2, 0.08, K.guard, K.guardMat)
	end
	-- leaf blade with a raised midrib: narrow, wide, narrow, point
	local y = hy + 0.48
	y = K.forge({ y0 = y, len = 0.35, w = 0.3, t = 0.13, b = 0.12, noZone = true })
	y = K.forge({ y0 = y - 0.01, len = 0.55, w = 0.46, t = 0.13, b = 0.2 })
	y = K.forge({ y0 = y - 0.01, len = 0.35, w = 0.36, t = 0.12, b = 0.15, point = 0.6, noZone = true })
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.14, hy + 0.2, 0), 0, sx * 0.4, sx * 0.4, 0.5, 0.08, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy + 0.9, 0.55)
	end
	return hy + 0.6, y
end

BUILD.Partisan = function(K)
	local hy = 4.4
	K.haft(-1.35, hy + 0.1, 0.2, { rings = { 2.0, 2.2 } })
	socket(K, hy - 0.1, hy + 0.45, 0.26)
	-- flukes (ears) curving up from the base
	for _, sx in { 1, -1 } do
		K.box("Fluke", V(0.42, 0.14, 0.1), CF(sx * 0.3, hy + 0.5, 0) * ANG(0, 0, sx * 0.25), K.blade, K.bladeMat)
		K.tri("Fluke", CF(sx * 0.5, hy + 0.54, 0) * ANG(0, 0, -sx * 0.35), -0.08, 0.08, sx * 0.07, 0.4, 0.09, K.edge, K.edgeMat)
	end
	-- broad triangular head
	local y = hy + 0.42
	y = K.forge({ y0 = y, len = 0.5, w = 0.6, t = 0.13, b = 0.2 })
	K.box("Rib", V(0.08, 1.3, 0.16), CF(0, y + 0.2, 0), shade(K.blade, 0.9), K.bladeMat)
	K.tri("Tip", CF(0, y, 0), -0.3, 0.3, 0, 1.05, 0.07, K.edge, K.edgeMat)
	K.tri("Tip", CF(0, y - 0.01, 0), -0.2, 0.2, 0, 0.8, 0.13, K.blade, K.bladeMat)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.62, hy + 0.3, 0), -0.08, 0.08, 0, -0.4, 0.08, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy + 0.8, 0.7)
	end
	return hy + 0.5, y + 1.05
end

BUILD.Glaive = function(K)
	local hy = 4.2
	K.haft(-1.3, hy + 0.1, 0.21, { rings = { 2.0 }, langets = { hy - 0.6, hy } })
	socket(K, hy - 0.1, hy + 0.35, 0.27)
	-- long knife blade, edge on -X, curving toward the spine
	local frame = CF(0, hy + 0.32, 0)
	local segs = { 0.62, 0.62, 0.6 }
	for i, L in segs do
		local w = 0.44 - (i - 1) * 0.03
		K.forge({ frame = frame * CF(0.06, 0, 0), y0 = 0, len = L + 0.04, w = w, t = 0.12, b = 0.12, single = 1, fuller = if i < 3 then 0.9 else 0, fullerStart = if i == 1 then 0.1 else 0, fw = 0.07, fx = w / 2 - 0.1, noZone = i ~= 1 })
		frame = frame * CF(0, L, 0) * ANG(0, 0, -0.1)
	end
	K.tri("Tip", frame * CF(0.06, 0, 0), -0.18, 0.2, 0.17, 0.55, 0.07, K.edge, K.edgeMat)
	K.tri("Tip", frame * CF(0.06, -0.01, 0), -0.08, 0.2, 0.17, 0.4, 0.12, K.blade, K.bladeMat)
	-- back spike on the spine
	K.tri("Spike", CF(0.28, hy + 0.55, 0) * ANG(0, 0, -PI / 2 - 0.3), -0.1, 0.1, 0.05, 0.36, 0.1, K.guard, K.guardMat)
	-- tassel
	K.box("Tassel", V(0.12, 0.4, 0.12), CF(0.18, hy - 0.2, 0), K.accent:Lerp(rgb(110, 26, 26), 0.6), M.Fabric)
	if K.rare >= 5 then
		K.tri("Wing", CF(-0.22, hy + 0.3, 0), -0.1, 0.1, -0.1, -0.5, 0.08, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy + 1.0, 0.7)
	end
	return hy + 0.45, (frame * CF(0, 0.55, 0)).Position.Y
end

BUILD.Halberd = function(K)
	local hy = 4.4
	K.haft(-1.2, hy + 0.7, 0.21, { rings = { 2.1 }, langets = { hy - 0.9, hy - 0.1 } })
	socket(K, hy - 0.1, hy + 0.72, 0.26)
	-- axe blade on the leading side (-X), slightly crescent
	local t = 0.12
	K.box("Bit", V(0.3, 0.46, t), CF(-0.28, hy + 0.3, 0), shade(K.blade, 0.94), K.bladeMat)
	local body = K.box("Bit", V(0.44, 0.9, t - 0.01), CF(-0.63, hy + 0.3, 0), K.blade, K.bladeMat)
	K.setFx(body)
	K.edgeBevel("Edge", CF(), -0.85, -1.0, hy - 0.2, hy + 0.8, t - 0.01)
	K.tri("Horn", CF(-0.92, hy + 0.8, 0), -0.14, 0.08, -0.08, 0.24, t * 0.6, K.edge, K.edgeMat)
	K.tri("Horn", CF(-0.92, hy - 0.2, 0), -0.14, 0.08, -0.08, -0.2, t * 0.6, K.edge, K.edgeMat)
	K.zone(CF(-0.6, hy + 0.3, 0) * ANG(0, 0, PI / 2), 0.5, 0.14, t / 2)
	-- back fluke hooking down
	K.box("Fluke", V(0.3, 0.16, 0.1), CF(0.28, hy + 0.34, 0), K.blade, K.bladeMat)
	K.tri("Fluke", CF(0.42, hy + 0.42, 0) * ANG(0, 0, -PI / 2), -0.08, 0.08, 0.08, 0.5, 0.1, K.blade, K.bladeMat)
	-- top spike
	local y = K.forge({ y0 = hy + 0.7, len = 0.7, w = 0.2, t = 0.14, b = 0.1, point = 0.5, noZone = true })
	if K.rare >= 5 then
		K.tri("Wing", CF(-0.3, hy + 0.75, 0), -0.16, 0.1, -0.16, 0.5, 0.08, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy + 0.5, 0.9)
	end
	return hy + 0.3, y
end

BUILD.Pike = function(K)
	local hy = 5.8
	K.haft(-2.2, hy + 0.1, 0.18, { rings = { -1.5, 3.0 }, langets = { hy - 1.1, hy } })
	K.wraps(-1.9, -1.2, 3, 0.24)
	socket(K, hy - 0.05, hy + 0.3, 0.22)
	local y = K.forge({ y0 = hy + 0.28, len = 0.8, w = 0.22, t = 0.17, b = 0.11, point = 0.55, noZone = true })
	K.zone(CF(0, hy + 0.12, 0), 0.25, 0.1, 0.11)
	-- short side prongs (ranseur)
	for _, sx in { 1, -1 } do
		K.box("Prong", V(0.26, 0.08, 0.08), CF(sx * 0.16, hy + 0.3, 0), K.guardDark, K.guardMat)
		K.tri("Prong", CF(sx * 0.27, hy + 0.34, 0), -0.05, 0.05, 0, 0.3, 0.07, K.edge, K.edgeMat)
	end
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.1, hy + 0.15, 0) * ANG(0, 0, -sx * 0.5), -0.06, 0.06, 0, 0.4, 0.06, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy + 0.3, 0.5)
	end
	return hy, y
end

-- scythes: blade leads toward -X and curves down, edge on the lower side ----
local function scytheBlade(K, origin: CFrame, segs, w0: number, taper: number, curve: number, t: number)
	-- frame Y runs along the blade (toward -X), frame -X is the edge (down)
	local frame = origin * ANG(0, 0, PI / 2)
	for i, L in segs do
		local w = w0 - (i - 1) * taper
		K.forge({ frame = frame * CF(w / 2 - 0.04, 0, 0), y0 = 0, len = L + 0.05, w = w, t = t, b = 0.1, single = 1, noZone = i ~= 2, zoneK = 0.8 })
		K.box("Rib", V(0.05, L + 0.05, t + 0.03), frame * CF(w - 0.06, L / 2, 0), shade(K.blade, 0.8), K.bladeMat)
		frame = frame * CF(0, L, 0) * ANG(0, 0, curve)
	end
	local w = w0 - #segs * taper
	K.tri("Tip", frame, -0.02, w, -0.02, 0.5, t * 0.8, K.edge, K.edgeMat)
	return frame
end

BUILD.Scythe = function(K)
	local hy = 4.3
	K.haft(-1.3, hy + 0.1, 0.2, { rings = { 2.5 } })
	-- the nib (side grip) on the snath
	K.box("Nib", V(0.5, 0.13, 0.13), CF(0.24, 2.0, 0), K.wood, M.Wood)
	K.box("Nib", V(0.14, 0.24, 0.16), CF(0.48, 2.0, 0), K.guardDark, K.guardMat)
	K.box("Collar", V(0.32, 0.36, 0.32), CF(0, hy, 0), K.guard, K.guardMat)
	K.box("Collar", V(0.36, 0.08, 0.36), CF(0, hy + 0.12, 0), K.guardDark, K.guardMat)
	K.box("Tang", V(0.34, 0.22, 0.12), CF(-0.2, hy + 0.08, 0), shade(K.blade, 0.8), K.bladeMat)
	scytheBlade(K, CF(-0.3, hy + 0.18, 0), { 0.8, 0.8, 0.75, 0.7, 0.62 }, 0.5, 0.07, 0.17, 0.08)
	if K.rare >= 3 then
		K.gem(CF(0, hy, -0.17), 0.13)
	end
	if K.rare >= 5 then
		K.tri("Spike", CF(0, hy + 0.2, 0), -0.1, 0.1, 0, 0.6, 0.1, K.guard, K.guardMat)
		K.tri("Spike", CF(0.16, hy, 0) * ANG(0, 0, -PI / 2), -0.1, 0.1, 0, 0.36, 0.1, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy, 1.0)
	end
	return hy - 0.3, hy + 0.3
end

BUILD.WarScythe = function(K)
	local hy = 4.3
	K.haft(-1.3, hy + 0.3, 0.21, { rings = { 2.3 } })
	-- the tang is bent and lashed along the pole with three iron rings
	K.box("Tang", V(0.12, 0.8, 0.1), CF(-0.14, hy, 0), K.dark, K.bladeMat)
	for i = 0, 2 do
		K.box("Lash", V(0.4, 0.09, 0.28), CF(-0.06, hy - 0.28 + i * 0.28, 0), K.guardDark, K.guardMat)
	end
	-- straightened blade: long, narrow, beaked toward the edge side
	local frame = CF(-0.1, hy + 0.36, 0)
	for i, L in { 0.8, 0.8, 0.7 } do
		local w = 0.34 - (i - 1) * 0.02
		K.forge({ frame = frame * CF(0.02, 0, 0), y0 = 0, len = L + 0.04, w = w, t = 0.1, b = 0.11, single = 1, noZone = i ~= 1, fuller = if i < 3 then 0.9 else 0, fullerStart = if i == 1 then 0.1 else 0, fw = 0.06, fx = w / 2 - 0.08 })
		frame = frame * CF(0, L, 0) * ANG(0, 0, 0.12)
	end
	K.tri("Tip", frame * CF(0.02, 0, 0), -0.15, 0.16, -0.15, 0.5, 0.06, K.edge, K.edgeMat)
	K.tri("Tip", frame * CF(0.02, -0.01, 0), -0.08, 0.16, -0.1, 0.36, 0.1, K.blade, K.bladeMat)
	if K.rare >= 5 then
		K.tri("Spike", CF(0.12, hy + 0.2, 0) * ANG(0, 0, -PI / 2), -0.1, 0.1, -0.1, 0.4, 0.1, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy + 1.2, 0.7)
	end
	return hy + 0.4, (frame * CF(0, 0.5, 0)).Position.Y
end

BUILD.GraveScythe = function(K)
	local hy = 4.4
	K.haft(-1.4, hy + 0.15, 0.22, { rings = { 2.4, 2.6 }, col = shade(K.wood, 0.7) })
	-- a skull at the collar
	local bone = rgb(222, 214, 192)
	K.box("Skull", V(0.44, 0.4, 0.42), CF(0, hy, 0), bone, M.Marble)
	K.box("Skull", V(0.34, 0.14, 0.3), CF(0, hy - 0.24, -0.04), shade(bone, 0.9), M.Marble)
	for _, sx in { 1, -1 } do
		K.box("Socket", V(0.12, 0.1, 0.03), CF(sx * 0.1, hy + 0.02, -0.21), rgb(16, 12, 12), M.Slate)
		if K.glowing then
			K.box("Eye", V(0.05, 0.05, 0.02), CF(sx * 0.1, hy + 0.02, -0.225), K.glow, M.Neon)
		end
	end
	K.box("Collar", V(0.34, 0.14, 0.34), CF(0, hy + 0.26, 0), K.guardDark, K.guardMat)
	-- the main blade and a smaller counter blade
	scytheBlade(K, CF(-0.2, hy + 0.3, 0), { 0.85, 0.85, 0.8, 0.72, 0.62 }, 0.56, 0.08, 0.18, 0.09)
	local fr = CF(0.2, hy + 0.2, 0) * ANG(0, PI, 0)
	scytheBlade(K, fr, { 0.45, 0.4, 0.35 }, 0.3, 0.05, 0.3, 0.08)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Horn", CF(sx * 0.14, hy + 0.2, 0), -0.06, 0.06, sx * 0.1, 0.4, 0.08, bone, M.Marble)
		end
	end
	if K.rare >= 6 then
		K.halo(hy, 1.0)
	end
	return hy - 0.3, hy + 0.35
end

-- daggers -----------------------------------------------------------
local DY = 0.7 -- dagger guard height

BUILD.Seax = function(K)
	K.box("Handle", V(0.24, 1.14, 0.24), CF(0, 0.07, 0), K.wood, M.Wood)
	for _, y in { -0.3, 0.1, 0.5 } do
		K.box("Band", V(0.27, 0.07, 0.27), CF(0, y, 0), K.guardDark, K.guardMat)
	end
	K.pommel("cap", -0.5, 0.28)
	K.box("Guard", V(0.46, 0.12, 0.26), CF(0, DY - 0.05, 0), K.guard, K.guardMat)
	-- broken-back single edge: spine on +X
	local y = K.forge({ y0 = DY, len = 1.0, w = 0.34, t = 0.1, b = 0.1, single = 1, fuller = 0.8, fw = 0.06, fx = 0.07 })
	-- the back breaks down toward the point
	K.tri("Tip", CF(0, y, 0), -0.17, 0.17, -0.12, 0.62, 0.06, K.edge, K.edgeMat)
	K.tri("Tip", CF(0, y - 0.01, 0), -0.08, 0.17, -0.06, 0.46, 0.1, K.blade, K.bladeMat)
	if K.rare >= 3 then
		for _, sz in { -1, 1 } do
			K.box("Inlay", V(0.22, 0.04, 0.02), CF(0, 0.1, sz * 0.13), K.inlay, M.Metal)
		end
	end
	if K.rare >= 5 then
		K.tri("Spike", CF(0.17, DY + 0.3, 0) * ANG(0, 0, -PI / 2), -0.08, 0.08, 0, 0.16, 0.06, K.guard, K.guardMat)
		K.tri("Wing", CF(-0.12, DY, 0), -0.14, 0.06, -0.14, 0.36, 0.06, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(DY + 0.5, 0.42)
	end
	return DY + 0.1, y + 0.62
end

BUILD.Stiletto = function(K)
	K.wraps(-0.42, DY - 0.1, 4, 0.22)
	K.pommel("ring", -0.46, 0.4)
	K.cyl("Guard", 0.1, 0.48, CF(0, DY - 0.04, 0), K.guard, K.guardMat)
	K.box("Guard", V(0.16, 0.14, 0.16), CF(0, DY + 0.06, 0), K.guardDark, K.guardMat)
	local y0, L = DY + 0.12, 1.55
	local core = K.box("Blade", V(0.04, L, 0.13), CF(0, y0 + L / 2, 0), K.blade, K.bladeMat)
	K.setFx(core)
	K.edgeBevel("Edge", CF(), 0.02, 0.09, y0, y0 + L, 0.13)
	K.edgeBevel("Edge", CF(), -0.02, -0.09, y0, y0 + L, 0.13)
	K.tri("Tip", CF(0, y0 + L, 0), -0.09, 0.09, 0, 0.45, 0.08, K.edge, K.edgeMat)
	K.zone(CF(0, 0.06, 0), 0.6, 0.12, 0.11)
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(0, DY + 0.04, 0), sx * 0.08, sx * 0.34, sx * 0.1, 0.3, 0.05, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(DY + 0.5, 0.38)
	end
	return y0, y0 + L + 0.45
end

BUILD.ParryingDagger = function(K)
	K.wraps(-0.42, DY - 0.1, 4, 0.23)
	K.pommel("nut", -0.46, 0.3)
	local g, gm, gd = K.guard, K.guardMat, K.guardDark
	K.box("Guard", V(1.2, 0.1, 0.14), CF(0, DY, 0), gd, gm)
	for _, sx in { 1, -1 } do
		K.ball("Quillon", 0.16, CF(sx * 0.62, DY, 0), g, gm)
	end
	-- side ring and a triangular shell over the fingers (-Z side)
	for i = 0, 3 do
		K.box("Ring", V(0.34, 0.07, 0.07), CF(0, DY - 0.04, -0.18) * ANG(PI / 2, 0, 0) * ANG(0, 0, i * PI / 2 + PI / 4) * CF(0, 0.15, 0) * ANG(PI / 2, 0, 0), g, gm)
	end
	K.tri("Shell", CF(0, DY + 0.06, -0.1) * ANG(-0.25, 0, 0), -0.36, 0.36, 0, -0.5, 0.04, g, gm)
	-- straight blade with notched ricasso and a stepped taper
	K.box("Ricasso", V(0.3, 0.24, 0.12), CF(0, DY + 0.16, 0), shade(K.blade, 0.88), K.bladeMat)
	for _, sx in { 1, -1 } do
		K.box("Notch", V(0.06, 0.08, 0.13), CF(sx * 0.15, DY + 0.22, 0), K.dark, K.bladeMat)
	end
	local y = K.forge({ y0 = DY + 0.27, len = 0.8, w = 0.3, t = 0.1, b = 0.1, fuller = 0.8, fw = 0.06 })
	y = K.forge({ y0 = y - 0.01, len = 0.55, w = 0.22, t = 0.09, b = 0.08, point = 0.45, noZone = true })
	if K.rare >= 5 then
		for _, sx in { 1, -1 } do
			K.tri("Wing", CF(sx * 0.4, DY + 0.05, 0), -0.06, 0.06, sx * 0.1, 0.32, 0.05, g, gm)
		end
	end
	if K.rare >= 6 then
		K.halo(DY + 0.6, 0.45)
	end
	return DY + 0.3, y
end

BUILD.Kris = function(K)
	-- pistol-grip handle angled back, asymmetric ganja, wavy blade
	K.box("Handle", V(0.25, 1.1, 0.25), CF(0.03, 0.06, 0) * ANG(0, 0, -0.1), K.wood, M.Wood)
	K.box("Handle", V(0.3, 0.24, 0.27), CF(0.14, -0.48, 0) * ANG(0, 0, -0.6), shade(K.wood, 0.85), M.Wood)
	K.box("Selut", V(0.3, 0.1, 0.3), CF(0, 0.6, 0), K.guard, K.guardMat)
	local g, gm = K.guard, K.guardMat
	K.box("Ganja", V(0.62, 0.12, 0.16), CF(-0.08, DY - 0.04, 0), shade(K.blade, 0.85), K.bladeMat)
	K.tri("Ganja", CF(-0.39, DY - 0.1, 0), -0.12, 0.08, -0.12, 0.3, 0.14, shade(K.blade, 0.85), K.bladeMat)
	-- the blade follows a sinuous centre line (a polyline of short segments)
	local xs = { 0, 0.07, -0.06, 0.06, -0.05, 0 }
	local frame = CF()
	for i = 1, #xs - 1 do
		local p0 = V(xs[i], DY + 0.02 + (i - 1) * 0.34, 0)
		local p1 = V(xs[i + 1], DY + 0.02 + i * 0.34, 0)
		local d = p1 - p0
		local l = d.Magnitude
		frame = CF(p0) * ANG(0, 0, -math.asin(d.X / l))
		local w = 0.32 - i * 0.025
		local core = K.box("Blade", V(w - 0.14, l + 0.08, 0.11), frame * CF(0, l / 2, 0), K.blade, K.bladeMat)
		if i == 2 then
			K.setFx(core)
			K.zone(frame * CF(0, l / 2, 0), l * 0.8, 0.08, 0.055)
		end
		K.edgeBevel("Edge", frame, w / 2 - 0.07, w / 2, -0.04, l + 0.04, 0.11)
		K.edgeBevel("Edge", frame, -(w / 2 - 0.07), -w / 2, -0.04, l + 0.04, 0.11)
		frame = frame * CF(0, l, 0)
	end
	K.tri("Tip", frame, -0.1, 0.1, 0, 0.36, 0.08, K.edge, K.edgeMat)
	if K.rare >= 3 then
		K.gem(CF(0.12, -0.4, -0.14), 0.1)
	end
	if K.rare >= 5 then
		K.tri("Wing", CF(0.2, DY - 0.04, 0), -0.06, 0.1, 0.1, 0.34, 0.06, g, gm)
	end
	if K.rare >= 6 then
		K.halo(DY + 0.6, 0.45)
	end
	return DY + 0.1, (frame * CF(0, 0.36, 0)).Position.Y
end

-- hammers (striking face leads toward -X) ---------------------------------
BUILD.Warhammer = function(K)
	local hy = 2.8
	K.haft(-0.85, hy + 0.3, 0.24, { rings = { hy - 0.6 }, langets = { hy - 1.0, hy - 0.2 } })
	local head = shade(K.blade, 0.9)
	local core = K.box("Head", V(0.56, 0.56, 0.56), CF(0, hy, 0), head, K.bladeMat)
	K.setFx(core)
	for _, y in { hy - 0.2, hy + 0.2 } do
		K.box("Band", V(0.62, 0.08, 0.62), CF(0, y, 0), K.guardDark, K.guardMat)
	end
	-- stepped striking face with a checkered (waffled) surface
	K.box("Face", V(0.2, 0.64, 0.64), CF(-0.36, hy, 0), K.blade, K.bladeMat)
	K.box("Face", V(0.14, 0.72, 0.72), CF(-0.52, hy, 0), K.edge, K.bladeMat)
	for i = 0, 3 do
		local yy, zz = (i % 2 - 0.5) * 0.34, (math.floor(i / 2) - 0.5) * 0.34
		K.box("Waffle", V(0.1, 0.22, 0.22), CF(-0.62, hy + yy, zz) * ANG(PI / 4, 0, 0), shade(K.edge, 0.9), K.bladeMat)
	end
	-- back spike (+X) and top spike
	K.tri("Spike", CF(0.28, hy, 0) * ANG(0, 0, -PI / 2), -0.2, 0.2, 0, 0.62, 0.16, K.blade, K.bladeMat)
	K.tri("Spike", CF(0.28, hy, 0) * ANG(0, 0, -PI / 2) * ANG(0, PI / 2, 0), -0.14, 0.14, 0, 0.5, 0.1, K.dark, K.bladeMat)
	K.box("Cap", V(0.26, 0.14, 0.26), CF(0, hy + 0.35, 0), K.guard, K.guardMat)
	K.tri("Spike", CF(0, hy + 0.4, 0), -0.1, 0.1, 0, 0.3, 0.1, K.guard, K.guardMat)
	K.zone(CF(0, hy, 0), 0.26, 0.3, 0.28)
	if K.rare >= 5 then
		for _, sz in { -1, 1 } do
			K.tri("Wing", CF(0, hy, sz * 0.28) * ANG(0, PI / 2, 0) * ANG(0, 0, -sz * PI / 2), -0.18, 0.18, 0, 0.4, 0.08, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy, 0.8)
	end
	return hy - 0.3, hy + 0.35
end

BUILD.FlangedMace = function(K)
	local hy = 2.65
	K.haft(-0.7, hy + 0.2, 0.22, { col = shade(K.guard, 0.7), noWrap = false, rings = { hy - 0.5 } })
	local head = K.blade
	local core = K.box("Head", V(0.3, 0.72, 0.3), CF(0, hy, 0), shade(head, 0.8), K.bladeMat)
	K.setFx(core)
	for i = 0, 5 do
		local a = i * PI / 3
		local fr = CF(0, hy, 0) * ANG(0, a, 0)
		K.box("Flange", V(0.07, 0.5, 0.32), fr * CF(0, -0.06, 0.28), if i % 2 == 0 then head else shade(head, 0.9), K.bladeMat)
		K.wedge("Flange", V(0.07, 0.26, 0.32), fr * CF(0, 0.32, 0.28), head, K.bladeMat)
		K.box("Flange", V(0.08, 0.34, 0.06), fr * CF(0, -0.06, 0.45), K.edge, K.bladeMat)
	end
	K.box("Collar", V(0.36, 0.12, 0.36), CF(0, hy - 0.42, 0), K.guardDark, K.guardMat)
	K.box("Knob", V(0.24, 0.2, 0.24), CF(0, hy + 0.44, 0), K.guard, K.guardMat)
	K.zone(CF(0, hy - 0.08, 0) * ANG(0, PI / 2, 0), 0.26, 0.1, 0.035)
	if K.rare >= 3 then
		K.gem(CF(0, hy + 0.44, -0.12), 0.1)
	end
	if K.rare >= 5 then
		K.tri("Spike", CF(0, hy + 0.52, 0), -0.1, 0.1, 0, 0.5, 0.1, K.guard, K.guardMat)
		K.tri("Spike", CF(0, hy + 0.52, 0) * ANG(0, PI / 2, 0), -0.1, 0.1, 0, 0.5, 0.1, K.guardDark, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy, 0.75)
	end
	return hy - 0.3, hy + 0.4
end

local function stud(K, cf: CFrame, len: number, w: number, col, mat)
	K.box("Stud", V(w, len * 0.5, w), cf * CF(0, len * 0.25, 0), col, mat)
	K.box("Stud", V(w * 0.58, len * 0.4, w * 0.58), cf * CF(0, len * 0.66, 0), col, mat)
	K.box("Stud", V(w * 0.26, len * 0.2, w * 0.26), cf * CF(0, len * 0.94, 0), shade(col, 1.15), mat)
end

BUILD.MorningStar = function(K)
	local hy = 2.75
	K.haft(-0.75, hy - 0.2, 0.24, { rings = { hy - 0.5 }, langets = { hy - 1.0, hy - 0.4 } })
	local head = shade(K.blade, 0.85)
	local core = K.box("Head", V(0.72, 0.72, 0.72), CF(0, hy, 0), head, K.bladeMat)
	K.setFx(core)
	K.box("Head", V(0.64, 0.8, 0.64), CF(0, hy, 0) * ANG(0, PI / 4, 0), shade(head, 0.9), K.bladeMat)
	for _, y in { hy - 0.3, hy + 0.3 } do
		K.box("Band", V(0.78, 0.08, 0.78), CF(0, y, 0), K.guardDark, K.guardMat)
	end
	local dirs = {
		ANG(0, 0, PI / 2), ANG(0, 0, -PI / 2), ANG(PI / 2, 0, 0), ANG(-PI / 2, 0, 0), CF(),
		ANG(0, 0, PI / 4) * ANG(PI / 4, 0, 0), ANG(0, 0, -PI / 4) * ANG(-PI / 4, 0, 0),
		ANG(0, 0, PI / 4) * ANG(-PI / 4, 0, 0), ANG(0, 0, -PI / 4) * ANG(PI / 4, 0, 0),
	}
	for i, d in dirs do
		local len = if i <= 5 then 0.5 else 0.4
		stud(K, CF(0, hy, 0) * d * CF(0, 0.36, 0), len, 0.2, K.edge, K.bladeMat)
	end
	K.zone(CF(0, hy, 0), 0.2, 0.3, 0.36)
	if K.rare >= 5 then
		for _, sz in { -1, 1 } do
			K.tri("Wing", CF(0, hy - 0.4, sz * 0.1), -0.34, 0.34, 0, -0.3, 0.06, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy, 0.9)
	end
	return hy - 0.3, hy + 0.9
end

BUILD.Warpick = function(K)
	local hy = 2.85
	K.haft(-0.8, hy + 0.25, 0.22, { rings = { hy - 0.55 }, langets = { hy - 1.0, hy - 0.25 } })
	K.box("Head", V(0.36, 0.5, 0.36), CF(0, hy, 0), shade(K.blade, 0.85), K.bladeMat)
	K.box("Band", V(0.4, 0.07, 0.4), CF(0, hy + 0.2, 0), K.guardDark, K.guardMat)
	-- long beak curving down toward the leading side (-X)
	local frame = CF(-0.16, hy + 0.05, 0) * ANG(0, 0, PI / 2)
	local ws = { 0.3, 0.24, 0.18, 0.13 }
	for i, w in ws do
		local L = 0.36
		local p = K.box("Beak", V(w, L + 0.04, w), frame * CF(0, L / 2, 0) * ANG(0, PI / 4, 0), if i % 2 == 0 then K.blade else shade(K.blade, 0.9), K.bladeMat)
		if i == 2 then
			K.setFx(p)
		end
		frame = frame * CF(0, L, 0) * ANG(0, 0, 0.14)
	end
	K.tri("Tip", frame, -0.07, 0.07, 0, 0.3, 0.09, K.edge, K.bladeMat)
	K.tri("Tip", frame * ANG(0, PI / 2, 0), -0.07, 0.07, 0, 0.3, 0.09, K.edge, K.bladeMat)
	-- small hammer face at the back
	K.box("Face", V(0.2, 0.34, 0.34), CF(0.26, hy, 0), K.blade, K.bladeMat)
	K.box("Face", V(0.08, 0.4, 0.4), CF(0.38, hy, 0), K.edge, K.bladeMat)
	K.tri("Spike", CF(0, hy + 0.25, 0), -0.08, 0.08, 0, 0.4, 0.08, K.guard, K.guardMat)
	K.zone(CF(0, hy - 0.05, 0), 0.22, 0.14, 0.18)
	if K.rare >= 5 then
		K.tri("Wing", CF(0.2, hy + 0.1, 0), -0.1, 0.12, 0.12, 0.5, 0.08, K.guard, K.guardMat)
	end
	if K.rare >= 6 then
		K.halo(hy, 0.75)
	end
	return hy - 0.3, hy + 0.3
end

BUILD.Maul = function(K)
	local hy = 3.3
	K.haft(-1.1, hy - 0.2, 0.26, { rings = { 1.2, hy - 0.6 }, langets = { hy - 1.2, hy - 0.4 } })
	K.wraps(-1.0, -0.55, 2, 0.32)
	-- a stone block bound in iron
	local stone = rgb(96, 92, 90):Lerp(K.blade, 0.3)
	local core = K.box("Head", V(1.5, 0.8, 0.8), CF(0, hy, 0), stone, M.Slate)
	K.setFx(core)
	for _, sx in { -1, 1 } do
		K.box("Face", V(0.14, 0.86, 0.86), CF(sx * 0.72, hy, 0), K.dark, K.bladeMat)
		K.box("Face", V(0.06, 0.6, 0.6), CF(sx * 0.8, hy, 0), K.edge, K.bladeMat)
		K.box("Band", V(0.12, 0.86, 0.86), CF(sx * 0.32, hy, 0), K.guardDark, K.guardMat)
	end
	K.box("Chip", V(0.3, 0.2, 0.84), CF(-0.2, hy + 0.36, 0) * ANG(0, 0, 0.2), shade(stone, 0.85), M.Slate)
	for _, sz in { -1, 1 } do
		K.box("Rivet", V(0.1, 0.1, 0.04), CF(0.32, hy + 0.3, sz * 0.44), K.inlay, M.Metal)
		K.box("Rivet", V(0.1, 0.1, 0.04), CF(-0.32, hy - 0.3, sz * 0.44), K.inlay, M.Metal)
	end
	K.zone(CF(0, hy, 0) * ANG(0, 0, PI / 2), 0.5, 0.2, 0.4)
	if K.rare >= 5 then
		for _, sx in { -1, 1 } do
			K.tri("Spike", CF(sx * 0.5, hy + 0.4, 0), -0.12, 0.12, 0, 0.4, 0.12, K.guard, K.guardMat)
		end
	end
	if K.rare >= 6 then
		K.halo(hy, 1.1)
	end
	return hy - 0.4, hy + 0.4
end

-- ------------------------------------------------------------------ assembly
local function addFx(K, grip: BasePart, s: number)
	local part = K.fx or grip
	if K.el then
		local fx = ELEMENT_FX[K.el]
		if fx then
			local e = Instance.new("ParticleEmitter")
			e.Name = "ElementFX"
			e.Texture = fx.tex
			e.Color = ColorSequence.new(K.glow:Lerp(rgb(255, 255, 255), 0.25), K.glow)
			e.LightEmission = fx.emit
			e.Rate = fx.rate * (if K.rare >= 6 then 1.8 elseif K.rare >= 5 then 1.4 else 1)
			e.Lifetime = NumberRange.new(fx.life[1], fx.life[2])
			e.Speed = NumberRange.new(fx.speed[1] * s, fx.speed[2] * s)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fx.size * s), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
			e.SpreadAngle = Vector2.new(35, 35)
			e.Rotation = NumberRange.new(0, 360)
			e.LockedToPart = false
			e.Acceleration = fx.acc * s
			e.Parent = part
		end
	end
	if K.rare >= 5 or K.el then
		local l = Instance.new("PointLight")
		l.Color = K.glow
		l.Range = (if K.rare >= 5 then 8 else 6) * math.max(s, 0.6)
		l.Brightness = if K.rare >= 6 then 1.8 elseif K.rare >= 5 then 1.3 else 0.8
		l.Shadows = false
		l.Parent = part
	end
end

-- Returns a Model with PrimaryPart "Grip" at the origin (unanchored, welded).
function Weapons.buildModel(item, scale: number?): Model
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Weapon"
	local kind = item.kind or "Sword"
	local b = Weapons.baseOf(item)
	local K = newKit(model, item)
	-- the grip: the part the hand holds, always at the origin
	local gripSize = if kind == "Axe" or kind == "Spear" or kind == "Scythe" or kind == "Hammer" then V(0.2, 0.9, 0.2) else V(0.2, 1.3, 0.2)
	local grip = basePart("Part", model, "Grip", gripSize, CF(), shade(K.gripC, 0.7), M.Leather)
	model.PrimaryPart = grip
	local fn = BUILD[b.id] or BUILD[CLASSIC[kind] or "Longsword"] or BUILD.Longsword
	local ok, baseY, tipY = pcall(fn, K)
	if not ok then
		warn("[Weapons] " .. tostring(b.id) .. ": " .. tostring(baseY))
		baseY, tipY = 0.8, 3
	end
	baseY = baseY or 0.8
	tipY = tipY or 3
	K.decorate()
	-- scale everything around the grip
	if s ~= 1 then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local cf = p.CFrame
				p.Size = p.Size * s
				p.CFrame = cf - cf.Position + cf.Position * s
			end
		end
	end
	addFx(K, grip, s)
	local a0 = Instance.new("Attachment")
	a0.Name = "Base"
	a0.Position = V(0, baseY * s, 0)
	a0.Parent = grip
	local a1 = Instance.new("Attachment")
	a1.Name = "Tip"
	a1.Position = V(0, tipY * s, 0)
	a1.Parent = grip
	-- weld everything to grip
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= grip then
			local w = Instance.new("WeldConstraint")
			w.Part0 = grip
			w.Part1 = p
			w.Parent = p
		end
	end
	model:SetAttribute("TipY", tipY * s)
	model:SetAttribute("BaseY", baseY * s)
	model:SetAttribute("Base", b.id)
	return model
end

-- ------------------------------------------------------------------ NPC weapons
-- Simple NPC/enemy weapons (not loot). Kept light: many enemies carry one.
-- The grip sits where the hand holds the weapon.
function Weapons.npcModel(kind: string): Model
	local model = Instance.new("Model")
	model.Name = "NPCWeapon"
	local K = newKit(model, { rarity = "Uncommon", shape = #kind * 37, colors = { blade = Util.arr(Palette.metal.iron), guard = Util.arr(Palette.metal.dark), grip = Util.arr(rgb(70, 46, 32)) } })
	local wood = rgb(104, 72, 44)
	local iron = Palette.metal.iron
	local dark = Palette.metal.dark
	local grip = basePart("Part", model, "Grip", V(0.2, 0.8, 0.2), CF(), rgb(66, 44, 30), M.Leather)
	model.PrimaryPart = grip
	local function pole(y0, y1, w, col)
		K.box("Haft", V(w, y1 - y0, w), CF(0, (y0 + y1) / 2, 0), col or wood, M.Wood)
	end
	if kind == "pitchfork" then
		pole(-0.9, 3.6, 0.18)
		K.box("Socket", V(0.24, 0.3, 0.24), CF(0, 3.55, 0), dark, M.CorrodedMetal)
		K.box("Bar", V(0.95, 0.12, 0.12), CF(0, 3.72, 0), iron, M.CorrodedMetal)
		for i = -1, 1 do
			K.box("Tine", V(0.09, 0.8, 0.09), CF(i * 0.42, 4.15, 0) * ANG(0, 0, -i * 0.06), iron, M.CorrodedMetal)
			K.tri("Tine", CF(i * 0.42 - i * 0.03, 4.54, 0), -0.045, 0.045, 0, 0.2, 0.09, iron, M.CorrodedMetal)
		end
	elseif kind == "torch" then
		pole(-0.5, 1.2, 0.22, rgb(80, 56, 36))
		K.box("Wrap", V(0.28, 0.2, 0.28), CF(0, 0.3, 0), rgb(60, 50, 40), M.Fabric)
		local head = K.box("Head", V(0.42, 0.5, 0.42), CF(0, 1.35, 0), rgb(56, 38, 28), M.Fabric)
		K.box("Band", V(0.46, 0.08, 0.46), CF(0, 1.14, 0), dark, M.CorrodedMetal)
		K.box("Ember", V(0.3, 0.12, 0.3), CF(0, 1.62, 0), rgb(255, 140, 50), M.Neon)
		local f = Instance.new("Fire")
		f.Size = 3
		f.Heat = 6
		f.Parent = head
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 150, 60)
		l.Range = 16
		l.Brightness = 1.4
		l.Parent = head
	elseif kind == "club" then
		grip.Size = V(0.26, 0.8, 0.26)
		grip.Material = M.Wood
		grip.Color = wood
		K.box("Head", V(0.5, 1.0, 0.5), CF(0, 0.8, 0), wood, M.Wood)
		K.box("Head", V(0.66, 1.0, 0.66), CF(0, 1.6, 0) * ANG(0, 0.4, 0.05), shade(wood, 0.9), M.Wood)
		K.box("Knot", V(0.3, 0.3, 0.3), CF(0.3, 1.3, 0.1) * ANG(0.4, 0.3, 0), shade(wood, 0.8), M.Wood)
		for i = 1, 4 do
			K.box("Nail", V(0.1, 0.1, 0.36), CF(((i % 2) - 0.5) * 0.3, 1.1 + i * 0.25, -0.3) * ANG(0.2 * (i % 2), 0, 0), iron, M.CorrodedMetal)
		end
	elseif kind == "bigclub" then
		grip.Size = V(0.4, 1.4, 0.4)
		grip.Color = wood
		grip.Material = M.Wood
		K.box("Head", V(1.1, 1.6, 1.1), CF(0, 1.5, 0), rgb(90, 70, 60), M.Slate)
		K.box("Head", V(1.4, 1.5, 1.4), CF(0, 2.8, 0) * ANG(0, 0.5, 0.06), rgb(100, 82, 70), M.Slate)
		K.box("Band", V(1.2, 0.2, 1.2), CF(0, 2.1, 0), dark, M.CorrodedMetal)
		for i = 1, 5 do
			local a = i * 1.3
			K.box("Spike", V(0.26, 0.26, 0.6), CF(0, 1.7 + i * 0.35, 0) * ANG(0, a, 0) * CF(0, 0, -0.7) * ANG(PI / 4, 0, 0), iron, M.CorrodedMetal)
		end
	elseif kind == "spear" then
		pole(-1.6, 3.9, 0.18)
		K.box("Socket", V(0.24, 0.5, 0.24), CF(0, 3.9, 0), dark, M.Metal)
		K.forge({ y0 = 4.1, len = 0.55, w = 0.36, t = 0.12, b = 0.16, point = 0.5, noZone = true })
	elseif kind == "sword" then
		K.wraps(-0.38, 0.38, 3, 0.24)
		K.box("Pommel", V(0.3, 0.24, 0.3), CF(0, -0.52, 0), dark, M.Metal)
		K.box("Guard", V(0.95, 0.14, 0.22), CF(0, 0.47, 0), dark, M.Metal)
		K.forge({ y0 = 0.54, len = 2.6, w = 0.32, t = 0.1, b = 0.09, point = 0.5, noZone = true })
	elseif kind == "halberd" then
		pole(-2.0, 4.1, 0.2)
		K.box("Socket", V(0.26, 0.7, 0.26), CF(0, 3.8, 0), dark, M.Metal)
		K.box("Axe", V(0.8, 0.8, 0.12), CF(-0.5, 3.8, 0), Palette.metal.steel, M.Metal)
		K.edgeBevel("Edge", CF(), -0.9, -1.05, 3.35, 4.25, 0.12, shade(Palette.metal.steel, 1.2), M.Metal)
		K.box("Fluke", V(0.4, 0.14, 0.1), CF(0.3, 3.85, 0), Palette.metal.steel, M.Metal)
		K.forge({ y0 = 4.15, len = 0.6, w = 0.2, t = 0.12, b = 0.1, point = 0.4, noZone = true, col = Palette.metal.steel })
	elseif kind == "bow" then
		grip.Size = V(0.18, 0.6, 0.2)
		for i = -3, 3 do
			if i ~= 0 then
				local a = math.abs(i)
				local sy = if i > 0 then 1 else -1
				K.box("Limb", V(0.14, 0.62, 0.18 - a * 0.02), CF(0, sy * (0.12 + a * 0.52), -(a * a) * 0.055) * ANG(sy * a * 0.13, 0, 0), wood, M.Wood)
			end
		end
		K.box("Nock", V(0.12, 0.14, 0.14), CF(0, 1.76, -0.5), rgb(210, 200, 180), M.Marble)
		K.box("Nock", V(0.12, 0.14, 0.14), CF(0, -1.76, -0.5), rgb(210, 200, 180), M.Marble)
		K.box("String", V(0.03, 3.5, 0.03), CF(0, 0, -0.52), rgb(230, 226, 214), M.Fabric)
		K.wraps(-0.28, 0.28, 2, 0.22)
	elseif kind == "staff" then
		pole(-2.2, 2.4, 0.2, rgb(78, 56, 40))
		K.box("Knot", V(0.28, 0.3, 0.28), CF(0, 0.9, 0) * ANG(0, 0.5, 0), rgb(66, 46, 34), M.Wood)
		-- claw cradling the orb
		for i = 0, 2 do
			K.box("Claw", V(0.1, 0.6, 0.1), CF(0, 2.5, 0) * ANG(0, i * 2.09, 0) * CF(0, 0, 0.22) * ANG(-0.35, 0, 0), rgb(70, 50, 36), M.Wood)
		end
		local orb = K.box("Orb", V(0.5, 0.5, 0.5), CF(0, 2.85, 0) * ANG(PI / 4, PI / 4, 0), rgb(140, 200, 255), M.Neon)
		local l = Instance.new("PointLight")
		l.Color = orb.Color
		l.Range = 10
		l.Parent = orb
	elseif kind == "dagger" then
		K.wraps(-0.3, 0.3, 2, 0.22)
		K.box("Guard", V(0.5, 0.1, 0.2), CF(0, 0.42, 0), dark, M.Metal)
		K.forge({ y0 = 0.47, len = 0.95, w = 0.26, t = 0.08, b = 0.08, point = 0.4, noZone = true, col = Palette.metal.steel })
	elseif kind == "axe" then
		pole(-0.5, 2.5, 0.2)
		K.box("Eye", V(0.32, 0.5, 0.32), CF(0, 2.3, 0), dark, M.Metal)
		K.box("Bit", V(0.6, 0.5, 0.12), CF(-0.44, 2.3, 0), iron, M.CorrodedMetal)
		K.box("Bit", V(0.24, 0.9, 0.11), CF(-0.82, 2.25, 0), iron, M.CorrodedMetal)
		K.edgeBevel("Edge", CF(), -0.94, -1.08, 1.78, 2.72, 0.11, shade(iron, 1.15), M.CorrodedMetal)
	elseif kind == "chainflail" then
		grip.Size = V(0.3, 1.2, 0.3)
		grip.Color = wood
		grip.Material = M.Wood
		K.box("Cap", V(0.36, 0.16, 0.36), CF(0, 0.66, 0), dark, M.Metal)
		for i = 1, 5 do
			K.box("Chain", V(0.14, 0.42, 0.06), CF(0, 0.66 + i * 0.44, 0) * ANG(0, (i % 2) * PI / 2, 0), iron, M.Metal)
		end
		K.box("Ball", V(1.1, 1.1, 1.1), CF(0, 3.5, 0), dark, M.Metal)
		K.box("Ball", V(1.0, 1.0, 1.0), CF(0, 3.5, 0) * ANG(PI / 4, PI / 4, 0), shade(dark, 1.15), M.Metal)
	elseif kind == "scepter" then
		grip.Size = V(0.2, 0.8, 0.2)
		grip.Color = Palette.metal.gold
		grip.Material = M.Metal
		K.box("Shaft", V(0.18, 1.8, 0.18), CF(0, 0.2, 0), Palette.metal.gold, M.Metal)
		K.box("Collar", V(0.3, 0.14, 0.3), CF(0, 1.1, 0), shade(Palette.metal.gold, 0.8), M.Metal)
		for i = 0, 3 do
			K.box("Prong", V(0.08, 0.5, 0.08), CF(0, 1.35, 0) * ANG(0, i * PI / 2, 0) * CF(0, 0, 0.18) * ANG(-0.4, 0, 0), Palette.metal.gold, M.Metal)
		end
		K.box("Top", V(0.4, 0.4, 0.4), CF(0, 1.55, 0) * ANG(PI / 4, 0, PI / 4), rgb(220, 30, 60), M.Neon)
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= grip then
			local w = Instance.new("WeldConstraint")
			w.Part0 = grip
			w.Part1 = p
			w.Parent = p
		end
	end
	return model
end

return Weapons
