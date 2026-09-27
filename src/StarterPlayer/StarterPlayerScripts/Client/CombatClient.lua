--!nonstrict
-- Combat input: combos with input buffering, heavy charge, parry/block, time stop,
-- flask, abilities. Visual/audio feedback from HitConfirm.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local C = require(script.Parent.C)

local CombatClient = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local combo = 0
local lastSwingEnd = 0
local nextSwingAt = 0
local lmbDown = false
local lmbAt = 0
local buffered = false
local rmbDown = false
CombatClient.tsReady = 0
CombatClient.tsTotal = 1
CombatClient.stepReady = 0
CombatClient.slashReady = 0
CombatClient.runeReady = 0
CombatClient.stormReady = 0

local function style(label: string, pts: number)
	if C.HUD and C.HUD.addStyle then
		pcall(C.HUD.addStyle, label, pts)
	end
end
CombatClient.style = style

-- where the crosshair points (for spells)
local function aimPoint(range: number): Vector3?
	local ch = player.Character
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ch, cam, workspace:FindFirstChild("FX") }
	local o = cam.CFrame.Position
	local d = cam.CFrame.LookVector
	local r = workspace:Raycast(o, d * range, params)
	local p = if r then r.Position else o + d * range
	-- drop onto the floor below
	local down = workspace:Raycast(p + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	if down then
		return down.Position
	end
	return p
end

local function canFight(): boolean
	local ch = player.Character
	if not ch or C.Controller.mode ~= "play" or C.timeStop.frozenSelf or C.wantsCursor() then
		return false
	end
	if ch:GetAttribute("Locked") or ch:GetAttribute("NoCombat") or ch:GetAttribute("Stun") then
		return false
	end
	return C.Viewmodel.equippedItem() ~= nil
end

local function stats()
	local item = C.Viewmodel.equippedItem()
	if not item then
		return nil
	end
	return Weapons.stats(item)
end

local function doSwing(heavy: boolean)
	local s = stats()
	if not s then
		return
	end
	local now = os.clock()
	if now < nextSwingAt then
		buffered = true
		return
	end
	if now - lastSwingEnd > Config.Combat.comboWindow + s.interval then
		combo = 0
	end
	combo = combo % 3 + 1
	if heavy then
		combo = 1
		C.Viewmodel.heavy(s.interval)
		nextSwingAt = now + s.interval * 1.15
		C.Audio.play("SwingHeavy", { pitch = 0.85 })
		C.Controller.kick(-2.5, 1.5)
	else
		C.Viewmodel.swing(combo, s.interval)
		nextSwingAt = now + s.interval
		C.Audio.play("Swing", { pitch = 1 + combo * 0.06 })
		C.Controller.kick(-0.8, if combo == 2 then -1 else 1)
	end
	lastSwingEnd = nextSwingAt
	-- air attacks keep you up there (juggles)
	local air = C.Controller.isGrounded ~= nil and not C.Controller.isGrounded()
	if air and C.Controller.hang then
		C.Controller.hang()
	end
	Net.send("Input", "Swing", { i = combo, heavy = heavy, look = cam.CFrame.LookVector, air = air })
end

function CombatClient.timeStop()
	local ch = player.Character
	if not ch or not C.profile or not C.profile.abilities.timestop then
		return
	end
	if ch:GetAttribute("Locked") or C.timeStop.frozenSelf then
		return
	end
	if C.timeStop.active and C.timeStop.mine then
		Net.send("Input", "TimeStop")
		return
	end
	if workspace:GetServerTimeNow() < CombatClient.tsReady then
		C.HUD.flashTimeStop()
		return
	end
	C.Viewmodel.snap()
	Net.send("Input", "TimeStop")
end

local function onBegan(input: InputObject, gp: boolean)
	if gp then
		return
	end
	local k = input.KeyCode
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
		if canFight() then
			lmbDown = true
			lmbAt = os.clock()
		end
	elseif t == Enum.UserInputType.MouseButton2 or k == Enum.KeyCode.ButtonL2 then
		if canFight() then
			rmbDown = true
			C.Viewmodel.parry(true)
			Net.send("Input", "Parry")
		end
	elseif k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonY then
		CombatClient.timeStop()
	elseif k == Enum.KeyCode.R or k == Enum.KeyCode.DPadUp then
		if player.Character and not player.Character:GetAttribute("Locked") and C.profile and C.profile.flasks > 0 then
			C.Viewmodel.flask()
			C.Audio.play("Flask")
			Net.send("Input", "Flask")
		end
	elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.ButtonB then
		-- tap: dash. hold: dash into a sprint (the lands are big)
		C.Controller.dash()
		local at = os.clock()
		C.Controller.shiftAt = at
		task.delay(0.3, function()
			if C.Controller.shiftAt == at then
				C.Controller.sprintHeld = true
			end
		end)
	elseif k == Enum.KeyCode.LeftControl or k == Enum.KeyCode.C or k == Enum.KeyCode.ButtonL3 then
		C.Controller.slide()
	elseif k == Enum.KeyCode.Z or k == Enum.KeyCode.DPadLeft then
		local cfg = Config.Abilities.FlameRune
		if C.profile and C.profile.abilities.flameRune and os.clock() >= CombatClient.runeReady and canFight() then
			local p = aimPoint(cfg.range)
			if p then
				CombatClient.runeReady = os.clock() + cfg.cooldown
				C.Viewmodel.snap()
				C.Audio.play("Rune", { pitch = 1.3 })
				C.Controller.kick(-1.5, 0)
				Net.send("Input", "FlameRune", { pos = p })
			end
		end
	elseif k == Enum.KeyCode.X or k == Enum.KeyCode.DPadRight then
		local cfg = Config.Abilities.StormWeb
		if C.profile and C.profile.abilities.stormWeb and os.clock() >= CombatClient.stormReady and canFight() then
			CombatClient.stormReady = os.clock() + cfg.cooldown
			C.Viewmodel.push()
			C.Audio.play("Lightning", { pitch = 0.6 })
			C.Controller.shake(0.8, 0.2)
			Net.send("Input", "StormWeb", { look = cam.CFrame.LookVector })
		end
	elseif k == Enum.KeyCode.F then
		if C.profile and C.profile.abilities.aetherStep and os.clock() >= CombatClient.stepReady and canFight() then
			if C.Controller.aetherStep() then
				CombatClient.stepReady = os.clock() + Config.Abilities.AetherStep.cooldown
			end
		end
	elseif k == Enum.KeyCode.G then
		if C.profile and C.profile.abilities.voidSlash and os.clock() >= CombatClient.slashReady and canFight() then
			CombatClient.slashReady = os.clock() + Config.Abilities.VoidSlash.cooldown
			C.Viewmodel.voidSlash()
			C.Audio.play("SwingHeavy", { pitch = 0.6 })
			C.Controller.kick(-3, 2)
			task.delay(0.1, function()
				Net.send("Input", "VoidSlash", { look = cam.CFrame.LookVector })
			end)
		end
	end
end

local function onEnded(input: InputObject)
	local t = input.UserInputType
	local k = input.KeyCode
	if k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.ButtonB then
		C.Controller.shiftAt = nil
		C.Controller.sprintHeld = false
	elseif k == Enum.KeyCode.LeftControl or k == Enum.KeyCode.C or k == Enum.KeyCode.ButtonL3 then
		if C.Controller.slideRelease then
			C.Controller.slideRelease()
		end
	end
	if t == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
		if lmbDown then
			lmbDown = false
			C.Viewmodel.setCharging(false)
			local held = os.clock() - lmbAt
			if canFight() then
				doSwing(held >= Config.Combat.heavyChargeTime)
			end
		end
	elseif t == Enum.UserInputType.MouseButton2 or k == Enum.KeyCode.ButtonL2 then
		if rmbDown then
			rmbDown = false
			C.Viewmodel.release()
			Net.send("Input", "BlockEnd")
		end
	end
end

RunService.RenderStepped:Connect(function()
	if lmbDown and os.clock() - lmbAt > 0.16 then
		C.Viewmodel.setCharging(true)
	end
	if buffered and os.clock() >= nextSwingAt then
		buffered = false
		if canFight() then
			doSwing(false)
		end
	end
	if rmbDown and not canFight() then
		rmbDown = false
		C.Viewmodel.release()
		Net.send("Input", "BlockEnd")
	end
end)

function CombatClient.init()
	UserInputService.InputBegan:Connect(onBegan)
	UserInputService.InputEnded:Connect(onEnded)
	Net.on("HitConfirm", function(d)
		if type(d.styles) == "table" then
			for _, st in d.styles do
				if type(st) == "table" then
					style(tostring(st[1]), tonumber(st[2]) or 10)
				end
			end
		end
		if d.silent then
			return
		end
		if d.hurt then
			if (d.dmg or 0) > 0 and not d.blocked then
				style("", -math.floor((d.dmg or 10) * 1.5))
			end
			C.Viewmodel.hurt()
			C.Controller.shake(math.clamp((d.dmg or 10) / 12, 0.6, 3.5), 0.25)
			C.Controller.kick(math.random(2, 4), math.random(-2, 2))
			C.HUD.hurt(d.dmg or 10, d.blocked)
			if d.blocked then
				C.Audio.play("Block")
			else
				C.Audio.play("Flesh", { pitch = 0.8 })
			end
		elseif d.parry then
			C.Audio.play("Parry", { pitch = 1.2, ignoreTime = true })
			C.Audio.play("Block", { pitch = 1.4 })
			C.Viewmodel.hitstop(0.09)
			C.Controller.shake(1.6, 0.18)
			C.Controller.punch(-4)
			C.HUD.flash(Color3.new(1, 1, 1), 0.12)
			if C.FX then
				C.FX.parrySpark()
			end
		elseif d.deflected then
			C.Viewmodel.recoil()
			C.Audio.play("Block", { pitch = 0.9 })
			C.Controller.shake(1.2, 0.2)
		else
			local n = d.n or 1
			C.Viewmodel.hitstop(if d.heavy then 0.1 else 0.045 + math.min(n, 4) * 0.01)
			if C.FX and not d.frozen then
				local tip = C.Viewmodel.tipPosition()
				if tip then
					C.FX.sparks(tip, -cam.CFrame.LookVector, Color3.fromRGB(255, 250, 230), if d.heavy then 10 else 5, 36, 1.2)
				end
				if d.heavy or n >= 3 then
					C.FX.focusLines(0.25)
				end
				if d.heavy then
					C.FX.impactFrame(0.55)
				end
			end
			C.Controller.shake(if d.heavy then 2.2 else 0.7 + n * 0.15, 0.12)
			C.Audio.play("Hit", { pitch = if d.frozen then 0.7 else 1.1 })
			if not d.frozen then
				C.Audio.play("Flesh", { vol = 0.8 })
			end
		end
	end)
end

return CombatClient
