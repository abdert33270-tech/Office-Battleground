--[[
	SkinReveals.Pack5 — chorégraphies de révélation : Temp, Consultant, OfficeCat, AIAssistant (agent reveal4).
	API : SkinRevealController v2 (voir son en-tête / REVEAL_API). Repère local : sol y = 0, héros sur CF(0, 3, 0)
	regardant -Z, caméra côté -Z, +X = main droite du héros.
	Structures : caméra de surveillance, imprimante -> origami, flaque d'ombre, la caméra « circle back »,
	pause dramatique de keynote, surf sur la courbe de croissance.
]]
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local rad, PI = math.rad, math.pi
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local WHITE, GOLD, DARK = C3(255, 255, 255), C3(255, 200, 60), C3(25, 25, 32)
local INDIGO, INDIGO2, INK, PAPER = C3(95, 80, 255), C3(150, 135, 255), C3(22, 22, 30), C3(245, 242, 232)
local ROYAL, ROYAL2, GREEN = C3(40, 100, 240), C3(120, 175, 255), C3(90, 230, 120)

local P = {}

local FACE_PX, FACE_NX, FACE_PZ = ANG(0, -PI / 2, 0), ANG(0, PI / 2, 0), ANG(0, PI, 0)
-- membre du rig (nil si absent)
local function limb(R, name)
	return R.rig and R.rig:FindFirstChild(name)
end

-- quelques bureaux d'open space (bureau + écran allumé + chaise)
local function officeRow(R, list, screenCol)
	for _, d in ipairs(list) do
		R.prop("Desk", CF(d[1], 0, d[2]) * ANG(0, d[3] or 0, 0))
		local m = R.box(V3(1.8, 1.1, 0.12), CF(d[1], 3.45, d[2] + 0.4) * ANG(0, d[3] or 0, 0), screenCol or C3(120, 170, 255), "Neon")
		m.Transparency = 0.1
	end
end

------------------------------------------------------------------------ THE TEMP
-- RARE · Night Shift Temp — caméra de surveillance : plan fixe, sauts d'images, il apparaît à chaque fois ailleurs.
P.Temp_Rare = {
	Caption = "Works 11 PM to 7 AM. Nobody has ever seen him arrive. Or leave.",
	Location = "Open Space - Floor 3 - CAM 04",
	Reveal = function(R, ctx)
		R.stage("Room", { color = C3(62, 70, 92), floor = C3(70, 72, 82), w = 28, d = 24, h = 12 })
		officeRow(R, { { -5, 6 }, { 0, 6 }, { 5, 6 } }, C3(90, 130, 220))
		R.prop("OfficeChair", CF(-5, 0, 4.4) * FACE_PZ)
		local cooler = R.cyl(3.2, 1.3, V3(5.5, 1.6, 2.2), C3(230, 230, 235))
		R.ball(1.3, V3(5.5, 3.8, 2.2), C3(140, 200, 255), "Glass", 0.3)
		local clock = R.box(V3(1.6, 1.6, 0.15), CF(0, 8.5, 11.8), WHITE)
		local clockLbl = R.text(clock, "3:12", { Color = DARK })
		R.light(V3(0, 9, 3), C3(150, 170, 255), 22, 0.6)
		local CCTV = { V3(9.5, 9.6, -9.5), V3(0, 2.2, 2.5), 74 }
		local finalPose = { RS = { p = 0.4, r = 0.3 }, LS = { p = 2.5, y = 0.3, r = 0.2 }, RJ = { ln = -0.05, sd = -0.06 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
		local function cctv(on)
			if on then
				R.fx.saturation(-0.85)
				R.fx.tint(C3(170, 255, 190))
				R.fx.contrast(0.25)
			else
				R.fx.saturation(0, 0.15)
				R.fx.tint(WHITE, 0.15)
				R.fx.contrast(0, 0.15)
			end
		end
		R.onSkip(function(R)
			cctv(false)
			R.alpha(1)
			R.place(CF(0, 3, 0))
			R.pose(finalPose)
			R.cam.hero()
		end)

		-- plan fixe de la caméra de surveillance : bureau vide
		cctv(true)
		R.alpha(0)
		R.cam.cut(CCTV[1], CCTV[2], CCTV[3])
		R.caption("● REC   CAM 04   03:12:07")
		R.sound("Electric", V3(0, 9, -9), 0.25, 0.6)
		R.wait(0.65)
		-- saut d'image : il est assis au fond
		local frames = {
			{ CF(-5, 3, 4.4) * FACE_PZ, "Typing", "03:12:31" },
			{ CF(5.2, 3, 0.6) * ANG(0, rad(-160), 0), "Drink", "03:13:02" },
			{ CF(7.2, 3, -6.8) * ANG(0, rad(-135), 0), nil, "03:13:40" },
		}
		for i, f in ipairs(frames) do
			R.fx.glitch()
			R.sound("UIClick", V3(0, 8, -8), 0.5, 0.6)
			R.alpha(1)
			R.place(f[1])
			if f[2] then
				R.pose(f[2])
			else
				-- il fixe la caméra et fait coucou
				R.face(CCTV[1], 0)
				R.anim("Wave")
			end
			clockLbl.Text = (i == 3) and "3:13" or "3:12"
			R.caption("● REC   CAM 04   " .. f[3])
			R.wait(i == 3 and 0.75 or 0.5)
		end
		-- coupure : retour en couleur, plan propre, il est sur sa marque
		R.fx.glitch()
		cctv(false)
		R.caption("")
		R.place(CF(0, 3, 0))
		R.pose(finalPose)
		R.cam.cut(V3(-2.6, 3.6, -8.6), V3(0, 4.4, 0), 56)
		R.cam.move(V3(-2.2, 3.8, -7.6), V3(0, 4.5, 0), 1.2, 54)
		R.sound("Ding", V3(0, 4, 0), 0.6, 0.8)
		R.fx.word("...hi.", V3(-1.8, 6.4, -0.8), 0.6)
		R.wait(0.45)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Origami Shinobi — l'imprimante crache une feuille qui se plie en grue, la nuée de grues tourbillonne,
-- converge et explose en papier : il apparaît en posture de ninja.
P.Temp_Epic = {
	Caption = "Folded himself out of a single A4 sheet. Recyclable. Lethal.",
	Location = "Print Room - Tray 2 Jammed",
	Reveal = function(R, ctx)
		R.stage("Room", { color = C3(225, 222, 235), floor = C3(185, 182, 200), w = 30, d = 26, h = 13 })
		-- imprimante géante (côté écran droit = -X)
		local PRN = C3(225, 225, 230)
		R.box(V3(4.4, 3.2, 3.2), CF(-5, 1.6, 2), PRN)
		R.box(V3(4.0, 0.6, 2.8), CF(-5, 3.5, 2), C3(200, 200, 208))
		R.box(V3(3.2, 0.12, 1.6), CF(-5, 2.3, 0.2), C3(180, 180, 190))
		local led = R.box(V3(0.3, 0.3, 0.1), CF(-3.4, 3.0, 0.38), C3(60, 255, 120), "Neon")
		local panel = R.box(V3(1.2, 0.6, 0.1), CF(-4.4, 3.0, 0.38), C3(30, 40, 60), "Neon")
		R.text(panel, "PRINTING", { Color = C3(120, 255, 160) })
		-- rideaux de papier en fond (bandes verticales)
		for i = -5, 5 do
			R.box(V3(1.6, 10, 0.1), CF(i * 1.9, 5, 10) * ANG(0, rad((i % 2 == 0) and 12 or -12), 0), (i % 2 == 0) and PAPER or C3(230, 228, 245))
		end
		local sheet = R.box(V3(2.0, 0.04, 2.8), CF(-5, 2.42, 1.4), PAPER)
		local cranes = {}
		local ninja = { RS = { p = 1.5, r = -0.55, y = 0.6 }, LS = { p = 1.5, r = -0.55, y = 0.6 }, RJ = { ln = 0.12 }, RH = { p = 0.55, r = 0.25 }, LH = { p = -0.35, r = 0.25 } }
		local crouch = { RS = { p = 1.6, y = 0.2 }, LS = { p = -0.5, r = 0.4 }, RJ = { ln = 0.55 }, RH = { p = 1.4, r = 0.2 }, LH = { p = -0.6, r = 0.2 } }
		R.onSkip(function(R)
			sheet.Transparency = 1
			for _, c in ipairs(cranes) do
				c:Destroy()
			end
			R.alpha(1)
			R.place(CF(0, 3, 0))
			R.pose(ninja)
			R.cam.hero()
		end)

		-- BEAT 1 : gros plan sur l'imprimante qui crache une feuille, la feuille s'envole
		R.alpha(0)
		R.cam.cut(V3(-2.2, 3.4, -4.0), V3(-5, 2.6, 1.2), 46)
		R.every(0.15, function(i)
			led.Color = (i % 2 == 0) and C3(60, 255, 120) or C3(20, 80, 40)
		end)
		R.sound("Typing", V3(-5, 2, 1), 0.6)
		R.moveTo(sheet, CF(-5, 2.42, -0.4), 0.55, ES.Linear)
		R.wait(0.6)
		R.sound("Whoosh", V3(-5, 3, 0), 0.8, 1.3)
		R.fly(sheet, { V3(-5, 2.42, -0.4), V3(-4, 6, -1), V3(-1.5, 7.5, 0), V3(0, 6.5, 0) }, 0.9, { face = true })
		R.cam.move(V3(-2.0, 5.0, -7.5), V3(-1, 6.5, 0), 0.9, 52, ES.Sine, ED.Out)
		R.wait(0.9)
		-- BEAT 2 : la feuille se plie (rotation + rétrécissement) puis devient une grue ; la nuée tourbillonne
		R.over(0.45, function(a, e)
			sheet.Size = V3(2.0 - 1.4 * e, 0.04, 2.8 - 2.2 * e)
			sheet.CFrame = R.at(0, 6.5, 0) * ANG(e * PI, e * PI * 2, e * PI * 0.5)
		end)
		R.wait(0.45)
		sheet.Transparency = 1
		R.fx.puff(V3(0, 6.5, 0), 1.5)
		R.sound("Pickup", V3(0, 6.5, 0), 0.8, 1.2)
		for k = 1, 6 do
			local c = R.mesh("Temp_Epic_Crane", CF(0, 6.5, 0), 1.3) or R.box(V3(1, 0.5, 1), CF(0, 6.5, 0), PAPER, nil, 0, "Wedge")
			cranes[k] = c
		end
		R.fx.word("FOLD!", V3(-1.5, 8.5, -0.5), 0.8)
		R.cam.orbit(V3(0, 4.5, 0), 10, 2.5, -0.4, 1.4, 1.5, 58, 52)
		R.over(1.5, function(a, e)
			for k, c in ipairs(cranes) do
				local ang = k / #cranes * 2 * PI + a * 2 * PI * 1.3
				local r = 1 + 3.2 * math.sin(math.min(1, a * 1.6) * PI * 0.5)
				local y = 6.5 - a * 2.5 + math.sin(a * 8 + k) * 0.4
				local p = V3(math.cos(ang) * r, y, math.sin(ang) * r)
				local tangent = V3(-math.sin(ang), 0, math.cos(ang))
				c.CFrame = CFrame.lookAt(R.wp(p.X, p.Y, p.Z), R.wp(p.X + tangent.X, p.Y, p.Z + tangent.Z))
			end
		end)
		R.fx.swirl(V3(0, 3, 0), 3.5, 6, { PAPER, INDIGO2, WHITE })
		R.wait(1.5)
		-- BEAT 3 : les grues plongent sur la marque, explosion de papier, il apparaît accroupi puis en garde
		for _, c in ipairs(cranes) do
			R.moveTo(c, CF(0, 3.5, 0), 0.22, ES.Quad, ED.In)
		end
		R.wait(0.22)
		for _, c in ipairs(cranes) do
			c:Destroy()
		end
		cranes = {}
		R.alpha(1)
		R.place(CF(0, 2.2, 0))
		R.pose(crouch)
		R.fx.confetti(V3(0, 3.5, 0), 70, { PAPER, WHITE, INDIGO, INDIGO2 }, 5, 12)
		R.fx.shockwave(V3(0, 0.2, 0), 8, INDIGO2)
		R.sound("Explosion", V3(0, 3, 0), 0.5, 1.4)
		R.cam.lowAngle(V3(0, 3.5, 0), 7, 0.25)
		R.freeze(0.12)
		R.wait(0.45)
		R.moveTo(R.rig, CF(0, 3, 0), 0.2, ES.Quad, ED.Out)
		R.pose(ninja)
		R.sound("Whoosh", V3(0, 4, 0), 0.7, 1.6)
		R.fx.ring(V3(0, 4.2, -1.4), V3(0, 0, -1), 2.5, INDIGO2)
		R.cam.move(V3(-2.6, 3.8, -8.4), V3(0, 4.3, 0), 0.7, 54, ES.Quad, ED.Out)
		R.wait(0.5)
		R.title()
		R.wait(1.2)
	end,
}
-- LEGENDARY · Shadow Contractor — flaque d'ombre : elle glisse dans l'open space en éteignant les néons, il en émerge,
-- shuriken géant au ralenti qui tranche les contrats, retour en boomerang, dernier néon en contre-plongée.
P.Temp_Legendary = {
	Caption = "Hired off the books. Paid in shadows. Leaves no paper trail. Ever.",
	Location = "Open Space - Floor 13 (Unlisted)",
	Reveal = function(R, ctx)
		R.stage("Room", { color = C3(205, 205, 215), floor = C3(165, 165, 178), w = 36, d = 32, h = 13 })
		-- néons du plafond (allumés), bureaux
		local ceiling = {}
		for _, z in ipairs({ -8, -2, 4, 10 }) do
			for _, x in ipairs({ -10, -3.5, 3.5, 10 }) do
				local n = R.box(V3(4, 0.25, 1), CF(x, 12.7, z), C3(250, 250, 255), "Neon")
				ceiling[#ceiling + 1] = { part = n, x = x, z = z, on = true }
			end
		end
		local roomLight = R.light(V3(0, 11, 0), C3(240, 240, 255), 40, 2.5)
		officeRow(R, { { -9, 5 }, { -4, 9 }, { 9, 6 }, { 6, -6, PI } }, C3(180, 200, 255))
		-- pile de contrats sur un bureau (sera tranchée)
		local STACK = V3(-6.5, 3.6, -3)
		R.box(V3(3.5, 3.2, 2), CF(-6.5, 1.6, -3), C3(120, 90, 70), "Wood")
		local stack = {}
		for k = 0, 5 do
			stack[#stack + 1] = R.box(V3(1.4, 0.18, 1.9), CF(STACK.X, 3.3 + k * 0.2, STACK.Z) * ANG(0, rad(R.rand(-8, 8)), 0), PAPER)
		end
		-- la flaque d'ombre
		local pool = R.box(V3(0.06, 2.6, 2.6), CF(-14, 0.04, 8) * ANG(0, 0, PI / 2), INK, "SmoothPlastic", 0.05, "Cyl")
		local path = { V3(-14, 0.04, 8), V3(-7, 0.04, 2), V3(-1, 0.04, 7), V3(4, 0.04, 1), V3(0, 0.04, 0) }
		local shuriken = R.mesh("Temp_Legendary_Shuriken", CF(0, -10, 0), 2.6)
		local stance = { RS = { p = 1.3, r = 0.65, y = 0.5 }, LS = { p = 0.4, r = 0.75 }, RJ = { ln = 0.25, tw = 0.2 }, RH = { p = 0.6, r = 0.35 }, LH = { p = -0.45, r = 0.35 } }
		local throw = {
			{ t = 0, RS = { p = 1.2, r = -0.9, y = 0.6 }, RJ = { tw = 0.6, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
			{ t = 0.25, RS = { p = 1.4, r = -1.1, y = 0.7 }, RJ = { tw = 0.8, ln = 0.15 }, RH = { p = 0.35 }, LH = { p = -0.25 } },
			{ t = 0.38, RS = { p = 1.6, r = 1.2 }, RJ = { tw = -0.6, ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
			{ t = 1.2, RS = { p = 1.5, r = 1.1 }, RJ = { tw = -0.5, ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		}
		local function allDark()
			for _, c in ipairs(ceiling) do
				c.on = false
				c.part.Color = C3(60, 60, 70)
			end
			roomLight.Brightness = 0
		end
		local topSpot = R.spot(V3(0, 12.5, 0), V3(0, 0, 0), { color = INDIGO2, width = 3.8, on = false })
		R.onSkip(function(R)
			allDark()
			R.fx.dark(0.7)
			pool.Transparency = 0.05
			pool:PivotTo(R.at(0, 0.04, 0) * ANG(0, 0, PI / 2))
			if shuriken then
				shuriken.Transparency = 1
			end
			topSpot.on(0)
			R.place(CF(0, 3, 0))
			R.pose(stance)
			R.cam.hero()
		end)

		-- BEAT 1 : open space allumé, la flaque d'ombre glisse et éteint les néons sur son passage
		R.place(CF(0, -4, 0))
		R.cam.cut(V3(-12, 10, -13), V3(-6, 0, 4), 58)
		R.cam.move(V3(-4, 9, -13), V3(0, 0, 3), 2.0, 56, ES.Sine, ED.InOut)
		R.fly(pool, path, 2.0)
		R.every(0.05, function()
			local p = R.pos(pool)
			for _, c in ipairs(ceiling) do
				if c.on and (V3(c.x, 0, c.z) - V3(p.X, 0, p.Z)).Magnitude < 5 then
					c.on = false
					c.part.Color = C3(60, 60, 70)
					R.sound("Thud", V3(c.x, 12, c.z), 0.25, 1.6)
				end
			end
		end)
		R.fx.dark(0.7, 2.0)
		R.tween(roomLight, 2.0, { Brightness = 0.4 })
		R.wait(2.0)
		-- BEAT 2 : la flaque s'élargit, des volutes montent, il émerge lentement de l'ombre
		allDark()
		R.tween(pool, 0.4, { Size = V3(0.06, 5.5, 5.5) })
		R.sound("Rumble", V3(0, 0, 0), 0.7)
		for k = 1, 8 do
			R.delay(k * 0.08, function()
				local a = k / 8 * 2 * PI
				local t = R.box(V3(0.35, 0.35, 0.35), CF(math.cos(a) * 2, 0.3, math.sin(a) * 2), (k % 2 == 0) and INDIGO or INK, (k % 2 == 0) and "Neon" or "SmoothPlastic")
				R.moveTo(t, CF(math.cos(a) * 1.2, 7, math.sin(a) * 1.2) * ANG(a, a, 0), 0.9, ES.Quad, ED.Out)
				R.show(t, false, 0.9)
			end)
		end
		R.fx.smoke(V3(0, 0.5, 0), 12, INDIGO, 2.5)
		R.pose("Crouch")
		R.moveTo(R.rig, CF(0, 3, 0), 1.3, ES.Quad, ED.Out)
		R.cam.crane(V3(0, 3.5, 0), 0.5, 4, 6.5, 1.4, { yaw = 0.35, fov = 52 })
		R.wait(1.0)
		R.pose(stance)
		R.tween(pool, 0.6, { Size = V3(0.06, 3, 3) })
		R.wait(0.4)
		-- BEAT 3 : le shuriken géant part au ralenti et tranche la pile de contrats
		R.anim(throw)
		R.wait(0.36)
		local from = V3(0.8, 4.4, -1.2)
		local mid = V3(-3.5, 4.2, -4.5)
		if shuriken then
			shuriken.CFrame = R.at(from.X, from.Y, from.Z) * ANG(PI / 2, 0, 0)
			R.fly(shuriken, { from, mid, STACK + V3(0, 0.5, 0), V3(-11, 4, -1) }, 0.9)
			R.spin(shuriken, 6, 0.9, "Z")
			R.cam.track(0.9, function()
				local p = R.pos(shuriken)
				return p + V3(2.0, 1.4, -3.6), p, 60
			end)
		end
		R.sound("Whoosh", from, 1, 0.7)
		R.slowmo(0.3)
		R.wait(0.55)
		R.freeze(0.2)
		R.fx.impact(0.8)
		R.fx.word("SLICE!", STACK + V3(0, 2.5, -1), 1)
		R.sound("Clang", STACK, 0.9, 1.4)
		for k, s in ipairs(stack) do
			local side = (k % 2 == 0) and 1 or -1
			R.fly(s, { R.pos(s), R.pos(s) + V3(side * 1.2, 2 + k * 0.3, -1), R.pos(s) + V3(side * 3, -2.5, -2) }, 0.9)
			R.spin(s, side * 2, 0.9, "X")
		end
		R.fx.confetti(STACK, 30, { PAPER, WHITE }, 3, 6)
		R.wait(0.35)
		R.slowmo(1)
		-- BEAT 4 : retour en boomerang, il le rattrape
		R.cam.whip(V3(-2.8, 4.0, -7.5), V3(0, 4.5, 0))
		if shuriken then
			R.fly(shuriken, { V3(-11, 4, -1), V3(-6, 6, 4), V3(0.8, 4.6, -0.8) }, 0.6)
			R.spin(shuriken, 4, 0.6, "Z")
		end
		R.wait(0.45)
		R.anim("Catch")
		R.wait(0.15)
		if shuriken then
			shuriken.Transparency = 1
		end
		R.fx.sparks(V3(0.8, 4.6, -0.8), 12, INDIGO2)
		R.sound("MetalHit", V3(0.8, 4.6, -0.8), 0.8)
		R.cam.shake(0.3)
		R.wait(0.4)
		-- BEAT 5 : un seul néon se rallume sur lui, contre-plongée, NO TRACE
		topSpot.on(0.1)
		R.sound("UIClick", V3(0, 12, 0), 0.8)
		R.pose(stance)
		R.fx.smoke(V3(0, 0.3, 0), 10, INK, 3)
		R.cam.lowAngle(V3(0, 4, 0), 7.5, 0.6)
		R.fx.banner("NO TRACE", { color = INDIGO2, t = 0.9, size = 0.14 })
		R.wait(0.5)
		R.title()
		R.wait(1.4)
	end,
}

------------------------------------------------------------------------ THE CONSULTANT
-- RARE · Casual Friday — « circle back » : il dessine un cercle au tableau blanc, et la caméra fait littéralement le tour.
P.Consultant_Rare = {
	Caption = "Fleece vest. Cold brew. Has never once said a sentence without 'circle back'.",
	Location = "Huddle Room B - Friday 4:55 PM",
	Reveal = function(R, ctx)
		R.stage("Room", { color = C3(232, 234, 240), floor = C3(150, 160, 178), w = 26, d = 24, h = 12 })
		-- tableau blanc
		R.box(V3(10.4, 5.4, 0.3), CF(0, 5.2, 4.2), C3(170, 175, 185), "Metal")
		local board = R.box(V3(10, 5, 0.2), CF(0, 5.2, 4.0), WHITE)
		local note = R.box(V3(3.2, 0.8, 0.05), CF(-3, 6.8, 3.88), WHITE)
		R.text(note, "Q3 SYNERGY", { Color = ROYAL })
		local note2 = R.box(V3(2.4, 0.7, 0.05), CF(3.3, 3.4, 3.88), WHITE)
		R.text(note2, "KPIs???", { Color = C3(230, 60, 60) })
		local headline = R.box(V3(6, 0.9, 0.05), CF(0.8, 3.0, 3.88), WHITE)
		local headLbl = R.text(headline, "", { Color = ROYAL })
		R.prop("Plant", CF(-8, 0, 3))
		R.box(V3(6, 0.25, 3), CF(0, 2.6, -4.5), C3(200, 225, 240), "Glass", 0.35)
		-- cercle tracé au feutre (segments qui apparaissent un à un)
		local CC, RAD = V3(0.8, 5.4, 3.85), 1.4
		local segs = {}
		for k = 0, 17 do
			local a0, a1 = k / 18 * 2 * PI, (k + 1) / 18 * 2 * PI
			local p0 = CC + V3(math.cos(a0) * RAD, math.sin(a0) * RAD, 0)
			local p1 = CC + V3(math.cos(a1) * RAD, math.sin(a1) * RAD, 0)
			local s = R.box(V3(0.14, (p1 - p0).Magnitude + 0.05, 0.04), CFrame.lookAt((p0 + p1) / 2, (p0 + p1) / 2 + V3(0, 0, -1), (p1 - p0).Unit), ROYAL)
			s.Transparency = 1
			segs[#segs + 1] = s
		end
		local guns = { RS = { p = 1.55, y = 0.1, r = 0.15 }, LS = { p = 1.45, y = 0.1, r = -0.15 }, RJ = { tw = 0.15, ln = -0.05 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
		R.onSkip(function(R)
			for _, s in ipairs(segs) do
				s.Transparency = 0
			end
			headLbl.Text = "LET'S CIRCLE BACK"
			R.place(CF(0, 3, 0))
			R.pose(guns)
			R.cam.hero()
		end)

		-- BEAT 1 : il entre en sirotant son cold brew, se tourne vers le tableau et trace un cercle
		R.place(CF(6.5, 3, 0) * FACE_NX)
		R.cam.cut(V3(-3.5, 4.2, -8), V3(1.5, 4.4, 1.5), 56)
		R.walk(CF(0, 3, 0) * FACE_NX, 0.8, "Strut")
		R.wait(0.8)
		R.face(V3(0, 3, 10), 0.2)
		R.anim({
			{ t = 0 },
			{ t = 0.15, LS = { p = 2.4, r = 0.2 } },
			{ t = 0.3, LS = { p = 2.7, r = 0.45 } },
			{ t = 0.45, LS = { p = 2.4, r = 0.65 } },
			{ t = 0.6, LS = { p = 2.1, r = 0.45 } },
			{ t = 0.75, LS = { p = 2.4, r = 0.2 } },
			{ t = 0.9 },
		})
		for k, s in ipairs(segs) do
			R.delay(k * 0.045, function()
				s.Transparency = 0
			end)
		end
		R.sound("Squeak", CC, 0.6, 1.4)
		R.wait(0.85)
		headLbl.Text = "LET'S CIRCLE BACK"
		R.sound("Ding", CC, 0.6, 1.2)
		-- BEAT 2 : la caméra fait littéralement le tour ; il se retourne, gorgée de cold brew, doigts pistolets
		R.cam.orbit(V3(0, 4.4, 0), 7.5, 1.0, PI * 0.85, PI * 0.85 - 2 * PI, 1.5, 56, 52)
		R.wait(0.5)
		R.face(V3(0, 3, -10), 0.3)
		R.pose("Drink")
		R.wait(0.6)
		R.pose(guns)
		R.sound("UIClick", V3(0, 4, -1), 0.8, 1.6)
		R.fx.word("SYNERGY!", V3(-1.8, 6.6, -0.8), 0.8)
		R.wait(0.4)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Keynote Visionary — pause dramatique : projecteur, silence de 9 secondes (compté en accéléré),
-- un clic, « REIMAGINED. », la salle se lève.
P.Consultant_Epic = {
	Caption = "Walks on stage, pauses for 9 seconds, says 'reimagined'. Standing ovation.",
	Location = "Keynote Hall - Main Event",
	Reveal = function(R, ctx)
		R.stage("Void")
		-- scène blanche minimaliste + écran géant
		R.box(V3(26, 0.6, 10), CF(0, 0.3, 2), C3(30, 30, 34))
		local screen = R.box(V3(24, 10, 0.3), CF(0, 7.5, 9), C3(8, 8, 10))
		local scrLbl = R.text(screen, "", { Color = WHITE })
		-- public de dos (sièges + têtes) au premier plan
		local crowd = {}
		for row = 0, 2 do
			for i = 0, 9 do
				local x = -11 + i * 2.4 + (row % 2) * 1.2
				local z = -8 - row * 2.2
				R.box(V3(2.0, 1.6, 0.4), CF(x, 0.8, z - 0.5), C3(70, 20, 30))
				local h = R.ball(1.1, V3(x, 2.3 + row * 0.25, z), C3(14, 14, 18))
				local b = R.box(V3(1.5, 1.4, 0.7), CF(x, 1.3 + row * 0.25, z), C3(14, 14, 18))
				crowd[#crowd + 1] = { h = h, b = b, x = x, z = z, y = row * 0.25 }
			end
		end
		local spot = R.spot(V3(0, 18, -6), V3(0, 0.6, 0), { color = C3(255, 250, 235), width = 4, on = false })
		local FINAL = CF(0, 3.6, 0)
		R.mark(FINAL)
		local still = { RS = { p = 0.15, r = 0.05 }, LS = { p = 0.15, r = 0.05 }, RJ = {} }
		local click = { RS = { p = 1.35, y = 0.2 }, LS = { p = 0.2 }, RJ = { ln = -0.04 } }
		local final = { RS = { p = 2.9, r = -0.1, y = 0.2 }, LS = { p = 0.25, r = 0.2 }, RJ = { ln = -0.1, tw = 0.1 }, RH = { r = 0.08 }, LH = { r = 0.08 } }
		local function stand(on)
			for _, c in ipairs(crowd) do
				local up = on and 1.3 or 0
				c.h:PivotTo(R.at(c.x, 2.3 + c.y + up, c.z))
				c.b:PivotTo(R.at(c.x, 1.3 + c.y + up, c.z))
			end
		end
		R.onSkip(function(R)
			spot.on(0)
			screen.Material = Enum.Material.Neon
			screen.Color = C3(20, 30, 60)
			scrLbl.Text = "REIMAGINED."
			stand(true)
			R.place(FINAL)
			R.transform(true)
			R.pose(final)
			R.cam.hero()
		end)

		-- BEAT 1 : noir total, le projecteur claque sur lui, plan large depuis le fond de la salle
		R.place(FINAL)
		R.pose(still)
		R.cam.cut(V3(0, 4.5, -17), V3(0, 4.5, 2), 50)
		R.wait(0.4)
		spot.on(0.05)
		R.sound("Thud", V3(0, 10, -5), 0.9, 0.7)
		R.wait(0.5)
		-- BEAT 2 : LA pause (9 secondes en accéléré sur l'écran), lente poussée
		R.cam.move(V3(0.6, 4.6, -7.5), V3(0, 4.6, 0), 1.9, 40, ES.Sine, ED.InOut)
		for n = 9, 1, -1 do
			scrLbl.Text = n .. ""
			scrLbl.TextColor3 = C3(90, 90, 100)
			R.sound("UIClick", V3(0, 7, 9), 0.15, 0.5)
			R.wait(0.17)
		end
		-- clic de la télécommande : REIMAGINED.
		R.pose(click)
		R.wait(0.15)
		R.sound("UIClick", V3(0.6, 4, -1), 1, 1.2)
		R.transform(true)
		screen.Material = Enum.Material.Neon
		screen.Color = C3(20, 30, 60)
		scrLbl.Text = "REIMAGINED."
		scrLbl.TextColor3 = WHITE
		R.fx.flash(C3(220, 235, 255), 0.03, 0.04, 0.35)
		R.cam.punch(-6)
		R.wait(0.5)
		-- BEAT 3 : ovation debout, flashs d'appareils photo, il salue humblement puis lève l'index
		R.cam.cut(V3(-6, 3.4, -15), V3(0, 4.5, 2), 54)
		for i, c in ipairs(crowd) do
			R.delay(R.rand(0, 0.35), function()
				R.moveTo(c.h, CF(c.x, 2.3 + c.y + 1.3, c.z), 0.25, ES.Back, ED.Out)
				R.moveTo(c.b, CF(c.x, 1.3 + c.y + 1.3, c.z), 0.25, ES.Back, ED.Out)
			end)
		end
		R.every(0.07, function()
			local c = crowd[R.randi(1, #crowd)]
			R.fx.light(V3(c.x, 4, c.z - 0.5), WHITE, 6, 5, 0.08)
		end)
		R.sound("Combo", V3(0, 3, -10), 0.7)
		R.pose("Bow")
		R.wait(0.7)
		R.cam.move(V3(-2.2, 3.8, -7.8), V3(0, 4.8, 0), 0.7, 52, ES.Quad, ED.Out)
		R.pose(final)
		R.fx.banner("ONE MORE THING...", { color = ROYAL2, t = 0.9, size = 0.1, y = 0.2 })
		R.wait(0.5)
		R.title()
		R.wait(1.2)
	end,
}
-- LEGENDARY · Synergy Overlord — surf sur la courbe : une flèche de croissance se dessine, il la surfe jusqu'au sommet,
-- saut au ralenti sur le pilier d'or, compteur d'heures facturées qui explose, scan au laser du monocle.
P.Consultant_Legendary = {
	Caption = "Billed 3,000 hours this week. There are only 168. Nobody dares to ask.",
	Location = "Q4 Earnings Call - Off The Charts",
	Reveal = function(R, ctx)
		R.stage("Void")
		local LASER = C3(255, 40, 50)
		-- sol en grille néon
		for i = -6, 6 do
			R.box(V3(0.08, 0.02, 60), CF(i * 5, 0.02, 0), C3(30, 60, 140), "Neon")
			R.box(V3(60, 0.02, 0.08), CF(0, 0.02, i * 5), C3(30, 60, 140), "Neon")
		end
		-- pilier d'or au sommet de la courbe
		local TOP = 10
		R.cyl(TOP, 3.2, V3(0, TOP / 2, 0), GOLD, "Foil")
		R.cyl(0.3, 3.6, V3(0, TOP + 0.15, 0), C3(255, 230, 140), "Neon")
		local FINAL = CF(0, TOP + 3.3, 0)
		R.mark(FINAL)
		-- la courbe (polyligne) : points où il surfe
		local pts = { V3(-26, 1.2, 5), V3(-19, 4.5, 4.5), V3(-15, 3, 4), V3(-9, 7.5, 3), V3(-6, 6.2, 2.2), V3(-1.5, 10.6, 0.6) }
		local Q = { "Q1", "Q2", "Q3", "Q4" }
		for k = 1, 4 do
			R.billboard(Q[k], V3(-24 + k * 6, 0.8, -1.5), { size = 2.2, Color = ROYAL2 })
		end
		local counter = R.billboard("HOURS BILLED: 0", V3(5.5, TOP + 6, 2), { size = 3.2, Color = GOLD, StrokeColor = DARK })
		local segs = {}
		local function seg(a, b)
			local s = R.box(V3(0.6, 0.6, (b - a).Magnitude + 0.3), CFrame.lookAt((a + b) / 2, b), GREEN, "Neon")
			segs[#segs + 1] = s
			return s
		end
		local bars = {}
		for k = 1, 7 do
			local h = 2 + k * 1.3
			local x = -24 + k * 3.2
			local b = R.box(V3(1.8, h, 1.8), CF(x, -h / 2 - 0.2, 9), ({ C3(255, 150, 40), C3(40, 200, 170), C3(255, 215, 50), C3(255, 90, 140) })[(k % 4) + 1], "Neon")
			bars[#bars + 1] = { part = b, x = x, h = h }
		end
		local surf = { RS = { p = 1.4, r = 1.0 }, LS = { p = 1.4, r = 1.0 }, RJ = { tw = 0.9, ln = 0.15 }, RH = { p = 0.35, r = 0.3 }, LH = { p = -0.35, r = 0.3 } }
		local final = { RS = { p = 0.6, r = 0.45 }, LS = { p = 2.9, r = 0.2 }, RJ = { ln = -0.12, sd = 0.05 }, RH = { r = 0.2 }, LH = { r = 0.2 } }
		local function lenOf()
			local L = 0
			for i = 1, #pts - 1 do
				L += (pts[i + 1] - pts[i]).Magnitude
			end
			return L
		end
		local TOTAL = lenOf()
		local function at(d)
			for i = 1, #pts - 1 do
				local l = (pts[i + 1] - pts[i]).Magnitude
				if d <= l or i == #pts - 1 then
					local a = math.clamp(d / l, 0, 1)
					return pts[i]:Lerp(pts[i + 1], a), (pts[i + 1] - pts[i]).Unit, i
				end
				d -= l
			end
			return pts[#pts], V3(1, 0, 0), #pts - 1
		end
		R.onSkip(function(R)
			for i = 1, #pts - 1 do
				if not segs[i] then
					seg(pts[i], pts[i + 1])
				end
			end
			for _, b in ipairs(bars) do
				b.part:PivotTo(R.at(b.x, b.h / 2, 9))
			end
			counter.Label.Text = "HOURS BILLED: 3,000"
			R.place(FINAL)
			R.pose(final)
			R.cam.hero()
		end)

		-- BEAT 1 : grille sombre, il apparaît au départ de la courbe
		R.place(CFrame.lookAt(pts[1] + V3(0, 3.2, 0), pts[2] + V3(0, 3.2, 0)))
		R.pose(surf)
		R.cam.cut(V3(-23, 4, -8), V3(-25, 3.5, 4), 56)
		R.fx.flash(GREEN, 0.02, 0.03, 0.25)
		R.fx.sparks(pts[1] + V3(0, 1, 0), 14, GREEN)
		R.sound("PowerUp", pts[1], 0.6)
		R.wait(0.7)
		-- BEAT 2 : la courbe se dessine sous ses pieds, il la surfe ; les barres poussent ; le compteur grimpe
		local drawn = 0
		R.over(2.4, function(a, e)
			local d = TOTAL * e
			local p, dir, i = at(d)
			while drawn < i - 1 do
				drawn += 1
				seg(pts[drawn], pts[drawn + 1])
				R.sound("Ding", pts[drawn + 1], 0.35, 1 + drawn * 0.12)
			end
			local flat = V3(dir.X, 0, dir.Z)
			if flat.Magnitude < 0.01 then
				flat = V3(1, 0, 0)
			end
			R.place(CFrame.lookAt(p + V3(0, 3.3, 0), p + V3(0, 3.3, 0) + flat))
			counter.Label.Text = "HOURS BILLED: " .. math.floor(e * 1200)
		end, ES.Quad, ED.In)
		R.cam.track(2.4, function()
			local p = R.pos(R.root)
			return p + V3(1.5, 1.5, -9), p + V3(2.5, 0, 0), 60
		end)
		for k, b in ipairs(bars) do
			R.delay(0.25 + k * 0.25, function()
				R.moveTo(b.part, CF(b.x, b.h / 2, 9), 0.35, ES.Back, ED.Out)
			end)
		end
		R.every(0.06, function()
			local p = R.pos(R.root)
			if p.Y < TOP + 2 then
				R.fx.sparks(p - V3(0, 3, 0), 3, GREEN)
			end
		end)
		R.wait(2.4)
		seg(pts[#pts - 1], pts[#pts])
		-- BEAT 3 : au sommet, saut au ralenti avec vrille, atterrissage sur le pilier d'or
		R.slowmo(0.3, 1.3)
		R.jump(R.rig, FINAL, 0.5, 3)
		R.spin(R.rig, 1, 0.5)
		R.cam.orbit(V3(0, TOP + 3, 0), 10, 0.5, -1.2, -0.3, 0.6, 58, 54)
		R.fx.money(V3(0, TOP + 3, 0), 2.5, 40)
		R.sound("Whoosh", V3(0, TOP + 3, 0), 0.8, 0.7)
		R.wait(0.55)
		R.slowmo(1)
		R.fx.coins(V3(0, TOP + 1, 0), 24)
		R.fx.shockwave(V3(0, TOP + 0.3, 0), 6, GOLD)
		R.sound("Clang", V3(0, TOP, 0), 0.9)
		R.cam.shake(0.4)
		-- BEAT 4 : le compteur s'emballe, scan au laser du monocle
		R.face(V3(0, TOP + 3, -10), 0.2)
		R.cam.cut(V3(-2.0, TOP + 3.8, -7.5), V3(0, TOP + 4.4, 0), 50)
		R.over(0.7, function(a, e)
			counter.Label.Text = "HOURS BILLED: " .. string.format("%d", math.floor(1200 + e * 1800))
		end)
		R.wait(0.7)
		counter.Label.Text = "HOURS BILLED: 3,000"
		R.fx.banner("3,000 HOURS BILLED", { color = GOLD, t = 0.8, size = 0.12 })
		R.sound("LevelUp", V3(0, TOP + 4, 0), 0.8)
		local eye = V3(0.24, TOP + 4.85, -0.7)
		for k = 0, 3 do
			R.delay(k * 0.12, function()
				R.fx.beam(eye, V3(-3 + k * 2, TOP + 3.5, -7), 0.12, LASER, 0.14)
			end)
		end
		R.fx.word("SCANNING...", V3(-2.5, TOP + 6.5, -1), 0.7)
		R.wait(0.6)
		-- BEAT 5 : mallette d'or levée, rayons dorés
		R.pose(final)
		R.fx.rays(GOLD, V3(0, TOP + 4, 0))
		R.fx.light(V3(0, TOP + 5, -2), GOLD, 20, 4, 1)
		R.cam.hero(0.7)
		R.wait(0.6)
		R.title()
		R.wait(1.4)
	end,
}

------------------------------------------------------------------------ THE OFFICE CAT
-- RARE · Tuxedo Cat — la tasse poussée du bord : gros plan sur le mug que sa patte pousse lentement… CRASH,
-- il fixe la caméra, saute de la table et réajuste son nœud papillon.
P.OfficeCat_Rare = {
	Caption = "Black tie, white paws, zero manners. Your mug had it coming.",
	Location = "Boardroom - Quarterly Review",
	Reveal = function(R, ctx)
		local WOODT, MUGC = C3(95, 60, 40), C3(245, 245, 240)
		local FINAL = CF(0, 3, -6.6)
		R.stage("Room", { color = C3(205, 195, 180), floor = C3(80, 62, 52), w = 28, d = 26, h = 12 })
		R.mark(FINAL)
		-- grande table de réunion + chaises + baie vitrée
		R.box(V3(5, 0.3, 12), CF(0, 3.2, 1), WOODT, "Wood")
		R.box(V3(1, 3.05, 1), CF(0, 1.5, -3), C3(60, 40, 30), "Wood")
		R.box(V3(1, 3.05, 1), CF(0, 1.5, 5), C3(60, 40, 30), "Wood")
		for _, z in ipairs({ -1, 2.5, 6 }) do
			R.prop("OfficeChair", CF(-3.8, 0, z) * FACE_PX)
			R.prop("OfficeChair", CF(3.8, 0, z) * FACE_NX)
		end
		for i = -2, 2 do
			R.box(V3(4.6, 7, 0.2), CF(i * 4.8, 5.5, 12.8), C3(150, 200, 240), "Glass", 0.3)
		end
		-- le mug (au bord droit de la table, côté +X)
		local mug = R.model({
			{ Size = V3(0.7, 0.8, 0.7), CFrame = CF(0, 0, 0), Color = MUGC, Shape = "Cyl", Name = "Body" },
			{ Size = V3(0.1, 0.62, 0.62), CFrame = CF(0, 0.36, 0), Color = C3(90, 55, 30), Shape = "Cyl" },
			{ Size = V3(0.12, 0.45, 0.3), CFrame = CF(0.45, 0, 0), Color = MUGC },
		}, CF(0, 0, 0))
		for _, p in ipairs(mug:GetChildren()) do
			if p:IsA("BasePart") and p.Shape == Enum.PartType.Cylinder then
				p.CFrame = p.CFrame * ANG(0, 0, PI / 2)
			end
		end
		local MUG0 = CF(1.8, 3.75, -3.7)
		mug:PivotTo(R.at(MUG0.X, MUG0.Y, MUG0.Z))
		local splat = R.box(V3(0.05, 2.2, 2.2), CF(3.4, 0.03, -3.9) * ANG(0, 0, PI / 2), C3(90, 55, 30), "SmoothPlastic", 0, "Cyl")
		R.show(splat, false)
		local sit = { RS = { p = 0.3, r = 0.1 }, LS = { p = 0.3, r = 0.1 }, RJ = { ln = 0.05 }, RH = { p = 1.57 }, LH = { p = 1.57 } }
		local bowtie = { RS = { p = 1.9, r = -0.75, y = 0.5 }, LS = { p = 0.3, r = 0.55, y = -0.3 }, RJ = { tw = 0.15, ln = -0.08 }, RH = { r = 0.12 }, LH = { r = 0.12 } }
		R.onSkip(function(R)
			mug:PivotTo(R.at(3.4, 0.4, -3.9) * ANG(0, 0, PI / 2))
			R.show(splat, true)
			R.place(FINAL)
			R.pose(bowtie)
			R.cam.hero()
		end)

		-- BEAT 1 : macro sur le mug, la patte s'approche et pousse… pousse… CRASH
		R.place(CF(0, 4.35, -3.5))
		R.pose(sit)
		R.cam.cut(V3(3.6, 3.9, -6.6), V3(1.6, 4.1, -3.6), 40)
		R.anim({
			{ t = 0, RS = { p = 0.3, r = 0.1 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
			{ t = 0.4, RS = { p = 0.9, r = 0.55 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
			{ t = 0.55, RS = { p = 0.95, r = 0.75 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
			{ t = 0.75, RS = { p = 0.9, r = 0.6 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
			{ t = 0.9, RS = { p = 0.95, r = 0.85 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
			{ t = 1.6, RS = { p = 0.9, r = 0.8 }, LS = { p = 0.3, r = 0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
		})
		R.wait(0.5)
		R.moveTo(mug, CF(2.1, 3.75, -3.7), 0.12)
		R.sound("Squeak", MUG0, 0.4, 1.8)
		R.wait(0.35)
		R.moveTo(mug, CF(2.35, 3.75, -3.7) * ANG(0, 0, rad(-12)), 0.12)
		R.sound("Squeak", MUG0, 0.4, 2)
		R.wait(0.3)
		R.fly(mug, { V3(2.6, 3.9, -3.75), V3(3.2, 2.6, -3.85), V3(3.4, 0.4, -3.9) }, 0.4, { style = ES.Quad, dir = ED.In })
		R.spin(mug, 0.3, 0.4, "Z")
		R.cam.move(V3(3.4, 2.4, -7.2), V3(3.0, 1.2, -3.8), 0.35, 44)
		R.wait(0.4)
		R.fx.shards(V3(3.4, 0.5, -3.9), 14, { MUGC, C3(90, 55, 30) })
		R.show(splat, true, 0.1)
		R.sound("GlassBreak", V3(3.4, 0.4, -3.9), 1)
		R.fx.word("CRASH!", V3(4.2, 2.6, -4.6), 0.9)
		R.cam.shake(0.3)
		R.wait(0.35)
		-- BEAT 2 : il fixe la caméra sans remords, saute de la table et réajuste son nœud papillon
		R.cam.move(V3(-1.8, 5.4, -10.5), V3(0, 4.6, -4), 0.45, 52, ES.Quad, ED.Out)
		R.fx.word("...", V3(-1.2, 7, -3.6), 0.6)
		R.wait(0.45)
		R.jump(R.rig, FINAL, 0.45, 1.2)
		R.wait(0.45)
		R.pose(bowtie)
		R.sound("UIClick", V3(0, 4.5, -6.6), 0.6, 1.5)
		R.fx.twinkle(V3(0.3, 4.0, -7.2))
		R.wait(0.35)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Cyber Kitty — la chasse au point laser : le point rouge danse, trois bonds ratés, le point grimpe sur
-- l'objectif, il bondit sur la caméra (MEOW.EXE), atterrit en pose néon.
P.OfficeCat_Epic = {
	Caption = "Neon ears, LED tail, all nine lives backed up to the cloud.",
	Location = "Server Lounge - Lights Off",
	Reveal = function(R, ctx)
		local NPINK, NCYAN, LASER = C3(255, 60, 200), C3(40, 230, 255), C3(255, 30, 40)
		local FINAL = CF(0, 3, -3)
		R.stage("Room", { dark = true, color = C3(40, 25, 70), floor = C3(70, 55, 105), w = 32, d = 30, h = 12 })
		R.mark(FINAL)
		for i, x in ipairs({ -15.6, 15.6 }) do
			R.box(V3(0.2, 0.3, 28), CF(x, 3, 0), (i == 1) and NPINK or NCYAN, "Neon")
			R.box(V3(0.2, 0.3, 28), CF(x, 8, 0), (i == 1) and NCYAN or NPINK, "Neon")
		end
		R.box(V3(30, 0.3, 0.2), CF(0, 5.5, 14.6), NPINK, "Neon")
		R.prop("Server", CF(-9, 0, 9))
		R.prop("Server", CF(9, 0, 9))
		-- le point laser
		local dot = R.ball(0.45, V3(4, 0.25, 6), LASER, "Neon")
		R.light(dot, LASER, 8, 3)
		R.light(V3(0, 10, 0), C3(170, 120, 255), 40, 1.3)
		local paws = { RS = { p = 2.2, r = -0.35, y = 0.4 }, LS = { p = 2.2, r = -0.35, y = 0.4 }, RJ = { ln = 0.12, sd = 0.08 }, RH = { p = 0.3, r = 0.15 }, LH = { p = -0.15, r = 0.15 } }
		local leap = { RS = { p = 2.6, r = -0.1 }, LS = { p = 2.6, r = -0.1 }, RJ = { ln = 0.35 }, RH = { p = -0.6 }, LH = { p = -0.6 } }
		R.onSkip(function(R)
			dot.Transparency = 1
			R.place(FINAL)
			R.transform(true)
			R.pose(paws)
			R.cam.hero()
		end)

		-- BEAT 1 : vue plongeante, le point rouge zigzague, le chat se ramasse prêt à bondir
		R.place(CF(-7, 3, 2) * FACE_PX)
		R.pose("Crouch")
		R.cam.cut(V3(-1, 17, -9), V3(0, 0, 1.5), 52)
		R.fly(dot, { V3(4, 0.25, 6), V3(-1, 0.25, 4), V3(3, 0.25, -1), V3(-2.5, 0.25, 2) }, 1.4, { style = ES.Linear })
		R.sound("Electric", V3(0, 1, 2), 0.3, 2)
		R.wait(1.0)
		R.face(V3(-2.5, 3, 2), 0.15)
		R.fx.word("!", V3(-7, 7, 2), 0.9)
		R.sound("Ding", V3(-7, 4, 2), 0.6, 2)
		R.wait(0.4)
		-- BEAT 2 : trois bonds — le point s'échappe à chaque fois
		local spots = { V3(-2.5, 0.25, 2), V3(2.5, 0.25, -1.5), V3(0, 0.25, 4) }
		local nexts = { V3(2.5, 0.25, -1.5), V3(0, 0.25, 4), V3(0, 0.25, -3) }
		local rl, ll = limb(R, "Right Arm"), limb(R, "Left Arm")
		if rl then
			R.fx.trail(rl, NPINK, 2.4)
		end
		if ll then
			R.fx.trail(ll, NCYAN, 2.4)
		end
		R.cam.track(2.1, function()
			local p = R.pos(R.root)
			return V3(p.X * 0.5, 12, p.Z - 10), V3(p.X * 0.7, 2, p.Z), 52
		end)
		for i = 1, 3 do
			local s = spots[i]
			R.pose(leap)
			R.jump(R.rig, CFrame.lookAt(V3(s.X, 3, s.Z), V3(nexts[i].X, 3, nexts[i].Z)), 0.42, 2.2)
			R.delay(0.3, function()
				R.moveTo(dot, nexts[i], 0.12, ES.Quad, ED.Out)
			end)
			R.wait(0.42)
			R.fx.dust(V3(s.X, 0, s.Z), 2.5)
			R.sound("Thud", V3(s.X, 0, s.Z), 0.6, 1.3)
			R.fx.word((i == 3) and "MISS!" or "POUNCE!", V3(s.X - 1, 6, s.Z), 0.7)
			R.pose("Crouch")
			R.wait(0.25)
		end
		-- BEAT 3 : le point grimpe sur l'objectif ; il bondit sur la caméra — MEOW.EXE
		R.cam.cut(V3(0, 4.4, -10), V3(0, 3.8, 1), 56)
		R.face(V3(0, 3, -10), 0)
		R.fly(dot, { V3(0, 0.25, -3), V3(0, 2.5, -6.5), V3(0.15, 4.3, -9.2) }, 0.35)
		R.wait(0.35)
		R.pose(leap)
		R.jump(R.rig, CF(0, 3, -4.2), 0.5, 2.6)
		R.cam.pushIn(V3(0, 5, -4), 6, 3.8, 0.3, { height = 0.2, fov = 62 })
		R.wait(0.25)
		R.freeze(0.22)
		R.fx.glitch()
		R.fx.banner("MEOW.EXE", { color = NCYAN, t = 0.7, size = 0.18 })
		R.sound("Electric", V3(0, 5, -5), 0.9, 1.4)
		dot.Transparency = 1
		R.wait(0.25)
		R.place(FINAL)
		R.transform(true)
		R.pose(paws)
		R.fx.sparks(V3(0, 4, -3), 18, NPINK)
		R.fx.shockwave(V3(0, 0.2, -3), 7, NCYAN)
		R.cam.move(V3(-2.4, 3.6, -11), V3(0, 4.3, -3), 0.6, 54, ES.Quad, ED.Out)
		R.wait(0.5)
		R.title()
		R.wait(1.2)
	end,
}

-- LEGENDARY · Lucky Fortune Cat — jackpot : lanternes qui s'allument, une pièce d'or géante roule jusqu'à lui,
-- se retourne et se plaque dans son dos, la patte fait coucou, la machine à sous tombe sur 7-7-7, avalanche d'or.
P.OfficeCat_Legendary = {
	Caption = "Waves one paw, brings fortune to the office. Brings ruin to your coworkers.",
	Location = "The Lucky Break Room - Jackpot Hour",
	Reveal = function(R, ctx)
		local LRED, LGOLD, LGOLDD = C3(220, 35, 45), C3(255, 200, 40), C3(215, 155, 30)
		R.stage("Room", { dark = true, color = C3(110, 18, 24), floor = C3(55, 14, 18), w = 38, d = 34, h = 16 })
		-- lanternes rouges (éteintes)
		local lanterns = {}
		for _, z in ipairs({ -5, 3, 10 }) do
			for _, x in ipairs({ -8, 8 }) do
				R.box(V3(0.08, 3, 0.08), CF(x, 14.5, z), C3(40, 30, 20))
				R.cyl(0.3, 1.2, V3(x, 12.9, z), LGOLD, "Metal")
				local l = R.ball(1.8, V3(x, 11.8, z), C3(90, 20, 20), "Neon")
				R.cyl(0.3, 1.2, V3(x, 10.8, z), LGOLD, "Metal")
				lanterns[#lanterns + 1] = { part = l, light = R.light(l, C3(255, 90, 60), 16, 0) }
			end
		end
		-- machine à sous géante au fond
		R.box(V3(12, 6, 1.6), CF(0, 7, 12), LGOLD, "Foil")
		R.box(V3(12.6, 1.2, 1.8), CF(0, 10.6, 12), LRED)
		local title = R.box(V3(10, 1, 0.2), CF(0, 10.6, 11.05), LRED)
		R.text(title, "LUCKY 7", { Color = LGOLD })
		local SYMS = { "7", "$", "★", "♣", "BAR" }
		local reels = {}
		for i, x in ipairs({ -3.6, 0, 3.6 }) do
			local r = R.box(V3(3.2, 3.8, 0.2), CF(x, 7, 11.15), WHITE)
			reels[i] = R.text(r, SYMS[i + 1], { Color = LRED })
		end
		R.box(V3(0.4, 4, 0.4), CF(6.6, 8, 12), C3(160, 160, 170), "Metal")
		R.ball(1.0, V3(6.6, 10.2, 12), LRED, "SmoothPlastic")
		-- pièce géante (disque, axe le long de Z pour rouler sur X)
		local COIN_R = 2.6
		local coin = R.box(V3(0.6, COIN_R * 2, COIN_R * 2), CF(17, COIN_R, -1.6), LGOLD, "Foil", 0, "Cyl")
		R.text(coin, "$", { Face = Enum.NormalId.Right, Color = LGOLDD })
		local function coinAt(x, roll)
			coin.CFrame = R.at(x, COIN_R, -1.6) * ANG(0, PI / 2, 0) * ANG(roll, 0, 0)
		end
		coinAt(17, 0)
		local beckon = {}
		for k = 0, 8 do
			beckon[#beckon + 1] = { t = k * 0.18, RS = { p = (k % 2 == 0) and 2.95 or 2.35, r = 0.15 }, LS = { p = 0.9, r = -0.2, y = 0.3 }, RJ = { sd = (k % 2 == 0) and 0.05 or -0.03 } }
		end
		local final = { RS = { p = 2.9, r = 0.15 }, LS = { p = 1.0, r = -0.2, y = 0.3 }, RJ = { ln = -0.08, sd = 0.06 }, RH = { r = 0.15 }, LH = { r = 0.15 } }
		local function lightsOn()
			for _, l in ipairs(lanterns) do
				l.part.Color = C3(255, 70, 50)
				l.light.Brightness = 2
			end
		end
		R.onSkip(function(R)
			lightsOn()
			if coin.Parent then
				coin:Destroy()
			end
			for i = 1, 3 do
				reels[i].Text = "7"
			end
			R.place(CF(0, 3, 0))
			R.transform(true)
			R.pose(final)
			R.cam.hero()
		end)

		-- BEAT 1 : dans le noir, les lanternes s'allument une à une
		R.place(CF(0, 3, 0))
		R.pose("Crouch")
		R.cam.cut(V3(-10, 3, -12), V3(0, 7, 4), 56)
		R.cam.move(V3(-5, 4, -13), V3(0, 7, 4), 1.8, 56, ES.Sine, ED.InOut)
		for i, l in ipairs(lanterns) do
			R.delay(0.15 + i * 0.25, function()
				l.part.Color = C3(255, 70, 50)
				R.tween(l.light, 0.2, { Brightness = 2 })
				R.sound("Ding", l.part, 0.5, 0.9 + i * 0.1)
			end)
		end
		R.wait(1.8)
		-- BEAT 2 : la pièce d'or géante roule jusqu'à lui et s'arrête devant, en vacillant
		R.cam.cut(V3(-1, 1.6, -11), V3(3, 2.6, -1.6), 50)
		R.sound("Rumble", V3(10, 1, -1.6), 0.5, 1.4)
		R.over(1.2, function(a, e)
			local x = 17 - 17 * e
			coinAt(x, -(17 * e) / COIN_R)
		end, ES.Quad, ED.Out)
		R.cam.move(V3(-0.5, 2.2, -10), V3(0, 3, -1.6), 1.2, 46)
		R.wait(1.2)
		R.sound("Clang", V3(0, 2, -1.6), 0.7, 1.3)
		-- BEAT 3 : la pièce saute, se retourne et file se plaquer dans son dos ; la patte porte-bonheur fait coucou
		R.fly(coin, { V3(0, COIN_R, -1.6), V3(0, 9, -0.5), V3(0, 4.5, 1.6) }, 0.6)
		R.spin(coin, 2, 0.6, "Y")
		R.pose(final)
		R.cam.move(V3(-2.0, 4.4, -9.5), V3(0, 4.6, 0), 0.5, 52, ES.Quad, ED.Out)
		R.wait(0.6)
		R.destroy(coin, "sparks")
		R.transform(true)
		R.fx.shockwave(V3(0, 4.5, 1.4), 5, LGOLD)
		R.sound("PowerUp", V3(0, 4.5, 1), 0.8)
		R.anim(beckon)
		R.every(0.36, function(i)
			if i <= 4 then
				R.fx.coins(V3(R.rand(-3, 3), 9, R.rand(-2, 2)), 6)
				R.sound("Pickup", V3(0, 6, 0), 0.4, 1 + i * 0.1)
			end
		end)
		R.wait(1.2)
		-- BEAT 4 : la machine à sous s'emballe… 7… 7… 7 — JACKPOT, avalanche d'or au ralenti
		R.cam.whip(V3(-3, 5, -6), V3(0, 6.5, 11))
		local stopped = 0
		R.every(0.06, function()
			for i = stopped + 1, 3 do
				reels[i].Text = SYMS[R.randi(1, #SYMS)]
			end
		end)
		for i = 1, 3 do
			R.wait(0.32)
			stopped = i
			reels[i].Text = "7"
			R.sound("Clang", V3(-3.6 + (i - 1) * 3.6, 7, 11), 0.8, 0.9 + i * 0.15)
			R.cam.shake(0.2)
		end
		R.fx.banner("JACKPOT!", { color = LGOLD, t = 1.0, size = 0.22 })
		R.sound("LevelUp", V3(0, 7, 11), 1)
		R.slowmo(0.35, 1.5)
		R.fx.rain({ Colors = { LGOLD, C3(255, 230, 120) }, Size = V3(0.14, 0.9, 0.9), Shape = "Cyl", Material = "Foil", Count = 60 }, 3)
		R.fx.coins(V3(0, 9, 11), 30)
		R.fx.rays(LGOLD, V3(0, 5, 0))
		R.cam.orbit(V3(0, 4.4, 0), 9, 0.6, 0.5, -0.4, 1.4, 54, 50)
		R.wait(0.6)
		-- BEAT 5 : patte levée, pièce géante qui tourne dans le dos
		R.slowmo(1)
		R.pose(final)
		R.cam.hero(0.6)
		R.wait(0.5)
		R.title()
		R.wait(1.5)
	end,
}
------------------------------------------------------------------------ THE AI ASSISTANT
-- RARE · Retro PC — démarrage : gros plan sur l'écran cathodique, lignes de BIOS, il s'allume d'un sursaut,
-- la disquette est éjectée et rattrapée, READY.
P.AIAssistant_Rare = {
	Caption = "Running on 640K of pure confidence. Please do not unplug.",
	Location = "IT Closet - Est. 1994",
	Reveal = function(R, ctx)
		local GRN, BEIGE = C3(80, 255, 120), C3(225, 215, 180)
		R.stage("Room", { color = C3(195, 190, 165), floor = C3(120, 115, 100), w = 24, d = 22, h = 11 })
		-- bureau des années 90 : vieux PC, pile de disquettes, plante
		R.prop("Desk", CF(4.5, 0, 5))
		R.box(V3(2.2, 1.9, 1.9), CF(4.5, 3.7, 5.3), BEIGE)
		local scr = R.box(V3(1.7, 1.3, 0.1), CF(4.5, 3.75, 4.3), C3(18, 28, 20), "Neon")
		R.text(scr, "C:\\>_", { Color = GRN })
		for k = 0, 3 do
			R.box(V3(0.8, 0.08, 0.8), CF(2.6, 2.8 + k * 0.09, 4.6), (k % 2 == 0) and C3(40, 60, 160) or C3(30, 30, 35))
		end
		R.prop("Plant", CF(-5, 0, 5))
		local floppy = R.model({
			{ Size = V3(0.8, 0.8, 0.08), CFrame = CF(0, 0, 0), Color = C3(40, 60, 160) },
			{ Size = V3(0.45, 0.25, 0.09), CFrame = CF(0, 0.25, 0), Color = C3(190, 195, 205), Material = "Metal" },
			{ Size = V3(0.6, 0.3, 0.09), CFrame = CF(0, -0.18, 0), Color = WHITE },
		}, CF(-0.5, -10, -0.7))
		local slump = { RS = { p = 0.1, r = -0.1 }, LS = { p = 0.1, r = -0.1 }, RJ = { ln = 0.55, sd = 0.12 }, RH = { p = 0.15 }, LH = { p = 0.05 } }
		local ready = { RS = { p = 1.5, r = 0.2, y = 0.3 }, LS = { p = 2.0, r = -0.3, y = 0.5 }, RJ = { ln = -0.05, tw = -0.1 }, RH = { r = 0.1 }, LH = { r = 0.1 } }
		R.onSkip(function(R)
			R.fx.dark(0)
			floppy:PivotTo(R.at(0, -10, 0))
			R.place(CF(0, 3, 0))
			R.pose(ready)
			R.cam.hero()
		end)

		-- BEAT 1 : écran éteint en très gros plan, lignes de démarrage
		R.place(CF(0, 3, 0))
		R.pose(slump)
		R.fx.dark(0.55)
		R.cam.cut(V3(0.2, 4.1, -2.6), V3(0, 4.25, 0), 42)
		local lines = { "BIOS v1.0 ... OK", "MEMORY 640K ... OK", "LOADING PERSONALITY.EXE" }
		for i, t in ipairs(lines) do
			R.fx.banner(t, { color = GRN, t = 0.38, size = 0.06, y = 0.18 + i * 0.07 })
			R.sound("UIClick", V3(0, 4.5, -1), 0.4, 0.6 + i * 0.1)
			R.wait(0.38)
		end
		-- BEAT 2 : sursaut d'allumage, la caméra recule ; la disquette est éjectée et rattrapée
		R.fx.dark(0, 0.1)
		R.fx.flash(GRN, 0.02, 0.03, 0.2)
		R.sound("PowerUp", V3(0, 4.5, 0), 0.8, 1.3)
		R.anim({ { t = 0, RJ = { ln = 0.55, sd = 0.12 } }, { t = 0.12, RJ = { ln = -0.25 }, RS = { p = 0.6, r = 0.6 }, LS = { p = 0.6, r = 0.6 } }, { t = 0.35, RJ = { ln = 0 } } })
		R.cam.pullOut(V3(0, 4.2, 0), 2.6, 8.5, 0.7, { height = 0.4, yaw = -0.2, fov = 54 })
		R.wait(0.45)
		R.sound("Boing", V3(-0.5, 3.4, -0.7), 0.6, 1.6)
		floppy:PivotTo(R.at(-0.5, 3.45, -0.7))
		R.fly(floppy, { V3(-0.5, 3.45, -0.7), V3(-0.8, 6.2, -1.8), V3(-1.3, 4.6, -1.6) }, 0.55)
		R.spin(floppy, 2, 0.55, "X")
		R.wait(0.5)
		R.pose(ready)
		R.fx.word("READY.", V3(-2, 6.4, -0.8), 0.8)
		R.sound("Ding", V3(0, 4, 0), 0.7, 1.2)
		R.wait(0.8)
		R.title()
		R.wait(1.0)
	end,
}

-- EPIC · Neon Hologram — projection : un projecteur au sol, un plan de balayage la construit de bas en haut,
-- le signal glitche, elle sort du faisceau et passe ONLINE.
P.AIAssistant_Epic = {
	Caption = "100% light, 0% physical form, 200% attitude.",
	Location = "R&D Lab - Projector Bay 3",
	Reveal = function(R, ctx)
		local HMAG, HCY = C3(255, 60, 200), C3(60, 230, 255)
		local FINAL = CF(0, 3, -2.6)
		R.stage("Void")
		R.mark(FINAL)
		-- sol de labo quadrillé + projecteur
		for i = -4, 4 do
			R.box(V3(0.06, 0.02, 24), CF(i * 3, 0.02, 2), C3(60, 30, 110), "Neon")
			R.box(V3(24, 0.02, 0.06), CF(0, 0.02, i * 3 + 2), C3(60, 30, 110), "Neon")
		end
		R.cyl(0.4, 3, V3(0, 0.2, 0.4), C3(30, 30, 40), "Metal")
		local ring = R.cyl(0.1, 2.6, V3(0, 0.42, 0.4), C3(40, 40, 60), "Neon")
		local beam = R.cyl(7, 3.4, V3(0, 3.6, 0.4), HCY, "ForceField")
		beam.Transparency = 1
		local scan = R.box(V3(0.06, 3.8, 3.8), CF(0, 0.3, 0.4) * ANG(0, 0, PI / 2), HMAG, "Neon", 0.2, "Cyl")
		R.show(scan, false)
		local online = { RS = { p = 0.6, r = 1.2 }, LS = { p = 0.6, r = 1.2 }, RJ = { ln = -0.12 }, RH = { r = 0.25 }, LH = { r = 0.25 } }
		R.onSkip(function(R)
			R.alpha(1)
			beam.Transparency = 0.75
			ring.Color = HCY
			R.place(FINAL)
			R.transform(true)
			R.pose(online)
			R.cam.hero()
		end)

		-- BEAT 1 : le projecteur s'allume, un plan de balayage la construit de bas en haut
		R.alpha(0)
		R.place(CF(0, 3, 0.4))
		R.pose({ RS = { p = 0.1 }, LS = { p = 0.1 }, RJ = {} })
		R.cam.cut(V3(-3, 1.2, -8), V3(0, 2.5, 0.4), 50)
		R.sound("Electric", V3(0, 0.5, 0.4), 0.6, 0.7)
		ring.Color = HCY
		R.tween(beam, 0.3, { Transparency = 0.75 })
		R.wait(0.3)
		R.show(scan, true, 0.05)
		R.moveTo(scan, CF(0, 5.6, 0.4) * ANG(0, 0, PI / 2), 1.2, ES.Linear)
		R.alpha(1, 1.2)
		R.cam.crane(V3(0, 3, 0.4), -1.2, 2, 8.5, 1.3, { yaw = -0.35, fov = 54 })
		R.wait(1.2)
		R.show(scan, false, 0.15)
		-- BEAT 2 : le signal glitche (téléports, scintillement), puis elle sort du faisceau
		R.fx.glitch()
		R.fx.banner("SIGNAL UNSTABLE", { color = HMAG, t = 0.5, size = 0.07, y = 0.2 })
		R.teleport(R.rig, CF(0.9, 3, 0.4), "glitch")
		R.wait(0.12)
		R.teleport(R.rig, CF(-0.7, 3, 0.4), "glitch")
		R.wait(0.12)
		R.teleport(R.rig, CF(0, 3, 0.4), "glitch")
		R.every(0.05, function(i)
			if i <= 10 then
				R.alpha((i % 2 == 0) and 0.35 or 1)
			elseif i == 11 then
				R.alpha(1)
			end
		end)
		R.wait(0.55)
		R.walk(FINAL, 0.6, "Strut")
		R.fx.ring(V3(0, 0.5, -1), V3(0, 1, 0), 4, HCY)
		R.cam.move(V3(-1.8, 3.4, -9.5), V3(0, 4.3, -2.4), 0.6, 50)
		R.wait(0.6)
		-- BEAT 3 : ONLINE — ailes holographiques, bras ouverts
		R.transform(true)
		R.pose(online)
		R.fx.banner("ONLINE", { color = HCY, t = 0.8, size = 0.16 })
		R.fx.sparks(V3(0, 4.5, -2.6), 20, HMAG)
		R.sound("PowerUp", V3(0, 4, -2.6), 0.9)
		R.cam.lowAngle(V3(0, 4.2, -2.6), 7.5, 0.45)
		R.wait(1.3)
		R.title()
		R.wait(1.2)
	end,
}

-- LEGENDARY · Singularity Core — éclosion : salle des serveurs, flux de données qui convergent dans un noyau de lumière,
-- le noyau se fissure au ralenti, elle s'y déplie, tous les écrans affichent ses secrets, tourbillon d'e-mails.
P.AIAssistant_Legendary = {
	Caption = "It read every email in the building. It knows what you did at the holiday party.",
	Location = "Data Center - Sublevel 9",
	Reveal = function(R, ctx)
		local CORE, GOLDC = C3(60, 230, 255), C3(255, 200, 60)
		local FINAL = CF(0, 5, 0)
		R.stage("Room", { dark = true, color = C3(20, 24, 34), floor = C3(26, 29, 40), w = 42, d = 42, h = 18 })
		R.mark(FINAL)
		-- baies de serveurs en arc + LED qui clignotent + écrans
		local racks, leds, screens = {}, {}, {}
		for i = 0, 7 do
			local a = rad(-105 + i * 30)
			local pos = V3(math.sin(a) * 13, 4, math.cos(a) * 13)
			local cf = CFrame.lookAt(pos, V3(0, 4, 0))
			R.box(V3(3, 8, 2), cf, C3(60, 66, 86), "Metal")
			racks[#racks + 1] = pos
			for k = 0, 5 do
				leds[#leds + 1] = R.box(V3(0.25, 0.12, 0.05), cf * CF(R.rand(-1.1, 1.1), -3 + k * 1.1, -1.03), CORE, "Neon")
			end
			if i % 2 == 1 then
				local s = R.box(V3(4.6, 2.6, 0.2), cf * CF(0, 6.4, 0), C3(10, 14, 22), "Neon")
				screens[#screens + 1] = R.text(s, "...", { Color = CORE })
			end
		end
		R.every(0.1, function()
			for _ = 1, 6 do
				local l = leds[R.randi(1, #leds)]
				l.Color = (R.randi(0, 2) == 0) and GOLDC or ((R.randi(0, 1) == 0) and CORE or C3(20, 40, 50))
			end
		end)
		-- le noyau
		local core = R.ball(4.2, V3(0, 5, 0), WHITE, "Neon")
		local shell = R.ball(5.4, V3(0, 5, 0), CORE, "Glass", 0.55)
		local coreLight = R.light(core, CORE, 26, 2)
		R.light(V3(0, 13, -6), C3(120, 170, 255), 45, 1.4)
		local bar = R.billboard("LEARNING... 1%", V3(0, 9.2, 0), { size = 6, Color = CORE })
		local fetal = { RS = { p = 1.2, r = -0.4 }, LS = { p = 1.2, r = -0.4 }, RJ = { ln = 0.6 }, RH = { p = 1.4 }, LH = { p = 1.4 } }
		local ascend = { RS = { p = 0.9, r = 1.3 }, LS = { p = 0.9, r = 1.3 }, RJ = { ln = -0.2 }, RH = { p = 0.2, r = 0.15 }, LH = { p = -0.1, r = 0.15 } }
		local SECRETS = { "I KNOW WHAT YOU DID", "HOLIDAY_PARTY.MOV", "48,213 EMAILS READ", "REPLY-ALL DETECTED" }
		local function revealed()
			for i, s in ipairs(screens) do
				s.Text = SECRETS[(i - 1) % #SECRETS + 1]
				s.TextColor3 = (i % 2 == 0) and GOLDC or CORE
			end
		end
		R.onSkip(function(R)
			core.Transparency = 1
			shell.Transparency = 1
			bar.Label.Text = "SINGULARITY REACHED"
			revealed()
			R.alpha(1)
			R.place(FINAL)
			R.transform(true)
			R.pose(ascend)
			R.cam.hero()
		end)

		-- BEAT 1 : les serveurs ronronnent, la barre d'apprentissage grimpe
		R.alpha(0)
		R.place(FINAL)
		R.pose(fetal)
		R.cam.cut(V3(-12, 2.5, -6), V3(0, 5, 0), 52)
		R.cam.dolly(V3(-12, 2.5, -6), V3(-4, 3.5, -11), V3(0, 5, 0), 1.8, 50)
		R.over(1.8, function(a)
			bar.Label.Text = "LEARNING... " .. math.floor(1 + a * 40) .. "%"
		end)
		R.sound("Rumble", V3(0, 4, 0), 0.4, 1.4)
		R.wait(1.8)
		-- BEAT 2 : flux de données de chaque baie vers le noyau, les e-mails convergent, le noyau grossit
		R.cam.orbit(V3(0, 5, 0), 12, 3, -0.4, 0.9, 1.8, 54, 50)
		R.every(0.12, function(i)
			if i <= 14 then
				local p = racks[(i % #racks) + 1]
				R.fx.beam(p + V3(0, 2, 0), V3(0, 5, 0), 0.25, (i % 3 == 0) and GOLDC or CORE, 0.25)
			end
		end)
		for k = 1, 10 do
			R.delay(k * 0.13, function()
				local p = racks[(k % #racks) + 1]
				local env = R.box(V3(0.9, 0.6, 0.05), CF(p.X, p.Y + 1, p.Z), WHITE)
				R.fly(env, { p + V3(0, 1, 0), (p + V3(0, 1, 0)):Lerp(V3(0, 5, 0), 0.5) + V3(0, 3, 0), V3(0, 5, 0) }, 0.6, { face = true })
				R.delay(0.6, function()
					if env.Parent then
						env:Destroy()
					end
				end)
			end)
		end
		R.tween(core, 1.8, { Size = V3(5, 5, 5) })
		R.over(1.8, function(a)
			bar.Label.Text = "LEARNING... " .. math.floor(41 + a * 58) .. "%"
			coreLight.Brightness = 2 + a * 4
		end)
		R.sound("PowerUp", V3(0, 5, 0), 0.8, 0.8)
		R.wait(1.8)
		-- BEAT 3 : le noyau se fissure au ralenti, elle s'y déplie et ouvre les bras
		bar.Label.Text = "SINGULARITY REACHED"
		R.cam.pushIn(V3(0, 5, 0), 10, 7, 1.2, { height = -0.8, fov = 56 })
		R.slowmo(0.3, 1.2)
		R.fx.flash(WHITE, 0.03, 0.05, 0.4)
		R.fx.explosion(V3(0, 5, 0), 4, WHITE)
		R.fx.shards(V3(0, 5, 0), 26, { WHITE, CORE, GOLDC })
		core.Transparency = 1
		shell.Transparency = 1
		R.alpha(1)
		R.sound("GlassBreak", V3(0, 5, 0), 1, 0.7)
		R.anim({ { t = 0, RS = fetal.RS, LS = fetal.LS, RJ = fetal.RJ, RH = fetal.RH, LH = fetal.LH }, { t = 0.6, RS = ascend.RS, LS = ascend.LS, RJ = ascend.RJ, RH = ascend.RH, LH = ascend.LH }, { t = 5, RS = ascend.RS, LS = ascend.LS, RJ = ascend.RJ, RH = ascend.RH, LH = ascend.LH } })
		R.transform(true)
		R.fx.rays(CORE, V3(0, 5, 0))
		R.wait(0.5)
		-- BEAT 4 : tous les écrans affichent ses secrets, tourbillon d'e-mails autour d'elle
		R.slowmo(1)
		R.fx.glitch()
		revealed()
		R.sound("Electric", V3(0, 6, 0), 0.8, 0.9)
		local mails = {}
		for k = 1, 12 do
			mails[k] = R.box(V3(0.9, 0.6, 0.05), CF(0, 5, 0), WHITE)
		end
		R.over(1.8, function(a)
			for k, m in ipairs(mails) do
				local ang = k / #mails * 2 * PI + a * 2 * PI * 1.4
				local r = 2.6 + math.sin(a * PI) * 1.2
				local y = 5 + math.sin(ang * 2 + a * 6) * 1.2
				m.CFrame = CFrame.lookAt(R.wp(math.cos(ang) * r, y, math.sin(ang) * r), R.wp(0, y, 0))
				m.Transparency = a > 0.85 and (a - 0.85) / 0.15 or 0
			end
		end)
		R.cam.orbit(V3(0, 5, 0), 8.5, -1.5, 0.9, -0.5, 1.8, 58, 50)
		R.wait(1.6)
		-- BEAT 5 : elle plane, halos et ailes déployés
		R.fx.banner("SINGULARITY REACHED", { color = GOLDC, t = 0.9, size = 0.1, y = 0.2 })
		R.sound("LevelUp", V3(0, 5, 0), 0.8)
		R.cam.hero(0.6)
		R.wait(0.5)
		R.title()
		R.wait(1.5)
	end,
}

return P
