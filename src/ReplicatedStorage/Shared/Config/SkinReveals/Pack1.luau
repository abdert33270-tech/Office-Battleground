--[[
	SkinReveals.Pack1 (agent reveal1) — chorégraphies de révélation des skins Rare / Epic / Legendary de
	Intern, Janitor, LunchLady et SecurityGuard. API : en-tête de Controllers.SkinRevealController (REVEAL_API).
	Repère LOCAL de la scène : sol y = 0, marque du héros CF(0, 3, 0), le héros regarde -Z,
	caméra par défaut côté -Z, +X = la droite du héros (à GAUCHE de l'écran).
	Chaque révélation a sa propre structure (entrée, action, langage caméra, fin) : pas de schéma commun.
]]
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local PI = math.pi
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local WHITE, BLACK = C3(255, 255, 255), C3(15, 15, 20)
local GOLD = C3(255, 200, 40)

-- repère du perso : position (x, z), lacet (0 = face caméra, PI/2 = regarde -X), hauteur de la racine
local function M(x, z, yaw, y)
	return CF(x, y or 3, z) * ANG(0, yaw or 0, 0)
end
local function lerp(a, b, t)
	return a + (b - a) * t
end
-- position locale d'une partie du rig (ou décalage dans son repère)
local function limb(R, name, off)
	local p = R.rig and R.rig:FindFirstChild(name)
	if not p then
		return V3(0, 4.5, 0)
	end
	return R.loc((p.CFrame * (off or CF())).Position)
end
-- pièce de skin générée (SkinAssets) portée par le rig, retrouvée par son MeshId
local function rigAsset(R, name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("SkinAssets")
	local src = folder and folder:FindFirstChild(name)
	if not (src and src:IsA("MeshPart")) or not R.rig then
		return nil
	end
	for _, d in ipairs(R.rig:GetDescendants()) do
		if d:IsA("MeshPart") and d.MeshId == src.MeshId then
			return d
		end
	end
	return nil
end
-- cylindre "Cyl" (axe X) orienté de a vers b (positions locales)
local function stretch(R, part, a, b, thick)
	local d = b - a
	local len = math.max(d.Magnitude, 0.05)
	part.Size = V3(len, thick, thick)
	part.CFrame = R.at(0, 0, 0) * (CFrame.lookAt((a + b) / 2, b) * ANG(0, PI / 2, 0))
end

local P = {}

------------------------------------------------------------------------
-- INTERN
------------------------------------------------------------------------
do
	local OR, CREAM, INK = C3(255, 145, 40), C3(240, 232, 210), C3(30, 30, 38)
	local FLIP = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 0.5 }, RJ = { ln = 0.08 }, RH = { p = 0.15 } },
		{ t = 0.2, RS = { p = 2.3, y = 0.2 }, RJ = { ln = -0.12 } },
		{ t = 0.55, RS = { p = 1.5 }, LS = { p = 0.2 }, RJ = { ln = -0.05 } },
	}

	-- Hypebeast Intern : unboxing d'une paire limitée -> il jaillit de la boîte, pile ou face, ajuste ses lunettes
	P.Intern_Rare = {
		Caption = "Limited drop. Unlimited ego.",
		Location = "Sneaker Drop - Lobby, 6:00 AM",
		Reveal = function(R)
			R.stage("Studio", { color = C3(36, 34, 46), floor = C3(52, 50, 64) })
			R.fx.dark(0.2)
			R.cyl(0.3, 10.8, V3(0, 0.15, 0), OR, "Neon")
			R.cyl(0.6, 10, V3(0, 0.45, 0), C3(245, 245, 245))
			-- boîte à baskets géante (creuse) posée sur le socle
			local front = R.box(V3(5.4, 3.4, 0.25), CF(0, 2.45, -2.2), OR)
			R.text(front, "LIMITED DROP", { Color = WHITE, Face = Enum.NormalId.Front })
			R.box(V3(5.42, 0.3, 0.27), CF(0, 1.15, -2.2), WHITE)
			R.box(V3(5.4, 3.4, 0.25), CF(0, 2.45, 2.2), OR)
			R.box(V3(0.25, 3.4, 4.4), CF(2.6, 2.45, 0), OR)
			R.box(V3(0.25, 3.4, 4.4), CF(-2.6, 2.45, 0), OR)
			local lid = R.box(V3(5.9, 0.6, 4.9), CF(0, 4.45, 0), INK)
			R.text(lid, "HYPE", { Color = OR, Face = Enum.NormalId.Front })
			R.light(V3(0, 9, -6), C3(255, 200, 150), 30, 1.5)
			R.mark(M(0, -5.5))
			R.place(M(0, 0, 0, 0.3))
			R.pose("Crouch")
			R.onSkip(function(R)
				R.show(lid, false)
				R.place(M(0, -5.5))
				R.pose("Shades")
				R.cam.cut(V3(2.5, 4.2, -14), V3(0, 3.8, -5.5), 50)
			end)
			R.cam.cut(V3(3, 1.6, -11), V3(0, 3, 0), 55)
			R.cam.move(V3(2, 2.2, -9), V3(0, 3.2, 0), 0.8, 55)
			-- la boîte tremble
			for i = 1, 3 do
				R.moveTo(lid, CF(0, 4.7, 0) * ANG(0, 0, (i % 2 == 0) and 0.07 or -0.07), 0.08, ES.Quad, ED.Out)
				R.sound("Thud", V3(0, 4, 0), 0.6, 0.9 + i * 0.1)
				R.wait(0.1)
				R.moveTo(lid, CF(0, 4.45, 0), 0.07)
				R.wait(0.09)
			end
			-- le couvercle explose, il surgit bras croisés
			R.jump(lid, CF(-7, 0.4, 6) * ANG(0.4, 1.2, 0.3), 0.8, 9)
			R.fx.confetti(V3(0, 4.5, 0), 50, { OR, CREAM, GOLD, WHITE }, 4, 14)
			R.fx.flash(C3(255, 230, 190), 0.03, 0.03, 0.2)
			R.sound("Boing", V3(0, 4, 0), 0.9)
			R.pose("ArmsCrossed")
			R.moveTo(R.rig, M(0, 0, 0, 3.7), 0.3, ES.Back, ED.Out)
			R.cam.punch(-8)
			R.fx.word("DROP!", V3(0, 8.5, 0), 1.2)
			R.wait(0.55)
			-- saut hors de la boîte, vers la caméra
			R.jump(R.rig, M(0, -5.5), 0.5, 3)
			R.cam.move(V3(2.5, 3.6, -14), V3(0, 3.8, -5.5), 0.55, 50)
			R.wait(0.55)
			R.fx.dust(V3(0, 0, -5.5), 3)
			-- pile ou face : la pièce monte, la caméra la suit, il la rattrape
			local hand = limb(R, "Right Arm", CF(0, -1, 0))
			local coin = R.prop("Coin", CF(hand))
			R.anim(FLIP)
			R.sound("Ding", hand, 0.5, 1.5)
			R.over(1.0, function(a)
				local h = math.sin(a * PI) * 9
				if coin and coin.Parent then
					coin:PivotTo(R.at(hand.X, hand.Y + h, hand.Z) * ANG(a * 30, 0, 0))
				end
			end)
			R.cam.track(1.0, function(a)
				local h = math.sin(a * PI) * 9
				return V3(2.5, 3.6 + h * 0.35, -14), V3(hand.X * 0.5, hand.Y + h * 0.85, hand.Z), 50
			end)
			R.wait(0.85)
			R.anim("Catch")
			R.wait(0.15)
			R.destroy(coin, "sparks")
			R.sound("Ding", hand, 0.8)
			R.pose("Shades")
			R.fx.twinkle(limb(R, "Head", CF(0.35, 0.1, -0.7)))
			R.fx.sparks(limb(R, "Head", CF(0, 0, -0.8)), 12, GOLD)
			R.cam.move(V3(2.2, 4.2, -12.5), V3(0, 4, -5.5), 0.6, 46)
			R.wait(0.45)
			R.title()
		end,
	}

	local G, K, HOLO = C3(80, 255, 120), C3(28, 30, 36), C3(15, 40, 25)
	local START = { RS = { p = -0.7 }, LS = { p = 0.9 }, RJ = { ln = 0.85 }, RH = { p = 1.3 }, LH = { p = -0.5 } }
	local SLIDE = { RS = { p = 3.0, r = 0.2 }, LS = { p = 0.4, r = 0.5 }, RJ = { ln = -0.35, sd = 0.1 }, RH = { p = 1.5 }, LH = { p = -1.3 } }
	local function corridor(R)
		R.floor(V3(110, 1, 24), CF(0, -0.5, 0), C3(70, 75, 92))
		R.box(V3(110, 15, 1), CF(0, 7.5, 9), C3(205, 210, 222))
		R.box(V3(110, 0.5, 0.3), CF(0, 1, 8.4), G, "Neon")
		R.box(V3(110, 1, 24), CF(0, 15, 0), C3(160, 165, 178))
		for x = -45, 45, 10 do
			R.box(V3(4, 0.3, 1.2), CF(x, 14.4, 1), WHITE, "Neon")
			R.box(V3(1.2, 15, 1.4), CF(x + 5, 7.5, 8.4), C3(175, 180, 195))
		end
		for _, z in ipairs({ -3.5, 3.5 }) do
			R.box(V3(110, 0.06, 0.25), CF(0, 0.03, z), WHITE)
		end
		R.light(V3(10, 12, -2), WHITE, 60, 1.2)
	end

	-- Speedrun Intern : départ 3-2-1, sprint chronométré + haie, glissade sous la ligne d'arrivée au ralenti
	P.Intern_Epic = {
		Caption = "Any% coffee run. Do not talk to him.",
		Location = "Floor 3 Hallway - Any% Category",
		Reveal = function(R)
			R.stage(corridor)
			-- ligne de départ + portique à 3 feux
			R.box(V3(0.5, 0.07, 7), CF(30.8, 0.04, 0), WHITE)
			for _, z in ipairs({ -3.6, 3.6 }) do
				R.box(V3(0.4, 8, 0.4), CF(28, 4, z), C3(60, 60, 70), "Metal")
			end
			R.box(V3(0.5, 0.6, 7.6), CF(28, 8, 0), C3(60, 60, 70), "Metal")
			local lights = {}
			for i, z in ipairs({ 1.4, 0, -1.4 }) do
				lights[i] = R.ball(0.9, V3(27.7, 7.3, z), C3(70, 20, 20))
			end
			-- chrono holographique
			local board = R.box(V3(11, 2.8, 0.2), CF(14, 8.2, 6.5), HOLO, "Glass", 0.25)
			local timer = R.text(board, "00:00.00", { Color = G, Face = Enum.NormalId.Front })
			R.box(V3(11.4, 0.15, 0.25), CF(14, 9.65, 6.5), G, "Neon")
			R.box(V3(11.4, 0.15, 0.25), CF(14, 6.75, 6.5), G, "Neon")
			-- haie (bureau) + pile de gobelets
			R.box(V3(1.6, 0.3, 5), CF(16, 2.55, 0), C3(150, 105, 65), "Wood")
			R.box(V3(1.4, 2.4, 0.3), CF(16, 1.2, -2.3), C3(120, 85, 55), "Wood")
			R.box(V3(1.4, 2.4, 0.3), CF(16, 1.2, 2.3), C3(120, 85, 55), "Wood")
			R.box(V3(1.6, 2.6, 1.6), CF(8, 1.3, -2.6), C3(190, 195, 205))
			local cups = {}
			for i = 1, 4 do
				cups[i] = R.cyl(0.75, 0.6, V3(8, 2.6 + i * 0.78 - 0.39, -2.6), i % 2 == 0 and C3(240, 240, 240) or C3(140, 90, 55))
			end
			-- arrivée : poteaux, banderole, ruban
			for _, z in ipairs({ -3.6, 3.6 }) do
				R.box(V3(0.4, 7, 0.4), CF(-2, 3.5, z), WHITE)
			end
			local fin = R.box(V3(0.3, 1.2, 7.6), CF(-2, 7.4, 0), BLACK)
			R.text(fin, "FINISH", { Color = WHITE, Face = Enum.NormalId.Right })
			R.text(fin, "FINISH", { Color = WHITE, Face = Enum.NormalId.Left })
			local tape = R.box(V3(0.15, 0.25, 7.2), CF(-2, 3.6, 0), WHITE, "Neon")
			R.mark(M(-8, 0, PI / 4, 2.2))
			R.place(M(30, 0, PI / 2))
			R.pose(START)
			R.onSkip(function(R)
				timer.Text = "00:59.99"
				timer.TextColor3 = GOLD
				R.show(tape, false)
				R.place(M(-8, 0, PI / 4, 2.2))
				R.pose(SLIDE)
				R.cam.cut(V3(-12.5, 2, -7), V3(-7.5, 2.6, 0), 55)
			end)
			-- départ
			R.cam.cut(V3(25, 1.5, -5.5), V3(29, 2.6, 0), 55)
			R.cam.move(V3(25.5, 1.8, -4.6), V3(29, 3, 0), 1.3, 50)
			for i = 1, 3 do
				R.wait(0.32)
				lights[i].Color = C3(255, 40, 40)
				lights[i].Material = Enum.Material.Neon
				R.sound("Ding", lights[i], 0.7, 0.8)
				R.fx.banner(tostring(4 - i), { color = C3(255, 60, 60), t = 0.28, size = 0.16, y = 0.25 })
			end
			R.wait(0.32)
			for _, l in ipairs(lights) do
				l.Color = G
			end
			R.sound("Whistle", nil, 0.8)
			R.fx.banner("GO!", { color = G, t = 0.45, size = 0.2, y = 0.25 })
			-- chrono qui défile
			local running = true
			local clock = 0
			R.every(0.03, function()
				if running then
					clock = math.min(clock + 1.05, 59.6)
					timer.Text = string.format("00:%05.2f", clock)
				end
			end)
			-- sprint en travelling latéral
			R.fx.speedLines(1.4, G)
			R.cam.track(1.4, function()
				local p = R.pos(R.rig)
				return V3(p.X + 2.5, 3.4, -11), V3(p.X - 2.5, 3, 0), 62
			end)
			R.wait(R.walk(M(20, 0, PI / 2), 0.42, "Run"))
			R.sound("Whoosh", R.pos(R.rig), 0.7)
			R.wait(R.jump(R.rig, M(12, 0, PI / 2), 0.42, 3.6))
			R.delay(0.1, function()
				for i, c in ipairs(cups) do
					R.jump(c, CF(5.5 - i * 1.4, 0.35, -5.5 - i * 0.8) * ANG(1.2, 0, i), 0.55, 2 + i)
				end
				R.sound("Clang", V3(8, 3, -2.6), 0.5, 1.4)
			end)
			R.wait(R.walk(M(1.5, 0, PI / 2), 0.38, "Run"))
			-- ligne d'arrivée : ruban qui casse, glissade à genoux au ralenti
			running = false
			timer.Text = "00:59.99"
			timer.TextColor3 = GOLD
			R.show(tape, false)
			local tA = R.box(V3(0.15, 0.25, 3.6), CF(-2, 3.6, -1.8), WHITE, "Neon")
			local tB = R.box(V3(0.15, 0.25, 3.6), CF(-2, 3.6, 1.8), WHITE, "Neon")
			R.moveTo(tA, CF(-6, 1.6, -4.5) * ANG(0, 0.9, 0.6), 0.6, ES.Quad, ED.Out)
			R.moveTo(tB, CF(-6, 1.6, 4.5) * ANG(0, -0.9, -0.6), 0.6, ES.Quad, ED.Out)
			R.slowmo(0.3, 0.9)
			R.fx.flash(WHITE, 0.03, 0.03, 0.25)
			R.sound("BigImpact", V3(-2, 3, 0), 0.6)
			R.pose(SLIDE)
			R.cam.cut(V3(-12.5, 1.8, -6.5), V3(-6, 2.6, 0), 62)
			R.fx.banner("WORLD RECORD!", { color = GOLD, t = 1.2, size = 0.15, y = 0.2 })
			R.over(0.9, function(a, e)
				R.place(M(lerp(1.5, -8, e), 0, lerp(PI / 2, PI / 4, e), lerp(3, 2.2, math.min(a * 4, 1))))
			end, ES.Quart, ED.Out)
			for k = 0, 4 do
				R.delay(k * 0.12, function()
					local p = R.pos(R.rig)
					R.fx.sparks(V3(p.X + 0.5, 0.2, p.Z), 6, G)
				end)
			end
			R.wait(0.9)
			R.fx.confetti(V3(-8, 7, 0), 45, { G, GOLD, WHITE }, 5, 6)
			R.sound("LevelUp", nil, 0.8)
			R.cam.move(V3(-11.5, 2.2, -6), V3(-7.8, 2.8, 0), 0.8, 52)
			R.wait(0.35)
			R.title()
		end,
	}

local PK, CYN = C3(255, 70, 190), C3(40, 230, 255)
	local TYPE = {}
	for i = 0, 7 do
		local s = (i % 2 == 0) and 1 or -1
		TYPE[#TYPE + 1] = { t = i * 0.1, RS = { p = 1.35 + 0.12 * s, r = -0.15 }, LS = { p = 1.35 - 0.12 * s, r = -0.15 }, RJ = { ln = 0.12 } }
	end
	local HEYCHAT = {}
	for i = 0, 6 do
		HEYCHAT[#HEYCHAT + 1] = { t = i * 0.16, RJ = { ln = 0.5 }, RS = { p = 1.2 }, LS = { p = 2.9, r = (i % 2 == 0) and 0.55 or 0.1 } }
	end
	local PUMP = {}
	for i = 0, 5 do
		PUMP[#PUMP + 1] = { t = i * 0.16, RS = { p = (i % 2 == 0) and 0.25 or 0.85, r = 0.1 }, LS = { p = 1.55, y = 0.1 }, RJ = { sd = -0.08, ln = (i % 2 == 0) and 0 or -0.08 } }
	end
	local CHAT = { "POG", "W STREAM", "LETS GOOO", "FIRST!", "GG", "<3 <3 <3", "CLIP IT", "HYPE", "LEGEND", "+1 SUB" }
	local DESK_TOP = CF(0, 6.05, -1.6)

	-- Livestream Legend : POV du drone qui décolle et vient le cadrer, la connexion saute, il tape sur le bureau,
	-- LIVE ! gros plan fish-eye « HEY CHAT! » au ralenti, il saute sur le bureau avec sa pancarte, le drone l'orbite
	P.Intern_Legendary = {
		Caption = "Smash that like button. Smash everything, actually.",
		Location = "Bedroom Studio - 2:00 AM",
		Reveal = function(R)
			R.stage("Room", { dark = true, color = C3(38, 30, 58), floor = C3(28, 26, 38), w = 28, d = 24, h = 13 })
			-- mur d'écrans derrière lui (son stream), bureau devant lui, ring light, néons
			R.box(V3(14, 0.3, 2), CF(0, 3.25, 4.4), C3(20, 20, 26))
			local mons, labels = {}, {}
			for i, x in ipairs({ -4.3, 0, 4.3 }) do
				mons[i], labels[i] = R.prop("Monitor", CF(x, 3.4, 4.4) * ANG(0, (i - 2) * 0.2, 0), { text = "OFFLINE" })
			end
			for i, y in ipairs({ 8.5, 10.5 }) do
				R.box(V3(28, 0.25, 0.25), CF(0, y, 11), i == 1 and PK or CYN, "Neon")
			end
			R.box(V3(7, 0.3, 2.4), CF(0, 2.9, -1.6), C3(20, 20, 26))
			R.box(V3(7, 0.12, 0.12), CF(0, 2.8, -2.8), PK, "Neon")
			R.box(V3(0.3, 2.75, 2.2), CF(-3.3, 1.38, -1.6), C3(20, 20, 26))
			R.box(V3(0.3, 2.75, 2.2), CF(3.3, 1.38, -1.6), C3(20, 20, 26))
			R.box(V3(2.8, 0.14, 0.9), CF(0, 3.12, -1.3), C3(30, 30, 38))
			R.box(V3(2.8, 0.05, 0.06), CF(0, 3.2, -1.76), CYN, "Neon")
			local keys = {}
			for i = 1, 6 do
				keys[i] = R.box(V3(0.32, 0.12, 0.32), CF(-1.0 + (i - 1) * 0.4, 3.24, -1.3), ({ PK, CYN, WHITE })[i % 3 + 1], "Neon")
			end
			R.prop("RingLight", CF(6.2, 0, 3.4) * ANG(0, -0.6, 0))
			R.light(V3(0, 6, 3), PK, 18, 1.5)
			R.light(V3(-4, 6, -4), CYN, 18, 1.2)
			R.box(V3(3, 0.3, 2), CF(-6, 3.2, -4.5), C3(50, 40, 70))
			local drone = R.mesh("Intern_Legendary_Drone", CF(-6, 3.75, -4.5), 1.6) or R.prop("Drone", CF(-6, 3.75, -4.5))
			R.show(drone, false)
			R.prop("GamingChair", CF(0, 0, 1.1), { color = C3(30, 30, 36), accent = PK })
			R.place(CF(0, 3.45, 1.15))
			R.pose("Sit")
			R.anim(TYPE)
			local viewers = R.billboard("0 watching", V3(-5.2, 9.2, 4), { size = 1.4, Color = WHITE })
			R.mark(DESK_TOP)
			R.onSkip(function(R)
				for _, l in ipairs(labels) do
					if l then
						l.Text = "♥ LIVE ♥"
					end
				end
				R.place(DESK_TOP)
				R.pose("Point")
				R.show(drone, true)
				drone:PivotTo(R.at(-3, 7.5, -5) * ANG(0, -0.6, 0))
				viewers.Label.Text = "99.9K watching"
				R.cam.cut(V3(2, 3, -11), V3(0, 6.2, -1.6), 55)
			end)
			local screenCol = { C3(20, 24, 40), C3(20, 24, 40), C3(20, 24, 40) }
			R.every(0.14, function(i)
				for k, m in ipairs(mons) do
					local scr = m:FindFirstChild("Screen")
					if scr then
						scr.Color = screenCol[k]:Lerp(WHITE, (i + k) % 3 == 0 and 0.15 or 0)
					end
				end
			end)
			-- 1. POV du drone : il décolle de l'étagère et vient cadrer le streamer qui tape au clavier
			R.caption("● REC")
			R.sound("Electric", nil, 0.3, 1.8)
			R.cam.track(1.7, function(a, el)
				local e = a * a * (3 - 2 * a)
				local p = V3(lerp(-6, 0.3, e), lerp(3.9, 5.3, e) + math.sin(el * 9) * 0.08, lerp(-4.6, -6.4, e))
				return p, V3(lerp(-6, 0, e), lerp(3.8, 4.6, e), lerp(-2, 1, e)), 85
			end)
			R.wait(0.8)
			R.sound("Whoosh", nil, 0.5)
			R.wait(0.9)
			-- 2. la connexion saute ; il tape sur le bureau, les touches volent, le stream démarre
			R.show(drone, true)
			drone:PivotTo(CFrame.lookAt(R.wp(0.3, 5.3, -6.4), R.wp(0, 4.6, 1)))
			local bob = true
			R.over(4, function()
				if bob and drone.Parent then
					drone:PivotTo(CFrame.lookAt(R.wp(0.3, 5.3 + math.sin(os.clock() * 4) * 0.12, -6.4), R.wp(0, 4.6, 1)))
				end
			end)
			R.cam.cut(V3(-5.5, 5.6, -9.5), V3(0, 4.5, 0), 50)
			for k, l in ipairs(labels) do
				if l then
					l.Text = "CONNECTION LOST"
				end
				screenCol[k] = C3(150, 20, 30)
			end
			R.fx.glitch()
			R.sound("Electric", nil, 0.6, 0.6)
			R.wait(0.35)
			R.anim("Slam")
			R.wait(0.3)
			R.cam.shake(0.45)
			R.sound("Bonk", V3(0, 3, -1.3), 0.9)
			R.fx.word("BONK!", V3(0, 6.5, -1.5), 0.9)
			for i, kpart in ipairs(keys) do
				R.jump(kpart, CF(-2.5 + i * 0.8, 3.24, -1.3 + R.rand(-0.6, 0.4)) * ANG(R.rand(0, 3), R.rand(0, 3), 0), 0.45, 1.5 + i * 0.2)
			end
			R.wait(0.25)
			for k, l in ipairs(labels) do
				if l then
					l.Text = "● LIVE"
				end
				screenCol[k] = ({ PK, CYN, C3(140, 80, 255) })[k]
			end
			R.caption("● LIVE")
			R.fx.flash(PK, 0.03, 0.05, 0.25)
			R.sound("PowerUp", nil, 0.8)
			R.wait(0.3)
			-- 3. gros plan fish-eye dans l'objectif du drone, au ralenti : « HEY CHAT! »
			R.slowmo(0.4, 1.1)
			R.anim(HEYCHAT)
			R.cam.cut(V3(0.25, 5.1, -4.6), V3(0, 4.9, 0.5), 92)
			R.cam.move(V3(0.2, 5.0, -3.4), V3(0, 4.8, 0.5), 1.0, 96)
			R.fx.word("HEY CHAT!", V3(1.5, 6.8, -1), 1.2)
			R.fx.hearts(V3(0, 6, -1.5), 12, PK)
			R.sound("Ding", nil, 0.7, 1.3)
			R.wait(1.0)
			-- 4. le chat explose ; il saute debout sur le bureau, pancarte SUBSCRIBE au poing
			R.over(1.5, function(_, e)
				viewers.Label.Text = string.format("%.1fK watching", e * 99.9)
			end, ES.Quad, ED.In)
			for i, m in ipairs(mons) do
				if labels[i] then
					labels[i].Text = "♥ ♥ ♥"
				end
				R.fx.hearts(R.pos(m) + V3(0, 2.6, -0.4), 10, i == 2 and CYN or PK)
			end
			for i = 1, 9 do
				R.delay(i * 0.13, function()
					R.billboard(R.choose(CHAT), V3(R.rand(-7, 7), R.rand(6, 10), R.rand(1, 7)), { size = 0.8, Color = R.choose({ PK, CYN, WHITE }) })
				end)
			end
			R.cam.cut(V3(1.5, 2.4, -10.5), V3(0, 5.8, -1.6), 60)
			R.jump(R.rig, DESK_TOP, 0.55, 2.5)
			R.wait(0.55)
			R.fx.shockwave(V3(0, 3.1, -1.6), 6, CYN)
			R.anim(PUMP)
			R.fx.confetti(V3(0, 10, -1.6), 60, { PK, CYN, WHITE }, 6, 4)
			for k = 0, 2 do
				R.delay(k * 0.15, function()
					R.sound("Ding", nil, 0.6, 1.6)
				end)
			end
			R.wait(0.85)
			-- 5. le drone filme en orbite, il pointe la caméra
			R.pose("Point")
			R.fx.rays(PK, V3(0, 6, 0))
			R.fx.word("SMASH THAT LIKE!", V3(0, 10.5, -1.6), 1.2)
			R.cam.orbit(V3(0, 6.6, -1.6), 10, 0.2, -0.9, 0.35, 1.6, 58, 48)
			bob = false
			local d0 = R.pos(drone)
			R.over(1.4, function(_, e)
				local ang = lerp(-2.4, -0.6, e)
				local tgt = V3(math.sin(ang) * 3.4, 8.6, -1.6 - math.cos(ang) * 3.4)
				local p = d0:Lerp(tgt, math.min(e * 2, 1))
				if drone.Parent then
					drone:PivotTo(CFrame.lookAt(R.wp(p.X, p.Y, p.Z), R.wp(0, 7, -1.6)))
				end
			end)
			R.wait(1.1)
			R.title()
		end,
	}
end

-----------------------------------------------------------------------
-- JANITOR
------------------------------------------------------------------------
do
	local PUR, PNKL, CY = C3(150, 60, 220), C3(255, 90, 200), C3(40, 230, 255)
	local DISCO = { C3(255, 90, 200), C3(150, 60, 220), C3(40, 230, 255), C3(255, 210, 60), C3(80, 255, 120) }
	local MOON = {}
	for i = 0, 8 do
		local s = (i % 2 == 0) and 1 or -1
		MOON[#MOON + 1] = { t = i * 0.19, RH = { p = 0.4 * s }, LH = { p = -0.4 * s }, RJ = { ln = -0.1, sd = 0.07 * s }, RS = { p = 0.55, y = 0.3 }, LS = { p = 0.9, r = 0.5 } }
	end
	local POINT = { RS = { p = 2.75, r = 0.55 }, LS = { p = -0.25, r = 0.35, y = -0.5 }, RJ = { sd = -0.22, tw = -0.15 }, RH = { r = 0.25, p = 0.05 }, LH = { p = 0.35, r = -0.1 } }

	-- Disco Custodian : il entre en moonwalk en passant la serpillière, chaque dalle s'allume, la boule descend
	P.Janitor_Rare = {
		Caption = "Mops the floor. Then owns the dance floor.",
		Location = "Lobby - After Hours",
		Reveal = function(R)
			R.stage("Void")
			local tiles = {}
			for ix = -4, 4 do
				for iz = -3, 3 do
					tiles[#tiles + 1] = R.box(V3(2.9, 0.2, 2.9), CF(ix * 3, 0.1, iz * 3), C3(28, 26, 38), "Glass")
				end
			end
			local function lightTile(t, c)
				t.Color = c
				t.Material = Enum.Material.Neon
			end
			local ball = R.ball(2.6, V3(0, 19, 0), C3(225, 225, 240), "Foil")
			ball.Reflectance = 0.5
			local chain = R.box(V3(0.12, 10, 0.12), CF(0, 25, 0), C3(200, 205, 215), "Metal")
			R.light(ball, PNKL, 34, 2.5)
			R.hold("Mop")
			R.place(M(12, 0, -PI / 2))
			R.onSkip(function(R)
				for i, t in ipairs(tiles) do
					lightTile(t, DISCO[i % #DISCO + 1])
				end
				ball.CFrame = R.at(0, 10, 0)
				chain.CFrame = R.at(0, 16, 0)
				R.place(M(0, 0))
				R.pose(POINT)
				R.cam.cut(V3(-4, 3, -10), V3(0, 4, 0), 50)
			end)
			-- 1. moonwalk + serpillière : les dalles s'allument sous ses pas
			R.anim(MOON)
			R.sound("Squeak", nil, 0.5)
			R.over(1.7, function(_, e)
				local x = lerp(12, 0, e)
				R.place(M(x, 0, -PI / 2))
				for _, t in ipairs(tiles) do
					if t.Material ~= Enum.Material.Neon then
						local tp = R.loc(t.Position)
						if math.abs(tp.X - x) < 1.6 and math.abs(tp.Z) < 4.6 then
							lightTile(t, R.choose(DISCO))
						end
					end
				end
			end, ES.Linear)
			R.cam.track(2.1, function()
				local p = R.pos(R.rig)
				return V3(p.X - 1.5, 1.6, -9.5), V3(p.X, 3.4, 0), 55
			end)
			R.wait(0.9)
			-- la boule à facettes tombe du plafond
			R.moveTo(ball, CF(0, 10, 0), 0.7, ES.Bounce, ED.Out)
			R.moveTo(chain, CF(0, 16, 0), 0.7, ES.Bounce, ED.Out)
			R.spin(ball, 5, 4)
			R.sound("Whoosh", nil, 0.6, 0.7)
			local beams = false
			R.delay(0.5, function()
				beams = true
			end)
			R.every(0.16, function()
				if beams then
					local p = R.pos(ball)
					R.fx.beam(p, V3(R.rand(-11, 11), 0.2, R.rand(-8, 8)), 0.35, R.choose(DISCO), 0.22)
				end
			end)
			R.wait(0.8)
			-- 2. demi-tour dansé puis LA pose disco, caméra qui tourne
			R.over(0.35, function(_, e)
				R.place(M(0, 0, lerp(-PI / 2, -2 * PI, e)))
			end, ES.Quad, ED.Out)
			R.wait(0.35)
			R.pose(POINT)
			R.sound("PowerUp", nil, 0.7)
			R.fx.word("GROOVY!", V3(1.5, 8.5, 0), 1.1)
			R.fx.sparks(limb(R, "Right Arm", CF(0, -1, 0)), 14, GOLD)
			R.every(0.2, function()
				for _ = 1, 8 do
					lightTile(R.choose(tiles), R.choose(DISCO))
				end
			end)
			R.cam.orbit(V3(0, 3.6, 0), 10, 0.8, 0.75, -0.35, 1.5, 55, 47)
			R.wait(0.9)
			R.title()
		end,
	}

	local YEL, WATER, GRIME = C3(255, 205, 40), C3(130, 225, 255), C3(92, 68, 44)
	local AIM = { RS = { p = -0.3, y = 0.1 }, LS = { p = 0.5, y = 0.7, r = -0.15 }, RJ = { ln = 0.3 }, RH = { p = 0.35 }, LH = { p = -0.25 } }
	local SWEEP = {}
	for i = 0, 6 do
		SWEEP[#SWEEP + 1] = { t = i * 0.2, RS = { p = -0.3 }, LS = { p = 0.5, y = 0.7, r = -0.15 }, RJ = { ln = 0.3, tw = (i % 2 == 0) and 0.4 or -0.4 }, RH = { p = 0.35 }, LH = { p = -0.25 } }
	end
	local SKY = { RS = { p = 1.6, r = 0.1 }, LS = { p = 1.2, y = 0.3 }, RJ = { ln = -0.18 }, RH = { p = 0.2 }, LH = { p = -0.2 } }
	local THUMB = { RS = { p = 2.5, y = 0.6, r = 0.35 }, LS = { p = 1.45, y = -0.4, r = 0.25 }, RJ = { sd = 0.1, tw = 0.15 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
	local RAINBOW = { C3(255, 70, 70), C3(255, 160, 50), C3(255, 235, 70), C3(90, 230, 110), C3(70, 160, 255), C3(170, 100, 255) }

	-- bande de crasse qui se décape du bord +X vers -X ; renvoie le point de contact (local) courant
	local function peel(R, strip, t)
		local s, c = strip.Size, R.loc(strip.Position)
		local edge = V3(c.X + s.X / 2, 0.2, c.Z)
		R.over(t, function(a)
			local w = s.X * (1 - a)
			edge = V3(c.X - s.X / 2 + w, 0.2, c.Z)
			if w < 0.03 then
				strip.Transparency = 1
				return
			end
			strip.Size = V3(w, s.Y, s.Z)
			strip.CFrame = R.at(c.X - s.X / 2 + w / 2, c.Y, c.Z)
		end, ES.Linear)
		return function()
			return edge
		end
	end

	-- Pressure Wash Pro : vidéo « satisfaisante » vue de dessus, recul qui le révèle, panneau décapé, fontaine + arc-en-ciel
	P.Janitor_Epic = {
		Caption = "10 million views of one very clean carpet.",
		Location = "Episode 412: The Break Room Carpet",
		Reveal = function(R)
			R.stage("Studio", { color = C3(195, 205, 215), floor = C3(150, 156, 168) })
			local strips = {}
			for i = 0, 7 do
				local z = -3 - i * 2
				R.box(V3(16, 0.1, 2), CF(0, 0.05, z), i % 2 == 0 and C3(240, 245, 250) or C3(120, 190, 255))
				strips[#strips + 1] = R.box(V3(16, 0.18, 2.04), CF(0, 0.14, z), i % 3 == 0 and GRIME or C3(80, 60, 40), "Concrete")
			end
			-- panneau crasseux à décaper
			R.box(V3(0.3, 2.4, 0.3), CF(-6.5, 1.2, -4.2), C3(90, 90, 100), "Metal")
			local sign = R.box(V3(4.4, 2.4, 0.25), CF(-6.5, 3.4, -4.2), WHITE)
			R.text(sign, "▶ 10M VIEWS", { Color = C3(230, 40, 40), Face = Enum.NormalId.Front })
			local dirt = R.box(V3(4.5, 2.5, 0.12), CF(-6.5, 3.4, -4.4), GRIME, "Concrete")
			local jet = R.box(V3(1, 0.4, 0.4), CF(0, -10, 0), WATER, "Neon", 0.3, "Cyl")
			R.mark(M(0, 0))
			R.place(M(0, 0))
			R.pose(AIM)
			local bands = {}
			R.onSkip(function(R)
				for _, s in ipairs(strips) do
					s.Transparency = 1
				end
				dirt.Transparency = 1
				jet.Transparency = 1
				for _, b in ipairs(bands) do
					b.Transparency = 0.35
				end
				R.place(M(0, 0))
				R.pose(THUMB)
				R.cam.cut(V3(3, 2, -11), V3(0, 4.5, 0), 55)
			end)
			-- 1. vue de dessus : le jet décape trois bandes, bien droites
			R.caption("oddly satisfying  ▶ 9,999,812 views")
			R.cam.cut(V3(0, 15, -9.2), V3(0, 0, -9), 55)
			for k, idx in ipairs({ 3, 4, 5 }) do
				local edge = peel(R, strips[idx], 0.55)
				R.sound("Spray", nil, 0.6)
				local f = 0
				R.over(0.55, function()
					local e = edge()
					stretch(R, jet, e + V3(5, 11, -6), e, 0.4)
					f += 1
					if f % 5 == 0 then
						R.fx.smoke(e, 1, C3(220, 245, 255), 0.35)
					end
				end)
				R.wait(0.58)
				if k == 3 then
					jet.Transparency = 1
				end
			end
			-- 2. recul : on le découvre, lance au poing, il balaie le reste
			R.cam.move(V3(-5, 6.5, -17), V3(0, 2, -5), 1.0, 55)
			R.anim(SWEEP)
			R.sound("Spray", nil, 0.7)
			for k, idx in ipairs({ 2, 6, 1, 7, 8 }) do
				R.delay(k * 0.13, function()
					local edge = peel(R, strips[idx], 0.55)
					local f = 0
					R.over(0.55, function()
						f += 1
						if f % 6 == 0 then
							R.fx.smoke(edge(), 1, C3(220, 245, 255), 0.35)
						end
					end)
				end)
			end
			R.wait(1.2)
			R.face(V3(-6.5, 3, -4.2), 0.2)
			R.pose(AIM)
			R.cam.move(V3(-2.5, 4.2, -11), V3(-4.5, 3.3, -3), 0.4, 50)
			R.wait(0.2)
			local s0, c0 = dirt.Size, R.loc(dirt.Position)
			R.over(0.45, function(a)
				local h = s0.Y * (1 - a)
				dirt.Size = V3(s0.X, math.max(h, 0.02), s0.Z)
				dirt.CFrame = R.at(c0.X, c0.Y - s0.Y / 2 + h / 2, c0.Z)
				if math.random() < 0.2 then
					R.fx.smoke(V3(c0.X, c0.Y - s0.Y / 2 + h, c0.Z - 0.3), 1, C3(220, 245, 255), 0.35)
				end
			end, ES.Linear)
			R.wait(0.45)
			dirt.Transparency = 1
			R.sound("Ding", sign, 0.8)
			R.fx.twinkle(V3(-6.5, 4.2, -4.5))
			R.fx.sparks(V3(-6.5, 3.4, -4.5), 12, GOLD)
			R.wait(0.25)
			-- 3. jet vers le ciel : pluie fine, arc-en-ciel derrière lui, pouce levé
			R.face(V3(0, 3, -10), 0.2)
			R.pose(SKY)
			R.sound("Water", nil, 0.8)
			local hand = limb(R, "Right Arm", CF(0, -1, 0))
			local fountain = R.box(V3(1, 0.7, 0.7), CF(0, -10, 0), WATER, "Neon", 0.35, "Cyl")
			R.over(0.4, function(_, e)
				stretch(R, fountain, hand + V3(0, 1.4, 0), hand + V3(0, 1.4 + 14 * e, 0), 0.7)
			end)
			R.fx.rain({ Colors = { WATER, WHITE }, Size = V3(0.3, 0.5, 0.3), Shape = "Ball", Material = "Glass", Count = 50, Slow = true }, 1.6)
			for b, col in ipairs(RAINBOW) do
				local rad = 11 - b * 0.6
				for s = 0, 13 do
					local a0 = PI * s / 14
					local a1 = PI * (s + 1) / 14
					local p0 = V3(math.cos(a0) * rad, math.sin(a0) * rad, 7)
					local p1 = V3(math.cos(a1) * rad, math.sin(a1) * rad, 7)
					local seg = R.box(V3(1, 0.62, 0.2), CF(0, -10, 0), col, "Neon", 1)
					seg.CFrame = R.at(0, 0, 0) * (CFrame.lookAt((p0 + p1) / 2, p1) * ANG(0, PI / 2, 0))
					seg.Size = V3((p1 - p0).Magnitude + 0.08, 0.62, 0.2)
					bands[#bands + 1] = seg
					R.delay(0.25 + s * 0.03, function()
						R.tween(seg, 0.4, { Transparency = 0.35 })
					end)
				end
			end
			R.cam.move(V3(2.5, 1.6, -12), V3(0, 5, 0), 1.0, 60)
			R.wait(0.9)
			R.destroy(fountain, "puff")
			R.pose(THUMB)
			R.fx.word("SO CLEAN!", V3(0, 8, 0), 1)
			R.sound("Ding", nil, 0.6, 1.3)
			R.wait(0.5)
			R.title()
		end,
	}

	local BUB, VEL = C3(150, 225, 255), C3(150, 30, 70)
	local CURL = { RS = { p = 0.9, y = 0.6 }, LS = { p = 0.9, y = 0.6 }, RJ = { ln = 0.35 }, RH = { p = 1.45, r = 0.35 }, LH = { p = 1.45, r = 0.35 } }
	local POKE = {
		{ t = 0, LS = { p = 1.0 }, RJ = { ln = 0.1 } },
		{ t = 0.2, LS = { p = 0.6 }, RJ = { ln = 0.2, tw = 0.2 } },
		{ t = 0.32, LS = { p = 2.4 }, RJ = { ln = -0.15, tw = -0.2 } },
		{ t = 0.7, LS = { p = 2.2 }, RJ = { ln = -0.1 } },
	}
	local EMPEROR = { LS = { p = 3.05, r = 0.12 }, RS = { p = 0.8, r = 0.55, y = -0.3 }, RJ = { ln = -0.12, sd = 0.05 }, RH = { p = 0.1, r = 0.08 }, LH = { p = -0.1, r = 0.08 } }

	-- Bubble Emperor : procession dans une bulle géante, éclatement au ralenti sur le trône, couronnement
	P.Janitor_Legendary = {
		Caption = "Long live the spotless empire. Kneel before the mop.",
		Location = "The Spotless Palace - Throne Room",
		Reveal = function(R)
			R.stage(function(R)
				R.floor(V3(40, 1, 70), CF(0, -0.5, -15), C3(225, 235, 245), "Marble")
				R.box(V3(6, 0.1, 44), CF(0, 0.05, -20), C3(170, 25, 50), "Fabric")
				R.box(V3(6.6, 0.08, 44), CF(0, 0.03, -20), GOLD, "Metal")
				R.box(V3(40, 24, 1), CF(0, 12, 6), C3(60, 100, 190))
				for z = -40, 0, 8 do
					for _, x in ipairs({ -8, 8 }) do
						R.cyl(14, 1.8, V3(x, 7, z), C3(240, 240, 248), "Marble")
						R.cyl(0.6, 2.4, V3(x, 14.3, z), GOLD, "Metal")
						local ban = R.box(V3(1.6, 4, 0.1), CF(x, 10, z - 1), C3(45, 90, 200), "Fabric")
						R.text(ban, "♛", { Color = GOLD, Face = Enum.NormalId.Front })
					end
				end
				R.light(V3(0, 12, -6), C3(200, 230, 255), 50, 1.5)
			end)
			-- trône
			R.box(V3(4.4, 1.6, 3), CF(0, 0.8, 2.2), GOLD, "Metal")
			R.box(V3(3.8, 0.4, 2.6), CF(0, 1.8, 2.1), VEL, "Fabric")
			R.box(V3(4.4, 7, 0.8), CF(0, 4.5, 3.6), VEL, "Fabric")
			R.box(V3(4.8, 0.6, 1), CF(0, 8.1, 3.6), GOLD, "Metal")
			R.ball(1.2, V3(0, 8.8, 3.6), BUB, "Glass", 0.2)
			for _, x in ipairs({ -2.4, 2.4 }) do
				R.box(V3(0.5, 1.6, 3), CF(x, 2.4, 2.2), GOLD, "Metal")
			end
			local crownRig = rigAsset(R, "Janitor_Legendary_Crown")
			if crownRig then
				R.show(crownRig, false)
			end
			local bubble = R.ball(7, V3(0, 3, 0), BUB, "Glass", 0.6)
			R.place(CF(0, 6, -24))
			R.pose(CURL)
			R.attach(bubble, "Torso", CF(0, -0.6, 0))
			local crown
			R.mark(M(0, -1.2))
			R.onSkip(function(R)
				if bubble and bubble.Parent then
					bubble.Transparency = 1
				end
				if crown and crown.Parent then
					crown:Destroy()
				end
				if crownRig then
					R.show(crownRig, true)
				end
				R.place(M(0, -1.2))
				R.pose(EMPEROR)
				R.transform(true)
				R.cam.cut(V3(3, 2, -11), V3(0, 4.5, -1), 55)
			end)
			R.every(0.12, function()
				R.fx.bubbles(V3(R.rand(-10, 10), 0.5, R.rand(-30, 2)), 1, R.rand(0.4, 1.1))
			end)
			-- 1. plan large du palais, la caméra descend du plafond
			R.sound("PowerUp", nil, 0.5, 0.6)
			R.cam.crane(V3(0, 4, -10), 16, 5, 22, 1.6, { fov = 60 })
			R.wait(1.4)
			-- 2. la bulle impériale flotte le long du tapis rouge
			R.fly(R.rig, { V3(0, 6, -24), V3(1.6, 7, -15), V3(-1.2, 6.2, -7), V3(0, 5.6, 1.4) }, 2.0, { style = ES.Sine })
			R.cam.track(2.0, function()
				local p = R.pos(R.rig)
				return V3(p.X + 5.2, p.Y - 0.5, p.Z - 7), p, 55
			end)
			R.wait(2.0)
			-- 3. coup de sceptre : la bulle éclate au ralenti, il tombe assis sur le trône
			R.cam.cut(V3(-3.5, 4.2, -7), V3(0, 4.8, 1.2), 50)
			R.anim(POKE)
			R.wait(0.3)
			R.slowmo(0.25, 1.0)
			R.detach(bubble)
			local bp = R.pos(bubble)
			R.destroy(bubble, "pop")
			R.fx.bubbles(bp, 30, 1)
			R.fx.shockwave(bp, 10, BUB)
			R.fx.ring(bp, V3(0, 0, -1), 9, BUB)
			R.sound("GlassBreak", bp, 0.8)
			R.sound("Boing", bp, 0.6)
			R.freeze(0.12)
			R.cam.shake(0.4)
			R.pose("Sit")
			R.moveTo(R.rig, CF(0, 3.05, 1.7), 0.35, ES.Bounce, ED.Out)
			R.wait(0.45)
			-- 4. la couronne descend des cieux, au ralenti
			local headTop = V3(0, 3.05 + 2.5, 1.7)
			crown = R.mesh("Janitor_Legendary_Crown", CF(0, 16, 1.7), 1.6) or R.prop("Crown", CF(0, 16, 1.7))
			R.fx.rays(GOLD, V3(0, 12, 1.7))
			R.fx.dark(0.3, 0.4)
			R.sound("PowerUp", nil, 0.7, 1.2)
			R.over(1.6, function(_, e)
				if crown and crown.Parent then
					crown:PivotTo(R.at(0, lerp(16, headTop.Y, e), 1.7) * ANG(0, e * PI * 3, 0))
				end
			end, ES.Sine, ED.Out)
			R.cam.track(1.6, function(a)
				local e = a * a * (3 - 2 * a)
				return V3(2.6, lerp(3.6, 5.2, e), -7), V3(0, lerp(13, 5.2, e), 1.7), 55
			end)
			R.wait(1.6)
			if crown and crown.Parent then
				crown:Destroy()
			end
			if crownRig then
				R.show(crownRig, true)
			end
			R.fx.dark(0, 0.2)
			R.fx.flash(GOLD, 0.03, 0.05, 0.3)
			R.fx.sparks(headTop, 20, GOLD)
			R.sound("Ding", headTop, 0.9)
			R.fx.word("ALL HAIL!", V3(0, 9, 1.7), 1.3)
			R.cam.shake(0.3)
			R.wait(0.3)
			-- 5. l'empereur se lève, sceptre au ciel, bulle-bouclier et halo de bulles
			R.walk(M(0, -1.2), 0.5, "Strut")
			R.wait(0.5)
			R.pose(EMPEROR)
			R.transform(true)
			R.fx.swirl(V3(0, 1, -1.2), 4, 7, { BUB, WHITE, GOLD })
			R.fx.confetti(V3(0, 10, -1.2), 40, { BUB, GOLD, WHITE }, 7, 2)
			R.sound("LevelUp", nil, 0.8)
			R.cam.orbit(V3(0, 4.2, -1.2), 11, -0.5, -0.45, 0.25, 1.4, 55, 50)
			R.wait(1.0)
			R.title()
		end,
	}
end

-----------------------------------------------------------------------
-- LUNCH LADY
------------------------------------------------------------------------
do
	local TOM, CHEESE, CRUST, PEP = C3(220, 50, 45), C3(255, 200, 90), C3(215, 150, 70), C3(170, 35, 30)
	local SURF = { RS = { p = 1.4, r = 1.2 }, LS = { p = 1.4, r = 1.2 }, RJ = { tw = 0.5, ln = 0.1, sd = 0.15 }, RH = { r = 0.35 }, LH = { r = 0.35, p = -0.2 } }
	local CATCH_L = { { t = 0 }, { t = 0.12, LS = { p = 1.7, r = 0.3 } }, { t = 0.4, LS = { p = 1.2 } } }
	local PULL = {
		{ t = 0, RS = { p = 2.5, y = -0.6, r = -0.2 }, RJ = { ln = 0.05 } },
		{ t = 0.75, RS = { p = 1.35, r = 0.75 }, RJ = { ln = -0.1, tw = -0.2 } },
	}
	local VEE = { RS = { p = 2.6, r = 0.75 }, LS = { p = 2.6, r = 0.75 }, RJ = { ln = -0.15 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
	local function slice(R, cf)
		return R.model({
			{ Size = V3(0.15, 1.7, 1.25), CFrame = CF(), Color = CHEESE, Shape = "Wedge" },
			{ Size = V3(0.3, 0.3, 1.3), CFrame = CF(0, -0.85, 0), Color = CRUST },
			{ Size = V3(0.22, 0.32, 0.32), CFrame = CF(0.04, -0.3, 0.2), Color = PEP, Shape = "Cyl" },
			{ Size = V3(0.22, 0.26, 0.26), CFrame = CF(0.04, 0.2, 0.3), Color = PEP, Shape = "Cyl" },
		}, cf)
	end

	-- Pizza Party Queen : pluie de parts de pizza, elle arrive en glissade et en attrape une, fil de fromage, banderole
	P.LunchLady_Rare = {
		Caption = "Every Friday. Attendance is mandatory.",
		Location = "Cafeteria - Friday, 12:00",
		Reveal = function(R)
			R.stage("Room", { color = C3(255, 236, 200), floor = C3(200, 70, 60), w = 34, d = 26, h = 15 })
			R.box(V3(12, 0.4, 3.4), CF(0, 2.6, 5), WHITE)
			for _, x in ipairs({ -5, 5 }) do
				R.box(V3(0.4, 2.4, 3), CF(x, 1.2, 5), C3(160, 160, 170), "Metal")
			end
			for i = 0, 2 do
				local b = R.box(V3(2.4, 0.45, 2.4), CF(-3.5, 3.05 + i * 0.47, 5) * ANG(0, i * 0.2, 0), C3(205, 165, 115))
				if i == 2 then
					R.text(b, "PIZZA", { Color = PEP, Face = Enum.NormalId.Top })
				end
			end
			local banner = R.box(V3(13, 0.1, 0.2), CF(0, 11, 9), TOM, "Fabric")
			local bannerLabel = R.text(banner, "", { Color = WHITE, Face = Enum.NormalId.Front })
			local caught = slice(R, CF(-1, 24, -1))
			R.place(M(15, -1, -PI / 2 + 0.4))
			R.pose(SURF)
			R.onSkip(function(R)
				banner.Size = V3(13, 3, 0.2)
				banner.CFrame = R.at(0, 9.55, 9)
				bannerLabel.Text = "PIZZA PARTY!"
				R.place(M(0, 0))
				R.pose(VEE)
				R.cam.cut(V3(3, 3.6, -12), V3(0, 4.6, 0), 55)
			end)
			-- 1. il pleut des pizzas ; elle arrive en glissade et attrape une part au vol
			R.cam.cut(V3(0, 4.5, -13), V3(0, 4, 2), 55)
			for i = 1, 14 do
				R.delay(i * 0.08, function()
					local x, z = R.rand(-10, 10), R.rand(-3, 8)
					local s = slice(R, CF(x, 24, z) * ANG(R.rand(0, 6), R.rand(0, 6), 0))
					local land = CF(x, 0.2, z) * ANG(0, R.rand(0, 6), PI / 2)
					R.moveTo(s, land, R.rand(0.55, 0.85), ES.Bounce, ED.Out)
					R.delay(0.5, function()
						R.sound("Splat", V3(x, 0, z), 0.3)
					end)
				end)
			end
			R.wait(0.2)
			R.sound("Slip", nil, 0.7)
			R.moveTo(R.rig, M(0, 0, 0.15), 0.8, ES.Quart, ED.Out)
			for k = 0, 5 do
				R.delay(k * 0.1, function()
					local p = R.pos(R.rig)
					R.fx.smoke(V3(p.X, 0.3, p.Z), 1, WHITE, 0.7)
				end)
			end
			-- la part tombe vers sa main gauche (driver par image, coupé avant la soudure : sinon il déplacerait tout le rig)
			local falling = true
			R.over(0.8, function(_, e)
				if falling and caught.Parent then
					caught:PivotTo(R.at(lerp(-1, -1.6, e), lerp(24, 4.2, e), lerp(-1, -1.2, e)) * ANG(0, 0, 0.3 * e))
				end
			end, ES.Quad, ED.In)
			R.wait(0.8)
			falling = false
			R.anim(CATCH_L)
			R.attach(caught, "LeftHand", CF(0.2, -1.3, -0.5))
			R.sound("Pickup", nil, 0.7)
			R.cam.punch(-5)
			R.wait(0.3)
			-- 2. bouchée + fil de fromage interminable, puis la banderole se déroule
			R.cam.move(V3(-2.6, 4.7, -5.5), V3(0.2, 4.3, 0), 0.3, 45)
			R.anim("Bite")
			R.sound("Eat", nil, 0.8)
			R.wait(0.35)
			local strand = R.box(V3(1, 0.12, 0.12), CF(0, -10, 0), CHEESE, "SmoothPlastic", 0, "Cyl")
			R.anim(PULL)
			R.over(0.75, function()
				stretch(R, strand, limb(R, "Head", CF(0, -0.25, -0.62)), limb(R, "Right Arm", CF(0, -1.3, -0.5)), 0.12)
			end)
			R.wait(0.75)
			R.destroy(strand, "puff")
			R.sound("Boing", nil, 0.6)
			R.pose(VEE)
			R.tween(banner, 0.4, { Size = V3(13, 3, 0.2), CFrame = R.at(0, 9.55, 9) }, ES.Back, ED.Out)
			bannerLabel.Text = "PIZZA PARTY!"
			R.fx.confetti(V3(0, 9, 0), 60, { TOM, CHEESE, WHITE, C3(80, 180, 80) }, 7, 4)
			R.fx.word("PARTY!", V3(0, 8, 0), 1.1)
			R.cam.move(V3(3, 3.6, -12), V3(0, 4.6, 0), 0.5, 55)
			R.wait(0.5)
			R.title()
		end,
	}

	local PNK, PNKD = C3(255, 110, 160), C3(225, 75, 135)
	local WHISK = {}
	for i = 0, 9 do
		local s = (i % 2 == 0) and 1 or -1
		WHISK[#WHISK + 1] = { t = i * 0.12, RS = { p = 1.25 + 0.15 * s, y = 0.4 * s, r = 0.12 * s }, LS = { p = 0.9, y = 0.6 }, RJ = { ln = 0.28, sd = 0.04 * s } }
	end
	local KISS = {
		{ t = 0 },
		{ t = 0.22, LS = { p = 2.5, y = -0.7, r = -0.45 }, RJ = { ln = 0.05 } },
		{ t = 0.5, LS = { p = 1.9, r = 0.6 }, RJ = { ln = -0.12, sd = 0.08 } },
		{ t = 0.9, LS = { p = 1.9, r = 0.6 }, RJ = { ln = -0.12, sd = 0.08 } },
	}

	-- Cooking Show Diva : on est derrière la caméra télé, ON AIR, coucou de diva, fouet frénétique,
	-- le four révèle un gâteau trois étages, APPLAUSE, bisou à la caméra
	P.LunchLady_Epic = {
		Caption = "Live from the break room: it's FABULOUS, darling.",
		Location = "Studio 4 - Live Broadcast",
		Reveal = function(R)
			R.stage("Studio", { color = C3(255, 200, 225), floor = C3(240, 236, 240) })
			R.box(V3(9, 3, 2.4), CF(-0.5, 1.5, -2.6), PNK)
			R.box(V3(9.3, 0.25, 2.7), CF(-0.5, 3.1, -2.6), WHITE, "Marble")
			local front = R.box(V3(4, 1, 0.1), CF(-0.5, 1.7, -3.85), WHITE)
			R.text(front, "♥ DIVA ♥", { Color = PNKD, Face = Enum.NormalId.Front })
			R.cyl(0.9, 2.1, V3(1.1, 3.65, -2.3), WHITE)
			R.cyl(0.08, 1.8, V3(1.1, 4.1, -2.3), C3(250, 228, 170))
			-- four
			R.box(V3(3.2, 3.6, 3), CF(5.6, 1.8, -0.6), C3(200, 205, 215), "Metal")
			local door = R.box(V3(2.6, 2.2, 0.15), CF(5.6, 1.9, -2.15), C3(60, 40, 30), "Glass")
			R.light(V3(5.6, 1.8, -0.6), C3(255, 150, 60), 8, 1)
			local cake = R.model({
				{ Size = V3(0.9, 2.4, 2.4), CFrame = CF(0, 0.45, 0) * ANG(0, 0, PI / 2), Color = WHITE, Shape = "Cyl" },
				{ Size = V3(0.8, 1.8, 1.8), CFrame = CF(0, 1.3, 0) * ANG(0, 0, PI / 2), Color = PNK, Shape = "Cyl" },
				{ Size = V3(0.7, 1.2, 1.2), CFrame = CF(0, 2.05, 0) * ANG(0, 0, PI / 2), Color = WHITE, Shape = "Cyl" },
				{ Size = V3(0.4, 0.4, 0.4), CFrame = CF(0, 2.6, 0), Color = C3(220, 30, 60), Shape = "Ball" },
				{ Size = V3(0.12, 0.5, 0.12), CFrame = CF(0.35, 2.65, 0), Color = GOLD, Material = "Neon" },
				{ Size = V3(0.12, 0.5, 0.12), CFrame = CF(-0.35, 2.65, 0), Color = GOLD, Material = "Neon" },
			}, CF(5.6, 0.6, -0.6))
			local onair = R.box(V3(3, 1, 0.3), CF(-5, 8, 3), C3(70, 25, 25))
			R.text(onair, "ON AIR", { Color = WHITE, Face = Enum.NormalId.Front })
			local applause = R.box(V3(5.4, 1.3, 0.3), CF(0, 10.5, 4), C3(60, 20, 20))
			local appl = R.text(applause, "APPLAUSE", { Color = C3(120, 90, 90), Face = Enum.NormalId.Front })
			R.prop("Camera", CF(-4.6, 0, -8.5) * ANG(0, PI - 0.35, 0))
			local spot = R.spot(V3(-7, 14, 3), V3(0, 0, 0), { color = C3(255, 200, 225), on = false, brightness = 4 })
			R.place(M(0, 0))
			R.onSkip(function(R)
				door.CFrame = R.at(5.6, 0.8, -3.2) * ANG(-PI / 2, 0, 0)
				cake:PivotTo(R.at(3.3, 3.25, -2.9))
				onair.Color = C3(255, 40, 40)
				onair.Material = Enum.Material.Neon
				appl.TextColor3 = WHITE
				R.place(M(0, 0))
				R.pose("Present")
				R.cam.cut(V3(-2.2, 4.8, -11), V3(0.6, 4.4, 0), 50)
			end)
			-- 1. derrière la caméra télé : ON AIR s'allume, coucou de diva
			R.fx.dark(0.75)
			R.caption("● REC   CH4 - LIVE")
			R.cam.cut(V3(0, 4.6, -13.5), V3(0, 4.2, 0), 42)
			R.wait(0.45)
			onair.Color = C3(255, 40, 40)
			onair.Material = Enum.Material.Neon
			R.sound("UIClick", nil, 0.9)
			spot.on(0.1)
			R.fx.dark(0, 0.3)
			R.sound("Ding", nil, 0.5, 1.2)
			R.anim("Wave")
			R.cam.move(V3(0, 4.6, -11), V3(0, 4.3, 0), 1.1, 40)
			R.wait(1.1)
			-- 2. fouet frénétique, nuage de farine
			R.cam.cut(V3(-2.6, 6.4, -6.8), V3(0.9, 3.9, -1.8), 48)
			R.anim(WHISK)
			for k = 0, 10 do
				R.delay(k * 0.11, function()
					R.fx.puff(V3(1.1 + R.rand(-0.5, 0.5), 4.4, -2.3 + R.rand(-0.5, 0.5)), 0.8)
					if k % 3 == 0 then
						R.sound("Whoosh", nil, 0.3, 1.6)
					end
				end)
			end
			R.cam.shake(0.15)
			R.wait(1.2)
			R.fx.smoke(V3(1.1, 4.5, -2.3), 7, WHITE, 2)
			R.sound("Splat", nil, 0.6)
			R.fx.word("WHISK!", V3(1.1, 7.5, -2.3), 0.9)
			R.wait(0.25)
			-- 3. le four : gâteau trois étages, APPLAUSE, bisou à la caméra
			R.face(V3(5.6, 3, -0.6), 0.2)
			R.cam.cut(V3(1, 4.5, -9.5), V3(3.5, 3.4, -1.5), 50)
			R.moveTo(door, CF(5.6, 0.8, -3.2) * ANG(-PI / 2, 0, 0), 0.3, ES.Back, ED.Out)
			R.sound("Clang", nil, 0.6)
			R.fx.smoke(V3(5.6, 2.4, -2.4), 5, WHITE, 1.4)
			R.fx.light(V3(5.6, 2, -2.4), C3(255, 180, 80), 16, 4, 0.6)
			R.wait(0.3)
			R.jump(cake, CF(3.3, 3.25, -2.9), 0.5, 2.5)
			R.wait(0.5)
			R.fx.sparks(V3(3.3, 6, -2.9), 16, GOLD)
			R.sound("Ding", nil, 0.8, 1.1)
			R.face(V3(0, 3, -10), 0.15)
			R.pose("Present")
			appl.TextColor3 = WHITE
			applause.Color = C3(230, 30, 40)
			applause.Material = Enum.Material.Neon
			R.every(0.2, function(i)
				appl.TextColor3 = (i % 2 == 0) and WHITE or C3(255, 230, 120)
			end)
			for k = 0, 5 do
				R.delay(k * 0.1, function()
					R.sound("Punch", nil, 0.25, 1.8)
				end)
			end
			R.fx.confetti(V3(0, 11, 0), 40, { PNK, WHITE, GOLD }, 7, 2)
			R.cam.move(V3(-2.2, 4.8, -11), V3(0.6, 4.4, 0), 0.6, 50)
			R.wait(0.6)
			R.anim(KISS)
			R.wait(0.4)
			R.fx.hearts(limb(R, "Head", CF(0, 0, -1.4)), 8, PNK)
			R.wait(0.3)
			R.title()
		end,
	}

	local FLAME, FLAME2 = C3(255, 120, 30), C3(255, 215, 60)
	local TOSS = {
		{ t = 0 },
		{ t = 0.15, RS = { p = 0.35 }, RJ = { ln = 0.15 } },
		{ t = 0.3, RS = { p = 1.95, y = 0.2 }, RJ = { ln = -0.2 } },
		{ t = 0.9, RS = { p = 1.5 }, RJ = { ln = -0.1 } },
	}
	local MILL = { LS = { p = 2.35, r = 0.5, y = 0.4 }, RS = { p = 0.35, r = 0.15 }, RJ = { sd = 0.15, tw = -0.2 }, RH = { p = 0.1 }, LH = { p = -0.1 } }
	local function plate(R, cf, food)
		return R.model({
			{ Size = V3(0.14, 1.8, 1.8), CFrame = ANG(0, 0, PI / 2), Color = WHITE, Shape = "Cyl" },
			{ Size = V3(0.9, 0.5, 0.9), CFrame = CF(0, 0.3, 0), Color = food, Shape = "Ball" },
			{ Size = V3(0.3, 0.2, 0.3), CFrame = CF(0.15, 0.6, 0), Color = C3(80, 180, 70), Shape = "Ball" },
		}, cf)
	end

	-- Celebrity Chef Inferno : ticket qui s'imprime + clochette, brûleurs qui s'allument en rafale, flambé au ralenti,
	-- assiettes envoyées en vol, coup de moulin à poivre, 5 étoiles qui tombent, épaules en feu
	P.LunchLady_Legendary = {
		Caption = "Five stars. Zero patience. Yes, chef.",
		Location = "The Break Room Kitchen - Dinner Rush",
		Reveal = function(R)
			R.stage("Room", { color = C3(70, 70, 78), floor = C3(40, 40, 46), w = 30, d = 24, h = 14 })
			for x = -12, 12, 2 do
				for y = 1, 11, 2 do
					R.box(V3(1.9, 1.9, 0.2), CF(x, y, 7), (x + y) % 4 == 1 and C3(235, 235, 240) or C3(215, 218, 225))
				end
			end
			R.box(V3(10, 1.5, 4), CF(0, 11, 5), C3(170, 175, 185), "Metal")
			R.box(V3(12, 2.2, 2.6), CF(0, 1.1, -2.8), C3(180, 185, 195), "Metal")
			R.box(V3(12.2, 0.2, 2.8), CF(0, 2.3, -2.8), C3(35, 35, 40), "Metal")
			local burners = {}
			for i, x in ipairs({ -4.5, -1.5, 1.5, 4.5 }) do
				R.cyl(0.12, 1.4, V3(x, 2.46, -2.8), C3(20, 20, 24), "Metal")
				burners[i] = V3(x, 2.7, -2.8)
			end
			local printer = R.box(V3(1.4, 1, 1.2), CF(-5.4, 2.9, -2.6), C3(30, 30, 36))
			local ticket = R.box(V3(0.9, 0.05, 0.05), CF(-5.4, 2.7, -3.25), WHITE)
			local tl = R.text(ticket, "ORDER UP!\n★★★★★", { Color = BLACK, Face = Enum.NormalId.Front, Stroke = false })
			local bell = R.ball(0.8, V3(5.3, 2.65, -3.4), GOLD, "Metal")
			R.box(V3(1, 0.1, 1), CF(5.3, 2.45, -3.4), C3(50, 50, 55), "Metal")
			local stars = {}
			for i = 1, 5 do
				local s = R.box(V3(1.9, 1.9, 0.2), CF(-5 + (i - 1) * 2.5, 24, 1.5), GOLD, "SmoothPlastic", 1)
				R.text(s, "★", { Color = GOLD, StrokeColor = C3(130, 70, 0), Face = Enum.NormalId.Front })
				stars[i] = s
			end
			local plates = {}
			R.place(M(0, 0))
			R.pose("HandsHips")
			R.onSkip(function(R)
				ticket.Size = V3(0.9, 1.6, 0.05)
				ticket.CFrame = R.at(-5.4, 1.9, -3.25)
				for i, s in ipairs(stars) do
					s.CFrame = R.at(-5 + (i - 1) * 2.5, 9.6, 1.5)
				end
				for _, b in ipairs(burners) do
					R.fx.fire(b, 3, FLAME, 1)
				end
				R.place(M(0, 0))
				R.pose("ArmsCrossed")
				R.transform(true)
				R.cam.cut(V3(2.5, 4.4, -11), V3(0, 5.2, 0), 52)
			end)
			-- 1. dans le noir : le ticket s'imprime, la clochette sonne
			R.fx.dark(0.8)
			R.cam.cut(V3(-4.2, 3.6, -6.2), V3(-5.4, 2.5, -2.8), 42)
			for k = 1, 6 do
				R.delay(k * 0.1, function()
					R.sound("UIClick", nil, 0.5, 1.4)
				end)
			end
			R.tween(ticket, 0.7, { Size = V3(0.9, 1.6, 0.05), CFrame = R.at(-5.4, 1.9, -3.25) }, ES.Linear)
			R.wait(0.85)
			tl.Text = "ORDER UP!\n★★★★★"
			R.cam.whip(V3(4.4, 3.6, -6.3), V3(5.3, 2.6, -3.4), 0.18)
			R.wait(0.2)
			R.tween(bell, 0.08, { Size = V3(1, 0.6, 1) }, ES.Quad, ED.Out)
			R.sound("Ding", bell, 1, 1.25)
			R.delay(0.1, function()
				R.tween(bell, 0.2, { Size = V3(0.8, 0.8, 0.8) }, ES.Elastic, ED.Out)
			end)
			R.wait(0.45)
			-- 2. les brûleurs s'allument en rafale vers elle
			R.cam.dolly(V3(-7, 5.6, -10), V3(2.5, 6.2, -10.5), V3(0, 5, 0), 1.6, 50)
			for i, b in ipairs(burners) do
				R.delay((i - 1) * 0.2, function()
					R.fx.fire(b, 8, i % 2 == 0 and FLAME or FLAME2, 1)
					R.fx.light(b, FLAME, 14, 3, 0.4)
					R.sound("Whoosh", b, 0.5, 0.8 + i * 0.1)
				end)
			end
			R.fx.dark(0.25, 1)
			R.wait(1.6)
			-- 3. flambé au ralenti : colonne de feu jusqu'au plafond
			R.anim(TOSS)
			R.wait(0.3)
			local pan = limb(R, "Right Arm", CF(0, -1.2, -1.3))
			R.slowmo(0.3, 1.2)
			R.fx.pillar(pan, 1.4, 12, FLAME, 1.5)
			R.fx.fire(pan + V3(0, 1.5, 0), 2.5, FLAME, 3)
			R.fx.light(pan, FLAME, 30, 6, 1.2)
			R.sound("Explosion", pan, 0.7)
			R.cam.cut(V3(-6.5, 6.8, -6.5), V3(0, 6.4, -1.2), 60)
			R.cam.punch(10)
			R.cam.shake(0.6)
			R.fx.word("FLAMBÉ!", pan + V3(0, 6, 0), 1.4)
			R.wait(0.9)
			-- 4. trois assiettes arrivent en vol sur le passe, coup de moulin à poivre façon star
			local foods = { C3(140, 70, 40), C3(230, 160, 60), C3(200, 60, 50) }
			for i, x in ipairs({ -3, 0, 3 }) do
				R.delay((i - 1) * 0.22, function()
					local pl = plate(R, CF(x + (i == 2 and 0 or (x > 0 and 14 or -14)), 9, -6), foods[i])
					plates[i] = pl
					R.jump(pl, CF(x, 2.5, -3.4), 0.42, 3)
					R.delay(0.42, function()
						R.sound("Clang", V3(x, 2.5, -3.4), 0.5, 1.3)
						R.fx.sparks(V3(x, 2.6, -3.4), 6, WHITE)
					end)
				end)
			end
			R.cam.orbit(V3(0, 4, -2.5), 8.5, 1.4, 0.9, 0.35, 1.8, 50, 46)
			R.wait(0.9)
			R.pose(MILL)
			for k = 0, 8 do
				R.delay(k * 0.08, function()
					R.fx.sparks(V3(R.rand(-3, 3), 4.0, -3.4), 3, C3(60, 50, 40))
				end)
			end
			R.sound("Spray", nil, 0.4, 1.5)
			R.wait(0.85)
			-- 5. cinq étoiles s'écrasent une à une, elle s'embrase, bras croisés
			R.cam.move(V3(2.5, 4.4, -11), V3(0, 5.4, 0), 0.6, 52)
			for i, s in ipairs(stars) do
				R.delay((i - 1) * 0.18, function()
					local x = -5 + (i - 1) * 2.5
					R.moveTo(s, CF(x, 9.6, 1.5), 0.15, ES.Back, ED.Out)
					R.delay(0.15, function()
						R.sound("PunchHeavy", V3(x, 9.6, 1.5), 0.5)
						R.fx.sparks(V3(x, 9.6, 1.2), 10, GOLD)
						R.cam.shake(0.22)
					end)
				end)
			end
			R.wait(1.0)
			R.pose("ArmsCrossed")
			R.transform(true)
			R.fx.flash(FLAME, 0.03, 0.05, 0.3)
			R.sound("PowerUp", nil, 0.8)
			R.fx.word("YES, CHEF!", V3(0, 12, 0), 1.2)
			R.wait(0.5)
			R.title()
		end,
	}
end

-----------------------------------------------------------------------
-- SECURITY GUARD
------------------------------------------------------------------------
do
	local OR, NV = C3(255, 130, 30), C3(30, 40, 75)
	local SEG_Y = 3.35 -- le gyropode du skin dépasse sous les pieds : on surélève la racine
	local BADGE = { RS = { p = 1.6 }, LS = { p = 0.15, r = 0.2 }, RJ = { tw = -0.12, ln = -0.08 } }
	local function cone(R, cf)
		return R.model({
			{ Size = V3(1.5, 0.2, 1.5), CFrame = CF(0, 0.1, 0), Color = OR },
			{ Size = V3(0.6, 1.1, 1.1), CFrame = CF(0, 0.5, 0) * ANG(0, 0, PI / 2), Color = OR, Shape = "Cyl" },
			{ Size = V3(0.5, 0.78, 0.78), CFrame = CF(0, 1.0, 0) * ANG(0, 0, PI / 2), Color = WHITE, Shape = "Cyl" },
			{ Size = V3(0.5, 0.5, 0.5), CFrame = CF(0, 1.45, 0) * ANG(0, 0, PI / 2), Color = OR, Shape = "Cyl" },
		}, cf)
	end
	local BADGE_SPEC = { Size = V3(0.9, 0.9, 0.12), Color = GOLD, Material = "Metal", Text = "★" }

	-- Segway Patrol : il déboule dans la galerie marchande en dérapage à 360°, renverse un plot, brandit son badge
	P.SecurityGuard_Rare = {
		Caption = "Top speed: 12 mph. Top attitude: maximum.",
		Location = "Sunny Plaza Mall - Level 1",
		Reveal = function(R)
			R.stage(function(R)
				R.floor(V3(90, 1, 40), CF(0, -0.5, 0), C3(235, 235, 242), "Marble")
				R.box(V3(90, 16, 1), CF(0, 8, 13), C3(250, 240, 225))
				for i, x in ipairs({ -15, 0, 15 }) do
					local col = ({ C3(255, 90, 90), C3(80, 170, 255), C3(110, 210, 110) })[i]
					R.box(V3(11, 6, 0.3), CF(x, 3.5, 12.4), C3(170, 220, 255), "Glass", 0.4)
					local s = R.box(V3(9, 1.6, 0.4), CF(x, 8.2, 12.3), col)
					R.text(s, ({ "SHOES", "FOOD COURT", "TOYS" })[i], { Color = WHITE, Face = Enum.NormalId.Front })
					R.box(V3(11.5, 0.6, 1.6), CF(x, 7, 11.6) * ANG(-0.4, 0, 0), col)
				end
				for _, x in ipairs({ -9, 9, -24, 24 }) do
					R.prop("Plant", CF(x, 0, 9))
				end
				R.light(V3(0, 13, -2), C3(255, 250, 235), 60, 1.2)
			end)
			local c1 = cone(R, CF(-2.6, 0, -1.6))
			cone(R, CF(-6, 0, 2))
			R.mark(M(0, 0, 0, SEG_Y))
			R.place(M(26, -1, PI / 2, SEG_Y))
			R.pose({ RS = { p = 0.6 }, LS = { p = 0.6 }, RJ = { ln = 0.15 } })
			local badge
			R.onSkip(function(R)
				c1:PivotTo(R.at(-8, 0.4, -6) * ANG(PI / 2, 0, 0.6))
				R.place(M(0, 0, 0, SEG_Y))
				badge = badge or R.hold(BADGE_SPEC, "Right")
				R.pose(BADGE)
				R.cam.cut(V3(1.5, 4.6, -7.5), V3(0.6, 4.2, -1), 48)
			end)
			-- 1. arrivée en dérapage, traces de pneus
			R.sound("Squeak", nil, 0.7, 0.8)
			local last = V3(26, 0, -1)
			R.over(1.7, function(_, e)
				local x = lerp(26, 0, e)
				local z = lerp(-1, 0, e)
				local yaw = lerp(PI / 2, 2 * PI, math.clamp((e - 0.35) / 0.65, 0, 1))
				local cf = M(x, z, yaw, SEG_Y)
				R.place(cf)
				local here = V3(x, 0, z)
				if (here - last).Magnitude > 0.7 and e > 0.3 then
					last = here
					for _, sx in ipairs({ -1.3, 1.3 }) do
						local w = (cf * CF(sx, 0, 0)).Position
						R.box(V3(0.5, 0.03, 0.6), CF(w.X, 0.02, w.Z) * ANG(0, yaw, 0), C3(40, 40, 45))
					end
				end
			end, ES.Quart, ED.Out)
			R.cam.track(1.7, function(a)
				local p = R.pos(R.rig)
				return V3(lerp(p.X + 2, 3, a), lerp(2.2, 3.2, a), -11), p + V3(0, 0.5, 0), 55
			end)
			R.delay(0.7, function()
				R.sound("Squeak", nil, 0.8, 1.1)
				R.fx.smoke(V3(8, 0.3, 0), 6, WHITE, 1.5)
			end)
			R.wait(1.35)
			R.jump(c1, CF(-8, 0.4, -6) * ANG(PI / 2, 0, 0.6), 0.55, 3.5)
			R.sound("Bonk", V3(-2.6, 1, -1.6), 0.7)
			R.fx.word("SKRRT!", V3(-2, 6.5, -1), 0.9)
			R.wait(0.35)
			-- 2. il brandit son badge vers la caméra : reflet !
			badge = R.hold(BADGE_SPEC, "Right")
			R.pose(BADGE)
			R.cam.move(V3(1.5, 4.6, -7.5), V3(0.6, 4.2, -1), 0.4, 46)
			R.over(1.2, function(_, _)
				R.place(M(0, 0, 0, SEG_Y) * ANG(math.sin(os.clock() * 7) * 0.03, 0, 0))
			end)
			R.wait(0.4)
			local bp = badge and badge.Parent and R.pos(badge) or limb(R, "Right Arm", CF(0, -1.2, -0.3))
			R.fx.twinkle(bp)
			R.fx.flash(WHITE, 0.03, 0.02, 0.15)
			R.sound("Ding", nil, 0.8, 1.4)
			R.fx.word("MALL COP!", V3(0, 7.5, 0), 1)
			R.wait(0.55)
			R.title()
		end,
	}

	local RED, BLUE = C3(255, 40, 40), C3(40, 90, 255)
	local SWEEP = {
		{ t = 0, RS = { p = 1.57 }, LS = { p = 0.3 }, RJ = { tw = 0.85 } },
		{ t = 0.75, RS = { p = 1.57 }, LS = { p = 0.3 }, RJ = { tw = -0.85 } },
		{ t = 1.0, RS = { p = 1.4 }, LS = { p = 0.3 }, RJ = { tw = -0.6 } },
	}

	-- Action Hero Guard : il marche vers la caméra au ralenti sans se retourner pendant que l'entrepôt explose,
	-- coup de lampe torche dans l'objectif, sirènes et réplique culte
	P.SecurityGuard_Epic = {
		Caption = "Wrong building. Wrong night. Wrong security guard.",
		Location = "Warehouse 13 - Night Shift",
		Reveal = function(R)
			R.stage("Night")
			R.box(V3(70, 18, 2), CF(0, 9, 30), C3(60, 62, 70), "Concrete")
			R.box(V3(16, 10, 0.4), CF(0, 5, 28.8), C3(90, 80, 60), "DiamondPlate")
			for _, s in ipairs({ { -7, 6 }, { 8, 9 }, { -9, 14 }, { 6.5, 16 } }) do
				R.prop("Crate", CF(s[1], 0, s[2]) * ANG(0, s[1] * 0.1, 0))
			end
			local barrels = {}
			for i, s in ipairs({ { -3, 20 }, { 2.5, 21 }, { 5, 19 }, { -5.5, 22 } }) do
				barrels[i] = R.cyl(2.6, 1.8, V3(s[1], 1.3, s[2]), C3(190, 40, 35), "Metal")
			end
			R.light(V3(0, 10, 6), C3(120, 140, 200), 40, 0.8)
			R.place(M(0, 12))
			R.onSkip(function(R)
				for _, b in ipairs(barrels) do
					b.Transparency = 1
				end
				R.place(M(0, 1.5))
				R.pose("Flex")
				R.cam.cut(V3(1.5, 2, -8), V3(0, 4.5, 3), 50)
			end)
			-- 1. il avance vers nous au ralenti ; derrière lui, tout explose — il ne se retourne pas
			R.cam.cut(V3(0, 2.2, -8.5), V3(0, 4.5, 8), 50)
			R.cam.move(V3(0, 2.4, -7.5), V3(0, 4.3, 5), 2.6, 46)
			R.walk(M(0, 1.5), 2.6, "Strut")
			R.wait(0.35)
			R.fx.explosion(V3(0, 4, 22), 1.6, C3(255, 140, 40))
			R.fx.pillar(V3(0, 0, 22), 5, 16, C3(255, 150, 50))
			R.fx.shockwave(V3(0, 0.3, 21), 22, C3(255, 160, 60))
			R.fx.debris(V3(0, 3, 21), 18)
			R.fx.light(V3(0, 6, 18), C3(255, 150, 60), 60, 8, 3)
			R.fx.fire(V3(-4, 1, 20), 6, C3(255, 120, 30), 3)
			R.fx.fire(V3(4, 1, 21), 6, C3(255, 120, 30), 3)
			R.fx.tint(C3(255, 205, 160), 0.3)
			R.sound("Explosion", V3(0, 4, 21), 1)
			R.cam.shake(0.8)
			for i, b in ipairs(barrels) do
				local p = R.loc(b.Position)
				R.jump(b, CF(p.X * 2.5, 1, p.Z + 4 + i) * ANG(PI / 2, i, 0), 1.0, 8 + i)
			end
			R.slowmo(0.4, 1.4)
			R.wait(2.25)
			-- 2. la lampe torche balaie l'objectif
			R.anim(SWEEP)
			R.sound("Whoosh", nil, 0.7, 0.7)
			R.delay(0.36, function()
				R.fx.flash(C3(255, 250, 220), 0.05, 0.06, 0.3)
			end)
			R.wait(1.0)
			-- 3. sirènes, réplique, pose
			R.every(0.18, function(i)
				R.fx.light(R.pos(R.rig) + V3(0, 5, -1), (i % 2 == 0) and RED or BLUE, 26, 6, 0.17)
			end)
			R.sound("Siren", nil, 0.5)
			R.pose("Flex")
			R.fx.banner("NOT ON MY WATCH.", { color = RED, t = 1.2, size = 0.12, y = 0.2 })
			R.cam.move(V3(1.5, 2, -8), V3(0, 4.5, 3), 0.8, 50)
			R.cam.dutch(0.1, 0.6)
			R.wait(1.0)
			R.title()
		end,
	}

	local CY2 = C3(40, 200, 255)
	local SLUMP = { RS = { p = 0.15, r = -0.05 }, LS = { p = 0.15, r = -0.05 }, RJ = { ln = 0.45, sd = 0.12 }, RH = { p = 0.1 }, LH = { p = -0.05 } }
	local SNAP = {
		{ t = 0, RS = { p = 0.15, r = -0.05 }, LS = { p = 0.15, r = -0.05 }, RJ = { ln = 0.45, sd = 0.12 } },
		{ t = 0.12, RS = { p = 0.4, r = 0.25 }, LS = { p = 0.4, r = 0.25 }, RJ = { ln = -0.14 } },
		{ t = 0.4, RS = { p = 0.1, r = 0.1 }, LS = { p = 0.1, r = 0.1 }, RJ = { ln = 0 } },
	}

	-- Cyber Sentinel : capsule de recharge dans un labo sombre, séquence de boot (néons qui s'allument du haut vers
	-- le bas), la vitre se lève dans la vapeur, pas lourds, laser de scan qui traverse la caméra, drone lancé
	P.SecurityGuard_Legendary = {
		Caption = "Scanning for overtime violations... Violation detected.",
		Location = "Security Lab B - Charging Bay",
		Reveal = function(R)
			R.stage("Room", { dark = true, color = C3(30, 36, 50), floor = C3(25, 28, 38), w = 32, d = 26, h = 14 })
			for _, x in ipairs({ -10, -7, 7, 10 }) do
				R.prop("Server", CF(x, 0, 8))
			end
			for _, x in ipairs({ -8.5, 8.5 }) do
				R.box(V3(0.25, 0.06, 9), CF(x * 0.5, 0.03, 3.5) * ANG(0, x > 0 and -0.6 or 0.6, 0), C3(15, 15, 20))
			end
			R.box(V3(24, 0.05, 0.2), CF(0, 0.03, -6), CY2, "Neon")
			-- capsule
			R.cyl(0.6, 6, V3(0, 0.3, 0), C3(60, 65, 80), "Metal")
			R.cyl(0.15, 6.2, V3(0, 0.65, 0), CY2, "Neon")
			R.cyl(0.8, 6, V3(0, 8.6, 0), C3(60, 65, 80), "Metal")
			R.cyl(0.15, 6.2, V3(0, 8.15, 0), CY2, "Neon")
			R.box(V3(1, 8.5, 1), CF(0, 4.3, 2.9), C3(50, 55, 70), "Metal")
			local tube = R.cyl(7.4, 5.6, V3(0, 4.4, 0), C3(150, 220, 255), "Glass")
			tube.Transparency = 0.7
			-- éteint les néons et lumières du robot (ils se rallument pendant le boot)
			local glow = {}
			for _, d in ipairs(R.rig:GetDescendants()) do
				if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
					glow[#glow + 1] = { part = d, color = d.Color }
					d.Material = Enum.Material.SmoothPlastic
					d.Color = C3(45, 50, 62)
				elseif d:IsA("Light") and d.Enabled then
					glow[#glow + 1] = { light = d }
					d.Enabled = false
				end
			end
			table.sort(glow, function(a, b)
				local ya = a.part and a.part.Position.Y or 99
				local yb = b.part and b.part.Position.Y or 99
				return ya > yb
			end)
			local function relight(g)
				if g.part and g.part.Parent then
					g.part.Material = Enum.Material.Neon
					g.part.Color = g.color
				elseif g.light and g.light.Parent then
					g.light.Enabled = true
				end
			end
			R.place(M(0, 0, 0, 3.6))
			R.pose(SLUMP)
			local boot = R.billboard("SYSTEM BOOT  0%", V3(0, 8.1, -3.4), { size = 1.3, Color = CY2 })
			local drone
			R.mark(M(0, -4))
			R.onSkip(function(R)
				for _, g in ipairs(glow) do
					relight(g)
				end
				tube.CFrame = R.at(0, 13, 0) * ANG(0, 0, PI / 2)
				boot.Label.Text = "OVERTIME DETECTED"
				R.place(M(0, -4))
				R.pose("Point")
				R.cam.cut(V3(2.5, 3.5, -12), V3(0, 4.5, -4), 50)
			end)
			-- 1. labo plongé dans le noir, la jauge de boot monte
			R.fx.dark(0.55)
			R.cam.cut(V3(0, 4.6, -13), V3(0, 4.4, 0), 50)
			R.cam.move(V3(0, 4.8, -8.8), V3(0, 4.6, 0), 1.9, 46)
			R.sound("Electric", nil, 0.5, 0.7)
			R.over(1.7, function(_, e)
				boot.Label.Text = string.format("SYSTEM BOOT  %d%%", math.floor(e * 100))
			end, ES.Quad, ED.In)
			R.delay(0.9, function()
				R.fx.glitch()
			end)
			R.wait(1.8)
			-- 2. les circuits s'allument du casque aux bottes, la tête se redresse d'un coup
			local n = #glow
			local lit = 0
			R.over(1.0, function(a)
				local want = math.floor(a * n + 0.5)
				while lit < want do
					lit += 1
					relight(glow[lit])
					if lit % 6 == 0 then
						R.sound("UIClick", nil, 0.35, 1.6)
					end
				end
			end, ES.Linear)
			R.wait(1.0)
			for i = lit + 1, n do
				relight(glow[i])
			end
			boot.Label.Text = "ONLINE"
			R.anim(SNAP)
			R.fx.flash(CY2, 0.03, 0.04, 0.25)
			R.cam.punch(-8)
			R.sound("PowerUp", nil, 0.9)
			R.fx.word("ONLINE", V3(0, 8.5, -2), 1.1)
			R.wait(0.5)
			-- 3. la vitre se lève dans la vapeur, pas lourds hors de la capsule
			R.moveTo(tube, CF(0, 13, 0) * ANG(0, 0, PI / 2), 0.6, ES.Quad, ED.In)
			R.fx.smoke(V3(-2.4, 1, 0.5), 4, WHITE, 1.8)
			R.fx.smoke(V3(2.4, 1, 0.5), 4, WHITE, 1.8)
			R.sound("Spray", nil, 0.7, 0.6)
			R.fx.dark(0.2, 0.6)
			R.cam.move(V3(1.6, 1.6, -11.5), V3(0, 4.6, -3), 1.5, 55)
			R.wait(0.3)
			R.walk(M(0, -4), 1.3, "Walk")
			for k = 0, 1 do
				R.delay(0.35 + k * 0.6, function()
					local p = R.pos(R.rig)
					R.sound("Thud", p, 0.9, 0.7)
					R.fx.dust(V3(p.X, 0.1, p.Z), 3)
					R.cam.shake(0.3)
				end)
			end
			R.wait(1.35)
			-- 4. laser de scan qui balaie la pièce et traverse l'objectif
			boot.Label.Text = "SCANNING..."
			local laser = R.box(V3(20, 12, 0.1), CF(0, 6, -3), C3(255, 40, 40), "Neon", 0.55)
			R.cam.move(V3(0.6, 4.7, -8.5), V3(0, 4.5, -4), 0.5, 42)
			R.moveTo(laser, CF(0, 6, -16), 1.0, ES.Linear)
			R.sound("Alarm", nil, 0.5)
			R.delay(0.45, function()
				R.fx.tint(C3(255, 130, 130), 0.1)
				R.fx.flash(C3(255, 40, 40), 0.03, 0.03, 0.2)
				boot.Label.Text = "OVERTIME DETECTED"
				boot.Label.TextColor3 = C3(255, 60, 60)
				R.fx.banner("⊕ TARGET LOCKED", { color = C3(255, 60, 60), t = 0.9, size = 0.09, y = 0.78 })
			end)
			R.wait(1.0)
			R.destroy(laser)
			-- 5. le drone d'épaule décolle et orbite, il nous désigne du doigt
			R.fx.tint(WHITE, 0.4)
			drone = R.prop("Drone", CF(0.8, 5.2, -3.4))
			R.fx.sparks(V3(0.8, 5.2, -3.4), 14, CY2)
			R.sound("Electric", nil, 0.6, 1.4)
			R.over(1.6, function(_, e)
				if drone and drone.Parent then
					local ang = e * PI * 2.2
					drone:PivotTo(R.at(math.sin(ang) * 3.2, 5.2 + e * 2.6, -4 - math.cos(ang) * 3.2))
				end
			end, ES.Sine, ED.InOut)
			R.pose("Point")
			R.fx.lightning(V3(0, 8.4, 0), V3(-7, 6, 8), CY2)
			R.fx.lightning(V3(0, 8.4, 0), V3(7, 6, 8), CY2)
			R.fx.banner("VIOLATION DETECTED", { color = CY2, t = 1.0, size = 0.11, y = 0.2 })
			R.cam.orbit(V3(0, 4.4, -4), 10, 0, -0.55, 0.3, 1.5, 52, 48)
			R.wait(1.1)
			R.title()
		end,
	}
end

return P
