--!nonstrict
-- ARMOR & TRINKETS. Nine equipment slots (plus the weapon), seeded loot rolls
-- with rarities and affixes, upgrade levels, and cubic visuals that are welded
-- onto any R6 rig - players, NPCs, the inventory preview.
--
-- Item shape (JSON-safe, saved in the DataStore):
--   { id, cat = "gear", slot, base, name, rarity, level, up = 0,
--     stats = { armor, hp, dmg, crit, ... }, colors = { main, second, trim, accent } }
local Palette = require(script.Parent.Palette)
local Util = require(script.Parent.Util)
local Weapons = require(script.Parent.Weapons)

local Gear = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local HEAD = 1.25
local M = Enum.Material

Gear.SLOTS = { "Head", "Chest", "Hands", "Legs", "Feet", "Cloak", "Offhand", "Amulet", "Ring" }
Gear.SLOT_INFO = {
	Head = { label = "HEAD", short = "HEAD", armor = 0.7 },
	Chest = { label = "CHEST", short = "BODY", armor = 1.4 },
	Hands = { label = "HANDS", short = "HAND", armor = 0.45 },
	Legs = { label = "LEGS", short = "LEGS", armor = 0.9 },
	Feet = { label = "FEET", short = "FEET", armor = 0.5 },
	Cloak = { label = "CLOAK", short = "CLOAK", armor = 0.35 },
	Offhand = { label = "SHIELD", short = "SHLD", armor = 0.8 },
	Amulet = { label = "AMULET", short = "AMUL", armor = 0 },
	Ring = { label = "RING", short = "RING", armor = 0 },
}
Gear.RARITIES = Weapons.RARITIES
local RMULT = { Common = 1.0, Uncommon = 1.18, Rare = 1.38, Epic = 1.62, Legendary = 1.95, Divine = 2.4 }
local RAFFIX = { Common = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 3, Divine = 4 }
Gear.MAX_UP = 10

-- ------------------------------------------------------------------ stats
-- key = { label, format, roll(rng, level, rarityIndex) }
Gear.STATS = {
	armor = { "Armor", "%d" },
	hp = { "Health", "+%d" },
	dmg = { "Damage", "+%d%%", pct = true },
	crit = { "Crit chance", "+%d%%", pct = true },
	critDmg = { "Crit damage", "+%d%%", pct = true },
	speed = { "Move speed", "+%d%%", pct = true },
	lifesteal = { "Lifesteal", "+%.1f%%", pct = true },
	tsDur = { "Time stop", "+%.2fs" },
	tsCd = { "Time stop cooldown", "-%d%%", pct = true },
	block = { "Block", "+%d%%", pct = true },
	regen = { "Regeneration", "+%.1f/s" },
	xp = { "XP gain", "+%d%%", pct = true },
	gold = { "Gold find", "+%d%%", pct = true },
	flask = { "Flask charges", "+%d" },
}
Gear.STAT_ORDER = { "armor", "hp", "dmg", "crit", "critDmg", "speed", "lifesteal", "tsDur", "tsCd", "block", "regen", "xp", "gold", "flask" }

local AFFIX = {
	hp = function(rng, L, r)
		return math.floor((4 + L * 1.6) * rng:float(0.8, 1.2) * (1 + r * 0.12))
	end,
	dmg = function(rng, L, r)
		return rng:float(0.03, 0.06) * (1 + r * 0.14)
	end,
	crit = function(rng, L, r)
		return rng:float(0.02, 0.045) * (1 + r * 0.12)
	end,
	critDmg = function(rng, L, r)
		return rng:float(0.08, 0.18) * (1 + r * 0.14)
	end,
	speed = function(rng, L, r)
		return rng:float(0.02, 0.045) * (1 + r * 0.1)
	end,
	lifesteal = function(rng, L, r)
		return rng:float(0.008, 0.02) * (1 + r * 0.12)
	end,
	tsDur = function(rng, L, r)
		return rng:float(0.1, 0.25) * (1 + r * 0.15)
	end,
	tsCd = function(rng, L, r)
		return rng:float(0.025, 0.05) * (1 + r * 0.12)
	end,
	regen = function(rng, L, r)
		return (0.3 + L * 0.04) * rng:float(0.8, 1.2) * (1 + r * 0.1)
	end,
	xp = function(rng, L, r)
		return rng:float(0.04, 0.09) * (1 + r * 0.1)
	end,
	gold = function(rng, L, r)
		return rng:float(0.06, 0.14) * (1 + r * 0.1)
	end,
	armor = function(rng, L, r)
		return math.floor((2 + L * 0.8) * rng:float(0.8, 1.2) * (1 + r * 0.12))
	end,
}
local AFFIX_POOL = {
	Head = { "hp", "crit", "tsDur", "xp", "armor", "regen" },
	Chest = { "hp", "armor", "regen", "dmg", "lifesteal" },
	Hands = { "dmg", "crit", "critDmg", "lifesteal" },
	Legs = { "hp", "armor", "speed", "regen" },
	Feet = { "speed", "armor", "hp", "tsCd" },
	Cloak = { "speed", "tsDur", "tsCd", "crit", "gold" },
	Offhand = { "armor", "hp", "regen", "dmg" },
	Amulet = { "dmg", "crit", "critDmg", "tsDur", "tsCd", "lifesteal", "hp", "xp" },
	Ring = { "dmg", "crit", "critDmg", "lifesteal", "tsCd", "gold", "xp", "speed" },
}

-- ------------------------------------------------------------------ bases
-- mats: which colour family the piece is made from
local MATS = {
	cloth = { main = { rgb(120, 96, 70), rgb(96, 84, 70), rgb(140, 120, 90), rgb(90, 70, 60), rgb(70, 80, 90), rgb(110, 60, 50), rgb(60, 70, 50) }, mat = M.Fabric },
	padded = { main = { rgb(214, 200, 170), rgb(190, 176, 146), rgb(170, 150, 120), rgb(150, 130, 110) }, mat = M.Fabric },
	leather = { main = { rgb(110, 72, 44), rgb(90, 58, 36), rgb(130, 90, 56), rgb(70, 48, 32) }, mat = M.Leather },
	mail = { main = { rgb(150, 154, 162), rgb(128, 132, 140), rgb(170, 172, 178) }, mat = M.DiamondPlate },
	iron = { main = { rgb(150, 154, 162), rgb(128, 132, 140), rgb(116, 118, 124) }, mat = M.Metal },
	steel = { main = { rgb(196, 200, 210), rgb(180, 186, 196), rgb(210, 214, 222) }, mat = M.Metal },
	fur = { main = { rgb(120, 96, 72), rgb(150, 140, 130), rgb(92, 80, 70), rgb(220, 218, 210) }, mat = M.Fabric },
	gold = { main = { Palette.metal.gold, Palette.metal.bronze }, mat = M.Metal },
	wood = { main = { rgb(130, 90, 56), rgb(110, 76, 46), rgb(150, 110, 70) }, mat = M.WoodPlanks },
	bone = { main = { rgb(230, 222, 200), rgb(210, 200, 176) }, mat = M.Marble },
}
local PAINT = { rgb(170, 30, 36), rgb(40, 70, 140), rgb(40, 110, 60), rgb(220, 190, 70), rgb(236, 232, 220), rgb(30, 30, 34), rgb(120, 40, 120), rgb(200, 110, 40) }
local SCOUT_GREEN = rgb(56, 86, 58)

Gear.BASES = {}
local function base(id, slot, name, style, minL, opts)
	opts = opts or {}
	local b = { id = id, slot = slot, name = name, style = style, minL = minL, mats = opts.mats or "cloth", armor = opts.armor or 1, hp = opts.hp or 0, implicit = opts.implicit, second = opts.second, hideHair = opts.hideHair }
	Gear.BASES[id] = b
	return b
end
-- head
base("LeatherCap", "Head", "Leather Cap", "cap", 1, { mats = "leather", armor = 0.7, hideHair = true })
base("TravelHood", "Head", "Wanderer's Hood", "hood", 1, { mats = "cloth", armor = 0.5, implicit = { speed = 0.02 }, hideHair = true })
base("NasalHelm", "Head", "Nasal Helm", "nasal", 3, { mats = "iron", armor = 1.0, hideHair = true })
base("WolfPelt", "Head", "Wolf-Pelt Hood", "wolf", 7, { mats = "fur", armor = 0.8, implicit = { crit = 0.02 }, hideHair = true })
base("Spangenhelm", "Head", "Spangenhelm", "spangen", 10, { mats = "steel", armor = 1.2, hideHair = true })
base("Circlet", "Head", "Rune Circlet", "circlet", 12, { mats = "gold", armor = 0.35, implicit = { tsDur = 0.15 } })
base("HornedHelm", "Head", "Horned Helm", "horned", 16, { mats = "iron", armor = 1.15, hp = 0.25, hideHair = true })
base("GreatHelm", "Head", "Great Helm", "greathelm", 24, { mats = "steel", armor = 1.5, hideHair = true })
base("ChainCoif", "Head", "Chainmail Coif", "coif", 4, { mats = "mail", armor = 0.9, hideHair = true })
base("PlagueMask", "Head", "Plague Doctor's Mask", "plague", 9, { mats = "leather", armor = 0.65, implicit = { regen = 0.4 }, second = "leather", hideHair = true })
base("Bascinet", "Head", "Bascinet", "bascinet", 14, { mats = "steel", armor = 1.35, second = "mail", hideHair = true })
base("CrownOfThorns", "Head", "Crown of Thorns", "thorns", 15, { mats = "wood", armor = 0.3, implicit = { dmg = 0.05 } })
base("Sallet", "Head", "Sallet", "sallet", 18, { mats = "steel", armor = 1.3, implicit = { crit = 0.015 }, hideHair = true })
base("Barbute", "Head", "Barbute", "barbute", 20, { mats = "steel", armor = 1.4, hp = 0.2, hideHair = true })
-- chest
base("Tunic", "Chest", "Linen Tunic", "tunic", 1, { mats = "cloth", armor = 0.45, hp = 0.6 })
base("Gambeson", "Chest", "Gambeson", "gambeson", 3, { mats = "padded", armor = 0.75, hp = 0.9 })
base("Jerkin", "Chest", "Leather Jerkin", "jerkin", 6, { mats = "leather", armor = 0.9, implicit = { speed = 0.02 } })
base("ScoutJacket", "Chest", "Scout Jacket", "scoutjacket", 8, { mats = "leather", armor = 0.8, implicit = { speed = 0.04 } })
base("Hauberk", "Chest", "Mail Hauberk", "hauberk", 10, { mats = "mail", armor = 1.2, hp = 0.8, second = "cloth" })
base("FurMantle", "Chest", "Fur Mantle", "furmantle", 12, { mats = "leather", armor = 1.0, hp = 1.1, second = "fur" })
base("Robe", "Chest", "Runecloth Robe", "robe", 14, { mats = "cloth", armor = 0.5, implicit = { tsCd = 0.04 } })
base("Lamellar", "Chest", "Lamellar Armor", "lamellar", 18, { mats = "iron", armor = 1.35, hp = 0.6, second = "leather" })
base("Cuirass", "Chest", "Plate Cuirass", "cuirass", 26, { mats = "steel", armor = 1.6, hp = 0.5 })
base("Surcoat", "Chest", "Crusader's Surcoat", "surcoat", 7, { mats = "cloth", armor = 1.05, hp = 0.6 })
base("Brigandine", "Chest", "Brigandine", "brigandine", 11, { mats = "iron", armor = 1.25, hp = 0.5, second = "padded" })
base("BoneHarness", "Chest", "Bone Harness", "bonemail", 13, { mats = "leather", armor = 1.0, implicit = { lifesteal = 0.01 } })
base("ScaleMail", "Chest", "Scale Mail", "scale", 15, { mats = "iron", armor = 1.3, hp = 0.5, second = "leather" })
base("GothicPlate", "Chest", "Gothic Plate", "gothic", 32, { mats = "steel", armor = 1.75, hp = 0.6 })
-- hands
base("Gloves", "Hands", "Leather Gloves", "gloves", 1, { mats = "leather", armor = 0.7 })
base("Bracers", "Hands", "Bracers", "bracers", 5, { mats = "leather", armor = 0.8, implicit = { crit = 0.015 } })
base("MailMitts", "Hands", "Mail Mittens", "mitts", 12, { mats = "mail", armor = 1.1 })
base("Gauntlets", "Hands", "Plate Gauntlets", "gauntlets", 22, { mats = "steel", armor = 1.4, implicit = { dmg = 0.02 } })
base("HandWraps", "Hands", "Hand Wraps", "handwraps", 1, { mats = "padded", armor = 0.5, implicit = { crit = 0.01 } })
base("ClawGauntlets", "Hands", "Clawed Gauntlets", "claws", 17, { mats = "steel", armor = 1.2, implicit = { critDmg = 0.12 } })
-- legs
base("Trousers", "Legs", "Wool Trousers", "trousers", 1, { mats = "cloth", armor = 0.5, hp = 0.4 })
base("LegWraps", "Legs", "Leg Wraps", "wraps", 4, { mats = "cloth", armor = 0.7, implicit = { speed = 0.02 }, second = "leather" })
base("Chausses", "Legs", "Mail Chausses", "chausses", 12, { mats = "mail", armor = 1.15, hp = 0.4 })
base("Greaves", "Legs", "Plate Greaves", "greaves", 22, { mats = "steel", armor = 1.45 })
base("Breeches", "Legs", "Leather Breeches", "breeches", 3, { mats = "leather", armor = 0.75, implicit = { speed = 0.015 }, second = "cloth" })
base("Tassets", "Legs", "Plate Tassets", "tassets", 17, { mats = "steel", armor = 1.3, second = "leather" })
-- feet
base("Boots", "Feet", "Leather Boots", "boots", 1, { mats = "leather", armor = 0.8 })
base("FurBoots", "Feet", "Fur Boots", "furboots", 6, { mats = "leather", armor = 0.9, hp = 0.3, second = "fur" })
base("RidingBoots", "Feet", "Riding Boots", "ridingboots", 10, { mats = "leather", armor = 0.9, implicit = { speed = 0.04 } })
base("Sabatons", "Feet", "Iron Sabatons", "sabatons", 20, { mats = "steel", armor = 1.4 })
base("FootWraps", "Feet", "Ashen Foot-Wraps", "footwraps", 1, { mats = "padded", armor = 0.55, implicit = { speed = 0.03 } })
base("Sollerets", "Feet", "Gothic Sollerets", "sollerets", 28, { mats = "steel", armor = 1.55 })
-- cloak
base("TravelCloak", "Cloak", "Traveler's Cloak", "cloak", 1, { mats = "cloth", armor = 0.6 })
base("FurCloak", "Cloak", "Fur Cloak", "furcloak", 8, { mats = "fur", armor = 0.9, hp = 0.4 })
base("ScoutCloak", "Cloak", "Scout Cloak", "scoutcloak", 10, { mats = "cloth", armor = 0.7, implicit = { speed = 0.04 } })
base("RoyalMantle", "Cloak", "Royal Mantle", "royalcloak", 20, { mats = "cloth", armor = 0.8, implicit = { gold = 0.1 }, second = "fur" })
base("ShadowCloak", "Cloak", "Shadow Cloak", "shadowcloak", 30, { mats = "cloth", armor = 0.8, implicit = { tsDur = 0.3 } })
base("PilgrimMantle", "Cloak", "Pilgrim's Mantle", "pilgrim", 4, { mats = "cloth", armor = 0.6, implicit = { regen = 0.3 } })
base("Shroud", "Cloak", "Tattered Shroud", "shroud", 16, { mats = "cloth", armor = 0.7, implicit = { tsCd = 0.04 } })
-- offhand
base("Buckler", "Offhand", "Buckler", "buckler", 1, { mats = "iron", armor = 0.6, implicit = { block = 0.12 } })
base("RoundShield", "Offhand", "Round Shield", "round", 3, { mats = "wood", armor = 1.0, implicit = { block = 0.2 } })
base("KiteShield", "Offhand", "Kite Shield", "kite", 14, { mats = "steel", armor = 1.3, implicit = { block = 0.26 } })
base("TowerShield", "Offhand", "Tower Shield", "tower", 26, { mats = "iron", armor = 1.7, implicit = { block = 0.34, speed = -0.04 } })
base("SpikedBuckler", "Offhand", "Spiked Buckler", "spiked", 7, { mats = "iron", armor = 0.7, implicit = { block = 0.14, dmg = 0.02 } })
base("HeaterShield", "Offhand", "Heater Shield", "heater", 9, { mats = "wood", armor = 1.15, implicit = { block = 0.24 } })
base("Pavise", "Offhand", "Pavise", "pavise", 20, { mats = "wood", armor = 1.55, implicit = { block = 0.3, speed = -0.03 } })
-- amulets
base("BoneCharm", "Amulet", "Bone Charm", "charm", 1, { mats = "bone", armor = 0, implicit = { hp = 12 } })
base("RuneStone", "Amulet", "Rune Stone", "runestone", 8, { mats = "iron", armor = 0, implicit = { dmg = 0.04 } })
base("Hourglass", "Amulet", "Hourglass Pendant", "hourglass", 16, { mats = "gold", armor = 0, implicit = { tsDur = 0.35 } })
base("CrimsonHeart", "Amulet", "Crimson Heart", "heart", 24, { mats = "gold", armor = 0, implicit = { lifesteal = 0.02 } })
base("Rosary", "Amulet", "Pilgrim's Rosary", "rosary", 3, { mats = "wood", armor = 0, implicit = { regen = 0.4 } })
base("WolfTooth", "Amulet", "Wolf-Tooth Necklace", "teeth", 6, { mats = "bone", armor = 0, implicit = { crit = 0.02 } })
base("AbyssEye", "Amulet", "Eye of the Abyss", "eye", 26, { mats = "iron", armor = 0, implicit = { critDmg = 0.2, tsDur = 0.2 } })
-- rings
base("IronBand", "Ring", "Iron Band", "ring", 1, { mats = "iron", armor = 0, implicit = { armor = 4 } })
base("SilverRing", "Ring", "Silver Ring", "gemring", 6, { mats = "steel", armor = 0, implicit = { crit = 0.02 } })
base("Signet", "Ring", "Signet Ring", "signet", 14, { mats = "gold", armor = 0, implicit = { gold = 0.12 } })
base("ChronoRing", "Ring", "Chrono Ring", "chronoring", 20, { mats = "gold", armor = 0, implicit = { tsCd = 0.06 } })
base("BloodRing", "Ring", "Blood Ring", "bloodring", 28, { mats = "gold", armor = 0, implicit = { lifesteal = 0.015 } })
base("EmberRing", "Ring", "Ring of Embers", "emberring", 12, { mats = "iron", armor = 0, implicit = { dmg = 0.04 } })
base("SerpentRing", "Ring", "Serpent Ring", "serpent", 18, { mats = "steel", armor = 0, implicit = { lifesteal = 0.01, speed = 0.02 } })

local BASE_LIST = {}
for id, b in Gear.BASES do
	table.insert(BASE_LIST, b)
end
table.sort(BASE_LIST, function(a, b)
	return a.id < b.id
end)

-- ------------------------------------------------------------------ names
local PREFIX = {
	Common = { "Worn", "Patched", "Plain", "Frayed", "Old", "Simple" },
	Uncommon = { "Sturdy", "Soldier's", "Hunter's", "Reinforced", "Farmer's", "Sailor's" },
	Rare = { "Northman's", "Kingsguard", "Raider's", "Wolf-Lord's", "Wallwarden's", "Scout's" },
	Epic = { "Jarl's", "Stormborn", "Oathsworn", "Bloodied", "Ashen", "Frostbitten" },
	Legendary = { "Titan-Hide", "Warlord's", "Everlasting", "Valkyrie's", "Kingslayer's", "Dragonscale" },
	Divine = { "Unwritten", "Godforged", "Timeless", "Heaven-Sewn" },
}
local SUFFIX = {
	hp = "of the Bear", armor = "of the Fortress", dmg = "of Fury", crit = "of the Hawk", critDmg = "of Ruin",
	speed = "of the Hare", lifesteal = "of Leeching", tsDur = "of Stillness", tsCd = "of the Second Hand",
	regen = "of the Troll", xp = "of the Sage", gold = "of Greed", block = "of the Wall",
}

-- ------------------------------------------------------------------ ids
local counter = 0
local function newId(rng)
	counter += 1
	return string.format("g%x%x%x", rng:int(0, 0xFFFFFF), counter, math.floor(os.clock() * 1000) % 0xFFFF)
end

local function pickRarity(rng, level: number, minRarity: string?)
	local entries = {}
	local minIdx = table.find(Gear.RARITIES, minRarity or "Common") or 1
	for i, r in Gear.RARITIES do
		if i >= minIdx then
			local w = Weapons.RARITY[r].weight * (1 + math.max(0, level - 1) * 0.02 * (i - 1))
			table.insert(entries, { r, w })
		end
	end
	return rng:weighted(entries)
end

-- Bases a piece of this level can roll (newer bases unlock as you go deeper).
local function eligible(slot: string?, level: number)
	local out = {}
	for _, b in BASE_LIST do
		if (not slot or b.slot == slot) and b.minL <= level + 2 then
			table.insert(out, b)
		end
	end
	return out
end

local function colorsFor(rng, b, rarity: string)
	local fam = MATS[b.mats] or MATS.cloth
	local main = rng:pick(fam.main)
	local second = if b.second then rng:pick((MATS[b.second] or MATS.cloth).main) else Palette.shade(main, 0.75)
	local trim = rng:pick({ rgb(70, 48, 32), Palette.metal.iron, Palette.metal.bronze, rgb(40, 34, 30) })
	local accent = rng:pick(PAINT)
	if rarity == "Epic" then
		trim = rng:pick({ Palette.metal.silver, Palette.metal.bronze, rgb(170, 120, 255) })
	elseif rarity == "Legendary" then
		trim = Palette.metal.gold
	elseif rarity == "Divine" then
		trim = Palette.metal.gold
		if b.mats == "steel" or b.mats == "iron" or b.mats == "mail" then
			main = rgb(236, 236, 244)
		elseif b.mats == "cloth" then
			main = rgb(244, 240, 228)
		end
		accent = rgb(255, 236, 160)
	end
	if b.style == "scoutcloak" then
		main = if rarity == "Divine" then main else SCOUT_GREEN
	end
	return { main = Util.arr(main), second = Util.arr(second), trim = Util.arr(trim), accent = Util.arr(accent) }
end

-- Rolls a gear piece. opts: {slot, base, rarity, minRarity, name, unique, desc}
function Gear.roll(rng, level: number, opts)
	opts = opts or {}
	level = math.max(1, math.floor(level))
	local b = opts.base and Gear.BASES[opts.base]
	if not b then
		local list = eligible(opts.slot, level)
		if #list == 0 then
			list = eligible(opts.slot, 999)
		end
		-- prefer bases close to the current level
		local entries = {}
		for _, x in list do
			table.insert(entries, { x, 1 + math.max(0, 12 - math.abs(level - x.minL - 4)) * 0.3 })
		end
		b = rng:weighted(entries)
	end
	local rarity = opts.rarity or pickRarity(rng, level, opts.minRarity)
	local rIdx = table.find(Gear.RARITIES, rarity) or 1
	local mult = RMULT[rarity] or 1
	local info = Gear.SLOT_INFO[b.slot]
	local stats = {}
	if info.armor > 0 and b.armor > 0 then
		stats.armor = math.floor(info.armor * b.armor * (3 + level * 1.25) * mult * rng:float(0.92, 1.08) + 0.5)
	end
	if b.hp > 0 then
		stats.hp = math.floor(b.hp * (5 + level * 2.6) * mult * rng:float(0.9, 1.1) + 0.5)
	end
	for k, v in b.implicit or {} do
		local scale = if k == "hp" or k == "armor" then (1 + level * 0.12) * mult else (0.85 + mult * 0.15)
		stats[k] = (stats[k] or 0) + v * scale
	end
	local pool = rng:shuffle(table.clone(AFFIX_POOL[b.slot] or AFFIX_POOL.Ring))
	local main = nil
	for i = 1, RAFFIX[rarity] or 0 do
		local k = pool[i]
		if k then
			stats[k] = (stats[k] or 0) + AFFIX[k](rng, level, rIdx)
			main = main or k
		end
	end
	local item = {
		id = newId(rng),
		cat = "gear",
		slot = b.slot,
		base = b.id,
		rarity = rarity,
		level = level,
		up = 0,
		stats = stats,
		colors = colorsFor(rng, b, rarity),
	}
	local name = b.name
	if rarity ~= "Common" or rng:chance(0.4) then
		name = rng:pick(PREFIX[rarity]) .. " " .. name
	end
	if main and SUFFIX[main] and rIdx >= 3 then
		name ..= " " .. SUFFIX[main]
	end
	item.name = opts.name or name
	item.unique = opts.unique
	item.desc = opts.desc
	return item
end

-- Story gear.
function Gear.unique(id: string, level: number)
	local rng = (require(script.Parent.RNG)).new(#id * 104729 + level)
	if id == "PitRags" then
		return Gear.roll(rng, level, { base = "Tunic", rarity = "Uncommon", name = "Rags of the Forgotten Pit", unique = id, desc = "Someone died in these. Now someone lives in them." })
	elseif id == "TitanHide" then
		local it = Gear.roll(rng, level, { base = "FurMantle", rarity = "Legendary", name = "Titan-Hide Mantle", unique = id, desc = "Still warm. Still steaming." })
		it.stats.hp = (it.stats.hp or 0) + 40 + level * 3
		return it
	elseif id == "WallwardenHelm" then
		return Gear.roll(rng, level, { base = "Spangenhelm", rarity = "Epic", name = "Wallwarden's Helm", unique = id, desc = "Worn by the guards who watched the Great Wall. They didn't see you coming either." })
	elseif id == "HollowHood" then
		local it = Gear.roll(rng, level, { base = "TravelHood", rarity = "Divine", name = "Hood of the Hollow", unique = id, desc = "Colours flipped. Still fits." })
		it.colors.main = Util.arr(rgb(10, 10, 14))
		it.colors.accent = Util.arr(rgb(255, 20, 30))
		it.stats.tsDur = (it.stats.tsDur or 0) + 0.6
		return it
	elseif id == "KingsSignet" then
		return Gear.roll(rng, level, { base = "Signet", rarity = "Legendary", name = "Signet of the Spared King", unique = id, desc = "Mercy, cast in gold." })
	end
	return Gear.roll(rng, level)
end

-- ------------------------------------------------------------------ numbers
-- Effective stats including upgrade levels.
function Gear.stats(item)
	local out = {}
	local k = 1 + 0.08 * (item.up or 0)
	for key, v in item.stats or {} do
		if key == "flask" then
			out[key] = v
		elseif key == "speed" and v < 0 then
			out[key] = v
		else
			out[key] = v * k
		end
	end
	return out
end

function Gear.fmt(key: string, v: number): string
	local def = Gear.STATS[key]
	if not def then
		return key .. " " .. tostring(v)
	end
	if def.pct then
		if key == "lifesteal" then
			return string.format(def[2], v * 100)
		end
		return string.format(def[2], math.floor(math.abs(v) * 100 + 0.5))
	elseif key == "armor" or key == "hp" or key == "flask" then
		return string.format(def[2], math.floor(v + 0.5))
	end
	return string.format(def[2], v)
end

function Gear.describe(item): { string }
	local b = Gear.BASES[item.base]
	local lines = {
		string.format("%s %s  ·  Lv %d%s", item.rarity, if b then Gear.SLOT_INFO[b.slot].label:lower():gsub("^%l", string.upper) else "Gear", item.level, if (item.up or 0) > 0 then "  ·  +" .. item.up else ""),
	}
	local s = Gear.stats(item)
	for _, key in Gear.STAT_ORDER do
		if s[key] and math.abs(s[key]) > 0.0001 then
			local def = Gear.STATS[key]
			table.insert(lines, def[1] .. "  " .. Gear.fmt(key, s[key]))
		end
	end
	if item.desc then
		table.insert(lines, "\"" .. item.desc .. "\"")
	end
	return lines
end

-- One number for "is this better?" comparisons.
local SCORE_W = { armor = 1, hp = 0.6, dmg = 300, crit = 260, critDmg = 110, speed = 280, lifesteal = 900, tsDur = 60, tsCd = 320, block = 120, regen = 12, xp = 80, gold = 60, flask = 40 }
function Gear.score(item): number
	local s = Gear.stats(item)
	local total = 0
	for k, v in s do
		total += v * (SCORE_W[k] or 10)
	end
	return total
end

function Gear.upgradeCost(item)
	local up = item.up or 0
	local r = table.find(Gear.RARITIES, item.rarity) or 1
	return math.floor((30 + item.level * 9) * (up + 1) ^ 1.35 * (0.8 + r * 0.2)), 1 + up + math.floor(r / 2)
end

function Gear.salvageValue(item)
	local r = table.find(Gear.RARITIES, item.rarity) or 1
	return math.floor((4 + item.level * 1.5) * r * r), r + math.floor((item.up or 0) / 2)
end

function Gear.isGear(item): boolean
	return type(item) == "table" and item.cat == "gear"
end

-- ------------------------------------------------------------------ visuals
local function c3(a, fallback: Color3): Color3
	if typeof(a) == "Color3" then
		return a
	end
	if type(a) == "table" then
		return Util.c3(a)
	end
	return fallback
end

-- Resolves an item, a base id string, or nil into {item, base, colors}.
local function resolve(x, rarityHint: string?)
	if type(x) == "string" then
		local b = Gear.BASES[x]
		if not b then
			return nil
		end
		local rng = (require(script.Parent.RNG)).new(#x * 31 + string.byte(x, 1))
		local cols = colorsFor(rng, b, rarityHint or "Common")
		return { item = { base = x, rarity = rarityHint or "Common", slot = b.slot }, base = b, colors = cols }
	elseif type(x) == "table" and x.base then
		local b = Gear.BASES[x.base]
		if not b then
			return nil
		end
		return { item = x, base = b, colors = x.colors or {} }
	end
	return nil
end

-- Adds one welded, massless deco part. `s` is the rig's scale.
local function makeAdder(folder: Instance, s: number, slot: string)
	return function(parent: BasePart, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?, props)
		-- never let a shell face sit (almost) on the face of the limb it covers:
		-- such faces z-fight in game. Push them out to a clear 0.03 gap.
		if not (props and (props.wedge or props.Shape)) then
			local _, _, _, r00, _, _, _, r11, _, _, _, r22 = offset:GetComponents()
			if math.abs(r00) > 0.999 and math.abs(r11) > 0.999 and math.abs(r22) > 0.999 then
				local L = parent.Size / s
				local P = { offset.X, offset.Y, offset.Z }
				local G = { size.X / 2, size.Y / 2, size.Z / 2 }
				local H = { L.X / 2, L.Y / 2, L.Z / 2 }
				local moved = false
				for a = 1, 3 do
					local covers = true
					for b = 1, 3 do
						if b ~= a and (P[b] + G[b] < -H[b] + 0.01 or P[b] - G[b] > H[b] - 0.01) then
							covers = false
						end
					end
					if covers then
						for _, sgn in { 1, -1 } do
							local gf = P[a] + sgn * G[a]
							if math.abs(gf - sgn * H[a]) < 0.03 then
								local delta = (sgn * H[a] + sgn * 0.03) - gf
								P[a] += delta / 2
								G[a] += sgn * delta / 2
								moved = true
							end
						end
					end
				end
				if moved then
					size = V(G[1] * 2, G[2] * 2, G[3] * 2)
					offset = CF(P[1], P[2], P[3]) * (offset - offset.Position)
				end
			end
		end
		local p = Instance.new(if props and props.wedge then "WedgePart" else "Part")
		p.Name = "Gear_" .. slot
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size * s
		p.CFrame = parent.CFrame * (offset - offset.Position) + parent.CFrame:VectorToWorldSpace(offset.Position * s)
		p.Color = color
		p.Material = mat or M.SmoothPlastic
		p.CastShadow = size.X + size.Y + size.Z > 1.2
		if props then
			for k, v in props do
				if k ~= "wedge" then
					(p :: any)[k] = v
				end
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = parent
		w.Part1 = p
		w.Parent = p
		p.Parent = folder
		return p
	end
end

local STYLE = {}
local PI = math.pi
local WEDGE = { wedge = true }
local CYL = { Shape = Enum.PartType.Cylinder }
local BALL = { Shape = Enum.PartType.Ball }
local DARK = rgb(14, 12, 14)
local BONE = rgb(226, 218, 196)
local sh = Palette.shade

-- Triangle plate in the frame's XY plane: base on y = 0 from x0..x1, apex at (xa, h), thickness t.
local function tri(add, part, frame: CFrame, x0: number, x1: number, xa: number, h: number, t: number, col, mat)
	if h < 0 then
		frame = frame * ANG(0, 0, PI)
		x0, x1, xa, h = -x1, -x0, -xa, -h
	end
	if x0 > x1 then
		x0, x1 = x1, x0
	end
	xa = math.clamp(xa, x0, x1)
	if xa - x0 > 0.005 then
		add(part, V(t, h, xa - x0), frame * CF(xa - (xa - x0) / 2, h / 2, 0) * ANG(0, PI / 2, 0), col, mat, WEDGE)
	end
	if x1 - xa > 0.005 then
		add(part, V(t, h, x1 - xa), frame * CF(xa + (x1 - xa) / 2, h / 2, 0) * ANG(0, -PI / 2, 0), col, mat, WEDGE)
	end
end

local function rivets(add, part, p0: Vector3, p1: Vector3, n: number, size: number, col)
	for i = 0, n - 1 do
		local p = if n == 1 then p0:Lerp(p1, 0.5) else p0:Lerp(p1, i / (n - 1))
		add(part, V(size, size, size), CF(p), col, M.Metal)
	end
end

-- a glowing rune for epic+ pieces
local function rune(add, part, cf: CFrame, c, rare: number, size: number?)
	if rare < 4 then
		return
	end
	local s = size or 0.2
	add(part, V(s * 0.3, s, 0.03), cf, c.accent, M.Neon)
	add(part, V(s, s * 0.3, 0.03), cf * CF(0, s * 0.15, 0), c.accent, M.Neon)
end

-- head ---------------------------------------------------------------
local h = HEAD / 2

function STYLE.cap(P, add, c, rare)
	add(P.head, V(1.34, 0.42, 1.36), CF(0, h + 0.02, 0.02), c.main, c.mat)
	add(P.head, V(1.06, 0.14, 1.08), CF(0, h + 0.28, 0.03), sh(c.main, 1.07), c.mat)
	add(P.head, V(1.4, 0.14, 1.42), CF(0, h - 0.16, 0.02), c.second, c.mat)
	add(P.head, V(0.05, 0.1, 1.12), CF(0, h + 0.36, 0.03), sh(c.main, 0.7), c.mat)
	add(P.head, V(1.1, 0.1, 0.05), CF(0, h + 0.36, 0.03), sh(c.main, 0.7), c.mat)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.1, 0.52, 0.56), CF(sx * (h + 0.07), -0.02, 0.06), c.main, c.mat)
		add(P.head, V(0.06, 0.3, 0.06), CF(sx * (h + 0.08), -0.42, -0.1), c.second, c.mat)
	end
	add(P.head, V(0.9, 0.08, 0.32), CF(0, h - 0.2, -h - 0.12) * ANG(0.15, 0, 0), c.second, c.mat)
	if rare >= 3 then
		add(P.head, V(0.2, 0.2, 0.05), CF(0, h + 0.02, -h - 0.06) * ANG(0, 0, PI / 4), c.trim, M.Metal)
	end
end

function STYLE.hood(P, add, c, rare)
	local dark = sh(c.main, 0.8)
	add(P.head, V(1.52, 0.3, 1.54), CF(0, h + 0.1, 0.03), c.main, c.mat)
	-- the peak falling back
	add(P.head, V(0.9, 0.34, 0.6), CF(0, h + 0.22, 0.42) * ANG(-0.5, 0, 0), sh(c.main, 0.95), c.mat)
	add(P.head, V(0.5, 0.3, 0.4), CF(0, h + 0.16, 0.86) * ANG(-0.9, 0, 0), dark, c.mat)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.2, 1.4, 1.44), CF(sx * (h + 0.12), -0.02, 0.05), c.main, c.mat)
		-- folds on the sides
		add(P.head, V(0.06, 1.3, 0.1), CF(sx * (h + 0.24), -0.05, -0.2), dark, c.mat)
		add(P.head, V(0.06, 1.1, 0.1), CF(sx * (h + 0.24), -0.1, 0.35), dark, c.mat)
		-- shadow inside the face opening
		add(P.head, V(0.1, 1.2, 0.06), CF(sx * (h - 0.02), -0.04, -h - 0.04), DARK, M.Fabric)
	end
	add(P.head, V(1.52, 1.5, 0.2), CF(0, -0.02, h + 0.12), c.second, c.mat)
	add(P.head, V(1.56, 0.26, 0.3), CF(0, h - 0.02, -h - 0.08), c.second, c.mat)
	add(P.head, V(1.2, 0.08, 0.06), CF(0, h - 0.17, -h - 0.02), DARK, M.Fabric)
	-- mantle over the shoulders
	add(P.torso, V(1.9, 0.38, 1.32), CF(0, 1.02, 0.05), c.main, c.mat)
	add(P.torso, V(2.2, 0.2, 1.4), CF(0, 0.84, 0.05), dark, c.mat)
	add(P.torso, V(1.0, 0.56, 0.2), CF(0, 0.66, -0.66) * ANG(0.12, 0, 0), c.second, c.mat)
	tri(add, P.torso, CF(0, 0.38, -0.7) * ANG(0.12, 0, 0), -0.5, 0.5, 0, -0.34, 0.12, c.second, c.mat)
	if rare >= 3 then
		add(P.torso, V(0.2, 0.2, 0.06), CF(0, 0.86, -0.78), c.trim, M.Metal)
	end
	rune(add, P.torso, CF(0, 0.6, -0.78), c, rare, 0.22)
end

local function brow(add, P, c, y, w)
	add(P.head, V(w, 0.14, w), CF(0, y, 0), c.trim, M.Metal)
	for i = 0, 7 do
		local a = i * PI / 4 + PI / 8
		add(P.head, V(0.07, 0.07, 0.07), CF(0, y, 0) * ANG(0, a, 0) * CF(0, 0, -w / 2 - 0.02), sh(c.trim, 1.2), M.Metal)
	end
end

local function nasalCore(P, add, c, rare)
	add(P.head, V(1.44, 0.46, 1.44), CF(0, h - 0.02, 0), c.main, c.mat)
	add(P.head, V(1.14, 0.26, 1.14), CF(0, h + 0.32, 0), c.main, c.mat)
	add(P.head, V(0.66, 0.2, 0.66), CF(0, h + 0.52, 0), sh(c.main, 1.08), c.mat)
	add(P.head, V(0.22, 0.12, 0.22), CF(0, h + 0.66, 0), c.trim, M.Metal)
	brow(add, P, c, h - 0.24, 1.5)
	add(P.head, V(0.18, 0.68, 0.1), CF(0, -0.02, -h - 0.1), c.trim, M.Metal)
	add(P.head, V(0.26, 0.12, 0.12), CF(0, -0.36, -h - 0.1), c.trim, M.Metal)
	-- riveted cross bands
	add(P.head, V(0.14, 0.64, 1.48), CF(0, h + 0.06, 0), c.trim, M.Metal)
	add(P.head, V(1.48, 0.64, 0.14), CF(0, h + 0.06, 0), c.trim, M.Metal)
	if rare >= 3 then
		add(P.head, V(0.08, 0.5, 0.06), CF(0, h + 0.1, -0.76), c.accent, if rare >= 4 then M.Neon else M.Metal)
	end
end

function STYLE.nasal(P, add, c, rare)
	nasalCore(P, add, c, rare)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.1, 0.42, 0.5), CF(sx * (h + 0.08), -0.2, 0.1), sh(c.main, 0.9), M.DiamondPlate)
	end
end

function STYLE.spangen(P, add, c, rare)
	nasalCore(P, add, c, rare)
	-- spectacle guard around the eyes
	for _, sx in { 1, -1 } do
		add(P.head, V(0.46, 0.08, 0.08), CF(sx * 0.3, 0.3, -h - 0.1), c.trim, M.Metal)
		add(P.head, V(0.46, 0.08, 0.08), CF(sx * 0.3, -0.02, -h - 0.1), c.trim, M.Metal)
		add(P.head, V(0.08, 0.36, 0.08), CF(sx * 0.53, 0.14, -h - 0.1), c.trim, M.Metal)
		add(P.head, V(0.12, 0.72, 0.62), CF(sx * (h + 0.07), -0.12, -0.28), c.main, c.mat)
		rivets(add, P.head, V(sx * (h + 0.14), 0.1, -0.5), V(sx * (h + 0.14), -0.36, -0.5), 3, 0.06, c.trim)
	end
	-- mail aventail
	add(P.head, V(1.52, 0.62, 1.0), CF(0, -0.42, 0.28), sh(c.main, 0.85), M.DiamondPlate)
	add(P.torso, V(1.72, 0.3, 1.3), CF(0, 1.05, 0.02), sh(c.main, 0.8), M.DiamondPlate)
	add(P.torso, V(1.9, 0.12, 1.34), CF(0, 0.9, 0.02), sh(c.main, 0.7), M.DiamondPlate)
end

function STYLE.horned(P, add, c, rare)
	nasalCore(P, add, c, rare)
	local bone = BONE
	for _, sx in { 1, -1 } do
		add(P.head, V(0.26, 0.3, 0.3), CF(sx * 0.74, h + 0.02, 0), c.trim, M.Metal)
		add(P.head, V(0.3, 0.34, 0.3), CF(sx * 0.86, h + 0.12, 0) * ANG(0, 0, -sx * 0.9), bone, M.Marble)
		add(P.head, V(0.25, 0.4, 0.25), CF(sx * 1.08, h + 0.36, -0.04) * ANG(-0.2, 0, -sx * 0.45), sh(bone, 0.95), M.Marble)
		add(P.head, V(0.19, 0.38, 0.19), CF(sx * 1.18, h + 0.7, -0.14) * ANG(-0.45, 0, -sx * 0.1), sh(bone, 0.9), M.Marble)
		add(P.head, V(0.12, 0.3, 0.12), CF(sx * 1.16, h + 0.98, -0.3) * ANG(-0.8, 0, sx * 0.2), sh(bone, 0.84), M.Marble)
		-- ridged bands on the horn
		add(P.head, V(0.28, 0.06, 0.28), CF(sx * 1.08, h + 0.36, -0.04) * ANG(-0.2, 0, -sx * 0.45), sh(bone, 0.75), M.Marble)
	end
	if rare >= 5 then
		add(P.head, V(0.14, 0.5, 0.9), CF(0, h + 0.62, 0.05), c.accent, M.Fabric)
	end
end

function STYLE.greathelm(P, add, c, rare)
	add(P.head, V(1.48, 1.5, 1.48), CF(0, 0.04, 0), c.main, c.mat)
	add(P.head, V(1.3, 0.16, 1.3), CF(0, h + 0.12, 0), sh(c.main, 1.06), c.mat)
	add(P.head, V(1.54, 0.12, 1.54), CF(0, h - 0.04, 0), c.trim, M.Metal)
	add(P.head, V(1.54, 0.12, 1.54), CF(0, -h + 0.04, 0), c.trim, M.Metal)
	-- the eye slits split by the cross reinforcement
	add(P.head, V(1.12, 0.12, 0.04), CF(0, 0.16, -0.75), DARK, M.Metal)
	add(P.head, V(0.18, 1.12, 0.08), CF(0, -0.06, -0.77), c.trim, M.Metal)
	add(P.head, V(1.22, 0.14, 0.08), CF(0, 0.32, -0.77), c.trim, M.Metal)
	add(P.head, V(0.4, 0.3, 0.14), CF(0, -0.2, -0.78) * ANG(0, 0, PI / 4), sh(c.main, 0.9), c.mat)
	for i = -1, 1 do
		for _, sx in { 1, -1 } do
			add(P.head, V(0.07, 0.07, 0.04), CF(sx * (0.28 + i * 0.12), -0.3 - math.abs(i) * 0.08, -0.75), DARK, M.Metal)
		end
	end
	rivets(add, P.head, V(-0.6, h - 0.04, -0.79), V(0.6, h - 0.04, -0.79), 5, 0.06, sh(c.trim, 1.2))
	-- crest
	add(P.head, V(0.18, 0.34, 1.2), CF(0, h + 0.34, 0.05), c.accent, M.Fabric)
	add(P.head, V(0.14, 0.2, 0.9), CF(0, h + 0.56, 0.12), sh(c.accent, 0.85), M.Fabric)
	if rare >= 5 then
		for _, sx in { 1, -1 } do
			tri(add, P.head, CF(sx * (h + 0.08), 0.3, 0.1) * ANG(0, PI / 2, 0), -0.4, 0.4, 0.4, 0.9, 0.06, c.trim, M.Metal)
		end
	end
	rune(add, P.head, CF(0.4, 0.55, -0.76), c, rare, 0.16)
end

function STYLE.wolf(P, add, c, rare)
	local fur = c.main
	add(P.head, V(1.52, 0.4, 1.56), CF(0, h + 0.1, 0.02), fur, M.Fabric)
	add(P.head, V(0.9, 0.36, 0.7), CF(0, h + 0.12, -0.72), sh(fur, 0.92), M.Fabric)
	add(P.head, V(0.62, 0.24, 0.4), CF(0, h + 0.06, -1.1), sh(fur, 0.86), M.Fabric)
	add(P.head, V(0.3, 0.16, 0.12), CF(0, h + 0.14, -1.32), rgb(26, 22, 22), M.Fabric)
	-- upper teeth over the brow
	for i = -2, 2 do
		tri(add, P.head, CF(i * 0.12, h - 0.1, -1.08), -0.04, 0.04, 0, -0.14, 0.04, rgb(236, 230, 212), M.Marble)
	end
	for _, sx in { 1, -1 } do
		add(P.head, V(0.14, 0.5, 0.36), CF(sx * 0.46, h + 0.5, 0.05), fur, M.Fabric, WEDGE)
		add(P.head, V(0.08, 0.3, 0.2), CF(sx * 0.46, h + 0.46, 0.0), rgb(90, 60, 56), M.Fabric, WEDGE)
		add(P.head, V(0.2, 1.2, 1.4), CF(sx * (h + 0.12), -0.1, 0.1), fur, M.Fabric)
		add(P.head, V(0.1, 0.1, 0.08), CF(sx * 0.24, h + 0.26, -0.98), if rare >= 4 then c.accent else rgb(240, 236, 220), if rare >= 4 then M.Neon else M.Fabric)
	end
	add(P.head, V(1.56, 1.2, 0.2), CF(0, -0.1, h + 0.12), sh(fur, 0.85), M.Fabric)
	add(P.torso, V(2.3, 0.5, 1.4), CF(0, 0.95, 0.05), fur, M.Fabric)
	add(P.torso, V(1.6, 1.6, 0.16), CF(0, 0.2, 0.62), sh(fur, 0.9), M.Fabric)
	-- the paws tied across the chest
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.36, 0.7, 0.18), CF(sx * 0.42, 0.55, -0.66) * ANG(0, 0, sx * 0.5), sh(fur, 0.9), M.Fabric)
	end
	add(P.torso, V(0.22, 0.22, 0.08), CF(0, 0.4, -0.76), c.trim, M.Metal)
end

function STYLE.circlet(P, add, c, rare)
	local g = c.main
	add(P.head, V(1.46, 0.1, 1.46), CF(0, h - 0.12, 0), g, M.Metal)
	add(P.head, V(1.43, 0.05, 1.48), CF(0, h - 0.04, 0), sh(g, 0.8), M.Metal)
	-- filigree points rising all round
	for i = 0, 7 do
		local a = i * PI / 4
		tri(add, P.head, CF(0, h - 0.07, 0) * ANG(0, a, 0) * CF(0, 0, -0.735), -0.08, 0.08, 0, if i % 2 == 0 then 0.24 else 0.15, 0.03, g, M.Metal)
	end
	add(P.head, V(0.26, 0.26, 0.08), CF(0, h - 0.06, -0.77) * ANG(0, 0, PI / 4), sh(g, 0.8), M.Metal)
	add(P.head, V(0.18, 0.18, 0.1), CF(0, h - 0.06, -0.78) * ANG(0, 0, PI / 4), c.accent, M.Neon)
	if rare >= 4 then
		for _, sx in { 1, -1 } do
			add(P.head, V(0.08, 0.08, 0.06), CF(sx * 0.4, h - 0.1, -0.75), c.accent, M.Neon)
		end
	end
end

function STYLE.bascinet(P, add, c, rare)
	-- pointed skull tipped back
	add(P.head, V(1.44, 0.9, 1.48), CF(0, h - 0.18, 0.02), c.main, c.mat)
	add(P.head, V(1.2, 0.3, 1.3), CF(0, h + 0.4, 0.1), c.main, c.mat)
	add(P.head, V(0.9, 0.26, 1.0), CF(0, h + 0.66, 0.2), sh(c.main, 1.05), c.mat)
	add(P.head, V(0.52, 0.22, 0.6), CF(0, h + 0.88, 0.3), sh(c.main, 1.08), c.mat)
	add(P.head, V(0.2, 0.2, 0.24), CF(0, h + 1.04, 0.38), c.trim, M.Metal)
	-- the pig-faced visor
	add(P.head, V(1.3, 1.0, 0.18), CF(0, 0.06, -h - 0.14), c.main, c.mat)
	add(P.head, V(0.92, 0.7, 0.2), CF(0, -0.02, -h - 0.32), sh(c.main, 1.04), c.mat)
	add(P.head, V(0.54, 0.44, 0.22), CF(0, -0.08, -h - 0.52), sh(c.main, 1.1), c.mat)
	add(P.head, V(0.26, 0.24, 0.12), CF(0, -0.1, -h - 0.68), c.trim, M.Metal)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.34, 0.07, 0.04), CF(sx * 0.3, 0.26, -h - 0.42), DARK, M.Metal)
		add(P.head, V(0.14, 0.14, 0.24), CF(sx * (h + 0.12), 0.08, -h + 0.02), c.trim, M.Metal)
		for i = 0, 2 do
			add(P.head, V(0.05, 0.05, 0.04), CF(sx * (0.1 + i * 0.07), -0.2 - i * 0.04, -h - 0.63), DARK, M.Metal)
		end
	end
	-- mail aventail
	add(P.head, V(1.5, 0.52, 1.5), CF(0, -0.46, 0.04), sh(c.second, 0.9), M.DiamondPlate)
	add(P.torso, V(1.84, 0.34, 1.3), CF(0, 1.04, 0.02), sh(c.second, 0.85), M.DiamondPlate)
	add(P.torso, V(2.0, 0.1, 1.36), CF(0, 0.88, 0.02), c.trim, M.Leather)
	rune(add, P.head, CF(0, 0.5, -h - 0.25), c, rare, 0.16)
end

function STYLE.sallet(P, add, c, rare)
	add(P.head, V(1.44, 0.72, 1.48), CF(0, h - 0.04, 0.02), c.main, c.mat)
	add(P.head, V(1.2, 0.2, 1.26), CF(0, h + 0.4, 0.04), sh(c.main, 1.06), c.mat)
	-- keel ridge
	add(P.head, V(0.1, 0.16, 1.2), CF(0, h + 0.54, 0.06), c.trim, M.Metal)
	-- visor with the sight slit
	add(P.head, V(1.46, 0.46, 0.12), CF(0, 0.34, -h - 0.1), sh(c.main, 1.04), c.mat)
	add(P.head, V(1.2, 0.07, 0.04), CF(0, 0.12, -h - 0.15), DARK, M.Metal)
	-- long tail sweeping back over the neck
	add(P.head, V(1.46, 0.14, 0.7), CF(0, 0.28, h + 0.28) * ANG(0.35, 0, 0), c.main, c.mat)
	add(P.head, V(1.36, 0.12, 0.5), CF(0, 0.1, h + 0.62) * ANG(0.55, 0, 0), sh(c.main, 0.94), c.mat)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.12, 0.6, 1.3), CF(sx * (h + 0.1), 0.18, 0.1), c.main, c.mat)
	end
	-- bevor guarding chin and throat
	add(P.head, V(1.4, 0.56, 0.62), CF(0, -0.42, -0.42), sh(c.main, 0.92), c.mat)
	add(P.head, V(1.44, 0.1, 0.66), CF(0, -0.18, -0.42), c.trim, M.Metal)
	add(P.torso, V(1.6, 0.2, 1.2), CF(0, 1.08, -0.02), sh(c.main, 0.86), c.mat)
	rivets(add, P.head, V(-0.6, 0.5, -h - 0.17), V(0.6, 0.5, -h - 0.17), 4, 0.06, c.trim)
	if rare >= 5 then
		add(P.head, V(0.16, 0.4, 0.3), CF(0, h + 0.7, -0.2), c.accent, M.Fabric)
		add(P.head, V(0.12, 0.6, 0.2), CF(0, h + 0.86, 0.06) * ANG(-0.6, 0, 0), sh(c.accent, 0.9), M.Fabric)
	end
	rune(add, P.head, CF(0.45, 0.4, -h - 0.17), c, rare, 0.14)
end

function STYLE.barbute(P, add, c, rare)
	-- built around a dark liner so the T-shaped opening reads from every side
	add(P.head, V(1.36, 1.36, 1.36), CF(0, 0.02, 0), DARK, M.Fabric)
	add(P.head, V(1.46, 1.5, 0.88), CF(0, 0.03, 0.29), c.main, c.mat)
	add(P.head, V(1.46, 0.46, 0.6), CF(0, 0.55, -0.43), c.main, c.mat)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.56, 0.9, 0.6), CF(sx * 0.45, -0.31, -0.43), sh(c.main, 1.04), c.mat)
		add(P.head, V(0.22, 0.2, 0.6), CF(sx * 0.62, 0.22, -0.43), c.main, c.mat)
		add(P.head, V(0.06, 0.86, 0.08), CF(sx * 0.2, -0.31, -0.75), c.trim, M.Metal)
	end
	add(P.head, V(1.24, 0.2, 1.3), CF(0, h + 0.16, 0.02), sh(c.main, 1.06), c.mat)
	add(P.head, V(0.1, 0.18, 1.3), CF(0, h + 0.3, 0.02), c.trim, M.Metal)
	add(P.head, V(1.5, 0.06, 0.08), CF(0, 0.33, -0.75), c.trim, M.Metal)
	rivets(add, P.head, V(-0.62, -h + 0.12, -0.75), V(0.62, -h + 0.12, -0.75), 4, 0.06, c.trim)
	if rare >= 5 then
		for _, sx in { 1, -1 } do
			add(P.head, V(0.12, 0.5, 0.12), CF(sx * 0.6, h + 0.3, 0) * ANG(0, 0, -sx * 0.5), c.trim, M.Metal)
			tri(add, P.head, CF(sx * 0.78, h + 0.5, 0) * ANG(0, 0, -sx * 0.5), -0.06, 0.06, 0, 0.4, 0.1, c.trim, M.Metal)
		end
	end
	rune(add, P.head, CF(0, 0.55, -0.75), c, rare, 0.16)
end

function STYLE.plague(P, add, c, rare)
	local leather = c.main
	add(P.head, V(1.36, 1.06, 0.12), CF(0, 0.02, -h - 0.04), leather, M.Leather)
	-- the beak, curving down
	add(P.head, V(0.54, 0.46, 0.4), CF(0, -0.1, -h - 0.28), sh(leather, 1.05), M.Leather)
	add(P.head, V(0.4, 0.34, 0.42), CF(0, -0.18, -h - 0.62) * ANG(-0.2, 0, 0), leather, M.Leather)
	add(P.head, V(0.26, 0.22, 0.38), CF(0, -0.32, -h - 0.94) * ANG(-0.45, 0, 0), sh(leather, 0.9), M.Leather)
	add(P.head, V(0.14, 0.12, 0.2), CF(0, -0.46, -h - 1.14) * ANG(-0.7, 0, 0), sh(leather, 0.8), M.Leather)
	add(P.head, V(0.56, 0.06, 0.06), CF(0, -0.02, -h - 0.5), c.trim, M.Metal)
	-- round glass lenses in brass rims
	for _, sx in { 1, -1 } do
		add(P.head, V(0.1, 0.36, 0.36), CF(sx * 0.3, 0.16, -h - 0.12) * ANG(0, PI / 2, 0), Palette.metal.bronze, M.Metal, CYL)
		add(P.head, V(0.12, 0.26, 0.26), CF(sx * 0.3, 0.16, -h - 0.13) * ANG(0, PI / 2, 0), if rare >= 4 then c.accent else rgb(120, 40, 36), if rare >= 4 then M.Neon else M.Glass, CYL)
	end
	-- wide-brimmed hat
	add(P.head, V(2.0, 0.1, 2.0), CF(0, h + 0.08, 0), sh(c.second, 0.6), M.Leather)
	add(P.head, V(1.32, 0.52, 1.32), CF(0, h + 0.38, 0), sh(c.second, 0.66), M.Leather)
	add(P.head, V(1.36, 0.12, 1.36), CF(0, h + 0.2, 0), c.trim, M.Leather)
	-- hood behind
	add(P.head, V(1.48, 1.36, 0.2), CF(0, -0.06, h + 0.1), sh(c.second, 0.7), M.Fabric)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.16, 1.3, 1.34), CF(sx * (h + 0.1), -0.08, 0.06), sh(c.second, 0.7), M.Fabric)
	end
	add(P.torso, V(1.9, 0.36, 1.32), CF(0, 1.02, 0.04), sh(c.second, 0.68), M.Fabric)
end

function STYLE.thorns(P, add, c, rare)
	local wood = rgb(112, 86, 60)
	add(P.head, V(1.48, 0.1, 1.48), CF(0, h - 0.1, 0) * ANG(0.06, 0.2, 0), wood, M.Wood)
	add(P.head, V(1.5, 0.08, 1.46), CF(0, h - 0.06, 0) * ANG(-0.05, -0.3, 0.04), sh(wood, 1.2), M.Wood)
	for i = 0, 11 do
		local a = i * PI / 6
		local up = if i % 2 == 0 then 0.5 else -0.3
		add(P.head, V(0.05, 0.26, 0.05), CF(0, h - 0.08, 0) * ANG(0, a, 0) * CF(0, 0, -0.76) * ANG(-up, 0, 0.3) * CF(0, 0.1, 0), rgb(214, 200, 170), M.Wood)
	end
	if rare >= 3 then
		for _, x in { -0.3, 0.2 } do
			add(P.head, V(0.06, 0.14, 0.04), CF(x, h - 0.26, -0.645), rgb(140, 14, 22), if rare >= 4 then M.Neon else M.Glass)
		end
	end
	if rare >= 5 then
		for i = 0, 4 do
			add(P.head, V(0.08, 0.34, 0.08), CF(0, h - 0.04, 0) * ANG(0, (i - 2) * 0.4, 0) * CF(0, 0.16, -0.76), c.accent, M.Neon)
		end
	end
end

function STYLE.coif(P, add, c, rare)
	local mail = c.main
	add(P.head, V(1.46, 0.4, 1.48), CF(0, h + 0.02, 0.01), mail, M.DiamondPlate)
	add(P.head, V(1.24, 0.14, 1.26), CF(0, h + 0.24, 0.02), sh(mail, 1.06), M.DiamondPlate)
	add(P.head, V(0.9, 0.1, 0.94), CF(0, h + 0.34, 0.02), sh(mail, 1.1), M.DiamondPlate)
	add(P.head, V(1.49, 0.06, 1.5), CF(0, h - 0.06, 0.01), rgb(70, 48, 32), M.Leather)
	for _, sx in { 1, -1 } do
		add(P.head, V(0.12, 1.3, 1.46), CF(sx * (h + 0.08), -0.08, 0.01), mail, M.DiamondPlate)
	end
	add(P.head, V(1.46, 1.36, 0.12), CF(0, -0.06, h + 0.08), sh(mail, 0.94), M.DiamondPlate)
	-- ventail across the mouth, laced at the side
	add(P.head, V(1.46, 0.4, 0.12), CF(0, -0.46, -h - 0.06), sh(mail, 0.92), M.DiamondPlate)
	add(P.head, V(0.08, 0.36, 0.14), CF(-0.5, -0.46, -h - 0.08), rgb(70, 48, 32), M.Leather)
	-- padded arming cap edge showing around the face
	add(P.head, V(1.3, 0.1, 0.1), CF(0, h - 0.12, -h - 0.02), rgb(200, 186, 150), M.Fabric)
	-- mantle over the shoulders
	add(P.torso, V(2.14, 0.44, 1.4), CF(0, 0.92, 0.02), mail, M.DiamondPlate)
	add(P.torso, V(2.2, 0.08, 1.44), CF(0, 0.7, 0.02), rgb(70, 48, 32), M.Leather)
	if rare >= 4 then
		add(P.head, V(1.49, 0.06, 1.5), CF(0, h - 0.14, 0.01), c.trim, M.Metal)
	end
end

-- chest ----------------------------------------------------------------
local function sleeves(P, add, col, mat, len, thick)
	for _, a in { P.ra, P.la } do
		add(a, V(thick, len, thick), CF(0, 1 - len / 2, 0), col, mat)
	end
end

local function beltOn(P, add, col, buckle, y, w)
	add(P.torso, V(w or 2.24, 0.26, (w or 2.24) - 1.0), CF(0, y or -0.8, 0), col, M.Leather)
	add(P.torso, V(0.38, 0.3, 0.08), CF(0, y or -0.8, -((w or 2.24) - 1.0) / 2 - 0.02), buckle, M.Metal)
	add(P.torso, V(0.1, 0.22, 0.06), CF(0.06, y or -0.8, -((w or 2.24) - 1.0) / 2 - 0.06), sh(buckle, 0.7), M.Metal)
end

function STYLE.tunic(P, add, c, rare)
	add(P.torso, V(2.18, 2.08, 1.18), CF(0, 0, 0), c.main, c.mat)
	add(P.torso, V(2.26, 0.62, 1.26), CF(0, -1.25, 0), c.main, c.mat)
	add(P.torso, V(2.3, 0.1, 1.3), CF(0, -1.52, 0), c.second, c.mat)
	-- laced V-neck
	tri(add, P.torso, CF(0, 1.04, -0.6), -0.3, 0.3, 0, -0.5, 0.04, sh(c.main, 0.62), c.mat)
	for i = 0, 2 do
		add(P.torso, V(0.3, 0.04, 0.03), CF(0, 0.9 - i * 0.12, -0.63) * ANG(0, 0, (i % 2 - 0.5) * 0.6), c.second, M.Leather)
	end
	add(P.torso, V(1.6, 0.18, 1.24), CF(0, 0.98, 0), c.second, c.mat)
	beltOn(P, add, c.trim, Palette.metal.bronze)
	sleeves(P, add, c.main, c.mat, 1.3, 1.12)
	for _, a in { P.ra, P.la } do
		add(a, V(1.16, 0.12, 1.16), CF(0, 0.42, 0), c.second, c.mat)
	end
	if rare >= 3 then
		add(P.torso, V(2.3, 0.06, 1.3), CF(0, -1.44, 0), c.trim, c.mat)
	end
end

function STYLE.gambeson(P, add, c, rare)
	local q = sh(c.main, 0.8)
	add(P.torso, V(2.2, 2.08, 1.2), CF(0, 0, 0), c.main, c.mat)
	-- quilting: horizontal and vertical seams
	for i = 0, 3 do
		add(P.torso, V(2.22, 0.06, 1.22), CF(0, 0.7 - i * 0.44, 0), q, c.mat)
	end
	for _, x in { -0.55, 0, 0.55 } do
		add(P.torso, V(0.06, 2.1, 1.22), CF(x, 0, 0), q, c.mat)
	end
	add(P.torso, V(1.5, 0.34, 1.28), CF(0, 1.05, 0), sh(c.main, 0.9), c.mat)
	add(P.torso, V(2.3, 0.9, 1.3), CF(0, -1.35, 0), c.main, c.mat)
	add(P.torso, V(2.32, 0.06, 1.32), CF(0, -1.3, 0), q, c.mat)
	sleeves(P, add, c.main, c.mat, 1.85, 1.14)
	for _, a in { P.ra, P.la } do
		add(a, V(1.16, 0.06, 1.16), CF(0, 0.2, 0), q, c.mat)
		add(a, V(1.16, 0.06, 1.16), CF(0, -0.35, 0), q, c.mat)
		add(a, V(1.2, 0.3, 1.2), CF(0, 0.82, 0), sh(c.main, 0.92), c.mat)
	end
	beltOn(P, add, c.trim, Palette.metal.iron, -0.8, 2.26)
end

function STYLE.jerkin(P, add, c, rare)
	add(P.torso, V(2.18, 1.96, 1.18), CF(0, 0.05, 0), c.main, c.mat)
	add(P.torso, V(0.1, 1.9, 0.06), CF(0.3, 0.05, -0.61), sh(c.main, 0.78), c.mat)
	for i = 0, 3 do
		add(P.torso, V(0.12, 0.12, 0.06), CF(0.42, 0.72 - i * 0.42, -0.62), c.trim, M.Metal)
	end
	-- stitched panels
	for _, x in { -0.62, 0.72 } do
		add(P.torso, V(0.04, 1.8, 0.04), CF(x, 0.05, -0.6), sh(c.main, 0.7), c.mat)
	end
	for _, a in { P.ra, P.la } do
		add(a, V(1.22, 0.5, 1.22), CF(0, 0.76, 0), sh(c.main, 0.9), c.mat)
		add(a, V(1.24, 0.08, 1.24), CF(0, 0.52, 0), sh(c.main, 0.7), c.mat)
	end
	beltOn(P, add, c.trim, Palette.metal.bronze, -0.8)
	add(P.torso, V(0.5, 0.5, 0.3), CF(-0.72, -0.98, -0.4), sh(c.main, 1.1), c.mat)
	add(P.torso, V(0.52, 0.12, 0.32), CF(-0.72, -0.76, -0.4), sh(c.main, 0.8), c.mat)
	add(P.torso, V(2.24, 0.5, 1.24), CF(0, -1.2, 0), sh(c.main, 0.92), c.mat)
end

function STYLE.scoutjacket(P, add, c, rare)
	-- short cropped jacket, pale shirt below, harness straps across chest and thighs
	local shirt = rgb(236, 232, 222)
	add(P.torso, V(2.12, 2.04, 1.12), CF(0, 0, 0), shirt, M.Fabric)
	add(P.torso, V(2.2, 1.15, 1.2), CF(0, 0.45, 0), c.main, c.mat)
	add(P.torso, V(0.5, 0.36, 0.08), CF(0.48, 0.86, -0.62) * ANG(0, 0, 0.55), sh(c.main, 1.15), c.mat)
	add(P.torso, V(0.5, 0.36, 0.08), CF(-0.48, 0.86, -0.62) * ANG(0, 0, -0.55), sh(c.main, 1.15), c.mat)
	add(P.torso, V(2.22, 0.06, 1.22), CF(0, -0.1, 0), sh(c.main, 0.8), c.mat)
	sleeves(P, add, c.main, c.mat, 1.5, 1.12)
	for _, a in { P.ra, P.la } do
		add(a, V(1.14, 0.1, 1.14), CF(0, -0.46, 0), sh(c.main, 0.8), c.mat)
	end
	local strap = rgb(42, 34, 30)
	add(P.torso, V(2.18, 0.16, 1.18), CF(0, -0.2, 0), strap, M.Leather)
	add(P.torso, V(2.18, 0.16, 1.18), CF(0, -0.85, 0), strap, M.Leather)
	for _, s in { 1, -1 } do
		add(P.torso, V(0.14, 2.0, 0.06), CF(s * 0.52, -0.1, -0.6) * ANG(0, 0, s * 0.08), strap, M.Leather)
		add(P.torso, V(0.14, 2.0, 0.06), CF(s * 0.52, -0.1, 0.6) * ANG(0, 0, -s * 0.08), strap, M.Leather)
		add(P.torso, V(0.12, 0.1, 0.08), CF(s * 0.52, -0.2, -0.64), Palette.metal.steel, M.Metal)
	end
	for _, l in { P.rl, P.ll } do
		add(l, V(1.14, 0.12, 1.14), CF(0, 0.55, 0), strap, M.Leather)
		add(l, V(1.14, 0.12, 1.14), CF(0, 0.1, 0), strap, M.Leather)
		add(l, V(0.12, 0.6, 0.06), CF(0.1, 0.32, -0.58), strap, M.Leather)
	end
	-- side boxes (gear canisters)
	for _, s in { 1, -1 } do
		add(P.torso, V(0.36, 0.7, 0.9), CF(s * 1.22, -1.05, 0), Palette.metal.steel, M.Metal)
		add(P.torso, V(0.38, 0.1, 0.92), CF(s * 1.22, -0.8, 0), strap, M.Leather)
		add(P.torso, V(0.2, 0.2, 0.3), CF(s * 1.22, -0.62, -0.3), sh(Palette.metal.steel, 0.8), M.Metal)
	end
end

function STYLE.hauberk(P, add, c, rare)
	local mail = c.main
	add(P.torso, V(2.2, 2.1, 1.2), CF(0, 0, 0), mail, M.DiamondPlate)
	add(P.torso, V(2.3, 1.2, 1.3), CF(0, -1.5, 0), sh(mail, 0.92), M.DiamondPlate)
	add(P.torso, V(0.06, 1.1, 1.32), CF(0, -1.56, 0), sh(mail, 0.7), M.DiamondPlate)
	sleeves(P, add, mail, M.DiamondPlate, 1.3, 1.14)
	for _, a in { P.ra, P.la } do
		add(a, V(1.18, 0.1, 1.18), CF(0, -0.3, 0), sh(mail, 0.8), M.DiamondPlate)
	end
	beltOn(P, add, rgb(70, 48, 32), Palette.metal.iron, -0.82, 2.3)
	-- tabard in the second colour with a painted stripe
	add(P.torso, V(1.2, 2.3, 0.06), CF(0, -0.4, -0.64), c.second, M.Fabric)
	add(P.torso, V(1.2, 2.3, 0.06), CF(0, -0.4, 0.64), c.second, M.Fabric)
	add(P.torso, V(0.3, 1.6, 0.07), CF(0, -0.1, -0.65), c.accent, M.Fabric)
	add(P.torso, V(1.24, 0.08, 0.08), CF(0, -1.54, -0.64), c.trim, M.Fabric)
	add(P.torso, V(1.6, 0.26, 1.3), CF(0, 1.02, 0), sh(mail, 0.88), M.DiamondPlate)
end

function STYLE.furmantle(P, add, c, rare)
	add(P.torso, V(2.18, 2.04, 1.18), CF(0, 0, 0), c.main, c.mat)
	add(P.torso, V(2.7, 0.7, 1.6), CF(0, 0.92, 0.02), c.second, M.Fabric)
	add(P.torso, V(2.44, 0.4, 1.5), CF(0, 0.5, 0.05), sh(c.second, 0.9), M.Fabric)
	-- tufts
	for i = -2, 2 do
		add(P.torso, V(0.36, 0.3, 0.3), CF(i * 0.5, 0.36, -0.7) * ANG(0.3, 0, i * 0.2), sh(c.second, 0.85 + (i % 2) * 0.12), M.Fabric)
	end
	for _, a in { P.ra, P.la } do
		add(a, V(1.35, 0.6, 1.35), CF(0, 0.75, 0), c.second, M.Fabric)
		add(a, V(1.18, 0.14, 1.18), CF(0, 0.2, 0), c.trim, M.Leather)
	end
	add(P.torso, V(0.12, 2.0, 0.08), CF(0.5, 0.3, -0.62) * ANG(0, 0, 0.5), c.trim, M.Leather)
	beltOn(P, add, c.trim, Palette.metal.bronze, -0.8)
	add(P.torso, V(2.28, 0.7, 1.28), CF(0, -1.3, 0), sh(c.main, 0.9), c.mat)
	add(P.torso, V(0.3, 0.3, 0.1), CF(0.42, 0.62, -0.84), Palette.metal.bronze, M.Metal)
end

function STYLE.robe(P, add, c, rare)
	add(P.torso, V(2.16, 2.06, 1.16), CF(0, 0, 0), c.main, M.Fabric)
	add(P.torso, V(2.34, 2.3, 1.42), CF(0, -2.0, 0), c.main, M.Fabric)
	-- folds in the skirt
	for _, x in { -0.7, 0, 0.7 } do
		add(P.torso, V(0.12, 2.1, 1.46), CF(x, -2.05, 0), sh(c.main, 0.82), M.Fabric)
	end
	add(P.torso, V(2.4, 0.16, 1.48), CF(0, -3.1, 0), c.trim, M.Fabric)
	add(P.torso, V(0.28, 2.08, 1.2), CF(0, 0, 0), c.trim, M.Fabric)
	-- sash and the hood resting on the back
	add(P.torso, V(2.22, 0.3, 1.22), CF(0, -0.8, 0), c.accent, M.Fabric)
	add(P.torso, V(0.3, 0.8, 0.08), CF(0.6, -1.2, -0.64), c.accent, M.Fabric)
	add(P.torso, V(1.4, 0.6, 0.4), CF(0, 0.85, 0.72), sh(c.main, 0.9), M.Fabric)
	for _, a in { P.ra, P.la } do
		add(a, V(1.28, 1.7, 1.28), CF(0, 0.15, 0), c.main, M.Fabric)
		add(a, V(1.44, 0.6, 1.44), CF(0, -0.55, 0), sh(c.main, 0.94), M.Fabric)
		add(a, V(1.48, 0.12, 1.48), CF(0, -0.8, 0), c.trim, M.Fabric)
	end
	if rare >= 3 then
		for _, y in { 0.4, -0.2 } do
			add(P.torso, V(0.18, 0.18, 0.04), CF(0, y, -0.62) * ANG(0, 0, PI / 4), c.accent, if rare >= 4 then M.Neon else M.Fabric)
		end
	end
	if rare >= 4 then
		add(P.torso, V(0.06, 1.8, 0.02), CF(0.3, -0.1, -0.61), c.accent, M.Neon)
		add(P.torso, V(0.06, 1.8, 0.02), CF(-0.3, -0.1, -0.61), c.accent, M.Neon)
	end
end

function STYLE.lamellar(P, add, c, rare)
	add(P.torso, V(2.14, 2.04, 1.14), CF(0, 0, 0), c.second, M.Leather)
	for i = 0, 5 do
		local sh2 = if i % 2 == 0 then 1 else 0.86
		add(P.torso, V(2.22 + (i % 2) * 0.04, 0.34, 1.22 + (i % 2) * 0.04), CF(0, 0.84 - i * 0.33, 0), sh(c.main, sh2), c.mat)
		-- lacing
		add(P.torso, V(0.04, 0.3, 1.3), CF(-0.5 + (i % 2) * 0.2, 0.84 - i * 0.33, 0), c.trim, M.Leather)
		add(P.torso, V(0.04, 0.3, 1.3), CF(0.5 - (i % 2) * 0.2, 0.84 - i * 0.33, 0), c.trim, M.Leather)
	end
	for _, a in { P.ra, P.la } do
		for i = 0, 2 do
			add(a, V(1.34 - i * 0.06, 0.3, 1.34 - i * 0.06), CF(0, 0.84 - i * 0.28, 0), sh(c.main, 1 - i * 0.08), c.mat)
		end
		add(a, V(1.1, 1.1, 1.1), CF(0, -0.15, 0), c.second, M.Leather)
	end
	add(P.torso, V(2.32, 0.26, 1.32), CF(0, -0.86, 0), c.trim, M.Leather)
	add(P.torso, V(2.34, 0.8, 1.34), CF(0, -1.34, 0), sh(c.main, 0.8), c.mat)
	add(P.torso, V(0.06, 0.8, 1.36), CF(0, -1.34, 0), c.trim, M.Leather)
	rune(add, P.torso, CF(0, 0.5, -0.64), c, rare)
end

local function pauldron(add, arm: BasePart, c, n: number, big: number)
	for i = 0, n - 1 do
		local w = big - i * 0.08
		add(arm, V(w, 0.3, w), CF(0, 0.86 - i * 0.26, 0) * ANG(0, 0, 0), sh(c.main, 1 - i * 0.07), M.Metal)
		add(arm, V(w + 0.04, 0.06, w + 0.04), CF(0, 0.72 - i * 0.26, 0), c.trim, M.Metal)
	end
end

function STYLE.cuirass(P, add, c, rare)
	-- breastplate with a central ridge
	add(P.torso, V(2.24, 1.36, 1.24), CF(0, 0.32, 0), c.main, M.Metal)
	for _, sx in { 1, -1 } do
		add(P.torso, V(1.0, 1.1, 0.12), CF(sx * 0.46, 0.34, -0.6) * ANG(0, sx * 0.22, 0), sh(c.main, 1.08), M.Metal)
	end
	add(P.torso, V(0.1, 1.2, 0.1), CF(0, 0.32, -0.7), sh(c.main, 1.2), M.Metal)
	add(P.torso, V(2.28, 0.1, 1.28), CF(0, 1.0, 0), c.trim, M.Metal)
	add(P.torso, V(2.22, 0.26, 1.22), CF(0, -0.45, 0), sh(c.main, 0.78), M.Metal)
	-- faulds
	for i = 0, 2 do
		add(P.torso, V(2.26 + i * 0.04, 0.28, 1.26 + i * 0.04), CF(0, -0.72 - i * 0.26, 0), sh(c.main, 0.92 - i * 0.05), M.Metal)
	end
	add(P.torso, V(1.46, 0.3, 1.36), CF(0, 1.05, 0), sh(c.main, 0.9), M.Metal)
	rivets(add, P.torso, V(-0.8, 0.9, -0.66), V(0.8, 0.9, -0.66), 4, 0.07, c.trim)
	for _, a in { P.ra, P.la } do
		pauldron(add, a, c, 3, 1.44)
		add(a, V(1.16, 1.3, 1.16), CF(0, -0.25, 0), sh(c.main, 0.85), M.Metal)
		add(a, V(1.22, 0.24, 1.26), CF(0, -0.05, -0.02), sh(c.main, 1.05), M.Metal)
	end
	if rare >= 4 then
		add(P.torso, V(0.36, 0.36, 0.05), CF(0, 0.5, -0.74) * ANG(0, 0, PI / 4), c.accent, M.Neon)
	end
	if rare >= 5 then
		for _, sx in { 1, -1 } do
			add(P.torso, V(0.3, 0.5, 0.3), CF(sx * 0.7, 1.12, 0.1) * ANG(0, 0, sx * 0.3), c.trim, M.Metal)
		end
	end
end

function STYLE.brigandine(P, add, c, rare)
	-- cloth-covered plates studded with rivets over a padded jack
	add(P.torso, V(2.16, 2.04, 1.16), CF(0, 0, 0), sh(c.second, 1.0), M.Fabric)
	local cover = c.accent:Lerp(rgb(60, 40, 40), 0.45)
	add(P.torso, V(2.24, 1.6, 1.24), CF(0, 0.18, 0), cover, M.Fabric)
	add(P.torso, V(0.06, 1.62, 0.08), CF(-0.02, 0.18, -0.64), sh(cover, 0.7), M.Fabric)
	local stud = if rare >= 3 then Palette.metal.gold else Palette.metal.iron
	for row = 0, 3 do
		for col = 0, 3 do
			local x = -0.72 + col * 0.48
			add(P.torso, V(0.08, 0.08, 0.06), CF(x, 0.8 - row * 0.42, -0.63), stud, M.Metal)
		end
	end
	for row = 0, 2 do
		add(P.torso, V(1.6, 0.08, 0.06), CF(0, 0.7 - row * 0.5, 0.63), stud, M.Metal)
	end
	-- plackart and padded skirt
	add(P.torso, V(1.3, 0.4, 0.1), CF(0, -0.46, -0.64), c.main, M.Metal)
	add(P.torso, V(2.28, 0.72, 1.28), CF(0, -1.3, 0), c.second, M.Fabric)
	for _, x in { -0.55, 0, 0.55 } do
		add(P.torso, V(0.05, 0.72, 1.3), CF(x, -1.3, 0), sh(c.second, 0.8), M.Fabric)
	end
	beltOn(P, add, rgb(60, 40, 28), stud, -0.8, 2.28)
	sleeves(P, add, c.second, M.Fabric, 1.7, 1.12)
	for _, a in { P.ra, P.la } do
		add(a, V(1.3, 0.5, 1.3), CF(0, 0.76, 0), cover, M.Fabric)
		rivets(add, a, V(-0.2, 0.8, -0.66), V(0.2, 0.8, -0.66), 3, 0.07, stud)
	end
	rune(add, P.torso, CF(0, 0.2, -0.66), c, rare)
end

function STYLE.surcoat(P, add, c, rare)
	local mail = rgb(150, 154, 162)
	add(P.torso, V(2.16, 2.06, 1.16), CF(0, 0, 0), mail, M.DiamondPlate)
	sleeves(P, add, mail, M.DiamondPlate, 1.9, 1.12)
	-- sleeveless surcoat with a painted device, split skirt
	local coat = c.main
	add(P.torso, V(2.24, 2.0, 1.24), CF(0, -0.02, 0), coat, M.Fabric)
	for _, sx in { 1, -1 } do
		add(P.torso, V(1.08, 1.3, 1.28), CF(sx * 0.58, -1.6, 0), sh(coat, 0.94), M.Fabric)
	end
	add(P.torso, V(2.3, 0.08, 1.3), CF(0, 0.9, 0), c.trim, M.Fabric)
	-- the device: a cross or a chevron
	local dev = if c.accent == coat then c.trim else c.accent
	if (rare % 2) == 1 then
		add(P.torso, V(0.24, 1.2, 0.04), CF(0, 0.12, -0.63), dev, M.Fabric)
		add(P.torso, V(0.9, 0.24, 0.04), CF(0, 0.3, -0.63), dev, M.Fabric)
	else
		add(P.torso, V(0.9, 0.2, 0.04), CF(0.3, 0.16, -0.63) * ANG(0, 0, 0.6), dev, M.Fabric)
		add(P.torso, V(0.9, 0.2, 0.04), CF(-0.3, 0.16, -0.63) * ANG(0, 0, -0.6), dev, M.Fabric)
	end
	add(P.torso, V(0.24, 1.2, 0.04), CF(0, 0.12, 0.63), dev, M.Fabric)
	beltOn(P, add, rgb(50, 36, 28), Palette.metal.iron, -0.82, 2.3)
	add(P.torso, V(0.2, 0.9, 0.16), CF(-0.9, -1.24, -0.2) * ANG(0, 0, -0.1), rgb(50, 36, 28), M.Leather)
	rune(add, P.torso, CF(0, 0.3, -0.66), c, rare)
end

function STYLE.scale(P, add, c, rare)
	add(P.torso, V(2.16, 2.04, 1.16), CF(0, 0, 0), c.second, M.Leather)
	for row = 0, 4 do
		local y = 0.82 - row * 0.4
		add(P.torso, V(2.24 + (row % 2) * 0.03, 0.34, 1.24 + (row % 2) * 0.03), CF(0, y, 0), sh(c.main, if row % 2 == 0 then 1 else 0.9), c.mat)
		-- scale tips along the lower edge of each row
		for i = 0, 3 do
			local x = -0.75 + i * 0.5 + (row % 2) * 0.25
			if x < 1.0 then
				tri(add, P.torso, CF(x, y - 0.17, -0.64 - (row % 2) * 0.015), -0.2, 0.2, 0, -0.14, 0.04, sh(c.main, 1.12), c.mat)
			end
		end
	end
	add(P.torso, V(2.36, 0.7, 1.36), CF(0, -1.3, 0), sh(c.main, 0.86), c.mat)
	beltOn(P, add, c.trim, Palette.metal.bronze, -0.86, 2.3)
	for _, a in { P.ra, P.la } do
		for i = 0, 2 do
			add(a, V(1.3 - i * 0.05, 0.3, 1.3 - i * 0.05), CF(0, 0.84 - i * 0.28, 0), sh(c.main, 1 - i * 0.06), c.mat)
		end
	end
	rune(add, P.torso, CF(0, 0.4, -0.67), c, rare)
end

function STYLE.bonemail(P, add, c, rare)
	-- a leather harness hung with ribs, skull pauldrons and a spine
	add(P.torso, V(2.16, 2.04, 1.16), CF(0, 0, 0), c.main, M.Leather)
	local bone = BONE
	add(P.torso, V(0.16, 1.5, 0.12), CF(0, 0.2, -0.64), sh(bone, 0.95), M.Marble)
	for i = 0, 3 do
		local y = 0.75 - i * 0.34
		for _, sx in { 1, -1 } do
			add(P.torso, V(0.9 - i * 0.08, 0.1, 0.1), CF(sx * 0.5, y, -0.64) * ANG(0, 0, sx * 0.22), bone, M.Marble)
		end
	end
	add(P.torso, V(0.14, 1.9, 0.12), CF(0, 0, 0.64), bone, M.Marble)
	for i = 0, 4 do
		add(P.torso, V(0.34, 0.08, 0.14), CF(0, 0.8 - i * 0.38, 0.66), sh(bone, 0.9), M.Marble)
	end
	for _, s in { 1, -1 } do
		add(P.torso, V(0.18, 2.4, 0.06), CF(s * 0.35, 0, -0.6) * ANG(0, 0, s * 0.5), rgb(46, 32, 26), M.Leather)
	end
	for _, a in { P.ra, P.la } do
		-- skull pauldron
		add(a, V(1.1, 0.7, 1.0), CF(0, 0.9, 0), bone, M.Marble)
		add(a, V(0.8, 0.28, 0.72), CF(0, 0.5, -0.1), sh(bone, 0.9), M.Marble)
		for _, sx in { 1, -1 } do
			add(a, V(0.22, 0.18, 0.04), CF(sx * 0.2, 0.92, -0.5), DARK, M.Slate)
			if rare >= 4 then
				add(a, V(0.08, 0.08, 0.02), CF(sx * 0.2, 0.92, -0.52), c.accent, M.Neon)
			end
		end
		add(a, V(1.12, 1.0, 1.12), CF(0, -0.1, 0), sh(c.main, 0.8), M.Leather)
	end
	beltOn(P, add, rgb(46, 32, 26), bone, -0.84)
	add(P.torso, V(2.28, 0.6, 1.28), CF(0, -1.3, 0), sh(c.main, 0.8), M.Leather)
end

function STYLE.gothic(P, add, c, rare)
	-- fluted breastplate, pointed plackart, fan-winged couters, big layered pauldrons
	add(P.torso, V(2.24, 1.4, 1.24), CF(0, 0.3, 0), c.main, M.Metal)
	for i = -2, 2 do
		add(P.torso, V(0.06, 1.1, 0.06), CF(i * 0.2, 0.42, -0.64) * ANG(0, 0, -i * 0.12), sh(c.main, 1.22), M.Metal)
	end
	tri(add, P.torso, CF(0, -0.45, -0.66), -0.6, 0.6, 0, 0.8, 0.06, sh(c.main, 1.08), M.Metal)
	add(P.torso, V(2.3, 0.1, 1.3), CF(0, 0.98, 0), c.trim, M.Metal)
	add(P.torso, V(2.22, 0.26, 1.22), CF(0, -0.46, 0), sh(c.main, 0.8), M.Metal)
	for i = 0, 3 do
		add(P.torso, V(2.26 + i * 0.03, 0.24, 1.26 + i * 0.03), CF(0, -0.68 - i * 0.22, 0), sh(c.main, 0.95 - (i % 2) * 0.08), M.Metal)
		add(P.torso, V(2.3 + i * 0.03, 0.04, 1.3 + i * 0.03), CF(0, -0.79 - i * 0.22, 0), c.trim, M.Metal)
	end
	add(P.torso, V(1.5, 0.34, 1.36), CF(0, 1.06, 0), sh(c.main, 0.92), M.Metal)
	for _, a in { P.ra, P.la } do
		pauldron(add, a, c, 3, 1.5)
		-- haute-piece standing up to guard the neck
		local inward = if a == P.ra then -1 else 1
		add(a, V(0.12, 0.4, 1.3), CF(inward * 0.6, 1.14, 0), sh(c.main, 1.1), M.Metal)
		add(a, V(1.16, 1.3, 1.16), CF(0, -0.25, 0), sh(c.main, 0.86), M.Metal)
		-- couter with a fan wing
		add(a, V(1.24, 0.3, 1.24), CF(0, -0.1, 0), sh(c.main, 1.06), M.Metal)
		tri(add, a, CF(-inward * 0.64, -0.1, 0) * ANG(0, PI / 2, 0), -0.3, 0.3, 0, 0.4, 0.05, sh(c.main, 1.1), M.Metal)
	end
	rivets(add, P.torso, V(-0.9, 0.9, -0.66), V(0.9, 0.9, -0.66), 5, 0.06, c.trim)
	if rare >= 4 then
		add(P.torso, V(0.3, 0.3, 0.05), CF(0, 0.55, -0.7) * ANG(0, 0, PI / 4), c.accent, M.Neon)
	end
	if rare >= 5 then
		for _, a in { P.ra, P.la } do
			tri(add, a, CF(0, 1.02, 0), -0.4, 0.4, 0, 0.5, 0.08, c.trim, M.Metal)
		end
	end
end

-- hands ------------------------------------------------------------------
function STYLE.gloves(P, add, c, rare)
	for _, a in { P.ra, P.la } do
		add(a, V(1.12, 0.52, 1.12), CF(0, -0.75, 0), c.main, c.mat)
		add(a, V(1.2, 0.26, 1.2), CF(0, -0.42, 0), c.second, c.mat)
		add(a, V(1.22, 0.05, 1.22), CF(0, -0.3, 0), sh(c.second, 0.7), c.mat)
		-- knuckle seam and finger lines
		add(a, V(1.14, 0.06, 1.14), CF(0, -0.78, 0), sh(c.main, 0.7), c.mat)
		for i = -1, 1 do
			add(a, V(0.03, 0.2, 0.03), CF(i * 0.25, -0.9, -0.57), sh(c.main, 0.65), c.mat)
		end
	end
end

function STYLE.bracers(P, add, c, rare)
	for _, a in { P.ra, P.la } do
		add(a, V(1.12, 0.36, 1.12), CF(0, -0.84, 0), sh(c.main, 0.8), c.mat)
		add(a, V(1.18, 0.7, 1.18), CF(0, -0.38, 0), c.main, c.mat)
		add(a, V(1.22, 0.08, 1.22), CF(0, -0.1, 0), c.trim, M.Metal)
		add(a, V(1.22, 0.08, 1.22), CF(0, -0.66, 0), c.trim, M.Metal)
		-- criss-cross laces on the front
		add(a, V(0.04, 0.5, 0.03), CF(0, -0.38, -0.6) * ANG(0, 0, 0.5), sh(c.main, 0.6), M.Leather)
		add(a, V(0.04, 0.5, 0.03), CF(0, -0.38, -0.6) * ANG(0, 0, -0.5), sh(c.main, 0.6), M.Leather)
		rivets(add, a, V(-0.4, -0.38, -0.6), V(0.4, -0.38, -0.6), 2, 0.07, c.trim)
	end
end

function STYLE.mitts(P, add, c, rare)
	for _, a in { P.ra, P.la } do
		add(a, V(1.12, 1.0, 1.12), CF(0, -0.52, 0), c.main, M.DiamondPlate)
		add(a, V(1.16, 0.3, 1.16), CF(0, -0.85, 0), sh(c.main, 0.9), M.DiamondPlate)
		add(a, V(1.18, 0.14, 1.18), CF(0, -0.05, 0), rgb(70, 48, 32), M.Leather)
		add(a, V(0.8, 0.4, 0.06), CF(0, -0.82, 0.57), rgb(70, 48, 32), M.Leather)
	end
end

local function fingerPlates(add, a, c, col)
	-- knuckle plate and three finger lames over the fist
	add(a, V(1.18, 0.14, 1.2), CF(0, -0.62, -0.01), sh(col, 1.08), M.Metal)
	for i = 0, 2 do
		add(a, V(1.14 - i * 0.04, 0.1, 0.12), CF(0, -0.74 - i * 0.1, -0.56), sh(col, 1 - i * 0.06), M.Metal)
	end
	rivets(add, a, V(-0.36, -0.62, -0.61), V(0.36, -0.62, -0.61), 3, 0.06, c.trim)
end

function STYLE.gauntlets(P, add, c, rare)
	for _, a in { P.ra, P.la } do
		add(a, V(1.14, 0.9, 1.14), CF(0, -0.55, 0), c.main, M.Metal)
		-- flared cuff
		add(a, V(1.3, 0.22, 1.3), CF(0, -0.08, 0), sh(c.main, 0.9), M.Metal)
		add(a, V(1.34, 0.05, 1.34), CF(0, 0.02, 0), c.trim, M.Metal)
		fingerPlates(add, a, c, c.main)
		if rare >= 4 then
			add(a, V(0.2, 0.2, 0.04), CF(0, -0.35, -0.6) * ANG(0, 0, PI / 4), c.accent, M.Neon)
		end
	end
end

function STYLE.claws(P, add, c, rare)
	local metal = sh(c.main, 0.55)
	for _, a in { P.ra, P.la } do
		add(a, V(1.14, 0.9, 1.14), CF(0, -0.55, 0), metal, M.Metal)
		add(a, V(1.3, 0.26, 1.3), CF(0, -0.08, 0), sh(metal, 0.85), M.Metal)
		fingerPlates(add, a, c, metal)
		-- spiked knuckles and long claws
		for i = -1, 1 do
			add(a, V(0.12, 0.12, 0.2), CF(i * 0.3, -0.62, -0.64) * ANG(PI / 4, 0, 0), c.trim, M.Metal)
			tri(add, a, CF(i * 0.3, -0.98, -0.52), -0.06, 0.06, 0, -0.5, 0.06, sh(c.trim, 1.2), M.Metal)
		end
		tri(add, a, CF(0, -0.1, 0.62) * ANG(0, PI / 2, 0), -0.18, 0.18, 0, 0.4, 0.05, metal, M.Metal)
		if rare >= 4 then
			add(a, V(0.8, 0.04, 0.03), CF(0, -0.4, -0.58), c.accent, M.Neon)
		end
	end
end

function STYLE.handwraps(P, add, c, rare)
	local cloth = c.main
	for _, a in { P.ra, P.la } do
		for i = 0, 5 do
			add(a, V(1.1 + (i % 2) * 0.02, 0.16, 1.1 + (i % 2) * 0.02), CF(0, -0.95 + i * 0.16, 0) * ANG(0, 0, if i % 2 == 0 then 0.18 else -0.18), if i % 2 == 0 then cloth else sh(cloth, 0.85), M.Fabric)
		end
		-- a loose end hanging from the wrist
		add(a, V(0.14, 0.44, 0.04), CF(0.3, -0.52, 0.58) * ANG(0.2, 0, 0.2), sh(cloth, 0.8), M.Fabric)
		if rare >= 3 then
			add(a, V(1.18, 0.06, 1.18), CF(0, -0.2, 0), c.trim, M.Metal)
		end
	end
end

-- legs -------------------------------------------------------------------
function STYLE.trousers(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		add(l, V(1.12, 1.9, 1.12), CF(0, 0.05, 0), c.main, c.mat)
		add(l, V(1.16, 0.5, 1.16), CF(0, 0.02, -0.02), sh(c.main, 0.9), c.mat)
		add(l, V(0.04, 1.8, 0.04), CF(0.56, 0.05, 0), sh(c.main, 0.7), c.mat)
		add(l, V(1.16, 0.12, 1.16), CF(0, -0.9, 0), sh(c.main, 0.75), c.mat)
	end
end

function STYLE.wraps(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		add(l, V(1.12, 1.9, 1.12), CF(0, 0.05, 0), c.main, c.mat)
		for i = 0, 4 do
			add(l, V(1.16, 0.12, 1.16), CF(0, -0.8 + i * 0.24, 0) * ANG(0, 0, if i % 2 == 0 then 0.18 else -0.18), c.second, M.Leather)
		end
		add(l, V(0.12, 0.36, 0.04), CF(0.3, -0.1, -0.6) * ANG(0, 0, 0.2), sh(c.second, 0.8), M.Leather)
	end
end

function STYLE.chausses(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		add(l, V(1.12, 1.92, 1.12), CF(0, 0.04, 0), c.main, M.DiamondPlate)
		-- poleyn (knee cop) with side wings
		add(l, V(1.18, 0.34, 1.24), CF(0, 0.05, -0.02), sh(c.main, 1.1), M.Metal)
		add(l, V(0.5, 0.3, 0.1), CF(0, 0.05, -0.65) * ANG(0, 0, PI / 4), sh(c.main, 1.18), M.Metal)
		add(l, V(1.18, 0.12, 1.18), CF(0, 0.5, 0), rgb(70, 48, 32), M.Leather)
	end
end

function STYLE.greaves(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		-- cuisse, poleyn with side fan, greave with a ridge
		add(l, V(1.16, 0.8, 1.16), CF(0, 0.5, 0), c.main, M.Metal)
		add(l, V(1.2, 0.06, 1.2), CF(0, 0.84, 0), c.trim, M.Metal)
		add(l, V(1.2, 0.38, 1.28), CF(0, 0.02, -0.04), sh(c.main, 1.1), M.Metal)
		add(l, V(0.44, 0.34, 0.1), CF(0, 0.02, -0.7) * ANG(0, 0, PI / 4), sh(c.main, 1.2), M.Metal)
		add(l, V(0.1, 0.5, 0.5), CF(0.62, 0.04, -0.08) * ANG(PI / 4, 0, 0), sh(c.main, 1.05), M.Metal)
		add(l, V(1.16, 0.8, 1.16), CF(0, -0.5, 0), c.main, M.Metal)
		add(l, V(0.1, 0.7, 0.1), CF(0, -0.5, -0.61), sh(c.main, 1.25), M.Metal)
		rivets(add, l, V(-0.4, 0.3, -0.6), V(0.4, 0.3, -0.6), 2, 0.07, c.trim)
	end
end

function STYLE.tassets(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		-- plate skirt hanging from the waist over the thigh
		for i = 0, 2 do
			add(l, V(1.2 + i * 0.03, 0.3, 1.24 + i * 0.03), CF(0, 0.88 - i * 0.26, -0.02), sh(c.main, 1 - i * 0.07), M.Metal)
			add(l, V(1.24 + i * 0.03, 0.04, 1.28 + i * 0.03), CF(0, 0.74 - i * 0.26, -0.02), c.trim, M.Metal)
		end
		add(l, V(1.14, 1.0, 1.14), CF(0, -0.45, 0), c.second, M.Leather)
		add(l, V(1.2, 0.34, 1.26), CF(0, -0.05, -0.03), sh(c.main, 1.08), M.Metal)
		add(l, V(0.4, 0.3, 0.1), CF(0, -0.05, -0.68) * ANG(0, 0, PI / 4), sh(c.main, 1.2), M.Metal)
		rivets(add, l, V(-0.45, 0.88, -0.66), V(0.45, 0.88, -0.66), 3, 0.06, c.trim)
	end
end

function STYLE.breeches(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		add(l, V(1.14, 1.3, 1.14), CF(0, 0.35, 0), c.main, c.mat)
		add(l, V(1.2, 0.5, 1.2), CF(0, 0.55, -0.01), sh(c.main, 1.08), c.mat)
		add(l, V(1.18, 0.14, 1.18), CF(0, -0.28, 0), c.trim, M.Leather)
		add(l, V(0.16, 0.18, 0.06), CF(0.3, -0.28, -0.61), Palette.metal.iron, M.Metal)
		add(l, V(1.12, 0.66, 1.12), CF(0, -0.64, 0), c.second, M.Fabric)
		add(l, V(0.04, 1.2, 0.04), CF(0.57, 0.35, 0), sh(c.main, 0.7), c.mat)
	end
end

-- feet -------------------------------------------------------------------
local function boot(l, add, col, mat, hgt, sole)
	add(l, V(1.14, hgt, 1.26), CF(0, -1 + hgt / 2, -0.08), col, mat)
	add(l, V(1.16, 0.12, 1.3), CF(0, -0.95, -0.08), sole or rgb(34, 26, 22), M.Leather)
	add(l, V(1.0, 0.24, 0.12), CF(0, -0.84, -0.72), sh(col, 1.08), mat)
end

function STYLE.boots(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		boot(l, add, c.main, c.mat, 0.66)
		add(l, V(1.2, 0.16, 1.3), CF(0, -0.34, -0.06), sh(c.main, 0.85), c.mat)
		for i = 0, 1 do
			add(l, V(0.36, 0.04, 0.04), CF(0, -0.5 - i * 0.14, -0.72), sh(c.main, 0.6), M.Leather)
		end
	end
end

function STYLE.furboots(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		boot(l, add, c.main, c.mat, 0.7)
		add(l, V(1.28, 0.34, 1.32), CF(0, -0.34, -0.04), c.second, M.Fabric)
		for _, x in { -0.35, 0.35 } do
			add(l, V(0.3, 0.26, 0.2), CF(x, -0.24, -0.62) * ANG(0.3, 0, x), sh(c.second, 0.88), M.Fabric)
		end
		add(l, V(1.2, 0.08, 1.2), CF(0, -0.56, -0.02), c.trim, M.Leather)
	end
end

function STYLE.ridingboots(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		boot(l, add, c.main, c.mat, 1.15)
		-- turned-down cuff and a buckled strap
		add(l, V(1.22, 0.22, 1.28), CF(0, 0.14, -0.02), sh(c.main, 1.12), c.mat)
		add(l, V(1.18, 0.08, 1.3), CF(0, -0.62, -0.08), rgb(40, 30, 24), M.Leather)
		add(l, V(0.14, 0.12, 0.06), CF(0.3, -0.62, -0.75), Palette.metal.iron, M.Metal)
		if rare >= 3 then
			add(l, V(0.06, 0.06, 0.3), CF(0, -0.84, 0.66), c.trim, M.Metal)
		end
	end
end

function STYLE.sabatons(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		boot(l, add, c.main, M.Metal, 0.66, sh(c.main, 0.7))
		-- overlapping lames over the foot
		for i = 0, 2 do
			add(l, V(1.02 - i * 0.06, 0.12, 0.3), CF(0, -0.64 - i * 0.08, -0.62 - i * 0.14), sh(c.main, 1.08 - i * 0.04), M.Metal)
		end
		add(l, V(1.2, 0.2, 1.3), CF(0, -0.38, -0.06), sh(c.main, 0.92), M.Metal)
		add(l, V(0.1, 0.3, 0.3), CF(0.6, -0.62, -0.06) * ANG(PI / 4, 0, 0), sh(c.main, 1.1), M.Metal)
	end
end

function STYLE.sollerets(P, add, c, rare)
	for _, l in { P.rl, P.ll } do
		boot(l, add, c.main, M.Metal, 0.66, sh(c.main, 0.7))
		for i = 0, 3 do
			add(l, V(0.96 - i * 0.1, 0.1, 0.24), CF(0, -0.66 - i * 0.06, -0.62 - i * 0.14), sh(c.main, 1.1 - i * 0.04), M.Metal)
		end
		-- the long gothic point
		tri(add, l, CF(0, -0.94, -0.8) * ANG(-PI / 2, 0, 0), -0.3, 0.3, 0, 0.6, 0.12, sh(c.main, 1.12), M.Metal)
		add(l, V(1.2, 0.2, 1.3), CF(0, -0.38, -0.06), sh(c.main, 0.9), M.Metal)
		add(l, V(1.24, 0.04, 1.32), CF(0, -0.28, -0.06), c.trim, M.Metal)
	end
end

function STYLE.footwraps(P, add, c, rare)
	local cloth = c.main
	for _, l in { P.rl, P.ll } do
		for i = 0, 4 do
			add(l, V(1.12 + (i % 2) * 0.02, 0.16, 1.14 + (i % 2) * 0.02), CF(0, -0.9 + i * 0.16, -0.02) * ANG(if i % 2 == 0 then 0.18 else -0.18, 0, 0), if i % 2 == 0 then cloth else sh(cloth, 0.85), M.Fabric)
		end
		add(l, V(1.1, 0.14, 1.28), CF(0, -0.94, -0.1), rgb(60, 46, 36), M.Leather)
		add(l, V(0.14, 0.3, 0.04), CF(0.35, -0.3, 0.6) * ANG(-0.2, 0, 0.3), sh(cloth, 0.8), M.Fabric)
	end
end

-- cloaks ------------------------------------------------------------------
-- A cape with folds: a main panel plus alternating fold strips behind it.
local function capeParts(P, add, col, mat, len, width, tatter)
	local t = P.torso
	add(t, V(width, 0.3, 1.34), CF(0, 1.04, 0.04), sh(col, 1.05), mat)
	if tatter then
		for i = -1, 1 do
			local l = len * (0.85 + ((i + 2) % 3) * 0.1)
			add(t, V(width / 3 + 0.02, l, 0.12), CF(i * width / 3, 0.95 - l / 2, 0.62) * ANG(0.1, 0, i * 0.02), col, mat)
			tri(add, t, CF(i * width / 3, 0.95 - l, 0.62) * ANG(0.1, 0, 0), -width / 6, width / 6, (i % 2) * 0.1, -0.35, 0.1, col, mat)
		end
	else
		add(t, V(width, len, 0.14), CF(0, 0.95 - len / 2, 0.64) * ANG(0.1, 0, 0), col, mat)
	end
	-- folds
	for i = -1, 1 do
		local x = i * width * 0.28
		local l = len * (if tatter then 0.7 else 0.94)
		add(t, V(0.2, l, 0.08), CF(x, 0.9 - l / 2, 0.72) * ANG(0.1, 0, 0), sh(col, if i == 0 then 0.84 else 0.9), mat)
	end
	-- the hem
	if not tatter then
		add(t, V(width + 0.04, 0.12, 0.18), CF(0, 0.95 - len + 0.08, 0.64 + len * 0.1) * ANG(0.1, 0, 0), sh(col, 0.75), mat)
	end
end

local function clasp(add, P, c, rare)
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.24, 0.24, 0.08), CF(sx * 0.62, 0.85, -0.62) * ANG(0, 0, PI / 4), c.trim, M.Metal)
	end
	add(P.torso, V(1.1, 0.05, 0.04), CF(0, 0.85, -0.64), c.trim, M.Metal)
	if rare >= 4 then
		add(P.torso, V(0.12, 0.12, 0.04), CF(0.62, 0.85, -0.67) * ANG(0, 0, PI / 4), c.accent, M.Neon)
	end
end

function STYLE.cloak(P, add, c, rare)
	capeParts(P, add, c.main, M.Fabric, 3.1, 2.1)
	add(P.torso, V(1.3, 0.5, 0.42), CF(0, 0.9, 0.82), sh(c.main, 0.9), M.Fabric)
	clasp(add, P, c, rare)
end

function STYLE.furcloak(P, add, c, rare)
	capeParts(P, add, c.main, M.Fabric, 3.0, 2.2)
	add(P.torso, V(2.6, 0.6, 1.6), CF(0, 0.95, 0.08), sh(c.main, 1.1), M.Fabric)
	for i = -2, 2 do
		add(P.torso, V(0.4, 0.34, 0.34), CF(i * 0.52, 0.72, 0.84) * ANG(-0.3, 0, i * 0.3), sh(c.main, 1.0 + (i % 2) * 0.1), M.Fabric)
	end
	clasp(add, P, c, rare)
end

function STYLE.scoutcloak(P, add, c, rare)
	capeParts(P, add, c.main, M.Fabric, 2.9, 2.2)
	-- hood resting on the back
	add(P.torso, V(1.3, 0.55, 0.45), CF(0, 0.92, 0.84), sh(c.main, 0.9), M.Fabric)
	-- crest: two crossed bars (not any real emblem)
	add(P.torso, V(0.12, 0.8, 0.02), CF(0.02, -0.25, 0.8) * ANG(0.1, 0, 0.6), rgb(236, 232, 222), M.Fabric)
	add(P.torso, V(0.12, 0.8, 0.02), CF(-0.02, -0.25, 0.81) * ANG(0.1, 0, -0.6), c.accent, M.Fabric)
	add(P.torso, V(0.22, 0.22, 0.08), CF(0, 0.92, -0.62), c.trim, M.Metal)
end

function STYLE.royalcloak(P, add, c, rare)
	capeParts(P, add, c.accent, M.Fabric, 3.4, 2.3)
	add(P.torso, V(2.6, 0.5, 1.6), CF(0, 0.98, 0.06), rgb(245, 244, 238), M.Fabric)
	-- ermine spots
	for i = -2, 2 do
		add(P.torso, V(0.1, 0.16, 0.04), CF(i * 0.45, 0.98, -0.82), rgb(20, 20, 20), M.Fabric)
		add(P.torso, V(0.1, 0.16, 0.04), CF(i * 0.45 + 0.2, 0.98, 0.88), rgb(20, 20, 20), M.Fabric)
	end
	add(P.torso, V(2.34, 0.12, 0.16), CF(0, 0.95 - 3.4 + 0.1, 0.64 + 0.36), c.trim, M.Metal)
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.1, 3.2, 0.1), CF(sx * 1.12, 0.95 - 1.6, 0.66 + 0.16) * ANG(0.1, 0, 0), c.trim, M.Metal)
	end
	clasp(add, P, c, rare)
end

function STYLE.shadowcloak(P, add, c, rare)
	capeParts(P, add, c.main, M.Fabric, 3.3, 2.2, true)
	add(P.torso, V(1.2, 0.5, 0.4), CF(0, 0.92, 0.82), sh(c.main, 0.8), M.Fabric)
	if rare >= 4 then
		add(P.torso, V(2.24, 0.06, 0.16), CF(0, 1.18, 0.62), c.accent, M.Neon)
	end
end

function STYLE.shroud(P, add, c, rare)
	-- long ragged burial shroud with a deep hood fallen back
	local col = c.main
	capeParts(P, add, col, M.Fabric, 3.9, 2.3, true)
	add(P.torso, V(2.5, 0.6, 1.5), CF(0, 0.92, 0.06), sh(col, 0.9), M.Fabric)
	add(P.torso, V(1.4, 0.8, 0.5), CF(0, 0.8, 0.86) * ANG(0.2, 0, 0), sh(col, 0.8), M.Fabric)
	-- loose strips hanging at the front
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.3, 1.4, 0.08), CF(sx * 0.9, 0.2, -0.66) * ANG(0, 0, sx * 0.05), sh(col, 0.92), M.Fabric)
		tri(add, P.torso, CF(sx * 0.9, -0.5, -0.66), -0.15, 0.15, 0, -0.3, 0.07, sh(col, 0.92), M.Fabric)
	end
	if rare >= 4 then
		for i = -1, 1 do
			add(P.torso, V(0.06, 0.6, 0.03), CF(i * 0.7, -1.2, 0.74) * ANG(0.1, 0, 0), c.accent, M.Neon)
		end
	end
end

function STYLE.pilgrim(P, add, c, rare)
	-- short shoulder cape (capelet) with a hood and a scallop badge
	local col = c.main
	add(P.torso, V(2.5, 0.7, 1.56), CF(0, 0.85, 0.04), col, M.Fabric)
	add(P.torso, V(2.56, 0.1, 1.6), CF(0, 0.5, 0.04), sh(col, 0.75), M.Fabric)
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.5, 0.5, 1.58), CF(sx * 1.08, 0.72, 0.04) * ANG(0, 0, sx * 0.4), sh(col, 0.92), M.Fabric)
	end
	add(P.torso, V(1.3, 0.6, 0.46), CF(0, 0.92, 0.84), sh(col, 0.88), M.Fabric)
	-- scallop shell
	add(P.torso, V(0.32, 0.3, 0.06), CF(0.5, 0.7, -0.82), rgb(236, 226, 200), M.Marble)
	for i = -1, 1 do
		add(P.torso, V(0.03, 0.26, 0.04), CF(0.5 + i * 0.09, 0.7, -0.855) * ANG(0, 0, -i * 0.3), rgb(190, 176, 150), M.Marble)
	end
	-- cord and a gourd at the hip
	add(P.torso, V(0.06, 1.6, 0.06), CF(-0.5, 0.0, -0.64) * ANG(0, 0, -0.5), c.trim, M.Fabric)
	add(P.torso, V(0.28, 0.36, 0.28), CF(-1.12, -0.7, -0.2), rgb(170, 120, 60), M.Wood)
	add(P.torso, V(0.18, 0.18, 0.18), CF(-1.12, -0.44, -0.2), rgb(150, 104, 52), M.Wood)
	if rare >= 4 then
		add(P.torso, V(0.12, 0.12, 0.04), CF(0.5, 0.7, -0.87), c.accent, M.Neon)
	end
end

-- shields (worn on the outside of the left forearm, face pointing -X) ------
local SHIELD_CF = CF(-0.68, -0.35, -0.1)
local function boss(add, P, c, cf, size, spike)
	add(P.la, V(size * 0.5, size, size), cf * CF(-0.1, 0, 0), sh(c.trim, 1.1), M.Metal, CYL)
	add(P.la, V(size * 0.7, size * 0.7, size * 0.7), cf * CF(-0.18, 0, 0), sh(c.trim, 1.2), M.Metal, BALL)
	if spike then
		tri(add, P.la, cf * CF(-0.4, 0, 0) * ANG(0, 0, PI / 2), -size * 0.2, size * 0.2, 0, size * 0.8, size * 0.2, sh(c.trim, 1.25), M.Metal)
		tri(add, P.la, cf * CF(-0.4, 0, 0) * ANG(0, 0, PI / 2) * ANG(0, PI / 2, 0), -size * 0.2, size * 0.2, 0, size * 0.8, size * 0.2, sh(c.trim, 1.1), M.Metal)
	end
end

function STYLE.buckler(P, add, c, rare)
	add(P.la, V(0.2, 1.8, 1.8), SHIELD_CF, c.main, M.Metal, CYL)
	add(P.la, V(0.22, 1.9, 1.9), SHIELD_CF * CF(0.04, 0, 0), c.trim, M.Metal, CYL)
	add(P.la, V(0.22, 1.2, 1.2), SHIELD_CF * CF(-0.03, 0, 0), sh(c.main, 0.86), M.Metal, CYL)
	for i = 0, 5 do
		add(P.la, V(0.08, 0.08, 0.08), SHIELD_CF * CF(-0.1, 0, 0) * ANG(i * PI / 3, 0, 0) * CF(0, 0.78, 0), sh(c.trim, 1.2), M.Metal)
	end
	boss(add, P, c, SHIELD_CF, 0.6, rare >= 3)
end

function STYLE.spiked(P, add, c, rare)
	add(P.la, V(0.2, 1.9, 1.9), SHIELD_CF, sh(c.main, 0.7), M.Metal, CYL)
	add(P.la, V(0.22, 2.0, 2.0), SHIELD_CF * CF(0.04, 0, 0), c.trim, M.Metal, CYL)
	for i = 0, 5 do
		local cf = SHIELD_CF * ANG(i * PI / 3, 0, 0) * CF(-0.12, 0.72, 0)
		tri(add, P.la, cf * ANG(0, 0, PI / 2), -0.1, 0.1, 0, 0.36, 0.1, sh(c.main, 1.1), M.Metal)
	end
	boss(add, P, c, SHIELD_CF, 0.7, true)
	if rare >= 4 then
		add(P.la, V(0.23, 1.3, 1.3), SHIELD_CF * CF(-0.02, 0, 0), c.accent, M.Neon, CYL)
		add(P.la, V(0.24, 1.2, 1.2), SHIELD_CF * CF(-0.03, 0, 0), sh(c.main, 0.7), M.Metal, CYL)
	end
end

function STYLE.round(P, add, c, rare)
	add(P.la, V(0.22, 3.3, 3.3), SHIELD_CF * CF(0.02, 0, 0), c.trim, M.Metal, CYL)
	add(P.la, V(0.2, 3.1, 3.1), SHIELD_CF * CF(-0.02, 0, 0), c.main, M.WoodPlanks, CYL)
	-- painted halves / cross (Norse style)
	add(P.la, V(0.03, 3.0, 0.5), SHIELD_CF * CF(-0.13, 0, 0), c.accent, M.WoodPlanks)
	add(P.la, V(0.03, 0.5, 3.0), SHIELD_CF * CF(-0.13, 0, 0), c.accent, M.WoodPlanks)
	for i = 0, 7 do
		add(P.la, V(0.08, 0.1, 0.1), SHIELD_CF * CF(-0.12, 0, 0) * ANG(i * PI / 4 + PI / 8, 0, 0) * CF(0, 1.46, 0), sh(c.trim, 1.2), M.Metal)
	end
	boss(add, P, c, SHIELD_CF, 0.8, rare >= 5)
	if rare >= 4 then
		rune(add, P.la, SHIELD_CF * CF(-0.15, 0.9, 0.9) * ANG(0, PI / 2, 0), c, rare, 0.3)
	end
end

local function heraldry(add, P, cf: CFrame, c, rare: number, w: number, hgt: number)
	local pick = (rare + math.floor(w * 10)) % 3
	local col, mat = c.accent, M.Metal
	if pick == 0 then
		add(P.la, V(0.03, hgt, w * 0.24), cf, col, mat)
		add(P.la, V(0.03, w * 0.24, w * 0.9), cf * CF(0, hgt * 0.18, 0), col, mat)
	elseif pick == 1 then
		add(P.la, V(0.03, w * 0.22, w * 0.72), cf * CF(0, 0, w * 0.2) * ANG(0.7, 0, 0), col, mat)
		add(P.la, V(0.03, w * 0.22, w * 0.72), cf * CF(0, 0, -w * 0.2) * ANG(-0.7, 0, 0), col, mat)
	else
		add(P.la, V(0.03, hgt, w * 0.34), cf, col, mat)
		add(P.la, V(0.04, w * 0.26, w * 0.26), cf * CF(-0.01, hgt * 0.1, 0) * ANG(PI / 4, 0, 0), c.trim, M.Metal)
	end
end

function STYLE.kite(P, add, c, rare)
	local s = SHIELD_CF * CF(0, -0.1, 0)
	add(P.la, V(0.22, 2.2, 2.1), s * CF(0.02, 0.5, 0), c.trim, M.Metal)
	add(P.la, V(0.2, 2.1, 1.95), s * CF(0, 0.5, 0), c.main, M.Metal)
	-- pointed lower half: a square turned 45 degrees
	add(P.la, V(0.22, 1.5, 1.5), s * CF(0.02, -0.55, 0) * ANG(PI / 4, 0, 0), c.trim, M.Metal)
	add(P.la, V(0.2, 1.38, 1.38), s * CF(0, -0.55, 0) * ANG(PI / 4, 0, 0), c.main, M.Metal)
	heraldry(add, P, s * CF(-0.12, 0.2, 0), c, rare, 1.8, 2.6)
	rivets(add, P.la, (s * CF(-0.12, 1.5, -0.8)).Position, (s * CF(-0.12, 1.5, 0.8)).Position, 4, 0.08, sh(c.trim, 1.2))
	boss(add, P, c, s * CF(0, 0.3, 0), 0.4, false)
end

function STYLE.heater(P, add, c, rare)
	local s = SHIELD_CF * CF(0, 0.05, 0)
	add(P.la, V(0.22, 1.5, 2.2), s * CF(0.02, 0.45, 0), c.trim, M.Metal)
	add(P.la, V(0.2, 1.42, 2.06), s * CF(0, 0.47, 0), c.main, M.WoodPlanks)
	-- curved lower half toward a point, stepped
	for i = 0, 2 do
		local w = 2.2 - i * 0.5
		add(P.la, V(0.22, 0.34, w), s * CF(0.02, -0.46 - i * 0.3, 0), c.trim, M.Metal)
		add(P.la, V(0.2, 0.36, w - 0.14), s * CF(0, -0.44 - i * 0.3, 0), c.main, M.WoodPlanks)
	end
	tri(add, P.la, s * CF(0.01, -1.2, 0) * ANG(0, PI / 2, 0), -0.35, 0.35, 0, -0.4, 0.22, c.trim, M.Metal)
	-- painted heraldry: a chief band and a charge
	add(P.la, V(0.03, 0.4, 2.0), s * CF(-0.12, 1.0, 0), c.accent, M.WoodPlanks)
	heraldry(add, P, s * CF(-0.12, -0.1, 0), c, rare + 1, 1.2, 1.4)
	if rare >= 5 then
		for _, sz in { 1, -1 } do
			tri(add, P.la, s * CF(0, 1.2, sz * 1.05) * ANG(0, PI / 2, 0), -0.14, 0.14, 0, 0.36, 0.1, c.trim, M.Metal)
		end
	end
end

function STYLE.tower(P, add, c, rare)
	local s = SHIELD_CF * CF(0, -0.2, 0)
	add(P.la, V(0.26, 3.8, 2.3), s, c.main, M.Metal)
	add(P.la, V(0.28, 3.9, 0.16), s * CF(0.02, 0, 1.15), c.trim, M.Metal)
	add(P.la, V(0.28, 3.9, 0.16), s * CF(0.02, 0, -1.15), c.trim, M.Metal)
	add(P.la, V(0.28, 0.16, 2.4), s * CF(0.02, 1.9, 0), c.trim, M.Metal)
	add(P.la, V(0.28, 0.16, 2.4), s * CF(0.02, -1.9, 0), c.trim, M.Metal)
	add(P.la, V(0.3, 0.14, 2.3), s * CF(0.02, 0.6, 0), c.trim, M.Metal)
	add(P.la, V(0.3, 0.14, 2.3), s * CF(0.02, -0.8, 0), c.trim, M.Metal)
	-- view slot near the top
	add(P.la, V(0.3, 0.1, 0.8), s * CF(0.01, 1.4, 0), DARK, M.Metal)
	add(P.la, V(0.06, 0.9, 0.9), s * CF(-0.15, -0.1, 0) * ANG(PI / 4, 0, 0), c.accent, M.Metal)
	rivets(add, P.la, (s * CF(-0.15, 1.8, -1.0)).Position, (s * CF(-0.15, -1.8, -1.0)).Position, 5, 0.08, sh(c.trim, 1.2))
	rivets(add, P.la, (s * CF(-0.15, 1.8, 1.0)).Position, (s * CF(-0.15, -1.8, 1.0)).Position, 5, 0.08, sh(c.trim, 1.2))
	rune(add, P.la, s * CF(-0.19, -0.1, 0) * ANG(0, PI / 2, 0), c, rare, 0.4)
end

function STYLE.pavise(P, add, c, rare)
	local s = SHIELD_CF * CF(0, -0.1, 0)
	add(P.la, V(0.24, 3.4, 2.0), s, c.main, M.WoodPlanks)
	-- the central canal (raised ridge)
	add(P.la, V(0.3, 3.3, 0.5), s * CF(-0.05, 0, 0), sh(c.main, 1.1), M.WoodPlanks)
	add(P.la, V(0.26, 3.5, 2.1), s * CF(0.03, 0, 0), c.trim, M.Metal)
	-- painted bands and a charge on the canal
	add(P.la, V(0.03, 0.5, 2.0), s * CF(-0.13, 1.2, 0), c.accent, M.WoodPlanks)
	add(P.la, V(0.03, 0.5, 2.0), s * CF(-0.13, -1.2, 0), c.accent, M.WoodPlanks)
	add(P.la, V(0.04, 0.4, 0.4), s * CF(-0.21, 0.1, 0) * ANG(PI / 4, 0, 0), c.accent, M.Metal)
	-- feet at the bottom
	for _, sz in { 1, -1 } do
		add(P.la, V(0.3, 0.3, 0.2), s * CF(0.02, -1.8, sz * 0.8), c.trim, M.Metal)
	end
	rivets(add, P.la, (s * CF(-0.15, 1.6, -0.9)).Position, (s * CF(-0.15, 1.6, 0.9)).Position, 4, 0.08, sh(c.trim, 1.2))
	rune(add, P.la, s * CF(-0.23, 0.9, 0) * ANG(0, PI / 2, 0), c, rare, 0.3)
end

-- trinkets ---------------------------------------------------------------
-- A chain of small links around the neck down to a pendant at the chest.
local function chain(P, add, col, y: number)
	-- links follow a curve from the collar down to the pendant
	local pts = { V(0.46, 1.0, -0.6), V(0.36, 0.8, -0.63), V(0.22, 0.64, -0.635), V(0.08, y + 0.2, -0.635) }
	for _, sx in { 1, -1 } do
		for i = 1, #pts - 1 do
			local a, b = pts[i] * V(sx, 1, 1), pts[i + 1] * V(sx, 1, 1)
			local d = b - a
			local ang = math.atan2(-d.X, d.Y)
			add(P.torso, V(if i % 2 == 0 then 0.05 else 0.07, d.Magnitude + 0.03, if i % 2 == 0 then 0.07 else 0.04), CF((a + b) / 2) * ANG(0, 0, ang), if i % 2 == 0 then col else sh(col, 0.8), M.Metal)
		end
	end
	add(P.torso, V(1.0, 0.06, 0.06), CF(0, 0.99, 0.1), col, M.Metal)
	add(P.torso, V(0.12, 0.08, 0.06), CF(0, y + 0.2, -0.635), sh(col, 0.9), M.Metal)
end

function STYLE.charm(P, add, c, rare)
	add(P.torso, V(0.05, 0.62, 0.05), CF(0.26, 0.72, -0.62) * ANG(0, 0, 0.6), rgb(60, 50, 40), M.Leather)
	add(P.torso, V(0.05, 0.62, 0.05), CF(-0.26, 0.72, -0.62) * ANG(0, 0, -0.6), rgb(60, 50, 40), M.Leather)
	-- a knucklebone charm with beads
	add(P.torso, V(0.12, 0.34, 0.1), CF(0, 0.34, -0.64), c.main, M.Marble)
	for _, y in { 0.2, 0.48 } do
		add(P.torso, V(0.24, 0.1, 0.12), CF(0, y, -0.64), c.main, M.Marble)
	end
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.08, 0.08, 0.08), CF(sx * 0.12, 0.56, -0.64), c.accent, M.Glass)
	end
end

function STYLE.runestone(P, add, c, rare)
	chain(P, add, rgb(80, 70, 60), 0.4)
	add(P.torso, V(0.34, 0.4, 0.1), CF(0, 0.32, -0.62) * ANG(0, 0, 0.1), rgb(104, 104, 112), M.Slate)
	add(P.torso, V(0.36, 0.05, 0.12), CF(0, 0.42, -0.62), c.main, M.Metal)
	add(P.torso, V(0.05, 0.42, 0.12), CF(0.08, 0.32, -0.62) * ANG(0, 0, 0.1), c.main, M.Metal)
	add(P.torso, V(0.06, 0.22, 0.02), CF(-0.04, 0.3, -0.68), rgb(120, 220, 255), M.Neon)
	add(P.torso, V(0.12, 0.05, 0.02), CF(-0.02, 0.36, -0.68) * ANG(0, 0, 0.5), rgb(120, 220, 255), M.Neon)
end

function STYLE.hourglass(P, add, c, rare)
	chain(P, add, c.main, 0.44)
	local g = c.main
	add(P.torso, V(0.34, 0.06, 0.14), CF(0, 0.58, -0.62), g, M.Metal)
	add(P.torso, V(0.34, 0.06, 0.14), CF(0, 0.22, -0.62), g, M.Metal)
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.04, 0.34, 0.04), CF(sx * 0.14, 0.4, -0.66), sh(g, 0.8), M.Metal)
	end
	add(P.torso, V(0.2, 0.14, 0.1), CF(0, 0.49, -0.62) * ANG(0, 0, PI / 4), rgb(190, 200, 230), M.Glass)
	add(P.torso, V(0.2, 0.14, 0.1), CF(0, 0.31, -0.62) * ANG(0, 0, PI / 4), rgb(190, 200, 230), M.Glass)
	add(P.torso, V(0.12, 0.08, 0.08), CF(0, 0.29, -0.62), rgb(190, 170, 255), M.Neon)
end

function STYLE.heart(P, add, c, rare)
	chain(P, add, c.main, 0.44)
	add(P.torso, V(0.24, 0.24, 0.12), CF(0, 0.38, -0.62) * ANG(0, 0, PI / 4), rgb(200, 16, 36), M.Neon)
	for _, sx in { 1, -1 } do
		add(P.torso, V(0.16, 0.16, 0.12), CF(sx * 0.08, 0.46, -0.62) * ANG(0, 0, PI / 4), rgb(180, 12, 30), M.Glass)
		add(P.torso, V(0.04, 0.34, 0.04), CF(sx * 0.12, 0.38, -0.69) * ANG(0, 0, sx * 0.3), c.main, M.Metal)
	end
	add(P.torso, V(0.3, 0.04, 0.04), CF(0, 0.38, -0.69), c.main, M.Metal)
end

function STYLE.rosary(P, add, c, rare)
	-- beads on a cord down to a cross
	chain(P, add, rgb(90, 70, 50), 0.42)
	for _, sx in { 1, -1 } do
		for i = 0, 3 do
			local t = i / 3
			add(P.torso, V(0.09, 0.09, 0.09), CF(sx * (0.1 + 0.36 * t), 0.62 + t * 0.36, -0.645), c.main, M.Wood)
		end
	end
	add(P.torso, V(0.06, 0.4, 0.05), CF(0, 0.26, -0.63), c.trim, M.Metal)
	add(P.torso, V(0.24, 0.06, 0.05), CF(0, 0.34, -0.63), c.trim, M.Metal)
	if rare >= 3 then
		add(P.torso, V(0.06, 0.06, 0.03), CF(0, 0.34, -0.665), c.accent, if rare >= 4 then M.Neon else M.Glass)
	end
end

function STYLE.teeth(P, add, c, rare)
	add(P.torso, V(0.05, 0.62, 0.05), CF(0.3, 0.72, -0.62) * ANG(0, 0, 0.7), rgb(70, 50, 36), M.Leather)
	add(P.torso, V(0.05, 0.62, 0.05), CF(-0.3, 0.72, -0.62) * ANG(0, 0, -0.7), rgb(70, 50, 36), M.Leather)
	for i = -2, 2 do
		local x = i * 0.13
		tri(add, P.torso, CF(x, 0.54 - math.abs(i) * 0.04, -0.63) * ANG(0, 0, i * 0.12), -0.05, 0.05, 0, -0.24 + math.abs(i) * 0.03, 0.06, BONE, M.Marble)
		add(P.torso, V(0.06, 0.06, 0.06), CF(x, 0.56 - math.abs(i) * 0.04, -0.63), sh(rgb(70, 50, 36), 1.2), M.Wood)
	end
	if rare >= 4 then
		add(P.torso, V(0.06, 0.06, 0.04), CF(0, 0.4, -0.67), c.accent, M.Neon)
	end
end

function STYLE.eye(P, add, c, rare)
	chain(P, add, rgb(40, 34, 38), 0.44)
	-- a staring eye set in black iron, spines around it
	add(P.torso, V(0.44, 0.3, 0.1), CF(0, 0.36, -0.62), rgb(30, 26, 30), M.Metal)
	add(P.torso, V(0.34, 0.2, 0.1), CF(0, 0.36, -0.64), rgb(230, 220, 210), M.Marble)
	local iris = add(P.torso, V(0.14, 0.14, 0.1), CF(0, 0.36, -0.66), c.accent, M.Neon)
	add(P.torso, V(0.05, 0.12, 0.06), CF(0, 0.36, -0.7), DARK, M.Metal)
	for i = 0, 5 do
		local a = i * PI / 3
		add(P.torso, V(0.04, 0.16, 0.04), CF(0, 0.36, -0.62) * ANG(0, 0, a) * CF(0, 0.26, 0), rgb(40, 34, 38), M.Metal)
	end
	local e = Instance.new("PointLight")
	e.Color = c.accent
	e.Range = 5
	e.Brightness = 0.6
	e.Shadows = false
	e.Parent = iris
end

-- rings: a small object worn on the right fist
local RING_CF = CF(0.1, -0.86, -0.54)
local function band(P, add, col, mat)
	add(P.ra, V(0.46, 0.1, 0.06), RING_CF, col, mat or M.Metal)
	add(P.ra, V(0.06, 0.1, 0.4), RING_CF * CF(0.26, 0, 0.2), col, mat or M.Metal)
	add(P.ra, V(0.06, 0.1, 0.4), RING_CF * CF(-0.26, 0, 0.2), col, mat or M.Metal)
end

function STYLE.ring(P, add, c, rare)
	band(P, add, c.main)
	add(P.ra, V(0.1, 0.06, 0.04), RING_CF * CF(0.1, 0, -0.04), sh(c.main, 0.7), M.Metal)
	add(P.ra, V(0.1, 0.06, 0.04), RING_CF * CF(-0.12, 0, -0.04), sh(c.main, 0.7), M.Metal)
end

function STYLE.gemring(P, add, c, rare)
	band(P, add, c.main)
	add(P.ra, V(0.2, 0.14, 0.1), RING_CF * CF(0, 0, -0.06), sh(c.main, 0.85), M.Metal)
	add(P.ra, V(0.14, 0.14, 0.12), RING_CF * CF(0, 0, -0.1) * ANG(0, 0, PI / 4), c.accent, if rare >= 4 then M.Neon else M.Glass)
end

function STYLE.signet(P, add, c, rare)
	band(P, add, c.main)
	add(P.ra, V(0.26, 0.2, 0.08), RING_CF * CF(0, 0, -0.06), c.main, M.Metal)
	add(P.ra, V(0.18, 0.12, 0.03), RING_CF * CF(0, 0, -0.105), sh(c.main, 0.6), M.Metal)
	add(P.ra, V(0.04, 0.1, 0.03), RING_CF * CF(0, 0, -0.12), c.main, M.Metal)
end

function STYLE.chronoring(P, add, c, rare)
	band(P, add, c.main)
	add(P.ra, V(0.18, 0.04, 0.1), RING_CF * CF(0, 0.1, -0.08), c.main, M.Metal)
	add(P.ra, V(0.18, 0.04, 0.1), RING_CF * CF(0, -0.1, -0.08), c.main, M.Metal)
	add(P.ra, V(0.1, 0.1, 0.08), RING_CF * CF(0, 0.03, -0.08) * ANG(0, 0, PI / 4), rgb(190, 170, 255), M.Neon)
	add(P.ra, V(0.1, 0.1, 0.08), RING_CF * CF(0, -0.05, -0.08) * ANG(0, 0, PI / 4), rgb(200, 205, 230), M.Glass)
end

function STYLE.bloodring(P, add, c, rare)
	band(P, add, c.main)
	add(P.ra, V(0.16, 0.16, 0.12), RING_CF * CF(0, 0, -0.08) * ANG(0, 0, PI / 4), rgb(190, 12, 30), M.Neon)
	for _, a in { 0, PI / 2, PI, PI * 1.5 } do
		add(P.ra, V(0.03, 0.14, 0.03), RING_CF * CF(0, 0, -0.08) * ANG(0, 0, a + PI / 4) * CF(0, 0.14, 0), c.main, M.Metal)
	end
end

function STYLE.emberring(P, add, c, rare)
	band(P, add, rgb(50, 44, 42))
	add(P.ra, V(0.22, 0.16, 0.1), RING_CF * CF(0, 0, -0.06), rgb(40, 34, 32), M.Basalt)
	local coal = add(P.ra, V(0.14, 0.12, 0.1), RING_CF * CF(0, 0.02, -0.1) * ANG(0.2, 0.3, 0.2), rgb(255, 120, 30), M.Neon)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(rgb(255, 170, 60), rgb(255, 80, 20))
	e.LightEmission = 1
	e.Rate = 4
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
	e.Acceleration = V(0, 2, 0)
	e.Parent = coal
end

function STYLE.serpent(P, add, c, rare)
	-- a snake coiled twice round the finger, head raised
	for i = 0, 1 do
		add(P.ra, V(0.46, 0.06, 0.06), RING_CF * CF(0, -0.04 + i * 0.08, 0) * ANG(0, 0, (i - 0.5) * 0.25), c.main, M.Metal)
	end
	add(P.ra, V(0.06, 0.1, 0.4), RING_CF * CF(0.26, 0, 0.2), c.main, M.Metal)
	add(P.ra, V(0.06, 0.1, 0.4), RING_CF * CF(-0.26, 0, 0.2), c.main, M.Metal)
	add(P.ra, V(0.12, 0.08, 0.14), RING_CF * CF(0.2, 0.08, -0.06) * ANG(0, 0.4, 0.3), sh(c.main, 1.1), M.Metal)
	add(P.ra, V(0.03, 0.03, 0.03), RING_CF * CF(0.2, 0.12, -0.13), c.accent, M.Neon)
end

-- ------------------------------------------------------------------ apply
local function limbs(model: Model)
	return {
		head = model:FindFirstChild("Head"),
		torso = model:FindFirstChild("Torso"),
		ra = model:FindFirstChild("Right Arm"),
		la = model:FindFirstChild("Left Arm"),
		rl = model:FindFirstChild("Right Leg"),
		ll = model:FindFirstChild("Left Leg"),
	}
end

-- Removes previously applied gear and shows the hair again.
function Gear.clear(model: Model)
	local f = model:FindFirstChild("Gear")
	if f then
		f:Destroy()
	end
	local head = model:FindFirstChild("Head")
	if head then
		for _, d in head:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Hair" and d:GetAttribute("HiddenByGear") then
				d.Transparency = 0
				d:SetAttribute("HiddenByGear", nil)
			end
		end
	end
end

-- gear: { [slot] = item | baseId } (weapon excluded). Safe to call again to refresh.
function Gear.apply(model: Model, gear)
	Gear.clear(model)
	if not gear then
		return
	end
	local P = limbs(model)
	if not P.torso or not P.head then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gear"
	folder.Parent = model
	local s = 1
	pcall(function()
		s = model:GetScale()
	end)
	local hide = false
	local topRare = 0
	for _, slot in Gear.SLOTS do
		local r = resolve(gear[slot])
		if r then
			local fn = STYLE[r.base.style]
			if fn then
				local fam = MATS[r.base.mats] or MATS.cloth
				local col = {
					main = c3(r.colors.main, fam.main[1]),
					second = c3(r.colors.second, Palette.shade(fam.main[1], 0.75)),
					trim = c3(r.colors.trim, rgb(70, 48, 32)),
					accent = c3(r.colors.accent, rgb(170, 30, 36)),
					mat = fam.mat,
				}
				local rare = table.find(Gear.RARITIES, r.item.rarity or "Common") or 1
				local ok, err = pcall(fn, P, makeAdder(folder, s, slot), col, rare)
				if not ok then
					warn("[Gear] " .. tostring(r.base.style) .. ": " .. tostring(err))
				end
				if r.base.hideHair then
					hide = true
				end
				if slot ~= "Ring" and slot ~= "Amulet" then
					topRare = math.max(topRare, rare)
				end
			end
		end
	end
	if hide then
		for _, d in P.head:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Hair" and d.Transparency < 1 then
				d.Transparency = 1
				d:SetAttribute("HiddenByGear", true)
			end
		end
	end
	-- divine gear glimmers
	if topRare >= 6 and not P.torso:FindFirstChild("DivineGlow") then
		local e = Instance.new("ParticleEmitter")
		e.Name = "DivineGlow"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(rgb(255, 240, 180))
		e.LightEmission = 1
		e.Rate = 6
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.3, 1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.2, 1)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = folder:FindFirstChildWhichIsA("BasePart") or P.torso
	end
end

-- Colours the first-person arms should use.
function Gear.viewColors(gear)
	local out = {}
	local ch = resolve(gear and gear.Chest)
	if ch then
		local fam = MATS[ch.base.mats] or MATS.cloth
		local main = c3(ch.colors.main, fam.main[1])
		local st = ch.base.style
		if st == "scoutjacket" or st == "tunic" or st == "gambeson" or st == "robe" or st == "jerkin" or st == "lamellar" or st == "cuirass" or st == "gothic" or st == "scale" then
			out.sleeve, out.sleeveMat = main, fam.mat
		elseif st == "hauberk" or st == "surcoat" then
			out.sleeve, out.sleeveMat = if st == "surcoat" then rgb(150, 154, 162) else main, M.DiamondPlate
		elseif st == "furmantle" or st == "brigandine" then
			out.sleeve, out.sleeveMat = c3(ch.colors.second, main), M.Fabric
		elseif st == "bonemail" then
			out.sleeve, out.sleeveMat = Palette.shade(main, 0.8), M.Leather
		end
	end
	local hd = resolve(gear and gear.Hands)
	if hd then
		local fam = MATS[hd.base.mats] or MATS.cloth
		out.glove = c3(hd.colors.main, fam.main[1])
		local st = hd.base.style
		out.gloveMat = if st == "mitts" then M.DiamondPlate elseif st == "gauntlets" or st == "claws" then M.Metal elseif st == "handwraps" then M.Fabric else fam.mat
		if st == "claws" then
			out.glove = Palette.shade(out.glove, 0.55)
		end
		out.bracer = st == "bracers" or st == "gauntlets" or st == "claws"
	end
	return out
end

-- A small stand-alone model of one piece (inventory icons / previews).
-- Builds it on an invisible mannequin so the same style code is reused.
function Gear.previewModel(item)
	local model = Instance.new("Model")
	model.Name = "GearPreview"
	local function limb(name, size, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.Transparency = 1
		p.CanCollide = false
		p.Parent = model
		return p
	end
	limb("Torso", V(2, 2, 1), CF(0, 3, 0))
	limb("Head", V(HEAD, HEAD, HEAD), CF(0, 4 + HEAD / 2, 0))
	limb("Right Arm", V(1, 2, 1), CF(1.5, 3, 0))
	limb("Left Arm", V(1, 2, 1), CF(-1.5, 3, 0))
	limb("Right Leg", V(1, 2, 1), CF(0.5, 1, 0))
	limb("Left Leg", V(1, 2, 1), CF(-0.5, 1, 0))
	local slot = item.slot or (Gear.BASES[item.base] and Gear.BASES[item.base].slot) or "Chest"
	Gear.apply(model, { [slot] = item })
	local leftArm = model:FindFirstChild("Left Arm")
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then
			-- icons show a single glove, large
			if slot == "Hands" and d.Part0 == leftArm and d.Part1 then
				d.Part1:Destroy()
			end
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- turn the piece so its best side faces the inventory camera (front-right):
	-- shields face out of the left arm, cloaks are seen from behind
	local turn = if slot == "Offhand" then -1.98 elseif slot == "Cloak" then 2.73 else 0
	if turn ~= 0 then
		local rot = CFrame.Angles(0, turn, 0)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = rot * d.CFrame
			end
		end
	end
	-- a focus point for the camera: centre of the visible parts
	local sum, n = Vector3.zero, 0
	local minP, maxP = V(1e9, 1e9, 1e9), V(-1e9, -1e9, -1e9)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			sum += d.Position
			n += 1
			minP = minP:Min(d.Position - d.Size / 2)
			maxP = maxP:Max(d.Position + d.Size / 2)
		end
	end
	local center = if n > 0 then (minP + maxP) / 2 else V(0, 3, 0)
	model:SetAttribute("Focus", center)
	model:SetAttribute("Extent", if n > 0 then (maxP - minP).Magnitude else 3)
	-- pivot around the visible piece so PivotTo / spinning centre on it
	model.WorldPivot = CFrame.new(center)
	return model
end

return Gear
