-- A small fake Roblox object model for smoke-testing the world builders headless:
-- Instances with properties, parenting, attributes and tags; a Terrain that counts
-- voxel writes; services; task.* that never resumes background loops. Geometry is
-- only approximated (CFrames from the base stubs ignore rotation) - the point is to
-- execute every builder path and catch nil indexes / wrong API calls.

-- ------------------------------------------------------------------ CFrame extras
do
	local proto = CFrame.new()
	local CFMeta = getmetatable(proto)
	local baseIndex = CFMeta.__index
	CFMeta.__index = function(c, k)
		if k == "X" then
			return c.Position.X
		elseif k == "Y" then
			return c.Position.Y
		elseif k == "Z" then
			return c.Position.Z
		elseif k == "Rotation" then
			return CFrame.new()
		elseif k == "ToEulerAnglesYXZ" or k == "ToOrientation" then
			return function()
				return 0, 0, 0
			end
		elseif k == "PointToObjectSpace" or k == "VectorToWorldSpace" or k == "VectorToObjectSpace" then
			return function(_, v)
				return v
			end
		elseif k == "PointToWorldSpace" then
			return function(self, v)
				return self.Position + v
			end
		elseif k == "ToWorldSpace" or k == "ToObjectSpace" then
			return function(self, o)
				return CFrame.new(self.Position + o.Position)
			end
		elseif k == "Lerp" then
			return function(a, b, t)
				return CFrame.new(a.Position:Lerp(b.Position, t))
			end
		end
		return baseIndex(c, k)
	end
end

-- coroutines started by task.spawn may yield (and are then never resumed, which
-- parks every background loop); the main thread never yields
local spawned = setmetatable({}, { __mode = "k" })
local function canYield()
	return spawned[coroutine.running()] == true
end

-- ------------------------------------------------------------------ signals
local function signal()
	local s = {}
	function s:Connect(fn)
		return { Disconnect = function() end, Connected = true }
	end
	function s:Once(fn)
		return self:Connect(fn)
	end
	function s:Wait()
		if canYield() then
			coroutine.yield()
		end
		return 0.016
	end
	return s
end

-- ------------------------------------------------------------------ task
task = {
	wait = function(t)
		if canYield() then
			coroutine.yield()
		end
		return t or 0
	end,
	spawn = function(f, ...)
		local co = coroutine.create(f)
		spawned[co] = true
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 2)
		end
		return co
	end,
	defer = function(f, ...)
		return task.spawn(f, ...)
	end,
	delay = function() end,
}

-- ------------------------------------------------------------------ instances
INSTANCE_COUNT = 0
local PART_CLASSES = { Part = true, WedgePart = true, MeshPart = true, CornerWedgePart = true, TrussPart = true, Seat = true, SpawnLocation = true }
local tags = setmetatable({}, { __mode = "k" })
local InstMeta = {}
local methods = {}

local function new(class, name)
	INSTANCE_COUNT += 1
	local o = setmetatable({ __props = { ClassName = class, Name = name or class }, __children = {}, __attrs = {} }, InstMeta)
	if PART_CLASSES[class] then
		o.__props.Size = Vector3.new(4, 1, 2)
		o.__props.CFrame = CFrame.new()
		o.__props.Transparency = 0
		o.__props.CanCollide = true
		o.__props.Anchored = false
		o.__props.Material = Enum.Material.Plastic
		o.__props.Color = Color3.new(0.6, 0.6, 0.6)
	end
	return o
end

InstMeta.__index = function(o, k)
	local m = methods[k]
	if m then
		return m
	end
	local p = rawget(o, "__props")
	if k == "Parent" then
		return rawget(o, "__parent")
	elseif k == "Position" and p.CFrame then
		return p.CFrame.Position
	end
	local v = p[k]
	if v ~= nil then
		return v
	end
	-- children by name
	for _, c in rawget(o, "__children") do
		if c.__props.Name == k then
			return c
		end
	end
	-- signals and anything else
	if k:sub(-5) == "Added" or k:sub(-7) == "Removed" or k:sub(-7) == "Changed" or k == "Touched" or k == "Triggered" or k == "Died" or k == "OnServerEvent" or k == "Heartbeat" or k == "Stepped" or k == "Event" then
		local s = signal()
		p[k] = s
		return s
	end
	return nil
end

InstMeta.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "__parent")
		if old then
			local ch = rawget(old, "__children")
			local i = table.find(ch, o)
			if i then
				table.remove(ch, i)
			end
		end
		rawset(o, "__parent", v)
		if v then
			table.insert(rawget(v, "__children"), o)
		end
		return
	elseif k == "Position" then
		o.__props.CFrame = CFrame.new(v)
		return
	end
	o.__props[k] = v
end
InstMeta.__tostring = function(o)
	return o.__props.Name
end

local function isA(o, cls)
	local c = o.__props.ClassName
	if c == cls or cls == "Instance" then
		return true
	end
	if cls == "BasePart" or cls == "PVInstance" then
		return PART_CLASSES[c] == true or (cls == "PVInstance" and c == "Model")
	end
	if cls == "GuiObject" then
		return c == "Frame" or c == "TextLabel" or c == "TextButton" or c == "ImageLabel"
	end
	if cls == "Light" then
		return c == "PointLight" or c == "SpotLight" or c == "SurfaceLight"
	end
	return false
end
methods.IsA = isA
function methods:FindFirstChild(name, recursive)
	for _, c in self.__children do
		if c.__props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self.__children do
			local f = c:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildOfClass(cls)
	for _, c in self.__children do
		if c.__props.ClassName == cls then
			return c
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(cls)
	for _, c in self.__children do
		if isA(c, cls) then
			return c
		end
	end
	return nil
end
function methods:FindFirstAncestorOfClass(cls)
	local p = self.Parent
	while p do
		if p.__props.ClassName == cls then
			return p
		end
		p = p.Parent
	end
	return nil
end
function methods:GetChildren()
	return table.clone(self.__children)
end
function methods:GetDescendants()
	local out = {}
	local function walk(o)
		for _, c in o.__children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods:IsDescendantOf(a)
	local p = self.Parent
	while p do
		if p == a then
			return true
		end
		p = p.Parent
	end
	return false
end
function methods:SetAttribute(k, v)
	self.__attrs[k] = v
end
function methods:GetAttribute(k)
	return self.__attrs[k]
end
function methods:GetAttributes()
	return self.__attrs
end
function methods:GetAttributeChangedSignal()
	return signal()
end
function methods:GetPropertyChangedSignal()
	return signal()
end
function methods:Destroy()
	self.Parent = nil
end
methods.ClearAllChildren = function(self)
	self.__children = {}
end
function methods:Clone()
	local c = new(self.__props.ClassName, self.__props.Name)
	for k, v in self.__props do
		c.__props[k] = v
	end
	return c
end
local function firstPart(m)
	for _, d in m:GetDescendants() do
		if isA(d, "BasePart") then
			return d
		end
	end
	return nil
end
function methods:GetPivot()
	if isA(self, "BasePart") then
		return self.__props.CFrame
	end
	local p = self.__props.WorldPivot or (self.__props.PrimaryPart and self.__props.PrimaryPart.__props.CFrame)
	if p then
		return p
	end
	local fp = firstPart(self)
	return if fp then fp.__props.CFrame else CFrame.new()
end
function methods:PivotTo(cf)
	if isA(self, "BasePart") then
		self.__props.CFrame = cf
	else
		self.__props.WorldPivot = cf
	end
end
function methods:GetScale()
	return 1
end
function methods:ScaleTo() end
function methods:GetBoundingBox()
	return self:GetPivot(), Vector3.new(4, 4, 4)
end
function methods:SetNetworkOwner() end
function methods:GetMass()
	return 1
end
function methods:ApplyImpulse() end
function methods:MoveTo() end
function methods:ChangeState() end
function methods:SetStateEnabled() end
function methods:GetState()
	return Enum.HumanoidStateType.Running
end
function methods:LoadAnimation()
	return { Play = function() end, Stop = function() end }
end
function methods:Play() end
function methods:Emit() end
function methods:FireAllClients() end
function methods:FireClient() end
-- terrain
VOXELS = 0
VOXEL_WRITES = 0
function methods:WriteVoxels(region, res, mats, occ)
	VOXEL_WRITES += 1
	VOXELS += #mats * #mats[1] * #mats[1][1]
end
function methods:SetMaterialColor() end
function methods:Clear() end
function methods:FillBlock() end
function methods:FillBall() end
function methods:Raycast()
	return nil
end
function methods:GetPartBoundsInBox()
	return {}
end
function methods:GetPartBoundsInRadius()
	return {}
end
function methods:GetServerTimeNow()
	return os.clock()
end

Instance = { new = function(class, parent)
	local o = new(class)
	if parent then
		o.Parent = parent
	end
	return o
end }

-- ------------------------------------------------------------------ services
local DataModel = new("DataModel", "game")
workspace = new("Workspace", "Workspace")
workspace.Parent = DataModel
local terrain = new("Terrain", "Terrain")
terrain.Parent = workspace
local serviceObjs = { Workspace = workspace }
local function service(name)
	local s = serviceObjs[name]
	if s then
		return s
	end
	s = new(name, name)
	s.Parent = DataModel
	serviceObjs[name] = s
	return s
end
game = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, n)
			return service(n)
		end
	elseif k == "Workspace" then
		return workspace
	end
	return DataModel[k]
end })

local CS = service("CollectionService")
rawset(CS.__props, "ClassName", "CollectionService")
methods.AddTag = function(self, inst, tag)
	if self == CS then
		tags[inst] = tags[inst] or {}
		tags[inst][tag] = true
	else
		-- Instance:AddTag(tag)
		tags[self] = tags[self] or {}
		tags[self][inst] = true
	end
end
methods.RemoveTag = function(self, inst, tag)
	if tags[inst] then
		tags[inst][tag] = nil
	end
end
methods.HasTag = function(self, inst, tag)
	if self == CS then
		return tags[inst] ~= nil and tags[inst][tag] == true
	end
	return tags[self] ~= nil and tags[self][inst] == true
end
methods.GetTagged = function(self, tag)
	local out = {}
	for inst, t in tags do
		if t[tag] then
			table.insert(out, inst)
		end
	end
	return out
end
methods.GetInstanceAddedSignal = function()
	return signal()
end
methods.GetInstanceRemovedSignal = methods.GetInstanceAddedSignal
function TAG_COUNT(tag)
	local n = 0
	for _, t in tags do
		if t[tag] then
			n += 1
		end
	end
	return n
end

local RS = service("RunService")
methods.IsServer = function()
	return true
end
methods.IsClient = function()
	return false
end
methods.IsStudio = function()
	return false
end
methods.GetPlayers = function()
	return {}
end
methods.Create = function()
	return { Play = function() end, Cancel = function() end, Completed = signal() }
end
methods.AddItem = function() end
methods.RegisterCollisionGroup = function() end
methods.CollisionGroupSetCollidable = function() end
methods.GetTextSize = function()
	return Vector2.new(10, 10)
end

Region3 = { new = function(a, b)
	return { min = a, max = b }
end }
RaycastParams = { new = function()
	return {}
end }
OverlapParams = RaycastParams
UDim = { new = function(a, b)
	return { Scale = a, Offset = b }
end }
PhysicalProperties = { new = function()
	return {}
end }
Font = { new = function()
	return {}
end }
BrickColor = { new = function()
	return {}
end }
Rect = { new = function()
	return {}
end }
