--[[
	The IT Guy — personnage complet (format : voir Modules/ContentLoader).
	Passif : immunisé contre l'aveuglement ; +25 % de dégâts avec l'électronique (clavier, écran, câble, baie serveur).
	Attaques : Ctrl+Alt+Del (téléportation dans le dos), Cable Whip (lasso qui attire), Firewall (mur de feu qui bloque les projectiles).
	Transformation Blue Screen of Death : Blue Screen (gel sur place), DDoS (rafale de pixels), Virus Upload (virus à retardement qui explose).
	Cable Whip plaque la cible au sol (Pin) après l'avoir tirée.
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local TEAL = Color3.fromRGB(0, 200, 170)
local DARK = Color3.fromRGB(25, 28, 34)
local BSOD = Color3.fromRGB(20, 90, 220)
local GLITCH = { Color3.fromRGB(0, 255, 170), Color3.fromRGB(20, 20, 25), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 40, 160), Color3.fromRGB(40, 120, 255) }
local FIRE = { Color3.fromRGB(255, 120, 30), Color3.fromRGB(230, 50, 40), Color3.fromRGB(255, 200, 40) }
local ELECTRONICS = { Keyboard = true, Monitor = true, Cable = true, ServerRack = true }

local M = { Id = "ITGuy", Order = 5 }

M.Character = {
	DisplayName = "The IT Guy",
	Role = "Tricky hacker",
	Color = TEAL,
	Shirt = Color3.fromRGB(60, 190, 175), Pants = Color3.fromRGB(55, 58, 70), Tie = Color3.fromRGB(30, 30, 40),
	Passive = { Name = "Have You Tried Turning It Off?", Desc = "Immune to Blind. Keyboards, Monitors, Cables and Server Racks deal +25% damage in his hands." },
	Attacks = { "CtrlAltDel", "CableWhip", "Firewall" },
	Transformation = { Name = "Blue Screen of Death", Desc = "Glowing blue visor and floating error screens.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "BlueScreen", "DDoS", "VirusUpload" },
}

M.Attacks = {
	CtrlAltDel = { Name = "Ctrl+Alt+Del", Kind = "ITTeleport", Desc = "Glitch-teleport behind the closest coworker in front of you and smack them from behind.", Cooldown = 8, Anim = "CtrlAltDel", Sound = "Electric",
		Range = 34, Windup = 0.18, Damage = 9, Knockback = 38, KnockUp = 12, Stun = 0.9, Category = "Heavy", Power = 0.8, Words = { "CTRL+ALT+DEL!", "REBOOTED!" } },
	CableWhip = { Name = "Cable Whip", Kind = "ITLasso", Desc = "Lasso the first coworker in a long line with an ethernet cable, yank them to you and slam them into the floor (PIN).", Prop = "ITCable", Cooldown = 9, Anim = "CableWhip", Sound = "Whoosh",
		Windup = 0.24, Range = 34, Width = 5, PullSpeed = 95, Damage = 9, Knockback = 0, KnockUp = 0, Stun = 1.0, Category = "Heavy", Power = 0.9, Words = { "CABLE WHIP!", "YOINK!" }, Effects = { Pin = true } },
	Firewall = { Name = "Firewall", Kind = "ITFirewall", Desc = "Raise a wall of fire blocks in front of you: it stops projectiles and burns whoever crosses it.", Cooldown = 13, Anim = "Firewall", Sound = "Electric",
		Windup = 0.28, Width = 14, Height = 7, Offset = 6, WallTime = 6, Damage = 4, Knockback = 28, KnockUp = 12, Stun = 0.5, Category = "Light", Power = 0.5,
		Words = { "FIREWALL!", "ACCESS DENIED!" }, Effects = { Burn = { Ticks = 2, Damage = 2, Interval = 0.5 } } },
	BlueScreen = { Name = "Blue Screen", Kind = "ITBlueScreen", Desc = "A giant Blue Screen of Death crashes down in front of you and freezes everyone under it.", Cooldown = 12, Anim = "BlueScreen", Sound = "Electric",
		Windup = 0.38, Radius = 12, Offset = 7, Freeze = 1.6, Damage = 7, Knockback = 0, KnockUp = 0, Stun = 1.6, Category = "Heavy", Power = 0.8, Words = { "BLUE SCREEN!", "NOT RESPONDING!" } },
	DDoS = { Name = "DDoS", Kind = "ITBarrage", Desc = "Type furiously and flood the target with a barrage of data pixels.", Prop = "ITLaptop", Cooldown = 8, Anim = "DDoS", Sound = "Electric",
		Shots = 14, Interval = 0.07, Spread = 9, Speed = 125, Range = 70, Size = Vector3.new(0.7, 0.7, 0.7), Colors = { Color3.fromRGB(0, 255, 170), Color3.fromRGB(40, 140, 255), Color3.fromRGB(255, 255, 255) },
		Damage = 1.3, Knockback = 4, Stun = 0.4, Category = "Light", Power = 0.25, Words = { "PING!", "LAG!", "404!", "BZZT!" } },
	VirusUpload = { Name = "Virus Upload", Kind = "ITVirus", Desc = "Infect the closest coworker in front of you: they glitch and slow down, then EXPLODE in glitch cubes 2.4s later, launching them and everyone near them.", Prop = "ITLaptop", Cooldown = 13, Anim = "VirusUpload", Sound = "Electric",
		Windup = 0.3, Range = 30, Fuse = 2.4, Radius = 11, InfectDamage = 4, Damage = 13, Knockback = 12, Launch = Vector3.new(14, 50, 0), Stun = 1.1, Category = "Heavy", Power = 1.15, Words = { "SYSTEM CRASH!", "FATAL ERROR!" } },
}

------------------------------------------------------------------------
-- Animations (une par attaque)
------------------------------------------------------------------------
local function ddosAnim()
	local f = { { t = 0 }, { t = 0.08, RS = { p = 1.25, y = 0.45 }, LS = { p = 1.1, y = 0.7 }, RJ = { ln = 0.3 }, RH = { p = -0.2 }, LH = { p = 0.35 } } }
	local t = 0.08
	for i = 1, 14 do
		t += 0.065
		local up = i % 2 == 0
		table.insert(f, { t = t, RS = { p = 1.25, y = 0.45 }, LS = { p = up and 1.5 or 1.05, y = up and 0.5 or 0.8 }, RJ = { ln = up and 0.36 or 0.28, tw = up and 0.06 or -0.06 }, RH = { p = -0.2 }, LH = { p = 0.35 } })
	end
	table.insert(f, { t = t + 0.12, RS = { p = 1.6, y = 0.2 }, LS = { p = 2.6, r = -0.5 }, RJ = { ln = -0.15 } }) -- « enter ! »
	table.insert(f, { t = t + 0.3 })
	return f
end

local function crashAnim()
	local f = { { t = 0 } }
	local head = { p = 2.7, y = 1.3, r = 0.25 }
	for i = 1, 5 do
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = i * 0.08, RS = head, LS = head, RJ = { ln = 0.35 + i * 0.05, sd = 0.14 * s, tw = 0.12 * s }, RH = { p = 0.3, r = -0.15 }, LH = { p = 0.3, r = -0.15 } })
	end
	table.insert(f, { t = 0.5, RS = { p = 2.3, r = -1.4 }, LS = { p = 2.3, r = -1.4 }, RJ = { ln = -0.5 }, RH = { r = -0.5 }, LH = { r = -0.5 } })
	table.insert(f, { t = 0.85, RS = { p = 2.2, r = -1.35 }, LS = { p = 2.2, r = -1.35 }, RJ = { ln = -0.45 }, RH = { r = -0.45 }, LH = { r = -0.45 } })
	table.insert(f, { t = 1.0 })
	return f
end

M.Anims = {
	CtrlAltDel = { -- tape le raccourci, disparaît accroupi, réapparaît avec un gros revers
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.35, y = 0.7 }, LS = { p = 1.35, y = 0.7 }, RJ = { ln = 0.2 } },
		{ t = 0.09, RS = { p = 1.15, y = 0.7 }, LS = { p = 1.5, y = 0.7 }, RJ = { ln = 0.22 } },
		{ t = 0.13, RS = { p = 1.5, y = 0.7 }, LS = { p = 1.15, y = 0.7 }, RJ = { ln = 0.25 } },
		{ t = 0.19, RS = { p = -0.9, r = -0.3 }, LS = { p = -0.9, r = -0.3 }, RJ = { ln = 0.65 }, RH = { p = 0.6 }, LH = { p = -0.6 } },
		{ t = 0.27, RS = { p = 1.5, y = -1.3, r = -0.5 }, LS = { p = 0.3 }, RJ = { tw = -0.95, ln = 0.1 }, LH = { p = 0.4 } },
		{ t = 0.34, RS = { p = 1.6, y = 1.15 }, LS = { p = -0.4 }, RJ = { tw = 0.85, ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.55, RS = { p = 1.5, y = 1.05 }, LS = { p = -0.35 }, RJ = { tw = 0.75, ln = 0.15 } },
		{ t = 0.72 },
	},
	CableWhip = { -- fait tourner le câble au-dessus de la tête, fouette devant, puis tire de toutes ses forces
		{ t = 0 },
		{ t = 0.07, RS = { p = 3.0, r = -0.3 }, RJ = { tw = -0.3, ln = -0.1 } },
		{ t = 0.13, RS = { p = 2.9, y = 1.5, r = -0.5 }, RJ = { tw = -0.2 } },
		{ t = 0.19, RS = { p = 3.0, y = -1.5, r = -0.2 }, RJ = { tw = -0.35 } },
		{ t = 0.27, RS = { p = 1.5, y = 0.2 }, LS = { p = -0.5 }, RJ = { tw = 0.5, ln = 0.3 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.45, RS = { p = 1.5, y = 0.2 }, LS = { p = -0.4 }, RJ = { tw = 0.45, ln = 0.25 }, LH = { p = 0.5 } },
		{ t = 0.58, RS = { p = 0.3, r = -0.2 }, LS = { p = 1.3, y = 0.4 }, RJ = { tw = -0.35, ln = -0.35 }, RH = { p = 0.55 }, LH = { p = -0.35 } },
		{ t = 0.85, RS = { p = 0.2 }, LS = { p = 1.2, y = 0.4 }, RJ = { tw = -0.3, ln = -0.3 }, RH = { p = 0.5 }, LH = { p = -0.3 } },
		{ t = 1.0 },
	},
	Firewall = { -- bras croisés, grands bras ouverts, mains plaquées au sol (un genou devant)
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.6, y = -0.9 }, LS = { p = 1.6, y = -0.9 }, RJ = { ln = -0.1 } },
		{ t = 0.2, RS = { p = 2.7, r = -0.8 }, LS = { p = 2.7, r = -0.8 }, RJ = { ln = -0.35 } },
		{ t = 0.3, RS = { p = 0.95, r = -0.45 }, LS = { p = 0.95, r = -0.45 }, RJ = { ln = 0.75 }, RH = { p = 0.95 }, LH = { p = -0.25 } },
		{ t = 0.65, RS = { p = 0.95, r = -0.45 }, LS = { p = 0.95, r = -0.45 }, RJ = { ln = 0.7 }, RH = { p = 0.9 }, LH = { p = -0.25 } },
		{ t = 0.85 },
	},
	BlueScreen = { -- « ta-da » : bras levés en V, puis paumes poussées vers l'avant
		{ t = 0 },
		{ t = 0.16, RS = { p = 2.9, r = -0.6 }, LS = { p = 2.9, r = -0.6 }, RJ = { ln = -0.35 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.34, RS = { p = 3.05, r = -0.75 }, LS = { p = 3.05, r = -0.75 }, RJ = { ln = -0.42 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.44, RS = { p = 1.45, y = 0.3 }, LS = { p = 1.45, y = 0.3 }, RJ = { ln = 0.45 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.95, RS = { p = 1.4, y = 0.3 }, LS = { p = 1.4, y = 0.3 }, RJ = { ln = 0.4 }, LH = { p = 0.55 }, RH = { p = -0.3 } },
		{ t = 1.1 },
	},
	DDoS = ddosAnim(), -- portable dans une main, l'autre tape comme un fou
	VirusUpload = { -- tape le virus sur le portable, puis « pistolet à doigt » : upload !
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.3, y = 0.5 }, LS = { p = 1.2, y = 0.7 }, RJ = { ln = 0.3 }, RH = { p = -0.2 }, LH = { p = 0.35 } },
		{ t = 0.13, RS = { p = 1.3, y = 0.5 }, LS = { p = 1.55, y = 0.6 }, RJ = { ln = 0.34, tw = 0.06 } },
		{ t = 0.18, RS = { p = 1.3, y = 0.5 }, LS = { p = 1.05, y = 0.8 }, RJ = { ln = 0.28, tw = -0.06 } },
		{ t = 0.24, RS = { p = 1.2, y = 0.5 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0.35 } },
		{ t = 0.31, RS = { p = 1.8, y = 0.05 }, LS = { p = -0.45, r = -0.35 }, RJ = { ln = 0.1, tw = 0.45 }, RH = { p = -0.45 }, LH = { p = 0.65 } },
		{ t = 0.37, RS = { p = 2.25, y = 0.05 }, LS = { p = -0.4, r = -0.35 }, RJ = { ln = -0.15, tw = 0.5 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.6, RS = { p = 1.95, y = 0.05 }, LS = { p = -0.3, r = -0.3 }, RJ = { ln = -0.05, tw = 0.4 } },
		{ t = 0.8 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	ITCable = {
		{ Vector3.new(0.35, 1.3, 1.3), CFrame.new(0, -1.35, 0), DARK, CYL }, -- bobine
		{ Vector3.new(0.38, 0.6, 0.6), CFrame.new(0, -1.35, 0), Color3.fromRGB(70, 75, 85), CYL },
		{ Vector3.new(0.14, 0.9, 0.14), CFrame.new(0, -2.3, -0.35), DARK },
		{ Vector3.new(0.32, 0.45, 0.32), CFrame.new(0, -2.85, -0.35), Color3.fromRGB(40, 140, 255) }, -- prise RJ45
	},
	ITLaptop = {
		{ Vector3.new(1.7, 1.15, 0.12), CFrame.new(-0.35, -1.65, 0.05), Color3.fromRGB(190, 195, 205) }, -- base
		{ Vector3.new(1.5, 0.9, 0.04), CFrame.new(-0.35, -1.6, 0.13), Color3.fromRGB(60, 65, 75) }, -- clavier
		{ Vector3.new(1.7, 0.1, 1.1), CFrame.new(-0.35, -2.25, 0.62), Color3.fromRGB(190, 195, 205) }, -- écran
		{ Vector3.new(1.45, 0.04, 0.85), CFrame.new(-0.35, -2.19, 0.62), Color3.fromRGB(0, 230, 170) },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : lunettes, cordon + badge, portable à la main gauche
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.46, 0.34, 0.06), CFrame.new(0.27 * s, 0.12, -0.62), DARK) -- monture
		prop(f, head, Vector3.new(0.34, 0.22, 0.06), CFrame.new(0.27 * s, 0.12, -0.64), Color3.fromRGB(170, 235, 255)) -- verre
		prop(f, head, Vector3.new(0.06, 0.07, 0.62), CFrame.new(0.62 * s, 0.14, -0.32), DARK) -- branche
		prop(f, torso, Vector3.new(0.12, 1.15, 0.08), CFrame.new(0.3 * s, 0.42, -0.55) * CFrame.Angles(0, 0, -0.4 * s), TEAL) -- cordon
	end
	prop(f, head, Vector3.new(0.14, 0.06, 0.06), CFrame.new(0, 0.15, -0.63), DARK)
	prop(f, torso, Vector3.new(0.6, 0.8, 0.08), CFrame.new(0, -0.2, -0.56), Color3.fromRGB(255, 255, 255)) -- badge
	prop(f, torso, Vector3.new(0.6, 0.22, 0.09), CFrame.new(0, 0.08, -0.565), TEAL)
	prop(f, torso, Vector3.new(0.12, 0.45, 0.12), CFrame.new(0.62, 0.55, -0.55), Color3.fromRGB(40, 90, 230)) -- stylo de poche
end

M.Signature = { Hand = "Left", Build = function(f, a, prop) -- portable fermé coincé dans la main
	prop(f, a, Vector3.new(0.22, 1.25, 1.6), CFrame.new(-0.05, -1.45, -0.25), Color3.fromRGB(190, 195, 205))
	prop(f, a, Vector3.new(0.23, 0.08, 1.6), CFrame.new(-0.05, -0.86, -0.25), DARK)
	prop(f, a, Vector3.new(0.05, 0.38, 0.38), CFrame.new(-0.18, -1.45, -0.25), TEAL) -- logo
end }

-- Transformation : visière bleue lumineuse + écrans d'erreur qui flottent autour de lui
function M.Transform(f, head, torso, c, prop)
	local visor = prop(f, head, Vector3.new(1.3, 0.32, 0.1), CFrame.new(0, 0.12, -0.7), Color3.fromRGB(60, 150, 255))
	visor.Transparency = 0.15
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(60, 150, 255)
	pl.Range = 12
	pl.Brightness = 2
	pl.Parent = visor
	for i, off in ipairs({ CFrame.new(-1.9, 1.3, 0.5) * CFrame.Angles(0, 0.5, 0.1), CFrame.new(1.9, 1.5, 0.5) * CFrame.Angles(0, -0.5, -0.1), CFrame.new(0, 2.4, 1.0) * CFrame.Angles(-0.3, 0, 0) }) do
		local s = prop(f, torso, Vector3.new(1.4, 0.95, 0.12), off, BSOD)
		prop(f, torso, Vector3.new(1.55, 1.1, 0.1), off * CFrame.new(0, 0, 0.03), DARK)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = s
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Text = i == 3 and "ERROR" or ":("
		l.Parent = gui
		local gui2 = gui:Clone()
		gui2.Face = Enum.NormalId.Front
		gui2.Parent = s
	end
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function frontTarget(attacker, dir, range)
	local root = Kit.root(attacker)
	local best, bestD = nil, math.huge
	for _, v in ipairs(Kit.enemies(attacker)) do
		local to = Kit.root(v).Position - root.Position
		local d = to.Magnitude
		if d <= range and not Kit.isProtected(v) then
			local facing = Kit.flat(to):Dot(dir)
			if (facing >= 0.35 or d < 10) and d < bestD then
				best, bestD = v, d
			end
		end
	end
	return best
end

M.Kinds = {
	-- Ctrl+Alt+Del : téléportation derrière la cible puis coup
	ITTeleport = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "ITBlink", p = root.Position, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local target = frontTarget(attacker, dir, cfg.Range)
		if target then
			local vr = Kit.root(target)
			local back = Kit.flat(vr.CFrame.LookVector)
			local dest = Kit.safePoint(vr.Position, vr.Position - back * 3.6, 1.2)
			root.CFrame = CFrame.lookAt(dest, Vector3.new(vr.Position.X, dest.Y, vr.Position.Z))
			Kit.fx({ id = "ITBlink", p = dest, a = attacker, arrive = true })
			task.wait(0.1)
			if api.CharacterState.isAlive(attacker) then
				api.hit(attacker, target, cfg, api.flat(vr.Position - root.Position, back * -1))
			end
		else
			local dest = Kit.safePoint(root.Position, root.Position + dir * 16, 2)
			root.CFrame = CFrame.lookAt(dest, dest + dir)
			Kit.fx({ id = "ITBlink", p = dest, a = attacker, arrive = true })
		end
	end,

	-- Cable Whip : lasso sur une ligne, la cible est tirée jusqu'à nous puis soulevée
	ITLasso = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		if not victim then
			Kit.fx({ id = "ITCable", a = attacker, dir = dir, range = cfg.Range, dur = 0.35 })
			return
		end
		local vr = Kit.root(victim)
		local dist = (vr.Position - root.Position).Magnitude
		local t = math.clamp((dist - 4) / cfg.PullSpeed, 0.08, 0.9)
		Kit.fx({ id = "ITCable", a = attacker, v = victim, dur = t + 0.2 })
		api.CharacterState.stun(victim, t + 0.5)
		task.wait(0.08) -- le câble atteint la cible
		t = Kit.pull(victim, root.Position, cfg.PullSpeed, 4)
		task.wait(t + 0.03)
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) then
			api.hit(attacker, victim, cfg, api.flat(vr.Position - root.Position, dir))
		end
	end,

	-- Firewall : mur de blocs de feu (bloque les projectiles : parts interrogeables hors du dossier FX)
	ITFirewall = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local spot = Kit.safePoint(root.Position, root.Position + look * cfg.Offset, 2.5)
		local ground = Kit.ground(spot)
		local base = CFrame.lookAt(ground, ground + look)
		local model = Instance.new("Model")
		model.Name = "Firewall"
		local cols, rows = 7, 3
		local bw, bh = cfg.Width / cols, cfg.Height / rows
		local parts = {}
		for r = 1, rows do
			for col = 1, cols do
				local x = -cfg.Width / 2 + bw * (col - 0.5) + ((r % 2 == 0) and bw * 0.25 or -bw * 0.25)
				local p = Kit.sPart({ Name = "FireBlock", Size = Vector3.new(bw * 0.92, bh * 0.9, 1.6), Color = FIRE[(r + col) % 3 + 1], Transparency = 0.12, CanQuery = true,
					CFrame = base * CFrame.new(x, bh * (r - 0.5), 0) }, model)
				table.insert(parts, p)
			end
		end
		for col = 1, cols do -- flammes au sommet
			local p = Kit.sPart({ Name = "Flame", Size = Vector3.new(bw * 0.5, bh * 0.6, 1.0), Color = FIRE[3], Transparency = 0.2, CanQuery = true,
				CFrame = base * CFrame.new(-cfg.Width / 2 + bw * (col - 0.5), cfg.Height + bh * 0.25, 0) * CFrame.Angles(0, 0, math.rad(45)) }, model)
			table.insert(parts, p)
		end
		local light = Instance.new("PointLight")
		light.Color = FIRE[1]
		light.Range = 16
		light.Brightness = 2
		light.Parent = parts[4]
		model.Parent = workspace
		Kit.fx({ id = "ITFirewall", cf = base, w = cfg.Width, h = cfg.Height, dur = cfg.WallTime })
		-- brûle ceux qui le traversent (repoussés du côté d'où ils viennent)
		local last = {}
		local t0 = os.clock()
		while os.clock() - t0 < cfg.WallTime and model.Parent do
			for _, v in ipairs(Kit.enemies(attacker)) do
				local lp = base:PointToObjectSpace(Kit.root(v).Position)
				if math.abs(lp.X) <= cfg.Width / 2 + 0.8 and math.abs(lp.Z) <= 2.4 and lp.Y > -2 and lp.Y < cfg.Height + 2.5 then
					if os.clock() - (last[v] or -10) > 0.8 then
						last[v] = os.clock()
						local side = lp.Z >= 0 and 1 or -1
						api.hit(attacker, v, cfg, base.LookVector * -side)
					end
				end
			end
			task.wait(0.15)
		end
		for _, p in ipairs(parts) do
			game:GetService("TweenService"):Create(p, TweenInfo.new(0.4), { Transparency = 1, Size = p.Size * 0.3 }):Play()
		end
		game:GetService("Debris"):AddItem(model, 0.45)
	end,

	-- Blue Screen : écran bleu géant, tout le monde dessous est gelé sur place
	ITBlueScreen = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		local spot = Kit.safePoint(root.Position, root.Position + look * cfg.Offset, 2)
		local center = Kit.ground(spot)
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "ITBSOD", p = center, look = look, r = cfg.Radius, fall = cfg.Windup, dur = cfg.Freeze + 0.3, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(Kit.enemies(attacker)) do
			local vp = Kit.root(v).Position
			local flatD = Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude
			if flatD <= cfg.Radius and math.abs(vp.Y - center.Y) < 9 then
				if api.hit(attacker, v, cfg, api.flat(vp - root.Position, look)) == "Hit" then
					Kit.hold(v, cfg.Freeze)
					Kit.fx({ id = "ITFrozen", v = v, dur = cfg.Freeze })
				end
			end
		end
	end,

	-- Virus Upload : infecte la cible devant, puis elle explose (et touche ses voisins) après Fuse secondes
	ITVirus = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local target = frontTarget(attacker, dir, cfg.Range)
		if not target then
			Kit.fx({ id = "ITVirusMiss", a = attacker, dir = dir })
			return
		end
		local infect = { Name = cfg.Name, Damage = cfg.InfectDamage, Knockback = 2, KnockUp = 0, Stun = 0.5, Category = "Light", Power = 0.35, Words = { "INFECTED!", "MALWARE!" } }
		local vr = Kit.root(target)
		Kit.fx({ id = "ITVirusLink", a = attacker, v = target })
		if api.hit(attacker, target, infect, api.flat(vr.Position - root.Position, dir)) ~= "Hit" then
			return
		end
		api.CharacterState.setSpeedMod(target, "Virus", 0.7, cfg.Fuse)
		Kit.fx({ id = "ITVirus", v = target, dur = cfg.Fuse })
		task.wait(cfg.Fuse)
		if not target.Parent or not api.CharacterState.isAlive(target) then
			return
		end
		local c = Kit.root(target).Position
		Kit.fx({ id = "ITVirusBoom", p = c, r = cfg.Radius, a = attacker })
		for _, v in ipairs(Kit.inRadius(attacker, c, cfg.Radius)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, dir), { hitPos = Kit.root(v).Position })
		end
		api.ZoneService.shatterAround(Kit.ground(c), cfg.Radius * 0.6, Vector3.new(0, 30, 0))
	end,

	-- DDoS : rafale de petits pixels dans la direction visée
	ITBarrage = function(attacker, cfg, aim, api)
		local rng = Kit.rng
		for i = 1, cfg.Shots do
			if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
				return
			end
			local base = Kit.aimDir(attacker, aim)
			local dir = CFrame.Angles(0, math.rad(rng:NextNumber(-cfg.Spread, cfg.Spread)), 0) * base
			api.projectile(attacker, cfg, dir, cfg.Colors[(i % #cfg.Colors) + 1])
			task.wait(cfg.Interval)
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur)
------------------------------------------------------------------------
function M.ServerInit(api)
	table.insert(api.CombatService.damageMods, function(p)
		local a = p.attacker
		if a and a:GetAttribute("CharacterName") == "ITGuy" and p.itemId and ELECTRONICS[p.itemId] then
			p.damage *= 1.25
			p.power = (p.power or 0.5) + 0.15
		end
	end)
	-- immunisé contre l'aveuglement (Flashlight, seau, cône, Policy Update…)
	local function watch(c)
		c:GetAttributeChangedSignal("BlindUntil"):Connect(function()
			if c:GetAttribute("CharacterName") == "ITGuy" and (c:GetAttribute("BlindUntil") or 0) > 0 then
				c:SetAttribute("BlindUntil", 0)
				c:SetAttribute("HeadPropUntil", 0)
				local head = c:FindFirstChild("Head")
				if head then
					Kit.fx({ id = "ITImmune", p = head.Position })
				end
			end
		end)
	end
	api.Signals.CharacterSpawned:Connect(watch)
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			watch(pl.Character)
		end
	end
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
M.MoveFX = {
	CtrlAltDel = function(c, d, api)
		api.afterimages(c, 0.2, TEAL)
	end,
	CableWhip = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			api.CartoonFX.sparks(r.Position + Vector3.new(0, 2.5, 0), 8, TEAL)
		end
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), TEAL, 0.6, 1.2, 1)
		task.delay(0.26, function()
			local r2 = c:FindFirstChild("HumanoidRootPart")
			if r2 then
				api.CartoonFX.slashArc(r2.CFrame * CFrame.new(0, 1, 0), 5, TEAL, -60, 40, 0.08, 75, 0.35)
				api.CartoonFX.casterShake(c, 0.3)
			end
		end)
	end,
	Firewall = function(c, d, api)
		task.delay(0.28, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.shockwave(r.Position - Vector3.new(0, 2.8, 0) + r.CFrame.LookVector * 2, 6, FIRE[1])
				api.CartoonFX.cracks(r.Position - Vector3.new(0, 2.8, 0) + r.CFrame.LookVector * 3, 5, 3)
				api.CartoonFX.light(r.Position + r.CFrame.LookVector * 6, FIRE[1], 20, 4, 0.5)
				api.CartoonFX.casterShake(c, 0.5)
			end
		end)
	end,
	DDoS = function(c, d, api)
		task.spawn(function()
			for i = 1, 7 do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				Kit.floatText(r.Position + r.CFrame.LookVector * 2 + Vector3.new(api.rng:NextNumber(-1.5, 1.5), 1.5, 0), (i % 2 == 0) and "1010" or "0110", Color3.fromRGB(0, 255, 170), 1.6, 0.6, 2.5)
				task.wait(0.13)
			end
		end)
	end,
	VirusUpload = function(c, d, api)
		task.delay(0.05, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.implode(r.Position + r.CFrame.LookVector * 1.5 + Vector3.new(0, 0.5, 0), 5, GLITCH, 12, 0.25)
			end
		end)
		task.delay(0.33, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0), r.CFrame.LookVector, 5, TEAL, 0.2)
				Kit.cubes(r.Position + r.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0), 10, GLITCH, 0.5, 6, 0.35)
			end
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	-- disparition / apparition en cubes glitch
	Kit.on("ITBlink", function(d)
		Kit.cubes(d.p, 18, GLITCH, 0.8, d.arrive and 5 or 9, 0.45)
		CartoonFX.sound("Electric", d.p, 0.8)
		local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(d.p) * CFrame.Angles(0, 0, math.pi / 2), Color = TEAL, Transparency = 0.2 })
		Kit.tween(ring, 0.3, { Size = Vector3.new(0.1, 8, 8), Transparency = 1 })
		Debris:AddItem(ring, 0.32)
		if d.arrive then
			Kit.floatText(d.p + Vector3.new(0, 3, 0), "REBOOT", TEAL, 2.5, 0.6, 2)
			CartoonFX.pillar(d.p, 1.8, 9, TEAL, 0.25)
			CartoonFX.light(d.p, TEAL, 16, 4, 0.3)
			CartoonFX.casterShake(d.a, 0.3)
		end
	end)

	-- câble tendu entre la main et la cible
	Kit.on("ITCable", function(d)
		local c = d.a
		local cable = Kit.part({ Size = Vector3.new(0.25, 0.25, 1), Color = DARK })
		local plug = Kit.part({ Size = Vector3.new(0.5, 0.5, 0.7), Color = Color3.fromRGB(40, 140, 255) })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local arm = c and c:FindFirstChild("Right Arm")
			if el > d.dur or not arm then
				conn:Disconnect()
				cable:Destroy()
				plug:Destroy()
				return
			end
			local from = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
			local to
			local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
			if vr then
				local reach = math.clamp(el / 0.08, 0, 1)
				to = from:Lerp(vr.Position + Vector3.new(0, 0.5, 0), reach)
			else
				local k = el < d.dur * 0.5 and el / (d.dur * 0.5) or (d.dur - el) / (d.dur * 0.5)
				to = from + d.dir * d.range * math.clamp(k, 0, 1)
			end
			local len = math.max((to - from).Magnitude, 0.1)
			cable.Size = Vector3.new(0.25, 0.25, len)
			cable.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			plug.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len)
		end)
		if d.v then
			task.delay(0.08, function()
				local vr = d.v:FindFirstChild("HumanoidRootPart")
				if vr then
					CartoonFX.word(vr.Position + Vector3.new(0, 2, 0), "YOINK!", 0.7, "Light")
					CartoonFX.sparks(vr.Position, 12, TEAL)
				end
			end)
		end
	end)

	-- étincelles qui montent du mur de feu
	Kit.on("ITFirewall", function(d)
		CartoonFX.sound("Electric", d.cf.Position, 1)
		CartoonFX.shockwave(d.cf.Position + Vector3.new(0, 0.2, 0), d.w * 0.6, FIRE[1])
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				local pos = (d.cf * CFrame.new(Kit.rng:NextNumber(-d.w / 2, d.w / 2), d.h * Kit.rng:NextNumber(0.6, 1.1), 0)).Position
				local e = Kit.part({ Size = Vector3.one * Kit.rng:NextNumber(0.3, 0.7), CFrame = CFrame.new(pos), Color = FIRE[Kit.rng:NextInteger(1, 3)] })
				Kit.tween(e, 0.6, { CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(1, 1, 0), Transparency = 1 })
				Debris:AddItem(e, 0.62)
				task.wait(0.06)
			end
		end)
		Kit.floatText(d.cf.Position + Vector3.new(0, d.h + 1.5, 0), "FIREWALL", FIRE[1], 3, 0.9, 1)
	end)

	-- écran bleu géant qui tombe du ciel
	Kit.on("ITBSOD", function(d)
		local back = d.p + d.look * (d.r * 0.55)
		local w, h = d.r * 1.3, d.r * 0.85
		local final = CFrame.lookAt(back + Vector3.new(0, h / 2, 0), back + Vector3.new(0, h / 2, 0) - d.look)
		local screen = Kit.part({ Size = Vector3.new(w, h, 0.5), CFrame = final + Vector3.new(0, 40, 0), Color = BSOD })
		local frame = Kit.part({ Size = Vector3.new(w + 0.8, h + 0.8, 0.4), CFrame = final * CFrame.new(0, 0, 0.1) + Vector3.new(0, 40, 0), Color = DARK })
		local l = Kit.flatText(screen, ":(", Color3.new(1, 1, 1), Enum.NormalId.Front)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Size = UDim2.fromScale(0.8, 0.42)
		l.Position = UDim2.fromScale(0.08, 0.08)
		local l2 = l:Clone()
		l2.Text = "Your PC ran into a problem and needs to restart."
		l2.Font = Enum.Font.GothamBold
		l2.Size = UDim2.fromScale(0.84, 0.3)
		l2.Position = UDim2.fromScale(0.08, 0.55)
		l2.Parent = l.Parent
		Kit.tween(screen, d.fall, { CFrame = final }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.tween(frame, d.fall, { CFrame = final * CFrame.new(0, 0, 0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(d.fall, function()
			CartoonFX.sound("Crash", d.p, 1.2)
			CartoonFX.quake(d.p, d.r, Color3.fromRGB(60, 150, 255), 1.2)
			Kit.cubes(back + Vector3.new(0, 1, 0), 20, { BSOD, Color3.new(1, 1, 1) }, 0.8, 10, 0.5)
			CartoonFX.casterShake(d.a, 0.9)
		end)
		task.delay(d.fall + d.dur, function()
			Kit.tween(screen, 0.3, { Transparency = 1 })
			Kit.tween(frame, 0.3, { Transparency = 1 })
			Kit.tween(l, 0.3, { TextTransparency = 1 })
			Kit.tween(l2, 0.3, { TextTransparency = 1 })
		end)
		Debris:AddItem(screen, d.fall + d.dur + 0.35)
		Debris:AddItem(frame, d.fall + d.dur + 0.35)
	end)

	-- victime gelée : cadre bleu « NOT RESPONDING »
	Kit.on("ITFrozen", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		local box = Kit.part({ Size = Vector3.new(4.4, 6, 2.6), CFrame = vr.CFrame * CFrame.new(0, -0.4, 0), Color = Color3.fromRGB(60, 150, 255), Transparency = 0.6 })
		local tag = Kit.part({ Size = Vector3.new(4.4, 0.9, 0.1), CFrame = vr.CFrame * CFrame.new(0, 3.3, 0), Color = BSOD })
		Kit.flatText(tag, "NOT RESPONDING", Color3.new(1, 1, 1), Enum.NormalId.Front)
		Kit.flatText(tag, "NOT RESPONDING", Color3.new(1, 1, 1), Enum.NormalId.Back)
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not box.Parent or not vr.Parent then
				conn:Disconnect()
				return
			end
			box.CFrame = vr.CFrame * CFrame.new(0, -0.4, 0)
			tag.CFrame = vr.CFrame * CFrame.new(0, 3.3, 0)
		end)
		task.delay(d.dur, function()
			Kit.cubes(box.Position, 10, { BSOD, Color3.new(1, 1, 1) }, 0.6, 6, 0.4)
		end)
		Debris:AddItem(box, d.dur)
		Debris:AddItem(tag, d.dur)
	end)

	-- lien de données entre l'IT Guy et la cible infectée
	Kit.on("ITVirusLink", function(d)
		local a = d.a and d.a:FindFirstChild("HumanoidRootPart")
		local v = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if a and v then
			CartoonFX.beam(a.Position + Vector3.new(0, 0.6, 0), v.Position + Vector3.new(0, 0.6, 0), 0.6, TEAL, 0.3)
			Kit.cubes(v.Position, 12, GLITCH, 0.6, 6, 0.4)
		end
	end)

	-- victime infectée : cubes glitch qui tournent, compte à rebours, clignotement
	Kit.on("ITVirus", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.word(vr.Position + Vector3.new(0, 4, 0), "INFECTED!", 0.9, "Light")
		local cubes = {}
		for i = 1, 5 do
			table.insert(cubes, Kit.part({ Size = Vector3.one * 0.6, Color = GLITCH[(i % #GLITCH) + 1] }))
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not vr.Parent then
				conn:Disconnect()
				for _, cb in ipairs(cubes) do
					cb:Destroy()
				end
				return
			end
			local speed = 4 + el * 4
			for i, cb in ipairs(cubes) do
				local a = el * speed + i * (math.pi * 2 / #cubes)
				cb.CFrame = CFrame.new(vr.Position + Vector3.new(math.cos(a) * 2.6, math.sin(el * 6 + i) * 1.2, math.sin(a) * 2.6)) * CFrame.Angles(el * 5, el * 3, 0)
			end
		end)
		for i = 1, 3 do
			task.delay(d.dur - (4 - i) * 0.6, function()
				if vr.Parent then
					Kit.floatText(vr.Position + Vector3.new(0, 4.5, 0), tostring(4 - i), Color3.fromRGB(255, 60, 120), 2.5, 0.5, 1)
					CartoonFX.sound("Electric", vr.Position, 0.6)
				end
			end)
		end
	end)

	-- explosion du virus
	Kit.on("ITVirusBoom", function(d)
		CartoonFX.quake(d.p, d.r, TEAL, 1.3)
		Kit.cubes(d.p, 36, GLITCH, 1.1, 18, 0.7)
		CartoonFX.sound("Explosion", d.p, 1.3)
		local flash = Kit.part({ Shape = BALL, Size = Vector3.one * 2, Position = d.p, Color = Color3.fromRGB(150, 255, 230), Transparency = 0.2 })
		Kit.tween(flash, 0.3, { Size = Vector3.one * d.r * 2, Transparency = 1 })
		Debris:AddItem(flash, 0.32)
		CartoonFX.word(d.p + Vector3.new(0, 4, 0), "FATAL ERROR!", 1.3, "Heavy")
		CartoonFX.casterShake(d.a, 0.9)
	end)

	Kit.on("ITVirusMiss", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 2, 0), "404", TEAL, 2.2, 0.6, 1.5)
			Kit.cubes(r.Position + r.CFrame.LookVector * 3, 8, GLITCH, 0.5, 5, 0.4)
		end
	end)

	Kit.on("ITImmune", function(d)
		Kit.floatText(d.p + Vector3.new(0, 1.5, 0), "IMMUNE!", TEAL, 2.2, 0.7, 2)
	end)

	-- aura de transformation : 0 et 1 qui montent
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "ITGuy" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(-2, 1), Kit.rng:NextNumber(-2, 2))
						Kit.floatText(r.Position + off, Kit.rng:NextInteger(0, 1) == 0 and "0" or "1", Color3.fromRGB(80, 170, 255), 1, 0.8, 2.5)
					end
				end
			end
		end
	end)
end

return M
