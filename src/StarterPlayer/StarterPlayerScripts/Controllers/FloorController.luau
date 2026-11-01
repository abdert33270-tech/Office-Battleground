--[[
	FloorController — effets locaux des étages et événements (remote "FloorFX" de FloorService/EventService).
	Warning : tremblement crescendo + poussière qui tombe + grondement.
	Collapse : gros tremblement + fracas. Land : « THUD! » + onde de choc. Fade : fondu blanc (NEW BUILDING).
	Puff / Stomp / Splat : petits effets des événements.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local CartoonFX = require(Shared.Modules.CartoonFX)
local EventsConfig = require(Shared.Config.Events)

local FloorController = {}
FloorController.Priority = 60

local player = Players.LocalPlayer
local rng = Random.new()
local fadeFrame = nil

local function fxFolder()
	return workspace:FindFirstChild("FX") or workspace
end

local function playSound(id, volume, duration)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, duration or 8)
	return s
end

local function ring(pos, radius, color, time)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color or Color3.new(1, 1, 1)
	p.Transparency = 0.2
	p.Size = Vector3.new(0.3, 2, 2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = fxFolder()
	TweenService:Create(p, TweenInfo.new(time or 0.45, Enum.EasingStyle.Quad), { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, (time or 0.45) + 0.05)
end

local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- poussière / gravats qui tombent autour du joueur
local function dust(amount)
	local root = myRoot()
	if not root then
		return
	end
	for _ = 1, amount do
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		local s = rng:NextNumber(0.2, 0.7)
		p.Size = Vector3.new(s, s, s)
		p.Color = Color3.fromRGB(rng:NextInteger(150, 200), rng:NextInteger(145, 190), rng:NextInteger(135, 180))
		p.Position = root.Position + Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(18, 28), rng:NextNumber(-30, 30))
		p.Parent = fxFolder()
		Debris:AddItem(p, 2)
	end
end

local handlers = {}

function handlers.Warning(d)
	local dur = d.dur or 10
	local rumble = playSound(EventsConfig.Sounds.Rumble, 0.2, dur + 1)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - t0) / dur, 0, 1)
		if a >= 1 then
			conn:Disconnect()
			return
		end
		rumble.Volume = 0.2 + a * 0.7
		CartoonFX.shake(0.08 + a * 0.45)
		if rng:NextNumber() < 0.15 + a * 0.6 then
			dust(1 + math.floor(a * 4))
		end
	end)
end

function handlers.Collapse(d)
	playSound(EventsConfig.Sounds.Crumble, 1, 8)
	CartoonFX.sound("Crash", nil, 0.9)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 1.4 then
			conn:Disconnect()
			return
		end
		CartoonFX.shake(1.2 * (1 - t / 1.4) + 0.2)
	end)
	local root = myRoot()
	if root then
		CartoonFX.word(root.Position + Vector3.new(0, 3, 0), "CRACK!", 1.2, "Heavy")
	end
end

function handlers.Land(d)
	if not d.p then
		return
	end
	local mine = d.c and d.c == player.Character
	CartoonFX.word(d.p + Vector3.new(0, 1, 0), "THUD!", mine and 1.0 or 0.7, "Land")
	CartoonFX.puff(d.p, 1.4)
	ring(d.p, 9, Color3.fromRGB(255, 255, 255), 0.5)
	CartoonFX.sound("Thud", d.p, 0.9)
	if mine then
		CartoonFX.shake(0.9)
	end
end

function handlers.Fade(d)
	if not fadeFrame then
		local gui = Instance.new("ScreenGui")
		gui.Name = "FloorFade"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 50
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		fadeFrame = Instance.new("Frame")
		fadeFrame.Size = UDim2.fromScale(1, 1)
		fadeFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		fadeFrame.BackgroundTransparency = 1
		fadeFrame.BorderSizePixel = 0
		fadeFrame.Parent = gui
	end
	TweenService:Create(fadeFrame, TweenInfo.new(d.dir == "out" and 0.6 or 0.8), { BackgroundTransparency = d.dir == "out" and 0 or 1 }):Play()
end

function handlers.Puff(d)
	if d.p then
		CartoonFX.puff(d.p, d.big and 4 or 1.2)
		if d.big then
			CartoonFX.word(d.p + Vector3.new(0, 6, 0), "POOF!", 1.2, "Heavy")
		end
	end
end

function handlers.Stomp(d)
	if not d.p then
		return
	end
	ring(d.p, 14, Color3.fromRGB(255, 255, 255), 0.4)
	CartoonFX.puff(d.p, 1.8)
	CartoonFX.sound("Thud", d.p, 1)
	local root = myRoot()
	if root then
		local dist = (root.Position - d.p).Magnitude
		if dist < 90 then
			CartoonFX.shake(0.9 * (1 - dist / 90))
		end
	end
end

function handlers.Splat(d)
	if d.p then
		CartoonFX.word(d.p + Vector3.new(0, 1, 0), "SPLAT!", 0.4, "Splat")
		CartoonFX.sound("Splat", d.p, 0.6)
	end
end

function FloorController.init()
	Net.get("FloorFX").OnClientEvent:Connect(function(d)
		local h = type(d) == "table" and handlers[d.k]
		if h then
			local ok, err = pcall(h, d)
			if not ok then
				warn("[FloorController]", d.k, err)
			end
		end
	end)
end

return FloorController
