--!nonstrict
-- Player characters (cubic R6 rigs built in code), respawning, input routing.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Rig = require(Shared.Rig)
local Weapons = require(Shared.Weapons)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Gear = require(Shared.Gear)
local S = require(script.Parent.S)

local PlayerService = {}
PlayerService.look = "casual"
PlayerService.checkpoint = CFrame.new(0, 12, 0)
PlayerService.locked = false
PlayerService.noCombat = true
PlayerService.noWeapon = true
PlayerService.skins = {}
local joinCounter = 0
local rgb = Color3.fromRGB

-- ------------------------------------------------------------------ appearance
local function appearance(player: Player)
	local a = PlayerService.skins[player]
	if a then
		return a
	end
	local rng = RNG.new(player.UserId % 2147483000 + 11)
	a = {
		skin = rng:pick(Palette.skin),
		hair = rng:pick({ rgb(30, 26, 24), rgb(58, 40, 28), rgb(96, 62, 36), rgb(214, 180, 110), rgb(20, 20, 22) }),
		hairStyle = rng:pick({ "short", "messy", "spiky", "slick", "long" }),
		shirt = rng:pick(Palette.modernCloth),
		eye = rng:pick({ rgb(60, 40, 30), rgb(40, 80, 140), rgb(50, 110, 60), rgb(30, 30, 30) }),
	}
	pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(player.UserId)
		if desc then
			a.skin = desc.HeadColor
		end
	end)
	PlayerService.skins[player] = a
	return a
end
PlayerService.appearance = appearance

function PlayerService.describe(player: Player, lookKey: string)
	local a = appearance(player)
	local d = {
		name = player.Name,
		race = "Human",
		skin = a.skin,
		hair = a.hair,
		hairStyle = a.hairStyle,
		eye = a.eye,
		mood = "neutral",
		player = true,
		walkSpeed = Config.Player.walkSpeed,
	}
	if lookKey == "casual" then
		d.outfit = "casual"
		d.shirt = a.shirt
		d.pants = rgb(50, 70, 110)
		d.shoes = rgb(40, 40, 46)
	elseif lookKey == "office" then
		d.outfit = "office"
		d.shirt = rgb(235, 235, 238)
		d.pants = rgb(40, 42, 50)
		d.blazer = rgb(44, 48, 60)
		d.accent = rgb(150, 30, 40)
	elseif lookKey == "night" then
		d.outfit = "jacket"
		d.shirt = a.shirt
		d.jacket = rgb(26, 26, 30)
		d.pants = rgb(30, 34, 50)
		d.shoes = rgb(230, 230, 230)
	elseif lookKey == "prisoner" then
		d.outfit = "prisoner"
		d.shirt = rgb(130, 118, 96)
		d.pants = rgb(100, 90, 74)
	elseif lookKey == "awakened" then
		d.outfit = "hero"
		d.shirt = rgb(24, 26, 34)
		d.pants = rgb(30, 30, 38)
		d.accent = rgb(120, 220, 255)
		d.awakened = true
		d.glow = rgb(140, 230, 255)
	else
		d.outfit = "hero"
		d.shirt = rgb(40, 36, 44)
		d.pants = rgb(46, 40, 38)
		d.accent = rgb(160, 30, 40)
	end
	if PlayerService.showsGear(lookKey) then
		d.gear = S.State.equippedGear(player)
	end
	return d
end

-- Modern-day clothes (the prologue) never show armour.
function PlayerService.showsGear(lookKey: string?): boolean
	local ch = S.State.run and S.State.run.chapter
	if ch == "Prologue" or ch == "Afterlife" then
		return false
	end
	return lookKey ~= "casual" and lookKey ~= "office"
end

-- Re-dresses the current character after an equipment change (no respawn).
function PlayerService.refreshGear(player: Player)
	local char = player.Character
	if not char then
		return
	end
	if PlayerService.showsGear(PlayerService.look) then
		Gear.apply(char, S.State.equippedGear(player))
	else
		Gear.clear(char)
	end
	Net.fire(player, "Scene", "gearChanged", {})
end

-- ------------------------------------------------------------------ spawning
function PlayerService.refreshWeapon(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("Weapon")
	if old then
		old:Destroy()
	end
	local arm = char:FindFirstChild("Right Arm")
	if arm then
		local w = arm:FindFirstChild("HandWeld")
		if w then
			w:Destroy()
		end
	end
	if char:GetAttribute("NoWeapon") then
		return
	end
	local item = S.State.equipped(player)
	if item then
		local m = Weapons.buildModel(item)
		m.Name = "Weapon"
		Rig.hold(char, m)
	end
end

function PlayerService.applyLocks(player: Player)
	local char = player.Character
	if not char then
		return
	end
	char:SetAttribute("Locked", PlayerService.locked or nil)
	char:SetAttribute("NoCombat", PlayerService.noCombat or nil)
	char:SetAttribute("NoWeapon", PlayerService.noWeapon or nil)
end

function PlayerService.setLocks(locked: boolean?, noCombat: boolean?, noWeapon: boolean?)
	if locked ~= nil then
		PlayerService.locked = locked
	end
	if noCombat ~= nil then
		PlayerService.noCombat = noCombat
	end
	local weaponChanged = noWeapon ~= nil and noWeapon ~= PlayerService.noWeapon
	if noWeapon ~= nil then
		PlayerService.noWeapon = noWeapon
	end
	for _, p in Players:GetPlayers() do
		PlayerService.applyLocks(p)
		if weaponChanged then
			PlayerService.refreshWeapon(p)
		end
	end
end

function PlayerService.spawn(player: Player, cf: CFrame?)
	local old = player.Character
	if old then
		local oe = S.Entities.fromModel(old)
		if oe then
			S.Entities.remove(oe)
		end
		old:Destroy()
	end
	local d = PlayerService.describe(player, PlayerService.look)
	d.health = S.State.derived(player).maxHp
	local model = Rig.build(d)
	model.Name = player.Name
	local at = cf or PlayerService.checkpoint
	if S.TerrainGen and at then
		S.TerrainGen.ensure(at.Position, 120)
	end
	model:PivotTo(at)
	model.Parent = workspace
	player.Character = model
	local root = model.PrimaryPart
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.JumpPower = Config.Player.jumpPower
	-- keep the joints so the body ragdolls instead of falling apart
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	S.Combat.setGroup(model, "Players")
	local e = S.Entities.new(model, { kind = "player", player = player, team = "hero", posture = 1e9, blood = "red", name = player.DisplayName })
	e.radius = 1.6
	PlayerService.applyLocks(player)
	PlayerService.refreshWeapon(player)
	S.State.applyStats(player)
	hum.Health = hum.MaxHealth
	hum.Died:Connect(function()
		PlayerService.onDied(player, e)
	end)
	if S.PvP then
		S.PvP.attach(player, model)
	end
	return model
end

function PlayerService.spawnAll(cf: CFrame?)
	local list = Players:GetPlayers()
	for i, p in list do
		local offset = if i == 1 then CFrame.identity else CFrame.new((i - 1) * 4 - 6, 0, 3)
		PlayerService.spawn(p, (cf or PlayerService.checkpoint) * offset)
	end
end

-- Teleport without rebuilding (keeps ragdoll state etc. clean).
function PlayerService.teleport(player: Player, cf: CFrame)
	if S.TerrainGen then
		S.TerrainGen.ensure(cf.Position, 120)
	end
	local char = player.Character
	if not char or not char.Parent then
		PlayerService.spawn(player, cf)
		return
	end
	if S.Ragdoll.isRagdolled(char) then
		S.Ragdoll.disable(char)
	end
	char:PivotTo(cf)
	Net.fire(player, "Scene", "teleported", { cf = cf })
end

function PlayerService.teleportAll(cf: CFrame)
	for i, p in Players:GetPlayers() do
		local offset = if i == 1 then CFrame.identity else CFrame.new((i - 1) * 4 - 6, 0, 3)
		PlayerService.teleport(p, cf * offset)
	end
end

function PlayerService.setLook(lookKey: string, respawnHere: boolean?)
	PlayerService.look = lookKey
	if respawnHere then
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local cf = char and char:GetPivot() or PlayerService.checkpoint
			PlayerService.spawn(p, cf)
		end
	end
end

function PlayerService.onDied(player: Player, e)
	if not e.dead then
		S.Combat.kill(e, nil, {})
	end
	local prof = S.State.profile(player)
	prof.deaths += 1
	Net.fire(player, "Notify", { kind = "death" })
	task.delay(Config.Player.respawnDelay, function()
		if not player.Parent then
			return
		end
		if S.Director and S.Director.onPlayerDied then
			local handled = S.Director.onPlayerDied(player)
			if handled then
				return
			end
		end
		prof.flasks = prof.maxFlasks
		PlayerService.spawn(player, PlayerService.checkpoint)
		S.State.sync(player)
	end)
end

function PlayerService.healAll()
	for _, p in Players:GetPlayers() do
		local e = S.Entities.forPlayer(p)
		if e and e.hum and e.hum.Health > 0 then
			e.hum.Health = e.hum.MaxHealth
		end
		local prof = S.State.profile(p)
		prof.flasks = prof.maxFlasks
		S.State.sync(p)
	end
end

-- Convenience: prompt on a part that calls fn(player).
function PlayerService.prompt(part: BasePart, action: string, object: string?, fn, opts)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = opts and opts.hold or 0
	pp.MaxActivationDistance = opts and opts.dist or 10
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = part
	pp.Triggered:Connect(function(player)
		if player.Character and player.Character:GetAttribute("Locked") and not (opts and opts.whileLocked) then
			return
		end
		fn(player, pp)
	end)
	return pp
end

-- ------------------------------------------------------------------ input
-- Movement state everybody else sees (third-person poses): "MoveStateS" on the
-- character. The owning client drives its own copy ("MoveState") locally.
local stateTok = {}
function PlayerService.moveState(player: Player, st: string?, dur: number?)
	local char = player.Character
	if not char then
		return
	end
	char:SetAttribute("MoveStateS", st)
	local tok = (stateTok[player] or 0) + 1
	stateTok[player] = tok
	if st and dur then
		task.delay(dur, function()
			if stateTok[player] == tok and char.Parent and char:GetAttribute("MoveStateS") == st then
				char:SetAttribute("MoveStateS", nil)
			end
		end)
	end
end

local function onInput(player: Player, action: string, data)
	local e = S.Entities.forPlayer(player)
	if type(action) ~= "string" then
		return
	end
	data = if type(data) == "table" then data else {}
	local now = os.clock()
	if action == "Swing" then
		S.Combat.playerSwing(player, data)
	elseif not e or not S.Entities.isAlive(e) then
		return
	elseif action == "Parry" then
		if now >= e.parryCd then
			e.parryUntil = now + Config.Player.parryWindow
			e.parryCd = now + Config.Player.parryCooldown
		end
		e.blocking = true
	elseif action == "BlockEnd" then
		e.blocking = false
	elseif action == "Dash" then
		e.dashUntil = now + Config.Player.dashIframes
		e.lastDashAt = now
		e.dashId = (e.dashId or 0) + 1
		if typeof(data.dir) == "Vector3" and data.dir.Magnitude > 0.5 then
			e.dashDir = data.dir.Unit
		end
		-- dashing bodies pass through monsters (the client does the same for its own physics)
		local char = player.Character
		if char then
			S.Combat.setGroup(char, "Dashing")
			PlayerService.moveState(player, "dash", Config.Player.dashTime + 0.05)
			local id = e.dashId
			task.delay(Config.Player.dashTime + 0.06, function()
				if char.Parent and e.dashId == id then
					S.Combat.setGroup(char, "Players")
				end
			end)
		end
	elseif action == "DashStab" then
		S.Combat.dashStab(player, data.target, data.from, data.to)
	elseif action == "Slide" then
		e.sliding = data.on == true
		PlayerService.moveState(player, if e.sliding then "slide" else nil)
	elseif action == "TimeStop" then
		S.TimeStop.request(player)
	elseif action == "Flask" then
		S.Combat.flask(player)
	elseif action == "AetherStep" then
		if typeof(data.from) == "Vector3" and typeof(data.to) == "Vector3" then
			S.Combat.aetherStep(player, data.from, data.to)
		end
	elseif action == "VoidSlash" then
		S.Combat.voidSlash(player, data.look)
	elseif action == "SlamStart" then
		e.slamming = true
		e.dashUntil = math.max(e.dashUntil, now + 0.12)
		PlayerService.moveState(player, "slam", 4)
	elseif action == "Slam" then
		e.slamming = false
		PlayerService.moveState(player, nil)
		S.Combat.slam(player, data.pos, data.fall)
	elseif action == "WallJump" then
		e.dashUntil = math.max(e.dashUntil, now + 0.08)
		PlayerService.moveState(player, "walljump", 0.38)
	elseif action == "FlameRune" then
		S.Combat.flameRune(player, data.pos)
	elseif action == "StormWeb" then
		S.Combat.stormWeb(player, data.look)
	end
end

local function onMenu(player: Player, action: string, data)
	data = if type(data) == "table" then data else {}
	if action == "Equip" and type(data.id) == "string" then
		S.State.equip(player, data.id)
	elseif action == "Unequip" and type(data.slot) == "string" then
		S.State.unequip(player, data.slot)
	elseif action == "Upgrade" and type(data.id) == "string" then
		S.State.upgrade(player, data.id)
	elseif action == "SalvageJunk" then
		S.State.salvageJunk(player)
	elseif action == "Allocate" and type(data.stat) == "string" then
		S.State.allocate(player, data.stat)
	elseif action == "Salvage" and type(data.id) == "string" then
		S.State.salvage(player, data.id)
	elseif action == "Dialogue" then
		S.Director.dialogueResponse(player, data.id, data.choice)
	elseif action == "CutsceneDone" then
		S.Director.cutsceneDone(player, data.id)
	elseif action == "Start" then
		S.Director.startGame(player, data)
	elseif action == "Arena" then
		S.Director.startGame(player, { mode = "arena", seed = data.seed })
	elseif action == "Skip" then
		S.Director.skipRequest(player)
	elseif action == "QTE" then
		S.Director.qteResult(player, data)
	elseif action == "Pause" then
		-- pause menu: S.Pause freezes the world (it only takes effect with a single player)
		local on = data.on == true
		if S.Pause then
			S.Pause.set(on, player)
		end
	end
end

function PlayerService.init()
	Net.on("Input", onInput)
	Net.on("Menu", onMenu)
	-- gear regeneration
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, e in S.Entities.players() do
				if e.regen and e.regen > 0 and e.hum and e.hum.Health > 0 and e.hum.Health < e.hum.MaxHealth and not e.frozen then
					e.hum.Health = math.min(e.hum.MaxHealth, e.hum.Health + e.regen * 0.5)
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		joinCounter += 1
		p:SetAttribute("JoinOrder", joinCounter)
	end)
	for _, p in Players:GetPlayers() do
		joinCounter += 1
		p:SetAttribute("JoinOrder", joinCounter)
	end
	Players.PlayerRemoving:Connect(function(p)
		local e = S.Entities.forPlayer(p)
		if e then
			S.Entities.remove(e)
		end
		S.State.save(p)
		PlayerService.skins[p] = nil
	end)
end

return PlayerService
