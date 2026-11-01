--[[
	The HR Manager — personnage complet (format : voir Modules/ContentLoader).
	Passif Mandatory Meeting : les ennemis qu'elle touche sont ralentis de 15 % pendant 2 s.
	Attaques : Write-Up (clipboard lancé qui marque), Team Building (rassemble devant elle puis pousse tout le groupe),
	Policy Update (cône de mémos qui repousse et aveugle).
	Transformation Restructuring : Performance Review (pluie d'étoiles), Layoffs (ruée qui envoie en l'air), Termination Letter (lettre géante claquée au sol : plaque tout le monde autour).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL = Kit.CYL, Kit.BALL

local PURPLE = Color3.fromRGB(190, 90, 230)
local PINK = Color3.fromRGB(255, 150, 210)
local BOARD = Color3.fromRGB(175, 120, 70)
local PAPER = Color3.fromRGB(250, 250, 245)
local STEEL = Color3.fromRGB(200, 205, 215)
local STAR = Color3.fromRGB(255, 215, 40)
local RED = Color3.fromRGB(225, 45, 45)
local MEMO = { PAPER, Color3.fromRGB(255, 240, 120), PINK, Color3.fromRGB(170, 220, 255) }

local M = { Id = "HRManager", Order = 8 }

M.Character = {
	DisplayName = "The HR Manager",
	Role = "Crowd control",
	Color = PURPLE,
	Shirt = PINK, Pants = Color3.fromRGB(110, 60, 150), Tie = PURPLE,
	Passive = { Name = "Mandatory Meeting", Desc = "Every enemy she hits is slowed by 15% for 2s." },
	Attacks = { "WriteUp", "TeamBuilding", "PolicyUpdate" },
	Transformation = { Name = "Restructuring", Desc = "Headset, giant clipboard and a purple aura.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "PerformanceReview", "Layoffs", "TerminationLetter" },
}

M.Attacks = {
	WriteUp = { Name = "Write-Up", Kind = "HRWriteUp", Desc = "Fling a clipboard. The target is written up: your next hit on them deals +6 and stuns longer.", Prop = "HRClip", Cooldown = 7, Anim = "WriteUp", Sound = "Throw",
		Windup = 0.14, Speed = 105, Range = 70, Damage = 5, Knockback = 6, Stun = 0.7, Category = "Projectile", Power = 0.45, Words = { "WRITTEN UP!", "NOTED!" },
		Bonus = 6, MarkTime = 7 },
	TeamBuilding = { Name = "Team Building", Kind = "HRTeamBuilding", Desc = "Pull everyone in front of you into a group hug, then shove the whole team away.", Cooldown = 9, Anim = "TeamBuilding", Sound = "Whoosh",
		Windup = 0.2, HitboxOffset = 5, HitboxSize = Vector3.new(14, 6, 10), PullSpeed = 60, GroupBonus = 3,
		Damage = 8, Knockback = 46, KnockUp = 14, Stun = 0.9, Category = "Heavy", Power = 0.85, Words = { "TEAM BUILDING!", "TRUST FALL!" } },
	PolicyUpdate = { Name = "Policy Update", Kind = "Cone", Desc = "Blast a cone of flying memos that pushes coworkers back and blinds them briefly.", Prop = "HRMemos", Cooldown = 9, Anim = "PolicyUpdate", Sound = "Whoosh",
		Windup = 0.12, Range = 18, Angle = 32, Duration = 0.6, Tick = 0.2, Color = PAPER,
		Damage = 2.5, Knockback = 24, KnockUp = 4, Stun = 0.4, Category = "Light", Power = 0.35, Words = { "MEMO!", "FWIP!", "NEW POLICY!" }, Effects = { Blind = 1.2 } },
	PerformanceReview = { Name = "Performance Review", Kind = "HRStarRain", Desc = "Rate their work: a rain of review stars crashes down on the area ahead.", Cooldown = 11, Anim = "PerformanceReview", Sound = "Ding",
		Offset = 12, Radius = 10, Stars = 8, StarRadius = 4.5, Interval = 0.14, Fall = 0.35, MaxHits = 3,
		Damage = 4, Knockback = 10, KnockUp = 16, Stun = 0.6, Category = "Light", Power = 0.5, Words = { "1 STAR!", "NEEDS WORK!", "MEH!" } },
	Layoffs = { Name = "Layoffs", Kind = "Lunge", Desc = "Power-walk through the office: everyone in your path gets laid off into the air.", Prop = "HRClip", Cooldown = 9, Pierce = true, Anim = "Layoffs", Sound = "Dash",
		Speed = 84, Time = 0.5, HitboxSize = Vector3.new(7, 6, 7), Damage = 10, Knockback = 10, Launch = Vector3.new(8, 52, 0), Stun = 1.1, Category = "Heavy", Power = 0.85,
		Words = { "LAID OFF!", "DOWNSIZED!" } },
	TerminationLetter = { Name = "Termination Letter", Kind = "AoE", Desc = "Slam a giant termination letter on the floor: a shockwave that PINS everyone around you to the ground.", Prop = "HRLetter", Cooldown = 15, Anim = "TerminationLetter", Sound = "Whoosh",
		Windup = 0.45, Radius = 14, Shockwave = true, Damage = 11, Knockback = 0, KnockUp = 0, Stun = 1.4, Category = "Heavy", Power = 1.1, Effects = { Pin = true },
		Words = { "TERMINATED!", "EFFECTIVE IMMEDIATELY!" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function policyAnim()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 1.3, y = -1.2, r = -0.4 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = -0.5, ln = 0.1 }, RH = { p = 0.3 } } }
	local t = 0.1
	for i = 1, 5 do -- éventail : le bras balaie gauche/droite en jetant les mémos
		t += 0.12
		local right = i % 2 == 1
		table.insert(f, { t = t, RS = { p = 1.5, y = right and 1.1 or -1.0, r = right and 0 or -0.4 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = right and 0.45 or -0.4, ln = 0.2 }, RH = { p = 0.3 }, LH = { p = -0.1 } })
	end
	table.insert(f, { t = t + 0.15 })
	return f
end

local function reviewAnim()
	local f = { { t = 0 }, { t = 0.1, LS = { p = 1.5, y = 0.8 }, RS = { p = 1.3, y = 0.9 }, RJ = { ln = 0.15 } } }
	local t = 0.1
	for i = 1, 4 do -- coche, coche, coche… sur le clipboard
		t += 0.08
		table.insert(f, { t = t, LS = { p = 1.5, y = 0.8 }, RS = { p = (i % 2 == 0) and 1.45 or 1.15, y = (i % 2 == 0) and 0.6 or 1.0 }, RJ = { ln = 0.18 } })
	end
	table.insert(f, { t = t + 0.12, RS = { p = 2.9, r = -0.4 }, LS = { p = 1.5, y = 0.8 }, RJ = { ln = -0.25, tw = 0.25 }, LH = { p = -0.2 } }) -- verdict !
	table.insert(f, { t = t + 0.7, RS = { p = 2.8, r = -0.4 }, LS = { p = 1.4, y = 0.8 }, RJ = { ln = -0.2, tw = 0.2 } })
	table.insert(f, { t = t + 0.85 })
	return f
end

M.Anims = {
	WriteUp = { -- lancer de frisbee en revers depuis l'épaule opposée
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.4, y = 1.3, r = 0.3 }, RJ = { tw = 0.7 }, LH = { p = 0.2 } },
		{ t = 0.16, RS = { p = 1.5, y = -1.0, r = -0.6 }, RJ = { tw = -0.6, ln = 0.15 }, LH = { p = 0.4 }, RH = { p = -0.2 } },
		{ t = 0.36, RS = { p = 1.45, y = -0.95, r = -0.55 }, RJ = { tw = -0.55, ln = 0.12 } },
		{ t = 0.5 },
	},
	TeamBuilding = { -- bras grands ouverts « venez ! », câlin de groupe, puis poussée des deux paumes
		{ t = 0 },
		{ t = 0.14, RS = { p = 1.5, r = -1.2 }, LS = { p = 1.5, r = -1.2 }, RJ = { ln = -0.2 } },
		{ t = 0.3, RS = { p = 1.5, y = 1.0, r = 0.2 }, LS = { p = 1.5, y = 1.0, r = 0.2 }, RJ = { ln = 0.15 } },
		{ t = 0.5, RS = { p = 1.5, y = 1.0, r = 0.2 }, LS = { p = 1.5, y = 1.0, r = 0.2 }, RJ = { ln = 0.1, sd = 0.1 } },
		{ t = 0.58, RS = { p = 0.4 }, LS = { p = 0.4 }, RJ = { ln = -0.15 } },
		{ t = 0.66, RS = { p = 1.6, y = 0.3 }, LS = { p = 1.6, y = 0.3 }, RJ = { ln = 0.5 }, LH = { p = 0.8 }, RH = { p = -0.4 } },
		{ t = 0.9, RS = { p = 1.55, y = 0.3 }, LS = { p = 1.55, y = 0.3 }, RJ = { ln = 0.4 }, LH = { p = 0.7 } },
		{ t = 1.05 },
	},
	PolicyUpdate = policyAnim(),
	PerformanceReview = reviewAnim(),
	Layoffs = { -- marche rapide penchée, clipboard tenu devant comme un bélier
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.6, y = 0.6 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0.45 }, RH = { p = -0.6 }, LH = { p = 0.7 } },
		{ t = 0.18, RS = { p = 1.6, y = 0.6 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0.45, tw = 0.1 }, RH = { p = 0.7 }, LH = { p = -0.6 } },
		{ t = 0.3, RS = { p = 1.6, y = 0.6 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0.45, tw = -0.1 }, RH = { p = -0.6 }, LH = { p = 0.7 } },
		{ t = 0.42, RS = { p = 1.6, y = 0.6 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0.45, tw = 0.1 }, RH = { p = 0.7 }, LH = { p = -0.6 } },
		{ t = 0.54, RS = { p = 2.4, r = -0.3 }, LS = { p = 0.3 }, RJ = { ln = -0.1 } }, -- coup de clipboard final vers le haut
		{ t = 0.7 },
	},
	TerminationLetter = { -- déplie une lettre géante au-dessus de la tête, puis la claque vers l'avant
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.5, r = -0.1 }, LS = { p = 2.5, r = -0.1 }, RJ = { ln = -0.15 } },
		{ t = 0.3, RS = { p = 2.7, r = -0.6 }, LS = { p = 2.7, r = -0.6 }, RJ = { ln = -0.35 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.4, RS = { p = 2.75, r = -0.65 }, LS = { p = 2.75, r = -0.65 }, RJ = { ln = -0.4 } },
		{ t = 0.48, RS = { p = 0.6, y = 0.3 }, LS = { p = 0.6, y = 0.3 }, RJ = { ln = 0.95 }, RH = { p = 1.05, r = -0.2 }, LH = { p = -0.4, r = -0.2 } },
		{ t = 0.85, RS = { p = 0.7, y = 0.3 }, LS = { p = 0.7, y = 0.3 }, RJ = { ln = 0.8 }, RH = { p = 0.9 }, LH = { p = -0.35 } },
		{ t = 1.0 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
M.Props = {
	HRClip = {
		{ Vector3.new(0.12, 1.4, 1.05), CFrame.new(0, -1.65, -0.35), BOARD },
		{ Vector3.new(0.13, 1.2, 0.9), CFrame.new(-0.02, -1.72, -0.35), PAPER },
		{ Vector3.new(0.18, 0.2, 0.5), CFrame.new(0, -1.0, -0.35), STEEL },
	},
	HRMemos = {
		{ Vector3.new(1.0, 0.5, 0.75), CFrame.new(-0.2, -1.3, -0.1), PAPER },
		{ Vector3.new(0.6, 0.1, 0.6), CFrame.new(-0.2, -1.03, -0.1), PINK },
	},
	HRLetter = {
		{ Vector3.new(2.6, 3.4, 0.08), CFrame.new(-0.8, -2.6, -0.3), PAPER },
		{ Vector3.new(2.62, 0.5, 0.1), CFrame.new(-0.8, -1.2, -0.3), RED },
		{ Vector3.new(2.0, 0.12, 0.1), CFrame.new(-0.8, -2.0, -0.31), Color3.fromRGB(80, 80, 90) },
		{ Vector3.new(2.0, 0.12, 0.1), CFrame.new(-0.8, -2.5, -0.31), Color3.fromRGB(80, 80, 90) },
		{ Vector3.new(1.4, 0.12, 0.1), CFrame.new(-1.1, -3.0, -0.31), Color3.fromRGB(80, 80, 90) },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : chignon, boucles d'oreilles, cordon + badge HR ; clipboard à la main gauche
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	local HAIR = Color3.fromRGB(90, 55, 35)
	prop(f, head, Vector3.new(1.32, 0.3, 1.32), CFrame.new(0, 0.56, 0.04), HAIR)
	prop(f, head, Vector3.new(1.32, 0.8, 0.35), CFrame.new(0, 0.2, 0.52), HAIR)
	prop(f, head, Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 0.75, 0.55), HAIR, BALL) -- chignon
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.22, 0.22, 0.22), CFrame.new(0.66 * s, -0.25, 0), STAR, BALL) -- boucles d'oreilles
		prop(f, torso, Vector3.new(0.12, 1.15, 0.08), CFrame.new(0.3 * s, 0.42, -0.55) * CFrame.Angles(0, 0, -0.4 * s), PURPLE) -- cordon
	end
	local badge = prop(f, torso, Vector3.new(0.7, 0.75, 0.08), CFrame.new(0, -0.2, -0.56), PAPER)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = badge
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = PURPLE
	l.Text = "HR"
	l.Parent = gui
end

M.Signature = { Hand = "Left", Build = function(f, a, prop) -- clipboard
	prop(f, a, Vector3.new(0.12, 1.6, 1.15), CFrame.new(0, -1.7, -0.35), BOARD)
	prop(f, a, Vector3.new(0.06, 1.35, 0.95), CFrame.new(-0.08, -1.78, -0.35), PAPER)
	prop(f, a, Vector3.new(0.18, 0.22, 0.5), CFrame.new(0, -0.95, -0.35), STEEL)
	for i = 0, 2 do
		prop(f, a, Vector3.new(0.07, 0.08, 0.6), CFrame.new(-0.11, -1.35 - i * 0.3, -0.3), Color3.fromRGB(120, 120, 130))
	end
end }

-- Transformation : casque-micro + clipboard géant dans le dos
function M.Transform(f, head, torso, c, prop)
	local DARK = Color3.fromRGB(40, 40, 50)
	prop(f, head, Vector3.new(1.4, 0.16, 0.24), CFrame.new(0, 0.66, 0), DARK)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.22, 0.5, 0.5), CFrame.new(0.68 * s, 0.05, 0), DARK, CYL)
		prop(f, head, Vector3.new(0.23, 0.32, 0.32), CFrame.new(0.7 * s, 0.05, 0), PURPLE, CYL)
	end
	prop(f, head, Vector3.new(0.07, 0.07, 0.7), CFrame.new(-0.55, -0.18, -0.38) * CFrame.Angles(0, 0.6, 0), DARK) -- micro
	prop(f, head, Vector3.new(0.18, 0.18, 0.18), CFrame.new(-0.32, -0.2, -0.66), DARK, BALL)
	prop(f, torso, Vector3.new(2.0, 2.6, 0.22), CFrame.new(0, 0.4, 0.72) * CFrame.Angles(0, 0, 0.12), BOARD) -- clipboard géant
	prop(f, torso, Vector3.new(1.7, 2.2, 0.06), CFrame.new(0, 0.3, 0.85) * CFrame.Angles(0, 0, 0.12), PAPER)
	prop(f, torso, Vector3.new(0.9, 0.3, 0.3), CFrame.new(-0.15, 1.65, 0.75) * CFrame.Angles(0, 0, 0.12), STEEL)
end

------------------------------------------------------------------------
-- Serveur
------------------------------------------------------------------------
local function clipDecor(part)
	local p = Kit.sPart({ Size = Vector3.new(part.Size.X * 0.85, 0.06, part.Size.Z * 0.85), CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.03, 0.05), Color = PAPER })
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = p
	w.Parent = p
	p.Parent = part
end

M.Kinds = {
	-- Write-Up : clipboard qui tourne, marque la cible (bonus sur notre prochain coup)
	HRWriteUp = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.new(1.3, 0.15, 1.7), color = BOARD, spin = 18, decorate = clipDecor,
			onHit = function(v, pos, vel)
				if api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos }) == "Hit" then
					v:SetAttribute("WriteUpBy", attacker.Name)
					v:SetAttribute("WriteUpUntil", Kit.now() + cfg.MarkTime)
					v:SetAttribute("WriteUpBonus", cfg.Bonus)
				end
				return nil
			end,
		})
	end,

	-- Team Building : rassemble les ennemis devant elle, puis les pousse tous ensemble
	HRTeamBuilding = function(attacker, cfg, aim, api)
		Kit.rawFX({ k = "Telegraph", shape = "Box", a = attacker, size = cfg.HitboxSize, offset = cfg.HitboxOffset, dur = cfg.Windup })
		task.wait(cfg.Windup)
		local root = Kit.root(attacker)
		if not root or not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local look = Kit.flat(root.CFrame.LookVector)
		local cf = root.CFrame * CFrame.new(0, 0, -cfg.HitboxOffset)
		local victims = {}
		for _, v in ipairs(api.Hitbox.box(cf, cfg.HitboxSize + Vector3.one * 2, attacker, 5)) do
			if not Kit.isProtected(v) then
				table.insert(victims, v)
			end
		end
		if #victims == 0 then
			return
		end
		local gather = root.Position + look * 4.5
		local maxT = 0
		for _, v in ipairs(victims) do
			api.CharacterState.stun(v, 0.8)
			maxT = math.max(maxT, Kit.pull(v, gather, cfg.PullSpeed, 1.2))
		end
		Kit.fx({ id = "HRHug", p = gather, n = #victims, dur = maxT })
		task.wait(maxT + 0.12)
		local bonus = (#victims - 1) * cfg.GroupBonus
		for _, v in ipairs(victims) do
			if api.CharacterState.isAlive(v) and api.CharacterState.isAlive(attacker) then
				api.hit(attacker, v, cfg, look, bonus > 0 and { Damage = cfg.Damage + bonus, Words = { "GROUP HUG!", "SYNERGY!" } } or nil)
			end
		end
	end,

	-- Performance Review : étoiles qui tombent une par une sur la zone (visées en partie sur les ennemis)
	HRStarRain = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Stars * cfg.Interval + cfg.Fall, a = attacker })
		local count = {}
		local rng = Kit.rng
		for i = 1, cfg.Stars do
			local pos
			local inside = {}
			for _, v in ipairs(Kit.inRadius(attacker, center, cfg.Radius + 3)) do
				table.insert(inside, v)
			end
			if #inside > 0 and i % 2 == 1 then
				local v = inside[rng:NextInteger(1, #inside)]
				pos = Kit.ground(Kit.root(v).Position)
			else
				local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, cfg.Radius * 0.8)
				pos = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			Kit.fx({ id = "HRStar", p = pos, fall = cfg.Fall, big = i == cfg.Stars })
			task.delay(cfg.Fall, function()
				for _, v in ipairs(Kit.inRadius(attacker, pos, cfg.StarRadius)) do
					if (count[v] or 0) < cfg.MaxHits then
						count[v] = (count[v] or 0) + 1
						api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - pos, dir))
					end
				end
			end)
			task.wait(cfg.Interval)
		end
	end,
}

function M.ServerInit(api)
	-- Mandatory Meeting : ralentit tous ceux qu'elle touche
	local lastFx = setmetatable({}, { __mode = "k" })
	api.Signals.Hit:Connect(function(attacker, victim)
		if attacker and victim and attacker:GetAttribute("CharacterName") == "HRManager" and victim.Parent then
			api.CharacterState.setSpeedMod(victim, "HRMeeting", 0.85, 2)
			if os.clock() - (lastFx[victim] or -10) > 2 then
				lastFx[victim] = os.clock()
				Kit.fx({ id = "HRMeeting", v = victim })
			end
		end
	end)
	-- Write-Up : bonus sur le prochain coup
	table.insert(api.CombatService.damageMods, function(p)
		local a, v = p.attacker, p.victim
		if a and v:GetAttribute("WriteUpBy") == a.Name and (v:GetAttribute("WriteUpUntil") or 0) > Kit.now() and p.weapon ~= "Write-Up" then
			p.damage += v:GetAttribute("WriteUpBonus") or 6
			p.stun = (p.stun or 0.4) + 0.4
			p.words = { "WRITE-UP!", "STRIKE TWO!" }
			p.power = (p.power or 0.5) + 0.3
			v:SetAttribute("WriteUpBy", nil)
		end
	end)
end

------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------
local function memo(pos, color)
	return Kit.part({ Size = Vector3.new(0.9, 0.05, 1.15), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = color })
end

local function starAt(cf, size, color)
	-- étoile en 5 branches (blocs fins tournés)
	local parts = {}
	for i = 0, 4 do
		local p = Kit.part({ Size = Vector3.new(size * 0.32, size, size * 0.2), CFrame = cf * CFrame.Angles(0, 0, math.rad(72 * i)) * CFrame.new(0, size * 0.35, 0), Color = color })
		table.insert(parts, p)
	end
	table.insert(parts, Kit.part({ Shape = BALL, Size = Vector3.one * size * 0.55, CFrame = cf, Color = color }))
	return parts
end

M.MoveFX = {
	PolicyUpdate = function(c, d, api)
		task.spawn(function()
			for _ = 1, 14 do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local a = math.rad(api.rng:NextNumber(-32, 32))
				local dir = CFrame.Angles(0, a, 0) * r.CFrame.LookVector
				local start = r.Position + Vector3.new(0, 1, 0) + r.CFrame.LookVector * 1.5
				local m = memo(start, MEMO[api.rng:NextInteger(1, #MEMO)])
				Kit.tween(m, 0.45, { CFrame = CFrame.new(start + dir * 18 + Vector3.new(0, api.rng:NextNumber(-1, 2), 0)) * CFrame.Angles(api.rng:NextNumber(0, 6), api.rng:NextNumber(0, 6), 0), Transparency = 0.6 })
				api.Debris:AddItem(m, 0.47)
				task.wait(0.045)
			end
		end)
	end,
	Layoffs = function(c, d, api)
		api.afterimages(c, d.dur or 0.5, PURPLE)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), PURPLE, d.dur or 0.5, 1, 1.2)
		local r0 = c:FindFirstChild("HumanoidRootPart")
		if r0 then
			api.CartoonFX.dust(r0.Position - Vector3.new(0, 2.8, 0), 5, nil, 8)
			api.CartoonFX.airRing(r0.Position + r0.CFrame.LookVector, r0.CFrame.LookVector, 7, PURPLE, 0.25)
		end
		if Kit.mine(c) then
			api.CartoonFX.speedLines(d.dur or 0.5, PURPLE)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < (d.dur or 0.5) do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local pos = r.Position + Vector3.new(api.rng:NextNumber(-1.5, 1.5), api.rng:NextNumber(-1, 1.5), api.rng:NextNumber(-1.5, 1.5))
				local s = memo(pos, PINK)
				Kit.tween(s, 0.7, { CFrame = s.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(2, 1, 0), Transparency = 1 })
				api.Debris:AddItem(s, 0.72)
				task.wait(0.04)
			end
		end)
	end,
	TerminationLetter = function(c, d, api)
		task.delay(0.42, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			api.CartoonFX.sound("BigImpact", r.Position, 1)
			api.CartoonFX.quake(r.Position - Vector3.new(0, 2.8, 0) + r.CFrame.LookVector * 2, 14, PURPLE, 1.3)
			for i = 1, 12 do -- enveloppes qui partent en cercle
				local a = (i / 12) * math.pi * 2
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				local env = Kit.part({ Size = Vector3.new(1.4, 0.9, 0.1), CFrame = CFrame.lookAt(r.Position + out * 2, r.Position + out * 4), Color = PAPER })
				local seal = Kit.part({ Shape = BALL, Size = Vector3.one * 0.35, CFrame = env.CFrame * CFrame.new(0, 0, -0.08), Color = RED })
				for _, p in ipairs({ env, seal }) do
					Kit.tween(p, 0.5, { CFrame = p.CFrame + out * 14 + Vector3.new(0, 1.5, 0), Transparency = 1 })
					api.Debris:AddItem(p, 0.52)
				end
			end
			Kit.floatText(r.Position + Vector3.new(0, 5, 0), "YOU'RE TERMINATED!", PURPLE, 4.5, 1.2, 1.5)
			api.CartoonFX.casterShake(c, 1.1)
		end)
	end,
	TeamBuilding = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4, 0), "BRING IT IN!", PINK, 2.8, 0.7, 1)
			api.CartoonFX.implode(r.Position + r.CFrame.LookVector * 5, 7, { PINK, PURPLE }, 12, 0.3)
		end
		task.delay(0.62, function()
			local r2 = c:FindFirstChild("HumanoidRootPart")
			if r2 then
				api.CartoonFX.airRing(r2.Position + r2.CFrame.LookVector * 3, r2.CFrame.LookVector, 10, PURPLE, 0.3)
				api.CartoonFX.dust(r2.Position - Vector3.new(0, 2.8, 0) + r2.CFrame.LookVector * 3, 6, nil, 8)
				api.CartoonFX.casterShake(c, 0.6)
			end
		end)
	end,
	WriteUp = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), PURPLE, 0.4, 1, 1)
		task.delay(0.15, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), r.CFrame.LookVector, 6, PURPLE, 0.2)
			end
		end)
	end,
	PerformanceReview = function(c, d, api)
		task.delay(0.5, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.pillar(r.Position, 1.2, 14, STAR, 0.3)
				api.CartoonFX.light(r.Position + Vector3.new(0, 4, 0), STAR, 16, 3, 0.4)
			end
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	Kit.on("HRMeeting", function(d)
		local head = d.v and d.v:FindFirstChild("Head")
		if head then
			Kit.floatText(head.Position + Vector3.new(0, 1.8, 0), "MEETING!", PURPLE, 2, 0.9, 1.2)
		end
	end)

	Kit.on("HRHug", function(d)
		CartoonFX.sound("Boing", d.p, 1)
		for _ = 1, 8 do -- cœurs (boules roses) qui jaillissent
			local h = Kit.part({ Shape = BALL, Size = Vector3.one * 0.7, CFrame = CFrame.new(d.p + Vector3.new(0, 1, 0)), Color = PINK })
			Kit.tween(h, 0.6, { CFrame = CFrame.new(d.p + Vector3.new(Kit.rng:NextNumber(-3, 3), Kit.rng:NextNumber(2, 5), Kit.rng:NextNumber(-3, 3))), Transparency = 1 })
			Debris:AddItem(h, 0.62)
		end
		if (d.n or 0) >= 2 then
			Kit.floatText(d.p + Vector3.new(0, 4, 0), "GROUP HUG!", PINK, 3, 0.8, 1.5)
		end
	end)

	-- étoile de notation qui tombe du ciel
	Kit.on("HRStar", function(d)
		local size = d.big and 4 or 2.6
		local from = CFrame.new(d.p + Vector3.new(0, 30, 0)) * CFrame.Angles(0, Kit.rng:NextNumber(0, 6), 0)
		local parts = starAt(from, size, STAR)
		for _, p in ipairs(parts) do
			local rel = from:ToObjectSpace(p.CFrame)
			Kit.tween(p, d.fall, { CFrame = (from - Vector3.new(0, 28.5, 0)) * rel }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(p, d.fall + 0.3)
		end
		task.delay(d.fall, function()
			CartoonFX.sound("Ding", d.p, 0.7)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), 4.5, STAR)
			CartoonFX.cracks(d.p, d.big and 6 or 3, d.big and 4 or 2)
			if d.big then
				CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1, STAR)
				CartoonFX.shake(0.3)
			end
			Kit.cubes(d.p + Vector3.new(0, 1, 0), 8, { STAR, Color3.new(1, 1, 1) }, 0.5, 6, 0.4)
			for _, p in ipairs(parts) do
				Kit.tween(p, 0.25, { Transparency = 1 })
			end
		end)
	end)

	-- marque WRITTEN UP + aura de transformation (coches violettes)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.15)
			tick += 1
			local nowS = workspace:GetServerTimeNow()
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("WriteUpBy") and (c:GetAttribute("WriteUpUntil") or 0) > nowS then
					Kit.mark(c, "WriteUpMark", "WRITTEN UP", PURPLE)
				else
					Kit.mark(c, "WriteUpMark", nil)
				end
				if tick % 2 == 0 and c:GetAttribute("CharacterName") == "HRManager" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(-2, 1), Kit.rng:NextNumber(-2, 2))
						Kit.floatText(r.Position + off, Kit.rng:NextNumber() < 0.5 and "!" or "?", PURPLE, 1.2, 0.9, 2.5)
					end
				end
			end
		end
	end)
end

return M
