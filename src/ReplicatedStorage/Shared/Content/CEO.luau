--[[
	The CEO — personnage complet (format : voir Modules/ContentLoader).
	Passif Executive Privilege : -20 % de dégâts des objets ; régénère 1 PV/s après 4 s sans être touché.
	Attaques : Briefcase Swing (gros coup), Money Rain (pluie de billets qui ralentit), Hostile Takeover (saisie + projection).
	Transformation Golden Parachute : Stock Crash (flèche rouge du ciel qui plaque au sol), Buyout (attire tout le monde),
	You're Fired (lettre de licenciement lancée : éjection énorme).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL = Kit.CYL, Kit.BALL
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local GOLD = Color3.fromRGB(255, 200, 40)
local BLACK = Color3.fromRGB(30, 30, 36)
local CASH = Color3.fromRGB(110, 200, 100)
local DCASH = Color3.fromRGB(60, 150, 70)
local RED = Color3.fromRGB(230, 40, 40)
local PINK = Color3.fromRGB(255, 150, 190)

local M = { Id = "CEO", Order = 7 }

M.Character = {
	DisplayName = "The CEO",
	Role = "Heavy hitter",
	Color = GOLD,
	Shirt = BLACK, Pants = Color3.fromRGB(25, 25, 30), Tie = RED,
	Passive = { Name = "Executive Privilege", Desc = "Takes 20% less damage from items. Regenerates 1 HP per second after 4s without being hit." },
	Attacks = { "BriefcaseSwing", "MoneyRain", "HostileTakeover" },
	Transformation = { Name = "Golden Parachute", Desc = "Top hat, monocle and a golden parachute pack.", Duration = 20, SpeedMultiplier = 1.1 },
	TransAttacks = { "StockCrash", "Buyout", "YoureFired" },
}

M.Attacks = {
	BriefcaseSwing = { Name = "Briefcase Swing", Kind = "Melee", Desc = "A heavy two-handed briefcase golf swing that sends coworkers flying.", Prop = "CEOCase", Cooldown = 7, Anim = "BriefcaseSwing", Sound = "Whoosh",
		Windup = 0.28, HitboxOffset = 3.5, HitboxSize = Vector3.new(8, 6, 7), Damage = 13, Knockback = 52, KnockUp = 20, Stun = 1.0, Category = "Heavy", GuardBreak = true, Power = 1.0, Material = "Metal",
		Words = { "BRIEFCASE!", "WHAM!", "CHA-CHING!" } },
	MoneyRain = { Name = "Money Rain", Kind = "CEOMoneyRain", Desc = "Make it rain on the area ahead: falling cash slows and stings everyone under it.", Prop = "CEOCash", Cooldown = 11, Anim = "MoneyRain", Sound = "Ding",
		Offset = 12, Radius = 9, RainTime = 3.5, Tick = 0.4, SlowMult = 0.55, Damage = 1.2, Knockback = 2, Stun = 0.25, Category = "Light", Power = 0.2, Words = { "$$$!", "CHA-CHING!", "$!" } },
	HostileTakeover = { Name = "Hostile Takeover", Kind = "Grab", Desc = "Grab a coworker by the collar, lift them up and toss them away.", Cooldown = 9, Anim = "HostileTakeover", Sound = "Whoosh",
		HitboxOffset = 3.5, HitboxSize = Vector3.new(5, 6, 6), HoldTime = 0.6, Windup = 0.25, Damage = 11, ThrowKnockback = 62, ThrowUp = 24, Stun = 1.0, Category = "Heavy", Power = 0.95,
		Words = { "HOSTILE TAKEOVER!", "ACQUIRED!" } },
	StockCrash = { Name = "Stock Crash", Kind = "CEOStockCrash", Desc = "Point at the floor ahead: a giant red stock arrow crashes down from the sky and PINS everyone under it.", Cooldown = 12, Anim = "StockCrash", Sound = "Whoosh",
		Offset = 13, Radius = 10, Windup = 0.55, Damage = 15, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.2, Words = { "STOCK CRASH!", "-99%!" }, Effects = { Pin = true } },
	Buyout = { Name = "Buyout", Kind = "CEOBuyout", Desc = "Buy everyone out: pulls every nearby coworker to you, then knocks them down.", Cooldown = 12, Anim = "Buyout", Sound = "Ding",
		Windup = 0.25, Radius = 22, PullSpeed = 80, Damage = 7, Knockback = 14, KnockUp = 18, Stun = 1.0, Category = "Heavy", Power = 0.8, Words = { "BUYOUT!", "SOLD!" } },
	YoureFired = { Name = "You're Fired", Kind = "CEOPinkSlip", Desc = "Hurl a pink slip like a dart: whoever it hits is FIRED out of the building (huge launch).", Prop = "CEOSlip", Cooldown = 14, Anim = "YoureFired", Sound = "Whoosh",
		Windup = 0.3, Speed = 120, Range = 75, Damage = 15, Knockback = 10, Launch = Vector3.new(120, 60, 0), Stun = 1.3, Category = "Heavy", Power = 1.4,
		Words = { "YOU'RE FIRED!" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function rainAnim()
	local f = { { t = 0 }, { t = 0.08, RS = { p = 2.9, r = -0.3 }, LS = { p = 1.3, y = 0.6 }, RJ = { ln = -0.15, tw = 0.2 } } }
	local t = 0.08
	for i = 1, 6 do -- petits coups de poignet : on jette les billets
		t += 0.07
		table.insert(f, { t = t, RS = { p = (i % 2 == 0) and 2.9 or 2.4, y = (i % 2 == 0) and 0.3 or -0.3, r = -0.3 }, LS = { p = 1.3, y = 0.6 }, RJ = { ln = -0.15, tw = (i % 2 == 0) and 0.25 or 0.1 }, RH = { p = (i % 2 == 0) and 0.15 or -0.1 } })
	end
	table.insert(f, { t = t + 0.15 })
	return f
end

M.Anims = {
	BriefcaseSwing = { -- swing de golf : armement bas à droite, frappe qui remonte en diagonale
		{ t = 0 },
		{ t = 0.18, RS = { p = 0.7, y = -0.9, r = -0.6 }, LS = { p = 0.9, y = -1.2 }, RJ = { tw = -1.0, ln = 0.35 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
		{ t = 0.28, RS = { p = 0.6, y = -1.0, r = -0.7 }, LS = { p = 0.8, y = -1.3 }, RJ = { tw = -1.15, ln = 0.4 }, RH = { p = 0.35 }, LH = { p = 0.35 } },
		{ t = 0.36, RS = { p = 2.6, y = 1.0 }, LS = { p = 2.4, y = 1.2 }, RJ = { tw = 1.0, ln = -0.25 }, LH = { p = 0.4 }, RH = { p = -0.4 } },
		{ t = 0.62, RS = { p = 2.7, y = 1.0 }, LS = { p = 2.5, y = 1.2 }, RJ = { tw = 0.9, ln = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.8 },
	},
	MoneyRain = rainAnim(), -- liasse dans la main gauche, la droite jette les billets en l'air
	HostileTakeover = { -- saisie au col d'une main, soulève en ajustant sa cravate, puis lance de côté
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.7, y = 0.2 }, RJ = { ln = 0.25 }, LH = { p = 0.5 } },
		{ t = 0.22, RS = { p = 2.45, y = 0.1 }, LS = { p = 2.3, y = 1.2 }, RJ = { ln = -0.2 } },
		{ t = 0.6, RS = { p = 2.55, y = 0.1 }, LS = { p = 2.3, y = 1.2 }, RJ = { ln = -0.25, tw = -0.35 } },
		{ t = 0.72, RS = { p = 1.4, y = 1.25 }, LS = { p = 0.3 }, RJ = { tw = 0.85, ln = 0.2 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.92, RS = { p = 1.35, y = 1.2 }, LS = { p = 0.3 }, RJ = { tw = 0.75, ln = 0.15 } },
		{ t = 1.05 },
	},
	StockCrash = { -- montre le ciel du doigt, puis abat le bras vers le sol devant lui
		{ t = 0 },
		{ t = 0.14, RS = { p = 3.15, r = -0.15 }, LS = { p = 0.4, r = -0.4 }, RJ = { ln = -0.35, tw = 0.2 }, LH = { p = -0.2 } },
		{ t = 0.45, RS = { p = 3.2, r = -0.15 }, LS = { p = 0.4, r = -0.4 }, RJ = { ln = -0.4, tw = 0.2 }, LH = { p = -0.2 } },
		{ t = 0.55, RS = { p = 1.1, y = 0.2 }, LS = { p = -0.5 }, RJ = { ln = 0.55, tw = -0.1 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 0.9, RS = { p = 1.15, y = 0.2 }, LS = { p = -0.5 }, RJ = { ln = 0.5 }, RH = { p = 0.55 }, LH = { p = -0.3 } },
		{ t = 1.05 },
	},
	Buyout = { -- bras grands ouverts « tout est à vendre », puis ramène tout et frappe dans ses mains
		{ t = 0 },
		{ t = 0.18, RS = { p = 1.7, r = -1.4 }, LS = { p = 1.7, r = -1.4 }, RJ = { ln = -0.35 }, RH = { r = -0.25 }, LH = { r = -0.25 } },
		{ t = 0.28, RS = { p = 1.75, r = -1.45 }, LS = { p = 1.75, r = -1.45 }, RJ = { ln = -0.4 } },
		{ t = 0.5, RS = { p = 1.6, y = 0.85 }, LS = { p = 1.6, y = 0.85 }, RJ = { ln = 0.3 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.62, RS = { p = 1.55, y = 1.05 }, LS = { p = 1.55, y = 1.05 }, RJ = { ln = 0.35 } },
		{ t = 0.9, RS = { p = 1.55, y = 1.0 }, LS = { p = 1.55, y = 1.0 }, RJ = { ln = 0.3 } },
		{ t = 1.05 },
	},
	YoureFired = { -- pointe du doigt (pause dramatique), arme le bras derrière la tête, lancer de fléchette avec tout le buste
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.7, y = 0.05 }, LS = { p = 0.2, r = -0.3 }, RJ = { ln = -0.3, tw = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.22, RS = { p = 3.0, r = -0.3 }, LS = { p = 1.3 }, RJ = { ln = -0.3, tw = -0.55 }, LH = { p = 0.75 }, RH = { p = 0.1 } },
		{ t = 0.3, RS = { p = 1.4, y = 0.25 }, LS = { p = -0.5 }, RJ = { ln = 0.45, tw = 0.65 }, LH = { p = 0.85 }, RH = { p = -0.5 } },
		{ t = 0.55, RS = { p = 1.3, y = 0.25 }, LS = { p = -0.4 }, RJ = { ln = 0.32, tw = 0.5 }, LH = { p = 0.6 }, RH = { p = -0.4 } },
		{ t = 0.72 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
M.Props = {
	CEOCase = {
		{ Vector3.new(0.6, 1.7, 2.5), CFrame.new(0, -2.3, 0), BLACK },
		{ Vector3.new(0.62, 0.14, 2.52), CFrame.new(0, -1.75, 0), GOLD },
		{ Vector3.new(0.64, 0.35, 0.35), CFrame.new(0, -1.85, -0.6), GOLD },
		{ Vector3.new(0.64, 0.35, 0.35), CFrame.new(0, -1.85, 0.6), GOLD },
		{ Vector3.new(0.25, 0.35, 0.8), CFrame.new(0, -1.3, 0), GOLD },
	},
	CEOCash = {
		{ Vector3.new(0.08, 1.3, 0.65), CFrame.new(0, -1.5, -0.2) * CFrame.Angles(0, 0, 0.25), CASH },
		{ Vector3.new(0.08, 1.3, 0.65), CFrame.new(0.05, -1.5, -0.2), DCASH },
		{ Vector3.new(0.08, 1.3, 0.65), CFrame.new(0.1, -1.5, -0.2) * CFrame.Angles(0, 0, -0.25), CASH },
	},
	CEOSlip = {
		{ Vector3.new(0.06, 1.3, 1.0), CFrame.new(0, -1.55, -0.25), PINK },
		{ Vector3.new(0.07, 0.2, 0.8), CFrame.new(0, -1.15, -0.25), RED },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : cheveux gominés, montre en or, pince à cravate, col blanc ; mallette à la main droite
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	local HAIR = Color3.fromRGB(55, 38, 25)
	prop(f, head, Vector3.new(1.32, 0.32, 1.3), CFrame.new(0, 0.58, 0.06), HAIR)
	prop(f, head, Vector3.new(1.32, 0.7, 0.3), CFrame.new(0, 0.28, 0.55), HAIR)
	prop(f, head, Vector3.new(0.9, 0.22, 0.4), CFrame.new(0.1, 0.72, -0.35) * CFrame.Angles(0.3, 0, 0), HAIR) -- mèche
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(0.4, 0.45, 0.06), CFrame.new(0.2 * s, 0.78, -0.53) * CFrame.Angles(0, 0, 0.5 * s), Color3.fromRGB(250, 250, 250)) -- col
		prop(f, torso, Vector3.new(0.16, 1.4, 0.06), CFrame.new(0.42 * s, 0.25, -0.53) * CFrame.Angles(0, 0, -0.25 * s), Color3.fromRGB(55, 55, 65)) -- revers
	end
	prop(f, torso, Vector3.new(0.32, 1.3, 0.06), CFrame.new(0, 0.2, -0.54), RED) -- cravate
	prop(f, torso, Vector3.new(0.5, 0.1, 0.08), CFrame.new(0, 0.3, -0.58), GOLD) -- pince à cravate
	prop(f, torso, Vector3.new(0.35, 0.2, 0.06), CFrame.new(0.55, 0.55, -0.54), GOLD) -- pochette
	local la = c:FindFirstChild("Left Arm")
	if la then
		prop(f, la, Vector3.new(1.06, 0.25, 1.06), CFrame.new(0, -0.7, 0), GOLD) -- montre
		prop(f, la, Vector3.new(0.1, 0.3, 0.3), CFrame.new(-0.55, -0.7, 0), Color3.fromRGB(250, 250, 250))
	end
end

M.Signature = { Hand = "Right", Build = function(f, a, prop) -- mallette noire et or
	prop(f, a, Vector3.new(0.5, 1.25, 1.8), CFrame.new(0, -2.05, 0), BLACK)
	prop(f, a, Vector3.new(0.52, 0.1, 1.82), CFrame.new(0, -1.6, 0), GOLD)
	prop(f, a, Vector3.new(0.54, 0.25, 0.25), CFrame.new(0, -1.7, -0.5), GOLD)
	prop(f, a, Vector3.new(0.54, 0.25, 0.25), CFrame.new(0, -1.7, 0.5), GOLD)
	prop(f, a, Vector3.new(0.2, 0.3, 0.6), CFrame.new(0, -1.3, 0), GOLD)
end }

-- Transformation : haut-de-forme, monocle, sac parachute doré
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.25, 1.1, 1.1), CFrame.new(0, 1.25, 0) * Kit.UPRIGHT, BLACK, CYL)
	prop(f, head, Vector3.new(0.14, 1.8, 1.8), CFrame.new(0, 0.72, 0) * Kit.UPRIGHT, BLACK, CYL)
	prop(f, head, Vector3.new(0.25, 1.13, 1.13), CFrame.new(0, 0.9, 0) * Kit.UPRIGHT, GOLD, CYL)
	prop(f, head, Vector3.new(0.06, 0.42, 0.42), CFrame.new(0.26, 0.1, -0.63) * ALONG_Z, GOLD, CYL) -- monocle
	local lens = prop(f, head, Vector3.new(0.06, 0.32, 0.32), CFrame.new(0.26, 0.1, -0.65) * ALONG_Z, Color3.fromRGB(220, 245, 255), CYL)
	lens.Transparency = 0.3
	prop(f, head, Vector3.new(0.04, 0.7, 0.04), CFrame.new(0.45, -0.25, -0.6) * CFrame.Angles(0, 0, 0.3), GOLD) -- chaînette
	prop(f, torso, Vector3.new(1.5, 1.4, 0.5), CFrame.new(0, 0.1, 0.75), GOLD) -- parachute doré
	prop(f, torso, Vector3.new(1.2, 0.3, 0.52), CFrame.new(0, 0.6, 0.76), Color3.fromRGB(255, 240, 160))
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(0.2, 2.0, 0.1), CFrame.new(0.6 * s, 0.1, -0.55), GOLD) -- sangles
	end
end

------------------------------------------------------------------------
-- Serveur
------------------------------------------------------------------------
local function inArea(attacker, center, radius)
	local list = {}
	for _, v in ipairs(Kit.enemies(attacker)) do
		local vp = Kit.root(v).Position
		if Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude <= radius and math.abs(vp.Y - center.Y) < 9 then
			table.insert(list, v)
		end
	end
	return list
end

M.Kinds = {
	-- Money Rain : zone de billets devant, ralentit et pique à chaque tick
	CEOMoneyRain = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		Kit.fx({ id = "CEORain", p = center, r = cfg.Radius, dur = cfg.RainTime })
		task.wait(0.25)
		local t0 = os.clock()
		local first = {}
		while os.clock() - t0 < cfg.RainTime do
			for _, v in ipairs(inArea(attacker, center, cfg.Radius)) do
				local over = first[v] and { Words = { "$", "$$" }, Power = 0.15 } or nil
				first[v] = true
				if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir), over) == "Hit" then
					api.CharacterState.setSpeedMod(v, "MoneyRain", cfg.SlowMult, cfg.Tick + 0.4)
				end
			end
			task.wait(cfg.Tick)
		end
	end,

	-- Stock Crash : flèche rouge géante qui tombe du ciel sur la zone visée
	CEOStockCrash = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		Kit.fx({ id = "CEOArrow", p = center, fall = cfg.Windup, a = attacker, r = cfg.Radius })
		task.wait(cfg.Windup)
		for _, v in ipairs(inArea(attacker, center, cfg.Radius)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir))
		end
		Kit.rawFX({ k = "Slam", p = center, a = attacker })
		api.ZoneService.shatterAround(center, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
	end,

	-- You're Fired : lettre de licenciement lancée comme une fléchette ; la cible touchée est éjectée très loin
	CEOPinkSlip = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1.2, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.new(1.4, 0.12, 2.0), color = PINK, spin = 0,
			decorate = function(part)
				local gui = Instance.new("SurfaceGui")
				gui.Face = Enum.NormalId.Top
				gui.LightInfluence = 0
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 50
				gui.Parent = part
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.Font = Enum.Font.LuckiestGuy
				l.TextScaled = true
				l.TextColor3 = RED
				l.Text = "FIRED"
				l.Rotation = 90
				l.Parent = gui
			end,
			onHit = function(v, pos, vel)
				if api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos }) == "Hit" then
					Kit.fx({ id = "CEOFired", v = v, p = pos, a = attacker })
				end
				return nil
			end,
		})
	end,

	-- Buyout : attire tous les ennemis proches, puis les renverse
	CEOBuyout = function(attacker, cfg, aim, api)
		Kit.rawFX({ k = "Telegraph", shape = "Circle", a = attacker, r = cfg.Radius, dur = cfg.Windup })
		task.wait(cfg.Windup)
		local root = Kit.root(attacker)
		if not root or not api.CharacterState.isAlive(attacker) then
			return
		end
		local victims, maxT = {}, 0
		for _, v in ipairs(Kit.inRadius(attacker, root.Position, cfg.Radius)) do
			if not Kit.isProtected(v) then
				table.insert(victims, v)
			end
		end
		Kit.fx({ id = "CEOBuyout", a = attacker, vs = victims, dur = 0.6 })
		for _, v in ipairs(victims) do
			local d = (Kit.root(v).Position - root.Position).Magnitude
			api.CharacterState.stun(v, math.clamp((d - 4) / cfg.PullSpeed, 0.1, 0.9) + 0.5)
			maxT = math.max(maxT, Kit.pull(v, root.Position, cfg.PullSpeed, 4))
		end
		task.wait(maxT + 0.05)
		for _, v in ipairs(victims) do
			if api.CharacterState.isAlive(v) and api.CharacterState.isAlive(attacker) then
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector))
			end
		end
	end,
}

function M.ServerInit(api)
	table.insert(api.CombatService.damageMods, function(p)
		if p.itemId and p.victim:GetAttribute("CharacterName") == "CEO" then
			p.damage *= 0.8
		end
	end)
	-- régénération hors combat
	task.spawn(function()
		while true do
			task.wait(1)
			for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
				local c = pl.Character
				local hum = c and c:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth and c:GetAttribute("CharacterName") == "CEO" then
					local s = api.CharacterState.get(c)
					if os.clock() - (s.lastHitTime or -100) > 4 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + 1)
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------
local function bill(pos, color)
	return Kit.part({ Size = Vector3.new(1.3, 0.08, 0.65), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = color or CASH })
end

M.MoveFX = {
	BriefcaseSwing = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), GOLD, 0.7, 1.6, 1.6)
		task.delay(0.1, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.dust(r.Position - Vector3.new(0, 2.8, 0), 4, nil, 6)
			end
		end)
		task.delay(0.3, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.slashArc(r.CFrame * CFrame.new(0, -0.2, 0), 4.8, GOLD, -100, 70, 0.08, -35, 0.6)
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 1, 0), r.CFrame.LookVector + Vector3.new(0, 0.5, 0), 9, GOLD, 0.25)
				api.CartoonFX.casterShake(c, 0.6)
			end
		end)
		task.delay(0.32, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				for _ = 1, 6 do
					local b = bill(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 1, 0))
					Kit.tween(b, 0.6, { CFrame = b.CFrame * CFrame.new(api.rng:NextNumber(-3, 3), api.rng:NextNumber(1, 4), api.rng:NextNumber(-3, 3)) * CFrame.Angles(2, 1, 0), Transparency = 1 })
					api.Debris:AddItem(b, 0.62)
				end
			end
		end)
	end,
	HostileTakeover = function(c, d, api)
		task.delay(0.72, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0), r.CFrame.LookVector + r.CFrame.RightVector * 0.8, 8, GOLD, 0.25)
				api.CartoonFX.dust(r.Position - Vector3.new(0, 2.8, 0), 6, nil, 8)
				api.CartoonFX.casterShake(c, 0.5)
			end
		end)
		task.delay(0.25, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				Kit.floatText(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 4, 0), "$$$", GOLD, 2.4, 0.8, 2)
			end
		end)
	end,
	Buyout = function(c, d, api)
		-- anneaux dorés qui se resserrent vers le PDG
		task.spawn(function()
			for _ = 1, 3 do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.25, 44, 44), CFrame = CFrame.new(r.Position - Vector3.new(0, 2.6, 0)) * Kit.UPRIGHT, Color = GOLD, Transparency = 0.6 })
				Kit.tween(ring, 0.35, { Size = Vector3.new(0.25, 2, 2), Transparency = 0.1 })
				api.Debris:AddItem(ring, 0.36)
				task.wait(0.1)
			end
		end)
	end,
	YoureFired = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "...", Color3.new(1, 1, 1), 2.5, 0.4, 0.5)
		end
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), PINK, 0.5, 1, 1)
		task.delay(0.3, function()
			local r2 = c:FindFirstChild("HumanoidRootPart")
			if not r2 then
				return
			end
			api.CartoonFX.airRing(r2.Position + r2.CFrame.LookVector * 2.5 + Vector3.new(0, 1.2, 0), r2.CFrame.LookVector, 7, PINK, 0.22)
			api.CartoonFX.airRing(r2.Position + r2.CFrame.LookVector * 4 + Vector3.new(0, 1.2, 0), r2.CFrame.LookVector, 5, RED, 0.22)
			if Kit.mine(c) then
				api.CartoonFX.speedLines(0.3, RED)
			end
		end)
	end,
	StockCrash = function(c, d, api)
		task.delay(0.14, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.implode(r.Position + Vector3.new(0.8, 4.5, 0), 5, { RED, GOLD }, 10, 0.25)
				api.CartoonFX.light(r.Position + Vector3.new(0, 4.5, 0), RED, 16, 3, 0.4)
			end
		end)
	end,
	MoneyRain = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), CASH, 0.6, 1, 0.8)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	-- pluie de billets
	Kit.on("CEORain", function(d)
		local disc = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d.r * 2, d.r * 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.08, 0)) * Kit.UPRIGHT, Color = CASH, Transparency = 0.6 })
		Debris:AddItem(disc, d.dur + 0.3)
		CartoonFX.sound("Ding", d.p, 0.8)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				for _ = 1, 3 do
					local a, rr = Kit.rng:NextNumber(0, math.pi * 2), Kit.rng:NextNumber(0, d.r)
					local pos = d.p + Vector3.new(math.cos(a) * rr, 14, math.sin(a) * rr)
					local b = bill(pos, Kit.rng:NextNumber() < 0.5 and CASH or DCASH)
					Kit.tween(b, 0.9, { CFrame = CFrame.new(pos - Vector3.new(Kit.rng:NextNumber(-1, 1), 13.6, Kit.rng:NextNumber(-1, 1))) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0) }, Enum.EasingStyle.Sine)
					task.delay(0.9, function()
						Kit.tween(b, 0.3, { Transparency = 1 })
					end)
					Debris:AddItem(b, 1.25)
				end
				task.wait(0.06)
			end
			Kit.tween(disc, 0.3, { Transparency = 1 })
		end)
		Kit.floatText(d.p + Vector3.new(0, 5, 0), "MAKE IT RAIN!", GOLD, 3.5, 1, 1.5)
	end)

	-- flèche boursière rouge qui s'écrase
	Kit.on("CEOArrow", function(d)
		CartoonFX.bigTelegraph(d.p, d.r, d.fall, Kit.mine(d.a) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60))
		local model = {}
		local top = d.p + Vector3.new(0, 45, 0)
		-- flèche de graphique boursier qui pique vers le sol (pointe en bas, légèrement inclinée)
		local tilt = CFrame.new(top) * CFrame.Angles(0, 0, 0.3)
		local shaft = Kit.part({ Size = Vector3.new(2.6, 13, 1.2), CFrame = tilt * CFrame.new(0, 8.5, 0), Color = RED })
		local headL = Kit.part({ Size = Vector3.new(1.6, 6, 1.25), CFrame = tilt * CFrame.Angles(0, 0, 0.7) * CFrame.new(0, 2.6, 0), Color = RED })
		local headR = Kit.part({ Size = Vector3.new(1.6, 6, 1.25), CFrame = tilt * CFrame.Angles(0, 0, -0.7) * CFrame.new(0, 2.6, 0), Color = RED })
		local tip = Kit.part({ Size = Vector3.new(1.9, 1.9, 1.25), CFrame = tilt * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = RED })
		model = { shaft, headL, headR, tip }
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = Color3.new(1, 1, 1)
		outline.Adornee = shaft
		outline.Parent = shaft
		for _, p in ipairs(model) do
			Kit.tween(p, d.fall, { CFrame = p.CFrame - Vector3.new(0, 45, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		Kit.floatText(d.p + Vector3.new(0, 6, 0), "SELL! SELL!", RED, 3, d.fall, 1)
		task.delay(d.fall, function()
			CartoonFX.sound("GroundSlam", d.p, 1.3)
			CartoonFX.sound("Crash", d.p, 1)
			CartoonFX.quake(d.p, d.r * 1.2, RED, 1.4)
			Kit.cubes(d.p + Vector3.new(0, 1, 0), 18, { RED, Color3.new(1, 1, 1), GOLD }, 0.9, 12, 0.6)
			Kit.floatText(d.p + Vector3.new(0, 4, 0), "-99%", RED, 4, 1, 2)
			CartoonFX.casterShake(d.a, 1.1)
			task.delay(0.5, function()
				for _, p in ipairs(model) do
					Kit.tween(p, 0.3, { Transparency = 1 })
				end
			end)
		end)
		for _, p in ipairs(model) do
			Debris:AddItem(p, d.fall + 0.85)
		end
	end)

	-- You're Fired : tampon FIRED + lettres roses qui explosent
	Kit.on("CEOFired", function(d)
		CartoonFX.word(d.p + Vector3.new(0, 3, 0), "FIRED!", 1.4, "KO")
		CartoonFX.sound("BigImpact", d.p, 1.1)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		local ar = d.a and d.a:FindFirstChild("HumanoidRootPart")
		CartoonFX.airRing(d.p, (vr and ar) and (vr.Position - ar.Position) or Vector3.new(0, 1, 0), 12, PINK, 0.3)
		for _ = 1, 10 do
			local s = Kit.part({ Size = Vector3.new(0.9, 0.06, 1.2), CFrame = CFrame.new(d.p), Color = (Kit.rng:NextNumber() < 0.5) and PINK or Color3.new(1, 1, 1) })
			Kit.tween(s, 0.7, { CFrame = CFrame.new(d.p + Vector3.new(Kit.rng:NextNumber(-6, 6), Kit.rng:NextNumber(1, 6), Kit.rng:NextNumber(-6, 6))) * CFrame.Angles(3, 2, 1), Transparency = 1 })
			Debris:AddItem(s, 0.72)
		end
		CartoonFX.casterShake(d.a, 0.8)
	end)

	-- chaînes de pièces entre le PDG et chaque victime attirée
	Kit.on("CEOBuyout", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Ding", r.Position, 1)
		for _, v in ipairs(d.vs or {}) do
			local vr = v:FindFirstChild("HumanoidRootPart")
			if vr then
				Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "SOLD!", GOLD, 2.5, 0.8, 1.5)
				for i = 1, 5 do
					task.delay(i * 0.06, function()
						if not vr.Parent or not r.Parent then
							return
						end
						local coin = Kit.part({ Shape = CYL, Size = Vector3.new(0.18, 0.9, 0.9), CFrame = CFrame.new(vr.Position + Vector3.new(0, 1, 0)), Color = GOLD })
						Kit.tween(coin, 0.3, { CFrame = CFrame.new(r.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 4, 0) })
						Debris:AddItem(coin, 0.32)
					end)
				end
			end
		end
	end)

	-- aura dorée : $ qui montent en transformation
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "CEO" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(-2, 1), Kit.rng:NextNumber(-2, 2))
						Kit.floatText(r.Position + off, "$", GOLD, 1.2, 0.9, 2.5)
					end
				end
			end
		end
	end)
end

return M
