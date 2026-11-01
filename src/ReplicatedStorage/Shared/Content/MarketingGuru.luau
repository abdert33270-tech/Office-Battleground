--[[
	The Marketing Guru — personnage complet (format : voir Modules/ContentLoader).
	Passif « Trending » : chaque coup d'attaque spéciale donne +5 % de vitesse pendant 4 s (cumulable 5 fois).
	Attaques : Megaphone Blast (cône sonore qui repousse), Confetti Cannon (obus de confettis qui aveugle), Billboard Drop (panneau géant qui plaque au sol).
	Transformation Viral Sensation : Viral Trend (buff dégâts/vitesse + onde de likes), SYNERGY! (attire tout le monde et les fracasse ensemble), Hype Train (surf sur une flèche « stonks »).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local MAGENTA = Color3.fromRGB(235, 35, 200)
local CYAN = Color3.fromRGB(40, 220, 255)
local YELLOW = Color3.fromRGB(255, 230, 40)
local WHITE = Color3.fromRGB(250, 250, 255)
local DARK = Color3.fromRGB(30, 30, 40)
local STONKS = Color3.fromRGB(40, 220, 90)
local CONFETTI = { MAGENTA, CYAN, YELLOW, Color3.fromRGB(120, 255, 90), Color3.fromRGB(255, 120, 40), WHITE }

local M = { Id = "MarketingGuru", Order = 14 }

M.Character = {
	DisplayName = "The Marketing Guru",
	Role = "Hype machine",
	Color = MAGENTA,
	Shirt = Color3.fromRGB(205, 30, 175), Pants = Color3.fromRGB(35, 35, 55), Tie = CYAN,
	Passive = { Name = "Trending", Desc = "Every ability hit gives +5% move speed for 4 s, stacking up to 5 times (+25%)." },
	Attacks = { "MegaphoneBlast", "ConfettiCannon", "BillboardDrop" },
	Transformation = { Name = "Viral Sensation", Desc = "Star shades, a glowing ring light and floating #TRENDING signs.", Duration = 20, SpeedMultiplier = 1.2 },
	TransAttacks = { "ViralTrend", "Synergy", "HypeTrain" },
}

M.Attacks = {
	MegaphoneBlast = { Name = "Megaphone Blast", Kind = "MKMegaphone", Desc = "Yell into your megaphone: a cone of sound blasts everyone in front far away.", Prop = "MKMegaphone", Cooldown = 7, Anim = "MKMegaphone", Sound = "Whistle",
		Windup = 0.28, Range = 22, Angle = 32, Damage = 8, Knockback = 58, KnockUp = 12, Stun = 0.9, Category = "Heavy", Power = 0.8, Words = { "LISTEN UP!", "LOUD AND CLEAR!" } },
	ConfettiCannon = { Name = "Confetti Cannon", Kind = "MKConfetti", Desc = "Fire a confetti shell that bursts on impact and blinds everyone around it.", Prop = "MKCannon", Cooldown = 8, Anim = "MKConfetti", Sound = "Throw",
		Windup = 0.2, Speed = 90, Range = 60, Gravity = 0.35, Up = 9, Radius = 8, Damage = 7, Knockback = 22, KnockUp = 10, Stun = 0.6, Category = "Splat", Power = 0.6, Words = { "POP!", "SURPRISE!" }, Effects = { Blind = 1.5 } },
	BillboardDrop = { Name = "Billboard Drop", Kind = "MKBillboard", Desc = "A giant advertising billboard slams down flat in front of you and pins everyone under it.", Cooldown = 11, Anim = "MKBillboard", Sound = "Crash",
		Windup = 0.5, Offset = 10, Width = 12, Depth = 7, Damage = 13, Knockback = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.1, Words = { "BUY NOW!", "AD BREAK!" }, Effects = { Pin = true } },
	ViralTrend = { Name = "Viral Trend", Kind = "MKViral", Desc = "Strike a pose and go viral: a burst of likes pushes enemies away, and you get +30% damage and +25% speed for 6 s.", Prop = "MKPhone", Cooldown = 15, Anim = "MKViral", Sound = "PowerUp",
		Windup = 0.25, Radius = 10, BuffTime = 6, SpeedBuff = 1.25, Damage = 4, Knockback = 30, KnockUp = 10, Stun = 0.5, Category = "Light", Power = 0.45, Words = { "LIKED!", "+1M VIEWS!" } },
	Synergy = { Name = "SYNERGY!", Kind = "MKSynergy", Desc = "Link up to 4 nearby coworkers with team-building ropes, yank them all together and smash them as one.", Cooldown = 13, Anim = "MKSynergy", Sound = "Whoosh",
		Windup = 0.3, Radius = 22, MaxTargets = 4, LinkTime = 0.35, PullSpeed = 110, Damage = 10, Knockback = 40, KnockUp = 22, Stun = 1.0, Category = "Heavy", GuardBreak = true, Power = 1.0, Words = { "SYNERGY!", "TEAM BUILDING!" } },
	HypeTrain = { Name = "Hype Train", Kind = "Lunge", Desc = "Surf a giant STONKS arrow forward, plowing through everyone and launching them sky-high.", Cooldown = 9, Pierce = true, Anim = "MKHypeTrain", Sound = "Dash",
		Speed = 95, Time = 0.5, HitboxSize = Vector3.new(7, 6, 7), Windup = 0.25, Damage = 12, Knockback = 10, Launch = Vector3.new(10, 50, 0), Stun = 1.1, Category = "Heavy", Power = 1.0, Words = { "STONKS!", "TO THE MOON!" } },
}

------------------------------------------------------------------------
-- Animations (une par attaque)
------------------------------------------------------------------------
local function megaAnim()
	local f = {
		{ t = 0 },
		{ t = 0.14, RS = { p = 1.15, y = 0.2 }, LS = { p = 0.7, r = -0.5 }, RJ = { tw = -0.4, ln = -0.35 }, RH = { p = -0.15 }, LH = { p = 0.2 } },
		{ t = 0.27, RS = { p = 1.25, y = 0.2 }, LS = { p = 0.9, r = -0.6 }, RJ = { tw = -0.45, ln = -0.45 }, RH = { p = -0.2 }, LH = { p = 0.25 } },
	}
	local t = 0.3
	for i = 1, 6 do -- tremble en criant
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = 1.6, y = 0.05 * s }, LS = { p = -0.4, r = -0.9 }, RJ = { tw = 0.2 + 0.05 * s, ln = 0.32, sd = 0.04 * s }, RH = { p = 0.5 }, LH = { p = -0.45 } })
		t += 0.06
	end
	table.insert(f, { t = t + 0.2 })
	return f
end

M.Anims = {
	MKMegaphone = megaAnim(), -- se penche en arrière pour prendre son souffle, puis hurle en avant (tout le corps tremble)
	MKConfetti = { -- canon sur l'épaule, recul violent
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.55 }, LS = { p = 1.45, y = 0.55 }, RJ = { tw = 0.25, ln = 0.18 }, RH = { p = 0.35 }, LH = { p = -0.25 } },
		{ t = 0.2, RS = { p = 1.5 }, LS = { p = 1.4, y = 0.55 }, RJ = { tw = 0.3, ln = 0.22 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
		{ t = 0.26, RS = { p = 2.05 }, LS = { p = 1.9, y = 0.5 }, RJ = { tw = 0.1, ln = -0.4 }, RH = { p = -0.35 }, LH = { p = 0.45 } },
		{ t = 0.5, RS = { p = 1.7 }, LS = { p = 1.6, y = 0.5 }, RJ = { tw = 0.15, ln = -0.1 } },
		{ t = 0.7 },
	},
	MKBillboard = { -- claque des doigts, pointe la cible, puis double poing vers le bas
		{ t = 0 },
		{ t = 0.14, RS = { p = 2.1, y = 0.9 }, LS = { p = 0.3, r = -0.3 }, RJ = { tw = -0.35, ln = -0.1 } },
		{ t = 0.22, RS = { p = 2.0, y = 0.6 }, RJ = { tw = -0.3 } },
		{ t = 0.4, RS = { p = 1.75 }, LS = { p = 0.5, r = -0.7 }, RJ = { tw = 0.4, ln = 0.2 }, RH = { p = 0.35 }, LH = { p = -0.2 } },
		{ t = 0.5, RS = { p = 2.9, r = -0.3 }, LS = { p = 2.9, r = -0.3 }, RJ = { ln = -0.3 } },
		{ t = 0.57, RS = { p = 0.35 }, LS = { p = 0.35 }, RJ = { ln = 0.55 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 0.8, RS = { p = 0.4 }, LS = { p = 0.4 }, RJ = { ln = 0.5 }, RH = { p = 0.55 }, LH = { p = -0.3 } },
		{ t = 0.95 },
	},
	MKViral = { -- selfie avec le téléphone levé, puis dab
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.6, y = 0.4, r = -0.4 }, LS = { p = 1.2, y = -0.9, r = 0.3 }, RJ = { tw = 0.3, sd = 0.2, ln = -0.15 }, RH = { r = -0.3 }, LH = { p = 0.3 } },
		{ t = 0.25, RS = { p = 2.7, y = 0.4, r = -0.45 }, LS = { p = 1.25, y = -0.9, r = 0.3 }, RJ = { tw = 0.35, sd = 0.22, ln = -0.18 }, RH = { r = -0.35 }, LH = { p = 0.35 } },
		{ t = 0.33, RS = { p = 2.4, r = -1.3 }, LS = { p = 1.7, y = 1.3, r = 0.9 }, RJ = { ln = 0.45, tw = -0.45, sd = -0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.7, RS = { p = 2.35, r = -1.25 }, LS = { p = 1.65, y = 1.3, r = 0.9 }, RJ = { ln = 0.4, tw = -0.4, sd = -0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.9 },
	},
	MKSynergy = { -- grands bras ouverts, puis tire et joint les mains, puis triomphe
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.6, r = -1.3 }, LS = { p = 1.6, r = -1.3 }, RJ = { ln = -0.2 } },
		{ t = 0.3, RS = { p = 1.7, r = -1.5 }, LS = { p = 1.7, r = -1.5 }, RJ = { ln = -0.3 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.62, RS = { p = 1.4, r = 0.45 }, LS = { p = 1.4, r = 0.45 }, RJ = { ln = 0.35 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
		{ t = 0.8, RS = { p = 1.0, r = 0.3 }, LS = { p = 1.0, r = 0.3 }, RJ = { ln = -0.3 }, RH = { p = -0.3 }, LH = { p = 0.3 } },
		{ t = 0.95, RS = { p = 3.0, r = -0.5 }, LS = { p = 3.0, r = -0.5 }, RJ = { ln = -0.35 } },
		{ t = 1.2, RS = { p = 2.9, r = -0.5 }, LS = { p = 2.9, r = -0.5 }, RJ = { ln = -0.3 } },
		{ t = 1.35 },
	},
	MKHypeTrain = { -- pose de surfeur : un bras pointé devant, l'autre derrière, jambes écartées
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.65, y = 0.2 }, LS = { p = -0.8, r = -0.5 }, RJ = { tw = -0.65, ln = 0.28 }, RH = { p = 0.55, r = -0.3 }, LH = { p = -0.45, r = -0.2 } },
		{ t = 0.55, RS = { p = 1.7, y = 0.2 }, LS = { p = -0.85, r = -0.55 }, RJ = { tw = -0.6, ln = 0.3 }, RH = { p = 0.5, r = -0.3 }, LH = { p = -0.4, r = -0.2 } },
		{ t = 0.75 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	MKMegaphone = { -- pavillon dans l'axe du bras (pointe devant quand le bras est tendu)
		{ Vector3.new(0.35, 0.6, 0.35), CFrame.new(0, -1.15, -0.35), DARK }, -- poignée
		{ Vector3.new(0.7, 0.6, 0.6), CFrame.new(0, -1.45, 0) * UP, WHITE, CYL },
		{ Vector3.new(0.6, 1.0, 1.0), CFrame.new(0, -2.05, 0) * UP, WHITE, CYL },
		{ Vector3.new(0.5, 1.45, 1.45), CFrame.new(0, -2.55, 0) * UP, WHITE, CYL },
		{ Vector3.new(0.16, 1.75, 1.75), CFrame.new(0, -2.85, 0) * UP, MAGENTA, CYL },
		{ Vector3.new(0.05, 1.4, 1.4), CFrame.new(0, -2.94, 0) * UP, DARK, CYL },
	},
	MKCannon = {
		{ Vector3.new(2.9, 1.05, 1.05), CFrame.new(0, -1.8, 0) * UP, MAGENTA, CYL },
		{ Vector3.new(0.25, 1.1, 1.1), CFrame.new(0, -1.1, 0) * UP, YELLOW, CYL },
		{ Vector3.new(0.25, 1.1, 1.1), CFrame.new(0, -1.9, 0) * UP, CYAN, CYL },
		{ Vector3.new(0.25, 1.1, 1.1), CFrame.new(0, -2.7, 0) * UP, YELLOW, CYL },
		{ Vector3.new(0.2, 1.3, 1.3), CFrame.new(0, -3.25, 0) * UP, WHITE, CYL },
	},
	MKPhone = {
		{ Vector3.new(0.18, 1.05, 0.6), CFrame.new(0, -1.35, -0.25), DARK },
		{ Vector3.new(0.05, 0.9, 0.5), CFrame.new(-0.1, -1.35, -0.25), CYAN },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : casque-micro, mèche, pochette, baskets blanches
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.32, 0.12, 0.2), CFrame.new(0, 0.62, 0), DARK) -- arceau
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.14, 0.45, 0.45), CFrame.new(0.66 * s, 0.05, 0) * UP, DARK, CYL) -- écouteurs
	end
	prop(f, head, Vector3.new(0.08, 0.08, 0.7), CFrame.new(-0.55, -0.15, -0.35) * CFrame.Angles(0, -0.5, 0), DARK) -- micro
	prop(f, head, Vector3.new(0.16, 0.16, 0.16), CFrame.new(-0.3, -0.22, -0.66), MAGENTA)
	prop(f, head, Vector3.new(1.0, 0.35, 0.5), CFrame.new(0.1, 0.62, -0.35) * CFrame.Angles(0.35, 0, 0.1), Color3.fromRGB(60, 40, 30)) -- mèche
	prop(f, torso, Vector3.new(0.4, 0.3, 0.08), CFrame.new(-0.55, 0.5, -0.54), CYAN) -- pochette
	prop(f, torso, Vector3.new(0.12, 0.12, 0.09), CFrame.new(0.5, 0.55, -0.55), YELLOW) -- pin's
	for _, n in ipairs({ "Left Leg", "Right Leg" }) do
		local leg = c:FindFirstChild(n)
		if leg then
			prop(f, leg, Vector3.new(1.06, 0.38, 1.25), CFrame.new(0, -0.82, -0.12), WHITE) -- baskets
			prop(f, leg, Vector3.new(1.08, 0.12, 1.27), CFrame.new(0, -0.95, -0.12), MAGENTA)
		end
	end
end

-- arme fétiche : mégaphone à la main gauche
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	local base = CFrame.new(0, -1.15, -0.2)
	prop(f, a, Vector3.new(0.3, 0.5, 0.3), base, DARK)
	prop(f, a, Vector3.new(0.6, 0.5, 0.5), base * CFrame.new(0, -0.1, -0.45) * ALONG_Z, WHITE, CYL)
	prop(f, a, Vector3.new(0.55, 0.9, 0.9), base * CFrame.new(0, -0.1, -0.95) * ALONG_Z, WHITE, CYL)
	prop(f, a, Vector3.new(0.14, 1.25, 1.25), base * CFrame.new(0, -0.1, -1.28) * ALONG_Z, MAGENTA, CYL)
end }

local function sign(f, torso, prop, text, size, off, color)
	local s = prop(f, torso, size, off, color)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = s
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = WHITE
		l.Text = text
		l.Parent = gui
	end
	return s
end

-- Transformation : lunettes étoiles, anneau lumineux derrière la tête, panneaux #TRENDING qui flottent
function M.Transform(f, head, torso, c, prop)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.42, 0.42, 0.06), CFrame.new(0.28 * s, 0.12, -0.63), MAGENTA)
		prop(f, head, Vector3.new(0.42, 0.42, 0.06), CFrame.new(0.28 * s, 0.12, -0.635) * CFrame.Angles(0, 0, math.rad(45)), YELLOW)
	end
	prop(f, head, Vector3.new(0.2, 0.06, 0.06), CFrame.new(0, 0.15, -0.64), DARK)
	local n = 14
	local first
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = prop(f, head, Vector3.new(0.5, 0.18, 0.18), CFrame.new(0, 0.2, 0.9) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.25, 0), WHITE)
		first = first or p
	end
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 200, 250)
	pl.Range = 12
	pl.Brightness = 2
	pl.Parent = first
	sign(f, torso, prop, "#TRENDING", Vector3.new(2.6, 0.7, 0.1), CFrame.new(0, 3.5, 0.6) * CFrame.Angles(-0.2, 0, 0), MAGENTA)
	sign(f, torso, prop, "#1", Vector3.new(0.9, 0.9, 0.1), CFrame.new(-1.9, 1.4, 0.4) * CFrame.Angles(0, 0.5, 0.15), CYAN)
	sign(f, torso, prop, "LIKE", Vector3.new(1.2, 0.6, 0.1), CFrame.new(1.9, 1.6, 0.4) * CFrame.Angles(0, -0.5, -0.15), STONKS)
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

local function inDisc(attacker, center, radius, height)
	local list = {}
	for _, v in ipairs(Kit.enemies(attacker)) do
		local vp = Kit.root(v).Position
		if Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude <= radius and math.abs(vp.Y - center.Y) < (height or 9) then
			table.insert(list, v)
		end
	end
	return list
end

M.Kinds = {
	-- Megaphone Blast : cône sonore devant soi qui expulse loin
	MKMegaphone = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "MK_ConeTele", a = attacker, p = Kit.ground(root.Position), dir = dir, r = cfg.Range, ang = cfg.Angle, dur = cfg.Windup })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		Kit.fx({ id = "MK_Blast", a = attacker, p = root.Position + Vector3.new(0, 1, 0), dir = dir, r = cfg.Range, ang = cfg.Angle })
		local cosA = math.cos(math.rad(cfg.Angle))
		for _, v in ipairs(Kit.enemies(attacker)) do
			local to = Kit.root(v).Position - root.Position
			local d = to.Magnitude
			if d <= cfg.Range and math.abs(to.Y) < 8 and (d < 3.5 or Kit.flat(to):Dot(dir) >= cosA) then
				api.hit(attacker, v, cfg, api.flat(to, dir))
			end
		end
	end,

	-- Confetti Cannon : obus en cloche qui éclate en confettis (zone, aveugle)
	MKConfetti = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1.5, 0) + dir * 3, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.one * 1.4, color = MAGENTA, shape = BALL, gravity = cfg.Gravity, up = cfg.Up, spin = 10,
			onHit = function()
				return nil -- éclate (onEnd)
			end,
			onEnd = function(pos)
				Kit.fx({ id = "MK_Pop", p = pos, r = cfg.Radius, a = attacker })
				for _, v in ipairs(Kit.inRadius(attacker, pos, cfg.Radius)) do
					api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - pos, dir))
				end
			end,
		})
	end,

	-- Billboard Drop : panneau publicitaire géant qui tombe à plat (rectangle) et plaque au sol
	MKBillboard = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local spot = Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3)
		local center = Kit.ground(spot)
		local cf = CFrame.lookAt(center, center + dir)
		Kit.fx({ id = "MK_Billboard", cf = cf, w = cfg.Width, l = cfg.Depth, fall = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(Kit.enemies(attacker)) do
			local vp = Kit.root(v).Position
			local lp = cf:PointToObjectSpace(vp)
			if math.abs(lp.X) <= cfg.Width / 2 + 1 and math.abs(lp.Z) <= cfg.Depth / 2 + 1 and lp.Y > -2 and lp.Y < 9 then
				api.hit(attacker, v, cfg, api.flat(vp - root.Position, dir))
			end
		end
	end,

	-- Viral Trend : buff (dégâts +30 %, vitesse +25 %) et onde de likes autour de soi
	MKViral = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		attacker:SetAttribute("MKViralUntil", api.now() + cfg.BuffTime)
		api.CharacterState.setSpeedMod(attacker, "MKViral", cfg.SpeedBuff, cfg.BuffTime)
		Kit.fx({ id = "MK_Viral", a = attacker, dur = cfg.BuffTime, r = cfg.Radius })
		for _, v in ipairs(inDisc(attacker, root.Position, cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector))
		end
	end,

	-- SYNERGY! : relie jusqu'à 4 ennemis, les attire tous au même point et les frappe ensemble
	MKSynergy = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		Kit.fx({ id = "Telegraph", p = Kit.ground(root.Position), r = cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local list = {}
		for _, v in ipairs(Kit.inRadius(attacker, root.Position, cfg.Radius)) do
			if not Kit.isProtected(v) and #list < cfg.MaxTargets then
				table.insert(list, v)
			end
		end
		if #list == 0 then
			Kit.fx({ id = "MK_NoSyn", a = attacker })
			return
		end
		Kit.fx({ id = "MK_Links", a = attacker, vs = list, dur = cfg.LinkTime + 0.4 })
		for _, v in ipairs(list) do
			api.CharacterState.stun(v, cfg.LinkTime + 0.8)
		end
		task.wait(cfg.LinkTime)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local point = root.Position + Kit.flat(root.CFrame.LookVector) * 4
		local maxT = 0
		for _, v in ipairs(list) do
			maxT = math.max(maxT, Kit.pull(v, point, cfg.PullSpeed, 1.5))
		end
		task.wait(maxT + 0.05)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		Kit.fx({ id = "MK_SynBoom", p = point, a = attacker })
		for _, v in ipairs(list) do
			if api.CharacterState.isAlive(v) then
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector))
			end
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Trending + buff de Viral Trend
------------------------------------------------------------------------
function M.ServerInit(api)
	local names = {}
	for _, a in pairs(M.Attacks) do
		names[a.Name] = true
	end
	local stacks = setmetatable({}, { __mode = "k" })
	api.Signals.Hit:Connect(function(attacker, victim, damage, info)
		if not attacker or attacker:GetAttribute("CharacterName") ~= "MarketingGuru" or not (info and names[info.weapon or ""]) then
			return
		end
		local s = stacks[attacker]
		if not s or os.clock() - s.t > 4 then
			s = { n = 0, t = 0 }
			stacks[attacker] = s
		end
		s.n = math.min(5, s.n + 1)
		s.t = os.clock()
		api.CharacterState.setSpeedMod(attacker, "MKTrending", 1 + 0.05 * s.n, 4)
		Kit.fx({ id = "MK_Trend", v = attacker, n = s.n })
	end)
	table.insert(api.CombatService.damageMods, function(p)
		local a = p.attacker
		if a and (a:GetAttribute("MKViralUntil") or 0) > workspace:GetServerTimeNow() and a:GetAttribute("CharacterName") == "MarketingGuru" then
			p.damage *= 1.3
			p.power = (p.power or 0.5) + 0.15
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local function teleCone(origin, dir, r, ang, dur, attacker)
	local col = Kit.mine(attacker) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local n = 9
	for i = 0, n - 1 do
		local a = math.rad(-ang + (2 * ang) * i / (n - 1))
		local d = CFrame.Angles(0, a, 0) * dir
		local base = CFrame.lookAt(origin, origin + d)
		local bar = Kit.part({ Size = Vector3.new(0.35, 0.12, r), CFrame = base * CFrame.new(0, 0.1, -r / 2), Color = col, Transparency = 0.45 })
		local fill = Kit.part({ Size = Vector3.new(2 * r * math.tan(math.rad(ang)) / n + 0.3, 0.1, 0.3), CFrame = base * CFrame.new(0, 0.08, -0.15), Color = col, Transparency = 0.6 })
		Kit.tween(fill, dur, { Size = Vector3.new(fill.Size.X, 0.1, r), CFrame = base * CFrame.new(0, 0.08, -r / 2) }, Enum.EasingStyle.Linear)
		Debris:AddItem(bar, dur + 0.05)
		Debris:AddItem(fill, dur + 0.05)
	end
end

local function teleRect(cf, w, l, dur, attacker)
	local col = Kit.mine(attacker) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local p = Kit.part({ Size = Vector3.new(w, 0.12, l), CFrame = cf * CFrame.new(0, 0.1, 0), Color = col, Transparency = 0.6 })
	local inner = Kit.part({ Size = Vector3.new(0.3, 0.14, 0.3), CFrame = cf * CFrame.new(0, 0.12, 0), Color = col, Transparency = 0.3 })
	Kit.tween(inner, dur, { Size = Vector3.new(w, 0.14, l) }, Enum.EasingStyle.Linear)
	Debris:AddItem(p, dur + 0.05)
	Debris:AddItem(inner, dur + 0.05)
end

-- confettis plats qui virevoltent et retombent
local function confetti(pos, n, spread, life)
	for _ = 1, n do
		local c = Kit.part({ Size = Vector3.new(0.35, 0.05, 0.5), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = CONFETTI[Kit.rng:NextInteger(1, #CONFETTI)] })
		local out = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(0.3, 1.2), Kit.rng:NextNumber(-1, 1)) * spread
		local l = life * Kit.rng:NextNumber(0.7, 1.2)
		Kit.tween(c, l * 0.35, { CFrame = CFrame.new(pos + out) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0) })
		task.delay(l * 0.35, function()
			Kit.tween(c, l * 0.65, { CFrame = CFrame.new(pos + out * 1.2 - Vector3.new(0, spread * 0.6, 0)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1 }, Enum.EasingStyle.Sine)
		end)
		Debris:AddItem(c, l + 0.05)
	end
end

local function heartAt(pos, color, size)
	-- cœur en 3 parts (deux boules + losange)
	local s = size or 0.8
	local parts = {
		Kit.part({ Shape = BALL, Size = Vector3.one * s, CFrame = CFrame.new(pos + Vector3.new(-s * 0.3, s * 0.15, 0)), Color = color }),
		Kit.part({ Shape = BALL, Size = Vector3.one * s, CFrame = CFrame.new(pos + Vector3.new(s * 0.3, s * 0.15, 0)), Color = color }),
		Kit.part({ Size = Vector3.new(s * 0.75, s * 0.75, s * 0.5), CFrame = CFrame.new(pos + Vector3.new(0, -s * 0.15, 0)) * CFrame.Angles(0, 0, math.rad(45)), Color = color }),
	}
	for _, p in ipairs(parts) do
		Kit.tween(p, 0.9, { Position = p.Position + Vector3.new(0, 3, 0), Transparency = 1 })
		Debris:AddItem(p, 0.92)
	end
end

M.MoveFX = {
	MegaphoneBlast = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3, 0), "AHEM...", WHITE, 1.8, 0.4, 1)
		end
	end,
	ConfettiCannon = function(c, d, api)
		task.delay(0.22, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				local tip = (arm.CFrame * CFrame.new(0, -3.4, 0)).Position
				confetti(tip, 14, 3, 0.6)
				api.CartoonFX.puff(tip, 1.5)
				api.CartoonFX.sound("Explosion", tip, 0.35)
			end
		end)
	end,
	BillboardDrop = function(c, d, api)
		api.CartoonFX.sound("Whistle", nil, 0.5)
	end,
	ViralTrend = function(c, d, api)
		task.delay(0.15, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				local p = (arm.CFrame * CFrame.new(0, -1.4, 0)).Position
				local flash = Kit.part({ Shape = BALL, Size = Vector3.one, Position = p, Color = WHITE, Transparency = 0.1 })
				Kit.tween(flash, 0.2, { Size = Vector3.one * 5, Transparency = 1 })
				Debris:AddItem(flash, 0.22)
				Kit.floatText(p + Vector3.new(0, 1, 0), "*CLICK*", WHITE, 1.6, 0.5, 1)
			end
		end)
	end,
	Synergy = function(c, d, api)
		api.CartoonFX.sound("PowerUp", nil, 0.4)
	end,
	HypeTrain = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		api.afterimages(c, 0.5, STONKS)
		local board = {}
		local function add(size, off, color)
			table.insert(board, { Kit.part({ Size = size, CFrame = r.CFrame * off, Color = color }), off })
		end
		add(Vector3.new(2.6, 0.35, 7), CFrame.new(0, -3.1, 0.5), STONKS) -- corps de la flèche
		add(Vector3.new(3.3, 0.38, 3.3), CFrame.new(0, -3.05, -3.0) * CFrame.Angles(0, math.rad(45), 0), STONKS) -- pointe
		add(Vector3.new(2.7, 0.4, 0.4), CFrame.new(0, -2.85, 2.6), WHITE)
		local t0 = os.clock()
		local last = r.Position
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if os.clock() - t0 > 0.6 or not r.Parent then
				conn:Disconnect()
				for _, e in ipairs(board) do
					Kit.tween(e[1], 0.2, { Transparency = 1 })
					Debris:AddItem(e[1], 0.22)
				end
				return
			end
			for _, e in ipairs(board) do
				e[1].CFrame = r.CFrame * e[2]
			end
			-- courbe « stonks » qui monte derrière
			if (r.Position - last).Magnitude > 2 then
				local a = last + Vector3.new(0, -2.5 + (os.clock() - t0) * 6, 0)
				local b = r.Position + Vector3.new(0, -2.5 + (os.clock() - t0) * 9, 0)
				local len = (b - a).Magnitude
				local seg = Kit.part({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2), Color = STONKS })
				Kit.tween(seg, 0.8, { Transparency = 1 })
				Debris:AddItem(seg, 0.82)
				last = r.Position
			end
		end)
		if Kit.mine(c) then
			api.CartoonFX.speedLines(0.5, STONKS)
		end
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	Kit.setupClient()

	Kit.on("MK_ConeTele", function(d)
		teleCone(d.p, d.dir, d.r, d.ang, d.dur, d.a)
	end)

	Kit.on("MK_Blast", function(d)
		CartoonFX.sound("BigImpact", d.p, 0.7)
		CartoonFX.sound("Whoosh", d.p, 1.2)
		local tan = math.tan(math.rad(d.ang))
		for i = 1, 6 do
			task.delay((i - 1) * 0.05, function()
				local start = d.p + d.dir * 2.5
				local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.3, 1.5, 1.5), CFrame = CFrame.lookAt(start, start + d.dir) * ALONG_Z, Color = (i % 2 == 0) and MAGENTA or WHITE, Transparency = 0.35 })
				local dist = d.r * (0.5 + i * 0.08)
				local endp = d.p + d.dir * dist
				local dia = 2 * tan * dist
				Kit.tween(ring, 0.32, { CFrame = CFrame.lookAt(endp, endp + d.dir) * ALONG_Z, Size = Vector3.new(0.12, dia, dia), Transparency = 1 })
				Debris:AddItem(ring, 0.34)
			end)
		end
		CartoonFX.shockwave(d.p + d.dir * 4 - Vector3.new(0, 3.5, 0), 6, MAGENTA)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.4)
			CartoonFX.fovKick(4)
		end
	end)

	Kit.on("MK_Pop", function(d)
		CartoonFX.sound("Explosion", d.p, 0.8)
		CartoonFX.bigImpact(d.p, nil, 1.2, MAGENTA)
		CartoonFX.shockwave(d.p - Vector3.new(0, 1.5, 0), d.r, YELLOW)
		confetti(d.p, 45, d.r * 0.9, 1.4)
		Kit.cubes(d.p, 16, CONFETTI, 0.5, d.r, 0.6)
		-- serpentins
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local dirv = Vector3.new(math.cos(a), 0.6, math.sin(a)).Unit
			local s = Kit.part({ Size = Vector3.new(0.25, 0.25, 4), CFrame = CFrame.lookAt(d.p, d.p + dirv) * CFrame.new(0, 0, -2), Color = CONFETTI[i] })
			Kit.tween(s, 0.6, { CFrame = CFrame.lookAt(d.p + dirv * d.r, d.p + dirv * (d.r + 1)) * CFrame.Angles(0, 0, 2), Transparency = 1 })
			Debris:AddItem(s, 0.62)
		end
	end)

	Kit.on("MK_Billboard", function(d)
		teleRect(d.cf, d.w, d.l, d.fall, d.a)
		local final = d.cf * CFrame.new(0, 0.35, 0)
		local start = d.cf * CFrame.new(0, 32, 4) * CFrame.Angles(1.3, 0, 0.2)
		local board = Kit.part({ Size = Vector3.new(d.w, 0.6, d.l), CFrame = start, Color = WHITE })
		local frame = Kit.part({ Size = Vector3.new(d.w + 0.8, 0.5, d.l + 0.8), CFrame = start * CFrame.new(0, -0.1, 0), Color = MAGENTA })
		local l1 = Kit.flatText(board, "50% OFF!", MAGENTA, Enum.NormalId.Top)
		Kit.tween(board, d.fall, { CFrame = final }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.tween(frame, d.fall, { CFrame = final * CFrame.new(0, -0.1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(d.fall, function()
			CartoonFX.sound("Crash", d.cf.Position, 1.2)
			CartoonFX.bigImpact(d.cf.Position + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, MAGENTA)
			CartoonFX.shockwave(d.cf.Position + Vector3.new(0, 0.2, 0), math.max(d.w, d.l) * 0.75, MAGENTA)
			Kit.cubes(d.cf.Position + Vector3.new(0, 0.8, 0), 20, { WHITE, MAGENTA, CYAN }, 0.7, 12, 0.5)
			CartoonFX.puff(d.cf * CFrame.new(d.w / 2, 0.5, 0).Position, 2)
			CartoonFX.puff(d.cf * CFrame.new(-d.w / 2, 0.5, 0).Position, 2)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.8)
			end
		end)
		task.delay(d.fall + 0.9, function()
			Kit.tween(board, 0.3, { Transparency = 1 })
			Kit.tween(frame, 0.3, { Transparency = 1 })
			Kit.tween(l1, 0.3, { TextTransparency = 1 })
		end)
		Debris:AddItem(board, d.fall + 1.25)
		Debris:AddItem(frame, d.fall + 1.25)
	end)

	Kit.on("MK_Viral", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.shockwave(r.Position - Vector3.new(0, 2.7, 0), d.r, MAGENTA)
		CartoonFX.shockwave(r.Position - Vector3.new(0, 2.5, 0), d.r * 0.6, CYAN)
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "+1M VIEWS!", MAGENTA, 3.2, 1.2, 2)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			heartAt(r.Position + Vector3.new(math.cos(a) * 3, Kit.rng:NextNumber(-1, 1.5), math.sin(a) * 3), (i % 2 == 0) and MAGENTA or Color3.fromRGB(255, 70, 110), 0.8)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur and r.Parent do
				heartAt(r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(0, 2.5), Kit.rng:NextNumber(-1.5, 1.5)), MAGENTA, 0.5)
				task.wait(0.25)
			end
		end)
	end)

	Kit.on("MK_Links", function(d)
		local beams = {}
		for _, v in ipairs(d.vs or {}) do
			table.insert(beams, { v = v, p = Kit.part({ Size = Vector3.new(0.3, 0.3, 1), Color = MAGENTA }) })
			local vr = v:FindFirstChild("HumanoidRootPart")
			if vr then
				Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "LET'S CIRCLE BACK", CYAN, 2.2, 0.7, 1)
			end
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
			if os.clock() - t0 > d.dur or not r then
				conn:Disconnect()
				for _, b in ipairs(beams) do
					b.p:Destroy()
				end
				return
			end
			for i, b in ipairs(beams) do
				local vr = b.v:FindFirstChild("HumanoidRootPart")
				if vr then
					local a, c = r.Position + Vector3.new(0, 1, 0), vr.Position
					local len = math.max((c - a).Magnitude, 0.1)
					b.p.Size = Vector3.new(0.3, 0.3, len)
					b.p.CFrame = CFrame.lookAt(a, c) * CFrame.new(0, 0, -len / 2)
					b.p.Color = (math.floor(os.clock() * 12 + i) % 2 == 0) and MAGENTA or CYAN
				end
			end
		end)
		CartoonFX.sound("Whoosh", nil, 0.8)
	end)

	Kit.on("MK_SynBoom", function(d)
		CartoonFX.sound("BigImpact", d.p, 1)
		CartoonFX.word(d.p + Vector3.new(0, 4, 0), "SYNERGY!", 1.4, "Heavy")
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), nil, 1.5, MAGENTA)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.5, 0), 12, MAGENTA)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.3, 0), 8, CYAN)
		confetti(d.p + Vector3.new(0, 1, 0), 30, 7, 1.2)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.9)
			CartoonFX.impactFrame(0.6)
		end
	end)

	Kit.on("MK_NoSyn", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "NO ENGAGEMENT...", WHITE, 2.4, 0.9, 1.5)
		end
	end)

	Kit.on("MK_Trend", function(d)
		local head = d.v and d.v:FindFirstChild("Head")
		if head then
			Kit.floatText(head.Position + Vector3.new(0, 2, 0), "TRENDING x" .. d.n, MAGENTA, 1.8 + d.n * 0.15, 0.8, 1.5)
		end
	end)

	-- aura de transformation : # et likes qui montent
	task.spawn(function()
		local tags = { "#", "LIKE", "#VIRAL", "+1" }
		while true do
			task.wait(0.35)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "MarketingGuru" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-2, 2))
						Kit.floatText(r.Position + off, tags[Kit.rng:NextInteger(1, #tags)], CONFETTI[Kit.rng:NextInteger(1, 3)], 1.2, 0.9, 2.5)
					end
				end
			end
		end
	end)
end

return M
