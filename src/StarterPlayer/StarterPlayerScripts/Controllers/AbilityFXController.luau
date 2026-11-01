--[[
	AbilityFXController — effets visuels des attaques de personnages et des transformations (client).
	Écoute la remote FX : Ability (nom crié au-dessus de la tête), Transform, Cone, Grab, Flood, Lockdown, Reveal, ProjPop.
	Passif du Security Guard (On Patrol) : contour à travers les murs des ennemis proches à faible PV.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local CartoonFX = require(Shared.Modules.CartoonFX)
local ProcAnim = require(Shared.Modules.ProcAnim)
local Attacks = require(Shared.Config.Attacks)

local AbilityFXController = {}
AbilityFXController.Priority = 40

local player = Players.LocalPlayer
local rng = Random.new()
local handlers = {}

local function mine(model)
	return model ~= nil and model == player.Character
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = workspace.FX
	return p
end

------------------------------------------------------------------------
-- Accessoires de main pendant une attaque (repère : bras droit, main en (0,-1,0),
-- -Y = prolongement du bras, -X = vers la main gauche)
------------------------------------------------------------------------
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2) -- cylindre dans l'axe du bras
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local C = {
	white = Color3.fromRGB(250, 250, 250), brown = Color3.fromRGB(120, 70, 40), dark = Color3.fromRGB(30, 30, 35),
	steel = Color3.fromRGB(200, 205, 215), yellow = Color3.fromRGB(255, 215, 0), blue = Color3.fromRGB(90, 180, 255),
	grey = Color3.fromRGB(150, 160, 175), orange = Color3.fromRGB(255, 150, 40), red = Color3.fromRGB(220, 50, 50),
}
-- { taille, décalage, couleur, forme }
local PROPS = {
	BigCup = { { Vector3.new(1.5, 1.1, 1.1), CFrame.new(0, -1.5, 0) * ALONG_Y, C.white, CYL }, { Vector3.new(0.5, 1.15, 1.15), CFrame.new(0, -1.4, 0) * ALONG_Y, Color3.fromRGB(150, 95, 50), CYL }, { Vector3.new(0.2, 1.1, 1.1), CFrame.new(0, -2.3, 0) * ALONG_Y, Color3.fromRGB(60, 40, 30), CYL } },
	PaperStack = { { Vector3.new(1.6, 0.5, 1.3), CFrame.new(-0.75, -1.4, 0), C.white }, { Vector3.new(1.62, 0.06, 1.32), CFrame.new(-0.75, -1.3, 0), Color3.fromRGB(220, 220, 220) } },
	StickyPad = { { Vector3.new(1.25, 0.3, 1.25), CFrame.new(0, -1.25, -0.1), Color3.fromRGB(255, 235, 60) }, { Vector3.new(1.3, 0.06, 1.3), CFrame.new(0, -1.43, -0.1), Color3.fromRGB(255, 200, 40) } },
	BubbleWand = { { Vector3.new(2.2, 0.18, 0.18), CFrame.new(0, -2.0, 0) * ALONG_Y, C.yellow, CYL }, { Vector3.new(0.14, 1.5, 1.5), CFrame.new(0, -3.7, 0) * ALONG_Z, Color3.fromRGB(255, 120, 200), CYL }, { Vector3.new(0.16, 1.15, 1.15), CFrame.new(0, -3.7, 0) * ALONG_Z, Color3.fromRGB(200, 240, 255), CYL } },
	EspressoCup = { { Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -1.25, 0) * ALONG_Y, C.white, CYL }, { Vector3.new(0.05, 0.42, 0.42), CFrame.new(0, -1.0, 0) * ALONG_Y, Color3.fromRGB(70, 40, 20), CYL } },
	Briefcase = { { Vector3.new(0.5, 1.3, 1.8), CFrame.new(0, -1.8, 0), Color3.fromRGB(110, 60, 30) }, { Vector3.new(0.2, 0.3, 0.6), CFrame.new(0, -1.1, 0), C.dark } },
	Mop = { { Vector3.new(4.6, 0.25, 0.25), CFrame.new(-0.5, -2.8, 0) * ALONG_Y, C.brown, CYL }, { Vector3.new(1.8, 0.6, 1.0), CFrame.new(-0.5, -5.2, 0), C.grey }, { Vector3.new(1.6, 0.4, 0.8), CFrame.new(-0.5, -5.6, 0), Color3.fromRGB(230, 230, 235) } },
	WetSign = { { Vector3.new(1.8, 2.4, 0.2), CFrame.new(-0.75, -2.4, 0.4) * CFrame.Angles(0.35, 0, 0), C.yellow }, { Vector3.new(1.8, 2.4, 0.2), CFrame.new(-0.75, -2.4, -0.4) * CFrame.Angles(-0.35, 0, 0), C.yellow }, { Vector3.new(1.4, 0.25, 0.22), CFrame.new(-0.75, -2.2, -0.5) * CFrame.Angles(-0.35, 0, 0), C.dark } },
	Bucket = { { Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, -1.9, 0) * ALONG_Y, C.grey, CYL }, { Vector3.new(0.1, 1.2, 1.2), CFrame.new(0, -1.25, 0) * ALONG_Y, C.blue, CYL } },
	BigBucket = { { Vector3.new(2.0, 2.2, 2.2), CFrame.new(-0.75, -2.0, 0) * ALONG_Y, C.grey, CYL }, { Vector3.new(0.1, 2.0, 2.0), CFrame.new(-0.75, -3.0, 0) * ALONG_Y, C.blue, CYL } },
	PowerWasher = { { Vector3.new(0.7, 1.0, 0.7), CFrame.new(-0.3, -1.4, 0), C.yellow }, { Vector3.new(2.8, 0.2, 0.2), CFrame.new(-0.3, -3.2, 0) * ALONG_Y, Color3.fromRGB(80, 80, 90), CYL }, { Vector3.new(0.4, 0.35, 0.35), CFrame.new(-0.3, -4.6, 0) * ALONG_Y, C.dark, CYL } },
	TrayShield = { { Vector3.new(2.8, 0.2, 2.0), CFrame.new(-0.75, -1.6, 0), C.orange }, { Vector3.new(2.5, 0.22, 1.7), CFrame.new(-0.75, -1.55, 0), Color3.fromRGB(255, 190, 90) } },
	Ladle = { { Vector3.new(2.6, 0.25, 0.25), CFrame.new(0, -2.3, 0) * ALONG_Y, C.steel, CYL }, { Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, -3.8, -0.3), C.steel, BALL }, { Vector3.new(0.1, 0.95, 0.95), CFrame.new(0, -3.55, -0.6) * ALONG_Z, C.orange, CYL } },
	Meat = { { Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, -1.5, 0), Color3.fromRGB(140, 90, 60), BALL }, { Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.4, -1.9, -0.3), Color3.fromRGB(120, 200, 80), BALL } },
	GiantPan = { { Vector3.new(0.35, 2.0, 0.35), CFrame.new(-0.6, -2.1, 0), C.dark }, { Vector3.new(0.35, 3.6, 3.6), CFrame.new(-0.6, -4.6, 0) * ALONG_Z, C.dark, CYL }, { Vector3.new(0.36, 1.4, 1.4), CFrame.new(-0.6, -4.6, -0.05) * ALONG_Z, C.white, CYL }, { Vector3.new(0.6, 0.6, 0.6), CFrame.new(-0.6, -4.6, -0.3), C.yellow, BALL } },
	SoupPot = { { Vector3.new(1.4, 1.6, 1.6), CFrame.new(-0.75, -1.6, 0) * ALONG_Y, C.steel, CYL }, { Vector3.new(0.1, 1.4, 1.4), CFrame.new(-0.75, -2.32, 0) * ALONG_Y, C.orange, CYL } },
	Handcuffs = { { Vector3.new(0.6, 0.6, 0.15), CFrame.new(-0.2, -1.2, -0.3), C.steel }, { Vector3.new(0.6, 0.6, 0.15), CFrame.new(0.3, -1.2, -0.3), C.steel } },
	FlashlightProp = { { Vector3.new(1.6, 0.4, 0.4), CFrame.new(0, -1.7, 0) * ALONG_Y, C.dark, CYL }, { Vector3.new(0.1, 0.5, 0.5), CFrame.new(0, -2.52, 0) * ALONG_Y, Color3.fromRGB(255, 250, 170), CYL } },
	Walkie = { { Vector3.new(0.45, 1.0, 0.3), CFrame.new(0, -1.3, -0.2), C.dark }, { Vector3.new(0.08, 0.8, 0.08), CFrame.new(0.12, -0.5, -0.2), C.dark } },
	WhistleProp = { { Vector3.new(0.5, 0.3, 0.3), CFrame.new(0, -1.15, -0.25), C.steel }, { Vector3.new(0.05, 0.9, 0.05), CFrame.new(0, -0.7, -0.25), C.red } },
	Baton = { { Vector3.new(2.6, 0.3, 0.3), CFrame.new(0, -2.3, 0) * ALONG_Y, C.dark, CYL } },
}

-- accessoires ajoutés par les modules de Content
require(Shared.Modules.ContentLoader).merge(PROPS, "Props")

local function attachProp(character, name, duration)
	local def = PROPS[name or ""]
	local armPart = character and character:FindFirstChild("Right Arm")
	if not def or not armPart then
		return
	end
	local model = Instance.new("Model")
	model.Name = "MoveProp"
	for _, d in ipairs(def) do
		local p = Instance.new("Part")
		p.Size = d[1]
		p.Color = d[3]
		if d[4] then
			p.Shape = d[4]
		end
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = armPart.CFrame * d[2]
		local w = Instance.new("WeldConstraint")
		w.Part0 = armPart
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	model.Parent = character
	character:SetAttribute("PropBusy", (character:GetAttribute("PropBusy") or 0) + 1)
	task.delay(duration or 0.8, function()
		model:Destroy()
		if character.Parent then
			character:SetAttribute("PropBusy", math.max(0, (character:GetAttribute("PropBusy") or 1) - 1))
		end
	end)
end

-- images fantômes derrière le personnage (ruées)
local function afterimages(character, duration, color)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration and character.Parent do
			for _, n in ipairs({ "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
				local src = character:FindFirstChild(n)
				if src then
					local g = part({ Size = src.Size * (n == "Head" and Vector3.new(1.2, 1.2, 1.2) or Vector3.one), CFrame = src.CFrame, Color = color, Transparency = 0.45 })
					TweenService:Create(g, TweenInfo.new(0.3), { Transparency = 1 }):Play()
					Debris:AddItem(g, 0.32)
				end
			end
			task.wait(0.05)
		end
	end)
end

-- traînée de petites parts (gouttes, bulles, feuilles…)
local function trail(character, duration, colors, size, rise)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration and character.Parent do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local pos = root.Position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-2.5, 0.5), rng:NextNumber(-1, 1))
				local b = part({ Shape = BALL, Size = Vector3.one * (size or 0.6), Position = pos, Color = colors[rng:NextInteger(1, #colors)], Transparency = 0.15 })
				TweenService:Create(b, TweenInfo.new(0.6), { Position = pos + Vector3.new(0, rise or 0, 0), Size = Vector3.one * (size or 0.6) * 1.8, Transparency = 1 }):Play()
				Debris:AddItem(b, 0.65)
			end
			task.wait(0.025)
		end
	end)
end

-- anneaux qui s'élargissent autour du personnage
local function rings(character, count, radius, color, height)
	task.spawn(function()
		for _ = 1, count do
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			local r = part({ Shape = CYL, Size = Vector3.new(0.25, 2, 2), CFrame = CFrame.new(root.Position + Vector3.new(0, height or 0, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Transparency = 0.2 })
			TweenService:Create(r, TweenInfo.new(0.45), { Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 }):Play()
			Debris:AddItem(r, 0.5)
			task.wait(0.12)
		end
	end)
end

-- effets propres à chaque attaque (en plus de l'accessoire, de l'animation et de l'effet de coup)
local ORANGE, JBLUE, PINKL, NAVY = Color3.fromRGB(255, 170, 40), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 110, 140), Color3.fromRGB(60, 80, 140)
local COFFEE, CREAM = Color3.fromRGB(120, 70, 40), Color3.fromRGB(210, 160, 110)
local WATER, FOAM = Color3.fromRGB(110, 200, 255), Color3.fromRGB(220, 245, 255)
local SIREN_R, SIREN_B = Color3.fromRGB(255, 50, 50), Color3.fromRGB(60, 140, 255)

local function rootOf(c)
	return c and c:FindFirstChild("HumanoidRootPart")
end
-- position devant le personnage (d studs devant, h au-dessus du centre)
local function ahead(r, d, h)
	return r.Position + r.CFrame.LookVector * d + Vector3.new(0, h or 0, 0)
end
local function feet(r)
	return r.Position - Vector3.new(0, 2.8, 0)
end
local function at(t, c, fn)
	task.delay(t, function()
		local r = rootOf(c)
		if r and r.Parent then
			fn(r)
		end
	end)
end

local MOVE_FX = {
	------------------------------------------------------------------ THE INTERN
	CoffeeRun = function(c, d)
		local r = rootOf(c)
		if not r then return end
		CartoonFX.dust(feet(r), 5, nil, 8)
		CartoonFX.airRing(ahead(r, 1, 0), r.CFrame.LookVector, 7, ORANGE, 0.25)
		trail(c, d.dur, { COFFEE, CREAM }, 0.55, 1)
		afterimages(c, d.dur * 0.9, ORANGE)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), ORANGE, d.dur, 1.2, 1)
		if mine(c) then
			CartoonFX.speedLines(d.dur, ORANGE)
		end
		at(0.3, c, function(r2)
			CartoonFX.shards(ahead(r2, 2.5, 0.5), 12, { COFFEE, CREAM, C.white }, 1)
			CartoonFX.airRing(ahead(r2, 2, 0.5), r2.CFrame.LookVector, 9, COFFEE, 0.2)
		end)
	end,
	PaperJam = function(c)
		at(0.12, c, function(r)
			for i = 1, 14 do -- tempête de feuilles en éventail
				local a = math.rad(rng:NextNumber(-22, 22))
				local dir = CFrame.Angles(0, a, 0) * r.CFrame.LookVector
				local start = ahead(r, 1.5, 0.8)
				local s = part({ Size = Vector3.new(1.1, 0.05, 1.4), CFrame = CFrame.new(start) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = C.white })
				TweenService:Create(s, TweenInfo.new(0.5), { CFrame = CFrame.new(start + dir * rng:NextNumber(10, 18) + Vector3.new(0, rng:NextNumber(-1, 2), 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1 }):Play()
				Debris:AddItem(s, 0.52)
			end
			CartoonFX.airRing(ahead(r, 1.5, 0.8), r.CFrame.LookVector, 8, C.white, 0.22)
			CartoonFX.airRing(ahead(r, 3, 0.8), r.CFrame.LookVector, 6, ORANGE, 0.22)
			CartoonFX.casterShake(c, 0.25)
		end)
	end,
	StickySlap = function(c)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), Color3.fromRGB(255, 235, 60), 0.4, 1, 1.1)
		at(0.15, c, function(r)
			CartoonFX.slashArc(r.CFrame * CFrame.new(0, 0.6, 0), 3.6, Color3.fromRGB(255, 235, 60), -70, 85, 0.07, -12, 0.6)
			CartoonFX.airRing(ahead(r, 3, 0.6), r.CFrame.LookVector + r.CFrame.RightVector * 0.6, 6, Color3.fromRGB(255, 235, 60), 0.2)
			for _ = 1, 6 do -- post-it qui volent
				local p0 = ahead(r, 3, 0.8)
				local n = part({ Size = Vector3.new(0.8, 0.05, 0.8), CFrame = CFrame.new(p0), Color = Color3.fromRGB(255, 235, 60) })
				TweenService:Create(n, TweenInfo.new(0.6), { CFrame = CFrame.new(p0 + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(1, 4), rng:NextNumber(-3, 3))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1 }):Play()
				Debris:AddItem(n, 0.62)
			end
			CartoonFX.casterShake(c, 0.35)
		end)
	end,
	EspressoCounter = function(c)
		at(0.05, c, function(r)
			CartoonFX.swirl(r.Position + Vector3.new(0, 1.5, 0), 1.2, 3, { COFFEE, CREAM, C.white }, 10, 0.4)
		end)
		task.spawn(function() -- tremblements de caféine : images fantômes et étincelles
			local t0 = os.clock()
			task.wait(0.1)
			while os.clock() - t0 < 1.0 and c.Parent and (c:GetAttribute("CounterUntil") or 0) > 0 do
				local r = rootOf(c)
				if r then
					for _, n in ipairs({ "Torso", "Head" }) do
						local src = c:FindFirstChild(n)
						if src then
							local g = part({ Size = src.Size, CFrame = src.CFrame * CFrame.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.3, 0.3)), Color = ORANGE, Transparency = 0.55 })
							TweenService:Create(g, TweenInfo.new(0.15), { Transparency = 1 }):Play()
							Debris:AddItem(g, 0.16)
						end
					end
					CartoonFX.sparks(r.Position + Vector3.new(0, 2.5, 0), 2, ORANGE)
				end
				task.wait(0.07)
			end
		end)
	end,
	OvertimeFlurry = function(c)
		task.spawn(function()
			for i = 1, 8 do
				local r = rootOf(c)
				if not r then return end
				local side = (i % 2 == 0) and -1 or 1
				local pos = ahead(r, 2, rng:NextNumber(-0.2, 1)) + r.CFrame.RightVector * side * rng:NextNumber(0.4, 1.2)
				local f = part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.lookAt(pos, pos + r.CFrame.LookVector), Color = Color3.fromRGB(255, 220, 170), Transparency = 0.25 })
				TweenService:Create(f, TweenInfo.new(0.14), { CFrame = f.CFrame * CFrame.new(0, 0, -3), Transparency = 1 }):Play()
				Debris:AddItem(f, 0.15)
				CartoonFX.airRing(pos + r.CFrame.LookVector, r.CFrame.LookVector, 3, ORANGE, 0.12)
				task.wait(0.06)
			end
		end)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), ORANGE, 0.8, 1, 0.9)
		CartoonFX.trailOn(c:FindFirstChild("Left Arm"), ORANGE, 0.55, 1, 0.9)
		at(0.58, c, function(r)
			CartoonFX.airRing(ahead(r, 2, 1.5), (r.CFrame.LookVector + Vector3.new(0, 1.2, 0)), 11, ORANGE, 0.3)
			CartoonFX.pillar(ahead(r, 2.5, 0), 1.6, 10, ORANGE, 0.3)
			CartoonFX.dust(feet(r), 6)
			CartoonFX.casterShake(c, 0.7)
			if mine(c) then
				CartoonFX.speedLines(0.3, ORANGE)
			end
		end)
	end,
	DeadlineDrop = function(c)
		at(0.08, c, function(r) -- tic-tac de la montre
			CartoonFX.word(r.Position + Vector3.new(-1.5, 3.5, 0), "TICK TOCK!", 0.6, "Light")
			CartoonFX.sound("Ding", r.Position, 0.7)
		end)
		at(0.32, c, function(r)
			CartoonFX.pillar(r.Position, 1.2, 18, ORANGE, 0.35)
			CartoonFX.implode(r.Position + Vector3.new(0, 4.5, 0), 6, { ORANGE, C.white }, 12, 0.25)
			CartoonFX.light(r.Position + Vector3.new(0, 4, 0), ORANGE, 18, 4, 0.4)
		end)
	end,

	------------------------------------------------------------------ THE JANITOR
	MopSweep = function(c)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), JBLUE, 0.6, 4.6, 1.2)
		at(0.24, c, function(r)
			CartoonFX.slashArc(r.CFrame * CFrame.new(0, -2.2, 0), 6.5, WATER, -10, 370, 0.22, 0, 0.5)
			CartoonFX.shockwave(feet(r) + Vector3.new(0, 0.2, 0), 8, JBLUE)
			CartoonFX.dust(feet(r), 7, FOAM, 12)
			CartoonFX.shards(feet(r) + Vector3.new(0, 0.6, 0), 14, { WATER, FOAM }, 1)
			CartoonFX.casterShake(c, 0.4)
		end)
	end,
	WetFloorSign = function(c)
		at(0.2, c, function(r)
			local p = feet(r) + r.CFrame.LookVector * 7
			CartoonFX.shockwave(p + Vector3.new(0, 0.2, 0), 9, WATER)
			CartoonFX.shockwave(p + Vector3.new(0, 0.25, 0), 5, C.yellow)
			CartoonFX.shards(p + Vector3.new(0, 1, 0), 16, { WATER, FOAM }, 1.1)
			CartoonFX.cracks(p, 5, 3)
			CartoonFX.light(p + Vector3.new(0, 2, 0), WATER, 14, 3, 0.3)
			CartoonFX.casterShake(c, 0.4)
		end)
	end,
	BucketToss = function(c)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), WATER, 0.4, 1.4, 1)
		at(0.15, c, function(r)
			CartoonFX.shards(ahead(r, 1.5, 2), 10, { WATER, FOAM }, 0.8)
			CartoonFX.airRing(ahead(r, 1.5, 1.5), r.CFrame.LookVector + Vector3.new(0, 0.6, 0), 5, WATER, 0.2)
		end)
	end,
	PowerWash = function(c, d)
		-- jet d'eau continu qui suit la lance
		local jet = part({ Size = Vector3.new(1, 1, 1), Color = WATER, Transparency = 0.35 })
		local core = part({ Size = Vector3.new(1, 1, 1), Color = FOAM, Transparency = 0.2 })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local r = rootOf(c)
			if el > (d.dur or 1.7) or not r then
				conn:Disconnect()
				jet:Destroy()
				core:Destroy()
				return
			end
			local from = ahead(r, 2.6, 0.4)
			local to = ahead(r, 20, -1.5)
			local len = (to - from).Magnitude
			local w = 1.1 + math.sin(el * 40) * 0.25
			jet.Size = Vector3.new(w, w, len)
			jet.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			core.Size = Vector3.new(w * 0.45, w * 0.45, len * 0.95)
			core.CFrame = jet.CFrame
		end)
		task.spawn(function()
			while os.clock() - t0 < (d.dur or 1.7) do
				local r = rootOf(c)
				if not r then return end
				local p = ahead(r, 20, -2)
				CartoonFX.shards(p, 3, { WATER, FOAM }, 0.6)
				local m = part({ Shape = BALL, Size = Vector3.one * 2, Position = p, Color = FOAM, Transparency = 0.4 })
				TweenService:Create(m, TweenInfo.new(0.4), { Size = Vector3.one * 5, Transparency = 1 }):Play()
				Debris:AddItem(m, 0.42)
				if mine(c) then
					CartoonFX.shake(0.12)
				end
				task.wait(0.09)
			end
		end)
	end,
	SoapSlide = function(c, d)
		local r = rootOf(c)
		if r then
			CartoonFX.shards(feet(r) + Vector3.new(0, 0.5, 0), 12, { FOAM, Color3.fromRGB(255, 200, 255) }, 0.9)
			CartoonFX.dust(feet(r), 5, FOAM)
		end
		trail(c, d.dur, { FOAM, Color3.fromRGB(255, 200, 255), WATER }, 0.9, 2)
		afterimages(c, d.dur, FOAM)
		if mine(c) then
			CartoonFX.speedLines(d.dur, FOAM)
		end
	end,
	BubblePrison = function(c)
		at(0.05, c, function(r)
			CartoonFX.implode(ahead(r, 1, 1.8), 4, { FOAM, Color3.fromRGB(255, 200, 255) }, 8, 0.2)
		end)
		at(0.3, c, function(r)
			CartoonFX.airRing(ahead(r, 2, 1.5), r.CFrame.LookVector, 6, FOAM, 0.25)
		end)
	end,

	------------------------------------------------------------------ THE LUNCH LADY
	TrayGuard = function(c, d)
		local r = rootOf(c)
		if not r then return end
		CartoonFX.shockwave(feet(r) + Vector3.new(0, 0.2, 0), 5, C.orange)
		-- bouclier lumineux devant elle tant que la garde tient
		local shield = part({ Shape = CYL, Size = Vector3.new(0.2, 5.5, 5.5), Color = Color3.fromRGB(255, 200, 110), Transparency = 0.6 })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local rr = rootOf(c)
			if el > (d.dur or 1.7) or not rr then
				conn:Disconnect()
				shield:Destroy()
				return
			end
			local s = 5.5 + math.sin(el * 12) * 0.25
			shield.Size = Vector3.new(0.2, s, s)
			shield.CFrame = CFrame.lookAt(ahead(rr, 2.4, 0.6), ahead(rr, 5, 0.6)) * CFrame.Angles(0, math.pi / 2, 0)
		end)
		CartoonFX.casterShake(c, 0.25)
	end,
	LadleBonk = function(c)
		CartoonFX.trailOn(c:FindFirstChild("Right Arm"), Color3.fromRGB(230, 235, 245), 0.45, 3.2, 1.2)
		at(0.1, c, function(r)
			CartoonFX.dust(feet(r), 4, nil, 6)
		end)
		at(0.22, c, function(r)
			CartoonFX.slashArc(r.CFrame * CFrame.new(0, 0.5, 0), 4, C.orange, -90, 60, 0.06, 90, 0.5)
		end)
		at(0.26, c, function(r)
			local p = feet(r) + r.CFrame.LookVector * 3.5
			CartoonFX.shockwave(p + Vector3.new(0, 0.2, 0), 7, PINKL)
			CartoonFX.cracks(p, 6, 3.5)
			CartoonFX.shards(p + Vector3.new(0, 1, 0), 12, { C.orange, Color3.fromRGB(255, 220, 120) }, 1.1)
			CartoonFX.casterShake(c, 0.6)
		end)
	end,
	MysteryMeat = function(c)
		at(0.18, c, function(r)
			local p = ahead(r, 1.5, 2)
			CartoonFX.shards(p, 8, { Color3.fromRGB(140, 90, 60), Color3.fromRGB(120, 200, 80) }, 0.8)
			for _ = 1, 5 do -- odeur verte
				local s = part({ Shape = BALL, Size = Vector3.one * 0.8, Position = p, Color = Color3.fromRGB(150, 220, 90), Transparency = 0.4 })
				TweenService:Create(s, TweenInfo.new(0.8), { Position = p + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1, 3), rng:NextNumber(-2, 2)), Size = Vector3.one * 2, Transparency = 1 }):Play()
				Debris:AddItem(s, 0.82)
			end
		end)
	end,
	FryingPanSmash = function(c)
		at(0.15, c, function(r)
			CartoonFX.implode(r.Position + Vector3.new(0, 4, 0), 7, { PINKL, C.white }, 12, 0.25)
		end)
		at(0.44, c, function(r)
			CartoonFX.quake(feet(r) + r.CFrame.LookVector * 2.5, 13, PINKL, 1.4)
			CartoonFX.shards(r.Position, 16, { C.white, C.yellow }, 1.3)
			CartoonFX.sparks(feet(r) + r.CFrame.LookVector * 2.5, 30, C.orange)
			CartoonFX.sound("MetalHit", r.Position, 1)
			CartoonFX.casterShake(c, 1.1)
		end)
	end,
	HotSoup = function(c)
		trail(c, 0.6, { Color3.fromRGB(240, 240, 240) }, 1.2, 4)
		at(0.17, c, function(r)
			for i = 1, 14 do -- gerbe de soupe en arc
				local a = math.rad(rng:NextNumber(-38, 38))
				local dir = CFrame.Angles(0, a, 0) * r.CFrame.LookVector
				local start = ahead(r, 2, 1)
				local b = part({ Shape = BALL, Size = Vector3.one * rng:NextNumber(0.6, 1.1), Position = start, Color = (i % 3 == 0) and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(255, 150, 40) })
				TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = start + dir * rng:NextNumber(8, 15) - Vector3.new(0, 3, 0), Transparency = 0.6 }):Play()
				Debris:AddItem(b, 0.36)
			end
			CartoonFX.light(ahead(r, 4, 1), Color3.fromRGB(255, 150, 40), 16, 3, 0.4)
		end)
	end,
	FoodCartRush = function(c)
		local r = rootOf(c)
		if r then
			CartoonFX.dust(feet(r), 5, nil, 8)
		end
		task.delay(0.12, function()
			afterimages(c, 0.8, PINKL)
		end)
	end,

	------------------------------------------------------------------ THE SECURITY GUARD
	Detain = function(c)
		at(0.08, c, function(r)
			CartoonFX.sparks(ahead(r, 2.5, 1), 10, C.steel)
			CartoonFX.airRing(ahead(r, 1.5, 0.8), r.CFrame.LookVector, 5, NAVY, 0.2)
		end)
		at(0.66, c, function(r)
			CartoonFX.dust(feet(r) + r.CFrame.LookVector * 3, 7, nil, 10)
			CartoonFX.shockwave(feet(r) + r.CFrame.LookVector * 3 + Vector3.new(0, 0.2, 0), 7, SIREN_B)
			CartoonFX.casterShake(c, 0.6)
		end)
	end,
	Flashlight = function(c)
		at(0.1, c, function(r)
			-- faisceau conique (3 tronçons qui s'élargissent) + éclat de lentille
			for i = 1, 3 do
				local w = 3 + i * 3.5
				local beam = part({ Size = Vector3.new(w, w * 0.6, 9.5), CFrame = r.CFrame * CFrame.new(0, 0.8, -2 - i * 8.5), Color = Color3.fromRGB(255, 250, 190), Transparency = 0.45 + i * 0.08 })
				TweenService:Create(beam, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				Debris:AddItem(beam, 0.52)
			end
			local flare = part({ Shape = BALL, Size = Vector3.one * 1, Position = ahead(r, 2.5, 0.8), Color = C.white, Transparency = 0.05 })
			TweenService:Create(flare, TweenInfo.new(0.25), { Size = Vector3.one * 6, Transparency = 1 }):Play()
			Debris:AddItem(flare, 0.27)
			local att = Instance.new("Attachment")
			att.Parent = r
			att.Position = Vector3.new(0, 0.8, -2)
			local light = Instance.new("SpotLight")
			light.Range = 40
			light.Angle = 55
			light.Brightness = 8
			light.Face = Enum.NormalId.Front
			light.Color = Color3.fromRGB(255, 250, 200)
			light.Parent = att
			TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
			Debris:AddItem(att, 0.52)
			if mine(c) then
				CartoonFX.impactFrame(0.5)
			end
		end)
	end,
	WalkieTalkie = function(c)
		task.spawn(function()
			for i = 1, 4 do -- ondes radio qui partent de la tête
				local head = c:FindFirstChild("Head")
				if not head then return end
				CartoonFX.airRing(head.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, 1, 0), 10 + i * 4, (i % 2 == 0) and SIREN_B or Color3.fromRGB(120, 200, 255), 0.4)
				CartoonFX.sparks(head.Position + Vector3.new(0.6, 0.3, 0), 4, C.white)
				task.wait(0.12)
			end
		end)
		rings(c, 3, 14, Color3.fromRGB(120, 200, 255), -2.6)
		if mine(c) then
			CartoonFX.speedLines(0.5, Color3.fromRGB(120, 200, 255))
		end
	end,
	WhistleBlast = function(c)
		at(0.05, c, function(r)
			CartoonFX.implode(r.Position + Vector3.new(0, 1.5, 0), 6, { C.yellow, C.white }, 10, 0.25)
		end)
		at(0.31, c, function(r)
			for i = 0, 7 do -- anneaux sonores verticaux dans toutes les directions
				local a = i / 8 * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				CartoonFX.airRing(r.Position + dir * 2 + Vector3.new(0, 1, 0), dir, 9, C.yellow, 0.35)
			end
			rings(c, 4, 15, Color3.fromRGB(255, 230, 80), -2.5)
			CartoonFX.light(r.Position, C.yellow, 22, 4, 0.35)
			CartoonFX.casterShake(c, 0.8)
		end)
	end,
	ElbowDrop = function(c)
		task.delay(0.2, function()
			afterimages(c, 0.6, NAVY)
		end)
		at(0.55, c, function(r)
			CartoonFX.sparks(r.Position + Vector3.new(0, 1.5, 0), 12, SIREN_R)
			CartoonFX.sparks(r.Position + Vector3.new(0, 1.5, 0), 12, SIREN_B)
		end)
		if mine(c) then
			task.delay(0.6, function()
				CartoonFX.speedLines(0.3, C.white)
			end)
		end
	end,
	TotalLockdown = function(c)
		local r = rootOf(c)
		if not r then return end
		rings(c, 3, 16, SIREN_R, -2.6)
		-- gyrophares rouge/bleu qui clignotent
		task.spawn(function()
			for i = 1, 10 do
				local rr = rootOf(c)
				if not rr then return end
				CartoonFX.light(rr.Position + Vector3.new(0, 6, 0), (i % 2 == 0) and SIREN_R or SIREN_B, 34, 5, 0.22)
				task.wait(0.25)
			end
		end)
		at(0.66, c, function(r2)
			CartoonFX.shockwave(feet(r2) + Vector3.new(0, 0.2, 0), 16, C.yellow)
			CartoonFX.dust(feet(r2), 8)
			CartoonFX.casterShake(c, 0.6)
		end)
	end,
}

-- effets ajoutés par les modules de Content
require(Shared.Modules.ContentLoader).merge(MOVE_FX, "MoveFX")
local FX_API = { part = part, afterimages = afterimages, trail = trail, rings = rings, CartoonFX = CartoonFX, TweenService = TweenService, Debris = Debris, rng = rng }

function handlers.Ability(data)
	local c = data.a
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	CartoonFX.word(root.Position + Vector3.new(0, 3.5, 0), string.upper(data.name or "") .. "!", 0.55, "Light")
	if data.snd then
		CartoonFX.sound(data.snd, root.Position, 1)
	end
	-- mon propre personnage : l'animation n'est pas prédite par le CombatController, on la joue ici
	local cfg = Attacks[data.id or ""]
	if mine(c) and cfg and cfg.Anim then
		ProcAnim.play(c, cfg.Anim)
	end
	if data.prop then
		attachProp(c, data.prop, data.dur)
	end
	-- éclair de lancement : anneau au sol + étincelles à la main, couleur du personnage
	local Characters = require(Shared.Config.Characters)
	local def = Characters[c:GetAttribute("CharacterName") or ""]
	local col = def and def.Color or Color3.new(1, 1, 1)
	CartoonFX.shockwave(root.Position - Vector3.new(0, 2.8, 0), 6, col)
	local hand = c:FindFirstChild("Right Arm")
	if hand then
		local hp = hand.Position - hand.CFrame.UpVector
		CartoonFX.sparks(hp, 16, col)
		-- charge d'énergie aspirée vers la main + petit éclair de lumière (couleur du perso)
		CartoonFX.implode(hp, 3.5, { col, Color3.new(1, 1, 1) }, 7, 0.16)
		CartoonFX.light(hp, col, 12, 3, 0.3)
	end
	if c:GetAttribute("Transformed") then
		rings(c, 1, 8, col, 0)
	end
	local fx = MOVE_FX[data.id or ""]
	if fx then
		fx(c, data, FX_API)
	elseif data.kind == "Lunge" then
		afterimages(c, data.dur or 0.3, Color3.new(1, 1, 1))
	end
end

-- indicateurs au sol : on voit OÙ l'attaque va frapper
function handlers.Telegraph(data)
	local c = data.a
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local col = mine(c) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	local p
	if data.shape == "Circle" then
		-- grand cercle : disque, bord et anneau blanc qui se resserre jusqu'à l'impact
		CartoonFX.bigTelegraph(ground, data.r, math.max(data.dur or 0.2, 0.15), col)
		return
	elseif data.shape == "Box" then
		p = part({ Size = Vector3.new(data.size.X, 0.12, data.size.Z), CFrame = (root.CFrame - root.Position + ground) * CFrame.new(0, 0, -data.offset), Color = col, Transparency = 0.55 })
		-- bord + ligne qui balaie vers l'avant
		local edge = part({ Size = Vector3.new(data.size.X + 0.6, 0.08, data.size.Z + 0.6), CFrame = p.CFrame * CFrame.new(0, -0.03, 0), Color = col, Transparency = 0.25 })
		local sweep = part({ Size = Vector3.new(data.size.X, 0.16, 0.35), CFrame = p.CFrame * CFrame.new(0, 0.03, data.size.Z / 2), Color = Color3.new(1, 1, 1), Transparency = 0.3 })
		local dd = math.max(data.dur or 0.2, 0.15)
		TweenService:Create(sweep, TweenInfo.new(dd, Enum.EasingStyle.Linear), { CFrame = p.CFrame * CFrame.new(0, 0.03, -data.size.Z / 2) }):Play()
		TweenService:Create(edge, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, dd), { Transparency = 1 }):Play()
		Debris:AddItem(edge, dd + 0.25)
		Debris:AddItem(sweep, dd)
	elseif data.shape == "Cone" then
		local w = 2 * data.r * math.tan(math.rad(data.angle))
		p = part({ Size = Vector3.new(w, 0.12, data.r), CFrame = (root.CFrame - root.Position + ground) * CFrame.new(0, 0, -data.r / 2), Color = col, Transparency = 0.6 })
	end
	if p then
		local dur = math.max(data.dur or 0.2, 0.15)
		TweenService:Create(p, TweenInfo.new(dur), { Transparency = 0.3 }):Play()
		task.delay(dur, function()
			TweenService:Create(p, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(p, dur + 0.25)
	end
end

-- ANIMATION DE TRANSFORMATION (Overtime, ~1,3 s ; le serveur soulève et protège le perso : CharacterService.transformLift)
-- 0 → 0,55 s : il se ramasse, l'énergie est aspirée, anneau qui se resserre, éclairs ; 0,58 s : EXPLOSION d'aura
local TRANSFORM_FRAMES = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 1.3, y = 1.1, r = 0.5 }, LS = { p = 1.3, y = 1.1, r = 0.5 }, RJ = { ln = 0.5 }, RH = { p = 0.6, r = -0.15 }, LH = { p = 0.6, r = -0.15 } },
	{ t = 0.3, RS = { p = 1.4, y = 1.15, r = 0.55 }, LS = { p = 1.25, y = 1.1, r = 0.5 }, RJ = { ln = 0.55, sd = 0.06 }, RH = { p = 0.65, r = -0.2 }, LH = { p = 0.65, r = -0.2 } },
	{ t = 0.5, RS = { p = 1.3, y = 1.15, r = 0.5 }, LS = { p = 1.4, y = 1.15, r = 0.55 }, RJ = { ln = 0.6, sd = -0.06 }, RH = { p = 0.7, r = -0.2 }, LH = { p = 0.7, r = -0.2 } },
	{ t = 0.6, RS = { p = 2.4, r = -1.15 }, LS = { p = 2.4, r = -1.15 }, RJ = { ln = -0.45 }, RH = { p = -0.2, r = -0.45 }, LH = { p = -0.2, r = -0.45 } },
	{ t = 1.05, RS = { p = 2.25, r = -1.05 }, LS = { p = 2.25, r = -1.05 }, RJ = { ln = -0.38 }, RH = { p = -0.15, r = -0.4 }, LH = { p = -0.15, r = -0.4 } },
	{ t = 1.35, RS = { p = 1.2, y = 0.3 }, LS = { p = 1.45, y = 0.5 }, RJ = { ln = 0.15, tw = 0.25 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
}
local UltKitMod
function handlers.Transform(data)
	local c = data.a
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	UltKitMod = UltKitMod or require(Shared.Modules.UltKit)
	local K = UltKitMod
	local col = data.color or Color3.new(1, 1, 1)
	local W = Color3.new(1, 1, 1)
	local me = mine(c)
	if ProcAnim.playFrames then
		ProcAnim.playFrames(c, TRANSFORM_FRAMES)
	else
		ProcAnim.play(c, "Transform")
	end
	-- 1) CHARGE
	K.sound("ChargeShort", root.Position, 1)
	K.sound("Electric", root.Position, 0.7)
	CartoonFX.implode(root.Position, 7, { col, W }, 18, 0.5)
	CartoonFX.dust(root.Position - Vector3.new(0, 2.9, 0), 6, col, 10)
	local ring = part({ Shape = CYL, Size = Vector3.new(0.35, 10, 10), CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2), Color = col, Material = Enum.Material.Neon, Transparency = 0.25 })
	local ring2 = part({ Shape = CYL, Size = Vector3.new(0.25, 12, 12), CFrame = CFrame.new(root.Position) * CFrame.Angles(0.5, 0, math.pi / 2), Color = W, Material = Enum.Material.Neon, Transparency = 0.4 })
	Debris:AddItem(ring, 0.7)
	Debris:AddItem(ring2, 0.7)
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.35, 3.5, 3.5) }):Play()
	TweenService:Create(ring2, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.25, 4, 4), Transparency = 0.1 }):Play()
	local t0 = os.clock()
	task.spawn(function()
		local n = 0
		while os.clock() - t0 < 0.56 and root.Parent do
			local el = os.clock() - t0
			if ring.Parent then
				ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, el * 9, math.pi / 2)
			end
			if ring2.Parent then
				ring2.CFrame = CFrame.new(root.Position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0.5, -el * 12, math.pi / 2)
			end
			n += 1
			if n % 4 == 0 then
				local a = rng:NextNumber(0, math.pi * 2)
				K.bolt(root.Position + Vector3.new(0, rng:NextNumber(-1, 2), 0), root.Position + Vector3.new(math.cos(a) * 4, rng:NextNumber(-2, 3), math.sin(a) * 4), n % 8 == 0 and W or col, 0.22, 0.12, 0.8)
			end
			task.wait()
		end
	end)
	if me then
		CartoonFX.shake(0.4)
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z).Unit
		local side = flat:Cross(Vector3.yAxis)
		local head = root.Position + Vector3.new(0, 1.4, 0)
		local pseudo = { seq = -7, caster = c }
		K.shot(pseudo, "dolly", {
			only = "caster",
			from = CFrame.lookAt(head + flat * 11 + side * 3 + Vector3.new(0, 1, 0), head),
			to = CFrame.lookAt(head + flat * 6 + side * 1.2 + Vector3.new(0, 0.4, 0), head),
			dur = 0.55, style = Enum.EasingStyle.Quad, fov0 = 70, fov1 = 52,
		})
		task.delay(0.58, function()
			K.shot(pseudo, "orbit", { only = "caster", at = c, basis = CFrame.lookAt(root.Position, root.Position + flat), r0 = 8, r1 = 13, dur = 0.7, height = 2.5, angle = 20, speed = 45, lookOffset = Vector3.new(0, 1, 0), fov = 70 })
		end)
		task.delay(1.3, function()
			K.release(pseudo)
		end)
	end
	-- 2) EXPLOSION D'AURA
	task.delay(0.58, function()
		if not root.Parent then
			return
		end
		local p = root.Position
		local g = CartoonFX.groundPos(p)
		K.layer({ { "PowerUp", 1.3 }, { "Explosion", 0.8, 1.1 }, { "Bass", 1 }, { "Lightning", 0.7 } }, p)
		CartoonFX.shockwave(g + Vector3.new(0, 0.2, 0), 18, col)
		CartoonFX.shockwave(g + Vector3.new(0, 0.25, 0), 11, W)
		task.delay(0.08, function()
			CartoonFX.shockwave(g + Vector3.new(0, 0.3, 0), 26, col)
		end)
		K.sphere(p, 12, col, 0.3)
		K.sphere(p, 7, W, 0.18)
		K.ring(CFrame.lookAt(p, p + Vector3.yAxis), 16, col, 0.35)
		K.pillar(g, 3, 24, col, 0.45)
		K.light(p, col, 34, 7, 0.5)
		CartoonFX.sparks(p, 40, col)
		CartoonFX.shards(p, 20, { col, W }, 1.4)
		CartoonFX.dust(g, 11, col:Lerp(W, 0.5), 6)
		for i = 1, 5 do
			local a = i * math.pi * 2 / 5 + rng:NextNumber(-0.3, 0.3)
			K.bolt(p + Vector3.new(0, 1, 0), p + Vector3.new(math.cos(a) * 9, rng:NextNumber(-1, 6), math.sin(a) * 9), i % 2 == 0 and W or col, 0.35, 0.22, 1.4)
		end
		if me then
			K.impactFrames("WB", 0.04)
			K.flash(col, 0.4, 0.55)
			CartoonFX.shake(1.4)
			CartoonFX.fovKick(12)
			CartoonFX.speedLines(0.8, col)
		elseif K.near(p, 60) then
			CartoonFX.shake(0.4)
		end
	end)
	-- aura : particules autour du personnage tant qu'il est transformé
	local att = Instance.new("Attachment")
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(data.color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = data.name == "Janitor" and 0 or 25
	pe.Parent = att
	if data.name == "Janitor" then -- bulles de savon
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
		pe.Rate = 18
		pe.Speed = NumberRange.new(1, 3)
		pe.Acceleration = Vector3.new(0, 4, 0)
	end
	task.spawn(function()
		local c = data.a
		while c.Parent and c:GetAttribute("Transformed") do
			task.wait(0.3)
		end
		att:Destroy()
	end)
end

function handlers.Cone(data)
	local root = data.a and data.a:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < math.max(data.dur, 0.25) and root.Parent do
			for _ = 1, 4 do
				local a = math.rad(rng:NextNumber(-data.angle, data.angle))
				local dir = CFrame.Angles(0, a, 0) * root.CFrame.LookVector
				local start = root.Position + Vector3.new(0, 0.8, 0) + root.CFrame.LookVector * 1.5
				local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Color = data.c or Color3.new(1, 1, 1), Transparency = 0.2, Position = start })
				TweenService:Create(b, TweenInfo.new(0.35), { Position = start + dir * data.range, Size = Vector3.one * 2.6, Transparency = 1 }):Play()
				Debris:AddItem(b, 0.4)
			end
			task.wait(0.05)
		end
	end)
end

function handlers.Grab(data)
	if data.v then
		CartoonFX.alert(data.v)
	end
	CartoonFX.word(data.p + Vector3.new(0, 2, 0), "GOTCHA!", 0.6, "Light")
end

function handlers.Flood(data)
	CartoonFX.word(data.p + Vector3.new(0, 3, 0), "FLOOD!", 1, "Splat")
	CartoonFX.sound("Water", data.p, 1.2)
	CartoonFX.shockwave(data.p, data.r, Color3.fromRGB(110, 200, 255))
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < data.dur do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, data.r)
			local pos = data.p + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
			local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.6, 1.4), Color = Color3.fromRGB(220, 245, 255), Transparency = 0.35, Position = pos })
			TweenService:Create(b, TweenInfo.new(1.2), { Position = pos + Vector3.new(0, 4, 0), Transparency = 1 }):Play()
			Debris:AddItem(b, 1.3)
			task.wait(0.06)
		end
	end)
end

function handlers.Lockdown(data)
	CartoonFX.word(data.p + Vector3.new(0, 4, 0), "LOCKDOWN!", 1.1, "KO")
	CartoonFX.sound("Siren", data.p, 0.8)
	CartoonFX.shockwave(data.p + Vector3.new(0, 0.3, 0), data.r, Color3.fromRGB(255, 210, 0))
	if mine(data.a) then
		CartoonFX.shake(0.5)
	end
end

function handlers.ProjPop(data)
	CartoonFX.puff(data.p, 0.5)
	CartoonFX.shards(data.p, 5, { data.c or Color3.new(1, 1, 1) }, 0.6)
end

-- Walkie-Talkie : révèle tous les ennemis proches
local revealUntil, revealRadius = 0, 0
function handlers.Reveal(data)
	revealUntil = os.clock() + data.dur
	revealRadius = data.r
	CartoonFX.sound("Electric", nil, 0.8)
end

-- contours (passif On Patrol + révélation)
local outlines = {}
local function setOutline(c, on, color)
	local h = outlines[c]
	if on and not h then
		h = Instance.new("Highlight")
		h.Name = "PatrolOutline"
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.75
		h.OutlineTransparency = 0
		h.Adornee = c
		h.Parent = c
		outlines[c] = h
	elseif not on and h then
		h:Destroy()
		outlines[c] = nil
	end
	if h then
		h.FillColor = color
		h.OutlineColor = color
	end
end

function AbilityFXController.init()
	for _, def in ipairs(require(Shared.Modules.ContentLoader).all()) do
		if def.ClientInit then
			task.spawn(def.ClientInit, { CartoonFX = CartoonFX, ProcAnim = ProcAnim, Hitbox = Hitbox, player = player })
		end
	end
	Net.get("FX").OnClientEvent:Connect(function(data)
		local h = type(data) == "table" and handlers[data.k]
		if h then
			h(data)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local me = player.Character
			local myRoot = me and me:FindFirstChild("HumanoidRootPart")
			local guard = me and me:GetAttribute("CharacterName") == "SecurityGuard"
			local revealing = os.clock() < revealUntil
			local nowS = workspace:GetServerTimeNow()
			for _, c in ipairs(Hitbox.characters()) do
				-- arme fétiche cachée si on tient un objet ou un accessoire d'attaque dans la même main
				local sig = c:FindFirstChild("Signature")
				if sig then
					local busy = (sig:GetAttribute("Hand") == "Right" and c:GetAttribute("HeldItem") ~= nil) or (c:GetAttribute("PropBusy") or 0) > 0
					for _, p in ipairs(sig:GetChildren()) do
						p.LocalTransparencyModifier = busy and 1 or 0
					end
				end
				-- accessoire sur la tête (seau du Janitor, cône)
				local head = c:FindFirstChild("Head")
				local hp = c:FindFirstChild("HeadPropFX")
				local wantHead = head and (c:GetAttribute("HeadPropUntil") or 0) > nowS and c:GetAttribute("HeadProp")
				if wantHead and (not hp or hp:GetAttribute("Kind") ~= wantHead) then
					if hp then hp:Destroy() end
					hp = Instance.new("Part")
					hp.Name = "HeadPropFX"
					hp:SetAttribute("Kind", wantHead)
					if wantHead == "Bucket" then
						hp.Shape = CYL
						hp.Size = Vector3.new(1.6, 1.7, 1.7)
						hp.Color = C.grey
						hp.CFrame = head.CFrame * CFrame.new(0, 0.3, 0) * ALONG_Y
					else
						hp.Shape = CYL
						hp.Size = Vector3.new(2.2, 1.6, 1.6)
						hp.Color = C.orange
						hp.CFrame = head.CFrame * CFrame.new(0, 0.6, 0) * ALONG_Y
					end
					hp.Material = Enum.Material.SmoothPlastic
					hp.CanCollide, hp.CanQuery, hp.CanTouch, hp.Massless = false, false, false, true
					local w = Instance.new("WeldConstraint")
					w.Part0 = head
					w.Part1 = hp
					w.Parent = hp
					hp.Parent = c
				elseif not wantHead and hp then
					hp:Destroy()
				end
				-- post-it collé sur la cible marquée
				local note = c:FindFirstChild("StickyFX")
				local torso = c:FindFirstChild("Torso")
				local marked = torso and c:GetAttribute("MarkedBy") and (c:GetAttribute("MarkUntil") or 0) > nowS
				if marked and not note then
					note = Instance.new("Part")
					note.Name = "StickyFX"
					note.Size = Vector3.new(0.9, 0.9, 0.08)
					note.Color = Color3.fromRGB(255, 235, 60)
					note.Material = Enum.Material.SmoothPlastic
					note.CanCollide, note.CanQuery, note.CanTouch, note.Massless = false, false, false, true
					note.CFrame = torso.CFrame * CFrame.new(0.3, 0.2, -0.56) * CFrame.Angles(0, 0, math.rad(12))
					local w = Instance.new("WeldConstraint")
					w.Part0 = torso
					w.Part1 = note
					w.Parent = note
					note.Parent = c
				elseif not marked and note then
					note:Destroy()
				end
			end
			for c in pairs(outlines) do
				if not c.Parent then
					outlines[c] = nil
				end
			end
			for _, c in ipairs(Hitbox.characters()) do
				if c ~= me then
					local r = c:FindFirstChild("HumanoidRootPart")
					local hum = c:FindFirstChildOfClass("Humanoid")
					local dist = (r and myRoot) and (r.Position - myRoot.Position).Magnitude or math.huge
					local low = guard and hum and hum.Health <= 35 and dist <= 80
					local rev = revealing and dist <= revealRadius
					setOutline(c, low or rev, low and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 220, 60))
				end
			end
		end
	end)
end

return AbilityFXController
