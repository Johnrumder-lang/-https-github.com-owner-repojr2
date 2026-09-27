--!nonstrict
-- Draws the Kingdom-Eater smoothly on this client using the shared TitanAnim FK.
-- The server sends actions on a shared "titan clock" that freezes in time stop.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local TitanAnim = require(Shared.TitanAnim)
local C = require(script.Parent.C)

local Titan = {}
local state = nil

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

RunService.RenderStepped:Connect(function(dt)
	local st = state
	if not st or not st.model or not st.model.Parent then
		return
	end
	if not C.timeStop.active then
		st.clock += dt
	end
	local act = st.action
	local def = TitanAnim.ACTIONS[act.name] or TitanAnim.ACTIONS.idle
	local t = st.clock - act.clock0
	local loops = act.name == "idle" or act.name == "walk" or act.name == "down" or act.name == "hover"
	local tt = if loops then t else math.min(t, def.dur)
	local k = if act.moveDur and act.moveDur > 0 then ease(t / act.moveDur) else 1
	local root = act.from:Lerp(act.to, k)
	local parts = TitanAnim.solve(root, TitanAnim.pose(act.name, tt))
	for name, cf in parts do
		local p = st.parts[name]
		if p and p.Parent then
			p.CFrame = cf
		end
	end
	for _, d in st.decos do
		local cf = parts[d.limb]
		if cf and d.part.Parent then
			d.part.CFrame = cf * d.off
		end
	end
	for name in TitanAnim.CORES do
		local core = st.cores[name]
		if core and core.Parent then
			core.CFrame = CFrame.new(TitanAnim.corePos(parts, name)) * CFrame.Angles(st.clock, st.clock * 0.7, 0)
		end
	end
	-- dust from the feet while walking
	if act.name == "walk" and math.random() < 0.08 and C.FX then
		local f = parts[if math.random() < 0.5 then "LFoot" else "RFoot"]
		C.FX.burst(f.Position, Color3.fromRGB(140, 130, 120), 4, 18, 1.2, false, 1.5)
	end
end)

function Titan.init()
	Net.on("Scene", function(name, d)
		if name == "titanStart" then
			local model = d.model
			local st = { model = model, parts = {}, cores = {}, decos = {}, clock = d.clock or 0 }
			for _, c in model:GetChildren() do
				if c.Name == "Deco" and c:GetAttribute("Limb") then
					table.insert(st.decos, { part = c, limb = c:GetAttribute("Limb"), off = c:GetAttribute("Offset") or CFrame.identity })
				end
			end
			for _, n in TitanAnim.ORDER do
				st.parts[n] = model:FindFirstChild(n)
			end
			for n in TitanAnim.CORES do
				st.cores[n] = model:FindFirstChild(n)
			end
			st.action = { name = "idle", clock0 = st.clock, from = d.root, to = d.root, moveDur = 0 }
			state = st
		elseif name == "titanAction" and state then
			state.action = { name = d.action, clock0 = d.clock0, from = d.from, to = d.to or d.from, moveDur = d.moveDur or 0 }
			if math.abs((d.clock or state.clock) - state.clock) > 0.25 then
				state.clock = d.clock or state.clock
			end
		elseif name == "titanClock" and state then
			if math.abs(d.clock - state.clock) > 0.2 then
				state.clock = d.clock
			end
		elseif name == "titanEnd" then
			state = nil
		end
	end)
end

return Titan
