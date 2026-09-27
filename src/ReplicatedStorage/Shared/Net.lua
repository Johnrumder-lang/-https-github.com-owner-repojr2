--!nonstrict
-- Thin wrapper around RemoteEvents. Every remote name must be listed here so the
-- validator can catch typos.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.EVENTS = {
	-- client -> server
	"Input", -- combat / movement actions
	"Menu", -- menus, dialogue choices, inventory
	-- server -> client
	"FX",
	"TimeStop",
	"Cutscene",
	"Dialogue",
	"Objective",
	"Notify",
	"Profile",
	"HitConfirm",
	"Zone",
	"Ragdoll",
	"Fade",
	"Music",
	"BossBar",
	"Ending",
	"Scene",
	"Marker",
	"Tutorial",
	"Shake",
	"Projectile",
	"PvP",
}
Net.FUNCS = { "Request" }

local isServer = RunService:IsServer()
local folder: Folder

if isServer then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing :: Folder
	else
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		folder = f
	end
	for _, n in Net.EVENTS do
		if not folder:FindFirstChild(n) then
			local e = Instance.new("RemoteEvent")
			e.Name = n
			e.Parent = folder
		end
	end
	for _, n in Net.FUNCS do
		if not folder:FindFirstChild(n) then
			local f = Instance.new("RemoteFunction")
			f.Name = n
			f.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local cache = {}
local function get(name: string): any
	local r = cache[name]
	if r then
		return r
	end
	r = folder:WaitForChild(name, 15)
	assert(r, "Missing remote " .. name)
	cache[name] = r
	return r
end

function Net.fire(player: Player, name: string, ...)
	if player and player.Parent then
		get(name):FireClient(player, ...)
	end
end

function Net.fireAll(name: string, ...)
	get(name):FireAllClients(...)
end

function Net.fireExcept(except: Player?, name: string, ...)
	local r = get(name)
	for _, p in game:GetService("Players"):GetPlayers() do
		if p ~= except then
			r:FireClient(p, ...)
		end
	end
end

function Net.send(name: string, ...)
	get(name):FireServer(...)
end

function Net.on(name: string, fn: (...any) -> ())
	local r = get(name)
	if isServer then
		return r.OnServerEvent:Connect(fn)
	else
		return r.OnClientEvent:Connect(fn)
	end
end

function Net.invoke(name: string, ...)
	return get(name):InvokeServer(...)
end

function Net.handle(name: string, fn: (...any) -> ...any)
	get(name).OnServerInvoke = fn
end

return Net
