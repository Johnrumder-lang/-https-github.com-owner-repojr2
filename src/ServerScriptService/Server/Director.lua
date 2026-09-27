--!nonstrict
-- The story director: runs chapters in order and provides the helpers every
-- chapter uses (dialogue, cutscenes, objectives, fades, waits, checkpoints).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Story = require(Shared.Story)
local RNG = require(Shared.RNG)
local Util = require(Shared.Util)
local S = require(script.Parent.S)

local D = {}
D.started = false
D.state = { zone = "menu", objective = nil, music = "Menu" }
D.pending = {}
D.skipFlag = false
D.deathHandler = nil
D.chapterModules = {}

D.ORDER = { "Prologue", "Afterlife", "Summoning", "Pit", "Breakout", "Prison", "Titan", "Castle", "World", "Tower", "Finale", "Epilogue" }

local idCounter = 0
local function newId()
	idCounter += 1
	return idCounter
end

-- ------------------------------------------------------------------ basics
function D.bible()
	return S.State.run.bible
end

function D.lines(scene: string, extra)
	return Story.lines(scene, D.bible(), extra)
end

function D.fill(text: string, extra): string
	return Story.fillText(text, D.bible(), extra)
end

function D.leader(): Player?
	return S.State.leader()
end

function D.players()
	return Players:GetPlayers()
end

function D.wait(t: number)
	if S.Pause then
		S.Pause.wait(t)
	else
		task.wait(t)
	end
end

-- Waits until fn() is truthy (or timeout). Returns fn()'s value.
function D.waitUntil(fn, timeout: number?, poll: number?)
	local t0 = os.clock()
	while true do
		local v = fn()
		if v then
			return v
		end
		if timeout and os.clock() - t0 > timeout then
			return nil
		end
		task.wait(poll or 0.2)
	end
end

function D.anyPlayerNear(pos: Vector3, radius: number): Player?
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c.PrimaryPart
		if r and (r.Position - pos).Magnitude <= radius then
			return p
		end
	end
	return nil
end

function D.waitNear(pos: Vector3, radius: number, timeout: number?)
	return D.waitUntil(function()
		return D.anyPlayerNear(pos, radius)
	end, timeout, 0.15)
end

function D.leaderPos(): Vector3
	local l = D.leader()
	local c = l and l.Character
	return c and c.PrimaryPart and c.PrimaryPart.Position or Vector3.zero
end

-- ------------------------------------------------------------------ client presentation
function D.zone(preset: string, title: string?, sub: string?)
	D.state.zone = preset
	D.state.zoneTitle = title
	Net.fireAll("Zone", { preset = preset, title = title, sub = sub })
end

function D.objective(text: string?, sub: string?)
	D.state.objective = text
	D.state.objectiveSub = sub
	Net.fireAll("Objective", { text = text, sub = sub })
end

function D.marker(pos: Vector3?, label: string?)
	D.state.marker = pos
	D.state.markerLabel = label
	Net.fireAll("Marker", { pos = pos, label = label })
end

function D.tutorial(text: string?, key: string?, dur: number?)
	Net.fireAll("Tutorial", { text = text, key = key, dur = dur })
end

function D.music(mood: string)
	D.state.music = mood
	Net.fireAll("Music", { mood = mood })
end

function D.shake(intensity: number, duration: number)
	Net.fireAll("Shake", { i = intensity, t = duration })
end

D.faded = false -- true while the screen is (supposed to be) black or white
function D.fade(to: string, time: number, color: Color3?)
	D.faded = to ~= "clear"
	Net.fireAll("Fade", { to = to, time = time, color = color })
	task.wait(time)
end

function D.title(text: string, sub: string?, dur: number?)
	Net.fireAll("Scene", "title", { text = text, sub = sub, dur = dur })
end

function D.bossBar(entity, name: string?)
	if entity then
		Net.fireAll("BossBar", { target = entity.model, name = name or entity.name, virtual = entity.virtual, id = entity.id })
	else
		Net.fireAll("BossBar", { clear = true })
	end
end

function D.bossHp(entity)
	local hp, max = S.Entities.health(entity)
	Net.fireAll("BossBar", { hp = hp, max = max, id = entity.id })
end

-- Speech bubble over a model.
function D.bark(model: Model?, text: string, dur: number?)
	if model then
		Net.fireAll("FX", "Shout", { target = model, text = text, dur = dur })
	end
end

-- Dialogue: lines = {{speaker, text}}. opts: {choices, auto, focus, player, timeout}
-- Yields until the leader finishes. Returns chosen index (or 0).
function D.say(lines, opts)
	opts = opts or {}
	local id = newId()
	local entry = { done = false, choice = 0, who = opts.player }
	D.pending[id] = entry
	local payload = {
		id = id,
		lines = lines,
		choices = opts.choices,
		auto = opts.auto,
		focus = opts.focus,
		hiddenChoice = opts.hiddenChoice,
		shop = opts.shop,
	}
	if opts.player then
		Net.fire(opts.player, "Dialogue", payload)
	else
		Net.fireAll("Dialogue", payload)
	end
	local chars = 0
	for _, l in lines do
		chars += #(l.text or "")
	end
	local timeout = opts.timeout or (if opts.choices then 900 else 25 + chars * 0.09 + #lines * 3)
	D.waitUntil(function()
		return entry.done
	end, timeout, 0.1)
	D.pending[id] = nil
	if not entry.done and opts.choices then
		return 1
	end
	return entry.choice
end

function D.dialogueResponse(player: Player, id, choice)
	local entry = D.pending[id]
	if not entry then
		return
	end
	if entry.who and entry.who ~= player then
		return
	end
	if not entry.who and player ~= D.leader() and #Players:GetPlayers() > 1 then
		return
	end
	entry.done = true
	entry.choice = tonumber(choice) or 0
end

-- Cutscene: def = {id?, shots = {...}, duration, ...}. Clients play it and report.
function D.cutscene(def)
	local id = newId()
	def.id = id
	local entry = { done = false }
	D.pending[id] = entry
	D.skipFlag = false
	Net.fireAll("Cutscene", def)
	local dur = def.duration or 5
	D.waitUntil(function()
		return entry.done
	end, dur + 6, 0.1)
	D.pending[id] = nil
	return entry.done
end

function D.cutsceneDone(player: Player, id)
	local entry = D.pending[id]
	if entry and (player == D.leader() or #Players:GetPlayers() == 1) then
		entry.done = true
	end
end

function D.skipRequest(player: Player)
	if player == D.leader() then
		D.skipFlag = true
		Net.fireAll("Scene", "skip", {})
	end
end

-- QTE (office typing etc.)
function D.qte(kind: string, data)
	local id = newId()
	local entry = { done = false, result = nil }
	D.pending[id] = entry
	data = data or {}
	data.id = id
	data.kind = kind
	Net.fireAll("Scene", "qte", data)
	D.waitUntil(function()
		return entry.done
	end, (data.time or 10) + 10, 0.1)
	D.pending[id] = nil
	return entry.result
end

function D.qteResult(player: Player, data)
	local entry = type(data) == "table" and D.pending[data.id]
	if entry then
		entry.done = true
		entry.result = data.result
	end
end

-- Client-side scene event (one-shot visuals: tv, burst, flash...).
function D.scene(name: string, data)
	Net.fireAll("Scene", name, data or {})
end

-- ------------------------------------------------------------------ players
function D.lock(locked: boolean?, noCombat: boolean?, noWeapon: boolean?)
	S.PlayerService.setLocks(locked, noCombat, noWeapon)
end

function D.checkpoint(cf: CFrame)
	S.PlayerService.checkpoint = cf
end

function D.spawnPlayers(cf: CFrame)
	D.checkpoint(cf)
	S.PlayerService.spawnAll(cf)
end

function D.teleport(cf: CFrame)
	S.PlayerService.teleportAll(cf)
end

function D.look(lookKey: string, rebuild: boolean?)
	S.PlayerService.setLook(lookKey, rebuild)
end

function D.heal()
	S.PlayerService.healAll()
end

function D.onPlayerDied(player: Player)
	if D.deathHandler then
		return D.deathHandler(player)
	end
	return false
end

function D.waitPrompt(part: BasePart, action: string, object: string?, opts)
	local who = nil
	local pp = S.PlayerService.prompt(part, action, object, function(player)
		who = player
	end, opts)
	D.waitUntil(function()
		return who
	end)
	pp:Destroy()
	return who
end

-- Kill objective with live counter. Returns when all entities with `tag` are dead.
-- Safety net: when the last few stay alive with no progress for 30 s they are
-- dragged out next to the players and outlined through walls, so a monster that
-- got stuck somewhere can never lock an objective.
function D.waitKills(tag: string, label: string, total: number?)
	local n = total or S.Entities.countTag(tag)
	local last = -1
	local lastChange = os.clock()
	while true do
		local alive = S.Entities.countTag(tag)
		if alive ~= last then
			last = alive
			lastChange = os.clock()
			D.objective(label, string.format("%d / %d", n - alive, n))
		end
		if alive <= 0 then
			break
		end
		if alive <= 3 and os.clock() - lastChange > 30 then
			lastChange = os.clock()
			D.pullStragglers(tag)
		end
		task.wait(0.3)
	end
end

function D.freeSpotNear(center: Vector3, r: number): Vector3?
	local params = S.AI.geoParams()
	for _ = 1, 16 do
		local a = math.random() * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local wall = workspace:Raycast(center + Vector3.new(0, 1, 0), p - center, params)
		if not wall then
			local down = workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -24, 0), params)
			if down and not S.AI.insideGeometry(down.Position + Vector3.new(0, 3, 0)) then
				return down.Position
			end
		end
	end
	return nil
end

function D.pullStragglers(tag: string)
	local lp = D.leaderPos()
	for _, e in S.Entities.withTag(tag) do
		local p = S.Entities.position(e)
		if e.root and not e.root.Anchored and (p - lp).Magnitude > 45 then
			local dest = D.freeSpotNear(lp, 16)
			if dest then
				e.root.AssemblyLinearVelocity = Vector3.zero
				e.root.CFrame = CFrame.new(dest + Vector3.new(0, 3 * (e.model and e.model:GetScale() or 1), 0))
				Net.fireAll("FX", "Teleport", { from = p, to = dest, color = Color3.fromRGB(255, 80, 80) })
			end
		end
		if e.model then
			Net.fireAll("FX", "Reveal", { target = e.model, t = 10 })
		end
	end
	D.tutorial("The last of them can't hide from you", nil, 4)
end

function D.clearWorld()
	D.clearActors()
	if S.Townlife then
		S.Townlife.clear()
	end
	if S.Interiors then
		S.Interiors.clear()
	end
	S.Projectiles.clear()
	S.Entities.clearNPCs()
	S.AI.clear()
	S.World.clear()
	D.bossBar(nil)
	D.marker(nil)
end

function D.save()
	S.State.saveAll()
end

function D.seed(): number
	return S.State.run.seed + (S.State.run.ngPlus or 0) * 7919
end

-- Builds a world once and keeps it until a different world is requested.
D.current = nil
D.refs = {}
function D.ensure(key: string, builder)
	if D.current == key and D.refs[key] then
		return D.refs[key]
	end
	D.faded = true
	Net.fireAll("Fade", { to = "black", time = 0.4 })
	task.wait(0.45)
	Net.fireAll("Scene", "loading", { on = true })
	D.clearWorld()
	-- the capital's terrain ring would cut through every other world
	if key ~= "capital" and S.TerrainGen then
		S.TerrainGen.clear()
	end
	local refs = builder()
	D.current = key
	D.refs = { [key] = refs }
	Net.fireAll("Scene", "loading", { on = false })
	return refs
end

function D.ensureCapital()
	return D.ensure("capital", function()
		return S.WorldCapital.build(D.bible(), D.seed())
	end)
end

-- Actors spawned for a chapter; cleaned with D.clearActors().
D.actors = {}
function D.actor(look, cf: CFrame, opts)
	local m = S.NPCs.actor(look, cf, opts)
	table.insert(D.actors, m)
	return m
end

function D.clearActors()
	for _, m in D.actors do
		if m and m.Parent then
			m:Destroy()
		end
	end
	D.actors = {}
end

function D.playerEntity()
	local l = D.leader()
	return l and S.Entities.forPlayer(l)
end

function D.leaderChar(): Model?
	local l = D.leader()
	return l and l.Character
end

function D.giveAll(fn)
	for _, p in Players:GetPlayers() do
		fn(p, S.State.profile(p))
		S.State.sync(p)
	end
end

-- ------------------------------------------------------------------ game start
function D.syncPlayer(player: Player)
	if D.state.zone then
		Net.fire(player, "Zone", { preset = D.state.zone })
	end
	if D.state.objective then
		Net.fire(player, "Objective", { text = D.state.objective, sub = D.state.objectiveSub })
	end
	Net.fire(player, "Music", { mood = D.state.music })
	if D.started then
		Net.fire(player, "Scene", "started", {})
		S.State.sync(player)
	end
end

function D.startGame(player: Player, data)
	if D.started then
		return
	end
	if player ~= D.leader() then
		return
	end
	D.started = true
	local mode = data.mode or "new"
	local save = S.State.saves[player]
	if mode == "arena" then
		local seed = RNG.seedFrom(type(data.seed) == "string" and data.seed or nil)
		S.State.run = S.State.newRun(seed, player.DisplayName)
		S.State.run.chapter = "Arena"
		S.State.run.flags.arena = true
		for _, p in Players:GetPlayers() do
			S.State.profiles[p] = S.State.newProfile()
		end
	elseif mode == "continue" and save and save.run then
		S.State.restore(player, save)
	else
		local seed = RNG.seedFrom(type(data.seed) == "string" and data.seed or nil)
		S.State.run = S.State.newRun(seed, player.DisplayName)
		S.State.profiles[player] = S.State.newProfile()
		if data.skipPrologue then
			S.State.run.chapter = "Summoning"
			S.State.run.flags.skippedPrologue = true
		end
	end
	for _, p in Players:GetPlayers() do
		S.State.profile(p)
	end
	Net.fireAll("Scene", "started", { seed = S.State.run.seed })
	for _, p in Players:GetPlayers() do
		S.State.sync(p)
	end
	task.spawn(D.loop)
end

-- Starts a brand new random story (keeps the player's level & gear: New Game+).
function D.restartStory(skipPrologue: boolean?)
	local old = S.State.run
	local l = D.leader()
	local seed = RNG.seedFrom(nil)
	local run = S.State.newRun(seed, l and l.DisplayName or "You")
	run.ngPlus = (old.ngPlus or 0) + 1
	run.chapter = if skipPrologue then "Summoning" else "Prologue"
	run.flags.skippedPrologue = skipPrologue
	S.State.run = run
	D.current = nil
	D.refs = {}
	Net.fireAll("Scene", "started", { seed = seed })
	for _, p in Players:GetPlayers() do
		local prof = S.State.profile(p)
		prof.quests = {}
		prof.blessed = false
		prof.abilities.aetherStep = false
		prof.abilities.voidSlash = false
		prof.abilities.timestop = false
		S.State.sync(p)
	end
	D.save()
	return "__restart"
end

function D.nextOf(ch: string): string
	if ch == "Epilogue" or ch == "GodFight" or ch == "Delete" then
		-- the end chapters fall back to free roam
		S.State.run.flags.epilogue = true
		return if ch == "Epilogue" then "World" else "Epilogue"
	end
	local i = table.find(D.ORDER, ch)
	return if i and D.ORDER[i + 1] then D.ORDER[i + 1] else "Epilogue"
end

-- Plays an ending card (title, lines, optional credits roll) and waits for it.
function D.ending(key: string, credits: boolean?)
	local e = Story.ENDINGS[key] or Story.ENDINGS.save
	local id = newId()
	local entry = { done = false }
	D.pending[id] = entry
	D.lock(true, true, false)
	D.objective(nil)
	D.marker(nil)
	D.bossBar(nil)
	D.music(if key == "delete" then "Silence" else "Ending")
	Net.fireAll("Scene", "ending", { id = id, title = e.title, lines = e.lines, credits = credits, color = if key == "best" then Color3.fromRGB(255, 230, 150) elseif key == "delete" then Color3.fromRGB(255, 60, 80) else nil })
	local dur = 4 + #e.lines * 2.6 + 2 + (if credits then 29 else 0) + 4
	D.waitUntil(function()
		return entry.done
	end, dur + 10, 0.2)
	D.pending[id] = nil
	local run = S.State.run
	run.flags.lastEnding = key
	D.giveAll(function(p, prof)
		prof.endings = prof.endings or {}
		prof.endings[key] = true
	end)
	D.save()
end

function D.loop()
	while true do
		local run = S.State.run
		local ch = run.chapter
		local mod = D.chapterModules[ch]
		if not mod then
			warn("[Director] missing chapter " .. tostring(ch))
			run.chapter = D.nextOf(ch)
			task.wait(1)
			continue
		end
		D.deathHandler = nil
		D.save()
		local ok, res = xpcall(function()
			return mod.run(D)
		end, debug.traceback)
		if not ok then
			warn("[Director] chapter " .. ch .. " crashed:\n" .. tostring(res))
			Net.fireAll("Notify", { kind = "warn", text = "Something broke in chapter " .. ch, sub = "Skipping ahead..." })
			res = D.nextOf(ch)
			D.fade("black", 0.5)
		end
		if res == "__stop" then
			break
		end
		if res == "__restart" then
			-- a brand new run was installed into S.State.run by the chapter
			continue
		end
		run.chapter = res or D.nextOf(ch)
	end
end

function D.init(chapters)
	D.chapterModules = chapters
	Players.PlayerAdded:Connect(function(p)
		task.wait(1)
		local data = S.State.load(p)
		Net.fire(p, "Scene", "menu", { hasSave = data ~= nil and data.run ~= nil, started = D.started, seed = data and data.run and data.run.seed })
		D.syncPlayer(p)
		if D.started then
			task.wait(1)
			S.PlayerService.spawn(p, S.PlayerService.checkpoint)
		end
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(function()
			local data = S.State.load(p)
			Net.fire(p, "Scene", "menu", { hasSave = data ~= nil and data.run ~= nil, started = D.started })
		end)
	end
	-- fade watchdog: a black screen while everybody is free to move is always a bug
	-- (v3: the PvP arena and "continue" into some chapters stayed black forever)
	task.spawn(function()
		local unlockedFor = 0
		while true do
			task.wait(0.5)
			if D.started and D.faded and not S.PlayerService.locked then
				unlockedFor += 0.5
				if unlockedFor >= 1.5 then
					unlockedFor = 0
					D.faded = false
					Net.fireAll("Fade", { to = "clear", time = 0.6 })
				end
			else
				unlockedFor = 0
			end
		end
	end)
	-- autosave
	task.spawn(function()
		while true do
			task.wait(90)
			if D.started then
				D.save()
			end
		end
	end)
	game:BindToClose(function()
		if D.started then
			for _, p in Players:GetPlayers() do
				S.State.save(p)
			end
		end
	end)
end

return D
