--[[
	The Receptionist — personnage complet (format : voir Modules/ContentLoader).
	Passif Visitor Badge : tout ennemi qu'elle touche porte un badge VISITOR 5 s et subit +10 % de dégâts de tout le monde.
	Attaques : Hold the Line (fil de téléphone : attrape, ramène, fait tournoyer et projette), Service Bell (sonnette géante :
	           DING qui étourdit autour d'elle), Visitor Badge (badge en boomerang : touche à l'aller ET au retour).
	Transformation Customer Service Meltdown : Hold Music (zone de musique d'attente : ralentit), Hang Up! (combiné géant
	           qui s'abat sur une ligne et PLAQUE au sol), Transfer Call (échange de place avec la cible, qui reste sonnée).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local FUCHSIA = Color3.fromRGB(235, 60, 170) -- couleur du perso
local PINKL = Color3.fromRGB(255, 170, 220)
local PHONE = Color3.fromRGB(45, 42, 52)
local BRASS = Color3.fromRGB(240, 195, 70)
local WHITE = Color3.fromRGB(250, 250, 250)
local BLUE = Color3.fromRGB(60, 130, 230)
local HAIR = Color3.fromRGB(105, 62, 40)
local NOTES = { FUCHSIA, PINKL, Color3.fromRGB(150, 110, 255), WHITE }

local M = { Id = "Receptionist", Order = 11 }

M.Character = {
	DisplayName = "The Receptionist",
	Role = "Crowd control",
	Color = FUCHSIA,
	Shirt = Color3.fromRGB(230, 85, 175), Pants = Color3.fromRGB(60, 50, 78), Tie = Color3.fromRGB(255, 230, 120),
	Passive = { Name = "Visitor Badge", Desc = "Enemies she hits wear a VISITOR badge for 5s: +10% damage taken." },
	Attacks = { "HoldTheLine", "ServiceBell", "VisitorBadge" },
	Transformation = { Name = "Customer Service Meltdown", Desc = "Flashing CLOSED sign, headset and ringing phones.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "HoldMusic", "HangUp", "TransferCall" },
}

M.Attacks = {
	HoldTheLine = { Name = "Hold the Line", Kind = "RecCord", Desc = "Whip the handset on its curly cord: snag the first coworker in line, reel them in, twirl and fling.", Prop = "RecHandset", Cooldown = 8, Anim = "RecCord", Sound = "Whoosh",
		Windup = 0.26, Range = 32, Width = 5, PullSpeed = 90, TwirlTime = 0.4, Damage = 8, Knockback = 46, KnockUp = 18, Stun = 1.0, Category = "Heavy", Power = 0.85,
		Words = { "PLEASE HOLD!", "CONNECTED!" } },
	ServiceBell = { Name = "Service Bell", Kind = "RecBell", Desc = "Slam a giant service bell: the DING shockwave dazes everyone around you.", Prop = "RecBellProp", Cooldown = 10, Anim = "RecBell", Sound = "Ding",
		Windup = 0.34, Radius = 13, Damage = 6, Knockback = 16, KnockUp = 8, Stun = 1.6, Category = "Heavy", GuardBreak = true, Power = 0.7, Words = { "DING!", "DING DING!" } },
	VisitorBadge = { Name = "Visitor Badge", Kind = "RecBadge", Desc = "Fling a badge on a lanyard: it boomerangs back, hitting on the way out AND back.", Prop = "RecBadgeProp", Cooldown = 6, Anim = "RecBadge", Sound = "Throw",
		Range = 34, Speed = 85, Damage = 5, Knockback = 8, Stun = 0.6, Category = "Projectile", Power = 0.4, Words = { "CHECKED IN!", "VISITOR!" } },
	HoldMusic = { Name = "Hold Music", Kind = "RecMusic", Desc = "Drop a speakerphone blasting hold music: enemies around it are slowed and stung.", Prop = "RecSpeaker", Cooldown = 14, Anim = "RecMusic", Sound = "Ding",
		Radius = 13, MusicTime = 6, Tick = 0.6, SlowMult = 0.45, Damage = 1.3, Knockback = 3, Stun = 0.2, Category = "Light", Power = 0.2, Words = { "SMOOTH JAZZ!", "LA LA LA!" } },
	HangUp = { Name = "Hang Up!", Kind = "RecHangUp", Desc = "A giant phone handset SLAMS down in a long line ahead and PINS everyone under it.", Cooldown = 12, Anim = "RecHangUp", Sound = "Whoosh",
		Windup = 0.5, Width = 8, Length = 22, Damage = 14, Knockback = 0, Stun = 1.4, Category = "Heavy", GuardBreak = true, Power = 1.2,
		Words = { "HANG UP!", "CLICK!" }, Effects = { Pin = true } },
	TransferCall = { Name = "Transfer Call", Kind = "RecTransfer", Desc = "Transfer the call: swap places with the first coworker ahead, leaving them dazed. No one? Blink forward.", Prop = "RecPhone", Cooldown = 9, Anim = "RecTransfer", Sound = "Electric",
		Windup = 0.25, Range = 40, Width = 6, Blink = 14, Damage = 6, Knockback = 6, KnockUp = 6, Stun = 1.5, Category = "Heavy", Power = 0.6, Words = { "TRANSFERRED!", "WRONG NUMBER!" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
M.Anims = {
	RecCord = { -- fait tourner le combiné, fouette, ramène le fil, tour complet sur elle-même et projette
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.9, y = 0.4, r = -0.3 }, RJ = { tw = -0.35, ln = -0.15 } },
		{ t = 0.18, RS = { p = 2.6, y = -1.2, r = -0.6 }, RJ = { tw = -0.2 } },
		{ t = 0.26, RS = { p = 1.55, y = 0.2 }, LS = { p = -0.5 }, RJ = { tw = 0.55, ln = 0.3 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.42, RS = { p = 1.5, y = 0.2 }, LS = { p = -0.45 }, RJ = { tw = 0.5, ln = 0.25 }, LH = { p = 0.55 }, RH = { p = -0.3 } },
		{ t = 0.55, RS = { p = 0.4 }, LS = { p = 1.2, y = 0.5 }, RJ = { tw = -0.3, ln = -0.35 }, RH = { p = 0.55 }, LH = { p = -0.35 } },
		{ t = 0.7, RS = { p = 2.0, r = -1.1 }, LS = { p = 0.3, r = -0.6 }, RJ = { tw = 2.1, ln = 0.1 } },
		{ t = 0.82, RS = { p = 2.0, r = -1.1 }, LS = { p = 0.3, r = -0.6 }, RJ = { tw = 4.2, ln = 0.1 } },
		{ t = 0.92, RS = { p = 1.6, y = 0.4 }, LS = { p = -0.4 }, RJ = { tw = 6.6, ln = 0.35 }, LH = { p = 0.7 }, RH = { p = -0.4 } },
		{ t = 0.93, RS = { p = 1.6, y = 0.4 }, LS = { p = -0.4 }, RJ = { tw = 0.32, ln = 0.35 }, LH = { p = 0.7 }, RH = { p = -0.4 } },
		{ t = 1.15 },
	},
	RecBell = { -- main levée très haut, le buste penché en arrière, puis claque la sonnette de tout son poids
		{ t = 0 },
		{ t = 0.18, RS = { p = 3.2, r = -0.1 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = -0.35, tw = 0.2 }, RH = { p = -0.2 } },
		{ t = 0.31, RS = { p = 3.35 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = -0.42, tw = 0.25 }, RH = { p = -0.2 } },
		{ t = 0.37, RS = { p = 0.9, y = 0.2 }, LS = { p = -0.3, r = -0.4 }, RJ = { ln = 0.85, tw = -0.1 }, RH = { p = 0.9 }, LH = { p = -0.4 } },
		{ t = 0.72, RS = { p = 0.95, y = 0.2 }, LS = { p = -0.3, r = -0.4 }, RJ = { ln = 0.75, tw = -0.1 }, RH = { p = 0.85 }, LH = { p = -0.35 } },
		{ t = 0.88 },
	},
	RecBadge = { -- fait tournoyer le badge au-dessus de la tête, lancer de côté, puis le rattrape
		{ t = 0 },
		{ t = 0.06, RS = { p = 2.3, y = 1.2, r = -0.5 }, RJ = { tw = 0.3 } },
		{ t = 0.12, RS = { p = 2.3, y = -1.2, r = -0.5 }, RJ = { tw = 0.15 } },
		{ t = 0.2, RS = { p = 1.5, y = -0.8, r = -0.65 }, RJ = { tw = -0.65, ln = 0.25 }, LH = { p = 0.5 }, RH = { p = -0.3 } },
		{ t = 0.5, RS = { p = 1.45, y = -0.7, r = -0.6 }, RJ = { tw = -0.5, ln = 0.2 }, LH = { p = 0.4 } },
		{ t = 0.72, RS = { p = 1.9, y = 0.6 }, LS = { p = 1.7, y = -0.6 }, RJ = { ln = -0.15 } },
		{ t = 0.95 },
	},
	RecMusic = { -- pose le haut-parleur au sol, puis se dandine en claquant des doigts
		{ t = 0 },
		{ t = 0.15, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.8 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ t = 0.35, RS = { p = 2.4, r = -0.6 }, LS = { p = 0.6, r = -0.6 }, RJ = { sd = 0.25, ln = -0.1 }, RH = { r = -0.2 } },
		{ t = 0.55, RS = { p = 0.6, r = -0.6 }, LS = { p = 2.4, r = -0.6 }, RJ = { sd = -0.25, ln = -0.1 }, LH = { r = -0.2 } },
		{ t = 0.75, RS = { p = 2.4, r = -0.6 }, LS = { p = 0.6, r = -0.6 }, RJ = { sd = 0.25, ln = -0.1 }, RH = { r = -0.2 } },
		{ t = 0.95 },
	},
	RecHangUp = { -- deux bras au-dessus de la tête (cambrée), puis raccroche violemment de tout le corps
		{ t = 0 },
		{ t = 0.2, RS = { p = 3.3, y = 0.2 }, LS = { p = 3.3, y = 0.2 }, RJ = { ln = -0.55 }, RH = { p = -0.2 }, LH = { p = 0.25 } },
		{ t = 0.45, RS = { p = 3.4 }, LS = { p = 3.4 }, RJ = { ln = -0.65 }, RH = { p = -0.25 }, LH = { p = 0.3 } },
		{ t = 0.52, RS = { p = 1.2, y = 0.25 }, LS = { p = 1.2, y = 0.25 }, RJ = { ln = 1.0 }, RH = { p = 1.0 }, LH = { p = -0.5 } },
		{ t = 0.9, RS = { p = 1.25, y = 0.25 }, LS = { p = 1.25, y = 0.25 }, RJ = { ln = 0.9 }, RH = { p = 0.95 }, LH = { p = -0.45 } },
		{ t = 1.05 },
	},
	RecTransfer = { -- appuie sur la touche TRANSFERT, pirouette, pose triomphale
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.3, y = 0.9 }, LS = { p = 1.4, y = 0.6 }, RJ = { ln = 0.2 } },
		{ t = 0.14, RS = { p = 1.05, y = 0.9 }, LS = { p = 1.4, y = 0.6 }, RJ = { ln = 0.32 } },
		{ t = 0.2, RS = { p = 1.35, y = 0.9 }, LS = { p = 1.4, y = 0.6 }, RJ = { ln = 0.2 } },
		{ t = 0.28, RS = { p = 0.3, r = -1.2 }, LS = { p = 0.3, r = -1.2 }, RJ = { tw = 3.14, ln = -0.2 } },
		{ t = 0.4, RS = { p = 2.9, r = -0.4 }, LS = { p = 0.2, r = -0.5 }, RJ = { tw = 6.28, ln = -0.2 } },
		{ t = 0.41, RS = { p = 2.9, r = -0.4 }, LS = { p = 0.2, r = -0.5 }, RJ = { tw = 0, ln = -0.2 } },
		{ t = 0.72, RS = { p = 2.85, r = -0.4 }, LS = { p = 0.2, r = -0.5 }, RJ = { ln = -0.15 } },
		{ t = 0.86 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
M.Props = {
	RecHandset = { -- combiné de téléphone
		{ Vector3.new(0.4, 1.7, 0.45), CFrame.new(0, -1.45, -0.15), PHONE },
		{ Vector3.new(0.6, 0.45, 0.7), CFrame.new(0, -0.75, -0.35), PHONE },
		{ Vector3.new(0.6, 0.45, 0.7), CFrame.new(0, -2.15, -0.35), PHONE },
		{ Vector3.new(0.05, 0.3, 0.4), CFrame.new(-0.3, -1.45, -0.15), FUCHSIA },
	},
	RecBellProp = { -- petite sonnette de comptoir dans la main
		{ Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, -1.55, -0.2), BRASS, BALL },
		{ Vector3.new(0.2, 1.3, 1.3), CFrame.new(0, -2.0, -0.2) * ALONG_Y, PHONE, CYL },
		{ Vector3.new(0.3, 0.22, 0.22), CFrame.new(0, -1.05, -0.2) * ALONG_Y, BRASS, CYL },
	},
	RecBadgeProp = { -- badge VISITOR au bout de son cordon
		{ Vector3.new(0.06, 0.9, 0.06), CFrame.new(0, -1.3, -0.2), BLUE },
		{ Vector3.new(0.1, 1.2, 0.9), CFrame.new(0, -2.25, -0.2), WHITE },
		{ Vector3.new(0.11, 0.3, 0.9), CFrame.new(0, -1.8, -0.2), FUCHSIA },
	},
	RecSpeaker = { -- téléphone haut-parleur
		{ Vector3.new(1.5, 0.5, 1.3), CFrame.new(-0.3, -1.4, -0.35), PHONE },
		{ Vector3.new(0.9, 0.06, 0.9), CFrame.new(-0.3, -1.66, -0.35), FUCHSIA },
		{ Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.25, -1.66, -0.75), Color3.fromRGB(120, 255, 150), BALL },
	},
	RecPhone = { -- téléphone de bureau avec la grosse touche TRANSFER
		{ Vector3.new(1.2, 0.5, 1.0), CFrame.new(0, -1.35, -0.35), WHITE },
		{ Vector3.new(0.8, 0.06, 0.6), CFrame.new(0, -1.62, -0.35), PHONE },
		{ Vector3.new(0.35, 0.12, 0.35), CFrame.new(0.3, -1.66, -0.6), FUCHSIA },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : chignon, casque-micro, lunettes à chaînette, badge RECEPTION ; combiné à la main droite
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 0.6, 0.05), HAIR) -- cheveux
	prop(f, head, Vector3.new(1.3, 0.8, 0.3), CFrame.new(0, 0.25, 0.55), HAIR)
	prop(f, head, Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, 0.85, 0.5), HAIR, BALL) -- chignon
	prop(f, head, Vector3.new(0.12, 0.6, 0.12), CFrame.new(0.15, 1.1, 0.5) * CFrame.Angles(0, 0, 0.6), FUCHSIA) -- crayon dans le chignon
	prop(f, head, Vector3.new(1.36, 0.12, 0.14), CFrame.new(0, 0.72, 0), PHONE) -- arceau du casque
	prop(f, head, Vector3.new(0.16, 0.5, 0.5), CFrame.new(-0.66, 0.15, 0) * ALONG_Z, PHONE, CYL) -- écouteur
	prop(f, head, Vector3.new(0.08, 0.08, 0.7), CFrame.new(-0.6, -0.15, -0.35) * CFrame.Angles(0, -0.5, 0), PHONE) -- micro
	prop(f, head, Vector3.new(0.18, 0.18, 0.18), CFrame.new(-0.42, -0.2, -0.62), FUCHSIA, BALL)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.4, 0.26, 0.06), CFrame.new(0.25 * s, 0.12, -0.62), FUCHSIA) -- lunettes
		prop(f, head, Vector3.new(0.3, 0.17, 0.06), CFrame.new(0.25 * s, 0.12, -0.635), Color3.fromRGB(230, 245, 255))
	end
	prop(f, torso, Vector3.new(0.7, 0.32, 0.06), CFrame.new(0.45, 0.5, -0.56), WHITE) -- badge RECEPTION
	prop(f, torso, Vector3.new(0.7, 0.1, 0.07), CFrame.new(0.45, 0.62, -0.565), FUCHSIA)
	for i = -2, 2 do -- collier de perles
		prop(f, torso, Vector3.new(0.18, 0.18, 0.18), CFrame.new(i * 0.16, 0.82 - math.abs(i) * -0.03 - 0.06 * (2 - math.abs(i)), -0.56), WHITE, BALL)
	end
end

M.Signature = { Hand = "Right", Build = function(f, a, prop) -- combiné de téléphone avec un bout de fil
	prop(f, a, Vector3.new(0.32, 1.3, 0.36), CFrame.new(0, -1.25, -0.25), PHONE)
	prop(f, a, Vector3.new(0.45, 0.35, 0.55), CFrame.new(0, -0.7, -0.4), PHONE)
	prop(f, a, Vector3.new(0.45, 0.35, 0.55), CFrame.new(0, -1.8, -0.4), PHONE)
	for i = 1, 4 do
		prop(f, a, Vector3.new(0.15, 0.15, 0.15), CFrame.new(0.12 * ((i % 2 == 0) and 1 or -1), -1.95 - i * 0.14, 0), PHONE, BALL)
	end
end }

-- Transformation : panneau CLOSED qui clignote au-dessus de la tête, téléphones qui sonnent sur les épaules
function M.Transform(f, head, torso, c, prop)
	local sign = prop(f, head, Vector3.new(2.2, 0.8, 0.12), CFrame.new(0, 2.0, 0), Color3.fromRGB(220, 30, 40))
	sign.Name = "ClosedSign"
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = sign
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Text = "CLOSED"
		l.Parent = gui
	end
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 60, 60)
	pl.Range = 10
	pl.Brightness = 2
	pl.Parent = sign
	prop(f, head, Vector3.new(0.08, 0.9, 0.08), CFrame.new(-0.7, 1.35, 0) * CFrame.Angles(0, 0, -0.5), PHONE) -- fils du panneau
	prop(f, head, Vector3.new(0.08, 0.9, 0.08), CFrame.new(0.7, 1.35, 0) * CFrame.Angles(0, 0, 0.5), PHONE)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(1.0, 0.45, 0.8), CFrame.new(1.05 * s, 1.25, 0) * CFrame.Angles(0, 0, 0.25 * s), FUCHSIA) -- téléphones sur les épaules
		prop(f, torso, Vector3.new(1.1, 0.3, 0.35), CFrame.new(1.05 * s, 1.55, 0) * CFrame.Angles(0, 0, 0.25 * s), PHONE)
	end
end

------------------------------------------------------------------------
-- Serveur
------------------------------------------------------------------------
local function ready(attacker, api)
	return api.CharacterState.isAlive(attacker) and not api.CharacterState.isStunned(attacker)
end

local function decor(part, size, off, color)
	local p = Kit.sPart({ Size = size, CFrame = part.CFrame * off, Color = color })
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = p
	w.Parent = p
	p.Anchored = false
	p.Massless = true
	p.Parent = part
end

M.Kinds = {
	-- Hold the Line : fil qui attrape la 1re cible en ligne, la ramène, la fait tournoyer autour d'elle puis la projette
	RecCord = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		if not victim then
			Kit.fx({ id = "RecCordFX", a = attacker, dir = dir, range = cfg.Range, dur = 0.4 })
			return
		end
		local vr = Kit.root(victim)
		local dist = (vr.Position - root.Position).Magnitude
		local t = math.clamp((dist - 4) / cfg.PullSpeed, 0.08, 0.9)
		Kit.fx({ id = "RecCordFX", a = attacker, v = victim, dur = t + cfg.TwirlTime + 0.25 })
		api.CharacterState.stun(victim, t + cfg.TwirlTime + 0.6)
		task.wait(0.08)
		t = Kit.pull(victim, root.Position, cfg.PullSpeed, 4)
		task.wait(t + 0.03)
		if not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(victim) then
			return
		end
		-- tour complet autour d'elle, comme un lasso
		local vh = victim:FindFirstChildOfClass("Humanoid")
		local a0 = Instance.new("Attachment")
		a0.Parent = vr
		local a1 = Instance.new("Attachment")
		a1.Parent = root
		local ap = Instance.new("AlignPosition")
		ap.Attachment0 = a0
		ap.Attachment1 = a1
		ap.RigidityEnabled = true
		ap.Parent = vr
		if vh then
			vh.PlatformStand = true
		end
		Kit.fx({ id = "RecTwirl", a = attacker, v = victim, dur = cfg.TwirlTime })
		local t0 = os.clock()
		while os.clock() - t0 < cfg.TwirlTime and root.Parent and vr.Parent do
			local k = (os.clock() - t0) / cfg.TwirlTime
			local ang = k * math.pi * 2
			a1.Position = Vector3.new(math.sin(ang) * 4.5, 1.5 + math.sin(k * math.pi) * 2, -math.cos(ang) * 4.5)
			game:GetService("RunService").Heartbeat:Wait()
		end
		ap:Destroy()
		a0:Destroy()
		a1:Destroy()
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) then
			api.hit(attacker, victim, cfg, api.flat(root.CFrame.LookVector, dir))
		end
		task.delay(0.6, function()
			if vh and vh.Parent and vh.Health > 0 and not api.CharacterState.isStunned(victim) then
				vh.PlatformStand = false
			end
		end)
	end,

	-- Service Bell : sonnette géante, DING qui étourdit tout le monde autour
	RecBell = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		Kit.fx({ id = "Telegraph", p = Kit.ground(root.Position), r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "RecBellFX", a = attacker, p = Kit.ground(root.Position + look * 2.6), fall = cfg.Windup, r = cfg.Radius })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local center = root.Position
		for _, v in ipairs(Kit.inCircle(attacker, center, cfg.Radius, 8)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, look))
		end
	end,

	-- Visitor Badge : badge en boomerang (touche une fois à l'aller, une fois au retour)
	RecBadge = function(attacker, cfg, aim, api)
		task.wait(0.2)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local start = root.Position + Vector3.new(0, 1, 0) + dir * 2
		local far = Kit.safePoint(start, start + dir * cfg.Range, 1.5)
		local outT = math.max((far - start).Magnitude / cfg.Speed, 0.12)
		local part = Kit.sPart({ Name = "Projectile", Size = Vector3.new(1.5, 0.15, 2.0), Color = WHITE, CFrame = CFrame.new(start) })
		decor(part, Vector3.new(1.52, 0.17, 0.5), CFrame.new(0, 0, -0.7), FUCHSIA)
		decor(part, Vector3.new(0.7, 0.17, 0.7), CFrame.new(0, 0, 0.25), BLUE)
		Kit.fx({ id = "RecLanyard", a = attacker, part = part })
		local hitOut, hitBack = {}, {}
		local t0 = os.clock()
		local last = start
		while part.Parent do
			local el = os.clock() - t0
			local pos, set
			if el < outT then
				local k = el / outT
				pos = start:Lerp(far, 1 - (1 - k) * (1 - k))
				set = hitOut
			else
				local r = Kit.root(attacker)
				if not r or not api.CharacterState.isAlive(attacker) then
					break
				end
				local k = math.clamp((el - outT) / outT, 0, 1)
				pos = far:Lerp(r.Position + Vector3.new(0, 1, 0), k * k)
				set = hitBack
				if k >= 1 then
					break
				end
			end
			local mv = pos - last
			last = pos
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, el * 22, 0)
			for _, v in ipairs(api.Hitbox.box(CFrame.new(pos), Vector3.new(4.5, 5, 4.5), attacker, 4)) do
				if not set[v] then
					set[v] = true
					api.hit(attacker, v, cfg, api.flat(mv.Magnitude > 0.01 and mv or dir, dir), { hitPos = pos })
				end
			end
			game:GetService("RunService").Heartbeat:Wait()
		end
		Kit.rawFX({ k = "ProjPop", p = part.Position, c = FUCHSIA })
		part:Destroy()
	end,

	-- Hold Music : haut-parleur posé à ses pieds, zone qui ralentit et pique
	RecMusic = function(attacker, cfg, aim, api)
		task.wait(0.18)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		local center = Kit.ground(root.Position + look * 2)
		Kit.fx({ id = "RecMusicFX", p = center, r = cfg.Radius, dur = cfg.MusicTime, look = look, a = attacker })
		local t0 = os.clock()
		local first = {}
		while os.clock() - t0 < cfg.MusicTime do
			for _, v in ipairs(Kit.inCircle(attacker, center, cfg.Radius, 7)) do
				local over = first[v] and { Words = { "ELEVATOR MUSIC!", "BEEP BOOP!" }, Power = 0.12 } or nil
				first[v] = true
				if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, look), over) == "Hit" then
					api.CharacterState.setSpeedMod(v, "RecHold", cfg.SlowMult, cfg.Tick + 0.35)
				end
			end
			task.wait(cfg.Tick)
		end
	end,

	-- Hang Up! : combiné géant qui s'abat sur une longue ligne devant elle : PLAQUE au sol
	RecHangUp = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.aimDir(attacker, aim)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		local start = Kit.ground(root.Position + look * 1.5)
		local far = Kit.safePoint(root.Position, root.Position + look * (cfg.Length + 1.5), 1)
		local length = math.clamp((Vector3.new(far.X, 0, far.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude, 6, cfg.Length)
		local cf = CFrame.lookAt(start, start + look)
		Kit.fx({ id = "RecHangFX", cf = cf, w = cfg.Width, l = length, fall = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		for _, v in ipairs(Kit.inRect(attacker, cf, cfg.Width, length, 8)) do
			api.hit(attacker, v, cfg, look)
		end
		api.ZoneService.shatterAround((cf * CFrame.new(0, 0, -length / 2)).Position, length * 0.4, Vector3.new(0, 30, 0))
	end,

	-- Transfer Call : échange de place avec la 1re cible devant (sinon petit saut en avant)
	RecTransfer = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		if victim then
			local vr = Kit.root(victim)
			local a, b = root.Position, vr.Position
			Kit.fx({ id = "RecSwap", a = attacker, v = victim, p1 = a, p2 = b })
			root.CFrame = CFrame.lookAt(b, b + Kit.flat(a - b))
			vr.CFrame = CFrame.lookAt(a, a + Kit.flat(b - a))
			task.wait(0.06)
			if api.CharacterState.isAlive(victim) then
				api.hit(attacker, victim, cfg, api.flat(a - b, dir))
			end
		else
			local dest = Kit.safePoint(root.Position, root.Position + dir * cfg.Blink, 2)
			Kit.fx({ id = "RecSwap", a = attacker, p1 = root.Position, p2 = dest })
			root.CFrame = CFrame.lookAt(dest, dest + dir)
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : badge VISITOR (+10 % de dégâts subis pendant 5 s)
------------------------------------------------------------------------
function M.ServerInit(api)
	local function now()
		return workspace:GetServerTimeNow()
	end
	-- bonus d'abord (le 1er coup qui pose le badge n'en profite pas)
	table.insert(api.CombatService.damageMods, function(p)
		if (p.damage or 0) > 0 and (p.victim:GetAttribute("RecVisitorUntil") or 0) > now() then
			p.damage *= 1.1
		end
	end)
	table.insert(api.CombatService.damageMods, function(p)
		local a = p.attacker
		if a and a ~= p.victim and (p.damage or 0) > 0 and a:GetAttribute("CharacterName") == "Receptionist" then
			p.victim:SetAttribute("RecVisitorUntil", now() + 5)
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local function note(pos, color, life, rise)
	local head = Kit.part({ Shape = BALL, Size = Vector3.new(0.7, 0.55, 0.55), Position = pos, Color = color })
	local stem = Kit.part({ Size = Vector3.new(0.12, 1.0, 0.12), CFrame = CFrame.new(pos + Vector3.new(0.3, 0.5, 0)), Color = color })
	local flag = Kit.part({ Size = Vector3.new(0.4, 0.12, 0.12), CFrame = CFrame.new(pos + Vector3.new(0.5, 0.95, 0)) * CFrame.Angles(0, 0, -0.5), Color = color })
	local sway = Kit.rng:NextNumber(-1.2, 1.2)
	for _, p in ipairs({ head, stem, flag }) do
		Kit.tween(p, life, { CFrame = p.CFrame + Vector3.new(sway, rise, 0), Transparency = 1 }, Enum.EasingStyle.Sine)
		game:GetService("Debris"):AddItem(p, life + 0.05)
	end
end

M.MoveFX = {
	HoldTheLine = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4, 0), "RING RING!", FUCHSIA, 2.2, 0.6, 1)
		end
	end,
	ServiceBell = function(c, d, api)
		task.delay(0.34, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.rings(c, 3, 13, BRASS, -2.4)
			end
		end)
	end,
	VisitorBadge = function(c, d, api)
		task.delay(0.2, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				api.CartoonFX.sparks(arm.Position - arm.CFrame.UpVector, 10, FUCHSIA)
			end
		end)
	end,
	HoldMusic = function(c, d, api)
		api.rings(c, 2, 6, PINKL, -2.6)
	end,
	HangUp = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "GOODBYE!", FUCHSIA, 2.6, 0.6, 1)
		end
	end,
	TransferCall = function(c, d, api)
		task.delay(0.12, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				api.CartoonFX.sparks(arm.Position - arm.CFrame.UpVector, 8, PINKL)
				api.CartoonFX.sound("UIClick", arm.Position, 1)
			end
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	-- fil de téléphone en spirale
	Kit.on("RecCordFX", function(d)
		Kit.rope(d.a, d.v, d.dir, d.range, d.dur, PHONE, 0.18, PHONE, Vector3.new(0.6, 0.6, 1.2), true)
		if d.v then
			task.delay(0.08, function()
				local vr = d.v:FindFirstChild("HumanoidRootPart")
				if vr then
					CartoonFX.word(vr.Position + Vector3.new(0, 2, 0), "PLEASE HOLD!", 0.8, "Light")
					CartoonFX.sparks(vr.Position, 12, FUCHSIA)
				end
			end)
		end
	end)

	-- tournoiement : anneau rose au sol + traînée derrière la victime
	Kit.on("RecTwirl", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			CartoonFX.sound("Whoosh", r.Position, 1.1)
			CartoonFX.shockwave(r.Position - Vector3.new(0, 2.7, 0), 6, FUCHSIA)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local b = Kit.part({ Shape = BALL, Size = Vector3.one * 1.6, Position = vr.Position, Color = PINKL, Transparency = 0.35 })
				Kit.tween(b, 0.3, { Size = Vector3.one * 0.4, Transparency = 1 })
				Debris:AddItem(b, 0.32)
				task.wait(0.025)
			end
		end)
	end)

	-- sonnette géante qui tombe devant elle, DING en anneaux
	Kit.on("RecBellFX", function(d)
		local dome = Kit.part({ Shape = BALL, Size = Vector3.new(4.2, 4.2, 4.2), CFrame = CFrame.new(d.p + Vector3.new(0, 12, 0)), Color = BRASS })
		local base = Kit.part({ Shape = CYL, Size = Vector3.new(0.7, 5.2, 5.2), CFrame = CFrame.new(d.p + Vector3.new(0, 10.4, 0)) * UP, Color = PHONE })
		local knob = Kit.part({ Shape = CYL, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(d.p + Vector3.new(0, 14.4, 0)) * UP, Color = BRASS })
		local parts = { dome, base, knob }
		for _, p in ipairs(parts) do
			Kit.tween(p, d.fall * 0.6, { CFrame = p.CFrame - Vector3.new(0, 10, 0) }, Enum.EasingStyle.Bounce)
		end
		task.delay(d.fall, function()
			CartoonFX.sound("Ding", d.p, 1.6)
			CartoonFX.sound("Clang", d.p, 0.8)
			Kit.tween(knob, 0.08, { CFrame = knob.CFrame - Vector3.new(0, 0.4, 0) })
			for i = 0, 2 do
				task.delay(i * 0.12, function()
					local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.3, 3, 3), CFrame = CFrame.new(d.p + Vector3.new(0, 1.5 + i * 0.8, 0)) * UP, Color = i % 2 == 0 and BRASS or FUCHSIA, Transparency = 0.15 })
					Kit.tween(ring, 0.45, { Size = Vector3.new(0.1, d.r * 2.1, d.r * 2.1), Transparency = 1 })
					Debris:AddItem(ring, 0.47)
				end)
			end
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r, BRASS)
			Kit.floatText(d.p + Vector3.new(0, 6, 0), "DING!", BRASS, 5, 0.9, 2)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.6)
				CartoonFX.fovKick(6)
			end
			task.delay(0.5, function()
				for _, p in ipairs(parts) do
					Kit.tween(p, 0.3, { Transparency = 1, Size = p.Size * 0.6 })
				end
			end)
		end)
		for _, p in ipairs(parts) do
			Debris:AddItem(p, d.fall + 0.85)
		end
	end)

	-- cordon du badge entre sa main et le badge en vol
	Kit.on("RecLanyard", function(d)
		local c, badge = d.a, d.part
		if not c or not badge then
			return
		end
		local line = Kit.part({ Size = Vector3.new(0.12, 0.12, 1), Color = BLUE })
		local conn
		local t0 = os.clock()
		conn = RunService.RenderStepped:Connect(function()
			local arm = c:FindFirstChild("Right Arm")
			if not badge.Parent or not arm or os.clock() - t0 > 3 then
				conn:Disconnect()
				line:Destroy()
				return
			end
			local from = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
			local to = badge.Position
			local len = math.max((to - from).Magnitude, 0.1)
			line.Size = Vector3.new(0.12, 0.12, len)
			line.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			if Kit.rng:NextNumber() < 0.3 then
				local s = Kit.part({ Size = Vector3.one * 0.35, CFrame = CFrame.new(to), Color = FUCHSIA })
				Kit.tween(s, 0.3, { Transparency = 1, Size = Vector3.one * 0.1 })
				Debris:AddItem(s, 0.32)
			end
		end)
	end)

	-- téléphone haut-parleur posé au sol : disque rose, notes de musique, ondes qui pulsent
	Kit.on("RecMusicFX", function(d)
		local look = d.look or Vector3.new(0, 0, -1)
		local base = CFrame.lookAt(d.p, d.p + look)
		local disc = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d.r * 2, d.r * 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.07, 0)) * UP, Color = PINKL, Transparency = 0.6 })
		local spk = Kit.part({ Size = Vector3.new(2.6, 0.9, 2.2), CFrame = base * CFrame.new(0, 0.45, 0), Color = PHONE })
		local grill = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 1.6, 1.6), CFrame = base * CFrame.new(0, 0.92, 0) * UP, Color = FUCHSIA })
		local led = Kit.part({ Shape = BALL, Size = Vector3.one * 0.4, CFrame = base * CFrame.new(0.9, 0.95, -0.8), Color = Color3.fromRGB(120, 255, 150) })
		local tag = Kit.part({ Size = Vector3.new(3.4, 0.9, 0.1), CFrame = base * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.pi, 0), Color = FUCHSIA })
		Kit.flatText(tag, "ON HOLD", WHITE, Enum.NormalId.Front)
		Kit.flatText(tag, "ON HOLD", WHITE, Enum.NormalId.Back)
		local parts = { disc, spk, grill, led, tag }
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r, FUCHSIA)
		Kit.floatText(d.p + Vector3.new(0, 5, 0), "YOUR CALL IS IMPORTANT TO US", PINKL, 4.5, 1.4, 1)
		task.spawn(function()
			local t0 = os.clock()
			local i = 0
			while os.clock() - t0 < d.dur do
				i += 1
				local a, rr = Kit.rng:NextNumber(0, math.pi * 2), Kit.rng:NextNumber(0, d.r)
				note(d.p + Vector3.new(math.cos(a) * rr, 1, math.sin(a) * rr), NOTES[Kit.rng:NextInteger(1, #NOTES)], 1.2, 3.5)
				if i % 8 == 0 then
					local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.2, 2, 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.3, 0)) * UP, Color = FUCHSIA, Transparency = 0.3 })
					Kit.tween(ring, 0.7, { Size = Vector3.new(0.1, d.r * 2, d.r * 2), Transparency = 1 })
					Debris:AddItem(ring, 0.72)
					Kit.tween(grill, 0.1, { Size = Vector3.new(0.1, 1.9, 1.9) })
					task.delay(0.1, function()
						Kit.tween(grill, 0.15, { Size = Vector3.new(0.1, 1.6, 1.6) })
					end)
				end
				task.wait(0.08)
			end
			for _, p in ipairs(parts) do
				Kit.tween(p, 0.3, { Transparency = 1 })
			end
			task.wait(0.32)
			for _, p in ipairs(parts) do
				p:Destroy()
			end
		end)
	end)

	-- combiné géant qui raccroche sur une longue ligne
	Kit.on("RecHangFX", function(d)
		Kit.rectTelegraph(d.cf, d.w, d.l, d.fall, d.a)
		local mid = d.cf * CFrame.new(0, 0, -d.l / 2)
		local L = d.l
		local handle = Kit.part({ Size = Vector3.new(d.w * 0.45, 1.6, L * 0.75), Color = PHONE })
		local cupA = Kit.part({ Size = Vector3.new(d.w * 0.85, 2.6, L * 0.2), Color = PHONE })
		local cupB = Kit.part({ Size = Vector3.new(d.w * 0.85, 2.6, L * 0.2), Color = PHONE })
		local stripe = Kit.part({ Size = Vector3.new(d.w * 0.47, 1.62, L * 0.3), Color = FUCHSIA })
		local parts = { handle, cupA, cupB, stripe }
		local offs = { CFrame.new(0, 2.2, 0), CFrame.new(0, 1.3, -L * 0.4), CFrame.new(0, 1.3, L * 0.4), CFrame.new(0, 2.2, 0) }
		local h = 40
		for i, p in ipairs(parts) do
			p.CFrame = mid * CFrame.new(0, h, 0) * CFrame.Angles(0.5, 0, 0) * offs[i]
			Kit.tween(p, d.fall, { CFrame = mid * offs[i] }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(d.fall, function()
			CartoonFX.sound("GroundSlam", mid.Position, 1.3)
			CartoonFX.sound("PlasticHit", mid.Position, 1)
			CartoonFX.bigImpact(mid.Position + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, FUCHSIA)
			for k = -1, 1 do
				CartoonFX.shockwave((mid * CFrame.new(0, 0.2, k * L * 0.33)).Position, d.w * 0.9, k == 0 and FUCHSIA or PINKL)
			end
			Kit.cubes(mid.Position + Vector3.new(0, 1, 0), 22, { PHONE, FUCHSIA, WHITE }, 0.8, 12, 0.6)
			Kit.floatText(mid.Position + Vector3.new(0, 5, 0), "*CLICK*", FUCHSIA, 4, 1, 2)
			if Kit.mine(d.a) then
				CartoonFX.shake(1)
				CartoonFX.impactFrame(0.8)
			end
			task.delay(0.55, function()
				for _, p in ipairs(parts) do
					Kit.tween(p, 0.3, { Transparency = 1 })
				end
			end)
		end)
		for _, p in ipairs(parts) do
			Debris:AddItem(p, d.fall + 0.9)
		end
	end)

	-- échange de place : ligne téléphonique rose entre les deux points, étincelles aux deux bouts
	Kit.on("RecSwap", function(d)
		local len = (d.p2 - d.p1).Magnitude
		local beam = Kit.part({ Size = Vector3.new(0.5, 0.5, math.max(len, 0.1)), CFrame = CFrame.lookAt(d.p1, d.p2) * CFrame.new(0, 0, -len / 2), Color = FUCHSIA, Transparency = 0.1 })
		Kit.tween(beam, 0.35, { Size = Vector3.new(0.05, 0.05, math.max(len, 0.1)), Transparency = 1 })
		Debris:AddItem(beam, 0.37)
		for _, p in ipairs({ d.p1, d.p2 }) do
			CartoonFX.sparks(p, 16, PINKL)
			CartoonFX.puff(p, 1)
			local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 2), Color = FUCHSIA, Transparency = 0.2 })
			Kit.tween(ring, 0.3, { Size = Vector3.new(0.1, 8, 8), Transparency = 1 })
			Debris:AddItem(ring, 0.32)
		end
		CartoonFX.sound("Electric", d.p1, 0.9)
		if d.v then
			Kit.floatText(d.p1 + Vector3.new(0, 3.5, 0), "TRANSFERRING...", PINKL, 3, 0.9, 1.5)
		end
	end)

	-- badges VISITOR au-dessus des têtes + aura de transformation (« RING! », panneau CLOSED qui clignote)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			local now = workspace:GetServerTimeNow()
			for _, c in ipairs(api.Hitbox.characters()) do
				local head = c:FindFirstChild("Head")
				if head then
					local visitor = (c:GetAttribute("RecVisitorUntil") or 0) > now
					local has = head:FindFirstChild("RecVisitor") ~= nil
					if visitor and not has then
						Kit.mark(c, "RecVisitor", "VISITOR", FUCHSIA)
					elseif not visitor and has then
						Kit.mark(c, "RecVisitor", nil)
					end
				end
				if c:GetAttribute("CharacterName") == "Receptionist" and c:GetAttribute("Transformed") then
					local fx = c:FindFirstChild("TransformFX")
					local sign = fx and fx:FindFirstChild("ClosedSign")
					if sign then
						sign.LocalTransparencyModifier = (tick % 2 == 0) and 0 or 0.5
					end
					local r = c:FindFirstChild("HumanoidRootPart")
					if r and tick % 3 == 0 then
						local off = Vector3.new(Kit.rng:NextNumber(-2.5, 2.5), Kit.rng:NextNumber(0, 2), Kit.rng:NextNumber(-2.5, 2.5))
						Kit.floatText(r.Position + off, "RING!", PINKL, 1.4, 0.7, 1.5)
					end
				end
			end
		end
	end)
end

return M
