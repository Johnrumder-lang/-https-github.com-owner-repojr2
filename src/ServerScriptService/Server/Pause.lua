--!nonstrict
-- Real pause (pause menu). Only when the pausing player is alone in the server:
-- every entity is anchored in place (velocities stored), AI / projectiles / the
-- director's waits stop, and everything resumes exactly where it was.
local Players = game:GetService("Players")

local S = require(script.Parent.S)

local Pause = {}
Pause.active = false
Pause.by = nil
Pause.since = 0
local anchored = {} -- [part] = { vel, ang }

local function freezeModel(m: Instance)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and not p.Anchored then
			anchored[p] = { p.AssemblyLinearVelocity, p.AssemblyAngularVelocity }
			p.Anchored = true
		end
	end
	if m:IsA("Model") then
		m:SetAttribute("Paused", true)
	end
end

function Pause.set(on: boolean, byPlayer: Player?)
	on = on == true
	if on and #Players:GetPlayers() ~= 1 then
		return false
	end
	if on == Pause.active then
		return true
	end
	Pause.active = on
	if on then
		Pause.by = byPlayer
		Pause.since = os.clock()
		for _, e in S.Entities.list do
			if e.model and e.model.Parent then
				freezeModel(e.model)
			end
		end
		local proj = workspace:FindFirstChild("Projectiles")
		if proj then
			freezeModel(proj)
		end
	else
		Pause.by = nil
		for p, v in anchored do
			if p.Parent then
				p.Anchored = false
				pcall(function()
					p.AssemblyLinearVelocity = v[1]
					p.AssemblyAngularVelocity = v[2]
				end)
			end
		end
		anchored = {}
		for _, e in S.Entities.list do
			if e.model then
				e.model:SetAttribute("Paused", nil)
			end
		end
	end
	return true
end

-- waits that stop while the game is paused (used by the director)
function Pause.wait(t: number)
	local left = t
	while left > 0 do
		local dt = task.wait(math.min(left, 0.1))
		if not Pause.active then
			left -= dt
		end
	end
end

Players.PlayerAdded:Connect(function()
	-- a second player joined: the world can't stay paused
	if Pause.active then
		Pause.set(false)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	if Pause.by == p then
		Pause.set(false)
	end
end)

return Pause
