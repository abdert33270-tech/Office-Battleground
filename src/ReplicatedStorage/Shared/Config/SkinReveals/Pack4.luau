--[[
	SkinReveals.Pack4 — chorégraphies de révélation : MaintenanceGuy, MarketingGuru, Lawyer, Mascot (agent reveal4).
	Chaque Reveal(R, ctx) suit l'API de SkinRevealController v2 (voir son en-tête / REVEAL_API) :
	repère local (sol y = 0, héros sur CF(0, 3, 0) regardant -Z, caméra côté -Z, +X = main droite du héros).
	Structures toutes différentes : obscurité -> lumière, mur qui s'ouvre, assemblage, selfie, rythme, prise de contrôle
	des pubs, objet d'abord, surgissement, entrée en marchant, sortie d'un pain, cabine à costume, sortie du tunnel.
]]
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local rad, PI = math.rad, math.pi
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local WHITE, GOLD, DARK = C3(255, 255, 255), C3(255, 200, 40), C3(25, 25, 32)
local CYAN, MAG = C3(40, 230, 255), C3(225, 40, 170)

local P = {}

-- membre du rig (nil si absent)
local function limb(R, name)
	return R.rig and R.rig:FindFirstChild(name)
end
-- regarder vers +X / -X / +Z (lacet)
local FACE_PX, FACE_NX, FACE_PZ = ANG(0, -PI / 2, 0), ANG(0, PI / 2, 0), ANG(0, PI, 0)

------------------------------------------------------------------------ MAINTENANCE GUY
-- RARE · Hard Hat Hero — obscurité -> lumière : la lampe frontale s'allume, il scotche le néon sur l'escabeau.
P.MaintenanceGuy_Rare = {
	Caption = "Fixes everything with tape. Everything. Including the tape.",
	Location = "Basement - Corridor B - 2:47 AM",
	Reveal = function(R, ctx)
		local ALU, HAT, TUBE_OFF, TUBE_ON = C3(185, 190, 200), C3(255, 205, 35), C3(70, 74, 84), C3(235, 245, 255)
		local FINAL = CF(0, 3, -2.4)
		R.stage("Room", { dark = true, color = C3(72, 80, 92), floor = C3(55, 58, 64), w = 26, d = 26, h = 13 })
		R.mark(FINAL)
		-- escabeau (deux paires de montants en A, 3 marches, plateau jaune)
		local specs = {}
		for _, x in ipairs({ -1.1, 1.1 }) do
			table.insert(specs, { Size = V3(0.22, 4.3, 0.3), CFrame = CF(x, 2.05, -0.15) * ANG(rad(12), 0, 0), Color = ALU, Material = "Metal" })
			table.insert(specs, { Size = V3(0.22, 4.3, 0.3), CFrame = CF(x, 2.05, 0.73) * ANG(rad(-12), 0, 0), Color = ALU, Material = "Metal" })
		end
		for _, y in ipairs({ 1.0, 2.0, 3.0 }) do
			table.insert(specs, { Size = V3(2.3, 0.16, 0.45), CFrame = CF(0, y, -0.15 + (y - 2.05) * 0.2126), Color = ALU, Material = "Metal" })
		end
		table.insert(specs, { Size = V3(2.5, 0.25, 1.1), CFrame = CF(0, 4.2, 0.3), Color = HAT })
		R.model(specs, CF(0, 0, 0))
		-- néon au plafond qui clignote + chaînes
		R.box(V3(4.4, 0.3, 1.1), CF(0, 10.95, 0.3), C3(95, 100, 110), "Metal")
		local tube = R.box(V3(3.9, 0.24, 0.5), CF(0, 10.72, 0.3), TUBE_OFF, "Neon")
		R.box(V3(0.08, 2.0, 0.08), CF(-1.8, 12.1, 0.3), C3(60, 60, 66), "Metal")
		R.box(V3(0.08, 2.0, 0.08), CF(1.8, 12.1, 0.3), C3(60, 60, 66), "Metal")
		local ceilLight = R.light(V3(0, 10.2, 0.3), TUBE_ON, 30, 0)
		-- deux bandes de ruban adhésif (apparaissent pendant le scotchage)
		local tape1 = R.box(V3(0.45, 0.62, 0.62), CF(-0.7, 10.72, 0.3), C3(200, 200, 210), "Foil", 0, "Cyl")
		local tape2 = R.box(V3(0.45, 0.62, 0.62), CF(0.8, 10.72, 0.3), C3(200, 200, 210), "Foil", 0, "Cyl")
		R.show(tape1, false)
		R.show(tape2, false)
		-- clé à molette (dans la main, apparaît à l'atterrissage)
		local lamp = R.spot(V3(0, 9.0, -0.4), V3(0, 10.7, 0.4), { color = C3(255, 245, 205), width = 1.4, on = false, brightness = 6, range = 14, angle = 18 })
		local wrench
		local thumbs = { RS = { p = 2.95, r = 0.35, y = 0.6 }, LS = { p = 1.5, r = 0.2, y = 0.2 }, RJ = { ln = -0.06, sd = 0.06 }, RH = { r = 0.18 }, LH = { r = 0.18 } }

		R.onSkip(function(R)
			R.fx.dark(0)
			tube.Color = TUBE_ON
			ceilLight.Brightness = 3
			R.show(tape1, true)
			R.show(tape2, true)
			R.place(FINAL)
			if not wrench then
				wrench = R.hold("MGWrench", "Right")
			end
			R.pose(thumbs)
			R.cam.hero()
		end)

		-- debout sur le plateau de l'escabeau, bras levés vers le néon, dans le noir
		local lit = false
		R.place(CF(0, 7.33, 0.3))
		R.fx.dark(0.85)
		R.pose({ RS = { p = 3.0, r = 0.12 }, LS = { p = 2.9, r = 0.12 }, RJ = { ln = -0.28 } })
		R.cam.cut(V3(2.6, 1.0, -6.2), V3(0, 6.8, 0.3), 64)
		R.every(0.08, function()
			if not lit then
				tube.Color = (R.randi(0, 3) == 0) and TUBE_ON or TUBE_OFF
			end
		end)
		R.wait(0.3)
		R.sound("UIClick", V3(0, 9, 0), 1)
		lamp.on(0.05)
		R.cam.move(V3(2.8, 9.2, -5.2), V3(0, 9.6, 0.3), 1.3, 56, ES.Sine, ED.Out)
		-- scotchage : les bras alternent au-dessus de la tête
		R.anim({
			{ t = 0, RS = { p = 3.0, r = 0.12 }, LS = { p = 2.9, r = 0.12 }, RJ = { ln = -0.28 } },
			{ t = 0.14, RS = { p = 2.7, r = -0.35, y = 0.6 }, LS = { p = 3.15, r = 0.35 }, RJ = { ln = -0.32, tw = 0.18 } },
			{ t = 0.28, RS = { p = 3.15, r = 0.35 }, LS = { p = 2.7, r = -0.35, y = 0.6 }, RJ = { ln = -0.32, tw = -0.18 } },
			{ t = 0.42, RS = { p = 2.7, r = -0.35, y = 0.6 }, LS = { p = 3.15, r = 0.35 }, RJ = { ln = -0.32, tw = 0.18 } },
			{ t = 0.56, RS = { p = 3.15, r = 0.35 }, LS = { p = 2.7, r = -0.35, y = 0.6 }, RJ = { ln = -0.32, tw = -0.18 } },
			{ t = 0.75, RS = { p = 3.0, r = 0.1 }, LS = { p = 2.9, r = 0.1 }, RJ = { ln = -0.25 } },
		})
		R.wait(0.25)
		R.show(tape1, true, 0.05)
		R.sound("Whoosh", V3(0, 10, 0), 0.8, 1.6)
		R.fx.word("RIIIP!", V3(-1.6, 11.6, -0.6), 0.9)
		R.wait(0.3)
		R.show(tape2, true, 0.05)
		R.sound("Squeak", V3(0, 10, 0), 0.8)
		R.wait(0.25)
		-- la lumière revient
		lit = true
		tube.Color = TUBE_ON
		ceilLight.Brightness = 3
		R.fx.dark(0, 0.12)
		R.fx.flash(C3(255, 255, 235), 0.03, 0.03, 0.25)
		R.sound("Ding", V3(0, 10, 0), 1)
		lamp.off(0.25)
		R.wait(0.2)
		-- il saute de l'escabeau, clé à la main, pouce levé
		wrench = R.hold("MGWrench", "Right")
		R.wait(R.jump(R.rig, FINAL, 0.5, 1.4))
		R.fx.dust(V3(0, 0, -2.4), 3)
		R.sound("Thud", V3(0, 0, -2.4), 0.8)
		R.pose(thumbs)
		R.cam.move(V3(-3.0, 3.6, -9.6), V3(0, 4.3, -2.4), 0.55, 58, ES.Quad, ED.Out)
		R.fx.word("FIXED!", V3(-2.2, 6.6, -3.0), 0.8)
		R.fx.twinkle(V3(0, 10.6, -0.1))
		R.wait(0.9)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Makeover Show Host — le mur « BEFORE » s'ouvre au mégaphone sur un cubicle rénové.
P.MaintenanceGuy_Epic = {
	Caption = "Your cubicle has been renovated. You were not consulted.",
	Location = "Makeover HQ - Episode 412: Cubicle 7B",
	Reveal = function(R, ctx)
		local FL, DRILL, TEAL = C3(200, 38, 38), C3(255, 185, 25), C3(70, 190, 170)
		local WALL = C3(140, 140, 135)
		R.stage("Room", { color = C3(205, 195, 175), floor = C3(150, 112, 72), w = 36, d = 34, h = 15 })
		-- cubicle rénové (derrière le mur)
		R.box(V3(16, 9, 0.4), CF(0, 4.5, 13.5), TEAL)
		local afterSign = R.box(V3(6, 1.6, 0.25), CF(0, 7.6, 13.2), WHITE)
		R.text(afterSign, "AFTER", { Color = FL })
		R.box(V3(11, 0.08, 6.5), CF(0, 0.05, 10), C3(235, 228, 215), "Marble")
		R.prop("Desk", CF(0, 0, 10.5))
		R.prop("OfficeChair", CF(1.6, 0, 8.6) * FACE_PZ)
		R.prop("Plant", CF(-5.5, 0, 11.5))
		R.prop("Plant", CF(5.5, 0, 11.5))
		for i, x in ipairs({ -3.5, 0, 3.5 }) do
			R.box(V3(2.2, 1.6, 0.12), CF(x, 4.8, 13.2), (i == 2) and GOLD or C3(255, 250, 240), "SmoothPlastic")
		end
		local afterLight = R.light(V3(0, 8, 9.5), C3(255, 240, 200), 24, 0)
		-- le mur « BEFORE » (deux moitiés) avec rubans et taches
		local wallL = R.box(V3(8.2, 10, 0.7), CF(-4.1, 5, 4.5), WALL, "Concrete")
		local wallR = R.box(V3(8.2, 10, 0.7), CF(4.1, 5, 4.5), WALL, "Concrete")
		R.text(wallL, "BEF", { Color = C3(70, 70, 70) })
		R.text(wallR, "ORE", { Color = C3(70, 70, 70) })
		local tapeL = R.box(V3(8.2, 0.5, 0.1), CF(-4.1, 2.2, 4.1) * ANG(0, 0, rad(8)), DRILL)
		local tapeR = R.box(V3(8.2, 0.5, 0.1), CF(4.1, 2.2, 4.1) * ANG(0, 0, rad(-8)), DRILL)
		local drill = R.mesh("MaintenanceGuy_Epic_Drill", CF(-12, 9, 2), 1.8)

		local openPose = { RS = { p = 1.5, r = 0.9 }, LS = { p = 1.6, y = 0.2 }, RJ = { tw = -0.15, ln = -0.05 }, RH = { r = 0.15 }, LH = { r = 0.15 } }
		local finalPose = { RS = { p = 1.65, y = 0.1, r = 0.1 }, LS = { p = 2.6, r = 0.35, y = 0.2 }, RJ = { tw = 0.25, ln = -0.08 }, RH = { p = -0.2, r = 0.12 }, LH = { p = 0.25, r = 0.12 } }
		local function opened()
			wallL:PivotTo(R.at(-16, 5, 4.5))
			wallR:PivotTo(R.at(16, 5, 4.5))
			tapeL:PivotTo(R.at(-16, 2.2, 4.1))
			tapeR:PivotTo(R.at(16, 2.2, 4.1))
			afterLight.Brightness = 2.5
		end
		R.onSkip(function(R)
			opened()
			R.place(CF(0, 3, 0))
			R.transform(true)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : dos à la caméra face au mur, il gonfle les poumons et hurle dans le mégaphone
		R.place(CF(0, 3, 0) * FACE_PZ)
		R.cam.cut(V3(-3.6, 4.4, 3.2), V3(0.3, 4.6, 0), 58)
		R.anim({
			{ t = 0 },
			{ t = 0.35, LS = { p = 1.2, y = 0.2 }, RS = { p = 0.3, r = 0.35 }, RJ = { ln = -0.35 }, RH = { p = 0.1 }, LH = { p = -0.1 } },
			{ t = 0.55, LS = { p = 1.65 }, RS = { p = -0.45, r = 0.6 }, RJ = { ln = 0.3 }, RH = { p = -0.25 }, LH = { p = 0.4 } },
			{ t = 1.6, LS = { p = 1.6 }, RS = { p = -0.4, r = 0.55 }, RJ = { ln = 0.26 }, RH = { p = -0.25 }, LH = { p = 0.4 } },
		})
		R.cam.move(V3(-2.8, 4.2, 2.4), V3(0.3, 4.7, 0), 0.5, 52)
		R.wait(0.55)
		R.sound("Whistle", V3(0, 4.5, 1), 1, 0.6)
		R.fx.banner("MOVE THAT DESK!", { color = DRILL, t = 1.0, size = 0.16 })
		R.cam.punch(-12)
		R.cam.shake(0.45)
		for i = 0, 2 do
			R.delay(i * 0.12, function()
				R.fx.ring(V3(0.4, 4.4, 1.6 + i * 0.6), V3(0, 0, 1), 2.5 + i, WHITE)
			end)
		end
		R.wait(0.7)
		-- BEAT 2 : le mur s'ouvre, whip derrière son épaule sur le cubicle rénové
		R.sound("Rumble", V3(0, 2, 4.5), 1)
		R.moveTo(wallL, CF(-16, 5, 4.5), 0.85, ES.Quad, ED.In)
		R.moveTo(wallR, CF(16, 5, 4.5), 0.85, ES.Quad, ED.In)
		R.moveTo(tapeL, CF(-16, 2.2, 4.1), 0.85, ES.Quad, ED.In)
		R.moveTo(tapeR, CF(16, 2.2, 4.1), 0.85, ES.Quad, ED.In)
		R.fx.dust(V3(0, 0, 4.5), 6)
		R.cam.whip(V3(1.8, 5.4, -6.2), V3(0, 4.2, 9))
		R.pose(openPose)
		R.wait(0.55)
		R.tween(afterLight, 0.3, { Brightness = 2.5 })
		R.fx.confetti(V3(0, 9, 10), 70)
		R.fx.word("TA-DA!", V3(0, 9.5, 10), 1)
		R.sound("Ding", V3(0, 5, 10), 1)
		for _, p in ipairs({ V3(-4, 5, 11), V3(3, 3, 9), V3(0, 7.6, 12.6), V3(5.5, 4, 11.5) }) do
			R.fx.twinkle(p)
		end
		-- la perceuse volante vient visser le panneau AFTER
		if drill then
			R.fly(drill, { V3(-12, 9, 2), V3(-5, 10, 8), V3(-1, 8.2, 12.2), V3(-3.3, 7.6, 12.9) }, 0.9, { face = true })
			R.delay(0.9, function()
				R.fx.sparks(V3(-3.0, 7.6, 13.0), 14, C3(255, 210, 90))
				R.sound("Electric", V3(-3, 7.6, 13), 0.6)
			end)
		end
		R.wait(1.1)
		-- BEAT 3 : il se retourne vers la caméra, panneau de l'émission, grue montante
		R.face(V3(0, 3, -10), 0.3)
		R.cam.move(V3(-2.4, 2.4, -8.2), V3(0, 4.4, 0), 0.6, 58, ES.Quad, ED.Out)
		R.wait(0.35)
		R.transform(true)
		R.pose(finalPose)
		R.sound("PowerUp", V3(0, 4, 0), 0.7)
		R.cam.move(V3(-3.0, 6.2, -9.2), V3(0, 4.6, 0.5), 1.4, 56, ES.Sine, ED.InOut)
		R.wait(1.2)
		R.title()
		R.wait(1.2)
	end,
}

-- LEGENDARY · Mega Mech Mechanic — assemblage : soudure dans le noir, les pièces de l'exosquelette volent et se verrouillent,
-- le réacteur s'allume au ralenti, les bras mécaniques frappent le sol.
P.MaintenanceGuy_Legendary = {
	Caption = "Brought a giant robot suit to a desk fight. Warranty void.",
	Location = "Sub-Basement Hangar - Bay 07",
	Reveal = function(R, ctx)
		local MECH, MD, MDK, OR, CORE = C3(255, 196, 28), C3(62, 66, 80), C3(34, 37, 46), C3(255, 135, 25), C3(70, 225, 255)
		R.stage("Room", { dark = true, color = C3(50, 54, 64), floor = C3(64, 66, 72), w = 46, d = 46, h = 24 })
		-- anneau de bandes de danger au sol, panneau BAY 07, gyrophares
		for i = 0, 15 do
			local a = i * PI / 8
			R.box(V3(2.0, 0.06, 0.7), CF(math.cos(a) * 6.5, 0.04, math.sin(a) * 6.5) * ANG(0, -a + PI / 2, 0), (i % 2 == 0) and MECH or C3(25, 25, 30))
		end
		local sign = R.box(V3(11, 2.4, 0.3), CF(0, 13, 14), C3(25, 25, 30))
		R.text(sign, "BAY 07", { Color = MECH })
		local beaconLights = {}
		for _, x in ipairs({ -10, 10 }) do
			local b = R.ball(1.0, V3(x, 11, 12), OR, "Neon")
			table.insert(beaconLights, R.light(b, OR, 18, 0))
		end
		-- pièces de l'exosquelette (positions finales + départs hors champ)
		local function arm(s)
			return R.model({
				{ Size = V3(2.3, 1.6, 2.3), CFrame = CF(0, 0, 0), Color = MECH, Name = "Pod" },
				{ Size = V3(2.34, 0.2, 2.34), CFrame = CF(0, -0.3, 0), Color = OR, Material = "Neon", Name = "Glow" },
				{ Size = V3(1.1, 2.4, 1.1), CFrame = CF(0, -1.8, 0), Color = MD, Material = "Metal" },
				{ Size = V3(0.3, 2.2, 0.3), CFrame = CF(0.65 * s, -1.8, 0.2), Color = C3(180, 185, 195), Material = "Metal" },
				{ Size = V3(2.1, 2.0, 2.1), CFrame = CF(0, -3.6, -0.2), Color = MECH },
				{ Size = V3(2.14, 0.24, 2.14), CFrame = CF(0, -3.0, -0.2), Color = OR, Material = "Neon", Name = "Glow2" },
				{ Size = V3(2.0, 0.5, 0.3), CFrame = CF(0, -4.2, -1.3), Color = MDK, Material = "Metal" },
			}, CF(0, 0, 0))
		end
		local pieces = {
			{ obj = R.model({
				{ Size = V3(3.6, 3.8, 0.7), CFrame = CF(0, 0, 0), Color = MD, Material = "Metal" },
				{ Size = V3(3.64, 0.3, 0.74), CFrame = CF(0, 1.2, 0), Color = MECH },
				{ Size = V3(2.4, 0.7, 0.7), CFrame = CF(-1.2, 2.6, 0.35), Color = C3(170, 175, 185), Material = "Metal", Shape = "Cyl" },
				{ Size = V3(2.4, 0.7, 0.7), CFrame = CF(1.2, 2.6, 0.35), Color = C3(170, 175, 185), Material = "Metal", Shape = "Cyl" },
				{ Size = V3(1.4, 1.4, 0.3), CFrame = CF(0, -0.4, 0.45), Color = CORE, Material = "Neon", Name = "BackCore" },
			}, CF(0, 0, 0)), final = CF(0, 3.6, 1.55), start = CF(0, 22, 1.55) },
			{ obj = arm(-1), final = CF(-3.2, 5.7, 0.7), start = CF(-24, 8, 0.7) },
			{ obj = arm(1), final = CF(3.2, 5.7, 0.7), start = CF(24, 8, 0.7) },
			{ obj = R.box(V3(1.9, 0.75, 2.6), CF(0, 0, 0), MECH), final = CF(-0.55, 0.38, -0.15), start = CF(-0.55, 0.38, -18) },
			{ obj = R.box(V3(1.9, 0.75, 2.6), CF(0, 0, 0), MECH), final = CF(0.55, 0.38, -0.15), start = CF(0.55, 0.38, -18) },
		}
		-- les cheminées sont des cylindres couchés : on les redresse
		for _, part in ipairs(pieces[1].obj:GetChildren()) do
			if part:IsA("BasePart") and part.Shape == Enum.PartType.Cylinder then
				part.CFrame = part.CFrame * ANG(0, 0, PI / 2)
			end
		end
		for _, pc in ipairs(pieces) do
			pc.obj:PivotTo(R.at(pc.start.X, pc.start.Y, pc.start.Z))
		end
		local function glowAll(col)
			for i = 2, 3 do
				for _, part in ipairs(pieces[i].obj:GetChildren()) do
					if part.Name == "Glow" or part.Name == "Glow2" then
						part.Color = col
					end
				end
			end
		end
		local flexPose = { RS = { p = 0.15, r = 1.55 }, LS = { p = 0.15, r = 1.55 }, RJ = { ln = 0.08 }, RH = { r = 0.32 }, LH = { r = 0.32 } }
		local function assembled()
			for _, pc in ipairs(pieces) do
				pc.obj:PivotTo(R.at(pc.final.X, pc.final.Y, pc.final.Z))
			end
			glowAll(CORE)
			for _, l in ipairs(beaconLights) do
				l.Brightness = 3
			end
		end
		R.onSkip(function(R)
			R.fx.dark(0)
			assembled()
			R.place(CF(0, 3, 0))
			R.transform(true)
			R.pose(flexPose)
			R.cam.hero()
		end)

		-- BEAT 1 : soudure en macro dans le noir
		R.fx.dark(0.6)
		R.place(CF(0, 3, 0))
		R.pose("Kneel")
		local welding = true
		R.every(0.07, function()
			if welding then
				R.fx.sparks(V3(-1.3, 0.6, -2.0), 4, C3(255, 190, 70))
			end
		end)
		local weldLight = R.light(V3(-1.3, 1.0, -2.0), C3(160, 220, 255), 14, 0)
		R.every(0.05, function()
			if welding then
				weldLight.Brightness = R.rand(1.5, 5)
			else
				weldLight.Brightness = 0
			end
		end)
		R.cam.cut(V3(-2.6, 1.3, -4.3), V3(-1.3, 0.8, -2.0), 38)
		R.cam.move(V3(-2.2, 1.6, -4.6), V3(-1.0, 1.4, -1.6), 1.1, 42)
		R.sound("Electric", V3(-1.3, 0.6, -2), 0.6)
		R.wait(1.1)
		-- il se relève, rabat la visière : CLANG
		welding = false
		R.anim({ { t = 0 }, { t = 0.3, RJ = { ln = -0.15 } }, { t = 0.42, RJ = { ln = 0.12 }, RS = { p = 2.8, r = 0.2 } }, { t = 0.7 } })
		R.sound("Clang", V3(0, 4.5, 0), 0.9)
		R.cam.pullOut(V3(0, 3.8, 0), 4, 10, 0.7, { height = 1.2, yaw = -0.3, fov = 60 })
		R.wait(0.55)
		-- BEAT 2 : assemblage — orbite complète pendant que les pièces se verrouillent
		R.fx.dark(0, 0.4)
		R.light(V3(0, 9, -6), C3(255, 230, 190), 30, 1.6)
		for _, l in ipairs(beaconLights) do
			R.tween(l, 0.4, { Brightness = 3 })
		end
		R.pose("Power")
		R.cam.orbit(V3(0, 3.8, 0), 12, 3.2, -0.5, 2.6, 2.6, 62, 54)
		for i, pc in ipairs(pieces) do
			R.delay((i - 1) * 0.42, function()
				R.moveTo(pc.obj, pc.final, 0.38, ES.Back, ED.Out)
				R.delay(0.3, function()
					local p = V3(pc.final.X, pc.final.Y, pc.final.Z)
					R.fx.sparks(p, 16, C3(255, 200, 80))
					R.sound("MetalHit", p, 0.9)
					R.cam.shake(0.3)
					if i == 2 or i == 3 then
						R.fx.word("CLANK!", p + V3(0, 1.5, -1), 0.7)
					end
				end)
			end)
		end
		R.wait(2.4)
		-- BEAT 3 : le réacteur s'allume au ralenti
		R.cam.pushIn(V3(0, 3.4, -0.9), 7, 3.2, 0.7, { height = 0.2, fov = 50 })
		R.fx.implode(V3(0, 3.4, -1.0), 5, { CORE, WHITE })
		R.sound("PowerUp", V3(0, 3.4, -1), 1)
		R.wait(0.5)
		R.slowmo(0.3, 1.1)
		R.fx.flash(CORE, 0.04, 0.06, 0.4)
		R.fx.rays(CORE, V3(0, 3.4, -1.0))
		R.fx.light(V3(0, 3.4, -2), CORE, 30, 6, 1.2)
		R.transform(true)
		glowAll(CORE)
		R.fx.shockwave(V3(0, 0.2, 0), 10, CORE)
		R.wait(0.6)
		-- BEAT 4 : les bras mécaniques se lèvent puis frappent le sol
		R.slowmo(1)
		R.cam.lowAngle(V3(0, 4, 0), 9, 0.4)
		R.moveTo(pieces[2].obj, CF(-3.4, 8.2, 0.9), 0.3, ES.Quad, ED.Out)
		R.moveTo(pieces[3].obj, CF(3.4, 8.2, 0.9), 0.3, ES.Quad, ED.Out)
		R.anim({
			{ t = 0 },
			{ t = 0.3, RS = { p = 3.1, r = 0.3 }, LS = { p = 3.1, r = 0.3 }, RJ = { ln = -0.3 }, RH = { p = 0.1 }, LH = { p = 0.1 } },
			{ t = 0.45, RS = { p = 1.0, r = 0.5 }, LS = { p = 1.0, r = 0.5 }, RJ = { ln = 0.45 }, RH = { p = 0.5, r = 0.3 }, LH = { p = -0.3, r = 0.3 } },
			{ t = 0.9, RS = { p = 1.0, r = 0.5 }, LS = { p = 1.0, r = 0.5 }, RJ = { ln = 0.4 }, RH = { p = 0.5, r = 0.3 }, LH = { p = -0.3, r = 0.3 } },
		})
		R.wait(0.3)
		R.moveTo(pieces[2].obj, CF(-3.6, 4.6, -0.9) * ANG(rad(-25), 0, 0), 0.15, ES.Quad, ED.In)
		R.moveTo(pieces[3].obj, CF(3.6, 4.6, -0.9) * ANG(rad(-25), 0, 0), 0.15, ES.Quad, ED.In)
		R.wait(0.15)
		R.freeze(0.14)
		for _, x in ipairs({ -3.6, 3.6 }) do
			R.fx.quake(V3(x, 0, -2.5), 7, OR)
			R.fx.debris(V3(x, 0.3, -2.5), 10, { C3(90, 90, 96), MECH })
		end
		R.fx.shockwave(V3(0, 0.2, -1), 16, OR)
		R.fx.word("MEGA!", V3(0, 8, -2), 1.3, "Heavy")
		R.sound("GroundSlam", V3(0, 0, -2), 1)
		R.cam.shake(1.0)
		R.wait(0.5)
		-- BEAT 5 : les bras reviennent, vapeur par les cheminées, pose de force
		for i = 2, 3 do
			R.moveTo(pieces[i].obj, pieces[i].final, 0.4, ES.Back, ED.Out)
		end
		R.pose(flexPose)
		R.fx.smoke(V3(-1.2, 8.6, 1.9), 8, C3(220, 220, 225), 2)
		R.fx.smoke(V3(1.2, 8.6, 1.9), 8, C3(220, 220, 225), 2)
		R.sound("Spray", V3(0, 8, 2), 0.7)
		R.cam.hero(0.8)
		R.wait(0.6)
		R.title()
		R.wait(1.4)
	end,
}
------------------------------------------------------------------------ MARKETING GURU
-- RARE · Hashtag Hustler — POV selfie : la caméra EST son téléphone, trois clichés figés, le # géant arrive derrière lui.
P.MarketingGuru_Rare = {
	Caption = "Personal brand: 100%. Actual work: to be determined.",
	Location = "Rooftop Content House - Golden Hour",
	Reveal = function(R, ctx)
		R.stage("Studio", { color = C3(255, 205, 235), floor = C3(250, 232, 245) })
		local FINAL = CF(0, 3, 0)
		-- grand # néon (4 barres) qui arrive du ciel
		local hash = R.model({
			{ Size = V3(0.7, 6, 0.6), CFrame = CF(-0.9, 0, 0) * ANG(0, 0, rad(-10)), Color = MAG, Material = "Neon" },
			{ Size = V3(0.7, 6, 0.6), CFrame = CF(0.9, 0, 0) * ANG(0, 0, rad(-10)), Color = MAG, Material = "Neon" },
			{ Size = V3(5.4, 0.7, 0.6), CFrame = CF(0.2, 1.1, 0), Color = MAG, Material = "Neon" },
			{ Size = V3(5.4, 0.7, 0.6), CFrame = CF(-0.2, -1.1, 0), Color = MAG, Material = "Neon" },
		}, CF(0, 30, 7))
		local hashLight = R.light(V3(0, 6, 6), MAG, 20, 0)
		-- bulles de « likes » en arrière-plan
		for i = 1, 6 do
			local b = R.ball(R.rand(0.8, 1.6), V3(R.rand(-9, 9), R.rand(2, 10), R.rand(8, 12)), (i % 2 == 0) and C3(255, 140, 190) or CYAN, "Neon", 0.4)
			local bp = R.pos(b)
			R.moveTo(b, CF(bp.X, bp.Y + 1.5, bp.Z), 4, ES.Sine, ED.InOut)
		end
		local counter = R.billboard("♥ 0", V3(-2.6, 7.2, -1.2), { size = 3, Color = WHITE, StrokeColor = C3(255, 40, 120), Bg = C3(255, 60, 140) })
		local pose1 = { RS = { p = 2.25, y = 0.35, r = -0.15 }, LS = { p = 2.7, r = 0.7 }, RJ = { sd = -0.12, ln = -0.06 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
		local pose2 = { RS = { p = 2.2, y = 0.35, r = -0.15 }, LS = { p = 0.35, r = 0.35 }, RJ = { sd = 0.2, tw = -0.3, ln = 0.12 }, RH = { p = 0.3 }, LH = { p = -0.25 } }
		local pose3 = { RS = { p = 2.3, y = 0.3, r = -0.15 }, LS = { p = 1.65, y = 0.5, r = -0.25 }, RJ = { ln = -0.22, tw = 0.22 }, RH = { r = 0.3 }, LH = { r = 0.3 } }
		local finalPose = { RS = { p = 2.9, r = 0.25 }, LS = { p = 2.5, r = 0.75, y = -0.8 }, RJ = { tw = -0.2, ln = -0.1 }, RH = { r = 0.2 }, LH = { p = 0.2, r = 0.2 } }
		R.onSkip(function(R)
			hash:PivotTo(R.at(0, 6, 7))
			hashLight.Brightness = 3
			counter.Label.Text = "♥ 1.2M"
			R.place(FINAL)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- POV du téléphone (main droite tendue = côté +X), cadre penché
		local function snap(pose, camPos, roll, count)
			R.pose(pose)
			R.cam.cut(camPos, V3(0, 4.55, 0), 72, roll)
			R.wait(0.32)
			R.sound("UIClick", V3(0, 5, -2), 1, 1.3)
			R.fx.flash(WHITE, 0.02, 0.02, 0.18)
			R.freeze(0.16)
			R.fx.hearts(V3(R.rand(-1.5, 1.5), 4.5, -1.2), 6, C3(255, 70, 140))
			counter.Label.Text = count
			R.cam.punch(4)
		end
		snap(pose1, V3(1.25, 5.4, -3.1), 0.12, "♥ 1.2K")
		snap(pose2, V3(1.0, 5.2, -2.7), -0.1, "♥ 120K")
		snap(pose3, V3(1.4, 5.7, -2.9), 0.18, "♥ 1.2M")
		R.fx.word("VIRAL!", V3(-1.8, 6.6, -1.5), 0.8)
		R.cam.roll(0, 0.3)
		-- le # géant tombe en tournoyant derrière lui ; la caméra quitte le téléphone
		R.cam.move(V3(-3.6, 4.0, -9.2), V3(0, 5.0, 2.5), 0.55, 62, ES.Quad, ED.Out)
		R.over(0.5, function(a, e)
			hash:PivotTo(R.at(0, 30 - 24 * e, 7) * ANG(0, (1 - e) * 4 * PI, 0))
		end, ES.Back, ED.Out)
		R.wait(0.45)
		R.tween(hashLight, 0.2, { Brightness = 3 })
		R.fx.shockwave(V3(0, 0.2, 7), 8, MAG)
		R.sound("BigImpact", V3(0, 4, 7), 0.6)
		R.cam.shake(0.35)
		R.pose(finalPose)
		R.fx.word("#HUSTLE", V3(0, 9.6, 6.5), 1)
		R.wait(0.9)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Hype Coach Live — rythme : trois mots claquent sur les écrans LED à chaque saut, glissade à genoux, colonnes de feu.
P.MarketingGuru_Epic = {
	Caption = "Let's GOOOO! (to the 3pm meeting about the 4pm meeting)",
	Location = "Hustle Arena - Sold Out Webinar",
	Reveal = function(R, ctx)
		R.stage("Void")
		local START, FINAL = CF(-7, 3, 1), CF(2.5, 3, 1)
		R.mark(FINAL)
		-- scène : bord LED, mur de 3 écrans
		R.box(V3(26, 0.12, 0.3), CF(0, 0.06, -4.5), MAG, "Neon")
		R.box(V3(26, 0.06, 12), CF(0, 0.03, 1.5), C3(28, 26, 38), "SmoothPlastic")
		local screens, labels = {}, {}
		for i, x in ipairs({ -8, 0, 8 }) do
			local s = R.box(V3(7, 4, 0.4), CF(x, 5.5, 9), C3(12, 12, 20))
			screens[i] = s
			labels[i] = R.text(s, "", { Color = WHITE })
			R.box(V3(7.4, 4.4, 0.2), CF(x, 5.5, 9.25), C3(40, 40, 55), "Metal")
		end
		-- public en ombres chinoises au premier plan
		local heads = {}
		for i = 0, 13 do
			local x = -13 + i * 2 + R.rand(-0.4, 0.4)
			local z = -9.5 - (i % 2) * 1.3
			local h = R.ball(1.3, V3(x, 2.3, z), C3(10, 10, 14))
			R.box(V3(1.8, 2.2, 0.8), CF(x, 0.9, z), C3(10, 10, 14))
			heads[#heads + 1] = { part = h, x = x, z = z, ph = R.rand(0, 6) }
		end
		local cheering = true
		R.every(0.05, function(i)
			if not cheering then
				return
			end
			for _, hd in ipairs(heads) do
				hd.part:PivotTo(R.at(hd.x, 2.3 + math.abs(math.sin(i * 0.35 + hd.ph)) * 0.6, hd.z))
			end
		end)
		local slidePose = { RS = { p = 2.7, r = 0.95 }, LS = { p = 2.7, r = 0.95 }, RJ = { ln = -0.5 }, RH = { p = -0.35 }, LH = { p = -0.35 } }
		local finalPose = { RS = { p = 1.65, y = 0.1 }, LS = { p = 0.4, r = 0.5 }, RJ = { tw = 0.35, ln = 0.08 }, RH = { p = -0.3, r = 0.12 }, LH = { p = 0.35, r = 0.12 } }
		local WORDS = { { "GRIND", MAG }, { "HUSTLE", CYAN }, { "SYNERGY", GOLD } }
		R.onSkip(function(R)
			for i = 1, 3 do
				screens[i].Material = Enum.Material.Neon
				screens[i].Color = C3(40, 10, 50)
				labels[i].Text = "LET'S GOOO!"
				labels[i].TextColor3 = WORDS[i][2]
			end
			R.place(FINAL)
			R.transform(true)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : trois temps, trois mots, trois angles
		R.place(START)
		R.fx.smoke(V3(0, 0.5, 2), 10, C3(80, 70, 110), 3)
		local cams = {
			{ V3(-4, 2.0, -6), V3(-7, 4.6, 1), 55 },
			{ V3(-11, 6.5, -4.5), V3(-6, 3.6, 2), 60 },
			{ V3(-7.5, 1.2, -4.2), V3(-7, 5.0, 1), 66 },
		}
		for i, w in ipairs(WORDS) do
			R.cam.cut(cams[i][1], cams[i][2], cams[i][3], (i == 2) and -0.12 or 0)
			R.jump(R.rig, START, 0.38, 1.3)
			R.wait(0.19)
			screens[i].Material = Enum.Material.Neon
			screens[i].Color = C3(40, 10, 50)
			labels[i].Text = w[1]
			labels[i].TextColor3 = w[2]
			R.fx.banner(w[1], { color = w[2], t = 0.38, size = 0.2 })
			R.sound("Thud", V3(0, 3, 4), 1, 0.7 + i * 0.1)
			R.cam.punch(-7)
			R.fx.light(V3(-8 + (i - 1) * 8, 5.5, 7), w[2], 18, 4, 0.4)
			R.wait(0.42)
		end
		-- BEAT 2 : course + glissade à genoux, traînées LED, travelling latéral
		R.place(START * FACE_PX)
		R.walk(CF(-4.2, 3, 1) * FACE_PX, 0.32, "Run")
		R.cam.track(1.5, function()
			local p = R.pos(R.root)
			return p + V3(-0.6, 0.0, -7.2), p + V3(1.0, 0.6, 0), 62
		end)
		R.wait(0.32)
		R.pose(slidePose)
		R.moveTo(R.rig, CF(2.5, 1.75, 1) * FACE_PX, 0.95, ES.Quad, ED.Out)
		local rl, ll = limb(R, "Right Leg"), limb(R, "Left Leg")
		if rl then
			R.fx.trail(rl, CYAN, 1.2)
		end
		if ll then
			R.fx.trail(ll, MAG, 1.2)
		end
		local sliding = true
		R.every(0.06, function()
			if sliding then
				local p = R.pos(R.root)
				R.fx.sparks(V3(p.X - 0.8, 0.2, p.Z), 3, C3(255, 220, 120))
			end
		end)
		R.sound("Dash", V3(0, 1, 1), 0.8)
		R.wait(0.95)
		sliding = false
		-- BEAT 3 : colonnes de feu, il bondit et pointe le public
		R.sound("Explosion", V3(0, 3, 6), 0.7)
		for _, x in ipairs({ -10, -4, 4, 10 }) do
			R.fx.pillar(V3(x, 0, 6.5), 1.1, 13, C3(255, 120, 30), 0.9)
			R.fx.fire(V3(x, 0.5, 6.5), 1.0, C3(255, 140, 40), 2)
		end
		R.moveTo(R.rig, FINAL * FACE_PX, 0.18, ES.Quad, ED.Out)
		R.face(V3(2.5, 3, -10), 0.2)
		R.wait(0.2)
		R.transform(true)
		R.pose(finalPose)
		for i = 1, 3 do
			labels[i].Text = "LET'S GOOO!"
		end
		R.fx.banner("LET'S GOOO!", { color = C3(255, 40, 90), t = 0.9, size = 0.2 })
		R.fx.confetti(V3(2.5, 12, 1), 80, { MAG, CYAN, GOLD, WHITE })
		R.cam.lowAngle(V3(2.5, 4.2, 1), 8, 0.35)
		R.cam.shake(0.4)
		R.wait(1.1)
		R.title()
		R.wait(1.2)
		cheering = false
	end,
}

-- LEGENDARY · Ad Overlord — prise de contrôle publicitaire : compte à rebours, panneaux qui s'allument, POV du drone,
-- claquement de doigts et faisceaux, bouton SKIP AD balayé au ralenti, pluie de pièces.
P.MarketingGuru_Legendary = {
	Caption = "This skin is sponsored by... this skin. Skip ad in 5... 4...",
	Location = "Downtown Ad Plaza - Every Screen, Everywhere",
	Reveal = function(R, ctx)
		local FINAL = CF(0, 3.25, 0)
		R.stage("Night")
		R.mark(FINAL)
		R.floor(V3(40, 0.2, 40), CF(0, -0.08, 4), C3(28, 26, 40), "Concrete")
		-- 5 panneaux géants en arc face au héros
		local ADS = {
			{ "BUY NOW", CYAN }, { "50% OFF", GOLD }, { "SCAN ME", MAG }, { "LIKE & SHARE", C3(120, 255, 120) }, { "MEGA SALE!", C3(255, 70, 90) },
		}
		local boards = {}
		for i = 1, 5 do
			local a = rad(-64 + (i - 1) * 32)
			local pos = V3(math.sin(a) * 15, 8.5, math.cos(a) * 15)
			R.cyl(6, 0.6, V3(pos.X, 3, pos.Z), C3(60, 62, 72), "Metal")
			local cf = CFrame.lookAt(pos, V3(0, 8.5, 0))
			R.box(V3(7.4, 4.2, 0.3), cf * CF(0, 0, 0.3), C3(50, 50, 60), "Metal")
			local s = R.box(V3(7, 3.8, 0.3), cf, C3(8, 8, 14))
			boards[i] = { part = s, label = R.text(s, "", { Color = ADS[i][2] }), pos = pos, color = ADS[i][2] }
		end
		-- plateforme holographique (cylindre vertical) qui descend du ciel
		local disc = R.box(V3(0.3, 5, 5), CF(0, 16, 0) * ANG(0, 0, PI / 2), CYAN, "Neon", 0.25, "Cyl")
		local drone = R.mesh("MarketingGuru_Legendary_Drone", CF(0, 10, -8), 1.1) or R.prop("Drone", CF(0, 10, -8))
		local skip = R.box(V3(4.2, 1.3, 0.3), CF(-14, -50, -3), C3(30, 30, 38))
		R.text(skip, "SKIP AD ▶", { Color = WHITE })
		R.show(skip, false)
		local snapAnim = {
			{ t = 0 },
			{ t = 0.22, RS = { p = 2.3, y = 0.6, r = 0.35 }, RJ = { tw = 0.25, ln = -0.05 } },
			{ t = 0.32, RS = { p = 1.95, y = 0.9, r = 0.1 }, RJ = { tw = -0.12, ln = 0.05 } },
			{ t = 1.6, RS = { p = 1.95, y = 0.9, r = 0.1 }, RJ = { tw = -0.12, ln = 0.05 } },
		}
		local swat = {
			{ t = 0, RS = { p = 1.6, r = -0.9, y = 0.4 }, RJ = { tw = -0.55 } },
			{ t = 0.16, RS = { p = 1.75, r = 1.1, y = -0.2 }, RJ = { tw = 0.55, ln = 0.1 } },
			{ t = 0.6, RS = { p = 1.5, r = 1.0 }, RJ = { tw = 0.4 } },
		}
		local function screensAll(text, col)
			for _, b in ipairs(boards) do
				b.part.Material = Enum.Material.Neon
				b.part.Color = C3(25, 10, 40)
				b.label.Text = text
				b.label.TextColor3 = col or b.color
			end
		end
		R.onSkip(function(R)
			screensAll("♛ OVERLORD", GOLD)
			disc:PivotTo(R.at(0, 0.1, 0) * ANG(0, 0, PI / 2))
			R.place(FINAL)
			R.transform(true)
			R.pose("Boss")
			R.cam.hero()
		end)

		-- BEAT 1 : compte à rebours publicitaire, les panneaux s'allument un par un
		R.place(CF(0, 19.25, 0))
		R.cam.cut(V3(0, 2.4, -24), V3(0, 7, 2), 60)
		R.cam.move(V3(0, 3.2, -15), V3(0, 7.5, 2), 1.9, 60, ES.Sine, ED.Out)
		for i = 1, 5 do
			R.fx.banner("AD · " .. (6 - i), { color = WHITE, t = 0.3, size = 0.12, y = 0.15 })
			local b = boards[i]
			R.fx.glitch()
			R.sound("Electric", b.pos, 0.5)
			b.part.Material = Enum.Material.Neon
			b.part.Color = C3(25, 10, 40)
			b.label.Text = ADS[i][1]
			R.fx.light(b.pos, b.color, 14, 3, 0.3)
			R.wait(0.36)
		end
		-- BEAT 2 : POV du drone qui tourne autour de la plateforme qui descend
		local function droneAt(a)
			local ang = -PI / 2 + a * PI * 0.65
			return V3(math.sin(ang) * 7.5, 9.5 - a * 3.5, -math.cos(ang) * 7.5)
		end
		R.pose("ArmsCrossed")
		R.over(2.0, function(a, e)
			local y = 16 - 15.9 * e
			disc:PivotTo(R.at(0, y, 0) * ANG(0, 0, PI / 2))
			R.place(CF(0, y + 3.15, 0))
			if drone then
				local dp = droneAt(a)
				drone:PivotTo(CFrame.lookAt(R.wp(dp.X, dp.Y, dp.Z), R.wp(0, y + 3, 0)))
			end
		end, ES.Quad, ED.Out)
		R.cam.track(2.0, function(a)
			local dp = droneAt(a)
			local out = V3(dp.X, 0, dp.Z).Unit
			local y = 16 - 15.9 * (1 - (1 - a) * (1 - a))
			return dp + out * 2.4 + V3(0, 2.2, 0) + V3(-out.Z, 0, out.X) * 1.6, V3(0, y + 3.5, 0), 62
		end)
		R.fx.pillar(V3(0, 0, 0), 2.4, 18, CYAN, 2.0)
		R.wait(2.0)
		R.fx.shockwave(V3(0, 0.2, 0), 10, CYAN)
		R.sound("BigImpact", V3(0, 0, 0), 0.6)
		-- BEAT 3 : claquement de doigts, tous les écrans basculent, faisceaux convergents
		R.cam.orbit(V3(0, 4.2, 0), 9, 1.6, -0.55, 0.45, 1.9, 60, 52)
		R.anim(snapAnim)
		R.wait(0.32)
		R.sound("UIClick", V3(1, 5, 0), 1, 0.7)
		R.fx.ring(V3(1.4, 5.0, -0.8), V3(0, 0, -1), 2, WHITE)
		screensAll("BUY NOW", nil)
		R.transform(true)
		for i, b in ipairs(boards) do
			R.delay(i * 0.05, function()
				R.fx.beam(b.pos, V3(0, 4.5, 0), 0.5, b.color, 0.9)
			end)
		end
		R.fx.implode(V3(0, 4.5, 0), 6, { CYAN, MAG, GOLD })
		R.cam.shake(0.45)
		R.wait(1.3)
		-- BEAT 4 : le bouton SKIP AD fonce sur lui, revers au ralenti, il explose en éclats
		skip:PivotTo(R.at(-14, 5.2, -3))
		R.show(skip, true, 0.1)
		R.cam.cut(V3(-3.4, 3.4, -6.5), V3(-0.2, 5.0, -1.5), 50)
		R.moveTo(skip, CF(-0.9, 5.0, -2.4) * ANG(0, rad(15), 0), 0.55, ES.Quad, ED.In)
		R.anim(swat)
		R.wait(0.3)
		R.slowmo(0.22, 0.9)
		R.wait(0.12)
		R.freeze(0.18)
		R.fx.shards(V3(-0.9, 5.0, -2.4), 18, { C3(30, 30, 38), WHITE, CYAN })
		R.fx.word("DENIED!", V3(-2.5, 6.8, -2.6), 1.1)
		R.sound("GlassBreak", V3(-0.9, 5, -2.4), 0.9)
		R.fly(skip, { V3(-0.9, 5.0, -2.4), V3(-8, 9, -6), V3(-18, 4, -10) }, 0.5)
		R.spin(skip, 3, 0.5, "Z")
		R.fx.rain({ Colors = { GOLD, C3(255, 230, 120) }, Size = V3(0.12, 0.8, 0.8), Shape = "Cyl", Material = "Foil", Count = 45 }, 3)
		R.fx.coins(V3(0, 6, -1), 24)
		R.cam.lowAngle(V3(0, 4.5, 0), 7.5, 0.6)
		R.wait(0.5)
		-- FIN : « OVERLORD » sur tous les écrans
		R.slowmo(1)
		screensAll("♛ OVERLORD", GOLD)
		R.fx.flash(GOLD, 0.03, 0.03, 0.3)
		R.pose("Boss")
		R.cam.hero(0.7)
		R.wait(0.5)
		R.title()
		R.wait(1.5)
	end,
}
------------------------------------------------------------------------ LAWYER
-- RARE · Barrister Supreme — l'objet d'abord : la mallette claque sur le bureau (vue du dessus), s'ouvre, tempête de papiers.
P.Lawyer_Rare = {
	Caption = "Powdered wig. Unpowdered arguments. Bills by the second.",
	Location = "Chambers of Barrister & Barrister & Barrister",
	Reveal = function(R, ctx)
		local WOODD, LEATH = C3(80, 45, 28), C3(75, 42, 25)
		R.stage("Room", { color = C3(110, 66, 40), floor = C3(110, 30, 40), w = 26, d = 24, h = 13 })
		-- bibliothèque derrière
		R.box(V3(15, 9.5, 1.2), CF(0, 4.75, 5.2), WOODD, "Wood")
		local BOOKS = { C3(130, 25, 35), C3(30, 60, 110), C3(35, 90, 50), C3(200, 170, 90), C3(90, 30, 70) }
		for row = 0, 3 do
			R.box(V3(14.6, 0.2, 1.0), CF(0, 1.1 + row * 2.2, 4.75), C3(60, 35, 22), "Wood")
			local x = -7
			while x < 6.8 do
				local w = R.rand(0.35, 0.6)
				local h = R.rand(1.3, 1.85)
				R.box(V3(w, h, 0.8), CF(x + w / 2, 1.2 + row * 2.2 + h / 2, 4.7), BOOKS[R.randi(1, #BOOKS)])
				x += w + 0.04
			end
		end
		-- bureau + lampe de banquier
		R.box(V3(6.4, 0.35, 2.8), CF(0, 3.1, -2.4), C3(95, 52, 30), "Wood")
		R.box(V3(6.4, 2.95, 0.25), CF(0, 1.5, -3.7), C3(85, 46, 27), "Wood")
		R.box(V3(0.4, 2.95, 2.6), CF(-3.0, 1.5, -2.4), C3(85, 46, 27), "Wood")
		R.box(V3(0.4, 2.95, 2.6), CF(3.0, 1.5, -2.4), C3(85, 46, 27), "Wood")
		R.box(V3(0.5, 0.15, 0.5), CF(2.3, 3.35, -2.0), GOLD, "Metal")
		R.box(V3(0.1, 0.9, 0.1), CF(2.3, 3.8, -2.0), GOLD, "Metal")
		local shade = R.box(V3(1.3, 0.35, 0.6), CF(2.3, 4.3, -2.2), C3(20, 120, 60), "Neon")
		R.light(shade, C3(200, 255, 200), 10, 1.2)
		-- mallette : corps + couvercle articulé + fermoirs + poignée
		local base = R.box(V3(2.2, 0.55, 1.5), CF(0, 17, -2.3), LEATH)
		local lid = R.box(V3(2.2, 0.18, 1.5), CF(0, 17.37, -2.3), LEATH)
		local clasps = {}
		for _, x in ipairs({ -0.6, 0.6 }) do
			clasps[#clasps + 1] = R.box(V3(0.25, 0.25, 0.08), CF(x, 17.2, -3.08), GOLD, "Metal")
		end
		local HINGE = CF(0, 3.83, -1.55)
		local LID_CLOSED, LID_OPEN = CF(0, 3.92, -2.3), HINGE * ANG(rad(105), 0, 0) * CF(0, 0.09, -0.75)
		local finger = { RS = { p = 2.75, r = -0.05, y = 0.2 }, LS = { p = 0.5, r = -0.35, y = 0.9 }, RJ = { ln = -0.1, tw = 0.12 }, RH = { r = 0.1 }, LH = { r = 0.1 } }
		R.onSkip(function(R)
			base:PivotTo(R.at(0, 3.55, -2.3))
			lid:PivotTo(R.at(0, 3.83, -1.55) * ANG(rad(105), 0, 0) * CF(0, 0.09, -0.75))
			for i, c in ipairs(clasps) do
				c:PivotTo(R.at((i == 1) and -0.6 or 0.6, 3.6, -3.08))
			end
			R.place(CF(0, 3, 0))
			R.pose(finger)
			R.cam.cut(V3(-1.8, 5.2, -9.4), V3(0, 4.4, -0.5), 55)
		end)

		-- BEAT 1 : plongée verticale sur le bureau, la mallette tombe et claque
		R.cam.cut(V3(0, 13.5, -3.4), V3(0, 3.4, -2.3), 46)
		R.moveTo(base, CF(0, 3.55, -2.3), 0.26, ES.Quad, ED.In)
		R.moveTo(lid, LID_CLOSED, 0.26, ES.Quad, ED.In)
		for i, c in ipairs(clasps) do
			R.moveTo(c, CF((i == 1) and -0.6 or 0.6, 3.6, -3.08), 0.26, ES.Quad, ED.In)
		end
		R.wait(0.26)
		R.sound("Thud", V3(0, 3.5, -2.3), 1)
		R.fx.dust(V3(0, 3.3, -2.3), 2.5)
		R.cam.shake(0.35)
		R.wait(0.3)
		R.sound("Ding", V3(-0.6, 3.6, -3), 0.7, 1.4)
		R.wait(0.1)
		R.sound("Ding", V3(0.6, 3.6, -3), 0.7, 1.6)
		R.wait(0.12)
		-- le couvercle saute, tempête de papiers
		R.moveTo(lid, LID_OPEN, 0.18, ES.Back, ED.Out)
		R.fx.confetti(V3(0, 4.2, -2.3), 45, { WHITE, C3(245, 240, 225), C3(235, 230, 210) }, 3, 16)
		R.sound("Whoosh", V3(0, 4, -2.3), 0.9)
		for i = 1, 8 do
			local sheet = R.box(V3(0.85, 0.04, 1.1), CF(0, 4.0, -2.3), WHITE)
			local tx, tz = R.rand(-4, 4), R.rand(-5, 0)
			R.fly(sheet, { V3(0, 4.0, -2.3), V3(tx * 0.5, R.rand(8, 11), -2.3 + tz * 0.4), V3(tx, R.rand(0.5, 3), tz - 1) }, R.rand(1.6, 2.3))
			R.spin(sheet, R.rand(1, 3), 2.0, (i % 2 == 0) and "X" or "Z")
		end
		-- BEAT 2 : la caméra se redresse sur lui, il ajuste sa perruque et lève l'index
		R.cam.move(V3(-1.8, 5.2, -9.4), V3(0, 4.4, -0.5), 0.8, 55, ES.Quad, ED.InOut)
		R.anim({
			{ t = 0 },
			{ t = 0.25, RS = { p = 2.85, r = 0.55, y = -0.3 }, LS = { p = 2.85, r = 0.55, y = -0.3 }, RJ = { ln = -0.05 } },
			{ t = 0.4, RS = { p = 2.95, r = 0.6 }, LS = { p = 2.95, r = 0.6 }, RJ = { sd = 0.1 } },
			{ t = 0.55, RS = { p = 2.85, r = 0.55 }, LS = { p = 2.85, r = 0.55 }, RJ = { sd = -0.1 } },
			{ t = 0.75 },
		})
		R.wait(0.8)
		R.pose(finger)
		R.sound("Ding", V3(0, 5, 0), 0.8, 2)
		R.fx.word("AHEM.", V3(-1.4, 6.3, -0.6), 0.8)
		R.fx.twinkle(V3(0.9, 6.6, -0.2))
		R.wait(0.9)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · TV Judge — surgissement : « ALL RISE », il jaillit derrière le banc, coup de maillet ORDER!, le jury exulte.
P.Lawyer_Epic = {
	Caption = "Court is in session. Ratings are through the roof.",
	Location = "Studio 4 - Judge Supreme, Live Taping",
	Reveal = function(R, ctx)
		local WOOD, WOODD, RED = C3(140, 88, 50), C3(95, 58, 32), C3(230, 40, 50)
		local FINAL = CF(0, 4.2, 0.4)
		R.stage("Room", { color = C3(165, 115, 75), floor = C3(125, 85, 55), w = 34, d = 30, h = 15 })
		R.mark(FINAL)
		-- estrade + banc du juge
		R.floor(V3(9, 1.2, 4), CF(0, 0.6, 1.0), WOODD, "Wood")
		local bench = R.box(V3(9, 4.4, 2.6), CF(0, 2.2, -1.6), WOOD, "Wood")
		R.box(V3(9.3, 0.25, 2.9), CF(0, 4.5, -1.6), WOODD, "Wood")
		R.box(V3(9.32, 0.12, 2.92), CF(0, 4.3, -1.6), GOLD, "Metal")
		local seal = R.box(V3(2.4, 2.4, 0.1), CF(0, 2.3, -2.95), GOLD, "Foil", 0, "Block")
		R.text(seal, "⚖", { Color = C3(90, 50, 25) })
		local block = R.box(V3(0.35, 1.0, 1.0), CF(1.3, 4.8, -1.4) * ANG(0, 0, PI / 2), WOODD, "Wood", 0, "Cyl")
		-- décor du plateau : sceau mural, drapés, ON AIR, caméra TV
		local wallSeal = R.box(V3(0.2, 4.5, 4.5), CF(0, 9, 7) * ANG(0, PI / 2, 0), GOLD, "Foil", 0, "Cyl")
		for _, x in ipairs({ -6, 6 }) do
			R.box(V3(2.4, 11, 0.3), CF(x, 6.5, 7.2), C3(120, 20, 40), "Fabric")
		end
		local onAir = R.box(V3(3.2, 1.1, 0.3), CF(-8, 11.5, 6.8), C3(60, 10, 10), "Neon")
		R.text(onAir, "ON AIR", { Color = WHITE })
		R.prop("Camera", CF(-9, 0, -8) * ANG(0, rad(-35), 0))
		-- tribune du jury (à l'écran à gauche = côté +X)
		R.box(V3(2.5, 2.6, 7.5), CF(10, 1.3, -3.5), WOOD, "Wood")
		local jurors = {}
		for i = 0, 5 do
			local row = i % 2
			local z = -6.3 + math.floor(i / 2) * 2.6
			local x = 11.4 + row * 1.6
			local base = 1.2 + row * 0.9
			local body = R.box(V3(1.2, 2.0, 1.0), CF(x, base + 1.0, z), C3(R.randi(60, 200), R.randi(60, 200), R.randi(60, 200)))
			local head = R.box(V3(1.1, 1.1, 1.1), CF(x, base + 2.6, z), C3(245, 205, 160))
			R.text(head, ":)", { Color = DARK })
			jurors[#jurors + 1] = { body = body, head = head, x = x, z = z, base = base }
		end
		local applause = R.box(V3(4.2, 1.2, 0.3), CF(8, 11, 4) * ANG(0, rad(-20), 0), C3(60, 10, 10), "Neon")
		local applauseLbl = R.text(applause, "APPLAUSE", { Color = C3(255, 220, 220) })
		local gavel
		local slam = {
			{ t = 0 },
			{ t = 0.3, RS = { p = 3.3, r = 0.15 }, LS = { p = 2.9, r = 0.1 }, RJ = { ln = -0.35, tw = 0.1 }, RH = { p = -0.1 }, LH = { p = 0.15 } },
			{ t = 0.42, RS = { p = 1.15, r = 0.1 }, LS = { p = 0.9 }, RJ = { ln = 0.45, tw = -0.05 }, RH = { p = 0.15 }, LH = { p = -0.15 } },
			{ t = 1.1, RS = { p = 1.25, r = 0.1 }, LS = { p = 0.95 }, RJ = { ln = 0.35 }, RH = { p = 0.15 }, LH = { p = -0.15 } },
		}
		local finalPose = { RS = { p = 2.9, r = 0.2 }, LS = { p = 1.6, y = 0.1 }, RJ = { tw = -0.25, ln = -0.08 }, RH = { r = 0.1 }, LH = { r = 0.1 } }
		local function cheer(on)
			for _, j in ipairs(jurors) do
				local up = on and 1.0 or 0
				j.body:PivotTo(R.at(j.x, j.base + 1.0 + up, j.z))
				j.head:PivotTo(R.at(j.x, j.base + 2.6 + up, j.z))
			end
		end
		R.onSkip(function(R)
			cheer(true)
			R.place(FINAL)
			R.transform(true)
			if not gavel then
				gavel = R.hold("LWGavelBig", "Right")
			end
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : ALL RISE — travelling le long du banc vide, le jury se lève, ON AIR clignote
		R.place(CF(0, 0.6, 0.4))
		R.every(0.45, function(i)
			onAir.Color = (i % 2 == 0) and RED or C3(60, 10, 10)
		end)
		R.cam.dolly(V3(8, 4.8, -8.5), V3(-3, 4.8, -8.5), V3(0, 4.4, -1), 1.7, 55)
		R.wait(0.3)
		R.fx.banner("ALL RISE!", { color = GOLD, t = 0.9, size = 0.15 })
		R.sound("Whistle", V3(0, 4, 0), 0.5, 0.8)
		for i, j in ipairs(jurors) do
			R.delay(i * 0.08, function()
				R.moveTo(j.body, CF(j.x, j.base + 1.5, j.z), 0.3, ES.Back, ED.Out)
				R.moveTo(j.head, CF(j.x, j.base + 3.1, j.z), 0.3, ES.Back, ED.Out)
			end)
		end
		R.wait(1.3)
		-- BEAT 2 : il surgit de derrière le banc, maillet en main
		R.cam.cut(V3(0, 3.6, -9.5), V3(0, 5.6, 0), 46)
		gavel = R.hold("LWGavelBig", "Right")
		R.moveTo(R.rig, FINAL, 0.42, ES.Back, ED.Out)
		R.sound("Whoosh", V3(0, 4, 0), 0.9, 0.8)
		R.pose("Boss")
		R.wait(0.6)
		-- BEAT 3 : coup de maillet — ORDER!
		R.cam.pushIn(V3(0.6, 5.2, 0), 9.5, 6.2, 0.4, { height = -0.6, fov = 50 })
		R.anim(slam)
		R.wait(0.42)
		R.freeze(0.13)
		R.fx.bigImpact(V3(1.3, 4.9, -1.4), V3(0, -1, 0), 1.2, GOLD)
		R.fx.shockwave(V3(1.3, 4.65, -1.4), 7, GOLD)
		R.fx.banner("ORDER!", { color = GOLD, t = 0.8, size = 0.22 })
		R.fx.confetti(V3(0, 5, -1.5), 30, { WHITE, C3(245, 240, 225) }, 4, 10)
		R.sound("GroundSlam", V3(1.3, 4.8, -1.4), 1)
		R.cam.shake(0.75)
		R.transform(true)
		R.wait(0.55)
		-- le jury exulte (whip vers la tribune puis retour)
		R.cam.whip(V3(4.5, 5.2, -9), V3(11, 3.8, -3.8))
		R.every(0.12, function(i)
			cheer(i % 2 == 0)
			applause.Color = (i % 2 == 0) and RED or C3(60, 10, 10)
		end)
		R.fx.confetti(V3(11.5, 8, -4), 50)
		R.sound("Combo", V3(11, 4, -4), 0.6)
		applauseLbl.Text = "APPLAUSE"
		R.wait(0.75)
		R.cam.whip(V3(-1.2, 5.0, -7.5), V3(0, 5.3, 0))
		R.pose(finalPose)
		R.fx.word("CASE CLOSED!", V3(-2, 7.6, -1.5), 0.9)
		R.wait(0.4)
		R.title()
		R.wait(1.2)
	end,
}

-- LEGENDARY · Supreme Closer — entrée en marchant : balance dans le noir, portes défoncées, marche au ralenti,
-- OBJECTION! en image figée, mallette d'or claquée, la balance penche, CASE CLOSED.
P.Lawyer_Legendary = {
	Caption = "Case closed. Building closed. Everything closed. OBJECTION sustained.",
	Location = "Supreme Hall of Billable Hours",
	Reveal = function(R, ctx)
		local MARBLE, DOORC = C3(236, 232, 224), C3(70, 40, 25)
		local FINAL = CF(0, 3, 0.6)
		R.stage("Void")
		R.mark(FINAL)
		R.floor(V3(12, 0.2, 30), CF(0, -0.09, 5), MARBLE, "Marble")
		R.box(V3(3.4, 0.03, 26), CF(0, 0.02, 6), C3(150, 20, 40), "Fabric")
		-- colonnes avec lanternes (éteintes)
		local lamps = {}
		for _, z in ipairs({ -1, 4, 9 }) do
			for _, x in ipairs({ -5.5, 5.5 }) do
				R.cyl(12, 1.7, V3(x, 6, z), MARBLE, "Marble")
				R.box(V3(2.2, 0.6, 2.2), CF(x, 0.3, z), C3(210, 205, 195), "Marble")
				local l = R.ball(0.7, V3(x * 0.82, 7.5, z), C3(80, 70, 50), "Neon")
				lamps[#lamps + 1] = { part = l, z = z, on = false }
			end
		end
		-- grandes portes au fond (charnières à x = ±3)
		R.box(V3(8, 0.8, 0.8), CF(0, 9.4, 12.5), GOLD, "Metal")
		R.box(V3(0.8, 9.8, 0.8), CF(-3.4, 4.9, 12.5), GOLD, "Metal")
		R.box(V3(0.8, 9.8, 0.8), CF(3.4, 4.9, 12.5), GOLD, "Metal")
		R.box(V3(4.5, 12, 0.5), CF(-5.25, 6, 13.2), C3(20, 18, 24))
		R.box(V3(4.5, 12, 0.5), CF(5.25, 6, 13.2), C3(20, 18, 24))
		R.box(V3(6, 2.6, 0.5), CF(0, 10.7, 13.2), C3(20, 18, 24))
		local doorL = R.box(V3(3, 9, 0.45), CF(-1.5, 4.5, 12.5), DOORC, "Wood")
		local doorR = R.box(V3(3, 9, 0.45), CF(1.5, 4.5, 12.5), DOORC, "Wood")
		local hallLight = R.light(V3(0, 5, 15), C3(255, 225, 160), 40, 0)
		local function doorCF(s, a)
			return CF(3 * s, 4.5, 12.5) * ANG(0, a * s, 0) * CF(-1.5 * s, 0, 0)
		end
		-- pupitre en marbre et balance flottante
		R.box(V3(3.2, 3.2, 1.4), CF(0, 1.6, -1.6), MARBLE, "Marble")
		R.box(V3(3.3, 0.15, 1.5), CF(0, 3.25, -1.6), GOLD, "Metal")
		local SC = CF(-4.0, 6.4, -3.2)
		local scales = R.mesh("Lawyer_Legendary_Scales", SC, 3)
		local spot = R.spot(V3(-4.0, 16, -3.2), V3(-4.0, 5, -3.2), { color = C3(255, 235, 190), width = 3.2, on = false })
		local function tilt(a)
			if scales then
				scales:PivotTo(R.at(SC.X, SC.Y, SC.Z) * ANG(0, 0, a))
			end
		end
		local slamL = {
			{ t = 0 },
			{ t = 0.28, LS = { p = 3.05, r = 0.15 }, RS = { p = 0.4, r = 0.3 }, RJ = { ln = -0.3, tw = -0.15 } },
			{ t = 0.4, LS = { p = 1.25, r = -0.05 }, RS = { p = 0.2, r = 0.35 }, RJ = { ln = 0.35, tw = 0.1 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
			{ t = 1.2, LS = { p = 1.3 }, RS = { p = 0.2, r = 0.35 }, RJ = { ln = 0.28, tw = 0.1 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		}
		local finalPose = "Shades"
		local function lampsOn()
			for _, l in ipairs(lamps) do
				l.part.Color = C3(255, 220, 140)
			end
		end
		R.onSkip(function(R)
			doorL:PivotTo(R.at(-3, 4.5, 12.5))
			doorR:PivotTo(R.at(3, 4.5, 12.5))
			lampsOn()
			hallLight.Brightness = 3
			spot.on(0)
			tilt(0.32)
			R.place(FINAL)
			R.transform(true)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : dans le noir, la balance de la justice vacille sous un projecteur
		R.place(CF(0, 3, 17))
		spot.on(0.2)
		R.cam.cut(V3(-1.6, 6.8, -8.4), V3(-4.0, 6.3, -3.2), 36)
		R.cam.move(V3(-2.4, 6.4, -7.2), V3(-4.0, 6.3, -3.2), 1.6, 34)
		R.over(1.6, function(a)
			tilt(math.sin(a * 14) * 0.14 * (1 - a * 0.5))
		end)
		R.sound("Ding", V3(-4, 6, -3), 0.4, 0.7)
		R.wait(1.6)
		-- BEAT 2 : BOUM, les portes volent, contre-jour, marche au ralenti
		R.moveTo(doorL, doorCF(-1, rad(100)), 0.32, ES.Back, ED.Out)
		R.moveTo(doorR, doorCF(1, rad(100)), 0.32, ES.Back, ED.Out)
		R.tween(hallLight, 0.2, { Brightness = 3.5 })
		R.place(CF(0, 3, 14))
		R.sound("Crash", V3(0, 4, 12.5), 1)
		R.sound("BigImpact", V3(0, 4, 12.5), 0.6)
		R.fx.flash(C3(255, 240, 210), 0.02, 0.05, 0.3)
		R.fx.light(V3(0, 5, 13), GOLD, 30, 5, 0.6)
		R.fx.smoke(V3(0, 1, 13.5), 5, C3(120, 110, 100), 2)
		R.cam.whip(V3(0.9, 2.0, 5.5), V3(0, 4.8, 13))
		R.wait(0.35)
		R.slowmo(0.55)
		R.walk(FINAL, 1.35, "Strut")
		R.cam.track(1.35, function()
			local p = R.pos(R.root)
			return p + V3(0.7, -1.3, -6.2), p + V3(0, 1.3, 0), 56
		end)
		R.every(0.05, function()
			local z = R.pos(R.root).Z
			for _, l in ipairs(lamps) do
				if not l.on and z < l.z + 2.5 then
					l.on = true
					l.part.Color = C3(255, 220, 140)
					R.fx.light(R.pos(l.part), C3(255, 210, 130), 10, 2, 0.4)
					R.sound("Ding", l.part, 0.25, 1.8)
				end
			end
		end)
		R.wait(1.35)
		-- BEAT 3 : OBJECTION! (image figée, zoom brutal)
		R.slowmo(1)
		R.pose("Point")
		R.cam.pushIn(V3(0, 4.4, 0.6), 8, 4.2, 0.18, { height = 0.3, fov = 50 })
		R.wait(0.18)
		R.transform(true)
		R.freeze(0.32)
		R.fx.impact(1)
		R.fx.banner("OBJECTION!", { color = C3(255, 50, 60), t = 0.9, size = 0.22 })
		R.fx.speedLines(0.7, WHITE)
		R.sound("AnimeHit", V3(0, 4.5, 0), 1)
		R.cam.shake(0.6)
		R.wait(0.6)
		-- BEAT 4 : la mallette d'or claque sur le pupitre, colonne de lumière, la balance penche
		R.cam.orbit(V3(0, 3.8, -0.5), 8.5, 1.8, 0.55, -0.35, 1.6, 52, 56)
		R.anim(slamL)
		R.wait(0.4)
		R.freeze(0.1)
		R.fx.bigImpact(V3(-0.6, 3.4, -1.5), V3(0, -1, 0), 1.1, GOLD)
		R.fx.coins(V3(-0.6, 3.6, -1.5), 26)
		R.fx.pillar(V3(-0.6, 3.3, -1.5), 1.2, 14, GOLD, 1.0)
		R.sound("Clang", V3(-0.6, 3.4, -1.5), 1)
		R.cam.shake(0.5)
		R.over(0.5, function(a, e)
			tilt(0.32 * e)
		end, ES.Bounce, ED.Out)
		R.delay(0.45, function()
			R.sound("Ding", V3(-4, 6, -3), 0.8, 1.2)
		end)
		R.wait(1.0)
		-- BEAT 5 : éclat des lunettes, les portes se referment, CASE CLOSED
		R.pose(finalPose)
		R.cam.hero(0.6)
		R.wait(0.25)
		R.fx.twinkle(V3(0.3, 4.7, 0.0))
		R.sound("Ding", V3(0, 4.6, 0), 0.9, 2.2)
		R.moveTo(doorL, CF(-1.5, 4.5, 12.5), 0.3, ES.Quad, ED.In)
		R.moveTo(doorR, CF(1.5, 4.5, 12.5), 0.3, ES.Quad, ED.In)
		R.wait(0.3)
		R.sound("Thud", V3(0, 4, 12.5), 1)
		R.fx.banner("CASE CLOSED", { color = C3(220, 30, 40), t = 0.8, size = 0.17 })
		R.cam.shake(0.35)
		R.wait(0.4)
		R.title()
		R.wait(1.5)
	end,
}
------------------------------------------------------------------------ MASCOT
-- RARE · Hot Dog Hero — sortie du pain : le pain géant grésille sur le barbecue, le chapeau saute, il jaillit,
-- zigzags de ketchup et moutarde, danse du saucisson.
P.Mascot_Rare = {
	Caption = "Relish the moment. Ketchup is extra.",
	Location = "Company BBQ - Grill #1",
	Reveal = function(R, ctx)
		local BUN, CRUMB, KET, MUST = C3(230, 170, 90), C3(250, 220, 160), C3(220, 35, 35), C3(255, 215, 40)
		local FINAL = CF(0, 5.2, 0.3)
		R.stage("Studio", { color = C3(150, 210, 255), floor = C3(120, 200, 95) })
		R.mark(FINAL)
		-- barbecue géant
		R.box(V3(9.5, 1.2, 4.6), CF(0, 0.6, 0.3), C3(40, 40, 46), "Metal")
		for i = -4, 4 do
			R.box(V3(0.15, 0.12, 4.4), CF(i, 1.26, 0.3), C3(90, 90, 96), "Metal")
		end
		local glow = R.box(V3(9, 0.1, 4.2), CF(0, 1.12, 0.3), C3(255, 110, 30), "Neon")
		R.light(glow, C3(255, 140, 60), 12, 1)
		-- pain : moitié basse (où il se tient) et moitié haute (qui saute)
		local bottom = R.box(V3(8, 1.0, 3.4), CF(0, 1.7, 0.3), BUN)
		R.box(V3(1.0, 1.0, 1.0) * 3.4, CF(-4, 1.7, 0.3), BUN, nil, 0, "Ball")
		R.box(V3(1.0, 1.0, 1.0) * 3.4, CF(4, 1.7, 0.3), BUN, nil, 0, "Ball")
		local top = R.model({
			{ Size = V3(8, 1.6, 3.4), CFrame = CF(0, 0, 0), Color = BUN },
			{ Size = V3(7.6, 0.3, 3.0), CFrame = CF(0, -0.85, 0), Color = CRUMB },
			{ Size = V3(0.3, 0.12, 0.6), CFrame = CF(-2, 0.82, 0), Color = WHITE },
			{ Size = V3(0.3, 0.12, 0.6), CFrame = CF(0.5, 0.82, -0.6), Color = WHITE },
			{ Size = V3(0.3, 0.12, 0.6), CFrame = CF(2.4, 0.82, 0.4), Color = WHITE },
		}, CF(0, 3.2, 0.3))
		local finalPose = { RS = { p = 3.0, r = 0.35 }, LS = { p = 2.6, r = 0.9 }, RJ = { ln = -0.15, sd = 0.08 }, RH = { r = 0.25 }, LH = { p = 0.3, r = 0.25 } }
		local zig = {}
		local function zigzag(col, y0, z, n, delay)
			for k = 0, n do
				R.delay(delay + k * 0.035, function()
					local x = -4.2 + k * (8.4 / n)
					local y = y0 + ((k % 2 == 0) and 0.45 or -0.45)
					local nx = -4.2 + (k + 1) * (8.4 / n)
					local ny = y0 + (((k + 1) % 2 == 0) and 0.45 or -0.45)
					if k < n then
						local a, b = V3(x, y, z), V3(nx, ny, z)
						local seg = R.box(V3((b - a).Magnitude + 0.2, 0.32, 0.32), CFrame.lookAt((a + b) / 2, b) * ANG(0, PI / 2, 0), col, "SmoothPlastic", 0, "Cyl")
						zig[#zig + 1] = seg
					end
				end)
			end
		end
		R.onSkip(function(R)
			top:PivotTo(R.at(3.5, 0.9, 5) * ANG(0, 0, rad(150)))
			R.place(FINAL)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : vue plongeante, le pain grésille et tremble
		R.place(CF(0, 0.6, 0.3))
		R.cam.cut(V3(-3.5, 9.5, -7.5), V3(0, 2.4, 0.3), 52)
		R.every(0.12, function()
			R.fx.smoke(V3(R.rand(-4, 4), 1.4, R.rand(-1.5, 2)), 1, C3(235, 235, 235), 0.8)
		end)
		R.sound("Spray", V3(0, 2, 0), 0.5, 0.6)
		R.over(0.75, function(a)
			top:PivotTo(R.at(0, 3.2 + math.abs(math.sin(a * 30)) * 0.18, 0.3))
		end)
		R.wait(0.75)
		-- BEAT 2 : POP ! le chapeau du pain s'envole, il jaillit et atterrit debout dans le pain
		R.sound("Boing", V3(0, 3, 0), 1)
		R.fly(top, { V3(0, 3.2, 0.3), V3(1.8, 9, 3), V3(3.5, 0.9, 5) }, 0.7)
		R.spin(top, 0.42, 0.7, "Z")
		R.fx.puff(V3(0, 3, 0.3), 3)
		R.jump(R.rig, FINAL, 0.55, 3.5)
		R.cam.move(V3(-1.2, 4.2, -8.6), V3(0, 5.6, 0.3), 0.45, 60, ES.Quad, ED.Out)
		R.wait(0.55)
		R.fx.word("POP!", V3(-2, 8, 0), 0.9)
		-- zigzags de ketchup et de moutarde qui traversent l'écran devant lui
		R.sound("Splat", V3(0, 5, -2), 0.9)
		zigzag(KET, 6.2, -2.4, 10, 0)
		zigzag(MUST, 4.9, -2.2, 10, 0.12)
		R.wait(0.45)
		-- danse du saucisson puis pose triomphale
		R.anim("Dance")
		R.cam.move(V3(-2.4, 5.0, -9.4), V3(0, 5.6, 0.3), 1.0, 58)
		R.wait(0.95)
		for _, s in ipairs(zig) do
			R.show(s, false, 0.3)
		end
		R.pose(finalPose)
		R.fx.confetti(V3(0, 10, 0.3), 30, { KET, MUST, WHITE })
		R.wait(0.25)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Super Mascot — changement de costume : la cabine « SUPPLY CLOSET » tourbillonne, vêtements éjectés,
-- elle explose, il décolle et plane au-dessus de la ville, POW!
P.Mascot_Epic = {
	Caption = "Faster than a speeding T-shirt cannon. Weakness: stairs.",
	Location = "Office Rooftop - Somewhere A Coworker Needs Help",
	Reveal = function(R, ctx)
		local MRED, MBLUE, MUST = C3(230, 45, 45), C3(40, 90, 220), C3(255, 215, 40)
		local SKY = CF(0, 15, 0)
		R.stage("Night")
		R.mark(SKY)
		R.floor(V3(40, 1, 40), CF(0, -0.5, 4), C3(90, 92, 100), "Concrete")
		for _, p in ipairs({ { -9, 7 }, { 8, 9 }, { -12, -2 } }) do
			R.box(V3(3, 2.2, 3), CF(p[1], 1.1, p[2]), C3(170, 172, 180), "Metal")
		end
		local sign = R.box(V3(12, 2.4, 0.4), CF(0, 2.4, 16), C3(20, 20, 26))
		R.text(sign, "OFFICE", { Color = C3(255, 230, 120) })
		-- ville au loin
		for i = 1, 14 do
			local h = R.rand(10, 34)
			local bx = -50 + i * 7 + R.rand(-1, 1)
			R.box(V3(R.rand(5, 9), h, 6), CF(bx, h / 2 - 12, R.rand(60, 75)), C3(25, 30, 50))
			for k = 1, 3 do
				R.box(V3(0.8, 0.8, 0.1), CF(bx + R.rand(-2, 2), R.rand(-10, h - 14), 56.8), C3(255, 230, 140), "Neon")
			end
		end
		-- cabine « SUPPLY CLOSET »
		local GL = C3(170, 210, 230)
		local booth = R.model({
			{ Size = V3(4, 0.3, 4), CFrame = CF(0, 0.15, 0), Color = C3(60, 60, 70), Material = "Metal" },
			{ Size = V3(4.3, 0.5, 4.3), CFrame = CF(0, 7.6, 0), Color = MRED },
			{ Size = V3(3.4, 0.7, 0.2), CFrame = CF(0, 7.0, -2.0), Color = WHITE, Text = "SUPPLY CLOSET", TextColor = MRED },
			{ Size = V3(0.3, 7.3, 0.3), CFrame = CF(-1.85, 3.8, -1.85), Color = MRED },
			{ Size = V3(0.3, 7.3, 0.3), CFrame = CF(1.85, 3.8, -1.85), Color = MRED },
			{ Size = V3(0.3, 7.3, 0.3), CFrame = CF(-1.85, 3.8, 1.85), Color = MRED },
			{ Size = V3(0.3, 7.3, 0.3), CFrame = CF(1.85, 3.8, 1.85), Color = MRED },
			{ Size = V3(3.4, 6.2, 0.1), CFrame = CF(0, 3.5, -1.9), Color = GL, Material = "Glass", Transparency = 0.55 },
			{ Size = V3(3.4, 6.2, 0.1), CFrame = CF(0, 3.5, 1.9), Color = GL, Material = "Glass", Transparency = 0.55 },
			{ Size = V3(0.1, 6.2, 3.4), CFrame = CF(-1.9, 3.5, 0), Color = GL, Material = "Glass", Transparency = 0.55 },
			{ Size = V3(0.1, 6.2, 3.4), CFrame = CF(1.9, 3.5, 0), Color = GL, Material = "Glass", Transparency = 0.55 },
		}, CF(0, 0, 0))
		local flyPose = { RS = { p = 1.7, y = 0.1 }, LS = { p = -0.35, r = 0.25 }, RJ = { ln = 0.15 }, RH = { p = 0.15 }, LH = { p = -0.7 } }
		R.onSkip(function(R)
			if booth.Parent then
				booth:Destroy()
			end
			R.place(SKY)
			R.transform(true)
			R.pose(flyPose)
			R.cam.cut(V3(-4, 14, -9), V3(0, 15.5, 0), 55)
		end)

		-- BEAT 1 : la cabine tourbillonne, les vêtements de bureau sont éjectés
		R.place(CF(0, 3.3, 0))
		R.pose("Crouch")
		R.cam.cut(V3(-1.5, 3.2, -11), V3(0, 4.2, 0), 52)
		R.cam.move(V3(-1.2, 3.6, -8.5), V3(0, 4.4, 0), 1.5, 52)
		R.spin(booth, 5, 1.4)
		R.fx.swirl(V3(0, 3.5, 0), 3.2, 8, { MRED, MBLUE, MUST })
		R.sound("Whoosh", V3(0, 4, 0), 1, 0.8)
		local CLOTHES = { { V3(1.6, 1.8, 0.4), WHITE }, { V3(0.35, 1.3, 0.1), C3(40, 60, 140) }, { V3(1.0, 0.25, 0.4), C3(30, 30, 35) }, { V3(1.5, 1.8, 0.4), C3(70, 70, 80) } }
		for i, c in ipairs(CLOTHES) do
			R.delay(0.25 + i * 0.22, function()
				local piece = R.box(c[1], CF(0, 7.9, 0), c[2])
				local a = R.rand(0, 2 * PI)
				R.fly(piece, { V3(0, 7.9, 0), V3(math.cos(a) * 3, 12, math.sin(a) * 3), V3(math.cos(a) * 9, 0.4, math.sin(a) * 9 - 2) }, 1.0)
				R.spin(piece, 2, 1.0, "X")
				R.sound("Whoosh", V3(0, 8, 0), 0.5, 1.4)
			end)
		end
		R.wait(1.4)
		-- BEAT 2 : la cabine explose, il apparaît en costume, puis décolle
		R.fx.explosion(V3(0, 4, 0), 6, MUST)
		R.fx.shards(V3(0, 4, 0), 20, { GL, MRED, WHITE })
		R.destroy(booth, "puff")
		R.sound("Explosion", V3(0, 4, 0), 0.8)
		R.place(CF(0, 3, 0))
		R.pose("Hero")
		R.cam.shake(0.5)
		R.wait(0.5)
		R.pose({ RS = { p = 3.1, r = 0.05 }, LS = { p = 0.1, r = 0.15 }, RJ = { ln = -0.1 }, RH = { p = 0 }, LH = { p = -0.3 } })
		R.fx.puff(V3(0, 0.3, 0), 4)
		R.fx.ring(V3(0, 0.4, 0), V3(0, 1, 0), 6, WHITE)
		R.fx.speedLines(0.6, WHITE)
		R.sound("Dash", V3(0, 3, 0), 1)
		R.moveTo(R.rig, SKY, 0.75, ES.Quad, ED.Out)
		R.cam.track(0.8, function()
			local p = R.pos(R.root)
			return V3(-1.5, p.Y - 2.5, -10.5), p + V3(0, 0.5, 0), 60
		end)
		R.wait(0.8)
		-- BEAT 3 : en vol stationnaire au-dessus de la ville, poing en avant, POW!
		R.pose(flyPose)
		R.over(3, function(a)
			R.place(SKY * CF(0, math.sin(a * 9) * 0.25, 0))
		end)
		R.cam.orbit(V3(0, 15, 0), 9.5, 0.8, -0.9, 0.35, 2.2, 56, 50)
		R.wait(0.35)
		R.transform(true)
		R.fx.word("POW!", V3(-1.5, 18.2, -2), 1.2)
		R.fx.ring(V3(0, 15.5, -2.4), V3(0, 0, -1), 4, MUST)
		R.sound("PunchHeavy", V3(0, 15, -2), 0.8)
		R.cam.punch(-8)
		R.wait(1.2)
		R.title()
		R.wait(1.3)
	end,
}

-- LEGENDARY · Halftime Legend — sortie du tunnel : stade de nuit, ola du public, il traverse la banderole en papier,
-- tirs de t-shirts dans la foule (caméra sur un t-shirt), feux d'artifice au ralenti, #1 sur l'écran géant.
P.Mascot_Legendary = {
	Caption = "The crowd goes WILD. The office goes WILDER. Jumbotron included.",
	Location = "Office Dome - Halftime Show",
	Reveal = function(R, ctx)
		local JERSEY, FUR, MUST = C3(30, 40, 95), C3(220, 40, 40), C3(255, 215, 40)
		local FINAL = CF(0, 3, 1.5)
		R.stage("Night")
		R.mark(FINAL)
		-- terrain + lignes
		R.floor(V3(70, 0.2, 60), CF(0, -0.09, 8), C3(55, 145, 60), "Fabric")
		for z = -16, 18, 6 do
			R.box(V3(50, 0.03, 0.3), CF(0, 0.02, z), WHITE)
		end
		R.box(V3(0.2, 7, 7), CF(0, 0.03, 1.5) * ANG(0, 0, PI / 2), C3(220, 40, 40), "SmoothPlastic", 0.3, "Cyl")
		-- tribunes + public (5 rangées)
		local CROWD = { FUR, MUST, JERSEY, WHITE, C3(255, 140, 40) }
		local fans = {}
		for row = 0, 4 do
			local h = 1.6 * (row + 1)
			R.box(V3(64, h, 3), CF(0, h / 2, 21.5 + row * 3), C3(45, 45, 62), "Concrete")
			for i = 0, 17 do
				local x = -30 + i * 3.5 + R.rand(-0.6, 0.6)
				if math.abs(x) > 4 or row > 1 then
					local f = R.ball(1.2, V3(x, h + 0.9, 21.5 + row * 3), CROWD[R.randi(1, #CROWD)])
					fans[#fans + 1] = { part = f, x = x, y = h + 0.9, z = 21.5 + row * 3 }
				end
			end
		end
		local waveOn, hype = true, 0
		R.every(0.05, function(i)
			if not waveOn then
				return
			end
			for _, f in ipairs(fans) do
				local w = math.max(0, math.sin(i * 0.3 - f.x * 0.22)) * 1.1 + hype * math.abs(math.sin(i * 0.9 + f.x))
				f.part:PivotTo(R.at(f.x, f.y + w, f.z))
			end
		end)
		-- tunnel sous les tribunes (arche gonflable) + banderole en papier
		R.box(V3(6, 6.5, 0.3), CF(0, 3.25, 19.85), C3(5, 5, 8))
		R.box(V3(1.2, 7.5, 1.2), CF(-3.6, 3.75, 19.6), FUR, "SmoothPlastic", 0, "Block")
		R.box(V3(1.2, 7.5, 1.2), CF(3.6, 3.75, 19.6), FUR, "SmoothPlastic", 0, "Block")
		R.box(V3(8.4, 1.2, 1.2), CF(0, 7.5, 19.6), MUST)
		R.box(V3(0.25, 6, 0.25), CF(-4.4, 3, 12.5), C3(200, 200, 205), "Metal")
		R.box(V3(0.25, 6, 0.25), CF(4.4, 3, 12.5), C3(200, 200, 205), "Metal")
		local banL = R.box(V3(4.3, 4.2, 0.08), CF(-2.15, 3.6, 12.5), WHITE)
		local banR = R.box(V3(4.3, 4.2, 0.08), CF(2.15, 3.6, 12.5), WHITE)
		R.text(banL, "GO OF", { Color = FUR })
		R.text(banR, "FICE!", { Color = FUR })
		-- écran géant
		local jumbo = R.prop("Jumbotron", CF(0, 4, 38), { text = "MAKE SOME NOISE!!!" })
		local function jumboText(t)
			local l = jumbo and jumbo:FindFirstChildWhichIsA("TextLabel", true)
			if l then
				l.Text = t
			end
		end
		local spots = { R.spot(V3(-22, 26, -4), V3(-6, 0, 10), { color = C3(255, 245, 220) }), R.spot(V3(22, 26, -4), V3(6, 0, 10), { color = C3(255, 245, 220) }) }
		local finalPose = { RS = { p = 3.1, r = 0.15 }, LS = { p = 1.3, r = 0.6, y = 0.3 }, RJ = { ln = -0.18, sd = -0.06 }, RH = { r = 0.25 }, LH = { p = 0.35, r = 0.25 } }
		R.onSkip(function(R)
			banL:PivotTo(R.at(-12, 0.3, 9) * ANG(rad(-90), 0, 0))
			banR:PivotTo(R.at(12, 0.3, 9) * ANG(rad(-90), 0, 0))
			jumboText("#1 HALFTIME LEGEND")
			R.place(FINAL)
			R.transform(true)
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- BEAT 1 : grue sur le stade de nuit, ola, projecteurs qui balaient
		R.place(CF(0, 3, 23))
		R.cam.cut(V3(-15, 3.5, -16), V3(0, 7, 20), 62)
		R.cam.move(V3(-6, 12, -15), V3(0, 6, 16), 2.0, 58, ES.Sine, ED.InOut)
		spots[1].aim(V3(6, 0, 14), 2.0)
		spots[2].aim(V3(-6, 0, 14), 2.0)
		R.sound("Whistle", V3(0, 5, 20), 0.6)
		R.every(0.5, function(i)
			if i < 5 then
				jumboText((i % 2 == 0) and "MAKE SOME NOISE!!!" or "")
			end
		end)
		R.wait(2.0)
		-- BEAT 2 : fumée au tunnel, il sort en courant et déchire la banderole
		R.fx.smoke(V3(0, 2, 20), 16, C3(200, 200, 210), 3.5)
		R.sound("Rumble", V3(0, 3, 20), 0.7)
		spots[1].aim(V3(0, 0, 8), 0.4)
		spots[2].aim(V3(0, 0, 8), 0.4)
		R.walk(FINAL, 1.4, "Run")
		R.cam.track(1.4, function()
			local p = R.pos(R.root)
			return p + V3(-1.2, -0.6, -7.5), p + V3(0, 1.0, 2), 62
		end)
		local ripped = false
		R.every(0.03, function()
			if not ripped and R.pos(R.root).Z < 13.2 then
				ripped = true
				R.fly(banL, { V3(-2.15, 3.6, 12.5), V3(-6, 5.5, 11), V3(-12, 0.3, 9) }, 0.6)
				R.fly(banR, { V3(2.15, 3.6, 12.5), V3(6, 5.5, 11), V3(12, 0.3, 9) }, 0.6)
				R.spin(banL, 1, 0.6, "Z")
				R.spin(banR, -1, 0.6, "Z")
				R.fx.confetti(V3(0, 4, 12.5), 50, { WHITE, MUST, FUR })
				R.fx.word("RIIIP!", V3(-2.5, 7, 12), 1)
				R.sound("Crash", V3(0, 4, 12.5), 0.6, 1.3)
			end
		end)
		R.wait(1.4)
		-- BEAT 3 : canon à t-shirts vers la foule (caméra sur le premier t-shirt)
		R.transform(true)
		R.face(V3(0, 3, 30), 0.25)
		R.wait(0.25)
		local shirts = {}
		for k = 1, 3 do
			R.delay((k - 1) * 0.22, function()
				local s = R.box(V3(1.0, 0.55, 0.55), CF(1.35, 4.4, 1.0), CROWD[k], "Fabric", 0, "Cyl")
				shirts[k] = s
				local target = V3(-8 + k * 4 + R.rand(-1, 1), 8.5 + k, 25 + k * 1.5)
				R.fly(s, { V3(1.35, 4.4, 1.0), V3(target.X * 0.5, 15, (target.Z + 1) * 0.5), target }, 0.95)
				R.spin(s, 4, 0.95, "X")
				R.fx.puff(V3(1.35, 4.5, 2.2), 1.5)
				R.sound("Throw", V3(1.35, 4.4, 1), 0.8)
				R.delay(0.95, function()
					R.fx.confetti(target, 25)
					hype = 1
				end)
			end)
		end
		R.wait(0.05)
		R.cam.track(1.1, function()
			local s = shirts[1]
			if s and s.Parent then
				local p = R.pos(s)
				return p + V3(0.8, 1.6, -5), p + V3(0, 0, 3), 64
			end
			return V3(0, 5, -6), V3(0, 5, 10), 60
		end)
		R.wait(1.15)
		-- BEAT 4 : il se retourne, ralenti, feux d'artifice, doigt en mousse levé, #1 sur l'écran géant
		R.cam.whip(V3(-2.0, 1.6, -6.5), V3(0, 4.6, 1.5))
		R.face(V3(0, 3, -10), 0.2)
		R.wait(0.2)
		R.slowmo(0.35, 1.6)
		R.pose(finalPose)
		jumboText("#1 HALFTIME LEGEND")
		for k, x in ipairs({ -14, -5, 5, 14 }) do
			R.delay(k * 0.12, function()
				R.fx.fireworks(V3(x, 22 + k, 28), 1)
			end)
		end
		R.fx.confetti(V3(0, 14, 2), 90, { FUR, MUST, WHITE, JERSEY })
		R.fx.rays(MUST, V3(0, 4, 3))
		R.sound("LevelUp", V3(0, 4, 1.5), 0.9)
		R.cam.orbit(V3(0, 4.4, 1.5), 7.5, -0.8, -0.65, 0.35, 1.6, 64, 54)
		R.wait(0.9)
		R.slowmo(1)
		R.cam.hero(0.6)
		R.wait(0.3)
		R.title()
		R.wait(1.5)
		waveOn = false
	end,
}

return P
