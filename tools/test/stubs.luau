--!nonstrict
-- Minimal Roblox API stubs so shared, pure-logic modules can run in the standalone
-- Luau interpreter (tools/test/run.py bundles modules + a test script).
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end
Vector3Meta = {}
Vector3Meta.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return vec(0, 0, 0)
		end
		return vec(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Cross" then
		return function(a, b)
			return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return vec(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
		end
	end
	return nil
end
Vector3Meta.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then
		return vec(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return vec(a.X * b, a.Y * b, a.Z * b)
	end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	if type(b) == "number" then
		return vec(a.X / b, a.Y / b, a.Z / b)
	end
	return vec(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3Meta.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
Vector3Meta.__tostring = function(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
Vector3 = { new = vec, zero = vec(0, 0, 0), one = vec(1, 1, 1), xAxis = vec(1, 0, 0), yAxis = vec(0, 1, 0), zAxis = vec(0, 0, 1) }
Vector2 = { new = function(x, y)
	return { X = x or 0, Y = y or 0 }
end, zero = { X = 0, Y = 0 } }

local CFMeta = {}
local function cf(pos)
	return setmetatable({ Position = pos or vec(0, 0, 0) }, CFMeta)
end
CFMeta.__index = function(c, k)
	if k == "LookVector" then
		return vec(0, 0, -1)
	elseif k == "RightVector" then
		return vec(1, 0, 0)
	elseif k == "UpVector" then
		return vec(0, 1, 0)
	elseif k == "Inverse" or k == "Lerp" or k == "ToObjectSpace" or k == "PointToWorldSpace" then
		return function(self)
			return self
		end
	end
	return nil
end
CFMeta.__mul = function(a, b)
	if getmetatable(b) == Vector3Meta then
		return a.Position + b
	end
	return cf(a.Position + b.Position)
end
CFMeta.__add = function(a, b)
	return cf(a.Position + b)
end
CFMeta.__sub = function(a, b)
	return cf(a.Position - b)
end
CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cf(x)
		end
		return cf(vec(x or 0, y or 0, z or 0))
	end,
	Angles = function()
		return cf()
	end,
	fromMatrix = function(p)
		return cf(p)
	end,
	lookAt = function(p)
		return cf(p)
	end,
	fromOrientation = function()
		return cf()
	end,
	fromAxisAngle = function()
		return cf()
	end,
	identity = cf(),
}

local function c3(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, {
		__index = function(_, k)
			if k == "Lerp" then
				return function(a, o, t)
					return c3(a.R + (o.R - a.R) * t, a.G + (o.G - a.G) * t, a.B + (o.B - a.B) * t)
				end
			end
			return nil
		end,
		__tostring = function(c)
			return string.format("rgb(%d,%d,%d)", c.R * 255, c.G * 255, c.B * 255)
		end,
	})
end
Color3 = { new = c3, fromRGB = function(r, g, b)
	return c3(r / 255, g / 255, b / 255)
end }

local function enumNode(path)
	return setmetatable({ Name = path }, {
		__index = function(t, k)
			local n = enumNode(path .. "." .. k)
			rawset(t, k, n)
			return n
		end,
		__tostring = function()
			return path
		end,
	})
end
Enum = enumNode("Enum")

local RandomMeta = {}
RandomMeta.__index = RandomMeta
function RandomMeta:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local f = self.s / 2147483648
	if a then
		return a + (b - a) * f
	end
	return f
end
function RandomMeta:NextInteger(a, b)
	return math.floor(self:NextNumber() * (b - a + 1)) + a
end
Random = { new = function(seed)
	return setmetatable({ s = (math.floor(seed or 1) % 2147483647) + 1 }, RandomMeta)
end }

NumberSequence = { new = function(...)
	return { ... }
end }
NumberSequenceKeypoint = { new = function(...)
	return { ... }
end }
ColorSequence = NumberSequence
ColorSequenceKeypoint = NumberSequenceKeypoint
NumberRange = NumberSequence
UDim2 = { new = function(...)
	return { ... }
end, fromOffset = function(...)
	return { ... }
end, fromScale = function(...)
	return { ... }
end }

tick = os.clock
local services = {}
game = {
	GetService = function(_, name)
		services[name] = services[name] or setmetatable({ Name = name }, {
			__index = function()
				return function() end
			end,
		})
		return services[name]
	end,
}
workspace = game:GetService("Workspace")
