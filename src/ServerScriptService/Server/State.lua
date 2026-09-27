--!nonstrict
-- Run state (seed, chapter, flags) + per-player profiles (level, stats, inventory).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Story = require(Shared.Story)
local RNG = require(Shared.RNG)
local Weapons = require(Shared.Weapons)
local Gear = require(Shared.Gear)
local S = require(script.Parent.S)

local State = {}
State.run = nil
State.profiles = {}
State.saves = {} -- raw loaded save per player

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DATASTORE)
end)

function State.newProfile()
	return {
		level = 1,
		xp = 0,
		points = 0,
		stats = { dmg = 0, hp = 0, tsDur = 0, tsCd = 0 },
		inventory = {},
		equipped = nil,
		gold = 0,
		flasks = Config.Player.flaskCharges,
		maxFlasks = Config.Player.flaskCharges,
		abilities = { timestop = false, aetherStep = false, voidSlash = false, flameRune = false, stormWeb = false },
		blessed = false,
		kills = 0,
		deaths = 0,
		quests = {},
		look = "casual",
		equipment = {}, -- slot -> item id (armor & trinkets)
		scrap = 0, -- upgrade material from salvaging
		endings = {},
	}
end

State.INVENTORY_CAP = 90

function State.newRun(seed: number, heroName: string)
	local run = {
		seed = seed,
		bible = Story.generate(seed, heroName),
		chapter = "Prologue",
		flags = {},
		land = 1,
		deleteMode = false,
		ngPlus = 0,
		started = os.time(),
		cleared = {}, -- ids of cleared camps/dungeons per land
		waystones = {},
	}
	return run
end

function State.profile(player: Player)
	local p = State.profiles[player]
	if not p then
		p = State.newProfile()
		State.profiles[player] = p
	end
	return p
end

function State.leader(): Player?
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return (a:GetAttribute("JoinOrder") or 0) < (b:GetAttribute("JoinOrder") or 0)
	end)
	return list[1]
end

function State.flag(name: string, value: any?)
	if value ~= nil then
		State.run.flags[name] = value
	end
	return State.run and State.run.flags[name]
end

-- ------------------------------------------------------------------ derived stats
-- Sum of every equipped armour piece / trinket.
function State.gearTotals(player: Player)
	local p = State.profile(player)
	local t = {}
	for slot, id in p.equipment or {} do
		local item = State.findItem(player, id)
		if item and Gear.isGear(item) then
			for k, v in Gear.stats(item) do
				t[k] = (t[k] or 0) + v
			end
		end
	end
	return t
end

function State.derived(player: Player)
	local p = State.profile(player)
	local g = State.gearTotals(player)
	local TS = Config.TimeStop
	local dur = TS.baseDuration + p.stats.tsDur * TS.durationPerPoint + (if p.blessed then TS.blessingDuration else 0) + (g.tsDur or 0)
	local cd = TS.baseCooldown - p.stats.tsCd * TS.cooldownPerPoint
	if p.blessed then
		cd *= TS.blessingCooldownMult
	end
	cd *= 1 - math.min(g.tsCd or 0, 0.5)
	local armor = g.armor or 0
	local armorRed = math.min(0.72, armor / (armor + 30 + 8 * p.level))
	return {
		maxHp = math.floor(Config.Player.baseHealth + p.stats.hp * Config.Player.healthPerPoint + (p.level - 1) * 4 + (g.hp or 0)),
		dmgMult = (1 + p.stats.dmg * Config.Player.damagePerPoint) * (if p.blessed then 1.5 else 1) * (1 + (g.dmg or 0)),
		tsDuration = math.min(dur, TS.maxDuration),
		tsCooldown = math.max(cd, TS.minCooldown),
		armor = armor,
		armorRed = armorRed,
		crit = g.crit or 0,
		critDmg = g.critDmg or 0,
		speed = math.clamp(1 + (g.speed or 0), 0.8, 1.35),
		lifesteal = math.min(g.lifesteal or 0, 0.15),
		block = math.min(g.block or 0, 0.6),
		regen = g.regen or 0,
		xpMult = 1 + (g.xp or 0),
		goldMult = 1 + (g.gold or 0),
	}
end

-- Serializable snapshot for the client HUD / inventory.
function State.sync(player: Player)
	local p = State.profile(player)
	local d = State.derived(player)
	Net.fire(player, "Profile", {
		level = p.level,
		xp = p.xp,
		xpNext = Config.xpForLevel(p.level),
		points = p.points,
		stats = p.stats,
		inventory = p.inventory,
		equipped = p.equipped,
		equipment = p.equipment,
		scrap = p.scrap,
		gold = p.gold,
		flasks = p.flasks,
		maxFlasks = p.maxFlasks,
		abilities = p.abilities,
		blessed = p.blessed,
		derived = d,
		quests = p.quests,
		land = State.run and State.run.land or 1,
		landName = State.run and State.run.bible.lands[State.run.land].name or "",
		deleteMode = State.run and State.run.deleteMode or false,
	})
end

function State.applyStats(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local d = State.derived(player)
	if hum then
		local ratio = if hum.MaxHealth > 0 then hum.Health / hum.MaxHealth else 1
		hum.MaxHealth = d.maxHp
		hum.Health = math.clamp(ratio * d.maxHp, 1, d.maxHp)
	end
	local e = S.Entities and S.Entities.forPlayer(player)
	if e then
		e.armor = d.armorRed
		e.blockBonus = d.block
		e.regen = d.regen
	end
	State.sync(player)
end

-- ------------------------------------------------------------------ xp / items
function State.addXP(player: Player, amount: number)
	local p = State.profile(player)
	p.xp += math.floor(amount * State.derived(player).xpMult + 0.5)
	local leveled = false
	while p.level < Config.XP.maxLevel and p.xp >= Config.xpForLevel(p.level) do
		p.xp -= Config.xpForLevel(p.level)
		p.level += 1
		p.points += Config.XP.pointsPerLevel
		leveled = true
	end
	if leveled then
		Net.fire(player, "Notify", { kind = "level", text = "LEVEL UP!", sub = "Level " .. p.level .. "  ·  +" .. Config.XP.pointsPerLevel .. " stat points  [I]" })
		-- spells unlock with levels
		for key, flag in { FlameRune = "flameRune", StormWeb = "stormWeb" } do
			local cfg = Config.Abilities[key]
			if cfg and p.level >= (cfg.level or 99) and not p.abilities[flag] then
				p.abilities[flag] = true
				task.delay(1.2, function()
					Net.fire(player, "Notify", { kind = "loot", text = if key == "FlameRune" then "NEW SPELL: FLAME RUNE" else "NEW SPELL: STORM WEB", sub = "Press " .. cfg.key .. " to cast.", rarity = "Epic" })
				end)
			end
		end
		local char = player.Character
		if char and char.PrimaryPart then
			Net.fireAll("FX", "LevelUp", { pos = char.PrimaryPart.Position })
		end
		State.applyStats(player)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
	State.sync(player)
end

function State.addGold(player: Player, amount: number)
	local p = State.profile(player)
	if amount > 0 then
		amount *= State.derived(player).goldMult
	end
	p.gold += math.floor(amount)
	State.sync(player)
end

local function isEquipped(p, id: string): boolean
	if p.equipped == id then
		return true
	end
	for _, v in p.equipment or {} do
		if v == id then
			return true
		end
	end
	return false
end
State.isEquipped = function(player: Player, id: string)
	return isEquipped(State.profile(player), id)
end

local function itemScore(it): number
	if Gear.isGear(it) then
		return Gear.score(it) / 60
	end
	return Weapons.score(it)
end
State.itemScore = itemScore

function State.addItem(player: Player, item, silent: boolean?)
	local p = State.profile(player)
	p.equipment = p.equipment or {}
	table.insert(p.inventory, item)
	if #p.inventory > State.INVENTORY_CAP then
		-- salvage the weakest non-equipped, non-unique item automatically
		local worst, wi = math.huge, nil
		for i, it in p.inventory do
			if not isEquipped(p, it.id) and not it.unique and it ~= item then
				local sc = itemScore(it)
				if sc < worst then
					worst, wi = sc, i
				end
			end
		end
		if wi then
			local old = p.inventory[wi]
			table.remove(p.inventory, wi)
			p.scrap += 1
			if not silent then
				Net.fire(player, "Notify", { kind = "info", text = "Bag full", sub = "Salvaged " .. old.name })
			end
		end
	end
	if Gear.isGear(item) then
		if not p.equipment[item.slot] then
			State.equip(player, item.id)
		end
	elseif not p.equipped then
		State.equip(player, item.id)
	end
	if not silent then
		local sub = if Gear.isGear(item) then item.rarity .. " " .. Gear.SLOT_INFO[item.slot].label:lower() else item.rarity .. " " .. item.kind
		Net.fire(player, "Notify", { kind = "loot", text = item.name, sub = sub, rarity = item.rarity })
	end
	State.sync(player)
end

function State.findItem(player: Player, id: string)
	for i, it in State.profile(player).inventory do
		if it.id == id then
			return it, i
		end
	end
	return nil
end

function State.equipped(player: Player)
	local p = State.profile(player)
	if not p.equipped then
		return nil
	end
	return (State.findItem(player, p.equipped))
end

-- slot -> item for every worn armour piece / trinket
function State.equippedGear(player: Player)
	local p = State.profile(player)
	local out = {}
	for slot, id in p.equipment or {} do
		local it = State.findItem(player, id)
		if it then
			out[slot] = it
		end
	end
	return out
end

local function gearChanged(player: Player)
	if S.PlayerService and S.PlayerService.refreshGear then
		S.PlayerService.refreshGear(player)
	end
	State.applyStats(player)
end

-- Equips a weapon, or toggles an armour piece in its slot.
function State.equip(player: Player, id: string)
	local item = State.findItem(player, id)
	if not item then
		return
	end
	local p = State.profile(player)
	if Gear.isGear(item) then
		p.equipment = p.equipment or {}
		if p.equipment[item.slot] == id then
			p.equipment[item.slot] = nil
		else
			p.equipment[item.slot] = id
		end
		gearChanged(player)
		return
	end
	p.equipped = id
	if S.PlayerService then
		S.PlayerService.refreshWeapon(player)
	end
	State.sync(player)
end

function State.unequip(player: Player, slot: string)
	local p = State.profile(player)
	if p.equipment and p.equipment[slot] then
		p.equipment[slot] = nil
		gearChanged(player)
	end
end

function State.salvage(player: Player, id: string)
	local p = State.profile(player)
	if isEquipped(p, id) then
		return
	end
	local item, i = State.findItem(player, id)
	if item and not item.unique then
		table.remove(p.inventory, i)
		if Gear.isGear(item) then
			local g, sc = Gear.salvageValue(item)
			p.gold += g
			p.scrap += sc
		else
			local idx = table.find(Weapons.RARITIES, item.rarity) or 1
			p.gold += math.floor((5 + item.level * 2) * idx * idx)
			p.scrap += idx + math.floor((item.up or 0) / 2)
		end
		State.sync(player)
	end
end

-- Salvages every unequipped Common/Uncommon item in one go.
function State.salvageJunk(player: Player)
	local p = State.profile(player)
	local ids = {}
	for _, it in p.inventory do
		if not isEquipped(p, it.id) and not it.unique and (it.rarity == "Common" or it.rarity == "Uncommon") then
			table.insert(ids, it.id)
		end
	end
	for _, id in ids do
		State.salvage(player, id)
	end
	if #ids > 0 then
		Net.fire(player, "Notify", { kind = "info", text = "Salvaged " .. #ids .. " items", sub = "Scrap: " .. p.scrap })
	end
end

function State.upgradeCost(item)
	if Gear.isGear(item) then
		return Gear.upgradeCost(item)
	end
	local up = item.up or 0
	local r = table.find(Weapons.RARITIES, item.rarity) or 1
	return math.floor((40 + item.level * 12) * (up + 1) ^ 1.35 * (0.8 + r * 0.2)), 1 + up + math.floor(r / 2)
end

function State.upgrade(player: Player, id: string)
	local p = State.profile(player)
	local item = State.findItem(player, id)
	if not item then
		return
	end
	if (item.up or 0) >= Gear.MAX_UP then
		Net.fire(player, "Notify", { kind = "warn", text = "Already at +" .. Gear.MAX_UP })
		return
	end
	local gold, scrap = State.upgradeCost(item)
	if p.gold < gold or p.scrap < scrap then
		Net.fire(player, "Notify", { kind = "warn", text = "Not enough", sub = string.format("Needs %dg and %d scrap", gold, scrap) })
		return
	end
	p.gold -= gold
	p.scrap -= scrap
	item.up = (item.up or 0) + 1
	Net.fire(player, "Notify", { kind = "level", text = item.name .. " +" .. item.up, sub = "Upgraded" })
	local char = player.Character
	if char and char.PrimaryPart then
		Net.fireAll("FX", "Upgrade", { pos = char.PrimaryPart.Position, rarity = item.rarity })
	end
	if isEquipped(p, id) then
		State.applyStats(player)
	else
		State.sync(player)
	end
end

function State.allocate(player: Player, stat: string)
	local p = State.profile(player)
	if p.points <= 0 or p.stats[stat] == nil then
		return
	end
	if stat == "tsCd" then
		local d = State.derived(player)
		if d.tsCooldown <= Config.TimeStop.minCooldown then
			return
		end
	end
	p.points -= 1
	p.stats[stat] += 1
	State.applyStats(player)
end

-- ------------------------------------------------------------------ saving
local function key(player: Player)
	return "p_" .. player.UserId
end

function State.load(player: Player)
	if not store or RunService:IsStudio() and not game:GetAttribute("StudioSaves") then
		-- Studio: saves only work with API access enabled; try anyway but don't block.
	end
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(key(player))
	end)
	if ok and type(data) == "table" then
		State.saves[player] = data
		return data
	end
	return nil
end

function State.save(player: Player)
	if not store or not State.run or (State.run.flags and State.run.flags.arena) then
		return false -- the PvP arena never overwrites the story save
	end
	local p = State.profile(player)
	local data = {
		v = 1,
		profile = p,
		run = {
			seed = State.run.seed,
			chapter = State.run.chapter,
			flags = State.run.flags,
			land = State.run.land,
			ngPlus = State.run.ngPlus,
			cleared = State.run.cleared,
			waystones = State.run.waystones,
			deleteMode = State.run.deleteMode,
		},
		time = os.time(),
	}
	local ok = pcall(function()
		store:SetAsync(key(player), HttpService:JSONDecode(HttpService:JSONEncode(data)))
	end)
	return ok
end

function State.saveAll()
	for _, pl in Players:GetPlayers() do
		task.spawn(State.save, pl)
	end
end

function State.restore(player: Player, data)
	local prof = State.newProfile()
	for k, v in data.profile or {} do
		prof[k] = v
	end
	for k, v in State.newProfile().stats do
		if prof.stats[k] == nil then
			prof.stats[k] = v
		end
	end
	for k, v in State.newProfile().abilities do
		if prof.abilities[k] == nil then
			prof.abilities[k] = v
		end
	end
	prof.equipment = prof.equipment or {}
	prof.scrap = prof.scrap or 0
	prof.endings = prof.endings or {}
	State.profiles[player] = prof
	local r = data.run or {}
	local run = State.newRun(r.seed or RNG.seedFrom(nil), player.DisplayName)
	run.chapter = r.chapter or "Prologue"
	run.flags = r.flags or {}
	run.land = r.land or 1
	run.ngPlus = r.ngPlus or 0
	run.cleared = r.cleared or {}
	run.waystones = r.waystones or {}
	run.deleteMode = r.deleteMode or false
	State.run = run
end

return State
