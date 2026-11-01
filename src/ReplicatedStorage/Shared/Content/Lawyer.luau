--[[
	The Lawyer — personnage complet (format : voir Modules/ContentLoader).
	Passif « Billable Hours » : chaque 5e coup qu'il porte est facturé (+6 dégâts, pluie de billets).
	Attaques : Order in the Court (saut + coup de marteau qui plaque au sol), Law Book Barrage (3 codes de loi lancés en cloche), OBJECTION! (posture de contre : parade + riposte).
	Transformation Court Is In Session : Sign Here (contrat au sol qui enchaîne/immobilise), Class Action (assignation de zone + dégâts sur la durée), Cross-Examination (saisie + coups de marteau + « GUILTY! »).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT

local BURGUNDY = Color3.fromRGB(140, 22, 50)
local GOLD = Color3.fromRGB(235, 190, 60)
local WOOD = Color3.fromRGB(120, 70, 35)
local DARKWOOD = Color3.fromRGB(80, 45, 25)
local PAPER = Color3.fromRGB(245, 240, 225)
local CHAIN = Color3.fromRGB(195, 195, 205)
local DARK = Color3.fromRGB(28, 26, 32)
local CASH = Color3.fromRGB(110, 200, 100)
local BOOKS = { BURGUNDY, Color3.fromRGB(40, 70, 140), Color3.fromRGB(30, 100, 60) }

local M = { Id = "Lawyer", Order = 15 }

M.Character = {
	DisplayName = "The Lawyer",
	Role = "Counter specialist",
	Color = BURGUNDY,
	Shirt = Color3.fromRGB(125, 20, 45), Pants = Color3.fromRGB(45, 30, 40), Tie = GOLD,
	Passive = { Name = "Billable Hours", Desc = "Every 5th hit he lands gets billed: +6 bonus damage and a shower of cash." },
	Attacks = { "GavelSlam", "LawBooks", "Objection" },
	Transformation = { Name = "Court Is In Session", Desc = "Black judge's robe, a powdered white wig and floating golden scales of justice.", Duration = 20, SpeedMultiplier = 1.1 },
	TransAttacks = { "SignHere", "ClassAction", "CrossExamination" },
}

M.Attacks = {
	GavelSlam = { Name = "Order in the Court", Kind = "LWGavel", Desc = "Leap forward and bring your giant gavel down: pins everyone where you land.", Prop = "LWGavelBig", Cooldown = 8, Anim = "LWGavelSlam", Sound = "Whoosh",
		Windup = 0.4, Forward = 13, JumpUp = 30, Radius = 8, Damage = 12, Knockback = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.0, Material = "Wood", Words = { "ORDER!", "ORDER IN THE COURT!" }, Effects = { Pin = true } },
	LawBooks = { Name = "Law Book Barrage", Kind = "LWBooks", Desc = "Hurl 3 heavy law books in a row. Read the fine print!", Prop = "LWBook", Cooldown = 7, Anim = "LWBooks", Sound = "Throw",
		Count = 3, Interval = 0.18, Spread = 5, Speed = 85, Range = 65, Gravity = 0.3, Up = 8, Size = Vector3.new(1.7, 0.55, 2.1), Colors = BOOKS,
		Damage = 4, Knockback = 12, KnockUp = 4, Stun = 0.5, Category = "Projectile", Power = 0.45, Words = { "THWACK!", "PAGE 1!", "AMENDED!" } },
	Objection = { Name = "OBJECTION!", Kind = "LWObjection", Desc = "Point and object for 1 s: the first attack that hits you is parried, and you counter with a blast that launches the attacker.", Cooldown = 10, Anim = "LWObjection", Sound = "Ding",
		Duration = 1.0, CounterDamage = 8, Words = { "OBJECTION!" } },
	SignHere = { Name = "Sign Here", Kind = "LWContract", Desc = "A giant contract unrolls under the closest coworker in front: whoever is on it gets chained in place for 2 s.", Prop = "LWScroll", Cooldown = 12, Anim = "LWSignHere", Sound = "Clang",
		Windup = 0.45, Range = 30, Offset = 12, Radius = 6, Root = 2.0, Damage = 7, Knockback = 0, Stun = 2.0, Category = "Heavy", GuardBreak = true, Power = 0.7, Words = { "SIGNED!", "BINDING!" } },
	ClassAction = { Name = "Class Action", Kind = "LWLawsuit", Desc = "Throw a storm of subpoenas around you: everyone hit is SUED and keeps losing health to legal fees.", Prop = "LWPapers", Cooldown = 13, Anim = "LWClassAction", Sound = "Whoosh",
		Windup = 0.3, Radius = 14, Ticks = 5, TickInterval = 0.6, TickDamage = 2, Damage = 4, Knockback = 20, KnockUp = 8, Stun = 0.6, Category = "Light", Power = 0.5, Words = { "SERVED!", "SUED!" } },
	CrossExamination = { Name = "Cross-Examination", Kind = "LWCross", Desc = "Grab the coworker in front, grill them with 4 gavel bonks, then slam a GUILTY! verdict that launches them.", Prop = "LWGavel", Cooldown = 12, Anim = "LWCross", Sound = "Punch",
		Range = 7, Width = 6, Bonks = 4, Interval = 0.16, Damage = 2, Knockback = 0, KnockUp = 0, Stun = 0.7, Category = "Light", Power = 0.35, Material = "Wood", Words = { "WHERE WERE YOU?", "LIES!", "ANSWER!", "HMM?" },
		Final = { Damage = 8, Knockback = 10, Launch = Vector3.new(8, 52, 0), Stun = 1.0, Category = "Heavy", Power = 1.1, Words = { "GUILTY!", "CASE CLOSED!" } } },
}

------------------------------------------------------------------------
-- Animations (une par attaque)
------------------------------------------------------------------------
local function crossAnim()
	local f = { { t = 0 }, { t = 0.07, LS = { p = 1.6, y = 0.3 }, RS = { p = 2.8, r = -0.2 }, RJ = { ln = -0.1, tw = 0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 } } }
	local t = 0.12
	for i = 1, 4 do
		table.insert(f, { t = t, LS = { p = 1.6, y = 0.3 }, RS = { p = 2.9, r = -0.2 }, RJ = { ln = -0.15, tw = 0.25 }, RH = { p = 0.3 }, LH = { p = -0.2 } })
		table.insert(f, { t = t + 0.07, LS = { p = 1.55, y = 0.3 }, RS = { p = 1.2, y = 0.1 }, RJ = { ln = 0.3, tw = -0.15 }, RH = { p = 0.45 }, LH = { p = -0.3 } })
		t += 0.16
	end
	table.insert(f, { t = t + 0.15, LS = { p = 0.6, r = -0.4 }, RS = { p = 3.25, r = -0.15 }, RJ = { ln = -0.5, tw = 0.1 }, RH = { p = 0.2 }, LH = { p = -0.1 } })
	table.insert(f, { t = t + 0.24, LS = { p = -0.3, r = -0.5 }, RS = { p = 0.7, y = 0.15 }, RJ = { ln = 0.95 }, RH = { p = 1.05 }, LH = { p = -0.45 } })
	table.insert(f, { t = t + 0.5, LS = { p = -0.3, r = -0.5 }, RS = { p = 0.75, y = 0.15 }, RJ = { ln = 0.85 }, RH = { p = 1.0 }, LH = { p = -0.4 } })
	table.insert(f, { t = t + 0.7 })
	return f
end

M.Anims = {
	LWGavelSlam = { -- s'accroupit, bondit marteau levé à deux mains, s'écrase genoux pliés
		{ t = 0 },
		{ t = 0.08, RS = { p = 2.3 }, LS = { p = 2.3 }, RJ = { ln = 0.35 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ t = 0.22, RS = { p = 3.1, r = -0.1 }, LS = { p = 3.1, r = -0.1 }, RJ = { ln = -0.45 }, RH = { p = 0.9 }, LH = { p = 0.25 } },
		{ t = 0.38, RS = { p = 3.25, r = -0.1 }, LS = { p = 3.25, r = -0.1 }, RJ = { ln = -0.55 }, RH = { p = 1.0 }, LH = { p = 0.35 } },
		{ t = 0.45, RS = { p = 0.6, y = 0.2 }, LS = { p = 0.6, y = 0.2 }, RJ = { ln = 1.05 }, RH = { p = 1.15 }, LH = { p = -0.4 } },
		{ t = 0.75, RS = { p = 0.65, y = 0.2 }, LS = { p = 0.65, y = 0.2 }, RJ = { ln = 0.95 }, RH = { p = 1.1 }, LH = { p = -0.4 } },
		{ t = 0.95 },
	},
	LWBooks = { -- trois lancers en alternant les bras, buste qui vrille à chaque fois
		{ t = 0 },
		{ t = 0.08, RS = { p = -0.7, r = -0.2 }, LS = { p = 0.6 }, RJ = { tw = -0.55 }, LH = { p = 0.3 } },
		{ t = 0.16, RS = { p = 2.1, y = 0.2 }, LS = { p = 0.2 }, RJ = { tw = 0.55, ln = 0.2 }, LH = { p = 0.55 }, RH = { p = -0.3 } },
		{ t = 0.26, LS = { p = -0.7, r = -0.2 }, RS = { p = 0.6 }, RJ = { tw = 0.55 }, RH = { p = 0.3 } },
		{ t = 0.34, LS = { p = 2.1, y = 0.2 }, RS = { p = 0.2 }, RJ = { tw = -0.55, ln = 0.2 }, RH = { p = 0.55 }, LH = { p = -0.3 } },
		{ t = 0.44, RS = { p = -0.8, r = -0.3 }, LS = { p = 0.6 }, RJ = { tw = -0.7, ln = -0.1 }, LH = { p = 0.3 } },
		{ t = 0.52, RS = { p = 2.3, y = 0.2 }, LS = { p = -0.3 }, RJ = { tw = 0.7, ln = 0.3 }, LH = { p = 0.65 }, RH = { p = -0.4 } },
		{ t = 0.75 },
	},
	LWObjection = { -- doigt pointé dramatique, l'autre main sur la hanche, buste qui avance
		{ t = 0 },
		{ t = 0.07, RS = { p = 1.65 }, LS = { p = 0.35, r = 0.65, y = -0.4 }, RJ = { tw = 0.5, ln = 0.18 }, RH = { p = 0.45 }, LH = { p = -0.3 } },
		{ t = 0.95, RS = { p = 1.7 }, LS = { p = 0.35, r = 0.65, y = -0.4 }, RJ = { tw = 0.45, ln = 0.2 }, RH = { p = 0.45 }, LH = { p = -0.3 } },
		{ t = 1.15 },
	},
	LWSignHere = { -- déroule le contrat à bout de bras, le lève, puis le plaque au sol
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.5, r = -0.9 }, LS = { p = 1.5, r = -0.9 }, RJ = { ln = 0.05 } },
		{ t = 0.38, RS = { p = 2.7, r = -0.3 }, LS = { p = 2.7, r = -0.3 }, RJ = { ln = -0.3 } },
		{ t = 0.46, RS = { p = 0.9, y = 0.2 }, LS = { p = 0.9, y = 0.2 }, RJ = { ln = 0.75 }, RH = { p = 0.7 }, LH = { p = -0.35 } },
		{ t = 0.75, RS = { p = 0.95, y = 0.2 }, LS = { p = 0.95, y = 0.2 }, RJ = { ln = 0.7 }, RH = { p = 0.65 }, LH = { p = -0.3 } },
		{ t = 0.95 },
	},
	LWClassAction = { -- ramasse la pile de papiers puis la jette en l'air à deux mains
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.6 }, LS = { p = 0.6 }, RJ = { ln = 0.45 }, RH = { p = 0.5 }, LH = { p = 0.1 } },
		{ t = 0.3, RS = { p = 3.1, r = -0.6 }, LS = { p = 3.1, r = -0.6 }, RJ = { ln = -0.45 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.65, RS = { p = 3.0, r = -0.7 }, LS = { p = 3.0, r = -0.7 }, RJ = { ln = -0.4 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.85 },
	},
	LWCross = crossAnim(), -- tient le col d'une main et assène des coups de marteau, puis verdict final
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	LWGavelBig = {
		{ Vector3.new(0.38, 0.38, 3.0), CFrame.new(0, -1.1, -1.5), WOOD },
		{ Vector3.new(2.4, 1.3, 1.3), CFrame.new(0, -1.1, -3.25), DARKWOOD, CYL },
		{ Vector3.new(0.22, 1.36, 1.36), CFrame.new(0.75, -1.1, -3.25), GOLD, CYL },
		{ Vector3.new(0.22, 1.36, 1.36), CFrame.new(-0.75, -1.1, -3.25), GOLD, CYL },
	},
	LWGavel = {
		{ Vector3.new(0.26, 0.26, 1.7), CFrame.new(0, -1.1, -0.85), WOOD },
		{ Vector3.new(1.3, 0.75, 0.75), CFrame.new(0, -1.1, -1.8), DARKWOOD, CYL },
		{ Vector3.new(0.14, 0.8, 0.8), CFrame.new(0.42, -1.1, -1.8), GOLD, CYL },
		{ Vector3.new(0.14, 0.8, 0.8), CFrame.new(-0.42, -1.1, -1.8), GOLD, CYL },
	},
	LWBook = {
		{ Vector3.new(0.45, 1.4, 1.15), CFrame.new(0, -1.35, -0.4), BURGUNDY },
		{ Vector3.new(0.38, 1.3, 0.05), CFrame.new(0, -1.35, -0.98), PAPER },
		{ Vector3.new(0.47, 0.15, 1.17), CFrame.new(0, -1.0, -0.4), GOLD },
	},
	LWScroll = {
		{ Vector3.new(1.8, 0.45, 0.45), CFrame.new(0, -1.1, -0.35), PAPER, CYL },
		{ Vector3.new(0.12, 0.55, 0.55), CFrame.new(0.92, -1.1, -0.35), WOOD, CYL },
		{ Vector3.new(0.12, 0.55, 0.55), CFrame.new(-0.92, -1.1, -0.35), WOOD, CYL },
		{ Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, -1.1, -0.6), Color3.fromRGB(200, 30, 30) },
	},
	LWPapers = {
		{ Vector3.new(0.6, 1.0, 1.3), CFrame.new(0, -1.3, -0.4), PAPER },
		{ Vector3.new(0.62, 0.1, 1.32), CFrame.new(0, -1.0, -0.4), Color3.fromRGB(200, 30, 30) },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : costume rayé, cheveux gominés, pochette, insigne balance
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	for i = -2, 2 do
		prop(f, torso, Vector3.new(0.04, 2.0, 0.04), CFrame.new(i * 0.38, 0, -0.52), Color3.fromRGB(190, 120, 140)) -- fines rayures
	end
	prop(f, torso, Vector3.new(0.4, 0.3, 0.08), CFrame.new(-0.55, 0.5, -0.55), GOLD) -- pochette
	prop(f, torso, Vector3.new(0.5, 0.1, 0.08), CFrame.new(0, 0.2, -0.56), GOLD) -- pince à cravate
	prop(f, torso, Vector3.new(0.35, 0.06, 0.06), CFrame.new(0.55, 0.62, -0.56), GOLD) -- insigne balance
	prop(f, torso, Vector3.new(0.06, 0.25, 0.06), CFrame.new(0.55, 0.52, -0.56), GOLD)
	prop(f, head, Vector3.new(1.28, 0.3, 1.15), CFrame.new(0, 0.6, 0.05), Color3.fromRGB(35, 25, 20)) -- cheveux gominés
	prop(f, head, Vector3.new(1.28, 0.6, 0.3), CFrame.new(0, 0.3, 0.55), Color3.fromRGB(35, 25, 20))
	prop(f, head, Vector3.new(0.5, 0.2, 0.06), CFrame.new(0.27, 0.12, -0.62), DARK) -- lunettes demi-lune
	prop(f, head, Vector3.new(0.5, 0.2, 0.06), CFrame.new(-0.27, 0.12, -0.62), DARK)
end

-- arme fétiche : marteau de juge à la main droite
M.Signature = { Hand = "Right", Build = function(f, a, prop)
	prop(f, a, Vector3.new(0.24, 0.24, 1.6), CFrame.new(0, -1.1, -0.75), WOOD)
	prop(f, a, Vector3.new(1.2, 0.7, 0.7), CFrame.new(0, -1.1, -1.65), DARKWOOD, CYL)
	prop(f, a, Vector3.new(0.12, 0.75, 0.75), CFrame.new(0.38, -1.1, -1.65), GOLD, CYL)
	prop(f, a, Vector3.new(0.12, 0.75, 0.75), CFrame.new(-0.38, -1.1, -1.65), GOLD, CYL)
end }

-- Transformation : robe noire, perruque poudrée, jabot blanc, balance de la justice qui flotte
function M.Transform(f, head, torso, c, prop)
	prop(f, torso, Vector3.new(2.12, 2.05, 1.12), CFrame.new(0, 0, 0), DARK) -- robe
	prop(f, torso, Vector3.new(2.3, 1.5, 1.3), CFrame.new(0, -1.7, 0), DARK)
	prop(f, torso, Vector3.new(0.5, 0.6, 0.1), CFrame.new(0, 0.6, -0.6), PAPER) -- jabot
	prop(f, torso, Vector3.new(2.14, 0.15, 1.14), CFrame.new(0, 1.0, 0), BURGUNDY)
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			prop(f, head, Vector3.one * 0.55, CFrame.new(0.62 * s, 0.35 - i * 0.42, 0.15), Color3.fromRGB(240, 240, 240), BALL) -- boucles
		end
	end
	prop(f, head, Vector3.new(1.35, 0.4, 1.3), CFrame.new(0, 0.62, 0.08), Color3.fromRGB(240, 240, 240))
	prop(f, head, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.35, 0.65), Color3.fromRGB(240, 240, 240), BALL)
	-- balance
	local base = CFrame.new(1.9, 2.3, 0.4)
	local pole = prop(f, torso, Vector3.new(0.15, 1.6, 0.15), base, GOLD)
	pole.Name = "Scales"
	prop(f, torso, Vector3.new(1.8, 0.12, 0.12), base * CFrame.new(0, 0.75, 0), GOLD)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(0.05, 0.7, 0.05), base * CFrame.new(0.85 * s, 0.4, 0), CHAIN)
		prop(f, torso, Vector3.new(0.08, 0.6, 0.6), base * CFrame.new(0.85 * s, 0.03, 0) * UP, GOLD, CYL)
	end
	local pl = Instance.new("PointLight")
	pl.Color = GOLD
	pl.Range = 10
	pl.Brightness = 1.5
	pl.Parent = pole
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

local function frontTarget(attacker, dir, range)
	local root = Kit.root(attacker)
	local best, bestD = nil, math.huge
	for _, v in ipairs(Kit.enemies(attacker)) do
		local to = Kit.root(v).Position - root.Position
		local d = to.Magnitude
		if d <= range and not Kit.isProtected(v) then
			if (Kit.flat(to):Dot(dir) >= 0.4 or d < 8) and d < bestD then
				best, bestD = v, d
			end
		end
	end
	return best
end

local function kbAtt(root)
	local att = root:FindFirstChild("KBAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KBAtt"
		att.Parent = root
	end
	return att
end

M.Kinds = {
	-- Order in the Court : bond vers l'avant puis écrasement au marteau (plaque au sol)
	LWGavel = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local landing = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Forward, 2.5))
		Kit.fx({ id = "Telegraph", p = landing, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		local horiz = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
		-- arc déterministe (montée puis descente symétriques) : l'impact se fait au point annoncé,
		-- la position répliquée du joueur étant en retard côté serveur
		local lv = Instance.new("LinearVelocity")
		lv.Name = "LWLeap"
		lv.Attachment0 = kbAtt(root)
		lv.MaxForce = 1e6
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = horiz / cfg.Windup + Vector3.new(0, cfg.JumpUp, 0)
		lv.Parent = root
		task.wait(cfg.Windup / 2)
		lv.VectorVelocity = horiz / cfg.Windup + Vector3.new(0, -cfg.JumpUp, 0)
		task.wait(cfg.Windup / 2)
		lv:Destroy()
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local c = landing + Vector3.new(0, 3, 0)
		Kit.fx({ id = "LW_Gavel", p = landing, r = cfg.Radius, a = attacker, look = dir })
		for _, v in ipairs(inDisc(attacker, c, cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, dir))
		end
	end,

	-- Law Book Barrage : 3 livres lancés en cloche, un par bras
	LWBooks = function(attacker, cfg, aim, api)
		task.wait(0.16)
		for i = 1, cfg.Count do
			if not ready(api, attacker) then
				return
			end
			local dir = CFrame.Angles(0, math.rad((i - 2) * cfg.Spread), 0) * Kit.aimDir(attacker, aim)
			api.projectile(attacker, cfg, dir, cfg.Colors[(i - 1) % #cfg.Colors + 1])
			if i < cfg.Count then
				task.wait(cfg.Interval)
			end
		end
	end,

	-- OBJECTION! : posture de contre (la parade et la riposte sont dans ServerInit)
	LWObjection = function(attacker, cfg, aim, api)
		attacker:SetAttribute("LWObjUntil", api.now() + cfg.Duration)
		api.CharacterState.setBlocking(attacker, true)
		Kit.fx({ id = "LW_Stance", a = attacker, dur = cfg.Duration })
		local t0 = os.clock()
		while os.clock() - t0 < cfg.Duration and (attacker:GetAttribute("LWObjUntil") or 0) > 0 and api.CharacterState.isAlive(attacker) do
			task.wait(0.05)
		end
		if (attacker:GetAttribute("LWObjUntil") or 0) == 0 then
			task.wait(0.3) -- contre réussi : on garde la pose un instant
		end
		attacker:SetAttribute("LWObjUntil", 0)
		api.CharacterState.setBlocking(attacker, false)
	end,

	-- Sign Here : contrat géant sous la cible la plus proche devant, chaînes qui immobilisent
	LWContract = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local target = frontTarget(attacker, dir, cfg.Range)
		local pos = target and Kit.root(target).Position or Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2)
		local center = Kit.ground(pos)
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "LW_Contract", p = center, look = dir, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(inDisc(attacker, center, cfg.Radius, 8)) do
			if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, dir)) == "Hit" then
				Kit.hold(v, cfg.Root)
				Kit.fx({ id = "LW_Bound", v = v, dur = cfg.Root })
			end
		end
	end,

	-- Class Action : assignations tout autour, les victimes paient des frais (dégâts sur la durée)
	LWLawsuit = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		Kit.fx({ id = "Telegraph", p = Kit.ground(root.Position), r = cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local c = root.Position
		Kit.fx({ id = "LW_Papers", p = c, r = cfg.Radius, a = attacker })
		for _, v in ipairs(inDisc(attacker, c, cfg.Radius, 8)) do
			if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, root.CFrame.LookVector)) == "Hit" then
				Kit.mark(v, "LWSued", "SUED!", BURGUNDY)
				task.spawn(function()
					for _ = 1, cfg.Ticks do
						task.wait(cfg.TickInterval)
						local hum = v:FindFirstChildOfClass("Humanoid")
						local head = v:FindFirstChild("Head")
						if not hum or hum.Health <= 0 or not head then
							break
						end
						if not Kit.isProtected(v) then
							api.CharacterState.recordHit(v, attacker, cfg.Name, "Combat")
							hum:TakeDamage(cfg.TickDamage)
							Kit.fx({ id = "LW_Fee", p = head.Position, d = cfg.TickDamage })
						end
					end
					if v.Parent then
						Kit.mark(v, "LWSued", nil)
					end
				end)
			end
		end
	end,

	-- Cross-Examination : saisie, 4 coups de marteau, verdict qui envoie en l'air
	LWCross = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(0.08)
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		if not victim or not ready(api, attacker) then
			Kit.fx({ id = "LW_Whiff", a = attacker })
			return
		end
		local total = 0.3 + cfg.Bonks * cfg.Interval + 0.3
		api.CharacterState.stun(victim, total)
		Kit.pull(victim, root.Position, 80, 3)
		Kit.fx({ id = "LW_Grab", a = attacker, v = victim })
		task.wait(0.1)
		for _ = 1, cfg.Bonks do
			if not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(victim) or api.CharacterState.isStunned(attacker) then
				return
			end
			Kit.hold(victim, cfg.Interval + 0.12)
			api.hit(attacker, victim, cfg, dir)
			task.wait(cfg.Interval)
		end
		task.wait(0.18)
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) and not api.CharacterState.isStunned(attacker) then
			local vr = Kit.root(victim)
			Kit.fx({ id = "LW_Guilty", p = vr.Position, a = attacker })
			api.hit(attacker, victim, cfg, api.flat(vr.Position - root.Position, dir), cfg.Final)
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Billable Hours + parade/riposte d'OBJECTION!
------------------------------------------------------------------------
function M.ServerInit(api)
	local CombatService, CharacterState = api.CombatService, api.CharacterState
	local function counter(v, a)
		if not CharacterState.isAlive(v) or not CharacterState.isAlive(a) then
			return
		end
		local vr, ar = Kit.root(v), Kit.root(a)
		if not vr or not ar then
			return
		end
		Kit.fx({ id = "LW_Objection", a = v, p = vr.Position, t = ar.Position })
		CombatService.applyHit({ attacker = v, victim = a, damage = M.Attacks.Objection.CounterDamage, dir = Kit.flat(ar.Position - vr.Position, vr.CFrame.LookVector),
			knockback = 55, up = 16, stun = 1.0, category = "Heavy", power = 1.0, words = { "OBJECTION!", "SUSTAINED!" }, weapon = "OBJECTION!" })
	end
	-- OBJECTION! : le premier coup reçu pendant la posture devient une parade
	table.insert(CombatService.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if a and a ~= v and v:GetAttribute("CharacterName") == "Lawyer" and (v:GetAttribute("LWObjUntil") or 0) > workspace:GetServerTimeNow() then
			v:SetAttribute("LWObjUntil", 0)
			local vr, ar = Kit.root(v), Kit.root(a)
			if vr and ar then
				local to = Kit.flat(ar.Position - vr.Position, vr.CFrame.LookVector)
				vr.CFrame = CFrame.lookAt(vr.Position, vr.Position + to)
				p.dir = -to
			end
			local vs = CharacterState.get(v)
			if not vs.blocking then
				CharacterState.setBlocking(v, true)
			end
			vs.blockStart = os.clock()
			p.unblockable = false
			task.delay(0.15, counter, v, a)
		end
	end)
	-- Billable Hours : chaque 5e coup est facturé
	local bills = setmetatable({}, { __mode = "k" })
	table.insert(CombatService.damageMods, function(p)
		local a = p.attacker
		if a and a ~= p.victim and a:GetAttribute("CharacterName") == "Lawyer" and (p.damage or 0) > 0 then
			local n = (bills[a] or 0) + 1
			if n >= 5 then
				n = 0
				p.damage += 6
				p.words = { "BILLED!", "$$$!" }
				p.power = (p.power or 0.5) + 0.2
				local vr = Kit.root(p.victim)
				if vr then
					Kit.fx({ id = "LW_Billed", p = vr.Position })
				end
			end
			bills[a] = n
			a:SetAttribute("LWBill", n)
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local function follow(part, target, offset, dur)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not part.Parent or not target.Parent then
			conn:Disconnect()
			return
		end
		part.CFrame = target.CFrame * offset
	end)
	Debris:AddItem(part, dur)
end

local function cash(pos, n, speed)
	for _ = 1, n do
		local b = Kit.part({ Size = Vector3.new(0.9, 0.05, 0.45), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = CASH })
		local out = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(0.2, 1.2), Kit.rng:NextNumber(-1, 1)) * (speed or 5)
		Kit.tween(b, 0.9, { CFrame = CFrame.new(pos + out - Vector3.new(0, 2, 0)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1 }, Enum.EasingStyle.Sine)
		Debris:AddItem(b, 0.92)
	end
end

local function papers(pos, n, dist, life)
	for i = 1, n do
		local a = i / n * math.pi * 2 + Kit.rng:NextNumber(-0.2, 0.2)
		local dirv = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Kit.part({ Size = Vector3.new(0.8, 0.05, 1.05), CFrame = CFrame.new(pos) * CFrame.Angles(0, a, 0), Color = PAPER })
		Kit.tween(p, life, { CFrame = CFrame.new(pos + dirv * dist + Vector3.new(0, Kit.rng:NextNumber(-1, 2), 0)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), a, Kit.rng:NextNumber(0, 6)), Transparency = 1 })
		Debris:AddItem(p, life + 0.03)
	end
end

M.MoveFX = {
	GavelSlam = function(c, d, api)
		api.afterimages(c, 0.4, BURGUNDY)
	end,
	LawBooks = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3, 0), "READ THIS!", GOLD, 1.8, 0.5, 1)
		end
	end,
	Objection = function(c, d, api) end,
	SignHere = function(c, d, api)
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			api.CartoonFX.twinkle((arm.CFrame * CFrame.new(0, -1.2, 0)).Position)
		end
	end,
	ClassAction = function(c, d, api) end,
	CrossExamination = function(c, d, api) end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	Kit.setupClient()

	Kit.on("LW_Gavel", function(d)
		CartoonFX.sound("GroundSlam", d.p, 1)
		CartoonFX.sound("Bonk", d.p, 1)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, GOLD)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.1, BURGUNDY)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.6, GOLD)
		Kit.cubes(d.p + Vector3.new(0, 0.5, 0), 16, { WOOD, DARKWOOD, GOLD }, 0.6, 10, 0.5)
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "ORDER!", 1.2, "Heavy")
		if Kit.mine(d.a) then
			CartoonFX.shake(0.9)
		end
	end)

	Kit.on("LW_Stance", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "OBJECTION?", GOLD, 2.2, d.dur, 0.8)
		local shield = Kit.part({ Shape = CYL, Size = Vector3.new(0.15, 5, 5), Color = GOLD, Transparency = 0.6 })
		follow(shield, r, CFrame.new(0, 0.5, -2) * CFrame.Angles(0, math.pi / 2, 0), d.dur)
		Kit.tween(shield, d.dur, { Transparency = 0.9 })
	end)

	Kit.on("LW_Objection", function(d)
		CartoonFX.sound("Parry", d.p, 1.2)
		CartoonFX.sound("BigImpact", d.t, 1)
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "OBJECTION!", 1.6, "Heavy")
		local dirv = Kit.flat(d.t - d.p)
		CartoonFX.bigImpact(d.t + Vector3.new(0, 1, 0), dirv, 1.4, GOLD)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.6, 0), 8, GOLD)
		-- panneau « OBJECTION! » façon bulle de BD
		local cf = CFrame.lookAt(d.p + Vector3.new(0, 3.5, 0) + dirv * 1.5, d.p + Vector3.new(0, 3.5, 0) + dirv * 3)
		local panel = Kit.part({ Size = Vector3.new(7, 2.2, 0.2), CFrame = cf * CFrame.Angles(0, 0, -0.12), Color = Color3.new(1, 1, 1) })
		local back = Kit.part({ Size = Vector3.new(7.6, 2.8, 0.15), CFrame = cf * CFrame.Angles(0, 0, -0.12) * CFrame.new(0, 0, 0.1), Color = BURGUNDY })
		local l1 = Kit.flatText(panel, "OBJECTION!", BURGUNDY, Enum.NormalId.Front)
		local l2 = Kit.flatText(panel, "OBJECTION!", BURGUNDY, Enum.NormalId.Back)
		panel.Size = Vector3.new(1, 0.3, 0.2)
		Kit.tween(panel, 0.12, { Size = Vector3.new(7, 2.2, 0.2) }, Enum.EasingStyle.Back)
		task.delay(0.8, function()
			Kit.tween(panel, 0.2, { Transparency = 1 })
			Kit.tween(back, 0.2, { Transparency = 1 })
			Kit.tween(l1, 0.2, { TextTransparency = 1 })
			Kit.tween(l2, 0.2, { TextTransparency = 1 })
		end)
		Debris:AddItem(panel, 1.05)
		Debris:AddItem(back, 1.05)
		if Kit.mine(d.a) then
			CartoonFX.impactFrame(0.7)
			CartoonFX.shake(0.6)
		end
	end)

	Kit.on("LW_Contract", function(d)
		local cf = CFrame.lookAt(d.p, d.p + d.look) * CFrame.new(0, 0.15, 0)
		local size = d.r * 1.7
		local paper = Kit.part({ Size = Vector3.new(size, 0.1, 0.4), CFrame = cf * CFrame.new(0, 0, size / 2), Color = PAPER })
		local roll = Kit.part({ Shape = CYL, Size = Vector3.new(size + 0.4, 0.8, 0.8), CFrame = cf * CFrame.new(0, 0.4, size / 2), Color = PAPER })
		Kit.tween(paper, d.dur, { Size = Vector3.new(size, 0.1, size), CFrame = cf }, Enum.EasingStyle.Quad)
		Kit.tween(roll, d.dur, { CFrame = cf * CFrame.new(0, 0.4, -size / 2) }, Enum.EasingStyle.Quad)
		local l = Kit.flatText(paper, "SIGN HERE: X______", DARK, Enum.NormalId.Top, Enum.Font.GothamBold)
		l.Rotation = 180
		CartoonFX.sound("Whoosh", d.p, 0.7)
		task.delay(d.dur, function()
			CartoonFX.sound("Clang", d.p, 1)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r, GOLD)
			Kit.cubes(d.p + Vector3.new(0, 0.5, 0), 12, { CHAIN, GOLD }, 0.5, 8, 0.4)
			roll:Destroy()
		end)
		task.delay(d.dur + 1.6, function()
			Kit.tween(paper, 0.3, { Transparency = 1 })
			Kit.tween(l, 0.3, { TextTransparency = 1 })
		end)
		Debris:AddItem(paper, d.dur + 2)
		Debris:AddItem(roll, d.dur + 0.1)
	end)

	Kit.on("LW_Bound", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		Kit.floatText(vr.Position + Vector3.new(0, 3.5, 0), "BOUND BY CONTRACT!", GOLD, 2.4, 0.9, 1.5)
		-- anneaux de chaîne (maillons) autour du corps
		for ri, y in ipairs({ 0.7, -0.4, -1.6 }) do
			local n = 10
			for i = 1, n do
				local a = i / n * math.pi * 2 + ri * 0.3
				local link = Kit.part({ Size = Vector3.new(0.5, 0.22, 0.28), Color = (i % 2 == 0) and CHAIN or GOLD })
				follow(link, vr, CFrame.new(0, y, 0) * CFrame.Angles(0, a, (i % 2) * 1.57) * CFrame.new(0, 0, -1.25), d.dur)
			end
		end
		-- chaînes qui partent du sol
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2 + 0.4
			local g = vr.Position + Vector3.new(math.cos(a) * 4, -3, math.sin(a) * 4)
			local to = vr.Position + Vector3.new(0, -0.5, 0)
			local len = (to - g).Magnitude
			local chain = Kit.part({ Size = Vector3.new(0.25, 0.25, len), CFrame = CFrame.lookAt(g, to) * CFrame.new(0, 0, -len / 2), Color = CHAIN })
			Kit.tween(chain, d.dur, { Transparency = 0.6 })
			Debris:AddItem(chain, d.dur)
		end
	end)

	Kit.on("LW_Papers", function(d)
		CartoonFX.sound("Whoosh", d.p, 1.1)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.7, 0), d.r, BURGUNDY)
		papers(d.p + Vector3.new(0, 1, 0), 28, d.r, 0.6)
		papers(d.p + Vector3.new(0, 2.5, 0), 16, d.r * 0.7, 0.8)
		Kit.floatText(d.p + Vector3.new(0, 4.5, 0), "YOU'VE BEEN SERVED!", GOLD, 3.4, 1.1, 1.5)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.4)
		end
	end)

	Kit.on("LW_Fee", function(d)
		Kit.floatText(d.p + Vector3.new(Kit.rng:NextNumber(-0.8, 0.8), 1.5, 0), "-$" .. tostring(d.d) .. " FEES", CASH, 1.6, 0.8, 2)
		cash(d.p, 3, 3)
	end)

	Kit.on("LW_Grab", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if vr then
			Kit.floatText(vr.Position + Vector3.new(0, 3.5, 0), "ANSWER THE QUESTION!", GOLD, 2.6, 0.9, 1)
			CartoonFX.sound("Ding", vr.Position, 0.6)
		end
	end)

	Kit.on("LW_Guilty", function(d)
		CartoonFX.sound("BigImpact", d.p, 1.2)
		CartoonFX.word(d.p + Vector3.new(0, 4.5, 0), "GUILTY!", 1.6, "Heavy")
		-- tampon rouge qui s'écrase
		local stamp = Kit.part({ Size = Vector3.new(3.4, 0.5, 2), CFrame = CFrame.new(d.p + Vector3.new(0, 9, 0)), Color = Color3.fromRGB(200, 30, 30) })
		Kit.flatText(stamp, "GUILTY", Color3.new(1, 1, 1), Enum.NormalId.Top)
		Kit.tween(stamp, 0.12, { CFrame = CFrame.new(d.p + Vector3.new(0, 3, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.12, function()
			CartoonFX.bigImpact(d.p + Vector3.new(0, 2, 0), Vector3.new(0, 1, 0), 1.4, BURGUNDY)
			CartoonFX.shockwave(d.p - Vector3.new(0, 2.6, 0), 8, BURGUNDY)
			Kit.tween(stamp, 0.35, { Transparency = 1, CFrame = CFrame.new(d.p + Vector3.new(0, 5, 0)) })
		end)
		Debris:AddItem(stamp, 0.5)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.8)
			CartoonFX.impactFrame(0.6)
		end
	end)

	Kit.on("LW_Whiff", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "NO FURTHER QUESTIONS...", PAPER, 2.4, 0.8, 1)
		end
	end)

	Kit.on("LW_Billed", function(d)
		CartoonFX.sound("Ding", d.p, 1)
		Kit.floatText(d.p + Vector3.new(0, 3, 0), "BILLED! +$$$", CASH, 2.6, 0.9, 2)
		cash(d.p + Vector3.new(0, 1, 0), 14, 6)
	end)

	-- aura de transformation : $ dorés et balance qui oscille
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Lawyer" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-2, 2))
						Kit.floatText(r.Position + off, Kit.rng:NextInteger(1, 3) == 1 and "ORDER" or "$", GOLD, 1.1, 0.9, 2.5)
					end
				end
			end
		end
	end)
end

return M
