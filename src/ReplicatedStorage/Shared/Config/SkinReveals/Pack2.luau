--[[
	SkinReveals.Pack2 — chorégraphies de révélation (agent "reveal2") : ITGuy, Accountant, CEO, HRManager.
	API : REVEAL_API (en-tête de Controllers/SkinRevealController). Repère scène : sol y = 0, héros sur CF(0, 3, 0)
	regardant -Z, caméra par défaut côté -Z, +X = main droite du héros (gauche de l'écran).
	Chaque skin a sa propre structure (aucune ne réutilise « chute + coup à droite + demi-tour ») :
		ITGuy_Rare        gros plan terminal -> ACCESS GRANTED -> il sirote son energy drink sous une pluie de code
		ITGuy_Epic        jeu de plateforme 8-bit vu de profil : sort du tuyau, saute, frappe le bloc "?", HIGH SCORE
		ITGuy_Legendary   alarme rouge, baies serveur en cascade, il se compile en lévitation, 4 écrans, ENTER au ralenti
		Accountant_Rare   film noir en noir et blanc : œil géant derrière la loupe, reçu suspect, coup de chapeau
		Accountant_Epic   salle des marchés : BUY! BUY! BUY! au téléphone brique, courbe STONKS, glissade à genoux
		Accountant_Legendary  cloche d'ouverture, il charge comme un taureau hors du coffre, naseaux fumants, BULL RUN
		CEO_Rare          porte de garage qui s'ouvre sur la start-up, 1 milliard d'utilisateurs, smoothie, haussement d'épaules
		CEO_Epic          keynote dans le noir : "THE FUTURE.", projecteur, clic, il brandit l'agrafeuse "REVOLUTION."
		CEO_Legendary     la fusée atterrit, trappe + rampe, drapeau "HQ 2.0", salut, redécollage au ralenti, bottes-fusées
		HRManager_Rare    lévitation en lotus au-dessus d'un tapis qui se déroule, posture de l'arbre, "You're fired."
		HRManager_Epic    plateau télé : projecteurs, ON AIR, il monte par une trappe, jette ses fiches, micro tendu
		HRManager_Legendary  jeu télé : ampoules, rideaux, la roue tourne sur "YOU!", elle s'envole, COME ON DOWN!, WINNER
]]
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local PI, rad, sin, cos = math.pi, math.rad, math.sin, math.cos
local WHITE = Color3.new(1, 1, 1)
local GOLD = C3(255, 200, 40)
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local NF, NB, NR, NL, NT = Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Right, Enum.NormalId.Left, Enum.NormalId.Top

------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------
local function K(t, pose)
	local k = { t = t }
	for j, v in pairs(pose) do
		k[j] = v
	end
	return k
end
-- tient la dernière clé (sinon le rig revient au repos à la fin de l'anim)
local function hold(frames)
	local last = frames[#frames]
	local k = table.clone(last)
	k.t = last.t + 60
	frames[#frames + 1] = k
	return frames
end
-- pose complète (membres absents = neutres)
local function full(p)
	return {
		RS = p.RS or { p = 0 }, LS = p.LS or { p = 0 }, RH = p.RH or { p = 0 }, LH = p.LH or { p = 0 },
		RJ = p.RJ or { ln = 0 },
	}
end
-- petite vibration autour d'une pose (frappe au clavier, martelage de boutons)
local function jitter(base, dur, step, amp, joints)
	local f = { K(0, full(base)) }
	local t, s = 0, 1
	while t < dur do
		t += step
		s = -s
		local k = full(base)
		for n, j in ipairs(joints) do
			local c = table.clone(k[j])
			c.p = (c.p or 0) + amp * s * (n % 2 == 1 and 1 or -1)
			k[j] = c
		end
		f[#f + 1] = K(t, k)
	end
	return f
end
-- barre entre deux points (courbes, flèches)
local function seg(R, a, b, w, col, mat, tr)
	return R.box(V3(w, w, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), col, mat or "Neon", tr)
end

local P = {}

------------------------------------------------------------------------
-- IT GUY
------------------------------------------------------------------------
local HACK_G, HACK_R = C3(60, 255, 120), C3(255, 50, 60)
local LEAN_SIP = full({ RS = { p = 2.35, y = 0.9, r = -0.55 }, LS = { p = 0.15, r = 0.1 }, RJ = { ln = -0.2, sd = 0.06 }, RH = { p = 0.2, r = 0.12 }, LH = { p = -0.1, r = 0.12 } })
local HUNCH = full({ RS = { p = 1.1, y = 0.3, r = -0.3 }, LS = { p = 1.1, y = 0.3, r = -0.3 }, RJ = { ln = 0.3 } })

P.ITGuy_Rare = {
	Caption = "I'm in. (He is not in. He forgot his password.)",
	Location = "Basement - Server Closet B, 3:12 AM",
	Reveal = function(R)
		R.stage("Room", { color = C3(40, 46, 56), floor = C3(34, 36, 44), w = 22, d = 22, h = 12 })
		R.fx.dark(0.18)
		-- poste de travail : bureau, terminal, clavier, canettes vides
		R.box(V3(5, 0.25, 2.2), CF(0, 2.3, -2.4), C3(48, 44, 40), "Wood")
		for _, x in ipairs({ -2.2, 2.2 }) do
			R.box(V3(0.25, 2.2, 0.25), CF(x, 1.1, -2.4), C3(30, 30, 35), "Metal")
		end
		local screen = R.box(V3(3.4, 1.6, 0.2), CF(0, 3.35, -3.2), C3(6, 14, 8), "Glass")
		R.box(V3(0.4, 0.6, 0.3), CF(0, 2.6, -3.3), C3(30, 30, 35), "Metal")
		R.box(V3(2.2, 0.12, 0.7), CF(0, 2.48, -1.9), C3(25, 25, 30))
		R.box(V3(2, 0.03, 0.55), CF(0, 2.55, -1.9), HACK_G, "Neon", 0.6)
		for _, p in ipairs({ V3(1.9, 2.73, -2.6), V3(2.15, 2.73, -1.85), V3(-1.95, 2.73, -2.3) }) do
			R.cyl(0.6, 0.34, p, C3(22, 22, 28), "Metal")
		end
		R.box(V3(0.34, 0.34, 0.6), CF(-1.6, 2.6, -1.7) * ANG(0, 0.6, 0), C3(22, 22, 28), "Metal", nil, "Cyl")
		local back = R.text(screen, "", { Face = NB, Color = HACK_G, Bg = C3(4, 10, 6) })
		R.text(screen, "> sudo", { Face = NF, Color = HACK_G, Bg = C3(4, 10, 6) })
		local glow = R.light(V3(0, 3.4, -2.5), HACK_G, 14, 2.5)
		local lines = { "> ssh mainframe", "> brute_force.exe", "> guess: password1", "> guess: hunter2", "> guess: coffee", "> bypass firewall..." }
		local scrolling = true
		local function grant()
			scrolling = false
			back.Text = "ACCESS\nGRANTED"
			back.TextColor3 = HACK_G
			glow.Color = HACK_G
		end
		R.mark(CF(0, 3, 1.8))
		R.onSkip(function()
			grant()
			R.place(CF(0, 3, 1.8))
			R.pose(LEAN_SIP)
			R.cam.cut(V3(3.6, 5.3, -6.2), V3(0, 4.3, 1.8), 42)
		end)

		-- temps 1 : par-dessus son épaule, il tape comme un fou ; ACCESS DENIED... puis GRANTED
		R.light(V3(1.5, 6.5, -0.5), C3(120, 255, 170), 18, 2.6)
		R.light(V3(-3, 7, 3), C3(90, 110, 170), 22, 0.9)
		R.cam.cut(V3(2.8, 5.6, 2.8), V3(-0.3, 3.4, -3.2), 50)
		R.cam.move(V3(2.2, 5.0, 1.6), V3(-0.2, 3.4, -3.2), 1.6, 40)
		R.anim("Typing", 1.4)
		R.every(0.11, function(i)
			if scrolling then
				back.Text = lines[i % #lines + 1]
			end
		end)
		R.wait(0.7)
		scrolling = false
		back.Text = "ACCESS\nDENIED"
		back.TextColor3 = HACK_R
		glow.Color = HACK_R
		R.sound("Alarm", nil, 0.35, 1.3)
		R.fx.flash(HACK_R, 0.04, 0.05, 0.25)
		R.cam.shake(0.25)
		R.anim("Typing", 2.8)
		R.wait(0.6)
		grant()
		R.sound("LevelUp")
		R.fx.flash(HACK_G, 0.04, 0.05, 0.3)
		R.fx.word("I'M IN.", V3(0, 5.2, -3), 1)
		R.wait(0.35)
		-- temps 2 : il se recule et sirote son energy drink sous une pluie de code
		R.wait(R.cam.whip(V3(4.2, 5.4, -6.8), V3(0, 4.2, 1.8)))
		R.anim(hold({ K(0, HUNCH), K(0.35, LEAN_SIP) }))
		R.moveTo(R.rig, CF(0, 3, 1.8), 0.5, ES.Quad, ED.Out)
		R.fx.rain({ Colors = { HACK_G, C3(30, 170, 80) }, Size = V3(0.12, 0.9, 0.12), Material = "Neon", Count = 45, Slow = true }, 2.5)
		R.cam.move(V3(3.6, 5.3, -6.2), V3(0, 4.3, 1.8), 1.3, 42)
		R.wait(0.5)
		R.sound("Water", nil, 0.5, 1.5)
		R.wait(0.7)
		R.title()
		R.wait(0.5)
	end,
}

local PIX = { C3(255, 60, 60), C3(255, 220, 40), C3(60, 200, 255), C3(80, 230, 90), WHITE }
local MASH = full({ RS = { p = 1.35, y = 0.5, r = -0.45 }, LS = { p = 1.35, y = 0.5, r = -0.45 }, RJ = { ln = 0.18 }, RH = { p = 0.25, r = 0.3 }, LH = { p = -0.25, r = 0.3 } })
local GAMER_WIN = full({ RS = { p = 3.0, r = 0.2 }, LS = { p = 0.6, r = 1.1 }, RJ = { ln = -0.15, sd = 0.08 }, RH = { p = -0.2, r = 0.35 }, LH = { p = 0.3, r = 0.35 } })
local FIST_UP = full({ RS = { p = 3.1, r = 0.1 }, LS = { p = 0.3, r = 0.6 }, RH = { p = 0.9 }, LH = { p = -0.4 } })

P.ITGuy_Epic = {
	Caption = "Press START to take a break. There is no break.",
	Location = "WORLD 1-1 - Break Room",
	Reveal = function(R)
		local BRICK, BRICK_D = C3(200, 76, 12), C3(110, 36, 4)
		R.stage("Studio", { color = C3(92, 148, 252), floor = BRICK })
		-- sol de briques 8-bit (vu de profil depuis +X)
		for z = -18, 18, 2 do
			R.box(V3(8, 2, 2), CF(0, -0.95, z), BRICK)
			R.box(V3(8.04, 0.14, 2.04), CF(0, -0.95, z), BRICK_D)
			R.box(V3(8.04, 2.04, 0.14), CF(0, -0.95, z + 1), BRICK_D)
		end
		-- collines et nuages
		R.ball(14, V3(-14, -2, 9), C3(0, 168, 0))
		R.ball(9, V3(-13, -2, -10), C3(0, 168, 0))
		for _, c in ipairs({ V3(-18, 13, 6), V3(-18, 15, -6), V3(-18, 12, -15) }) do
			R.box(V3(1, 2, 5), CF(c), WHITE)
			R.box(V3(1, 3, 3), CF(c + V3(0, 0.6, 0)), WHITE)
		end
		-- tuyau vert
		R.cyl(3.2, 2.6, V3(0, 1.6, 7), C3(0, 168, 0))
		R.cyl(0.9, 3.2, V3(0, 3.6, 7), C3(0, 200, 0))
		-- bloc "?" entouré de briques
		local qb = R.box(V3(1.8, 1.8, 1.8), CF(0, 9.6, -2), C3(252, 188, 60))
		local qlabels = {}
		for _, f in ipairs({ NR, NF, NL, NB }) do
			qlabels[#qlabels + 1] = R.text(qb, "?", { Face = f, Color = C3(120, 60, 10) })
		end
		for _, z in ipairs({ -0.2, -3.8 }) do
			R.box(V3(1.8, 1.8, 1.8), CF(0, 9.6, z), BRICK)
			R.box(V3(1.84, 0.12, 1.84), CF(0, 9.6, z), BRICK_D)
		end
		local coin = R.prop("Coin", CF(0, 9.6, -2))   -- caché dans le bloc
		local function usedBlock()
			qb.Color = C3(150, 90, 40)
			for _, l in ipairs(qlabels) do
				l.Text = ""
			end
		end
		R.mark(CF(0, 3, -2))
		R.onSkip(function()
			usedBlock()
			R.place(CF(0, 3, -2))
			R.pose(GAMER_WIN)
			R.cam.cut(V3(-4.2, 3.7, -11), V3(0, 4.6, -2), 45)
		end)

		-- temps 1 : PRESS START, PLAYER 1, il sort du tuyau
		R.place(CF(0, 0.4, 7))
		R.cam.cut(V3(34, 5.2, 1), V3(0, 5.2, 1), 26)
		R.fx.banner("PRESS START", { color = C3(255, 220, 40), t = 0.45 })
		R.sound("UIClick")
		R.wait(0.55)
		R.fx.banner("PLAYER 1", { color = WHITE, t = 0.45 })
		R.sound("UIClick", nil, 0.8, 1.3)
		R.pose(full({ RS = { p = 3.0 }, LS = { p = 3.0 } }))
		R.sound("SlideWhistle", nil, 0.7, 1.4)
		R.wait(R.moveTo(R.rig, CF(0, 7.05, 7), 0.6, ES.Quad, ED.Out))
		R.wait(R.jump(R.rig, CF(0, 3, 3.2), 0.5, 2))
		-- temps 2 : course, saut, coup de poing dans le bloc "?"
		R.cam.move(V3(34, 5.2, -1.5), V3(0, 5.2, -1.5), 1.6, 26)
		R.wait(R.walk(CF(0, 3, -1.2), 0.4, "Run"))
		R.jump(R.rig, CF(0, 3, -2), 0.7, 4)
		R.anim(hold({ K(0, full({})), K(0.15, FIST_UP) }))
		R.wait(0.35)
		R.moveTo(qb, CF(0, 10.2, -2), 0.07)
		R.delay(0.08, function()
			R.moveTo(qb, CF(0, 9.6, -2), 0.1)
			usedBlock()
		end)
		R.sound("Pickup")
		R.cam.shake(0.2)
		R.fly(coin, { V3(0, 12.6, -2), V3(0, 11.4, -2) }, 0.6)
		R.fx.word("1UP!", V3(0, 12.6, -2), 1)
		R.fx.hearts(V3(0, 11, -2), 8)
		R.delay(0.7, function()
			R.show(coin, false, 0.15)
		end)
		R.wait(0.45)
		-- temps 3 : face caméra, il martèle sa manette puis la brandit
		R.fx.speedLines(0.35)
		R.sound("Whoosh", nil, 0.6)
		R.cam.cut(V3(-4.5, 3.6, -10.5), V3(0, 4.3, -2), 48)
		R.anim(jitter(MASH, 0.9, 0.06, 0.12, { "RS", "LS" }))
		R.fx.word("COMBO x99", V3(0, 6.3, -2.5), 0.8)
		R.sound("Combo")
		R.cam.move(V3(-4.2, 3.7, -11), V3(0, 4.6, -2), 1.4, 45)
		R.wait(0.9)
		R.anim(hold({ K(0, MASH), K(0.2, GAMER_WIN) }))
		R.fx.banner("HIGH SCORE!", { color = C3(255, 220, 40), t = 0.8 })
		R.fx.confetti(V3(0, 9, -2), 70, PIX, 6, 8)
		R.sound("LevelUp")
		R.wait(0.5)
		R.title()
		R.wait(0.6)
	end,
}
local ROOT_G = C3(40, 255, 110)
local SEAT_RH, SEAT_LH, SEAT_RJ = { p = 1.5, r = 0.55 }, { p = 1.5, r = 0.55 }, { ln = 0.08 }
local SEATED_TYPE = full({ RS = { p = 1.15, y = 0.4, r = -0.35 }, LS = { p = 1.15, y = 0.4, r = -0.35 }, RH = SEAT_RH, LH = SEAT_LH, RJ = SEAT_RJ })
local ARM_UP = full({ RS = { p = 3.1, r = 0.15 }, LS = { p = 0.9, r = 0.45 }, RH = SEAT_RH, LH = SEAT_LH, RJ = { ln = -0.22 } })
local ENTER = full({ RS = { p = 1.0, r = -0.15 }, LS = { p = 0.9, r = 0.45 }, RH = SEAT_RH, LH = SEAT_LH, RJ = { ln = 0.38 } })
local DEITY = full({ RS = { p = 0.9, y = -0.5, r = 1.25 }, LS = { p = 0.9, y = -0.5, r = 1.25 }, RJ = { ln = -0.16 }, RH = { r = 0.18 }, LH = { r = 0.18 } })

P.ITGuy_Legendary = {
	Caption = "Admin privileges: the entire building. Including you.",
	Location = "Sub-basement - Data Center Zero",
	Reveal = function(R)
		R.stage("Void")
		R.floor(V3(16, 0.2, 44), CF(0, -0.1, 0), C3(18, 22, 26), "DiamondPlate")
		-- 2 rangées de baies serveur, voyants éteints
		local strips = {}
		for row = 1, 5 do
			local z = -18 + row * 6
			strips[row] = {}
			for _, side in ipairs({ -1, 1 }) do
				local x = side * 7
				R.box(V3(2.6, 8, 2.6), CF(x, 4, z), C3(34, 36, 42), "Metal")
				for i = 1, 6 do
					local s = R.box(V3(0.12, 0.22, 2.0), CF(x - side * 1.33, 0.9 + i * 1.1, z), C3(40, 40, 46), "Neon")
					table.insert(strips[row], s)
				end
			end
		end
		-- 4 écrans holo (repliés)
		local SCR = {}
		local texts = { "sudo su", "rm -rf /meetings", "chmod 777 /building", "whoami" }
		for i, a in ipairs({ -118, -50, 50, 118 }) do
			local ang = rad(a)
			local pos = V3(5.4 * sin(ang), 7.2, -5.4 * cos(ang))
			local cf = CFrame.lookAt(pos, V3(0, 7.2, 0))
			local p = R.box(V3(0.1, 0.1, 0.08), cf, C3(30, 160, 80), "Glass", 0.35)
			SCR[i] = { part = p, cf = cf, labels = {
				R.text(p, texts[i], { Face = NF, Color = ROOT_G }),
				R.text(p, texts[i], { Face = NB, Color = ROOT_G }),
			} }
		end
		local alarm = true
		local lamp = R.light(V3(0, 9, 0), C3(255, 40, 40), 45, 3)
		R.onSkip(function()
			alarm = false
			lamp.Color = ROOT_G
			lamp.Brightness = 2
			for _, row in ipairs(strips) do
				for _, s in ipairs(row) do
					s.Color = ROOT_G
				end
			end
			for _, s in ipairs(SCR) do
				s.part.Size = V3(3.4, 2.2, 0.08)
				for _, l in ipairs(s.labels) do
					l.Text = "ROOT\nACCESS"
				end
			end
			R.transform(true)
			R.alpha(1)
			R.place(CF(0, 3, 0))
			R.pose(DEITY)
			R.cam.hero()
			R.fx.tint(C3(150, 255, 180))
		end)

		-- temps 1 : alarme rouge, travelling au ras du sol dans l'allée vide
		R.alpha(0)
		R.place(CF(0, 6.2, 0))
		R.fx.tint(C3(255, 90, 90))
		R.every(0.25, function(i)
			if alarm then
				lamp.Brightness = (i % 2 == 0) and 4 or 0.4
			end
		end)
		R.sound("Alarm", nil, 0.6)
		R.fx.banner("!! INTRUSION DETECTED !!", { color = C3(255, 60, 60), t = 1.0 })
		R.cam.cut(V3(0, 1.4, -23), V3(0, 4, 0), 62)
		R.cam.move(V3(0, 2.6, -13), V3(0, 5, 0), 1.7, 50)
		R.wait(1.5)
		-- temps 2 : les baies passent au vert en cascade, le code se compile en IT Guy
		alarm = false
		lamp.Color = ROOT_G
		lamp.Brightness = 2
		R.fx.tint(C3(150, 255, 180), 0.4)
		for row = 5, 1, -1 do
			R.delay((5 - row) * 0.12, function()
				for _, s in ipairs(strips[row]) do
					R.tween(s, 0.15, { Color = ROOT_G })
				end
				R.sound("Electric", nil, 0.35, 1 + (5 - row) * 0.1)
			end)
		end
		R.fx.rain({ Colors = { ROOT_G, C3(20, 140, 60) }, Size = V3(0.1, 1.4, 0.1), Material = "Neon", Count = 70 }, 5)
		R.wait(0.5)
		R.fx.swirl(V3(0, 6, 0), 3.2, 6, { ROOT_G, C3(10, 90, 40), WHITE })
		R.fx.implode(V3(0, 6, 0), 6, { ROOT_G })
		R.sound("PowerUp")
		R.cam.move(V3(0, 5.4, -9.5), V3(0, 6, 0), 1.0, 48)
		R.wait(0.6)
		R.teleport(R.rig, CF(0, 6.2, 0), "glitch")
		R.alpha(1, 0.15)
		R.fx.glitch()
		R.anim(jitter(SEATED_TYPE, 8, 0.07, 0.16, { "RS", "LS" }))
		R.wait(0.5)
		-- temps 3 : 4 écrans holo s'ouvrent autour de lui, caméra en orbite
		R.cam.orbit(V3(0, 6.5, 0), 11, 1.2, -0.7, 0.55, 2.0, 55, 48)
		for i, s in ipairs(SCR) do
			R.tween(s.part, 0.22, { Size = V3(3.4, 2.2, 0.08) }, ES.Back, ED.Out)
			R.fx.sparks(s.cf.Position, 8, ROOT_G)
			R.sound("UIClick", nil, 0.7, 1 + i * 0.1)
			R.wait(0.35)
		end
		R.wait(0.3)
		-- temps 4 : ralenti, bras levé... ENTRÉE
		R.slowmo(0.3)
		R.anim(hold({ K(0, SEATED_TYPE), K(0.35, ARM_UP) }))
		R.cam.move(V3(1.6, 3.2, -6), V3(0, 6.6, 0), 0.4, 64)
		R.wait(0.42)
		R.slowmo(1)
		R.anim(hold({ K(0, ARM_UP), K(0.07, ENTER) }))
		R.wait(0.07)
		R.freeze(0.22)
		R.sound("BigImpact")
		R.sound("Electric")
		R.fx.bigImpact(V3(0, 5.6, -1.4), V3(0, -1, 0), 1.4, ROOT_G)
		R.fx.shockwave(V3(0, 5.6, 0), 16, ROOT_G)
		for _, s in ipairs(SCR) do
			R.fx.lightning(s.cf.Position, V3(0, 5.8, -1.3), ROOT_G)
			for _, l in ipairs(s.labels) do
				l.Text = "ROOT\nACCESS"
			end
		end
		R.transform(true)
		R.cam.shake(0.8)
		R.fx.flash(ROOT_G, 0.03, 0.05, 0.35)
		R.wait(0.6)
		-- temps 5 : il redescend, pose de divinité, la caméra s'élève
		R.moveTo(R.rig, CF(0, 3, 0), 0.55, ES.Quad, ED.In)
		R.anim(hold({ K(0, ENTER), K(0.4, DEITY) }))
		R.cam.crane(V3(0, 4.5, 0), 0.8, 5, 10, 1.6, { fov = 50 })
		R.wait(0.55)
		R.fx.quake(V3(0, 0, 0), 10, ROOT_G)
		R.sound("GroundSlam")
		R.fx.rays(ROOT_G)
		R.wait(0.9)
		R.title()
		R.wait(0.6)
	end,
}

------------------------------------------------------------------------
-- ACCOUNTANT
------------------------------------------------------------------------
local NOIR_RED = C3(200, 20, 30)
local MAGNIFY = full({ RS = { p = 1.9, y = 0, r = -0.5 }, LS = { p = 0.45, r = -0.1 }, RJ = { ln = 0.06 }, RH = { p = 0.05 }, LH = { p = -0.05 } })
local INSPECT = full({ RS = { p = 1.3, y = 0.3, r = -0.3 }, LS = { p = 0.6, r = -0.15 }, RJ = { ln = 0.42, tw = -0.35 }, RH = { p = 0.1 }, LH = { p = -0.2 } })
local TIP_HAT = full({ RS = { p = 2.75, y = 0.8, r = -0.4 }, LS = { p = 0.3, r = 0.08 }, RJ = { ln = 0.12, sd = -0.05 }, RH = { p = -0.1, r = 0.1 }, LH = { p = 0.15, r = 0.1 } })

P.Accountant_Rare = {
	Caption = "The numbers never lie. People do. Every receipt is a clue.",
	Location = "Accounts Payable - Midnight. Raining. Always raining.",
	Reveal = function(R)
		R.stage("Room", { dark = true, color = C3(70, 64, 58), floor = C3(52, 42, 34), w = 22, d = 18, h = 12 })
		-- fenêtre à stores derrière lui (lumière de rue blafarde)
		R.box(V3(7, 6, 0.1), CF(-1, 6, 8.8), C3(200, 210, 220), "Neon", 0.2)
		for i = 0, 9 do
			R.box(V3(7.2, 0.32, 0.12), CF(-1, 3.3 + i * 0.6, 8.65), C3(30, 28, 26))
		end
		R.light(V3(-1, 6, 7.4), C3(190, 205, 230), 22, 2)
		-- bureau, lampe de banquier, ventilateur de plafond
		R.box(V3(3, 0.2, 2), CF(2.6, 2.6, -1.4), C3(70, 45, 30), "Wood")
		R.box(V3(2.8, 2.5, 1.8), CF(2.6, 1.25, -1.4), C3(55, 36, 24), "Wood")
		R.box(V3(0.12, 0.9, 0.12), CF(3.6, 3.15, -1.8), C3(200, 160, 70), "Metal")
		R.box(V3(1.2, 0.35, 0.6), CF(3.6, 3.65, -1.8), C3(30, 120, 60), "Glass")
		R.light(V3(3.6, 3.3, -1.8), C3(255, 220, 160), 10, 2)
		local fan = R.model({
			{ Size = V3(0.5, 0.3, 0.5), CFrame = CF(), Color = C3(60, 50, 40) },
			{ Size = V3(6, 0.08, 0.7), CFrame = CF(), Color = C3(80, 60, 40), Material = "Wood" },
			{ Size = V3(0.7, 0.08, 6), CFrame = CF(), Color = C3(80, 60, 40), Material = "Wood" },
		}, CF(0, 11, 1))
		R.spin(fan, 5, 12)
		-- le reçu suspect
		local receipt = R.box(V3(0.9, 0.03, 1.4), CF(-0.5, 10, -3), C3(245, 240, 225))
		R.text(receipt, "LUNCH ... $4.20\nPENS ... $900\nYACHT ... $2M", { Face = NT, Color = C3(40, 40, 40) })
		-- grosse loupe de détective dans la main droite (verre face caméra quand le bras est levé)
		local gspecs = { { Size = V3(0.9, 0.2, 0.2), CFrame = CF(), Color = C3(70, 40, 25), Material = "Wood", Shape = "Cyl" } }
		for k = 0, 13 do
			local an = k * 2 * PI / 14
			gspecs[#gspecs + 1] = { Size = V3(0.1, 0.14, 0.42), CFrame = CF(-1.35, cos(an) * 0.85, sin(an) * 0.85) * ANG(an, 0, 0), Color = GOLD, Material = "Metal" }
		end
		local glass = R.model(gspecs, CF(0, -20, 0))
		R.attach(glass, "RightHand", CF(0, -0.3, 0) * ANG(0, 0, PI / 2))
		R.onSkip(function()
			R.show(glass, false)
			R.teleport(receipt, CF(2.3, 2.72, -1.4))
			R.place(CF(0, 3, 0))
			R.pose(TIP_HAT)
			R.fx.saturation(-0.6)
			R.cam.cut(V3(-4.2, 2.8, -6.4), V3(0, 4.3, 0), 40)
		end)

		-- temps 1 : noir et blanc, œil géant derrière la loupe, recul lent ; un reçu tombe en virevoltant
		R.fx.saturation(-1)
		R.fx.contrast(0.35)
		R.sound("Water", nil, 0.25, 0.6)
		R.pose(MAGNIFY)
		R.cam.cut(V3(0.3, 4.7, -7.2), V3(0.1, 4.5, 0), 26)
		R.wait(0.5)
		R.cam.move(V3(-2.5, 4.2, -7.5), V3(0.6, 4, 0), 1.4, 42)
		R.fly(receipt, { V3(-0.5, 10, -3), V3(1.2, 7, -2.2), V3(0.4, 5, -1.6), V3(2.3, 2.72, -1.4) }, 1.3)
		R.wait(0.9)
		R.anim(hold({ K(0, MAGNIFY), K(0.3, INSPECT) }))
		R.wait(0.6)
		-- temps 2 : verdict en rouge, il se redresse et touche le bord de son fedora
		R.fx.banner("EMBEZZLEMENT.", { color = NOIR_RED, t = 0.9 })
		R.sound("Thud")
		R.cam.punch(-5)
		R.wait(0.4)
		R.anim(hold({ K(0, INSPECT), K(0.25, TIP_HAT) }))
		R.show(glass, false, 0.15)
		R.wait(R.cam.whip(V3(-4.2, 2.8, -6.4), V3(0, 4.3, 0)))
		R.fx.saturation(-0.6, 0.6)
		R.wait(0.5)
		R.title()
		R.wait(0.5)
	end,
}
local CASH = C3(110, 200, 90)
local PHONE_EAR = full({ LS = { p = 2.55, y = 1.0, r = -0.8 }, RS = { p = 0.35, r = 0.2 }, RJ = { ln = 0.05, sd = 0.05 }, RH = { r = 0.12 }, LH = { r = 0.12 } })
local BUY_UP = full({ LS = PHONE_EAR.LS, RS = { p = 3.0, r = 0.15 }, RJ = { ln = -0.12, sd = 0.08 }, RH = { p = -0.15, r = 0.15 }, LH = { p = 0.15, r = 0.15 } })
local BUY_DN = full({ LS = PHONE_EAR.LS, RS = { p = 1.2, r = -0.2 }, RJ = { ln = 0.3, tw = -0.2 }, RH = { p = 0.3, r = 0.15 }, LH = { p = -0.2, r = 0.15 } })
local KNEE_SLIDE = full({ RS = { p = 0.6, r = 2.2 }, LS = { p = 0.6, r = 2.2 }, RJ = { ln = -0.45 }, RH = { p = -1.25, r = 0.15 }, LH = { p = -1.25, r = 0.15 } })
local SUSPENDERS = full({ RS = { p = 0.4, y = 0.3, r = -0.4 }, LS = { p = 0.4, y = 0.3, r = -0.4 }, RJ = { ln = -0.15 }, RH = { r = 0.15 }, LH = { r = 0.15 } })
local WOLF_POINT = full({ RS = { p = 1.6, y = 0.1 }, LS = { p = 0.4, y = 0.3, r = -0.4 }, RJ = { tw = 0.3, ln = -0.05 }, RH = { p = -0.25, r = 0.15 }, LH = { p = 0.3, r = 0.15 } })

P.Accountant_Epic = {
	Caption = "Buy low. Sell high. Yell constantly into a brick phone.",
	Location = "Trading Floor - Opening Bell",
	Reveal = function(R)
		R.stage("Room", { color = C3(22, 30, 46), floor = C3(36, 38, 46), w = 30, d = 26, h = 15 })
		-- grand tableau de cours derrière lui
		R.box(V3(18, 8.5, 0.3), CF(0, 7.2, 10.6), C3(8, 12, 10))
		for i = 1, 4 do
			R.box(V3(17.6, 0.05, 0.05), CF(0, 3.4 + i * 1.6, 10.43), C3(30, 60, 40))
		end
		local pts = { V3(7.5, 4.2, 10.4), V3(5.5, 5.2, 10.4), V3(3.5, 4.6, 10.4), V3(1.5, 6.2, 10.4), V3(-0.5, 5.7, 10.4), V3(-2.5, 7.6, 10.4), V3(-4.5, 8.8, 10.4), V3(-7, 10.8, 10.4) }
		local segs = {}
		for i = 1, #pts - 1 do
			segs[i] = seg(R, pts[i], pts[i + 1], 0.28, C3(60, 255, 110))
			R.show(segs[i], false)
		end
		local tip = R.ball(0.9, pts[#pts], C3(60, 255, 110), "Neon")
		R.show(tip, false)
		local tk = R.box(V3(28, 1.1, 0.2), CF(0, 12.6, 10.6), C3(5, 5, 5))
		R.text(tk, "▲ STONKS +420%   ▲ COFFEE +12%   ▼ MONDAYS -99%   ▲ SNACKS +69%", { Face = NF, Color = C3(255, 220, 60) })
		-- bureaux de traders avec écrans
		for _, x in ipairs({ -9, 9 }) do
			R.box(V3(5, 2.5, 2.5), CF(x, 1.25, 2), C3(50, 50, 60))
			for k = -1, 1 do
				R.box(V3(1.4, 1, 0.12), CF(x + k * 1.5, 3.2, 2.6), C3(10, 60, 25), "Neon")
			end
		end
		R.place(CF(0, 3, 3))
		R.mark(CF(0, 3, -3))
		R.onSkip(function()
			for _, s in ipairs(segs) do
				R.show(s, true)
			end
			R.show(tip, true)
			R.place(CF(0, 3, -3))
			R.pose(WOLF_POINT)
			R.cam.cut(V3(-2.6, 3.4, -10), V3(0, 4.2, -3), 45)
		end)

		-- temps 1 : le téléphone brique sonne, il hurle BUY! BUY! BUY!
		R.pose(PHONE_EAR)
		R.cam.cut(V3(-1.8, 4.7, -1.2), V3(0, 4.5, 3), 46)
		R.sound("Ding", nil, 0.6, 1.8)
		R.fx.word("RING RING!", V3(-1.2, 5.6, 2.5), 0.7)
		R.wait(0.5)
		for i = 1, 3 do
			R.anim(hold({ K(0, BUY_DN), K(0.12, BUY_UP) }))
			R.fx.word("BUY!", V3(1.2 - i * 1.1, 5.6 + i * 0.5, 2), 0.8 + i * 0.25, "Heavy")
			R.sound("PunchHeavy", nil, 0.5, 1.1 + i * 0.1)
			R.cam.punch(-5 - i * 2)
			R.cam.shake(0.15 + i * 0.1)
			R.wait(0.3)
			R.anim(hold({ K(0, BUY_UP), K(0.1, BUY_DN) }))
			R.wait(0.08)
		end
		-- temps 2 : la courbe s'envole, STONKS, il jette la liasse
		R.wait(R.cam.whip(V3(0, 5.3, -12), V3(0, 5.8, 6)))
		for i, s in ipairs(segs) do
			R.show(s, true, 0.05)
			R.sound("Ding", nil, 0.4, 0.8 + i * 0.12)
			R.wait(0.09)
		end
		R.show(tip, true)
		R.fx.sparks(pts[#pts], 14, CASH)
		R.fx.banner("STONKS +420%", { color = C3(80, 255, 120), t = 0.9 })
		R.anim("Throw")
		R.wait(0.25)
		R.fx.money(V3(0, 3, 0), 3.5, 80)
		R.sound("Pickup")
		R.wait(0.5)
		-- temps 3 : glissade à genoux dans la pluie de billets, claquement de bretelles
		R.wait(R.walk(CF(0, 3, 1.5), 0.3, "Run"))
		R.pose(KNEE_SLIDE)
		R.moveTo(R.rig, CF(0, 1.9, -3), 0.9, ES.Quad, ED.Out)
		R.cam.follow(R.rig, V3(-0.8, 0.6, -6.5), 1.0, { look = V3(0, 1, 0), fov = 55 })
		R.sound("Dash")
		local sliding = true
		R.every(0.08, function()
			if sliding then
				R.fx.sparks(R.pos(R.rig) - V3(0, 1.7, 0), 3, GOLD)
			end
		end)
		R.wait(0.95)
		sliding = false
		R.moveTo(R.rig, CF(0, 3, -3), 0.2, ES.Back, ED.Out)
		R.anim(hold({ K(0, KNEE_SLIDE), K(0.2, SUSPENDERS) }))
		R.wait(0.3)
		R.fx.word("SNAP!", V3(0.8, 4.5, -4), 0.6)
		R.sound("Squeak", nil, 0.7, 1.2)
		R.anim(hold({ K(0, SUSPENDERS), K(0.15, WOLF_POINT) }))
		R.cam.move(V3(-2.6, 3.4, -10), V3(0, 4.2, -3), 0.6, 45)
		R.wait(0.5)
		R.title()
		R.wait(0.6)
	end,
}

local LAPEL = full({ RS = { p = 0.35, r = 0.3 }, LS = { p = 1.15, y = 1.0, r = -0.55 }, RJ = { ln = -0.1, sd = 0.06 }, RH = { p = -0.1, r = 0.15 }, LH = { p = 0.2, r = 0.1 } })
local CHARGE_END = full({ RJ = { ln = 0.5 }, RS = { p = -0.5, r = 0.4 }, LS = { p = -0.5, r = 0.4 }, RH = { p = 0.5, r = 0.2 }, LH = { p = -0.4, r = 0.2 } })
local CANE_UP = full({ RS = { p = 2.3, r = 0.1 }, LS = { p = 0.3, r = 0.2 }, RJ = { ln = -0.1 } })
local CANE_DOWN = full({ RS = { p = 0.3, r = 0.25 }, LS = { p = 0.3, r = 0.2 }, RJ = { ln = 0.15 }, RH = { p = 0.2, r = 0.2 }, LH = { p = -0.15, r = 0.2 } })
-- course tête baissée, cornes en avant
local function chargeRun(dur)
	local f = { K(0, full({ RS = { p = -0.6 }, LS = { p = -0.6 }, RJ = { ln = 0.65 } })) }
	local t, s = 0, 1
	while t < dur do
		t += 0.11
		s = -s
		f[#f + 1] = K(t, full({ RS = { p = -0.7 + 0.25 * s, r = 0.2 }, LS = { p = -0.7 - 0.25 * s, r = 0.2 }, RJ = { ln = 0.65, tw = 0.08 * s }, RH = { p = 1.1 * s }, LH = { p = -1.1 * s } }))
	end
	return f
end
-- grattage du sol avec le sabot (pied droit), tête baissée
local PAW = { K(0, CHARGE_END) }
for i = 1, 3 do
	PAW[#PAW + 1] = K(i * 0.26 - 0.13, full({ RJ = { ln = 0.45 }, RS = { p = -0.3, r = 0.3 }, LS = { p = -0.3, r = 0.3 }, RH = { p = -0.85 }, LH = { p = 0.15 } }))
	PAW[#PAW + 1] = K(i * 0.26, full({ RJ = { ln = 0.45 }, RS = { p = -0.3, r = 0.3 }, LS = { p = -0.3, r = 0.3 }, RH = { p = 0.35 }, LH = { p = 0.15 } }))
end
hold(PAW)

P.Accountant_Legendary = {
	Caption = "When he charges, the market goes up. And so does your blood pressure.",
	Location = "Stock Exchange - Gold Vault Level",
	Reveal = function(R)
		local GOLD2 = C3(255, 225, 120)
		local GREEN = C3(60, 255, 110)
		R.stage("Studio", { color = C3(10, 30, 20), floor = C3(24, 54, 36) })
		local disk = R.cyl(0.1, 26, V3(0, 0.06, 0), C3(30, 90, 55), "Marble")
		-- mur du coffre-fort et ses deux portes
		local METAL = C3(60, 66, 70)
		R.box(V3(11, 14, 1), CF(-9.5, 7, 10.5), METAL, "Metal")
		R.box(V3(11, 14, 1), CF(9.5, 7, 10.5), METAL, "Metal")
		R.box(V3(8, 4, 1), CF(0, 12, 10.5), METAL, "Metal")
		local doors = {}
		for _, sx in ipairs({ -1, 1 }) do
			doors[sx] = R.model({
				{ Size = V3(4, 10, 0.8), CFrame = CF(), Color = C3(150, 120, 50), Material = "Metal" },
				{ Size = V3(0.3, 2.6, 2.6), CFrame = CF(0, 0.5, -0.5) * ANG(0, PI / 2, 0), Color = GOLD, Material = "Metal", Shape = "Cyl" },
				{ Size = V3(0.2, 0.2, 2.2), CFrame = CF(0, 0.5, -0.7), Color = C3(120, 90, 30), Material = "Metal" },
			}, CF(sx * 2, 5, 10))
		end
		-- l'intérieur du coffre : lumière dorée, tas de pièces
		R.box(V3(10, 12, 1), CF(0, 6, 19.5), C3(80, 66, 30), "Metal")
		R.light(V3(0, 5, 15), GOLD, 26, 2.5)
		for i = 1, 9 do
			R.ball(R.rand(1.5, 2.6), V3(R.rand(-3.5, 3.5), 0.4, R.rand(15.5, 18.5)), GOLD, "Foil")
		end
		local ticker = R.text(R.box(V3(8, 1, 0.2), CF(0, 11.2, 9.95), C3(6, 10, 8)), "MARKET CLOSED", { Face = NF, Color = C3(255, 80, 80) })
		-- cloche d'ouverture
		local podium = R.box(V3(1.8, 3.2, 1.8), CF(6.5, 1.6, -1), C3(90, 60, 35), "Wood")
		R.text(podium, "OPENING\nBELL", { Face = NF, Color = GOLD })
		R.ball(2.2, V3(6.5, 4.4, -1), C3(205, 160, 60), "Metal")
		R.box(V3(0.5, 0.6, 0.5), CF(6.5, 5.6, -1), C3(120, 90, 40), "Metal")
		-- la flèche BULL RUN (repliée sous le sol)
		local A0, A1 = V3(-9, -0.9, 6), V3(8, 17, 6)
		local dir = (A1 - A0).Unit
		local L = (A1 - A0).Magnitude
		local nrm = V3(-dir.Y, dir.X, 0)
		local arrow = R.box(V3(1.4, 1.4, 0.2), CFrame.lookAt(A0, A1), GREEN, "Neon")
		local heads = {
			seg(R, A1, A1 - (dir + nrm) * 1.8, 1.4, GREEN),
			seg(R, A1, A1 - (dir - nrm) * 1.8, 1.4, GREEN),
		}
		for _, h in ipairs(heads) do
			R.show(h, false)
		end
		local function arrowFull()
			arrow.Size = V3(1.4, 1.4, L)
			R.teleport(arrow, CFrame.lookAt((A0 + A1) / 2, A1))
			for _, h in ipairs(heads) do
				R.show(h, true)
			end
		end
		R.onSkip(function()
			R.teleport(doors[-1], CF(-6.2, 5, 10))
			R.teleport(doors[1], CF(6.2, 5, 10))
			disk.Color = C3(200, 150, 40)
			disk.Material = Enum.Material.Metal
			R.fx.dark(0)
			ticker.Text = "BULL RUN +1000%"
			arrowFull()
			R.transform(true)
			R.place(CF(0, 3, 0))
			R.pose(LAPEL)
			R.cam.cut(V3(-3.5, 2.6, -8), V3(0, 4.2, 0), 42)
		end)

		-- temps 1 : dans le noir, la cloche d'ouverture sonne trois fois
		R.place(CF(0, 3, 16))
		R.fx.dark(0.45)
		local spot = R.spot(V3(6.5, 16, -7), V3(6.5, 4, -1), { color = C3(255, 230, 170), width = 3 })
		R.cam.cut(V3(3.8, 5.2, -6.5), V3(6.5, 4.5, -1), 38)
		R.wait(0.25)
		for i = 1, 3 do
			R.sound("Ding", nil, 0.9, 0.85)
			R.fx.word("DING!", V3(6.5 + R.rand(-1, 1), 6.2 + i * 0.4, -1.5), 0.7 + i * 0.15)
			R.cam.shake(0.2)
			R.fx.ring(V3(6.5, 4.4, -1), V3(0, 0, -1), 3, GOLD)
			R.wait(0.38)
		end
		-- temps 2 : les portes du coffre s'ouvrent, il charge vers la caméra au ras du sol
		spot.off(0.2)
		R.fx.dark(0, 0.3)
		ticker.Text = "MARKET OPEN"
		ticker.TextColor3 = GREEN
		R.sound("Rumble")
		R.cam.shake(0.4)
		R.cam.cut(V3(0.6, 1.0, -7.5), V3(0, 3.6, 6), 64)
		R.moveTo(doors[-1], CF(-6.2, 5, 10), 0.7)
		R.moveTo(doors[1], CF(6.2, 5, 10), 0.7)
		R.fx.smoke(V3(0, 3, 9.5), 14, C3(255, 230, 160), 3)
		R.fx.light(V3(0, 5, 9), GOLD, 30, 4, 0.8)
		R.wait(0.45)
		R.anim(chargeRun(1.2))
		R.moveTo(R.rig, CF(0, 3, 0), 0.9, ES.Quad, ED.In)
		local charging = true
		R.every(0.09, function()
			if charging then
				R.fx.dust(R.pos(R.rig) - V3(0, 2.9, 0), 2)
			end
		end)
		R.wait(0.9)
		charging = false
		R.anim(hold({ K(0, full({ RJ = { ln = 0.65 }, RS = { p = -0.7 }, LS = { p = -0.7 } })), K(0.1, CHARGE_END) }))
		R.freeze(0.28)
		R.sound("BigImpact")
		R.fx.bigImpact(V3(0, 2, -1.5), V3(0, 0, -1), 1.3, GOLD)
		R.fx.word("CHARGE!", V3(0, 6.5, -1), 1.3, "Heavy")
		R.cam.shake(0.9)
		R.wait(0.3)
		-- temps 3 : gros plan au ralenti, il souffle de la fumée par les naseaux et gratte le sol
		R.slowmo(0.45)
		R.transform(true)
		R.cam.cut(V3(1.4, 4.1, -5.2), V3(0, 3.9, -0.4), 36)
		R.cam.move(V3(1.0, 4.0, -4.3), V3(0, 3.9, -0.4), 0.7, 32)
		R.anim(PAW)
		for i = 1, 2 do
			R.fx.smoke(V3(i == 1 and -0.15 or 0.15, 4.15, -0.75), 4, WHITE, 0.6)
			R.sound("Whoosh", nil, 0.6, 0.6)
			R.wait(0.28)
		end
		R.slowmo(1)
		-- temps 4 : BULL RUN — la flèche verte jaillit, pluie d'or, la canne frappe et le sol devient or
		R.wait(R.cam.whip(V3(-1, 2, -11), V3(0, 6, 2)))
		ticker.Text = "BULL RUN +1000%"
		R.moveTo(arrow, CFrame.lookAt((A0 + A1) / 2, A1), 0.9, ES.Quad, ED.Out)
		R.tween(arrow, 0.9, { Size = V3(1.4, 1.4, L) }, ES.Quad, ED.Out)
		R.delay(0.9, function()
			for _, h in ipairs(heads) do
				R.show(h, true, 0.1)
			end
			R.fx.sparks(A1, 20, GREEN)
		end)
		R.sound("PowerUp")
		R.cam.crane(V3(0, 4, 0), 1.5, 9, 15, 1.8, { fov = 56 })
		for i = 0, 2 do
			R.delay(i * 0.25, function()
				R.fx.coins(V3(0, 1, 0), 14)
			end)
		end
		R.fx.rain({ Colors = { GOLD, GOLD2 }, Size = V3(0.2, 1.1, 1.1), Shape = "Cyl", Material = "Metal", Count = 35 }, 3)
		R.anim(hold({ K(0, LAPEL), K(0.15, CANE_UP), K(0.32, CANE_DOWN) }))
		R.wait(0.32)
		R.sound("GroundSlam")
		R.fx.shockwave(V3(0.6, 0.1, -0.6), 18, GOLD)
		R.tween(disk, 0.5, { Color = C3(200, 150, 40) })
		disk.Material = Enum.Material.Metal
		R.fx.banner("BULL RUN!", { color = GOLD, t = 0.9 })
		R.wait(1.2)
		-- temps 5 : ralenti, appuyé sur la canne, main sur le revers, reflet du monocle
		R.slowmo(0.5)
		R.anim(hold({ K(0, CANE_DOWN), K(0.3, LAPEL) }))
		R.cam.orbit(V3(0, 4.2, 0), 12, 0.2, -0.55, 0.15, 1.0, 44, 40)
		R.fx.rays(C3(255, 240, 190))
		R.wait(0.35)
		R.fx.twinkle(V3(-0.25, 4.6, -0.65))
		R.sound("Ding", nil, 0.5, 2)
		R.wait(0.4)
		R.slowmo(1)
		R.title()
		R.wait(0.6)
	end,
}

------------------------------------------------------------------------
-- CEO
------------------------------------------------------------------------
local SIT_TYPE = full({ RS = { p = 1.2, y = 0.3, r = -0.3 }, LS = { p = 1.2, y = 0.3, r = -0.3 }, RH = { p = 1.57 }, LH = { p = 1.57 }, RJ = { ln = 0.15 } })
local SIP = full({ LS = { p = 2.3, y = 0.9, r = -0.55 }, RS = { p = 0.3, r = 0.2 }, RJ = { ln = -0.05 }, RH = { r = 0.1 }, LH = { r = 0.1 } })
local SHRUG = full({ RS = { p = 0.7, y = -0.6, r = 0.75 }, LS = { p = 0.7, y = -0.6, r = 0.75 }, RJ = { ln = -0.08, sd = 0.05 }, RH = { r = 0.12 }, LH = { r = 0.12 } })

P.CEO_Rare = {
	Caption = "Move fast and break the printer. Worth 40 billion. Wears sandals.",
	Location = "Mom's Garage - Day 1 of the Startup",
	Reveal = function(R)
		R.stage("Night")
		local WARM = C3(255, 205, 140)
		local wall, flr = C3(185, 175, 160), C3(120, 118, 112)
		-- le garage
		R.floor(V3(15, 0.2, 13), CF(0, -0.08, 1), flr, "Concrete")
		R.box(V3(15, 9.5, 0.5), CF(0, 4.75, 7.5), wall)
		R.box(V3(0.5, 9.5, 13), CF(-7.5, 4.75, 1), wall)
		R.box(V3(0.5, 9.5, 13), CF(7.5, 4.75, 1), wall)
		R.box(V3(16, 0.5, 13.5), CF(0, 9.75, 1), C3(90, 70, 60))
		R.box(V3(16, 2.5, 0.5), CF(0, 8.25, -5.5), wall)
		R.box(V3(1.8, 7, 0.5), CF(-7.1, 3.5, -5.5), wall)
		R.box(V3(1.8, 7, 0.5), CF(7.1, 3.5, -5.5), wall)
		local door = R.box(V3(12.6, 7, 0.3), CF(0, 3.5, -5.6), C3(225, 225, 230), "Metal")
		R.text(door, "GARAGE HQ\nKEEP OUT", { Face = NF, Color = C3(200, 40, 40) })
		-- la start-up : table pliante, portable, caisse, tableau blanc, cartons de pizza, guirlande
		R.box(V3(4.4, 0.18, 2.2), CF(0, 2.55, -1.6), C3(200, 200, 205))
		for _, x in ipairs({ -2, 2 }) do
			R.box(V3(0.12, 2.5, 0.12), CF(x, 1.25, -1.6), C3(90, 90, 95), "Metal")
		end
		R.box(V3(1.6, 0.08, 1.1), CF(0, 2.68, -1.5), C3(190, 190, 200), "Metal")
		R.box(V3(1.6, 1.05, 0.08), CF(0, 3.2, -2.05), C3(190, 190, 200), "Metal")
		R.ball(0.25, V3(0, 3.2, -2.1), WHITE, "Neon")
		R.box(V3(2, 1.2, 1.8), CF(0, 0.6, 0.3), C3(150, 110, 60), "Wood")
		local wb = R.box(V3(6.5, 3.6, 0.12), CF(-2.5, 5.2, 7.15), WHITE)
		R.text(wb, "WORLD DOMINATION\nv0.1 -> ??? -> $$$", { Face = NF, Color = C3(30, 60, 200) })
		for i = 0, 3 do
			R.box(V3(1.8, 0.25, 1.8), CF(5.4, 0.15 + i * 0.27, 5) * ANG(0, i * 0.2, 0), C3(220, 190, 140))
		end
		for i = 0, 8 do
			R.ball(0.3, V3(-6 + i * 1.5, 9.2 - (i % 2) * 0.3, -4.6), WARM, "Neon")
		end
		R.light(V3(0, 8.5, 1), WARM, 30, 3.2)
		R.light(V3(0, 5, -3.5), WARM, 16, 1.2)
		R.mark(CF(0, 3, 0.3))
		R.onSkip(function()
			door.Size = V3(12.6, 0.4, 0.3)
			R.teleport(door, CF(0, 6.8, -5.6))
			R.place(CF(0, 3, 0.3))
			R.pose(SHRUG)
			R.cam.cut(V3(-3.2, 5.4, -7.2), V3(0, 4.2, 0.3), 44)
			R.fx.tint(C3(255, 228, 200))
		end)

		-- temps 1 : porte fermée, tap-tap-tap... la porte de garage s'enroule et dévoile la start-up
		R.place(CF(0, 2.7, 0.3))
		R.anim(jitter(SIT_TYPE, 6, 0.08, 0.14, { "RS", "LS" }))
		R.cam.cut(V3(0, 4, -16), V3(0, 3.8, 0), 48)
		R.fx.word("tap tap tap...", V3(0, 4.5, -6.3), 0.55)
		R.sound("UIClick", nil, 0.5, 1.3)
		R.wait(0.6)
		R.sound("Rumble", nil, 0.6, 1.4)
		R.tween(door, 0.9, { Size = V3(12.6, 0.4, 0.3) }, ES.Quad, ED.In)
		R.moveTo(door, CF(0, 6.8, -5.6), 0.9, ES.Quad, ED.In)
		R.fx.light(V3(0, 4, -4.5), WARM, 28, 3, 1.2)
		R.fx.tint(C3(255, 228, 200), 0.8)
		R.cam.move(V3(0, 4.2, -9.5), V3(0, 3.6, 0), 1.5, 46)
		R.wait(1.0)
		-- temps 2 : 1 milliard d'utilisateurs ; il se lève, sirote son smoothie, hausse les épaules
		local bb = R.billboard("1,000,000,000 USERS", V3(0, 4.7, -1.8), { size = 5, Color = C3(80, 200, 255) })
		R.sound("LevelUp")
		R.fx.flash(WHITE, 0.03, 0.03, 0.2)
		R.moveTo(R.rig, CF(0, 3, 0.3), 0.25, ES.Back, ED.Out)
		R.anim(hold({ K(0, SIT_TYPE), K(0.25, full({ RS = { p = 0.2 }, LS = { p = 0.2 } })), K(0.55, SIP) }))
		R.fx.hearts(V3(0, 5, 0.3), 14, C3(60, 120, 255))
		R.fx.word("+999K", V3(2.2, 6.2, 0), 0.7)
		R.delay(0.25, function()
			R.fx.word("LIKE!", V3(-2.2, 6.6, 0), 0.7)
		end)
		R.cam.move(V3(-3.2, 5.4, -7.2), V3(0, 4.2, 0.3), 1.2, 44)
		R.wait(0.6)
		R.sound("Water", nil, 0.5, 1.6)
		R.wait(0.4)
		R.anim(hold({ K(0, SIP), K(0.22, SHRUG) }))
		R.fx.word("MEH.", V3(0, 6.3, -0.5), 0.6)
		R.wait(0.4)
		R.destroy(bb.Parent or bb)
		R.title()
		R.wait(0.5)
	end,
}

local STEEPLE = full({ RS = { p = 1.25, y = 0.6, r = -0.5 }, LS = { p = 1.25, y = 0.6, r = -0.5 }, RJ = { ln = 0.04 }, RH = { r = 0.06 }, LH = { r = 0.06 } })
local CLICK = full({ RS = { p = 1.5, y = 0.1, r = -0.05 }, LS = { p = 0.9, y = 0.6, r = -0.45 }, RJ = { tw = 0.15 }, RH = { r = 0.06 }, LH = { r = 0.06 } })
local REVEAL_UP = full({ LS = { p = 2.45, y = 0.2, r = -0.15 }, RS = { p = 0.15, y = 0.5, r = -0.1 }, RJ = { ln = -0.08, sd = -0.05 }, RH = { r = 0.08 }, LH = { p = 0.2, r = 0.1 } })

P.CEO_Epic = {
	Caption = "It's not a stapler. It's a revolution. Available in black.",
	Location = "Annual Keynote - Main Hall",
	Reveal = function(R)
		R.stage("Void")
		local screen = R.box(V3(22, 11, 0.4), CF(0, 8, 11), C3(4, 4, 7))
		local label = R.text(screen, "", { Face = NF, Color = WHITE, Bg = C3(4, 4, 7) })
		local glow = R.light(V3(0, 8, 9.5), C3(220, 225, 255), 34, 0.6)
		R.cyl(0.06, 16, V3(0, 0.03, 1), C3(26, 26, 30), "Glass")
		-- le public en silhouettes
		for row = 0, 2 do
			for i = -7, 7 do
				local x = i * 1.7 + (row % 2) * 0.85
				local z = -8.5 - row * 2.2
				R.ball(1.15, V3(x, 3.6 + row * 0.45, z), C3(14, 14, 18))
				R.box(V3(1.5, 1.4, 0.9), CF(x, 2.5 + row * 0.45, z), C3(14, 14, 18))
			end
		end
		-- la "révolution" : une agrafeuse noire
		local stapler = R.model({
			{ Size = V3(0.36, 0.16, 1.2), CFrame = CF(), Color = C3(18, 18, 20) },
			{ Size = V3(0.32, 0.2, 1.1), CFrame = CF(0, 0.2, 0.04) * ANG(rad(-6), 0, 0), Color = C3(28, 28, 32) },
			{ Size = V3(0.06, 0.06, 0.5), CFrame = CF(0, 0.31, -0.2), Color = C3(210, 210, 220), Material = "Metal" },
		}, CF(0, -20, 0))
		R.show(stapler, false)
		local spot = R.spot(V3(0, 22, -8), V3(0, 0, 0.3), { color = C3(255, 250, 235), on = false, width = 4.4 })
		local flashes = false
		R.onSkip(function()
			label.Text = "REVOLUTION."
			glow.Brightness = 1.6
			spot.on()
			R.fx.dark(0.2)
			R.alpha(1)
			R.attach(stapler, "LeftHand", CF(0, -0.1, -0.3) * ANG(0, PI / 2, 0))
			R.show(stapler, true)
			R.pose(REVEAL_UP)
			R.cam.cut(V3(-1.8, 4.6, -6.5), V3(0, 4.6, 0), 40)
		end)

		-- temps 1 : salle noire, vue depuis le public ; "THE FUTURE." s'écrit sur l'écran géant
		R.alpha(0)
		R.pose(STEEPLE)
		R.fx.dark(0.55)
		R.cam.cut(V3(0, 5.4, -18), V3(0, 6.5, 4), 44)
		R.cam.move(V3(0, 5.2, -16), V3(0, 6.5, 4), 1.8, 42)
		R.wait(0.35)
		local msg = "THE FUTURE."
		for i = 1, #msg do
			label.Text = msg:sub(1, i)
			R.wait(0.07)
		end
		R.sound("Ding", nil, 0.5, 0.7)
		R.wait(0.45)
		-- temps 2 : un seul projecteur, il est là, mains jointes ; clic -> diapo suivante
		R.alpha(1)
		spot.on(0.05)
		R.sound("Thud", nil, 0.8, 0.8)
		R.fx.dark(0.25, 0.2)
		R.cam.cut(V3(-3.6, 4.3, -8.5), V3(0, 4.3, 0), 40)
		R.cam.dolly(V3(-3.6, 4.3, -8.5), V3(2.8, 4.3, -8), V3(0, 4.4, 0), 2.6, 40)
		R.wait(0.9)
		R.anim(hold({ K(0, STEEPLE), K(0.15, CLICK) }))
		R.wait(0.15)
		R.sound("UIClick", nil, 1, 0.8)
		label.Text = "ONE MORE THING..."
		glow.Brightness = 1.6
		R.fx.flash(WHITE, 0.02, 0.02, 0.15)
		R.fx.word("*click*", V3(1.3, 3.5, -1.2), 0.5)
		R.wait(0.8)
		-- temps 3 : il brandit la "révolution" vers la caméra, crépitement de flashs dans le public
		R.attach(stapler, "LeftHand", CF(0, -0.1, -0.3) * ANG(0, PI / 2, 0))
		R.show(stapler, true, 0.1)
		R.anim(hold({ K(0, CLICK), K(0.3, REVEAL_UP) }))
		label.Text = "REVOLUTION."
		R.cam.move(V3(-0.8, 5.0, -7.6), V3(-0.9, 5.0, -1), 0.7, 36)
		flashes = true
		R.every(0.1, function()
			if flashes then
				R.fx.twinkle(V3(R.rand(-11, 11), R.rand(3, 5), R.rand(-13, -8)))
			end
		end)
		R.fx.word("OOOOOH!", V3(0, 6.5, -6), 0.9)
		R.sound("Pickup", nil, 0.6, 0.7)
		R.wait(1.0)
		R.cam.move(V3(-1.8, 4.6, -6.5), V3(0, 4.6, 0), 0.6, 40)
		R.wait(0.3)
		R.title()
		R.wait(0.6)
		flashes = false
	end,
}

P.CEO_Legendary = {
	Caption = "Moving the head office to orbit. Parking is still a nightmare.",
	Location = "Rooftop Launch Pad - T-minus whenever",
	Reveal = function(R)
		R.stage("Night")
		local PADZ, mz = 10, 0
		local FIRE = C3(255, 150, 40)
		R.cyl(0.2, 11, V3(0, 0.1, PADZ), C3(70, 72, 80), "Concrete")
		R.cyl(0.22, 8, V3(0, 0.1, PADZ), GOLD)
		R.cyl(0.24, 7, V3(0, 0.1, PADZ), C3(70, 72, 80), "Concrete")
		for i = 0, 7 do
			local a = i * PI / 4
			R.ball(0.35, V3(cos(a) * 5.3, 0.3, PADZ + sin(a) * 5.3), C3(255, 80, 60), "Neon")
		end
		for _, x in ipairs({ -14, 14 }) do
			R.box(V3(0.3, 1.2, 44), CF(x, 0.6, 0), C3(110, 115, 125), "Metal")
		end
		-- la fusée (trappe côté -Z, charnière en bas : elle s'abat en rampe)
		local rocket = R.prop("Rocket", CF(0, 70, PADZ), { color = C3(245, 245, 250), accent = C3(30, 60, 160) })
		local flame, core, hatch, door = rocket:FindFirstChild("Flame"), rocket:FindFirstChild("FlameCore"), rocket:FindFirstChild("Hatch"), rocket:FindFirstChild("Door")
		local landed = CF(0, 0, PADZ)
		local hingeRel = CF(0, 1.2, -2.45)
		local hatchRel
		local function setHatch(e)
			if hatch and hatchRel then
				hatch.CFrame = rocket:GetPivot() * hingeRel * ANG(-1.79 * e, 0, 0) * hingeRel:Inverse() * hatchRel
			end
		end
		local function engine(on)
			for _, p in ipairs({ flame, core }) do
				if p then
					R.tween(p, 0.1, { Transparency = on and 0.1 or 1 })
				end
			end
		end
		local flag
		local function flagFinal()
			flag = flag or R.prop("Flag", CF(2.2, -0.6, mz - 0.8), { text = "HQ 2.0", color = C3(30, 60, 160) })
			R.moveTo(flag, CF(2.2, -0.6, mz - 0.8), 0)
		end
		R.mark(CF(0, 4.2, mz))
		R.onSkip(function(R2)
			rocket:PivotTo(R2.at(0, 300, PADZ))
			flagFinal()
			R2.alpha(1)
			R2.transform(true)
			R2.place(CF(0, 4.2, mz))
			R2.pose("Salute")
			R2.cam.cut(V3(-3.5, 2.8, mz - 8), V3(0, 4.6, mz), 46)
		end)

		-- temps 1 : vue en contre-plongée, la fusée descend du ciel étoilé sur sa flamme
		R.alpha(0)
		R.place(CF(0, 4.2, PADZ - 2.6))
		engine(true)
		R.cam.cut(V3(4, 1.5, -18), V3(0, 30, PADZ), 58)
		R.sound("Rumble", nil, 1, 0.8)
		R.moveTo(rocket, landed, 1.7, ES.Quad, ED.Out)
		R.cam.move(V3(3, 2.4, -17), V3(0, 7, PADZ - 1), 1.7, 50, ES.Quad, ED.Out)
		local descending = true
		R.spawn(function()
			while descending do
				R.fx.smoke(R.pos(rocket) + V3(0, -1.5, 0), 2, C3(235, 225, 210), 1.6)
				R.wait(0.1)
			end
		end)
		R.wait(1.7)
		descending = false
		engine(false)
		R.sound("Thud")
		R.sound("Explosion", nil, 0.4)
		R.cam.shake(0.6)
		R.fx.smoke(V3(0, 0.6, PADZ), 12, C3(220, 220, 228), 3)
		R.fx.shockwave(V3(0, 0.3, PADZ), 16, C3(255, 200, 120))
		R.fx.dust(V3(0, 0, PADZ), 9)
		R.wait(0.4)
		-- temps 2 : la trappe s'abat en rampe, lumière dorée, il apparaît et salue de la main
		if hatch then
			hatchRel = rocket:GetPivot():ToObjectSpace(hatch.CFrame)
		end
		R.cam.cut(V3(-6, 4.5, PADZ - 17), V3(0, 4, PADZ - 3), 40)
		R.sound("Clang")
		R.over(0.6, function(_, e)
			setHatch(e)
		end, ES.Bounce, ED.Out)
		R.wait(0.45)
		if door then
			R.tween(door, 0.2, { Transparency = 0 })
			R.light(door, C3(255, 225, 160), 20, 4)
		end
		R.fx.smoke(V3(0, 2, PADZ - 2.8), 6, WHITE, 1.2)
		R.sound("PowerUp", nil, 0.6)
		R.alpha(1, 0.25)
		R.anim("Wave")
		R.wait(0.9)
		-- temps 3 : il descend la rampe d'un pas assuré, travelling latéral
		R.cam.follow(R.rig, V3(-7, 0.6, -5), 1.9, { look = V3(0, 0.6, 0), fov = 48 })
		R.wait(R.walk(CF(0, 3.05, PADZ - 7.9), 1.1, "Strut"))
		R.wait(R.walk(CF(0, 3, mz), 0.6, "Strut"))
		-- temps 4 : il plante le drapeau "HQ 2.0" et salue
		flag = R.prop("Flag", CF(2.2, 6, mz - 0.8), { text = "HQ 2.0", color = C3(30, 60, 160) })
		R.anim("FlagPlant")
		R.cam.lowAngle(V3(0, 4, mz), 8, 0.5)
		R.wait(0.25)
		R.moveTo(flag, CF(2.2, -0.6, mz - 0.8), 0.14, ES.Quad, ED.In)
		R.wait(0.14)
		R.sound("GroundSlam")
		R.fx.dust(V3(2.2, 0, mz - 0.8), 3)
		R.fx.word("HQ 2.0!", V3(2.2, 7.5, mz - 0.8), 1)
		R.cam.shake(0.3)
		R.wait(0.35)
		R.pose("Salute")
		R.sound("Ding")
		R.wait(0.45)
		-- temps 5 : la trappe se referme, la fusée redécolle au ralenti ; ses bottes-fusées s'allument
		R.over(0.3, function(_, e)
			setHatch(1 - e)
		end)
		if door then
			R.tween(door, 0.2, { Transparency = 1 })
		end
		R.cam.cut(V3(-2.5, 1.4, mz - 9), V3(0.5, 6, PADZ - 2), 52)
		R.cam.track(2.4, function(a)
			return V3(-2.5, 1.4 - a * 0.3, mz - 9 - a * 1.5), V3(0.5, 6 + a * 16, PADZ - 2 + a * 2), 52 + a * 4
		end)
		R.wait(0.3)
		engine(true)
		R.fx.smoke(V3(0, 0.6, PADZ), 26, C3(225, 225, 230), 3.8)
		R.fx.light(V3(0, 3, PADZ), FIRE, 45, 6, 1.6)
		R.fx.tint(C3(255, 228, 200), 0.3)
		R.sound("Explosion", nil, 0.8, 0.7)
		R.sound("Rumble")
		R.cam.shake(0.8)
		R.slowmo(0.4, 1.2)
		local rising = true
		R.spawn(function()
			while rising do
				R.fx.smoke(R.pos(rocket) + V3(0, -1.5, 0), 2, C3(240, 220, 200), 2)
				R.wait(0.09)
			end
		end)
		R.moveTo(rocket, landed + V3(0, 120, 0), 3.0, ES.Quad, ED.In)
		R.wait(0.5)
		R.transform(true)
		R.sound("PowerUp")
		R.moveTo(R.rig, CF(0, 4.2, mz), 0.8, ES.Sine, ED.Out)
		R.wait(0.6)
		R.title()
		R.wait(1.0)
		rising = false
	end,
}

------------------------------------------------------------------------
-- HR MANAGER
------------------------------------------------------------------------
local LOTUS = full({ RH = { p = 1.45, r = 0.75 }, LH = { p = 1.45, r = 0.75 }, RS = { p = 0.45, r = 0.55 }, LS = { p = 0.45, r = 0.55 }, RJ = { ln = -0.04 } })
local TREE = full({ RH = { p = 0.02, r = 0.04 }, LH = { p = 0.9, r = 1.25 }, RS = { p = 3.0, r = -0.45 }, LS = { p = 3.0, r = -0.45 }, RJ = { ln = -0.04 } })

P.HRManager_Rare = {
	Caption = "Breathe in. Breathe out. You're fired. Namaste.",
	Location = "Rooftop Wellness Garden",
	Reveal = function(R)
		local PINK, MINT = C3(255, 170, 200), C3(170, 235, 205)
		R.stage("Studio", { color = C3(200, 238, 222), floor = C3(232, 210, 172) })
		-- bambous, bassin aux lotus, galets
		for i, x in ipairs({ -8, -7, -6.4, 6.2, 7, 8 }) do
			local h = 8 + (i % 3) * 1.5
			R.cyl(h, 0.4, V3(x, h / 2, 6 + (i % 2)), C3(110, 170, 70))
		end
		R.cyl(0.15, 6, V3(4.5, 0.08, 4), C3(90, 170, 220), "Glass")
		for _, p in ipairs({ V3(3.6, 0.3, 3.4), V3(5.3, 0.3, 4.6), V3(4.4, 0.3, 5.4) }) do
			R.ball(0.8, p, PINK)
		end
		for _, p in ipairs({ V3(-4, 0.3, 3), V3(-4.8, 0.25, 3.6), V3(-3.3, 0.2, 3.8) }) do
			R.ball(0.9, p, C3(150, 150, 145), "Marble")
		end
		-- le tapis de yoga (roulé)
		local mat = R.box(V3(2.4, 0.08, 0.05), CF(0, 0.05, 2.6), C3(150, 110, 220))
		local roll = R.box(V3(2.4, 0.55, 0.55), CF(0, 0.3, 2.6), C3(150, 110, 220), nil, nil, "Cyl")
		R.onSkip(function()
			mat.Size = V3(2.4, 0.08, 5.4)
			R.teleport(mat, CF(0, 0.05, -0.1))
			R.show(roll, false)
			R.place(CF(0, 3.08, 0))
			R.pose(TREE)
			R.cam.cut(V3(-3, 3.6, -8.5), V3(0, 4, 0), 42)
		end)

		-- temps 1 : vue zénithale qui tourne ; il lévite en lotus pendant que le tapis se déroule sous lui
		R.place(CF(0, 4.6, 0))
		R.pose(LOTUS)
		R.fx.swirl(V3(0, 4, 0), 3.5, 5, { PINK, WHITE, MINT })
		R.cam.track(1.9, function(a)
			local ang = 0.3 + a * 1.1
			return V3(sin(ang) * 3.5, 20 - a * 4, -cos(ang) * 3.5), V3(0, 2.5, 0), 55
		end)
		R.tween(mat, 1.1, { Size = V3(2.4, 0.08, 5.4) }, ES.Quad, ED.Out)
		R.moveTo(mat, CF(0, 0.05, -0.1), 1.1, ES.Quad, ED.Out)
		R.moveTo(roll, CF(0, 0.15, -2.8), 1.1, ES.Quad, ED.Out)
		R.tween(roll, 1.1, { Size = V3(2.4, 0.2, 0.2) }, ES.Quad, ED.Out)
		R.delay(1.15, function()
			R.show(roll, false, 0.2)
		end)
		R.caption("Breathe in...")
		R.moveTo(R.rig, CF(0, 5.2, 0), 1.6, ES.Sine, ED.InOut)
		R.sound("Ding", nil, 0.5, 0.5)
		R.wait(1.7)
		-- temps 2 : il se pose sur le tapis en posture de l'arbre, orbite douce
		R.caption("Breathe out...")
		R.cam.orbit(V3(0, 3.8, 0), 11.5, 0.3, -0.7, -0.25, 1.8, 46, 42)
		R.moveTo(R.rig, CF(0, 3.08, 0), 0.7, ES.Sine, ED.InOut)
		R.anim(hold({ K(0, LOTUS), K(0.7, TREE) }))
		R.wait(0.8)
		R.caption("You're fired.")
		R.fx.word("NAMASTE.", V3(0, 7, 0), 0.8)
		R.fx.confetti(V3(0, 9, 0), 30, { PINK, WHITE }, 5, 0)
		R.sound("Ding", nil, 0.5, 0.75)
		R.wait(0.7)
		R.title()
		R.wait(0.5)
	end,
}

local PRESENT = full({ RS = { p = 1.0, y = -0.3, r = 1.25 }, LS = { p = 1.0, y = -0.3, r = 1.25 }, RJ = { ln = -0.12 }, RH = { r = 0.15 }, LH = { r = 0.15 } })
local TOSS = full({ LS = { p = 3.0, r = 0.5 }, RS = { p = 0.6, r = 0.3 }, RJ = { ln = -0.1, tw = -0.25 }, RH = { r = 0.1 }, LH = { r = 0.1 } })
local INTERVIEW = full({ RS = { p = 1.7, y = 0.15, r = -0.1 }, LS = { p = 1.0, y = 1.1, r = -0.55 }, RJ = { ln = 0.32 }, RH = { p = -0.25, r = 0.1 }, LH = { p = 0.35, r = 0.1 } })

P.HRManager_Epic = {
	Caption = "Tell me... how does that performance review make you feel?",
	Location = "Studio 4 - \"Let's Talk About Your Attitude\"",
	Reveal = function(R)
		local MAG = C3(255, 70, 170)
		R.stage("Room", { color = C3(70, 32, 92), floor = C3(46, 24, 56), w = 30, d = 22, h = 15 })
		-- skyline de nuit en fond
		R.box(V3(28, 11, 0.2), CF(0, 6, 10.6), C3(22, 28, 66))
		for i = -6, 6 do
			local h = 4 + ((i * 37) % 5)
			local x = i * 2.1
			R.box(V3(1.9, h, 0.2), CF(x, h / 2 + 0.5, 10.4), C3(14, 16, 34))
			for w = 1, math.floor(h / 1.2) do
				if (i + w) % 3 ~= 0 then
					R.box(V3(0.35, 0.4, 0.05), CF(x + ((w % 2) - 0.5) * 0.8, 0.5 + w * 1.1, 10.28), C3(255, 220, 120), "Neon")
				end
			end
		end
		-- canapé, bureau et mug
		R.box(V3(5, 1.2, 2.2), CF(-6, 0.6, 3), MAG)
		R.box(V3(5, 2.2, 0.7), CF(-6, 1.7, 4.0), MAG)
		R.box(V3(4, 2.6, 2), CF(6, 1.3, 3), C3(120, 70, 40), "Wood")
		R.cyl(0.6, 0.5, V3(6.5, 2.9, 3), WHITE)
		-- trappe (anneau doré) et plateforme cachée sous le sol
		R.cyl(0.06, 4.6, V3(0, 0.03, 0), GOLD, "Neon")
		local lid = R.cyl(0.07, 4, V3(0, 0.035, 0), C3(30, 15, 36))
		local plat = R.cyl(0.3, 4, V3(0, -6.75, 0), GOLD, "Metal")
		-- enseigne ON AIR et rampe de projecteurs
		local onair = R.box(V3(3.6, 1.1, 0.3), CF(0, 12.8, 10.3), C3(70, 10, 14))
		R.text(onair, "ON AIR", { Face = NF, Color = C3(255, 230, 230) })
		local lamps = {}
		for i = 1, 6 do
			lamps[i] = R.box(V3(1, 1, 1.2), CF(-10 + (i - 1) * 4, 13.2, -5) * ANG(rad(-35), 0, 0), C3(40, 40, 46), "Metal")
		end
		local function onAir()
			onair.Color = C3(255, 30, 40)
			onair.Material = Enum.Material.Neon
		end
		R.onSkip(function()
			onAir()
			for _, l in ipairs(lamps) do
				l.Color = WHITE
				l.Material = Enum.Material.Neon
			end
			R.show(lid, false)
			R.teleport(plat, CF(0, 0.15, 0))
			R.place(CF(0, 3.3, 0))
			R.pose(INTERVIEW)
			R.cam.cut(V3(0.6, 4.8, -5.6), V3(0, 4.5, 0), 44)
			R.fx.dark(0)
		end)

		-- temps 1 : plateau dans le noir, les projecteurs claquent un par un, ON AIR s'allume
		R.place(CF(0, -3.6, 0))
		R.fx.dark(0.55)
		R.cam.cut(V3(0, 6.5, -10), V3(0, 4.5, 2), 56)
		for i, l in ipairs(lamps) do
			R.delay(0.12 * i, function()
				l.Color = WHITE
				l.Material = Enum.Material.Neon
				R.light(l, C3(255, 240, 220), 22, 0.6)
				R.sound("Clang", nil, 0.35, 0.8 + i * 0.08)
			end)
		end
		R.wait(0.85)
		onAir()
		R.sound("Ding")
		R.fx.dark(0, 0.3)
		R.fx.word("ON AIR", V3(0, 11, 9), 0.9)
		R.wait(0.5)
		-- temps 2 : il monte par la trappe sur une plateforme dorée ; confettis et applaudissements
		R.show(lid, false)
		R.pose(PRESENT)
		R.moveTo(R.rig, CF(0, 3.3, 0), 0.8, ES.Back, ED.Out)
		R.moveTo(plat, CF(0, 0.15, 0), 0.8, ES.Back, ED.Out)
		R.fx.smoke(V3(0, 0.3, 0), 10, C3(255, 210, 240), 2)
		R.cam.move(V3(0, 2.2, -8.5), V3(0, 4.6, 0), 0.9, 50)
		R.sound("PowerUp")
		R.wait(0.6)
		R.fx.confetti(V3(-9, 1, -1), 50, { MAG, GOLD, WHITE, C3(80, 200, 255) }, 4, 14)
		R.fx.confetti(V3(9, 1, -1), 50, { MAG, GOLD, WHITE, C3(80, 200, 255) }, 4, 14)
		R.fx.word("APPLAUSE!", V3(0, 8, 1), 1.1)
		R.fx.hearts(V3(0, 5, 0), 10, MAG)
		R.sound("LevelUp")
		R.wait(1.0)
		-- temps 3 : il jette ses fiches par-dessus l'épaule et tend le micro à la caméra
		R.anim(hold({ K(0, PRESENT), K(0.18, TOSS) }))
		R.wait(0.12)
		local card = R.box(V3(0.7, 0.95, 0.05), CF(-1.5, 6, -0.6), WHITE)
		R.text(card, "SMILE!", { Face = NF, Color = MAG })
		R.fly(card, { V3(-1.5, 6, -0.6), V3(-2.5, 8.5, 2), V3(-3.5, 2, 5) }, 0.9)
		R.sound("Throw")
		R.wait(0.3)
		R.anim(hold({ K(0, TOSS), K(0.3, INTERVIEW) }))
		R.cam.move(V3(0.6, 4.8, -5.6), V3(0, 4.5, 0), 0.8, 44)
		R.caption("...and how does that make you FEEL?")
		R.wait(1.2)
		R.title()
		R.wait(0.6)
	end,
}

local POINT_MIC = full({ RS = { p = 1.65, y = 0.1 }, LS = { p = 0.4, r = 0.6 }, RJ = { tw = 0.3, ln = 0.05 }, RH = { p = -0.3, r = 0.12 }, LH = { p = 0.35, r = 0.12 } })
local MIC_WIDE = full({ RS = { p = 2.25, y = 1.2, r = -0.5 }, LS = { p = 0.5, r = 1.9 }, RJ = { ln = -0.1, sd = -0.08 }, RH = { r = 0.15 }, LH = { p = 0.3, r = 0.2 } })

P.HRManager_Legendary = {
	Caption = "Spin the wheel... of PERFORMANCE REVIEWS! Live, in front of everyone!",
	Location = "Prime Time - Live Studio Audience",
	Reveal = function(R)
		local DIM, LIL = C3(90, 70, 40), C3(190, 110, 255)
		R.stage("Stage")
		R.place(CF(0, 3.2, 0))   -- plancher de la scène à y = 0,2
		R.mark(CF(0, 3.2, 0))
		-- cadre d'ampoules de music-hall
		local bulbs = {}
		for y = 1, 14 do
			bulbs[#bulbs + 1] = R.ball(0.45, V3(-10, y, -6.5), DIM, "Neon")
			bulbs[#bulbs + 1] = R.ball(0.45, V3(10, y, -6.5), DIM, "Neon")
		end
		for x = -9, 9 do
			bulbs[#bulbs + 1] = R.ball(0.45, V3(x, 14.5, -6.5), DIM, "Neon")
		end
		local chase = true
		R.every(0.07, function(i)
			if chase then
				for k, b in ipairs(bulbs) do
					b.Color = ((k + i) % 3 == 0) and GOLD or DIM
				end
			end
		end)
		-- la roue géante (devant lui, elle le cache)
		local WC = { C3(255, 200, 40), C3(255, 70, 90), C3(80, 200, 255), C3(130, 230, 90), LIL, C3(255, 140, 50), C3(60, 220, 200), C3(255, 110, 200) }
		local LBL = { "YOU!", "WRITE-UP", "PIZZA\nPARTY", "FIRED", "BONUS", "MEETING", "RAISE", "ANOTHER\nMEETING" }
		local specs = {
			{ Size = V3(0.6, 0.6, 0.6), CFrame = CF(), Color = GOLD, Material = "Metal" },
			{ Size = V3(0.5, 9.8, 9.8), CFrame = CF(0, 0, 0.1) * ANG(0, PI / 2, 0), Color = C3(240, 240, 250), Shape = "Cyl", Material = "Metal" },
			{ Size = V3(0.7, 1.5, 1.5), CFrame = CF(0, 0, -0.45) * ANG(0, PI / 2, 0), Color = GOLD, Shape = "Cyl", Material = "Metal" },
		}
		for i = 1, 8 do
			specs[#specs + 1] = { Size = V3(2.5, 4.1, 0.2), CFrame = ANG(0, 0, (i - 1) * PI / 4) * CF(0, 2.45, -0.25 - i * 0.012), Color = WC[i], Text = LBL[i], TextColor = WHITE }
		end
		for i = 1, 16 do
			local th = i * PI / 8
			specs[#specs + 1] = { Size = V3(0.35, 0.35, 0.35), CFrame = CF(sin(th) * 4.7, cos(th) * 4.7, -0.3), Color = C3(255, 245, 200), Material = "Neon", Shape = "Ball" }
		end
		local wheel = R.model(specs, CF(0, 5.4, -2.6))
		R.box(V3(0.9, 0.9, 0.4), CF(0, 10.55, -3.0) * ANG(0, 0, PI / 4), C3(255, 40, 40), "Neon")
		R.onSkip(function()
			chase = false
			for _, b in ipairs(bulbs) do
				b.Color = GOLD
			end
			if R.S and R.S.curtainOpen then
				R.S.curtainOpen(0.01)
			end
			R.teleport(wheel, CF(-40, 5.4, -2.6))
			R.transform(true)
			R.place(CF(0, 3.2, 0))
			R.pose(MIC_WIDE)
			R.cam.hero()
			R.fx.dark(0)
		end)

		-- temps 1 : rideaux fermés, ampoules qui courent, "IT'S TIIIIME FOR..."
		R.fx.dark(0.3)
		R.cam.cut(V3(0, 6, -21), V3(0, 6, 0), 50)
		R.cam.move(V3(0, 6, -16), V3(0, 6, 0), 1.8, 48)
		R.fx.banner("IT'S TIIIIIME FOR...", { color = GOLD, t = 1.2 })
		R.sound("Rumble", nil, 0.5, 1.6)
		R.wait(1.5)
		-- temps 2 : rideaux ouverts, la roue tourne, gros plan sur l'aiguille qui ralentit... YOU!
		if R.S and R.S.curtainOpen then
			R.S.curtainOpen(0.7)
		end
		R.fx.dark(0, 0.4)
		R.fx.banner("SPIN THE WHEEL!", { color = WHITE, t = 0.8 })
		R.sound("Whoosh")
		R.spin(wheel, 4, 2.1, "Z")
		R.wait(0.5)
		R.cam.move(V3(1.5, 8.2, -13), V3(0, 7.9, -2.6), 0.5, 38)
		R.spawn(function()
			for _, g in ipairs({ 0.06, 0.06, 0.07, 0.08, 0.09, 0.11, 0.13, 0.16, 0.2, 0.26 }) do
				R.sound("UIClick", nil, 0.6, 1.4)
				R.wait(g)
			end
		end)
		R.wait(1.5)
		R.sound("Ding")
		R.fx.flash(GOLD, 0.03, 0.05, 0.25)
		R.fx.banner("...YOU!", { color = GOLD, t = 0.7 })
		R.wait(0.4)
		-- temps 3 : la roue s'envole ; contre-jour, projecteur — il pointe la caméra avec son micro d'or
		R.moveTo(wheel, CF(-26, 12, -2.6), 0.5, ES.Back, ED.In)
		local spot = R.spot(V3(0, 22, -9), V3(0, 0, 0), { color = C3(255, 235, 170), on = false, brightness = 4 })
		R.fx.dark(0.45, 0.1)
		R.pose(POINT_MIC)
		R.wait(R.cam.whip(V3(-2.2, 4.4, -8), V3(0, 4.5, 0)))
		R.wait(0.2)
		spot.on(0.05)
		R.sound("Thud")
		R.fx.dark(0.15, 0.2)
		R.fx.word("COME ON DOWN!", V3(0, 7.5, -1), 1.2)
		R.wait(0.8)
		-- temps 4 : ralenti, transformation (WINNER), canons à confettis, il tournoie
		R.slowmo(0.4)
		R.transform(true)
		R.sound("LevelUp")
		R.fx.confetti(V3(-8, 1, 0), 60, { GOLD, WHITE, LIL }, 4, 16)
		R.fx.confetti(V3(8, 1, 0), 60, { GOLD, WHITE, LIL }, 4, 16)
		R.fx.fireworks(V3(-6, 12, 6), 3)
		R.fx.fireworks(V3(6, 12, 6), 3)
		R.anim("Spin")
		R.spin(R.rig, 1, 0.7)
		R.cam.orbit(V3(0, 4.2, 0), 9, 0.4, -0.7, 0.5, 0.9, 50, 44)
		R.wait(0.8)
		R.slowmo(1)
		-- temps 5 : pose finale micro aux lèvres, ampoules dorées fixes
		chase = false
		for _, b in ipairs(bulbs) do
			b.Color = GOLD
		end
		R.anim(hold({ K(0, POINT_MIC), K(0.25, MIC_WIDE) }))
		R.fx.rays(GOLD)
		R.cam.hero(0.6)
		R.wait(0.8)
		R.title()
		R.wait(0.6)
	end,
}

return P
