--!nonstrict
-- XP/gold on kills, weapon drops, chests and merchants.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local Gear = require(Shared.Gear)
local Palette = require(Shared.Palette)
local Kit = require(Shared.Kit)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local Loot = {}
local rng = RNG.new(os.time() % 7777 + 3)
local rgb = Color3.fromRGB

function Loot.folder(): Folder
	local world = workspace:FindFirstChild("World") or Kit.folder("World", workspace)
	local f = world:FindFirstChild("Loot") or Kit.folder("Loot", world)
	return f :: Folder
end

-- ------------------------------------------------------------------ drops
function Loot.dropWeapon(pos: Vector3, item, opts)
	local holder = Kit.model("Drop_" .. item.name, Loot.folder())
	local color = Palette.rarity[item.rarity] or Color3.new(1, 1, 1)
	local base = Kit.part(holder, Vector3.new(1.2, 0.2, 1.2), CFrame.new(pos + Vector3.new(0, 0.1, 0)), color, Enum.Material.Neon, { CanCollide = false, Transparency = 0.3 })
	base.Name = "Base"
	local pillar = Kit.deco(holder, Vector3.new(0.5, 26, 0.5), CFrame.new(pos + Vector3.new(0, 13, 0)), color, Enum.Material.Neon, { Transparency = 0.55, CastShadow = false })
	pillar.Name = "Pillar"
	local isGear = Gear.isGear(item)
	local w
	if isGear then
		w = Gear.previewModel(item)
		w:PivotTo(CFrame.new(pos + Vector3.new(0, 2.4, 0)))
	else
		w = Weapons.buildModel(item)
		w:PivotTo(CFrame.new(pos + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, 0.3))
	end
	for _, p in w:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	w.Parent = holder
	CollectionService:AddTag(w, "Spin")
	Kit.pointLight(base, color, 12, 1.4)
	holder:SetAttribute("Rarity", item.rarity)
	local taken = false
	local kindText = Loot.kindText(item)
	S.PlayerService.prompt(base, "Take", item.name .. "  (" .. item.rarity .. " " .. kindText .. ")", function(player)
		if taken then
			return
		end
		taken = true
		S.State.addItem(player, item)
		Net.fireAll("FX", "Pickup", { pos = pos, color = color })
		holder:Destroy()
	end, { dist = 9 })
	task.delay(opts and opts.life or 240, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	return holder
end

Loot.dropItem = Loot.dropWeapon

-- "falchion", "helm"... what the item is, for prompts and shop lines.
function Loot.kindText(item): string
	if Gear.isGear(item) then
		local info = Gear.SLOT_INFO[item.slot]
		return if info then info.label:lower() else "gear"
	end
	local b = Weapons.baseOf(item)
	if b and b.name then
		return b.name:lower()
	end
	return item.kind or "weapon"
end

function Loot.rollAny(level: number, opts)
	if rng:chance(0.58) then
		return Gear.roll(rng, level, opts)
	end
	return Weapons.roll(rng, level, opts)
end

-- A weapon of a named variant (not the plain classic of its type), or gear from
-- one of the newest bases this level unlocks: bosses and rich chests show off
-- the wider arsenal instead of another plain longsword.
function Loot.rollShowcase(level: number, opts)
	opts = table.clone(opts or {})
	if opts.type or rng:chance(0.5) then
		local kind = opts.type or rng:pick(Weapons.TYPE_LIST)
		local pool, earliest = {}, nil
		for _, b in Weapons.KIND_BASES[kind] or {} do
			if b.id ~= Weapons.CLASSIC[kind] then
				if b.minL <= level + 4 then
					table.insert(pool, { b.id, 1 + b.minL * 0.1 })
				end
				if not earliest or b.minL < earliest.minL then
					earliest = b
				end
			end
		end
		if #pool > 0 then
			opts.base = rng:weighted(pool)
		elseif earliest then
			-- a boss may hand out a variant a little ahead of its level
			opts.base = earliest.id
		end
		opts.type = kind
		return Weapons.roll(rng, level, opts)
	end
	local pool = {}
	for id, b in Gear.BASES do
		if b.minL <= level + 4 and b.minL >= level - 16 then
			table.insert(pool, { id, 1 + b.minL * 0.05 })
		end
	end
	if #pool > 0 and not opts.slot then
		opts.base = rng:weighted(pool)
	end
	return Gear.roll(rng, level, opts)
end

function Loot.goldBurst(pos: Vector3, amount: number)
	if amount <= 0 then
		return
	end
	for _, p in Players:GetPlayers() do
		S.State.addGold(p, amount)
	end
	Net.fireAll("FX", "Gold", { pos = pos, amount = amount })
end

local function rarityForKill(e)
	if e.boss then
		return rng:weighted({ { "Epic", 60 }, { "Legendary", 35 }, { "Divine", 5 } })
	elseif e.miniboss then
		return rng:weighted({ { "Rare", 55 }, { "Epic", 38 }, { "Legendary", 7 } })
	end
	return nil
end

function Loot.onDeath(e, killer)
	if e.kind == "player" or e.noDrop then
		return
	end
	local pos = S.Entities.position(e)
	for _, p in Players:GetPlayers() do
		S.State.addXP(p, e.xp or 5)
		local prof = S.State.profile(p)
		prof.kills += 1
	end
	if e.gold then
		Loot.goldBurst(pos, rng:int(e.gold[1], e.gold[2]))
	end
	local level = math.max(1, e.level or 1)
	local rar = rarityForKill(e)
	if rar then
		Loot.dropItem(pos + Vector3.new(0, 1, 0), if e.boss then Loot.rollShowcase(level, { rarity = rar }) else Loot.rollAny(level, { rarity = rar }))
		if e.boss then
			Loot.dropItem(pos + Vector3.new(4, 1, 0), Loot.rollShowcase(level, { minRarity = "Rare", type = rng:pick(Weapons.TYPE_LIST) }))
			Loot.dropItem(pos + Vector3.new(-4, 1, 0), Gear.roll(rng, level, { minRarity = "Rare" }))
		end
	elseif rng:chance(0.03) then
		Loot.dropItem(pos + Vector3.new(0, 1, 0), Weapons.roll(rng, level))
	elseif rng:chance(0.055) then
		Loot.dropItem(pos + Vector3.new(0, 1, 0), Gear.roll(rng, level))
	end
	-- occasional flask shard: refills one flask
	if rng:chance(if e.miniboss or e.boss then 1 else 0.05) then
		for _, p in Players:GetPlayers() do
			local prof = S.State.profile(p)
			if prof.flasks < prof.maxFlasks then
				prof.flasks += 1
				S.State.sync(p)
				Net.fire(p, "Notify", { kind = "info", text = "Flask refilled", sub = "+1 healing flask" })
			end
		end
	end
end

-- ------------------------------------------------------------------ chests
local TIERS = {
	wood = { body = rgb(120, 82, 50), band = rgb(90, 90, 96), gem = rgb(200, 200, 200), gold = { 10, 30 }, weapons = 1, rarity = { { "Common", 50 }, { "Uncommon", 40 }, { "Rare", 10 } } },
	iron = { body = rgb(90, 70, 50), band = rgb(160, 165, 175), gem = rgb(80, 160, 255), gold = { 30, 70 }, weapons = 1, rarity = { { "Uncommon", 40 }, { "Rare", 45 }, { "Epic", 15 } } },
	gold = { body = rgb(80, 30, 30), band = rgb(236, 190, 70), gem = rgb(200, 90, 255), gold = { 80, 160 }, weapons = 2, rarity = { { "Rare", 40 }, { "Epic", 45 }, { "Legendary", 15 } } },
	divine = { body = rgb(240, 240, 250), band = rgb(255, 220, 120), gem = rgb(255, 250, 200), gold = { 200, 400 }, weapons = 2, rarity = { { "Epic", 50 }, { "Legendary", 45 }, { "Divine", 5 } } },
}

function Loot.chest(parent: Instance?, cf: CFrame, tier: string, opts)
	opts = opts or {}
	local t = TIERS[tier] or TIERS.wood
	local model = Kit.model("Chest", parent or Loot.folder())
	local body = Kit.part(model, Vector3.new(3.2, 1.8, 2.1), cf * CFrame.new(0, 0.9, 0), t.body, Enum.Material.WoodPlanks)
	body.Name = "Body"
	for _, x in { -1.2, 1.2 } do
		Kit.deco(model, Vector3.new(0.25, 1.85, 2.15), cf * CFrame.new(x, 0.9, 0), t.band, Enum.Material.Metal)
	end
	local lidModel = Kit.model("Lid", model)
	local hinge = cf * CFrame.new(0, 1.8, 1.05)
	local lid = Kit.part(lidModel, Vector3.new(3.2, 0.7, 2.1), hinge * CFrame.new(0, 0.35, -1.05), Palette.shade(t.body, 1.1), Enum.Material.WoodPlanks)
	lid.Name = "LidPart"
	local lidBands = {}
	for _, x in { -1.2, 1.2 } do
		table.insert(lidBands, Kit.deco(lidModel, Vector3.new(0.25, 0.75, 2.15), hinge * CFrame.new(x, 0.35, -1.05), t.band, Enum.Material.Metal))
	end
	local lock = Kit.deco(lidModel, Vector3.new(0.5, 0.6, 0.2), hinge * CFrame.new(0, 0.1, -2.15), t.gem, Enum.Material.Neon)
	local glow = Kit.pointLight(body, t.gem, 10, 0.8)
	local opened = false
	local function open(player)
		if opened then
			return
		end
		opened = true
		Net.fireAll("FX", "Chest", { pos = body.Position, color = t.gem })
		local parts = { lid, lock }
		for _, b in lidBands do
			table.insert(parts, b)
		end
		local offsets = {}
		for _, p in parts do
			offsets[p] = hinge:ToObjectSpace(p.CFrame)
		end
		task.spawn(function()
			for i = 1, 12 do
				local a = -math.rad(105) * (i / 12)
				local h = hinge * CFrame.Angles(a, 0, 0)
				for _, p in parts do
					p.CFrame = h * offsets[p]
				end
				task.wait(0.02)
			end
		end)
		glow.Brightness = 3
		local level = opts.level or 1
		Loot.goldBurst(body.Position + Vector3.new(0, 2, 0), rng:int(t.gold[1], t.gold[2]) * math.max(1, math.floor(level / 3)))
		local n = 0
		for i = 1, t.weapons + 1 do
			if i == 1 or rng:chance(0.6) then
				local roll = if (tier == "gold" or tier == "divine") and i == 1 then Loot.rollShowcase else Loot.rollAny
				local item = if opts.item and i == 1 then opts.item else roll(level, { rarity = rng:weighted(t.rarity) })
				n += 1
				Loot.dropItem((cf * CFrame.new((n - 1.5) * 3, 0, -3.5)).Position, item)
			end
		end
		for _, p in Players:GetPlayers() do
			local prof = S.State.profile(p)
			prof.scrap = (prof.scrap or 0) + rng:int(1, 2 + t.weapons)
		end
		for _, p in Players:GetPlayers() do
			local prof = S.State.profile(p)
			if prof.flasks < prof.maxFlasks then
				prof.flasks = prof.maxFlasks
				S.State.sync(p)
			end
		end
		if opts.id and S.State.run then
			S.State.run.cleared[opts.id] = true
		end
		if opts.onOpen then
			task.spawn(opts.onOpen, player)
		end
		local pp = body:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp:Destroy()
		end
	end
	S.PlayerService.prompt(body, "Open", tier:gsub("^%l", string.upper) .. " Chest", open, { dist = 9 })
	return model
end

-- ------------------------------------------------------------------ merchant (via dialogue choices)
function Loot.merchant(npcModel: Model, name: string, level: number)
	local stock = {}
	-- two weapons of different types, at least one of them a named variant
	local kinds = rng:shuffle(table.clone(Weapons.TYPE_LIST))
	for i = 1, 2 do
		local r = rng:weighted({ { "Uncommon", 30 }, { "Rare", 50 }, { "Epic", 20 } })
		local w = if i == 1 then Loot.rollShowcase(level + 1, { rarity = r, type = kinds[i] }) else Weapons.roll(rng, level + 1, { rarity = r, type = kinds[i] })
		table.insert(stock, w)
	end
	for _, slot in rng:shuffle(table.clone(Gear.SLOTS)) do
		if #stock >= 6 then
			break
		end
		table.insert(stock, Gear.roll(rng, level + 1, { slot = slot, rarity = rng:weighted({ { "Uncommon", 35 }, { "Rare", 48 }, { "Epic", 17 } }) }))
	end
	local head = npcModel:FindFirstChild("Head") :: BasePart
	S.PlayerService.prompt(npcModel.PrimaryPart, "Trade", name, function(player)
		local prof = S.State.profile(player)
		local flaskCost = 180 * (prof.maxFlasks - 2)
		local scrapCost = 45 + level * 6
		local choices = { string.format("Extra flask (+1 max) — %dg", flaskCost), string.format("5 iron scrap (for upgrades) — %dg", scrapCost) }
		local offers = {}
		for _, w in stock do
			local price = math.floor((40 + w.level * 22) * ((table.find(Weapons.RARITIES, w.rarity) or 1) ^ 1.7))
			local kind = Loot.kindText(w)
			table.insert(choices, string.format("%s (%s %s) — %dg", w.name, w.rarity, kind, price))
			table.insert(offers, { item = w, price = price })
		end
		table.insert(choices, "Leave")
		local c = S.Director.say({ { speaker = name, text = "Gold for goods, stranger. You have " .. prof.gold .. "g." } }, { choices = choices, player = player })
		if c == 1 then
			if prof.gold >= flaskCost and prof.maxFlasks < 8 then
				prof.gold -= flaskCost
				prof.maxFlasks += 1
				prof.flasks = prof.maxFlasks
				Net.fire(player, "Notify", { kind = "info", text = "Max flasks: " .. prof.maxFlasks })
			else
				Net.fire(player, "Notify", { kind = "warn", text = "Not enough gold" })
			end
		elseif c == 2 then
			if prof.gold >= scrapCost then
				prof.gold -= scrapCost
				prof.scrap = (prof.scrap or 0) + 5
				Net.fire(player, "Notify", { kind = "info", text = "+5 scrap", sub = "Upgrade gear in your inventory [Tab]" })
			else
				Net.fire(player, "Notify", { kind = "warn", text = "Not enough gold" })
			end
		else
			local idx = c - 2
			local offer = offers[idx]
			if offer then
				if prof.gold >= offer.price then
					prof.gold -= offer.price
					table.remove(stock, table.find(stock, offer.item))
					S.State.addItem(player, offer.item)
				else
					Net.fire(player, "Notify", { kind = "warn", text = "Not enough gold" })
				end
			end
		end
		S.State.sync(player)
	end, { dist = 10 })
end

function Loot.init()
	S.Entities.onDeath(Loot.onDeath)
end

return Loot
