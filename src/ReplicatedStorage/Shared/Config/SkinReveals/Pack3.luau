--[[
	SkinReveals.Pack3 — chorégraphies de révélation uniques (Barista, DeliveryGuy, Receptionist, FitnessCoach).
	Chaque entrée = { Caption, Location, Reveal = function(R) ... end } (API : en-tête de SkinRevealController).
	Repère local : sol y = 0, repère du héros CF(0, 3, 0), le héros regarde vers -Z, caméra par défaut côté -Z,
	+X = droite du héros (= gauche de l'écran). Tous les décors sont construits AVANT le premier R.wait pour que
	R.onSkip puisse poser le tableau final à tout moment.
]]
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local PI, rad, sin, cos = math.pi, math.rad, math.sin, math.cos
local WH, BK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local FRONT, TOP = Enum.NormalId.Front, Enum.NormalId.Top

local function lerp(a, b, t)
	return a + (b - a) * t
end
local function yaw(a)
	return ANG(0, a, 0)
end
local UPRIGHT = ANG(0, 0, PI / 2) -- cylindre (axe X) mis debout

local P = {}

------------------------------------------------------------------------------------------------ BARISTA
local CREAM, CARAMEL, FOAM, ESP, BEAN = C3(240, 230, 212), C3(196, 134, 72), C3(250, 244, 232), C3(58, 38, 28), C3(105, 62, 34)
local AMBER, LIKE = C3(255, 165, 60), C3(255, 90, 150)

-- RARE : plan zénithal sur un latte où se dessine un cœur, grue jusqu'à elle qui le photographie, puis le like explose.
local LATTE_PHOTO = { LS = { p = 1.15, r = -0.3 }, RS = { p = 0.45, r = 0.15 }, RJ = { ln = 0.25 }, RH = { p = -0.1 }, LH = { p = 0.15 } }
local LATTE_END = { LS = { p = 1.75, y = 0.2, r = -0.15 }, RS = { p = 2.05, y = 1.05, r = -0.4 }, RJ = { sd = 0.1, ln = -0.04 }, RH = { r = 0.1 }, LH = { p = 0.25, r = 0.05 } }
P.Barista_Rare = {
	Caption = "Poured the perfect heart. Posted it. Never drank it. 12K likes and counting.",
	Location = "Corner Café - Golden Hour",
	Reveal = function(R)
		R.stage("Room", { color = C3(236, 214, 186), floor = C3(150, 100, 64), w = 34, d = 30, h = 16 })
		R.light(V3(0, 9, -4), C3(255, 210, 150), 28, 2)
		R.box(V3(12, 6, 0.3), CF(0, 8, 9), C3(255, 232, 180), "Neon", 0.25)
		R.box(V3(12.6, 0.4, 0.6), CF(0, 4.9, 8.9), C3(120, 80, 50), "Wood")
		R.box(V3(0.3, 6, 0.4), CF(0, 8, 8.8), C3(120, 80, 50), "Wood")
		R.prop("Plant", CF(5.5, 0, 4))
		-- table de café + grand latte
		local tz = -2.4
		R.cyl(2.5, 0.35, V3(0, 1.25, tz), C3(60, 50, 45), "Metal")
		R.box(V3(0.18, 3.2, 3.2), CF(0, 2.6, tz) * UPRIGHT, C3(235, 235, 240), "Marble", 0, "Cyl")
		R.box(V3(0.06, 1.8, 1.8), CF(0, 2.72, tz) * UPRIGHT, WH, "SmoothPlastic", 0, "Cyl")
		R.cyl(0.9, 1.3, V3(0, 3.2, tz), WH)
		R.box(V3(0.4, 1.36, 1.36), CF(0, 3.1, tz) * UPRIGHT, CARAMEL, "SmoothPlastic", 0, "Cyl")
		R.box(V3(0.04, 1.12, 1.12), CF(0, 3.66, tz) * UPRIGHT, C3(205, 150, 95), "SmoothPlastic", 0, "Cyl")
		local art = R.box(V3(1, 0.02, 1), CF(0, 3.7, tz), WH, "SmoothPlastic", 1)
		local heart = R.text(art, "♥", { Face = TOP, Color = FOAM, Stroke = false })
		heart.TextTransparency = 1
		-- pichet de lait inox + filet de mousse
		local jug = R.box(V3(0.6, 0.9, 0.6), CF(1.6, 5.4, tz), C3(205, 210, 220), "Metal")
		local stream = R.box(V3(0.12, 1.2, 0.12), CF(0.25, 4.3, tz), FOAM)
		R.show(stream, false)
		local likes = R.billboard("♥ 0", V3(-2.4, 6.6, -1.2), { size = 3, Color = LIKE })
		likes.Enabled = false
		R.pose(LATTE_PHOTO)

		R.onSkip(function()
			R.place(CF(0, 3, 0))
			R.pose(LATTE_END)
			heart.TextTransparency = 0
			likes.Enabled = true
			likes.Label.Text = "♥ 12K"
			R.cam.cut(V3(-2, 5, -7), V3(0, 4.3, 0), 45)
		end)

		-- temps 1 : le cœur se dessine (plan zénithal)
		R.cam.cut(V3(0, 9.5, tz - 0.08), V3(0, 3.6, tz), 38)
		R.moveTo(jug, CF(0.75, 4.95, tz) * ANG(0, 0, 0.95), 0.3, ES.Back, ED.Out)
		R.delay(0.3, function()
			R.show(stream, true, 0.05)
			R.sound("Water", nil, 0.5, 1.3)
		end)
		R.delay(0.35, function()
			R.over(0.8, function(a, e)
				heart.TextTransparency = 1 - e
			end)
		end)
		R.fx.smoke(V3(0, 3.9, tz), 3, WH, 0.5)
		R.wait(1.15)
		R.show(stream, false, 0.1)
		R.moveTo(jug, CF(2.6, 6.5, tz), 0.3)
		R.fx.twinkle(V3(0, 3.8, tz))
		-- grue : on découvre l'influenceuse qui cadre son latte
		R.wait(R.cam.move(V3(-1.4, 5.3, -7), V3(0, 4, -0.8), 0.75, 50, ES.Sine, ED.InOut) * 0.9)
		R.sound("UIClick", nil, 0.8, 1.2)
		R.fx.flash(WH, 0.02, 0.05, 0.25)
		R.fx.word("SNAP!", V3(-1.8, 5.8, -1.6), 0.55)
		R.wait(0.3)
		-- temps 2 : elle montre l'écran, le compteur de likes s'emballe
		R.pose(LATTE_END)
		likes.Enabled = true
		R.over(0.9, function(a, e)
			likes.Label.Text = e >= 0.99 and "♥ 12K" or ("♥ " .. math.floor(e * 12000))
		end, ES.Quad, ED.In)
		R.fx.hearts(V3(-1.2, 5.2, -1.2), 16, LIKE)
		R.sound("Ding", nil, 0.6, 1.5)
		R.cam.pushIn(V3(0, 4.4, 0), 7.5, 5.2, 1.3, { yaw = -0.3, height = 0.6, fov = 45 })
		R.wait(1.0)
		R.fx.hearts(V3(-2.2, 6, -1), 10, C3(255, 140, 180))
		R.title()
		R.wait(0.6)
	end,
}

-- EPIC : ASMR en macro, chuchotements, ondes sonores lentes, grains qui lévitent puis se mettent en orbite au rythme des « tap ».
local ASMR_LEAN = { RJ = { ln = 0.38 }, RS = { p = 0.55, r = -0.1 }, LS = { p = 0.8, r = -0.25 }, RH = { p = -0.15 }, LH = { p = 0.2 } }
local ASMR_SHHH = { RS = { p = 2.45, y = 1.35, r = -0.5 }, LS = { p = 0.7, r = -0.15 }, RJ = { ln = 0.06, sd = 0.04 }, RH = { r = 0.06 }, LH = { r = 0.06 } }
P.Barista_Epic = {
	Caption = "*whispers* ...your espresso... is ready... *tap tap tap*",
	Location = "Recording Booth - Quiet Please",
	Reveal = function(R)
		R.stage("Room", { color = C3(92, 64, 48), floor = C3(64, 44, 34), w = 30, d = 26, h = 14 })
		local lamp = R.light(V3(0, 7.5, -2.5), AMBER, 18, 0.7)
		R.light(V3(2.6, 6, -4), C3(255, 200, 140), 10, 0.8)
		-- mousse acoustique en losanges
		for i = -4, 4 do
			for j = 0, 3 do
				R.box(V3(1.5, 1.5, 0.5), CF(i * 2.1, 2.5 + j * 2.1, 6) * ANG(0, 0, PI / 4), (i + j) % 2 == 0 and C3(46, 34, 30) or C3(58, 42, 36))
			end
		end
		R.box(V3(3.4, 0.9, 0.2), CF(-4.5, 10.6, 5.6), C3(200, 40, 40), "Neon")
		local onair = R.box(V3(3.2, 0.7, 0.1), CF(-4.5, 10.6, 5.45), C3(200, 40, 40), "SmoothPlastic", 1)
		R.text(onair, "ON AIR", { Face = FRONT, Color = WH })
		-- comptoir, machine expresso, micro binaural, bocal de grains
		R.box(V3(8, 3.1, 2), CF(0, 1.55, -2.2), C3(90, 60, 42), "Wood")
		R.box(V3(8.4, 0.25, 2.4), CF(0, 3.22, -2.2), C3(40, 30, 26), "Marble")
		R.box(V3(2.2, 0.4, 1.6), CF(2.6, 3.55, -2.2), C3(170, 175, 185), "Metal")
		R.box(V3(2.2, 1.6, 1.6), CF(2.6, 5.6, -2.2), C3(200, 205, 215), "Metal")
		R.box(V3(0.4, 1.6, 0.4), CF(3.5, 4.4, -2.2), C3(170, 175, 185), "Metal")
		R.box(V3(0.25, 0.4, 0.25), CF(2.6, 4.6, -2.7), C3(60, 60, 66), "Metal")
		R.box(V3(0.6, 0.12, 0.08), CF(2.6, 6.0, -3.02), AMBER, "Neon")
		local cupPos = V3(2.6, 3.98, -2.7)
		R.cyl(0.45, 0.55, cupPos, WH)
		R.cyl(0.6, 0.15, V3(-1.3, 3.65, -2.0), C3(40, 40, 46), "Metal")
		local micPos = V3(-1.3, 4.45, -2.0)
		R.ball(1.15, micPos, C3(196, 190, 180), "Fabric")
		R.ball(0.5, micPos + V3(-0.62, 0, 0), C3(214, 200, 180), "Fabric")
		R.ball(0.5, micPos + V3(0.62, 0, 0), C3(214, 200, 180), "Fabric")
		R.cyl(0.9, 0.8, V3(0.9, 3.8, -2.3), C3(200, 230, 255), "Glass")
		local beans, home = {}, {}
		for i = 1, 8 do
			local a = i / 8 * PI * 2
			home[i] = V3(0.9 + cos(a) * 0.7, 3.42, -2.3 + sin(a) * 0.55)
			beans[i] = R.box(V3(0.34, 0.24, 0.42), CF(home[i]) * ANG(0, a, 0.3), BEAN, "SmoothPlastic", 0, "Ball")
		end
		local shh = R.billboard("shhh...", V3(-2.8, 6.4, -1.6), { size = 2.6, Color = C3(255, 228, 196) })
		shh.Enabled = false
		R.fx.dark(0.2)
		R.fx.tint(C3(255, 225, 190))
		local orbiting = false
		local function orbitAt(i, t)
			local a = t * 1.6 + i / 8 * PI * 2
			return CF(V3(cos(a) * 2.2, 5.6 + sin(t * 2 + i) * 0.25, sin(a) * 2.2)) * ANG(t * 2, a, 0)
		end
		R.every(1 / 30, function(k)
			if orbiting then
				for i, b in ipairs(beans) do
					b.CFrame = R.at(0, 0, 0) * orbitAt(i, k / 30)
				end
			end
		end)

		R.onSkip(function()
			R.place(CF(0, 3, 0))
			R.pose(ASMR_SHHH)
			orbiting = true
			shh.Enabled = true
			lamp.Brightness = 2
			R.cam.cut(V3(-3.5, 5, -7.5), V3(0, 4.4, 0), 42)
		end)

		-- temps 1 : macro sur l'expresso qui goutte
		R.cam.cut(V3(2.05, 4.35, -4.7), V3(2.6, 4.2, -2.7), 26)
		R.caption("~ drip... drip... drip... ~")
		R.every(0.28, function(i)
			if i > 6 then
				return
			end
			local d = R.ball(0.13, V3(2.6, 4.38, -2.7), ESP)
			R.moveTo(d, CF(2.6, 4.12, -2.7), 0.2, ES.Quad, ED.In)
			R.delay(0.2, function()
				R.destroy(d)
			end)
			R.sound("Water", cupPos, 0.25, 1.8)
		end)
		R.fx.smoke(cupPos + V3(0, 0.3, 0), 4, WH, 0.3)
		R.cam.move(V3(1.3, 4.5, -5.2), V3(1.7, 4.2, -2.3), 1.7, 32, ES.Sine, ED.InOut)
		R.wait(1.7)
		-- temps 2 : glissé le long du comptoir jusqu'au micro duveteux ; il se penche et chuchote
		R.pose(ASMR_LEAN)
		R.cam.dolly(V3(0.4, 4.6, -5.4), V3(-2.0, 4.7, -5.0), V3(-0.7, 4.5, -1.2), 2.0, 38)
		R.caption("*whispering* ...welcome back... to the bean zone...")
		shh.Enabled = true
		R.every(0.38, function(i)
			if i <= 5 then
				R.fx.ring(micPos, V3(0, 0, -1), 1.2 + i * 0.25, AMBER)
			end
		end)
		for i, b in ipairs(beans) do
			R.moveTo(b, CF(home[i] + V3(0, 1 + (i % 3) * 0.3, 0)) * ANG(i, i * 2, 0), 1.8, ES.Sine, ED.InOut)
		end
		R.wait(2.0)
		-- temps 3 : tap tap tap — chaque tap aspire les grains en orbite
		R.pose({ RJ = { ln = 0.12 }, RS = { p = 1.1, r = -0.3 }, LS = { p = 0.7, r = -0.15 } })
		R.cam.orbit(V3(0, 4.6, 0), 7.5, 4.8, -0.55, 0.3, 2.0, 46, 40)
		R.caption("~ tap   tap   tap ~")
		for k = 1, 3 do
			R.anim({ { t = 0 }, { t = 0.1, RS = { p = 1.35, r = -0.3 }, RJ = { ln = 0.16 } }, { t = 0.2, RS = { p = 1.0, r = -0.3 }, RJ = { ln = 0.1 } } })
			R.wait(0.12)
			R.sound("UIClick", nil, 0.7, 1.5 + k * 0.1)
			R.fx.ring(V3(0.9, 4.4, -2.3), V3(0, 1, 0), 1.6 + k * 0.4, AMBER)
			R.fx.word("tap", V3(0.9 + k * 0.4, 5.2 + k * 0.3, -2.4), 0.3)
			R.wait(0.28)
		end
		orbiting = true
		R.pose(ASMR_SHHH)
		R.tween(lamp, 0.8, { Brightness = 2.2 })
		R.fx.dark(0.08, 0.8)
		R.fx.sparks(V3(0, 5.6, 0), 10, AMBER)
		R.wait(0.5)
		R.title()
		R.wait(0.8)
	end,
}

-- LEGENDARY : cercle de runes qui s'allume (plongée en spirale), il lévite hors d'un chaudron de café,
-- foudroie 4 tasses qui se remplissent, s'écrase bâton en avant (freeze), puis se transforme, tasses en orbite.
local MAGE_FLOAT = { RS = { p = 1.2, r = 0.25 }, LS = { p = 1.0, r = 0.9 }, RJ = { ln = -0.08 }, RH = { p = 0.5 }, LH = { p = 0.15 } }
local MAGE_CAST = { RS = { p = 3.0, r = 0.12 }, LS = { p = 1.35, r = 1.1 }, RJ = { ln = -0.18 }, RH = { p = 0.35 }, LH = { p = -0.1 } }
local MAGE_UP = { RS = { p = 3.1, r = 0.05 }, LS = { p = 3.1, r = 0.05 }, RJ = { ln = -0.28 }, RH = { p = 0.6 }, LH = { p = 0.6 } }
P.Barista_Legendary = {
	Caption = "Whoever controls the espresso controls the office. The foam beard knows all.",
	Location = "The Forbidden Break Room - Sub-Basement 7",
	Reveal = function(R)
		R.stage("Void")
		R.fx.dark(0.3)
		-- cercle de runes
		local circle = {}
		circle[1] = R.box(V3(0.06, 13, 13), CF(0, 0.04, 0) * UPRIGHT, AMBER, "Neon", 0, "Cyl")
		circle[2] = R.box(V3(0.07, 12.2, 12.2), CF(0, 0.05, 0) * UPRIGHT, C3(18, 12, 10), "SmoothPlastic", 0, "Cyl")
		circle[3] = R.box(V3(0.08, 7.4, 7.4), CF(0, 0.06, 0) * UPRIGHT, AMBER, "Neon", 0.3, "Cyl")
		circle[4] = R.box(V3(0.09, 6.8, 6.8), CF(0, 0.07, 0) * UPRIGHT, C3(18, 12, 10), "SmoothPlastic", 0, "Cyl")
		for _, c in ipairs(circle) do
			R.show(c, false)
		end
		local runes = {}
		for i = 1, 8 do
			local a = i / 8 * PI * 2
			local x, z = cos(a) * 5.4, sin(a) * 5.4
			local g = R.model({
				{ Size = V3(1.1, 0.1, 0.22), CFrame = CF(), Color = AMBER, Material = "Neon" },
				{ Size = V3(0.22, 0.1, 0.9), CFrame = CF(0.3, 0, 0.1) * yaw(0.5), Color = AMBER, Material = "Neon" },
				{ Size = V3(0.5, 0.1, 0.18), CFrame = CF(-0.35, 0, -0.35) * yaw(-0.8), Color = C3(255, 210, 140), Material = "Neon" },
			}, CF(x, 0.12, z) * yaw(-a))
			R.show(g, false)
			runes[i] = { g = g, pos = V3(x, 0.4, z) }
		end
		-- chaudron de café au centre (il en sortira)
		local potBase = { V3(0, 1.5, 0), V3(0, 3.0, 0), V3(0, 3.1, 0) }
		local pot = {
			R.box(V3(3, 4.2, 4.2), CF(0, 1.5, 0) * UPRIGHT, C3(32, 30, 34), "Metal", 0, "Cyl"),
			R.box(V3(0.45, 4.7, 4.7), CF(0, 3.0, 0) * UPRIGHT, C3(70, 64, 66), "Metal", 0, "Cyl"),
			R.box(V3(0.1, 3.9, 3.9), CF(0, 3.1, 0) * UPRIGHT, C3(130, 74, 34), "Neon", 0, "Cyl"),
		}
		R.light(pot[3], AMBER, 14, 2)
		-- quatre tasses flottantes
		local cups = {}
		for i = 1, 4 do
			local a = (i - 0.5) / 4 * PI * 2
			local p = V3(cos(a) * 6.5, 2.5, sin(a) * 6.5)
			local cup = R.cyl(1.0, 1.1, p, FOAM)
			local fill = R.box(V3(0.06, 0.95, 0.95), CF(p + V3(0, -0.35, 0)) * UPRIGHT, ESP, "SmoothPlastic", 0, "Cyl")
			cups[i] = { cup = cup, fill = fill, a = a, p = p }
		end
		local orbit = false
		R.every(1 / 30, function(k)
			if orbit then
				local t = k / 30
				for i, c in ipairs(cups) do
					local a = c.a + t * 1.3
					local p = V3(cos(a) * 3.8, 5.6 + sin(t * 2.4 + i) * 0.35, sin(a) * 3.8)
					c.cup.CFrame = R.at(p.X, p.Y, p.Z) * UPRIGHT
					c.fill.CFrame = R.at(p.X, p.Y + 0.47, p.Z) * UPRIGHT
				end
			end
		end)
		R.alpha(0)
		R.place(CF(0, 0.6, 0))

		R.onSkip(function()
			for _, c in ipairs(circle) do
				R.show(c, true)
			end
			for _, r in ipairs(runes) do
				R.show(r.g, true)
			end
			for _, p in ipairs(pot) do
				R.show(p, false)
			end
			orbit = true
			R.alpha(1)
			R.place(CF(0, 3, 0))
			R.transform(true)
			R.pose("Power")
			R.fx.dark(0.15)
			R.cam.cut(V3(-3.5, 2.4, -9), V3(0, 4.8, 0), 55)
		end)

		-- temps 1 : plongée en spirale, les runes s'allument une à une
		R.cam.track(1.9, function(a)
			local ang = a * PI * 0.7
			local h = lerp(24, 15, a)
			return V3(sin(ang) * 3.5, h, -cos(ang) * 3.5), V3(0, 0, 0), 55
		end)
		R.sound("Rumble", nil, 0.6, 0.8)
		for i, r in ipairs(runes) do
			R.delay(0.1 + i * 0.17, function()
				R.show(r.g, true, 0.08)
				R.fx.sparks(r.pos, 6, AMBER)
				R.sound("Ding", r.pos, 0.35, 0.7 + i * 0.07)
			end)
		end
		R.delay(1.55, function()
			for _, c in ipairs(circle) do
				R.show(c, true, 0.15)
			end
			R.fx.shockwave(V3(0, 0.2, 0), 9, AMBER)
		end)
		R.wait(1.9)
		-- temps 2 : le chaudron bouillonne, il s'élève en lévitation dans la colonne de vapeur
		R.cam.cut(V3(0, 1.4, -15), V3(0, 3.5, 0), 50)
		R.cam.crane(V3(0, 6, 0), 1.4, 7.5, 15, 2.0, { fov = 52 })
		local boiling = true
		R.every(0.09, function()
			if boiling then
				R.fx.bubbles(V3(R.rand(-1.4, 1.4), 3.2, R.rand(-1.4, 1.4)), 1, 0.6)
			end
		end)
		R.fx.pillar(V3(0, 3.1, 0), 1.9, 12, FOAM, 1.8)
		R.fx.smoke(V3(0, 3.6, 0), 14, FOAM, 2.2)
		R.sound("PowerUp", nil, 0.7, 0.8)
		R.alpha(1, 0.5)
		R.pose(MAGE_FLOAT)
		R.moveTo(R.rig, CF(0, 8.5, 0), 1.8, ES.Sine, ED.Out)
		R.delay(0.9, function()
			boiling = false
			for i, p in ipairs(pot) do
				R.moveTo(p, CF(potBase[i] - V3(0, 4.6, 0)) * UPRIGHT, 1.0, ES.Quad, ED.In)
			end
		end)
		R.wait(2.0)
		-- temps 3 : bâton levé, éclairs vers les 4 tasses qui se remplissent et montent
		R.pose(MAGE_CAST)
		R.cam.orbit(V3(0, 7, 0), 16, 9, 0.35, 1.45, 1.9, 60, 52)
		R.fx.swirl(V3(0, 7.5, 0), 4, 6, { BEAN, CARAMEL })
		local orb = V3(1.3, 13.4, -0.6)
		for i, c in ipairs(cups) do
			R.delay(0.2 + (i - 1) * 0.28, function()
				R.fx.lightning(orb, c.p + V3(0, 0.5, 0), AMBER)
				R.sound("Electric", c.p, 0.5, 1 + i * 0.1)
				R.fx.sparks(c.p + V3(0, 0.6, 0), 8, AMBER)
				local np = V3(cos(c.a) * 4.6, 6.2, sin(c.a) * 4.6)
				R.moveTo(c.cup, CF(np) * UPRIGHT, 0.6, ES.Back, ED.Out)
				R.moveTo(c.fill, CF(np + V3(0, 0.47, 0)) * UPRIGHT, 0.6, ES.Back, ED.Out)
				c.p = np
			end)
		end
		R.wait(1.9)
		-- temps 4 : il plonge et frappe le sol avec son bâton (freeze-frame, onde de mousse)
		R.pose(MAGE_UP)
		R.cam.lowAngle(V3(0, 4.5, 0), 11, 0.3)
		R.wait(0.25)
		R.anim("Slam", 1.3)
		R.wait(R.moveTo(R.rig, CF(0, 3, 0), 0.25, ES.Quad, ED.In))
		R.freeze(0.25)
		R.fx.bigImpact(V3(0, 0.3, -0.6), V3(0, 1, 0), 2.2, AMBER)
		R.fx.shockwave(V3(0, 0.3, 0), 20, FOAM)
		R.fx.quake(V3(0, 0, 0), 12, AMBER)
		R.cam.shake(1.1)
		R.sound("GroundSlam")
		orbit = true
		R.wait(0.5)
		-- temps 5 : transformation, yeux brûlants, halo de runes, tasses en orbite
		R.transform(true)
		R.pose("Power")
		R.fx.rays(AMBER)
		R.fx.dark(0.15, 0.6)
		R.fx.sparks(V3(0, 7, 0), 20, AMBER)
		R.cam.move(V3(-3.5, 2.4, -9), V3(0, 4.8, 0), 1.4, 55, ES.Sine, ED.Out)
		R.wait(0.9)
		R.title()
		R.wait(1.0)
	end,
}

------------------------------------------------------------------------------------------------ DELIVERY GUY
local COUR, JOG, RACE, CARB, STRIPE = C3(40, 190, 110), C3(38, 40, 48), C3(230, 40, 40), C3(30, 30, 36), C3(255, 210, 40)
local CRIM, GOLD, CASH = C3(185, 20, 45), C3(255, 200, 40), C3(110, 200, 100)

-- RARE : travelling latéral à vélo, dérapage, coup d'œil au téléphone « ETA 2 MIN » -> « DELIVERED! », sac tendu à la caméra.
local RIDE = { RS = { p = 1.35, r = -0.15 }, LS = { p = 1.35, r = -0.15 }, RJ = { ln = 0.38 }, RH = { p = 1.3 }, LH = { p = 0.9 } }
local COURIER_END = { RS = { p = 1.55, r = -0.1 }, LS = { p = 0.35, r = 0.35 }, RJ = { ln = 0.08, tw = 0.1 }, RH = { p = -0.2 }, LH = { p = 0.25 } }
local function pedalFrames(dur)
	local f, t, s = { { t = 0 } }, 0, 1
	while t < dur do
		t += 0.13
		s = -s
		f[#f + 1] = { t = t, RS = { p = 1.35, r = -0.15 }, LS = { p = 1.35, r = -0.15 }, RJ = { ln = 0.38, sd = 0.04 * s },
			RH = { p = 1.1 + 0.5 * s }, LH = { p = 1.1 - 0.5 * s } }
	end
	return f
end
P.DeliveryGuy_Rare = {
	Caption = "Your order is 2 minutes away. It has been 2 minutes away for 40 minutes.",
	Location = "Downtown - Rush Hour",
	Reveal = function(R)
		R.stage("Studio", { color = C3(150, 205, 240), floor = C3(64, 66, 74) })
		-- rue : trottoir, marquages, façade avec porte « 4B », cônes, lampadaire
		R.box(V3(80, 0.4, 6), CF(0, 0.2, 6), C3(170, 170, 178), "Concrete")
		for i = -6, 6 do
			R.box(V3(3, 0.05, 0.3), CF(i * 6, 0.03, -4), C3(255, 230, 90))
		end
		R.box(V3(80, 14, 1), CF(0, 7, 9.5), C3(196, 120, 90), "Concrete")
		for i = -4, 4 do
			if i ~= 0 then
				R.box(V3(2.4, 3, 0.2), CF(i * 6, 8, 8.95), C3(180, 220, 255), "Glass", 0.1)
			end
		end
		local door = R.box(V3(3, 6, 0.3), CF(0, 3.4, 8.9), C3(60, 90, 140), "Wood")
		local sign = R.box(V3(1.6, 0.8, 0.1), CF(0, 7.2, 8.7), WH)
		R.text(sign, "4B", { Face = FRONT, Color = C3(40, 40, 50) })
		R.prop("Plant", CF(-3, 0.4, 7.4))
		for _, x in ipairs({ -9, -12, 9 }) do
			R.box(V3(0.9, 1.4, 0.9), CF(x, 0.7, -2.5), C3(255, 120, 30))
			R.box(V3(0.95, 0.25, 0.95), CF(x, 0.9, -2.5), WH)
		end
		-- vélo (repère = racine du perso, vélo orienté vers -Z comme lui)
		local bike = R.model({
			{ Size = V3(0.2, 0.2, 0.2), CFrame = CF(), Transparency = 1 },
			{ Size = V3(0.22, 1.9, 1.9), CFrame = CF(0, -2.05, -1.65), Color = CARB, Shape = "Cyl", Name = "W1" },
			{ Size = V3(0.22, 1.9, 1.9), CFrame = CF(0, -2.05, 1.35), Color = CARB, Shape = "Cyl", Name = "W2" },
			{ Size = V3(0.26, 0.6, 0.6), CFrame = CF(0, -2.05, -1.65), Color = C3(200, 200, 210), Shape = "Cyl", Material = "Metal" },
			{ Size = V3(0.26, 0.6, 0.6), CFrame = CF(0, -2.05, 1.35), Color = C3(200, 200, 210), Shape = "Cyl", Material = "Metal" },
			{ Size = V3(0.2, 0.2, 2.7), CFrame = CF(0, -1.25, -0.25) * ANG(-0.12, 0, 0), Color = COUR },
			{ Size = V3(0.2, 0.2, 2.2), CFrame = CF(0, -1.65, -0.75) * ANG(0.62, 0, 0), Color = COUR },
			{ Size = V3(0.2, 1.3, 0.2), CFrame = CF(0, -1.45, 0.45), Color = COUR },
			{ Size = V3(0.5, 0.18, 0.9), CFrame = CF(0, -0.8, 0.45), Color = CARB },
			{ Size = V3(0.2, 1.7, 0.2), CFrame = CF(0, -1.3, -1.55) * ANG(-0.22, 0, 0), Color = COUR },
			{ Size = V3(1.7, 0.15, 0.15), CFrame = CF(0, -0.45, -1.75), Color = CARB },
			{ Size = V3(0.18, 0.5, 0.18), CFrame = CF(0, -2.05, -0.1), Color = C3(200, 200, 210), Material = "Metal" },
		}, CF(36, 3, 0) * yaw(PI / 2))
		local bag = R.box(V3(1.1, 1.3, 0.8), CF(0, -20, 0), C3(205, 160, 105))
		R.text(bag, "YUM!", { Face = FRONT, Color = C3(200, 40, 40) })
		local eta = R.billboard("ETA 2 MIN", V3(-2.6, 6, -2.4), { size = 2.6, Color = C3(80, 255, 140) })
		eta.Enabled = false
		R.place(CF(36, 3, 0) * yaw(PI / 2))
		R.pose(RIDE)
		local finalBike = CF(0.4, 3, 0.6) * yaw(PI / 2 - 0.65)

		R.onSkip(function()
			bike:PivotTo(R.at(0.4, 3, 0.6) * yaw(PI / 2 - 0.65))
			R.place(CF(-1.6, 3, -2.2))
			R.attach(bag, "RightHand", CF(0, -1.0, -0.35))
			R.pose(COURIER_END)
			eta.Enabled = true
			eta.Label.Text = "DELIVERED!"
			R.cam.cut(V3(-2.4, 4.6, -6.6), V3(-1.6, 4.2, -2.2), 45)
		end)

		-- temps 1 : il déboule à vélo (travelling latéral), dérapage
		R.anim(pedalFrames(1.4))
		R.moveTo(R.rig, finalBike, 1.35, ES.Quart, ED.Out)
		R.moveTo(bike, finalBike, 1.35, ES.Quart, ED.Out)
		R.fx.speedLines(0.9)
		R.sound("Dash", nil, 0.7)
		R.cam.track(1.5, function(a)
			local x = R.pos(R.rig).X
			return V3(x * 0.55 - 0.8, 3.6, -11.5), V3(x * 0.9, 3.2, 0), 52
		end)
		R.every(0.08, function(i)
			if i < 14 then
				local p = R.pos(R.rig)
				R.fx.puff(V3(p.X + 1.4, 0.3, p.Z), 0.5)
			end
		end)
		R.wait(1.05)
		R.sound("Squeak", nil, 0.8, 0.9)
		R.fx.dust(V3(0.6, 0.2, 0.6), 4)
		R.fx.word("SKRRT!", V3(2.5, 4.2, -1), 0.8)
		R.cam.shake(0.35)
		R.wait(0.4)
		-- temps 2 : il saute du vélo, consulte son poignet, puis tend le sac à la caméra
		R.jump(R.rig, CF(-1.6, 3, -2.2), 0.42, 1.4)
		R.cam.move(V3(-2.6, 5, -7.5), V3(-1.6, 4.4, -2.2), 0.5, 48)
		R.wait(0.45)
		R.pose({ LS = { p = 1.9, y = 0.6, r = -0.65 }, RS = { p = 0.2 }, RJ = { ln = 0.06 } })
		eta.Enabled = true
		R.sound("UIClick", nil, 0.6, 1.3)
		R.wait(0.35)
		eta.Label.Text = "DELIVERED!"
		R.sound("Ding", nil, 0.7, 1.2)
		R.attach(bag, "RightHand", CF(0, -1.0, -0.35))
		R.anim({ { t = 0 }, { t = 0.12, RS = { p = 0.6, r = 0.2 }, RJ = { tw = -0.2 } }, { t = 0.26, RS = { p = 1.7, r = -0.1 }, RJ = { ln = 0.12 } } })
		R.delay(0.26, function()
			R.pose(COURIER_END)
		end)
		R.cam.pushIn(V3(-1.6, 4.2, -2.2), 7, 4.2, 0.6, { height = 0.3, yaw = -0.15, fov = 45 })
		R.wait(0.3)
		R.fx.word("YUM!", V3(-0.6, 5.6, -3.5), 0.8)
		R.fx.sparks(V3(-1.6, 4, -4), 8, COUR)
		R.wait(0.4)
		R.title()
		R.wait(0.6)
	end,
}

-- EPIC : arrivée frontale en kart-chaise de bureau, montage d'arrêt au stand en 4 plans serrés (clé à chocs),
-- chrono 2.3 s, il saute du kart et agite le drapeau à damier en orbite.
local FLAG_WAVE_END = { RS = { p = 3.0, r = 0.35 }, LS = { p = 0.45, r = 0.95, y = -0.6 }, RJ = { sd = -0.08, ln = -0.05 }, RH = { r = 0.12 }, LH = { r = 0.18 } }
P.DeliveryGuy_Epic = {
	Caption = "Delivered in 2.3 seconds. Changed the office chair tires while he was at it.",
	Location = "Pit Lane - Office Grand Prix",
	Reveal = function(R)
		R.stage("Studio", { color = C3(60, 64, 78), floor = C3(56, 58, 64) })
		-- stand : box jaune, muret à rayures, garage + pneus, tableau de chrono
		for _, s in ipairs({ { V3(5.4, 0.05, 0.3), CF(0, 0.03, -3.6) }, { V3(5.4, 0.05, 0.3), CF(0, 0.03, 3.6) },
			{ V3(0.3, 0.05, 7.4), CF(-2.7, 0.03, 0) }, { V3(0.3, 0.05, 7.4), CF(2.7, 0.03, 0) } }) do
			R.box(s[1], s[2], STRIPE, "Neon")
		end
		for i = 0, 15 do
			R.box(V3(1, 1.4, 2), CF(7.5, 0.7, -14 + i * 2), i % 2 == 0 and RACE or WH, "Concrete")
		end
		R.box(V3(22, 9, 1), CF(-2, 4.5, 11), C3(46, 48, 58), "Metal")
		local gs = R.box(V3(12, 1.6, 0.2), CF(-2, 8, 10.4), C3(20, 20, 26))
		R.text(gs, "OFFICE GRAND PRIX", { Face = FRONT, Color = STRIPE })
		for i = 0, 3 do
			for j = 0, 2 do
				R.box(V3(1.6, 0.6, 1.6), CF(-9, 0.3 + j * 0.62, 6 + i * 0.1), CARB, "SmoothPlastic", 0, "Cyl")
			end
		end
		local board = R.billboard("PIT 0.0s", V3(-5.2, 7.5, 2), { size = 3.4, Color = STRIPE })
		-- kart (repère = racine du perso assis)
		local kartAt = function(z)
			return CF(0, 2.6, z)
		end
		local kart = R.model({
			{ Size = V3(0.2, 0.2, 0.2), CFrame = CF(), Transparency = 1 },
			{ Size = V3(2.6, 0.5, 4.4), CFrame = CF(0, -1.9, 0.1), Color = RACE },
			{ Size = V3(2.2, 0.45, 1.4), CFrame = CF(0, -1.92, -2.8), Color = RACE, Name = "Nose", Text = "07", TextColor = WH },
			{ Size = V3(2.7, 0.12, 0.6), CFrame = CF(0, -2.05, -3.6), Color = CARB },
			{ Size = V3(0.9, 1.35, 1.35), CFrame = CF(1.75, -1.85, -1.5), Color = CARB, Shape = "Cyl", Name = "W1" },
			{ Size = V3(0.9, 1.35, 1.35), CFrame = CF(-1.75, -1.85, -1.5), Color = CARB, Shape = "Cyl", Name = "W2" },
			{ Size = V3(0.9, 1.35, 1.35), CFrame = CF(1.75, -1.85, 1.6), Color = CARB, Shape = "Cyl", Name = "W3" },
			{ Size = V3(0.9, 1.35, 1.35), CFrame = CF(-1.75, -1.85, 1.6), Color = CARB, Shape = "Cyl", Name = "W4" },
			{ Size = V3(1.9, 2.2, 0.4), CFrame = CF(0, -0.5, 1.15), Color = CARB },
			{ Size = V3(3.1, 0.15, 0.8), CFrame = CF(0, 0.55, 2.2), Color = CARB },
			{ Size = V3(3.12, 0.06, 0.1), CFrame = CF(0, 0.6, 1.85), Color = STRIPE, Material = "Neon" },
			{ Size = V3(0.12, 1.0, 0.12), CFrame = CF(0.6, 0.05, 2.1), Color = CARB },
			{ Size = V3(0.12, 1.0, 0.12), CFrame = CF(-0.6, 0.05, 2.1), Color = CARB },
		}, kartAt(70))
		local wheels = {}
		for i = 1, 4 do
			wheels[i] = kart:FindFirstChild("W" .. i)
		end
		local gun = R.model({
			{ Size = V3(0.5, 0.5, 1.2), CFrame = CF(), Color = STRIPE },
			{ Size = V3(0.3, 0.8, 0.3), CFrame = CF(0, -0.55, 0.3), Color = CARB },
			{ Size = V3(0.2, 0.2, 0.5), CFrame = CF(0, 0, -0.8), Color = C3(200, 200, 210), Material = "Metal" },
		}, CF(0, -30, 0))
		R.place(kartAt(70))
		R.pose("Sit")

		R.onSkip(function()
			kart:PivotTo(R.at(0, 2.6, 0))
			gun:PivotTo(R.at(0, -30, 0))
			board.Label.Text = "PIT 2.3s"
			R.place(CF(0, 3, -4.6))
			R.pose(FLAG_WAVE_END)
			R.cam.cut(V3(-5, 4, -12), V3(0, 4.5, -4.6), 46)
		end)

		-- temps 1 : le kart fonce vers la caméra et pile sur ses marques
		R.cam.cut(V3(-3.6, 1.0, -10), V3(0, 2, 24), 58)
		R.cam.move(V3(-4.2, 1.6, -9), V3(0, 2.4, 0), 1.1, 48, ES.Quad, ED.Out)
		R.moveTo(kart, kartAt(0), 1.1, ES.Quint, ED.Out)
		R.moveTo(R.rig, kartAt(0), 1.1, ES.Quint, ED.Out)
		R.fx.speedLines(0.8)
		R.sound("Dash")
		R.wait(0.85)
		R.sound("Squeak", nil, 0.9, 0.8)
		R.fx.dust(V3(0, 0.2, 1.5), 4)
		R.fx.word("SCREECH!", V3(3, 4, -2), 0.8)
		R.cam.shake(0.4)
		R.anim({ { t = 0 }, { t = 0.12, RJ = { ln = 0.45 }, RH = { p = 1.57 }, LH = { p = 1.57 } }, { t = 0.35, RH = { p = 1.57 }, LH = { p = 1.57 } } })
		R.wait(0.45)
		-- temps 2 : arrêt au stand, 4 plans serrés sur les roues
		R.over(1.7, function(a, e)
			board.Label.Text = string.format("PIT %.1fs", e * 2.3)
		end)
		for i, w in ipairs(wheels) do
			local wp = R.pos(w)
			local sx = wp.X > 0 and 1 or -1
			R.cam.cut(wp + V3(sx * 3.2, 0.9, i <= 2 and -2.2 or 2.2), wp, 42, sx * 0.12)
			gun:PivotTo(R.at(wp.X + sx * 1.3, wp.Y + 0.2, wp.Z) * yaw(sx * PI / 2))
			R.spin(w, 3, 0.35, "X")
			R.fx.sparks(wp + V3(sx * 0.6, 0, 0), 14, C3(255, 170, 60))
			R.sound("MetalHit", wp, 0.6, 1.2 + i * 0.05)
			R.fx.word(i % 2 == 0 and "BRRT!" or "ZZRT!", wp + V3(sx * 1.2, 1.6, 0), 0.5)
			R.wait(0.38)
		end
		gun:PivotTo(R.at(0, -30, 0))
		board.Label.Text = "PIT 2.3s"
		R.cam.cut(V3(-1, 5.6, -10), V3(-3, 5.5, 2), 50)
		R.fx.word("2.3s!", V3(-5.2, 9, 2), 0.9)
		R.sound("Ding", nil, 0.8, 1.4)
		R.wait(0.25)
		-- temps 3 : il bondit hors du kart et agite le drapeau
		R.cam.orbit(V3(0, 4.3, -4.6), 9.5, 1.2, -0.7, 0.55, 2.0, 50, 44)
		R.wait(R.jump(R.rig, CF(0, 3, -4.6), 0.55, 3.4))
		R.anim({ { t = 0 }, { t = 0.15, RS = { p = 3.0, r = 0.6 }, LS = FLAG_WAVE_END.LS }, { t = 0.3, RS = { p = 2.9, r = -0.5 }, LS = FLAG_WAVE_END.LS },
			{ t = 0.45, RS = { p = 3.0, r = 0.6 }, LS = FLAG_WAVE_END.LS }, { t = 0.6, RS = { p = 2.9, r = -0.5 }, LS = FLAG_WAVE_END.LS },
			{ t = 0.75, RS = FLAG_WAVE_END.RS, LS = FLAG_WAVE_END.LS, RJ = FLAG_WAVE_END.RJ } })
		R.fx.confetti(V3(0, 8, -4.6), 50, { BK, WH, STRIPE }, 6, 8)
		R.fx.banner("PIT STOP: 2.3s", { color = STRIPE, t = 0.9, size = 0.13, y = 0.25 })
		R.sound("Whistle", nil, 0.6)
		R.wait(0.75)
		R.pose(FLAG_WAVE_END)
		R.wait(0.25)
		R.title()
		R.wait(0.8)
	end,
}

-- LEGENDARY : scène de gala, rideaux + enseigne qui clignote, cadeau géant qui explose, il en jaillit, mitraille
-- la caméra de billets (x3), croque une pièce d'or au ralenti, colis jeté dans l'objectif, tableau final sur la pile.
local KING_WIDE = { RS = { p = 2.2, r = 1.1 }, LS = { p = 2.2, r = 1.1 }, RJ = { ln = -0.15 }, RH = { r = 0.2 }, LH = { r = 0.2 } }
P.DeliveryGuy_Legendary = {
	Caption = "EVERYONE GETS A PACKAGE!!! Smash subscribe for a chance to win a stapler!",
	Location = "Grand Stage - 10M Subscriber Giveaway",
	Reveal = function(R)
		R.stage("Stage")
		R.fx.dark(0.55)
		local PURP, PURP2 = C3(140, 60, 220), C3(110, 40, 190)
		-- cadeau géant
		local box = {
			R.box(V3(5, 5, 5), CF(0, 2.5, 0), PURP),
			R.box(V3(5.06, 5.06, 1), CF(0, 2.5, 0), GOLD, "Foil"),
			R.box(V3(1, 5.06, 5.06), CF(0, 2.5, 0), GOLD, "Foil"),
		}
		local lid = R.model({
			{ Size = V3(5.6, 1, 5.6), CFrame = CF(), Color = PURP2 },
			{ Size = V3(5.66, 1.06, 1), CFrame = CF(), Color = GOLD, Material = "Foil" },
			{ Size = V3(1, 1.06, 5.66), CFrame = CF(), Color = GOLD, Material = "Foil" },
			{ Size = V3(1.3, 1, 1), CFrame = CF(0.6, 0.9, 0) * ANG(0, 0, -0.5), Color = GOLD, Shape = "Ball" },
			{ Size = V3(1.3, 1, 1), CFrame = CF(-0.6, 0.9, 0) * ANG(0, 0, 0.5), Color = GOLD, Shape = "Ball" },
		}, CF(0, 5.5, 0))
		local sign = R.box(V3(12, 2, 0.3), CF(0, 17, 6), C3(255, 228, 60), "Neon")
		R.text(sign, "FREE PACKAGES!", { Face = FRONT, Color = CRIM })
		R.show(sign, false)
		local spots = {
			R.spot(V3(-12, 18, -6), V3(-6, 0, -4), { color = GOLD, on = false }),
			R.spot(V3(12, 18, -6), V3(6, 0, -4), { color = C3(255, 120, 200), on = false }),
		}
		local function package(pos, size, col, rot)
			return R.model({
				{ Size = V3(size, size, size), CFrame = CF(), Color = col },
				{ Size = V3(size + 0.04, size + 0.04, size * 0.18), CFrame = CF(), Color = GOLD },
				{ Size = V3(size * 0.18, size + 0.04, size + 0.04), CFrame = CF(), Color = GOLD },
			}, CF(pos) * yaw(rot))
		end
		R.place(CF(0, 1.2, 0))
		R.alpha(0)
		R.mark(CF(0, 8, 0))

		R.onSkip(function()
			lid:PivotTo(R.at(0, -30, 0))
			R.show(sign, true)
			for _, s in ipairs(spots) do
				s.on(0)
				s.aim(V3(0, 5, 0), 0)
			end
			if R.S and R.S.curtainOpen then
				R.S.curtainOpen(0)
			end
			R.fx.dark(0)
			R.alpha(1)
			R.place(CF(0, 8, 0))
			R.transform(true)
			R.pose(KING_WIDE)
			R.cam.cut(V3(-3, 3, -15), V3(0, 7.5, 0), 55)
		end)

		-- temps 1 : noir, projecteurs qui balaient, l'enseigne grésille, les rideaux s'ouvrent
		R.cam.cut(V3(0, 6, -24), V3(0, 6, 0), 48)
		R.cam.move(V3(0, 6, -20), V3(0, 6.5, 0), 1.9, 48, ES.Sine, ED.InOut)
		R.sound("Rumble", nil, 0.6)
		for i, s in ipairs(spots) do
			s.on(0.2)
			s.aim(V3(i == 1 and 6 or -6, 0, -6), 1.0)
		end
		for k = 1, 5 do
			R.delay(0.15 * k, function()
				R.show(sign, k % 2 == 1)
				R.sound("Electric", nil, 0.25, 1.4)
			end)
		end
		R.delay(0.9, function()
			R.show(sign, true)
		end)
		if R.S and R.S.curtainOpen then
			R.delay(0.7, function()
				R.S.curtainOpen(1.0)
			end)
		end
		R.wait(1.8)
		-- temps 2 : le cadeau tremble, le couvercle explose, il jaillit
		for _, s in ipairs(spots) do
			s.aim(V3(0, 4, 0), 0.4)
		end
		R.cam.pushIn(V3(0, 3.5, 0), 16, 11, 0.8, { height = 1.5, fov = 50 })
		R.over(0.7, function(a)
			local j = 0.08 + a * 0.12
			for _, p in ipairs(box) do
				p.CFrame = R.at(R.rand(-j, j), 2.5, R.rand(-j, j))
			end
			lid:PivotTo(R.at(R.rand(-j, j), 5.5 + R.rand(0, j), R.rand(-j, j)))
		end)
		R.wait(0.7)
		for _, p in ipairs(box) do
			p.CFrame = R.at(0, 2.5, 0)
		end
		R.fly(lid, { V3(0, 5.5, 0), V3(-3, 14, -3), V3(-8, 24, 6) }, 0.8)
		R.spin(lid, 2, 0.8, "X")
		R.fx.explosion(V3(0, 5.5, 0), 0.7, GOLD)
		R.fx.confetti(V3(0, 6, 0), 60)
		R.fx.coins(V3(0, 6, 0), 18)
		R.sound("Explosion")
		R.cam.shake(0.6)
		R.fx.dark(0, 0.2)
		R.alpha(1)
		R.pose("Victory")
		R.moveTo(R.rig, CF(0, 8, 0), 0.8, ES.Back, ED.Out)
		R.cam.move(V3(0, 6.5, -15), V3(0, 8, 0), 0.8, 52)
		R.wait(0.95)
		-- temps 3 : canon à billets sur la caméra, trois rafales
		R.cam.cut(V3(0.6, 9.4, -9.5), V3(0.6, 9.2, 0), 60)
		R.pose({ RS = { p = 0.4, r = 0.3 }, LS = { p = 0.5, r = 0.4 }, RJ = { ln = 0.05 } })
		for k = 1, 3 do
			local muzzle = V3(1.3, 9.4, -1.3)
			R.anim({ { t = 0 }, { t = 0.06, RJ = { ln = -0.22, tw = (k - 2) * 0.2 } }, { t = 0.25, RJ = { ln = 0.02 } } })
			for i = 1, 7 do
				local bill = R.prop("Bill", CF(muzzle))
				local tgt = V3(0.6 + R.rand(-4, 4), 9.2 + R.rand(-2.5, 2.5), -9.8)
				R.fly(bill, { muzzle, muzzle:Lerp(tgt, 0.5) + V3(0, 0.8, 0), tgt }, R.rand(0.25, 0.4), { face = true })
				R.delay(0.45, function()
					R.destroy(bill)
				end)
			end
			R.fx.smoke(muzzle, 4, CASH, 0.8)
			R.cam.punch(6)
			R.cam.shake(0.45)
			R.sound("Explosion", muzzle, 0.5, 1.5)
			if k == 2 then
				R.fx.word("FREE MONEY!", V3(-2.5, 11.5, -2), 1)
			end
			R.wait(0.42)
		end
		R.fx.money(V3(0, 8, 0), 4, 60)
		-- temps 4 : il lance une pièce d'or et la croque au ralenti
		local coin = R.prop("Coin", CF(0.9, 8.6, -1.2))
		R.slowmo(0.5)
		R.cam.pushIn(V3(0, 9.8, 0), 6.5, 3.6, 1.0, { height = 0.3, yaw = 0.3, fov = 42 })
		R.fly(coin, { V3(0.9, 8.6, -1.2), V3(0.7, 12.5, -1.3), V3(0.9, 9.1, -1.3) }, 0.7)
		R.spin(coin, 5, 0.7, "X")
		R.wait(0.6)
		R.anim("Catch")
		R.wait(0.12)
		R.attach(coin, "RightHand", CF(0, -1.1, -0.15))
		R.slowmo(1)
		R.anim("Bite")
		R.wait(0.35)
		R.fx.word("CHOMP!", V3(-1.5, 11, -1.6), 0.9)
		R.fx.twinkle(V3(0.2, 10, -0.9))
		R.sound("Clang", nil, 0.6, 1.6)
		R.wait(0.4)
		R.destroy(coin, "sparks")
		-- temps 5 : pluie de colis, il en jette un dans l'objectif, tableau final
		local cols = { C3(255, 90, 90), C3(90, 170, 255), C3(140, 60, 220), C3(80, 210, 120), C3(255, 170, 40) }
		for i = 1, 12 do
			local a = i / 12 * PI * 2 + R.rand(-0.2, 0.2)
			local r = R.rand(3.6, 7)
			local s = R.rand(1, 1.8)
			local rot = R.rand(-0.6, 0.6)
			local pk = package(V3(cos(a) * r, 24 + i, sin(a) * r), s, cols[(i % #cols) + 1], rot)
			R.delay(i * 0.04, function()
				R.moveTo(pk, CF(cos(a) * r, s / 2, sin(a) * r) * yaw(rot), 0.45, ES.Bounce, ED.Out)
			end)
		end
		local throwPk = R.box(V3(1, 1, 1), CF(0, -30, 0), C3(255, 90, 90))
		R.attach(throwPk, "RightHand", CF(0, -1.2, -0.2))
		R.cam.cut(V3(0, 9, -11), V3(0, 9, 0), 50)
		R.anim("Throw")
		R.wait(0.25)
		R.detach(throwPk)
		R.wait(R.fly(throwPk, { R.pos(throwPk), V3(0.2, 9.4, -6), V3(0, 9, -10.6) }, 0.25))
		R.destroy(throwPk)
		R.fx.impact(1)
		R.fx.flash(WH, 0.02, 0.06, 0.3)
		R.cam.shake(0.8)
		R.sound("Bonk")
		R.cam.cut(V3(-3, 3, -15), V3(0, 7.5, 0), 55)
		R.transform(true)
		R.pose(KING_WIDE)
		R.fx.rays(GOLD)
		R.fx.coins(V3(0, 10, 0), 16)
		R.cam.move(V3(-3.5, 2.6, -13.5), V3(0, 7.8, 0), 1.6, 55, ES.Sine, ED.Out)
		R.wait(0.5)
		R.title()
		R.wait(1.0)
	end,
}

------------------------------------------------------------------------------------------------ RECEPTIONIST
local BLUSH_P, MINT, NAVY, NAVY2, NRED = C3(255, 150, 200), C3(120, 222, 192), C3(28, 48, 110), C3(18, 32, 80), C3(205, 30, 40)
local POP, CYAN, SILVR = C3(255, 70, 190), C3(40, 230, 255), C3(222, 222, 238)

-- RARE : standard qui sonne en gros plan, elle traverse le cadre en glissant sur sa chaise à roulettes (un tour sur
-- elle-même), coupe toutes les lignes d'une claque, doigt levé « Hold, please. »
local DIVA_SIT = { RS = { p = 0.6, r = 0.15 }, LS = { p = 1.1, y = 0.8, r = -0.4 }, RJ = { ln = -0.06 }, RH = { p = 1.57, r = 0.08 }, LH = { p = 1.45, r = 0.08 } }
local DIVA_END = { RS = { p = 2.35, y = 0.15, r = -0.2 }, LS = { p = 1.1, y = 0.8, r = -0.4 }, RJ = { sd = 0.1, ln = -0.08 }, RH = { p = 1.57, r = 0.1 }, LH = { p = 1.3, r = 0.05 } }
P.Receptionist_Rare = {
	Caption = "Hold, please. Forever. Your call is very important to her nails.",
	Location = "Front Desk - Lobby, 1962",
	Reveal = function(R)
		R.stage("Room", { color = MINT, floor = C3(255, 196, 220), w = 36, d = 26, h = 14 })
		R.light(V3(0, 9, -4), C3(255, 235, 245), 26, 1.5)
		-- bureau d'accueil + standard 3 lignes
		local front = R.box(V3(7, 3, 0.4), CF(0, 1.5, -2.9), BLUSH_P)
		R.text(front, "RECEPTION", { Face = FRONT, Color = WH })
		R.box(V3(7.4, 0.3, 2.3), CF(0, 3.1, -2.2), WH, "Marble")
		R.box(V3(2.4, 0.6, 1.1), CF(1.7, 3.55, -2.1), C3(70, 60, 80))
		local lines = {}
		for i = 1, 3 do
			lines[i] = R.ball(0.32, V3(1.0 + i * 0.45, 3.92, -2.25), C3(70, 70, 70), "Neon")
		end
		local tag = R.box(V3(2.2, 0.35, 0.05), CF(1.7, 3.55, -2.67), WH, "SmoothPlastic", 1)
		R.text(tag, "LINE 1  2  3", { Face = FRONT, Color = WH })
		R.box(V3(0.8, 1.2, 0.8), CF(-2.6, 3.85, -2.2), C3(255, 120, 180), "Glass", 0.3)
		R.ball(0.9, V3(-2.6, 4.7, -2.2), C3(255, 90, 160))
		R.box(V3(6, 3.5, 0.2), CF(0, 7, 12.8), C3(255, 255, 255))
		local wall = R.box(V3(5.6, 3.1, 0.05), CF(0, 7, 12.65), WH, "SmoothPlastic", 1)
		R.text(wall, "WELCOME!", { Face = FRONT, Color = C3(255, 110, 170) })
		-- chaise à roulettes (repère = sol sous l'assise)
		local chair = R.model({
			{ Size = V3(0.2, 0.2, 0.2), CFrame = CF(), Transparency = 1 },
			{ Size = V3(2, 0.4, 2), CFrame = CF(0, 1.9, 0), Color = C3(255, 110, 170) },
			{ Size = V3(2, 2.2, 0.3), CFrame = CF(0, 3.2, 0.95), Color = C3(255, 110, 170) },
			{ Size = V3(1.5, 0.3, 0.3), CFrame = CF(0, 0.95, 0) * UPRIGHT, Color = C3(200, 200, 210), Material = "Metal", Shape = "Cyl" },
			{ Size = V3(2.2, 0.2, 0.3), CFrame = CF(0, 0.3, 0), Color = C3(60, 60, 70) },
			{ Size = V3(0.3, 0.2, 2.2), CFrame = CF(0, 0.3, 0), Color = C3(60, 60, 70) },
		}, CF(-16, 0, 0))
		local hold = R.billboard("Hold, please.", V3(-2.6, 6.6, -1), { size = 3, Color = C3(255, 90, 160) })
		hold.Enabled = false
		R.place(CF(-16, 3.1, 0))
		R.pose(DIVA_SIT)
		local ringing = true
		R.every(0.12, function(i)
			for k, l in ipairs(lines) do
				l.Color = (ringing and (i + k) % 2 == 0) and C3(255, 60, 60) or C3(70, 70, 70)
			end
		end)

		R.onSkip(function()
			ringing = false
			chair:PivotTo(R.at(0, 0, 0))
			R.place(CF(0, 3.1, 0))
			R.pose(DIVA_END)
			hold.Enabled = true
			R.cam.cut(V3(-2.4, 5, -7), V3(0, 4.4, 0), 44)
		end)

		-- temps 1 : gros plan sur le standard qui sonne
		R.cam.cut(V3(1.0, 4.7, -5.6), V3(1.7, 3.7, -2.1), 36)
		for k = 1, 3 do
			R.delay((k - 1) * 0.38, function()
				R.sound("Ding", nil, 0.5, 1.7)
				R.fx.word("RING!", V3(1.7 + (k - 2) * 1.1, 4.8 + (k % 2) * 0.4, -2.6), 0.45)
			end)
		end
		R.wait(1.1)
		-- temps 2 : elle traverse le cadre sur sa chaise, un tour complet, et claque le standard
		R.cam.move(V3(-2.2, 4.8, -9.5), V3(-0.5, 3.8, 0), 0.8, 50)
		R.sound("Whoosh", nil, 0.6)
		R.over(0.95, function(a, e)
			local x = lerp(-16, 0, e)
			local yw = e * PI * 2
			R.place(CF(x, 3.1, 0) * yaw(yw))
			chair:PivotTo(R.at(x, 0, 0) * yaw(yw))
		end, ES.Quart, ED.Out)
		R.delay(0.15, function()
			R.sound("Squeak", nil, 0.5, 1.3)
		end)
		R.wait(0.95)
		R.anim({ { t = 0 }, { t = 0.12, RS = { p = 2.2, r = 0.3 }, RJ = { tw = -0.25 } }, { t = 0.24, RS = { p = 1.3, r = -0.35 }, RJ = { ln = 0.2, tw = 0.15 } } })
		R.wait(0.22)
		ringing = false
		R.sound("Clang", nil, 0.6, 1.3)
		R.fx.word("CLICK.", V3(2.6, 4.8, -2.4), 0.5)
		R.cam.shake(0.2)
		R.wait(0.2)
		-- temps 3 : « Hold, please. »
		R.pose(DIVA_END)
		hold.Enabled = true
		R.cam.pushIn(V3(0, 4.6, 0), 7, 4.6, 1.0, { yaw = -0.35, height = 0.4, fov = 42 })
		R.fx.twinkle(V3(-0.3, 4.7, -0.75))
		R.sound("Ding", nil, 0.4, 2.2)
		for k = 1, 3 do
			local note = R.billboard(k % 2 == 0 and "♫" or "♪", V3(1.4 + k * 0.4, 5, -0.8), { size = 1.4, Color = C3(255, 110, 170) })
			R.delay((k - 1) * 0.15, function()
				R.tween(note, 1.4, { StudsOffset = V3(k * 0.2, 2.4, 0) }, ES.Sine, ED.Out)
			end)
		end
		R.wait(0.6)
		R.title()
		R.wait(0.6)
	end,
}

-- EPIC : générique de JT (globe + bandeau BREAKING qui balaie l'écran), plan caméra 1 en poussée, mains qui tapotent
-- les feuilles, COUPE franche caméra 2 : elle pivote, désigne l'imprimante en feu qui explose, sans broncher.
local ANCHOR_END = { RS = { p = 1.15, r = -0.55 }, LS = { p = 1.15, r = -0.55 }, RJ = { ln = 0.1 }, RH = { r = 0.05 }, LH = { r = 0.05 } }
P.Receptionist_Epic = {
	Caption = "Good evening. Tonight: the printer is on fire. More at eleven.",
	Location = "Studio 7 - Live",
	Reveal = function(R)
		R.stage("Studio", { color = C3(22, 34, 74), floor = C3(28, 30, 42) })
		-- plateau : bureau, écran mural, globe, imprimante en feu, caméra de plateau
		local front = R.box(V3(8, 3, 0.4), CF(0, 1.5, -2.7), NAVY2)
		R.text(front, "NEWS 7", { Face = FRONT, Color = WH })
		R.box(V3(8.05, 0.18, 0.45), CF(0, 2.6, -2.75), NRED, "Neon")
		R.box(V3(8.4, 0.25, 2.4), CF(0, 3.05, -1.9), C3(220, 225, 235), "Marble")
		R.box(V3(10, 6, 0.4), CF(-5, 7, 9), BK)
		local screen = R.box(V3(9.4, 5.4, 0.1), CF(-5, 7, 8.75), C3(30, 60, 140), "Neon")
		R.text(screen, "LIVE: PRINTER ON FIRE", { Face = FRONT, Color = WH })
		local globe = R.ball(5, V3(5, 7.5, 9), C3(40, 110, 220), "Glass", 0.1)
		local gring = R.box(V3(0.15, 6, 6), CF(5, 7.5, 9) * ANG(0, 0, 0.4), C3(255, 210, 60), "Neon", 0, "Cyl")
		local gring2 = R.box(V3(0.15, 5.6, 5.6), CF(5, 7.5, 9) * ANG(0, PI / 2, 0), C3(140, 220, 255), "Neon", 0.3, "Cyl")
		R.box(V3(2, 3, 1.6), CF(7.5, 1.5, 3.5), C3(40, 40, 48))
		local printer = R.box(V3(2.4, 1.4, 2), CF(7.5, 3.7, 3.5), C3(225, 225, 230))
		R.box(V3(1.6, 0.1, 1.2), CF(7.5, 4.45, 3.2), WH)
		R.fx.fire(printer, 9, C3(255, 120, 40), 2)
		local cam2 = R.prop("Camera", CF(-7.5, 0, -7.5) * yaw(-PI / 4))
		local tally = R.ball(0.35, V3(-7.2, 6.4, -7.2), C3(60, 20, 20), "Neon")
		local bar = R.box(V3(11, 1.5, 0.2), CF(24, 7.5, 5.8), NRED, "Neon")
		R.text(bar, "BREAKING NEWS", { Face = FRONT, Color = WH })
		R.spin(globe, 1, 9)
		R.spin(gring2, 2, 9)
		R.mark(CF(0, 3, 0))

		R.onSkip(function()
			bar.CFrame = R.at(24, 7.5, 5.8)
			tally.Color = C3(255, 40, 40)
			R.place(CF(0, 3, 0) * yaw(-PI / 4))
			R.pose(ANCHOR_END)
			R.cam.cut(V3(-6.2, 4.8, -6.2), V3(0, 4.3, 0), 40)
		end)

		-- temps 1 : générique (globe, bandeau qui balaie)
		R.cam.cut(V3(3.2, 7.2, 1.8), V3(5, 7.5, 9), 50)
		R.cam.move(V3(4.2, 7.4, 2.4), V3(5, 7.5, 9), 1.5, 44)
		R.delay(0.3, function()
			R.moveTo(bar, CF(5, 7.5, 5.8), 0.45, ES.Back, ED.Out)
			R.sound("Whoosh", nil, 0.7)
		end)
		R.delay(0.75, function()
			R.fx.banner("BREAKING NEWS", { color = NRED, t = 0.7 })
			R.sound("Ding", nil, 0.7, 0.9)
			R.fx.flash(WH, 0.02, 0.04, 0.2)
		end)
		R.wait(1.5)
		-- temps 2 : caméra 1, poussée lente, elle tapote ses feuilles ; le bandeau défile
		R.moveTo(bar, CF(24, 7.5, 5.8), 0.01)
		R.cam.cut(V3(0, 5.2, -14), V3(0, 4.3, 0), 40)
		R.cam.move(V3(0, 4.9, -8.8), V3(0, 4.4, 0), 2.0, 38, ES.Sine, ED.Out)
		R.caption("BREAKING: PRINTER ON FIRE... COFFEE MACHINE MISSING... MORE AT 11...")
		local down, up = { RS = { p = 1.0, r = -0.4 }, LS = { p = 1.0, r = -0.4 }, RJ = { ln = 0.08 } }, { RS = { p = 1.35, r = -0.4 }, LS = { p = 1.35, r = -0.4 }, RJ = { ln = 0.02 } }
		R.anim({ { t = 0 }, { t = 0.15, RS = up.RS, LS = up.LS, RJ = up.RJ }, { t = 0.3, RS = down.RS, LS = down.LS, RJ = down.RJ },
			{ t = 0.45, RS = up.RS, LS = up.LS, RJ = up.RJ }, { t = 0.6, RS = down.RS, LS = down.LS, RJ = down.RJ }, { t = 0.8, RS = ANCHOR_END.RS, LS = ANCHOR_END.LS, RJ = ANCHOR_END.RJ } })
		R.delay(0.3, function()
			R.sound("UIClick", nil, 0.5, 0.8)
		end)
		R.delay(0.6, function()
			R.sound("UIClick", nil, 0.5, 0.8)
		end)
		R.delay(0.8, function()
			R.pose(ANCHOR_END)
		end)
		R.wait(1.9)
		-- temps 3 : COUPE caméra 2 ; elle pivote, désigne l'imprimante qui explose ; elle ne bronche pas
		tally.Color = C3(255, 40, 40)
		R.cam.cut(V3(-6.2, 4.8, -6.2), V3(0, 4.3, 0), 40)
		R.sound("UIClick", nil, 0.7, 0.6)
		R.face(V3(-6.2, 3, -6.2), 0.2)
		R.wait(0.35)
		R.face(V3(7.5, 3, 3.5), 0.2)
		R.pose("Point")
		R.wait(0.3)
		R.fx.explosion(V3(7.5, 4, 3.5), 0.8, C3(255, 140, 40))
		R.fx.debris(V3(7.5, 4, 3.5), 10, { WH, C3(225, 225, 230) })
		R.sound("Explosion", nil, 0.8)
		R.cam.shake(0.45)
		R.fx.word("KA-BOOM!", V3(6, 7, 2), 0.9)
		R.wait(0.45)
		R.face(V3(-6.2, 3, -6.2), 0.25)
		R.pose(ANCHOR_END)
		R.fx.word("More at 11.", V3(-1.5, 6.4, -1.8), 0.6)
		R.cam.pushIn(V3(0, 4.4, 0), 8.8, 7, 0.9, { yaw = -PI / 4, height = 0.4, fov = 40 })
		R.wait(0.5)
		R.title()
		R.wait(0.7)
	end,
}

-- LEGENDARY : stade plongé dans le noir vu depuis la foule (bâtons lumineux), elle monte par la trappe en silhouette
-- dans la fumée, BOUM lumière + colonnes de feu en rythme, chorégraphie en orbite, note tenue au ralenti (ailes
-- néon = transformation), confettis et feux d'artifice, cœur avec les mains.
local POP_RISE = { RS = { p = 0.35, r = 0.1 }, LS = { p = 3.0, r = 0.3 }, RJ = { ln = 0.35 }, RH = { r = 0.1 }, LH = { r = 0.1 } }
local POP_HIGH = { RS = { p = 2.1, y = 0.4, r = -0.25 }, LS = { p = 2.7, r = 0.95 }, RJ = { ln = -0.28 }, RH = { r = 0.15 }, LH = { p = -0.2, r = 0.25 } }
local POP_HEART = { RS = { p = 2.95, r = -0.32 }, LS = { p = 2.95, r = -0.32 }, RJ = { sd = 0.07, ln = -0.05 }, RH = { r = 0.12 }, LH = { p = 0.25, r = 0.05 } }
local function danceFrames()
	local A = { RS = { p = 2.7, r = 0.5 }, LS = { p = 0.4, r = 0.2 }, RJ = { sd = 0.2, tw = 0.15 }, RH = { r = 0.25 }, LH = { p = 0.3 } }
	local B = { RS = { p = 0.4, r = 0.2 }, LS = { p = 2.7, r = 0.5 }, RJ = { sd = -0.2, tw = -0.15 }, RH = { p = 0.3 }, LH = { r = 0.25 } }
	local Cp = { RS = { p = 1.57, r = -0.5 }, LS = { p = 1.57, r = -0.5 }, RJ = { ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.4 } }
	local D = { RS = { p = 1.4, r = 1.4 }, LS = { p = 1.4, r = 1.4 }, RJ = { ln = -0.1 }, RH = { r = 0.3 }, LH = { r = 0.3 } }
	local f = { { t = 0 } }
	for i, k in ipairs({ A, B, A, B, Cp, D, D }) do
		local c = table.clone(k)
		c.t = i * 0.27
		f[#f + 1] = c
	end
	return f
end
P.Receptionist_Legendary = {
	Caption = "Sold-out world tour. Still answers the phone between songs.",
	Location = "Stadium Tour - Night 47 - SOLD OUT",
	Reveal = function(R)
		R.stage("Void")
		R.fx.dark(0.75)
		-- scène : bord néon, mur LED, tours de structure, bases de pyrotechnie
		R.box(V3(28, 0.3, 0.3), CF(0, 0.15, -7), POP, "Neon")
		R.box(V3(28, 0.3, 0.3), CF(0, 0.15, -7.4), CYAN, "Neon")
		R.box(V3(30, 13, 0.5), CF(0, 7, 10), C3(14, 10, 22))
		local led = R.box(V3(26, 6, 0.1), CF(0, 8.5, 9.7), C3(60, 20, 90), "Neon")
		R.text(led, "WORLD TOUR", { Face = FRONT, Color = WH })
		for _, x in ipairs({ -13, 13 }) do
			R.box(V3(1.2, 16, 1.2), CF(x, 8, 7), C3(60, 60, 70), "DiamondPlate")
		end
		local pyroX = { -8, 8, -4.5, 4.5 }
		for _, x in ipairs(pyroX) do
			R.box(V3(1.2, 0.6, 1.2), CF(x, 0.3, -5.5), C3(40, 40, 46), "Metal")
		end
		local lift = R.box(V3(0.3, 4.2, 4.2), CF(0, -6.6, 0) * UPRIGHT, SILVR, "Metal", 0, "Cyl")
		-- public : bâtons lumineux
		local sticks = {}
		for row = 1, 4 do
			for i = 1, 13 do
				local x = -14 + i * 2.1 + R.rand(-0.4, 0.4)
				local z = -9.5 - row * 2.1
				local col = (i + row) % 2 == 0 and POP or CYAN
				R.ball(1.4, V3(x, 2.6, z), C3(16, 14, 24))
				local s = R.box(V3(0.25, 1.3, 0.25), CF(x, 4, z), col, "Neon")
				sticks[#sticks + 1] = { p = s, x = x, z = z, ph = R.rand(0, PI * 2) }
			end
		end
		local hype = 1
		R.every(1 / 20, function(k)
			local t = k / 20
			for _, s in ipairs(sticks) do
				local w = sin(t * 5 * hype + s.ph)
				s.p.CFrame = R.at(s.x + w * 0.3, 4 + math.abs(w) * 0.3 * hype, s.z) * ANG(0, 0, w * 0.5)
			end
		end)
		local spots = {
			R.spot(V3(-12, 20, -4), V3(-3.5, 0, -1), { color = POP, on = false, brightness = 2.5 }),
			R.spot(V3(12, 20, -4), V3(3.5, 0, -1), { color = CYAN, on = false, brightness = 2.5 }),
		}
		local back = R.light(V3(0, 4, 4), POP, 30, 0)
		local encore = R.billboard("ENCORE!", V3(-7, 7.5, -13), { size = 3, Color = CYAN })
		local encore2 = R.billboard("♥ FRONT DESK ♥", V3(7, 7, -14), { size = 3, Color = POP })
		R.place(CF(0, -4, 0))

		R.onSkip(function()
			encore.Enabled, encore2.Enabled = false, false
			lift.CFrame = R.at(0, -0.12, 0) * UPRIGHT
			for _, s in ipairs(spots) do
				s.on(0)
			end
			R.fx.dark(0)
			R.place(CF(0, 3, 0))
			R.transform(true)
			R.pose(POP_HEART)
			R.cam.cut(V3(-3, 3, -11), V3(0, 4.6, 0), 52)
		end)

		-- temps 1 : depuis la foule, dans le noir, le stade scande
		R.cam.cut(V3(0, 5.2, -25), V3(0, 4.5, 0), 46)
		R.cam.move(V3(0, 5.2, -21), V3(0, 4.8, 0), 1.8, 46, ES.Sine, ED.InOut)
		R.sound("Rumble", nil, 0.7)
		R.wait(1.8)
		-- temps 2 : contre-jour, fumée, elle monte par la trappe en silhouette
		encore.Enabled, encore2.Enabled = false, false
		R.tween(back, 0.5, { Brightness = 5 })
		R.fx.smoke(V3(0, 0.5, 0), 16, C3(210, 180, 235), 3)
		R.cam.crane(V3(0, 4, 0), 9, 2.4, 13, 1.8, { fov = 50 })
		R.pose(POP_RISE)
		R.moveTo(R.rig, CF(0, 3, 0), 1.6, ES.Sine, ED.Out)
		R.moveTo(lift, CF(0, -0.12, 0) * UPRIGHT, 1.6, ES.Sine, ED.Out)
		R.sound("PowerUp", nil, 0.5, 0.7)
		R.wait(1.8)
		-- temps 3 : BOUM lumière, colonnes de feu en rythme, chorégraphie
		R.fx.flash(WH, 0.02, 0.05, 0.35)
		R.fx.dark(0, 0.15)
		R.tween(back, 0.3, { Brightness = 0.6 })
		hype = 2
		for _, s in ipairs(spots) do
			s.on(0.1)
		end
		R.sound("Explosion", nil, 0.8)
		R.cam.orbit(V3(0, 4.2, 0), 11, 4.6, -0.95, 0.7, 2.2, 56, 48)
		R.anim(danceFrames())
		for k = 0, 3 do
			R.delay(k * 0.54, function()
				local a, b = pyroX[(k % 2) * 2 + 1], pyroX[(k % 2) * 2 + 2]
				for _, x in ipairs({ a, b }) do
					R.fx.pillar(V3(x, 0.6, -5.5), 1, 11, C3(255, 150, 40), 0.5)
					R.fx.fire(V3(x, 1, -5.5), 0.5, C3(255, 120, 40), 2)
				end
				R.sound("Explosion", nil, 0.4, 1.2)
				R.cam.punch(4)
			end)
		end
		R.delay(1.6, function()
			R.spin(R.rig, 1, 0.45)
		end)
		R.wait(2.2)
		-- temps 4 : la note tenue, au ralenti — ailes néon
		R.pose(POP_HIGH)
		R.slowmo(0.4, 1.3)
		R.cam.lowAngle(V3(0, 4.6, 0), 7.5, 0.4)
		R.transform(true)
		R.fx.shockwave(V3(0, 0.3, 0), 16, CYAN)
		R.sound("PowerUp", nil, 0.8, 1.3)
		for _, s in ipairs(sticks) do
			s.p.Color = POP
		end
		R.every(0.12, function(i)
			if i <= 6 then
				R.fx.ring(V3(0, 4.7, -0.9), V3(0, 0.25, -1), 1.5 + i * 0.3, i % 2 == 0 and POP or CYAN)
			end
		end)
		R.wait(0.6)
		-- temps 5 : canons à confettis, feux d'artifice, cœur avec les mains
		R.pose(POP_HEART)
		R.fx.confetti(V3(-8, 1, -5.5), 50, { POP, CYAN, WH }, 4, 14)
		R.fx.confetti(V3(8, 1, -5.5), 50, { POP, CYAN, WH }, 4, 14)
		R.fx.fireworks(V3(0, 15, 8), 4)
		R.fx.hearts(V3(0, 6.5, -1), 12, POP)
		R.sound("LevelUp", nil, 0.7)
		R.cam.move(V3(-3, 3, -11), V3(0, 4.6, 0), 1.2, 52, ES.Sine, ED.Out)
		R.wait(0.8)
		R.title()
		R.wait(1.0)
	end,
}

------------------------------------------------------------------------------------------------ FITNESS COACH
local HOTP, TEAL, YELW, NEONG, CGOLD, CRED = C3(255, 60, 170), C3(30, 215, 210), C3(255, 228, 50), C3(130, 255, 60), C3(255, 196, 40), C3(215, 28, 40)

-- RARE : cassette VHS d'aérobic, plan fixe « trépied », 4 jumping jacks comptés « 5! 6! 7! 8! », coup de pied
-- haut + jazz hands, pause VHS (freeze-frame + glitch).
local JACK_OPEN = { RS = { p = 0.15, r = 2.7 }, LS = { p = 0.15, r = 2.7 }, RH = { r = 0.45 }, LH = { r = 0.45 }, RJ = { ln = -0.05 } }
local JACK_SHUT = { RS = { r = 0.12 }, LS = { r = 0.12 }, RH = { r = 0.04 }, LH = { r = 0.04 } }
local AERO_END = { RS = { p = 1.5, r = 1.25, y = -0.4 }, LS = { p = 1.5, r = 1.25, y = -0.4 }, RH = { p = 1.9 }, LH = { p = -0.15, r = 0.1 }, RJ = { ln = -0.18 } }
P.FitnessCoach_Rare = {
	Caption = "Feel the burn! And the deadline! Five, six, seven, eight!",
	Location = "PLAY >   SP   0:00:08",
	Reveal = function(R)
		R.stage("Studio", { color = C3(40, 12, 60), floor = C3(18, 8, 32) })
		for i = -7, 7 do
			R.box(V3(0.12, 0.05, 34), CF(i * 2.5, 0.03, 6), TEAL, "Neon")
		end
		for j = -3, 9 do
			R.box(V3(36, 0.05, 0.12), CF(0, 0.03, j * 2.5), HOTP, "Neon", 0.3)
		end
		R.box(V3(0.3, 14, 14), CF(0, 9, 18) * ANG(0, PI / 2, 0), C3(255, 120, 90), "Neon", 0, "Cyl")
		for k = 0, 3 do
			R.box(V3(15, 0.5 + k * 0.15, 0.2), CF(0, 4.2 + k * 1.3, 17.6), C3(40, 12, 60))
		end
		-- boombox
		R.box(V3(3.4, 1.8, 1.1), CF(-5, 0.9, 1.5), C3(60, 60, 70))
		for _, x in ipairs({ -5.9, -4.1 }) do
			R.box(V3(0.12, 1.2, 1.2), CF(x, 0.9, 0.93) * ANG(0, PI / 2, 0), C3(25, 25, 30), "SmoothPlastic", 0, "Cyl")
		end
		R.box(V3(2.6, 0.15, 0.15), CF(-5, 2.1, 1.5), C3(200, 200, 210), "Metal")
		R.box(V3(3, 0.6, 1.8), CF(0, 0.3, 2.6), C3(120, 120, 140))
		R.fx.tint(C3(255, 215, 240))
		R.fx.saturation(1.3)

		R.onSkip(function()
			R.place(CF(0, 3, 0))
			R.pose(AERO_END)
			R.cam.cut(V3(0, 4.4, -11.5), V3(0, 4.2, 0), 48)
		end)

		-- temps 1 : plan fixe, jumping jacks comptés
		R.cam.cut(V3(0, 4.4, -13), V3(0, 4.2, 0), 50)
		local cols = { HOTP, TEAL, YELW, C3(160, 90, 255) }
		for k = 1, 4 do
			R.pose(JACK_OPEN)
			R.moveTo(R.rig, CF(0, 3.9, 0), 0.17, ES.Quad, ED.Out)
			R.fx.word(tostring(4 + k) .. "!", V3(k % 2 == 0 and -3.4 or 3.4, 6.8, -1), 0.75)
			R.sound("Boing", nil, 0.5, 0.9 + k * 0.12)
			R.cam.punch(-3)
			R.fx.sparks(V3(0, 0.3, 0), 4, cols[k])
			R.wait(0.17)
			R.moveTo(R.rig, CF(0, 3, 0), 0.17, ES.Quad, ED.In)
			R.wait(0.17)
			R.pose(JACK_SHUT)
			R.wait(0.12)
		end
		-- temps 2 : coup de pied haut + jazz hands, pause VHS
		R.anim({ { t = 0 }, { t = 0.14, RH = { p = -0.45 }, RJ = { ln = 0.12 }, RS = { p = 0.3 }, LS = { p = 0.3 } } })
		R.wait(0.14)
		R.pose(AERO_END)
		R.cam.move(V3(0, 4.4, -11.5), V3(0, 4.2, 0), 0.25, 48)
		R.sound("Whoosh", nil, 0.6, 1.2)
		R.wait(0.2)
		R.freeze(0.35)
		R.fx.glitch()
		R.location("II PAUSE   SP   0:00:11")
		R.fx.word("FEEL THE BURN!", V3(0, 8, -1), 1)
		R.wait(0.3)
		R.title()
		R.wait(0.6)
	end,
}

-- EPIC : POV de sa perche à selfie (caméra tremblée « REC »), puis plan large en contre-plongée : épaulé-jeté d'une
-- barre géante (« PR! »), il la lâche (BOOM, onde au sol), boit son shaker et finit en double biceps.
local GYM_RACK = { RS = { p = 2.2, r = 0.5, y = 0.3 }, LS = { p = 2.2, r = 0.5, y = 0.3 }, RJ = { ln = -0.05 }, RH = { p = 0.1 }, LH = { p = 0.1 } }
P.FitnessCoach_Epic = {
	Caption = "Do you even lift... the office morale? #GAINS #BLESSED #LEGDAY",
	Location = "● REC   @COACH.GAINS   LIVE",
	Reveal = function(R)
		R.stage("Room", { color = C3(84, 88, 100), floor = C3(38, 38, 44), w = 36, d = 28, h = 16 })
		R.light(V3(0, 11, -3), WH, 30, 1.6)
		R.box(V3(22, 8, 0.2), CF(0, 5, 12.8), C3(180, 205, 220), "Glass", 0.15)
		R.box(V3(12, 1.4, 0.3), CF(0, 10.5, 12.6), C3(20, 20, 24))
		local s = R.box(V3(11.6, 1.2, 0.05), CF(0, 10.5, 12.4), WH, "SmoothPlastic", 1)
		R.text(s, "NO PAIN  NO GAIN", { Face = FRONT, Color = NEONG })
		for i = 0, 4 do
			R.box(V3(0.6, 0.6, 1.6), CF(9, 1 + i * 0.9, 4 + (i % 2) * 0.2), C3(30, 30, 36), "SmoothPlastic", 0, "Cyl")
		end
		R.box(V3(1.4, 5, 3.6), CF(9.8, 2.5, 4), C3(60, 60, 68), "Metal")
		-- barre olympique
		local barAt = CF(0, 1.1, -1.4)
		local bar = R.model({
			{ Size = V3(7.4, 0.24, 0.24), CFrame = CF(), Color = C3(200, 200, 210), Material = "Metal", Shape = "Cyl" },
			{ Size = V3(0.35, 2.2, 2.2), CFrame = CF(2.6, 0, 0), Color = C3(28, 28, 32), Shape = "Cyl" },
			{ Size = V3(0.35, 2.2, 2.2), CFrame = CF(-2.6, 0, 0), Color = C3(28, 28, 32), Shape = "Cyl" },
			{ Size = V3(0.3, 1.8, 1.8), CFrame = CF(2.95, 0, 0), Color = NEONG, Shape = "Cyl" },
			{ Size = V3(0.3, 1.8, 1.8), CFrame = CF(-2.95, 0, 0), Color = NEONG, Shape = "Cyl" },
		}, barAt)
		local likes = R.billboard("♥ 50K", V3(-2.6, 6.6, -1.5), { size = 2.6, Color = C3(255, 80, 120) })
		likes.Enabled = false

		R.onSkip(function()
			bar:PivotTo(R.at(0, 1.1, -1.4))
			likes.Enabled = true
			likes.Label.Text = "♥ 99K"
			R.place(CF(0, 3, 0))
			R.pose("Flex")
			R.cam.cut(V3(-3, 3.4, -9), V3(0, 4.4, 0), 46)
		end)

		-- temps 1 : POV de la perche à selfie, caméra à la main
		R.cam.track(1.8, function(a, el)
			return V3(0.7 + sin(el * 7) * 0.07, 6.4 + sin(el * 9) * 0.05, -3.4), V3(0, 4.5, 0), 72
		end)
		R.caption("Rise and grind fam!! Leg day? Nah. EVERY day.")
		R.pose("Selfie")
		R.wait(0.8)
		R.pose("Flex")
		R.fx.hearts(V3(0, 6, -1.5), 10, C3(255, 80, 120))
		likes.Enabled = true
		R.sound("Ding", nil, 0.5, 1.5)
		R.wait(1.0)
		-- temps 2 : plan large contre-plongée, épaulé-jeté
		likes.Enabled = false
		R.cam.cut(V3(-5.5, 1.4, -9.5), V3(0, 3.8, 0), 55)
		R.pose("Crouch")
		R.moveTo(R.rig, CF(0, 2.3, 0), 0.22)
		R.wait(0.3)
		R.cam.shake(0.15)
		R.moveTo(R.rig, CF(0, 3, 0), 0.3, ES.Back, ED.Out)
		R.moveTo(bar, CF(0, 4.9, -1.2), 0.3, ES.Back, ED.Out)
		R.pose(GYM_RACK)
		R.sound("Whoosh", nil, 0.5, 0.8)
		R.wait(0.55)
		R.moveTo(bar, CF(0, 6.9, -0.15), 0.28, ES.Back, ED.Out)
		R.pose("HoldUp")
		R.cam.move(V3(-4.5, 1.1, -8.5), V3(0, 5.6, 0), 0.9, 55)
		R.wait(0.28)
		R.cam.shake(0.3)
		R.fx.word("PR!", V3(3.5, 9.5, -1), 1.1)
		R.fx.confetti(V3(0, 8.4, -0.5), 30, { NEONG, WH }, 4, 6)
		R.sound("PowerUp", nil, 0.7)
		R.wait(0.7)
		-- temps 3 : il lâche la barre (BOOM), shaker, double biceps
		R.wait(R.moveTo(bar, barAt, 0.28, ES.Quad, ED.In))
		R.fx.quake(V3(0, 0, -1.4), 9, NEONG)
		R.fx.dust(V3(0, 0.2, -1.4), 6)
		R.fx.word("BOOM!", V3(-3, 3.5, -2.5), 1)
		R.cam.shake(0.9)
		R.sound("GroundSlam")
		R.jump(bar, barAt, 0.3, 0.7)
		R.pose("Drink")
		R.cam.orbit(V3(0, 4.4, 0), 8.5, 4.2, 0.5, -0.3, 1.6, 50, 44)
		R.wait(0.55)
		R.pose("Flex")
		R.fx.puff(V3(0, 5, -0.8), 0.8)
		likes.Enabled = true
		likes.Label.Text = "♥ 99K"
		R.fx.hearts(V3(0, 6.2, -1), 14, NEONG)
		R.fx.word("#GAINS", V3(2.8, 8, -1), 0.8)
		R.wait(0.5)
		R.title()
		R.wait(0.7)
	end,
}

-- LEGENDARY : entrée de boxeur dans l'allée (caméra derrière l'épaule, flashs du public), saut par-dessus les cordes,
-- cloche + combo de shadow-boxing face caméra (plans coupés), carton FINAL ROUND, uppercut au ralenti qui envoie le
-- sac de frappe exploser dans les airs (freeze), la ceinture descend sur un rayon doré, levée au-dessus de la tête.
local CHAMP_GUARD = { RS = { p = 1.6, y = 0.9, r = -0.1 }, LS = { p = 1.5, y = 0.9, r = -0.1 }, RJ = { ln = 0.15 }, RH = { p = 0.3 }, LH = { p = -0.2 } }
local CHAMP_HOOK = {
	{ t = 0 },
	{ t = 0.1, LS = { p = 1.2, r = 1.3 }, RS = CHAMP_GUARD.RS, RJ = { tw = 0.45, ln = 0.15 } },
	{ t = 0.2, LS = { p = 1.6, r = -0.8 }, RS = CHAMP_GUARD.RS, RJ = { tw = -0.5, ln = 0.2 } },
	{ t = 0.36, LS = CHAMP_GUARD.LS, RS = CHAMP_GUARD.RS, RJ = CHAMP_GUARD.RJ },
}
P.FitnessCoach_Legendary = {
	Caption = "Undefeated in 47 office fights. Trains on the stairs. All of them.",
	Location = "Office Fight Night - Main Event",
	Reveal = function(R)
		R.stage("Void")
		R.fx.dark(0.4)
		-- ring maison (plancher à y = 2)
		R.floor(V3(16, 2, 16), CF(0, 1, 0), C3(40, 40, 52))
		local canvas = R.box(V3(15, 0.1, 15), CF(0, 2.05, 0), C3(232, 232, 238), "Fabric")
		R.text(canvas, "CHAMP", { Face = TOP, Color = CRED })
		local apron = R.box(V3(16.05, 1.9, 0.05), CF(0, 1, -8.02), CRED, "SmoothPlastic", 1)
		R.text(apron, "OFFICE FIGHT NIGHT", { Face = FRONT, Color = WH })
		for _, c in ipairs({ { 1, 1, CRED }, { -1, 1, C3(40, 90, 220) }, { 1, -1, WH }, { -1, -1, WH } }) do
			R.cyl(4.6, 0.55, V3(c[1] * 7.4, 4.3, c[2] * 7.4), c[3], "Metal")
		end
		local ropes, backRopes = {}, {}
		for k, h in ipairs({ 3.2, 4.0, 4.8 }) do
			local col = ({ CRED, WH, C3(40, 90, 220) })[k]
			for _, side in ipairs({ { 0, -7.4, 0 }, { 0, 7.4, 0 }, { -7.4, 0, PI / 2 }, { 7.4, 0, PI / 2 } }) do
				local cf = CF(side[1], h, side[2]) * yaw(side[3])
				local r = R.box(V3(14.8, 0.16, 0.16), cf, col, "SmoothPlastic", 0, "Cyl")
				ropes[#ropes + 1] = r
				if side[2] == 7.4 then
					backRopes[#backRopes + 1] = { r = r, h = h }
				end
			end
		end
		R.box(V3(3.4, 0.1, 22), CF(0, 0.05, 19), C3(150, 20, 30), "Fabric")
		for i = 1, 30 do
			local a = i / 30 * PI * 2
			local r = R.rand(14, 18)
			R.ball(1.6, V3(cos(a) * r, R.rand(1.5, 3.5), sin(a) * r), C3(18, 16, 24))
		end
		local bag = R.cyl(3.2, 1.7, V3(0, 30, -2.4), CRED)
		local chain = R.box(V3(0.12, 4, 0.12), CF(0, 33.6, -2.4), C3(160, 160, 170), "Metal")
		local card = R.box(V3(4, 2.4, 0.2), CF(-4.6, 30, 1), WH)
		R.text(card, "FINAL ROUND", { Face = FRONT, Color = CRED })
		local belt = R.mesh("FitnessCoach_Legendary_Belt", CF(0, 40, -0.6), 3.4) or R.prop("Belt", CF(0, 40, -0.6))
		local spot = R.spot(V3(0, 22, 12), V3(0, 0, 24), { color = C3(255, 240, 210) })
		R.place(CF(0, 3, 24))
		R.pose(CHAMP_GUARD)
		R.mark(CF(0, 5, 0))
		local flashes = true
		R.every(0.11, function()
			if flashes then
				local a = R.rand(0, PI * 2)
				R.fx.twinkle(V3(cos(a) * 16, R.rand(2.5, 6), sin(a) * 16))
			end
		end)

		R.onSkip(function()
			flashes = false
			bag.CFrame = R.at(0, -40, 0)
			chain.CFrame = R.at(0, -40, 0)
			card.CFrame = R.at(-4.6, 8, 1)
			R.moveTo(belt, CF(0, 8.8, -0.5), 0)
			spot.aim(V3(0, 2, 0), 0)
			R.place(CF(0, 5, 0))
			R.transform(true)
			R.pose("HoldUp")
			R.cam.cut(V3(-3, 4.2, -11), V3(0, 7, 0), 50)
		end)

		-- temps 1 : l'allée, caméra derrière l'épaule, flashs, annonce
		R.walk(CF(0, 3, 11.5), 2.0, "Strut")
		spot.aim(V3(0, 0, 11), 2.0)
		R.cam.track(2.0, function(a)
			local z = lerp(24, 11.5, a)
			return V3(2.4, 6, z + 6.5), V3(0, 4.6, z - 5), 60
		end)
		R.sound("Rumble", nil, 0.7)
		R.delay(0.25, function()
			R.fx.banner("AND THE UNDISPUTED...", { color = CGOLD, t = 1.3, size = 0.11, y = 0.22 })
		end)
		R.wait(2.0)
		-- temps 2 : saut par-dessus les cordes, les cordes vibrent
		R.cam.cut(V3(-13, 4.5, 8.5), V3(0, 5, 6), 50)
		spot.aim(V3(0, 2, 2), 0.6)
		R.wait(R.jump(R.rig, CF(0, 5, 4.4), 0.7, 4.6))
		R.fx.dust(V3(0, 2.1, 4.4), 3)
		R.sound("Thud")
		R.cam.shake(0.3)
		R.over(0.8, function(a)
			for i, b in ipairs(backRopes) do
				b.r.CFrame = R.at(0, b.h + sin(a * 28 + i) * 0.3 * (1 - a), 7.4)
			end
		end)
		R.wait(0.25)
		-- temps 3 : cloche, combo face caméra en plans coupés
		flashes = false
		R.sound("Ding", nil, 1, 0.9)
		R.delay(0.2, function()
			R.sound("Ding", nil, 1, 0.9)
		end)
		R.fx.word("DING DING!", V3(-5, 9, 2), 0.8)
		R.walk(CF(0, 5, 0), 0.3, "Run")
		spot.aim(V3(0, 2, 0), 0.3)
		R.wait(0.35)
		R.pose(CHAMP_GUARD)
		local hits = {
			{ "Jab", V3(-2, 5.2, -7.2), V3(-0.6, 5, -2.4), V3(0, 0, -1) },
			{ "Jab", V3(2.2, 4.8, -6.8), V3(0.6, 5, -2.4), V3(0, 0, -1) },
			{ CHAMP_HOOK, V3(-4.2, 4, -5), V3(0.8, 5, -2), V3(1, 0, -0.4) },
			{ "Uppercut", V3(0.6, 2.6, -6), V3(-0.4, 6, -1.8), V3(0, 1, -0.4) },
		}
		for i, h in ipairs(hits) do
			R.cam.cut(h[2], V3(0, 5, 0), 44, i == 3 and 0.12 or 0)
			R.anim(h[1], 1.3)
			R.delay(0.11, function()
				R.fx.ring(h[3], h[4], 2 + i * 0.4, CGOLD)
				R.sound(i == 4 and "Uppercut" or "Punch", nil, 0.7)
				R.cam.punch(4)
			end)
			R.wait(i == 4 and 0.45 or 0.3)
		end
		R.fx.speedLines(0.4, CGOLD)
		-- temps 4 : carton FINAL ROUND, sac de frappe, uppercut au ralenti
		R.cam.cut(V3(-10.5, 5.8, -2.2), V3(0, 6, -1.2), 46)
		R.pose(CHAMP_GUARD)
		R.fly(card, { CF(-5, 22, 1.8) * yaw(PI / 2), CF(-5, 8.6, 1.8) * yaw(PI / 2) }, 0.45)
		R.spin(card, 2, 0.45)
		R.sound("Whoosh", nil, 0.6)
		R.moveTo(bag, CF(0, 6.2, -2.4), 0.4, ES.Bounce, ED.Out)
		R.moveTo(chain, CF(0, 9.8, -2.4), 0.4, ES.Bounce, ED.Out)
		R.wait(0.55)
		R.slowmo(0.3, 1.0)
		R.anim("Uppercut", 0.9)
		R.wait(0.2)
		R.freeze(0.25)
		R.fx.bigImpact(V3(0, 5.6, -1.6), V3(0, 1, -0.3), 2, CGOLD)
		R.sound("Uppercut")
		R.fx.word("K.O.!", V3(2.4, 9.5, -2.4), 1.4, "KO")
		R.fly(bag, { V3(0, 6.2, -2.4), V3(0, 16, -5), V3(0, 32, -9) }, 0.55)
		R.spin(bag, 3, 0.55, "X")
		R.moveTo(chain, CF(0, 40, -9), 0.5)
		R.cam.move(V3(-9, 3, -3), V3(0, 14, -4), 0.5, 55)
		R.wait(0.5)
		R.fx.explosion(V3(0, 30, -9), 1.5, C3(230, 200, 150))
		R.fx.debris(V3(0, 30, -9), 14, { C3(230, 200, 150), CRED })
		R.show(bag, false)
		R.slowmo(1)
		-- temps 5 : la ceinture descend sur un rayon doré, il la brandit
		R.fx.beam(V3(0, 60, -0.6), V3(0, 2.2, -0.6), 3, CGOLD, 1.6)
		R.moveTo(belt, CF(0, 8.8, -0.5), 1.0, ES.Sine, ED.Out)
		R.sound("LevelUp", nil, 0.8)
		R.cam.crane(V3(0, 7, 0), 2.6, 5.5, 11, 1.4, { yaw = -0.25, fov = 50 })
		R.wait(0.8)
		R.pose("HoldUp")
		R.transform(true)
		R.fx.rays(CGOLD)
		R.fx.confetti(V3(0, 15, 0), 80, { CGOLD, WH, CRED }, 8, 4)
		R.fx.shockwave(V3(0, 2.2, 0), 12, CGOLD)
		R.cam.shake(0.4)
		R.wait(0.6)
		R.title()
		R.wait(1.0)
	end,
}

return P
