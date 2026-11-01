--[[
	Ultimate du Delivery Guy : OVERNIGHT EXPRESS
	Coup de pied, un carton géant tombe sur la victime ; trois tampons sautés (PRIORITY / FRAGILE / OVERNIGHT) ;
	klaxon + crissement : son camion de livraison déboule derrière lui, il saute sur le toit, le camion percute le carton
	et l'emporte ; freinage brutal, le carton s'envole, il bondit du toit : coup de pied volant « DELIVERED! »,
	le carton explose en chips de calage et la victime est expédiée au loin.
	Raté : le camion passe en trombe dans le vide, « MISSED DELIVERY ».
]]
-- ===== PRELUDE ult3 (commun aux 4 modules, copié dans chacun) =====
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Enum.PartType.Cylinder, Enum.PartType.Ball, CFrame.Angles(0, 0, math.pi / 2)
local rng = Random.new()
local function now()
	return workspace:GetServerTimeNow()
end
local function flat(v, fb)
	v = Vector3.new(v.X, 0, v.Z)
	if v.Magnitude < 0.05 then
		return fb or Vector3.new(0, 0, -1)
	end
	return v.Unit
end
local function rootOf(c)
	return c and c.Parent and c:FindFirstChild("HumanoidRootPart")
end
local function alive(c)
	local h = c and c.Parent and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
-- ===== FIN PRELUDE =====

local RED = Color3.fromRGB(220, 45, 40)
local BOX = Color3.fromRGB(200, 150, 90)
local BOX2 = Color3.fromRGB(175, 125, 70)
local TAPE = Color3.fromRGB(230, 200, 130)
local DARK = Color3.fromRGB(40, 36, 34)
local STEEL = Color3.fromRGB(185, 190, 200)
local YELLOW = Color3.fromRGB(255, 205, 40)
local WHITE = Color3.fromRGB(250, 250, 250)
local PEANUT = Color3.fromRGB(250, 240, 215)
local GLASS = Color3.fromRGB(150, 210, 240)

local SND = {
	Horn = "rbxassetid://114107876724534",
	Horn2 = "rbxassetid://135845561567751",
	Screech = "rbxassetid://8763693960",
	Screech2 = "rbxassetid://4421207506",
	BoxDrop = "rbxassetid://9113720294",
	Carton = "rbxassetid://9113721413",
	Tape = "rbxassetid://9117053785",
	Stamp = "rbxassetid://9113573976",
	Boom = "rbxassetid://9114362625",
	Bass = "rbxassetid://9119388384",
	Sonic = "rbxassetid://5689401424",
	Riser = "rbxassetid://1837834302",
}

local T = { Box = 0.15, Stamp = { 0.55, 0.95, 1.35 }, Horn = 1.55, Roof = 1.75, Ram = 2.05, Brake = 2.45, Kick = 2.75, End = 3.3 }
-- rythme v3 : temps forts ~15 % plus lents (le serveur ET le client lisent cette même table T)
do
	local PACE, COUNTS = 1.15, { bars = true, Blinks = true, Reps = true, BarrageN = true, Whips = true }
	local function pace(t)
		for k, v in pairs(t) do
			if type(v) == "number" and not COUNTS[k] then
				t[k] = v * PACE
			elseif type(v) == "table" then
				pace(v)
			end
		end
	end
	pace(T)
end
local DMG = { Kick = 3, Stamp = 3, Ram = 7, Final = 13, Splash = 10, SplashR = 10 }

local ANIMS = {
	DelUltKick = { -- coup de pied de face sec, bras en arrière
		{ t = 0 },
		{ t = 0.06, RH = { p = 0.6 }, RJ = { ln = 0.2 }, RS = { p = -0.4 }, LS = { p = 0.8 } },
		{ t = 0.12, RH = { p = 1.9 }, LH = { p = -0.2 }, RJ = { ln = -0.45 }, RS = { p = -0.8, r = -0.3 }, LS = { p = -0.6, r = -0.3 } },
		{ t = 0.3, RH = { p = 1.7 }, RJ = { ln = -0.4 }, RS = { p = -0.7, r = -0.3 }, LS = { p = -0.5, r = -0.3 } },
		{ t = 0.42 },
	},
	DelUltStamp = { -- saut, tampon brandi à deux mains, écrasé sur le carton
		{ t = 0 },
		{ t = 0.1, RS = { p = 3.3, y = 0.2 }, LS = { p = 3.2, y = 0.2 }, RJ = { ln = -0.45 }, RH = { p = 1.2 }, LH = { p = 0.9 } },
		{ t = 0.18, RS = { p = 1.2, y = 0.3 }, LS = { p = 1.2, y = 0.3 }, RJ = { ln = 0.75 }, RH = { p = 0.6 }, LH = { p = 0.9 } },
		{ t = 0.32, RS = { p = 1.3, y = 0.3 }, LS = { p = 1.3, y = 0.3 }, RJ = { ln = 0.6 }, RH = { p = 0.5 }, LH = { p = 0.7 } },
		{ t = 0.4 },
	},
	DelUltWhistle = { -- deux doigts à la bouche, l'autre bras appelle le camion
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.6, y = 1.3 }, LS = { p = 2.9, r = -0.6 }, RJ = { ln = -0.25, tw = -0.3 } },
		{ t = 0.25, RS = { p = 2.6, y = 1.3 }, LS = { p = 2.4, r = -1.0 }, RJ = { ln = -0.3, tw = -0.35 } },
		{ t = 0.4 },
	},
	DelUltSurf = { -- debout sur le toit du camion, bras écartés, penché dans le vent
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.5, r = -1.4 }, LS = { p = 0.5, r = -1.4 }, RJ = { ln = 0.35, tw = 0.7 }, RH = { p = 0.7, r = -0.2 }, LH = { p = -0.5, r = -0.2 } },
		{ t = 0.45, RS = { p = 0.7, r = -1.3 }, LS = { p = 0.3, r = -1.5 }, RJ = { ln = 0.4, tw = 0.65, sd = 0.1 }, RH = { p = 0.75, r = -0.2 }, LH = { p = -0.45, r = -0.2 } },
		{ t = 0.75, RS = { p = 0.4, r = -1.5 }, LS = { p = 0.6, r = -1.3 }, RJ = { ln = 0.35, tw = 0.7, sd = -0.1 }, RH = { p = 0.7, r = -0.2 }, LH = { p = -0.5, r = -0.2 } },
		{ t = 0.95 },
	},
	DelUltFlyKick = { -- coup de pied sauté latéral, l'autre jambe repliée, bras en arrière
		{ t = 0 },
		{ t = 0.1, RH = { p = 1.2 }, LH = { p = 1.4 }, RJ = { ln = -0.2, tw = 0.5 }, RS = { p = 2.0 }, LS = { p = -0.6 } },
		{ t = 0.2, RH = { p = 1.8, r = -0.3 }, LH = { p = 0.9 }, RJ = { ln = -0.75, tw = 0.45 }, RS = { p = -0.9, r = -0.5 }, LS = { p = 2.1 } },
		{ t = 0.5, RH = { p = 1.7, r = -0.3 }, LH = { p = 0.8 }, RJ = { ln = -0.65, tw = 0.4 }, RS = { p = -0.8, r = -0.5 }, LS = { p = 2.0 } },
		{ t = 0.62 },
	},
	DelUltSign = { -- tend le bordereau « signez ici », puis pouce levé
		{ t = 0 },
		{ t = 0.12, LS = { p = 1.65, y = 0.4 }, RS = { p = 1.4, y = -0.4 }, RJ = { tw = 0.2 } },
		{ t = 0.45, LS = { p = 1.6, y = 0.4 }, RS = { p = 1.5, y = -0.6 }, RJ = { tw = 0.2 } },
		{ t = 0.55, LS = { p = 0.3 }, RS = { p = 2.7, y = 0.2 }, RJ = { ln = -0.15 } },
		{ t = 0.9, LS = { p = 0.3 }, RS = { p = 2.7, y = 0.2 }, RJ = { ln = -0.15 } },
		{ t = 1.05 },
	},
}

-- ===== OUTILS CLIENT ult3 (s'appuient sur UltKit = KK, fourni à chaque appel Client) =====
local KK, CFX, CUR
local LIVE, ENDED = {}, {}
-- garde une connexion pour la couper à "End"
local function keep(d, conn)
	local k = d.seq or 0
	LIVE[k] = LIVE[k] or {}
	table.insert(LIVE[k], conn)
	return conn
end
local function finishSeq(d)
	local k = d.seq or 0
	ENDED[k] = true
	for _, cn in ipairs(LIVE[k] or {}) do
		cn:Disconnect()
	end
	LIVE[k] = nil
	task.delay(10, function()
		ENDED[k] = nil
	end)
end
local function play(c, name, speed)
	if c and c.Parent then
		if ANIMS[name] then
			KK.anim(c, ANIMS[name], speed)
		else
			KK.ProcAnim.play(c, name, speed) -- animations partagées (HitHeavy, HitLight…)
		end
	end
end
-- planifie fn à l'instant t de la phase (synchro sur l'horloge serveur via data.t0)
local function at(d, t, fn)
	KK.at(d, t, function()
		if ENDED[d.seq or 0] then -- ulti terminée / annulée : on ne lance plus rien
			return
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[Ult " .. tostring(d.id) .. "]", err)
		end
	end)
end
local function fxPart(props, life)
	return KK.part(props, life or 4)
end
local function tw(o, t, props, style, dir)
	return KK.tween(o, t, props, style, dir)
end
local function snd(id, pos, vol, pitch)
	return KK.sound(id, pos, vol, pitch)
end
local function word(pos, text, power)
	KK.word(pos, text, power or 1, "Heavy")
end
local function label(pos, text, color, size, life, rise)
	Kit.floatText(pos, text, color, size or 3, life or 1, rise or 1.5)
end
local function ball(pos, size, color, transp, life)
	return fxPart({ Shape = BALL, Size = Vector3.one * size, Position = pos, Color = color, Transparency = transp or 0 }, life)
end
local function puff(pos, size, life, rise, color)
	local b = ball(pos, size, color or Color3.fromRGB(235, 240, 245), 0.25, life + 0.1)
	tw(b, life, { Position = pos + Vector3.new(0, rise, 0), Size = Vector3.one * size * 2.2, Transparency = 1 })
end
-- boule qui grossit et s'efface (explosion, flash)
local function blast(pos, from, to, color, life, transp)
	local b = ball(pos, from, color, transp or 0.1, life + 0.1)
	tw(b, life, { Size = Vector3.one * to, Transparency = 1 })
	return b
end
-- anneau plat (cf : repère d'un cylindre ; défaut = horizontal au sol)
local function ring(pos, cf, from, to, color, life, thick)
	local r = fxPart({ Shape = CYL, Size = Vector3.new(thick or 0.4, from, from), CFrame = cf or (CFrame.new(pos) * UP), Color = color, Transparency = 0.1 }, life + 0.1)
	tw(r, life, { Size = Vector3.new(0.1, to, to), Transparency = 1 })
end
-- teinte globale temporaire (sépia…) : ColorCorrection local, suivi par l'ulti (nettoyé à "End")
local function tint(d, props, dur, fadeIn, fadeOut)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Ult3Tint"
	cc.Parent = game:GetService("Lighting")
	KK.track(d, cc)
	tw(cc, fadeIn or 0.15, props)
	task.delay(dur, function()
		if cc.Parent then
			tw(cc, fadeOut or 0.25, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
			Debris:AddItem(cc, (fadeOut or 0.25) + 0.05)
		end
	end)
	Debris:AddItem(cc, dur + (fadeOut or 0.25) + 2)
	return cc
end
local function near(d, pos)
	return KK.involved(d) or KK.near(pos, 70)
end
-- ===== FIN OUTILS CLIENT =====

-- ===== RIG client (groupe de parts ancrées déplacé d'un bloc) =====
local Rig = {}
Rig.__index = Rig
local function newRig(cf)
	local folder = Instance.new("Folder")
	folder.Name = "Ult3Rig"
	folder.Parent = workspace:FindFirstChild("FX") or workspace
	if CUR then
		KK.track(CUR, folder) -- détruit à "End" quoi qu'il arrive
	end
	Debris:AddItem(folder, 9)
	return setmetatable({ folder = folder, parts = {}, offs = {}, cf = cf, conns = {} }, Rig)
end
function Rig:add(size, off, color, shape, transp, mat)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Size, p.Color = size, color
	if shape then
		p.Shape = shape
	end
	p.Transparency = transp or 0
	p.CFrame = self.cf * off
	if not self.folder.Parent then -- ulti déjà nettoyée
		return p
	end
	p.Parent = self.folder
	table.insert(self.parts, p)
	table.insert(self.offs, off)
	return p
end
function Rig:set(cf)
	self.cf = cf
	for i, p in ipairs(self.parts) do
		p.CFrame = cf * self.offs[i]
	end
end
-- déplace le rig de son CFrame actuel vers cf en t secondes (style d'easing : fonction alpha -> alpha)
function Rig:move(cf, t, ease)
	local from = self.cf
	local t0 = os.clock()
	if self.mover then
		self.mover:Disconnect()
	end
	self.mover = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / math.max(t, 1e-3), 0, 1)
		local e = ease and ease(a) or (1 - (1 - a) * (1 - a))
		if self.folder.Parent then
			self:set(from:Lerp(cf, e))
		end
		if a >= 1 and self.mover then
			self.mover:Disconnect()
			self.mover = nil
		end
	end)
end
function Rig:text(part, text, color, face)
	return Kit.flatText(part, text, color, face)
end
function Rig:fade(t)
	if self.mover then
		self.mover:Disconnect()
		self.mover = nil
	end
	for _, p in ipairs(self.parts) do
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(t), { Transparency = 1 }):Play()
			for _, g in ipairs(p:GetDescendants()) do
				if g:IsA("TextLabel") then
					TweenService:Create(g, TweenInfo.new(t), { TextTransparency = 1 }):Play()
				end
			end
		end
	end
	Debris:AddItem(self.folder, t + 0.05)
end
function Rig:destroy()
	if self.mover then
		self.mover:Disconnect()
		self.mover = nil
	end
	self.folder:Destroy()
end
-- ===== FIN RIG =====

-- enchaîne des évènements { {t, fn}, ... } (t en s depuis le début, horloge absolue : pas de dérive) ; false si annulée
local function run(U, ctx, events)
	table.sort(events, function(a, b)
		return a[1] < b[1]
	end)
	local start = os.clock()
	for _, e in ipairs(events) do
		local dt = e[1] - (os.clock() - start)
		if dt > 0.005 then
			if not U.wait(ctx, dt) then
				return false
			end
		elseif not U.alive(ctx) then
			return false
		end
		local ok, err = pcall(e[2])
		if not ok then
			warn("[Ult " .. tostring(ctx.id) .. "]", err)
		end
	end
	return true
end

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
local TRUCK_START, TRUCK_RAM = 45, 11 -- distance du centre du camion derrière la victime (début / impact)
local function truckSpeed()
	return (TRUCK_START - TRUCK_RAM) / (T.Ram - T.Horn)
end

local function server(U, caster, target, ctx)
	local cr = U.root(caster)
	if not cr then
		return
	end
	-- attaque : sprint, colis sous le bras
	U.fx(ctx, "Dash")
	if not target or not U.rush(ctx, target, { speed = 115, contact = 4.2, maxTime = 0.45, whiffDist = 16, whiffTime = 0.25 }) then
		cr = U.root(caster)
		if cr then
			local dir = U.flat(cr.CFrame.LookVector)
			U.fx(ctx, "Whiff", { base = U.ground(cr.Position), dir = dir, side = dir:Cross(Vector3.yAxis) })
		end
		U.wait(ctx, 0.85)
		return
	end
	cr = U.root(caster)
	local vr = U.root(target)
	if not cr or not vr then
		return
	end
	local dir = U.flat(vr.Position - cr.Position, cr.CFrame.LookVector)
	local right = dir:Cross(Vector3.yAxis)
	local base = U.ground(vr.Position)
	local V0 = base + Vector3.new(0, 3, 0)
	local pushEnd = Kit.safePoint(V0, V0 + dir * 14, 5)
	local flyEnd = Kit.safePoint(pushEnd, pushEnd + dir * 9 + Vector3.new(0, 5, 0), 4)
	local side = V0 - dir * 7 + right * 5
	local roofY = 9.4
	local function roofAt(centerDist, endPos)
		local c = (endPos or V0) - dir * centerDist
		return Vector3.new(c.X, base.Y + roofY + 3, c.Z) + dir * 1.5
	end
	U.hold(ctx, target, CFrame.lookAt(V0, V0 - dir))
	U.place(ctx, caster, CFrame.lookAt(V0 - dir * 4, V0))
	U.fx(ctx, "Hit", { base = base, dir = dir, right = right, pushEnd = pushEnd, flyEnd = flyEnd, side = side, roofY = roofY })
	local ev = {
		{ 0.08, function()
			U.hit(ctx, target, DMG.Kick, { words = { "PACKAGE!" } })
		end },
		{ T.Stamp[3] + 0.18, function()
			U.glide(ctx, caster, CFrame.lookAt(side, side + dir), 0.2)
		end },
		{ T.End, function() end },
	}
	local stampAt = {
		V0 - dir * 3.8 + Vector3.new(0, 1.5, 0),
		V0 + right * 3.8 + Vector3.new(0, 1.5, 0),
		V0 + Vector3.new(0, 6.2, 0) - dir * 0.5,
	}
	for i, p in ipairs(stampAt) do
		table.insert(ev, { T.Stamp[i] - 0.18, function()
			local look = (i == 3) and (p + dir) or Vector3.new(V0.X, p.Y, V0.Z)
			U.glide(ctx, caster, CFrame.lookAt(p, look), 0.16)
		end })
		table.insert(ev, { T.Stamp[i], function()
			U.hit(ctx, target, DMG.Stamp, { words = { ({ "PRIORITY!", "FRAGILE!", "OVERNIGHT!" })[i] } })
		end })
	end
	local dRoof = TRUCK_START - truckSpeed() * (T.Roof + 0.2 - T.Horn)
	table.insert(ev, { T.Roof, function()
		U.glide(ctx, caster, CFrame.lookAt(roofAt(dRoof), roofAt(dRoof) + dir), 0.2)
	end })
	table.insert(ev, { T.Roof + 0.2, function()
		U.glide(ctx, caster, CFrame.lookAt(roofAt(TRUCK_RAM), roofAt(TRUCK_RAM) + dir), T.Ram - T.Roof - 0.2, "Linear")
	end })
	table.insert(ev, { T.Ram, function()
		U.hit(ctx, target, DMG.Ram, { words = { "SPECIAL DELIVERY!" } })
		U.glide(ctx, target, CFrame.lookAt(pushEnd, pushEnd - dir), T.Brake - T.Ram, "Linear")
		U.glide(ctx, caster, CFrame.lookAt(roofAt(TRUCK_RAM, pushEnd), roofAt(TRUCK_RAM, pushEnd) + dir), T.Brake - T.Ram, "Linear")
	end })
	table.insert(ev, { T.Brake, function()
		U.glide(ctx, target, CFrame.lookAt(flyEnd, flyEnd - dir), T.Kick - T.Brake)
		local kp = flyEnd - dir * 3.4 + Vector3.new(0, 0.5, 0)
		U.glide(ctx, caster, CFrame.lookAt(kp, kp + dir), T.Kick - T.Brake)
	end })
	table.insert(ev, { T.Kick, function()
		U.finish(ctx, target, DMG.Final, { launch = dir * 105 + Vector3.new(0, 42, 0), stun = 1.6, words = { "DELIVERED!" },
			splash = { radius = DMG.SplashR, damage = DMG.Splash, center = flyEnd } })
	end })
	table.insert(ev, { T.Kick + 0.1, function()
		local land = U.ground(flyEnd - dir * 3) + Vector3.new(0, 3, 0)
		U.glide(ctx, caster, CFrame.lookAt(land, land + dir), 0.25, "In")
	end })
	run(U, ctx, ev)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
-- camion de livraison (repère : centre au sol, regard = sens de la marche)
local function buildTruck(cf)
	local r = newRig(cf)
	r:add(Vector3.new(8, 8, 10.5), CFrame.new(0, 5.2, 1.6), RED) -- caisse
	r:add(Vector3.new(8.1, 1.1, 10.6), CFrame.new(0, 3.6, 1.6), YELLOW) -- bande jaune
	local side = r:add(Vector3.new(0.1, 3, 8), CFrame.new(-4.08, 6.4, 1.6), RED)
	r:text(side, "OVERNIGHT EXPRESS", WHITE, Enum.NormalId.Left)
	local side2 = r:add(Vector3.new(0.1, 3, 8), CFrame.new(4.08, 6.4, 1.6), RED)
	r:text(side2, "OVERNIGHT EXPRESS", WHITE, Enum.NormalId.Right)
	r:add(Vector3.new(7.6, 5.2, 4), CFrame.new(0, 3.8, -5.6), RED) -- cabine
	r:add(Vector3.new(7, 2.2, 0.2), CFrame.new(0, 5.1, -7.62), GLASS) -- pare-brise
	r:add(Vector3.new(7.8, 0.8, 0.6), CFrame.new(0, 1.7, -7.8), STEEL) -- pare-chocs
	r:add(Vector3.new(4, 0.6, 0.1), CFrame.new(0, 2.6, -7.66), DARK) -- calandre
	for _, s in ipairs({ -1, 1 }) do
		r:add(Vector3.new(0.9, 0.9, 0.9), CFrame.new(2.9 * s, 2.7, -7.6), YELLOW, BALL) -- phares
		for _, z in ipairs({ -5.2, 3.6 }) do
			r:add(Vector3.new(1.2, 2.6, 2.6), CFrame.new(3.6 * s, 1.3, z) * CFrame.Angles(0, 0, math.pi / 2), DARK, CYL) -- roues
			r:add(Vector3.new(1.25, 1.2, 1.2), CFrame.new(3.62 * s, 1.3, z) * CFrame.Angles(0, 0, math.pi / 2), STEEL, CYL)
		end
	end
	r:add(Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 7.3, -6.3), YELLOW, BALL) -- gyrophare
	return r
end

-- carton géant autour de la victime (repère : root de la victime)
local function buildBox(cf)
	local r = newRig(cf)
	r:add(Vector3.new(6.4, 7, 6.4), CFrame.new(0, 0.3, 0), BOX)
	r:add(Vector3.new(6.5, 0.15, 1.4), CFrame.new(0, 3.82, 0), TAPE) -- scotch du dessus
	r:add(Vector3.new(1.4, 7.1, 6.5), CFrame.new(0, 0.3, 0), TAPE) -- scotch qui fait le tour
	r:add(Vector3.new(3.1, 0.2, 6.3), CFrame.new(-1.6, 3.9, 0) * CFrame.Angles(0, 0, 0.35), BOX2) -- rabats entrouverts
	r:add(Vector3.new(3.1, 0.2, 6.3), CFrame.new(1.6, 3.9, 0) * CFrame.Angles(0, 0, -0.35), BOX2)
	local lab = r:add(Vector3.new(2.6, 1.4, 0.1), CFrame.new(1.6, 1.6, -3.22), WHITE)
	r:text(lab, "THIS SIDE UP", DARK, Enum.NormalId.Front)
	return r
end

local function stampDecal(rig, off, text, face)
	local p = rig:add(Vector3.new(4.4, 1.6, 0.12), off, RED)
	rig:text(p, text, WHITE, face or Enum.NormalId.Front)
	p.Size = Vector3.new(0.5, 0.2, 0.12)
	tw(p, 0.12, { Size = Vector3.new(4.4, 1.6, 0.12) }, Enum.EasingStyle.Back)
	return p
end

local function clientWhiff(K, d)
	local c = d.caster
	play(c, "DelUltWhistle")
	snd("Whistle", d.base, 1)
	local from = CFrame.lookAt(d.base + d.dir * 7 - d.side * 40, d.base + d.dir * 7)
	local to = CFrame.lookAt(d.base + d.dir * 7 + d.side * 40, d.base + d.dir * 7 + d.side * 80)
	local truck = buildTruck(from)
	snd(SND.Horn, d.base + d.dir * 7, 1.2)
	truck:move(to, 0.75, function(a)
		return a
	end)
	at(d, 0.35, function()
		snd(SND.Screech2, d.base + d.dir * 7, 1)
		CFX.dust(d.base + d.dir * 7, 9, nil, 10)
		label(d.base + d.dir * 7 + Vector3.new(0, 6, 0), "MISSED DELIVERY", RED, 4, 1.2, 1.5)
		CFX.speedLines(0.3, YELLOW)
	end)
	task.delay(0.8, function()
		truck:destroy()
	end)
end

local function clientHit(K, d)
	local c, v = d.caster, d.target
	local base, dir, right = d.base, d.dir, d.right
	local V0 = base + Vector3.new(0, 3, 0)
	local isNear = near(d, d.base)
	KK.letterbox(d, true)
	KK.impactFrames("BWB", 0.04)
	local rigs = {}
	play(c, "DelUltKick")
	snd("PunchHeavy", V0, 1)
	KK.shot(d, "fixed", { pos = V0 - dir * 9 + right * 6 + Vector3.new(0, 3, 0), lookAt = V0 + Vector3.new(0, 2, 0), fov = 60 })
	-- le carton tombe du ciel
	local box
	local follow
	at(d, T.Box, function()
		box = buildBox(CFrame.new(V0 + Vector3.new(0, 14, 0)))
		table.insert(rigs, box)
		box:move(CFrame.lookAt(V0, V0 - dir), 0.14, function(a)
			return a * a
		end)
		task.delay(0.14, function()
			snd(SND.BoxDrop, V0, 1.3)
			CFX.dust(base, 8, Color3.fromRGB(215, 190, 150), 10)
			CFX.shockwave(base + Vector3.new(0, 0.2, 0), 7, BOX)
			-- le carton suit la victime
			local vr = rootOf(v)
			follow = keep(d, RunService.RenderStepped:Connect(function()
				if box.folder.Parent and vr and vr.Parent and not box.mover then
					box:set(vr.CFrame)
				end
			end))
		end)
	end)
	-- 3 tampons
	local stamps = {
		{ CFrame.new(0, 1.2, -3.27), "PRIORITY" }, -- face vers le caster (la victime le regarde : son avant = -dir)
		{ CFrame.new(-3.27, 1.2, 0) * CFrame.Angles(0, math.pi / 2, 0), "FRAGILE" }, -- côté « right » du monde = gauche locale
		{ CFrame.new(0, 3.98, 0) * CFrame.Angles(math.pi / 2, 0, 0), "OVERNIGHT" }, -- dessus
	}
	for i, s in ipairs(stamps) do
		at(d, T.Stamp[i] - 0.18, function()
			local shots = {
				{ V0 - dir * 6 - right * 4 + Vector3.new(0, 0.5, 0), V0 + Vector3.new(0, 1.5, 0) },
				{ V0 + right * 9 + dir * 4 + Vector3.new(0, 2, 0), V0 + Vector3.new(0, 1.5, 0) },
				{ V0 - dir * 5 + Vector3.new(0, 13, 0), V0 + Vector3.new(0, 4, 0) },
			}
			KK.shot(d, "fixed", { pos = shots[i][1], lookAt = shots[i][2], fov = 62 })
			play(c, "DelUltStamp")
			snd("Whoosh", V0, 0.8)
		end)
		at(d, T.Stamp[i], function()
			snd(SND.Stamp, V0, 1.3, 0.85)
			snd(SND.Tape, V0, 0.6, 1.4)
			if box then
				local p = stampDecal(box, s[1], s[2])
				CFX.sparks(p.Position, 10, RED)
				CFX.airRing(p.Position, p.CFrame.LookVector, 5, RED, 0.2)
			end
			word(V0 + Vector3.new(0, 4.5, 0), s[2] .. "!", 0.9)
			if isNear then
				CFX.shake(0.4)
			end
		end)
	end
	-- klaxon : le camion déboule
	local truck
	at(d, T.Stamp[3] + 0.2, function()
		play(c, "DelUltWhistle")
		snd("Whistle", V0, 1)
	end)
	at(d, T.Horn, function()
		local startC = CFrame.lookAt(base - dir * TRUCK_START, base - dir * TRUCK_START + dir)
		truck = buildTruck(startC)
		table.insert(rigs, truck)
		truck:move(CFrame.lookAt(base - dir * TRUCK_RAM, base - dir * TRUCK_RAM + dir), T.Ram - T.Horn, function(a)
			return a
		end)
		snd(SND.Horn, base - dir * 20, 1.5)
		-- plan dramatique : depuis la route, on voit le camion foncer sur le carton
		KK.shot(d, "fixed", { pos = V0 + dir * 11 + right * 9 + Vector3.new(0, 0.5, 0), lookAt = base - dir * 16 + Vector3.new(0, 4, 0), fov = 62 })
		snd(SND.Horn2, base - dir * 20, 0.6, 1.1)
		if isNear then
			CFX.speedLines(0.6, YELLOW)
		end
		label(base - dir * 14 + Vector3.new(0, 11, 0), "BEEP BEEP!", YELLOW, 3.5, 0.8, 1.5)
	end)
	at(d, T.Roof, function()
		play(c, "DelUltSurf")
	end)
	-- impact : le camion percute le carton et l'emporte
	at(d, T.Ram, function()
		KK.shot(d, "orbit", { at = v or V0, radius = 18, height = 4, angle = 90, speed = -15, basis = CFrame.lookAt(Vector3.zero, dir), fov = 66 })
		snd("BigImpact", V0, 1.4)
		snd(SND.Carton, V0, 1.2)
		CFX.bigImpact(V0 - dir * 3, dir, 1.4, YELLOW)
		CFX.airRing(V0, dir, 12, WHITE, 0.3)
		word(V0 + Vector3.new(0, 5, 0), "SPECIAL DELIVERY!", 1.3)
		if isNear then
			KK.impactFrames("BW", 0.04)
			CFX.shake(1.1)
		end
		if truck then
			local tEnd = d.pushEnd - dir * TRUCK_RAM - Vector3.new(0, 3, 0)
			truck:move(CFrame.lookAt(tEnd, tEnd + dir), T.Brake - T.Ram, function(a)
				return a
			end)
		end
	end)
	-- freinage
	at(d, T.Brake, function()
		snd(SND.Screech, d.pushEnd, 1.3)
		local g = Kit.ground(d.pushEnd)
		for _, s in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -5.2, 3.6 }) do
				local w = g - dir * (TRUCK_RAM + z) + right * 3.6 * s
				CFX.sparks(w + Vector3.new(0, 0.5, 0), 10, YELLOW)
				puff(w + Vector3.new(0, 0.8, 0), 1.4, 0.7, 1.5, Color3.fromRGB(200, 200, 205))
				local skid = fxPart({ Size = Vector3.new(1, 0.05, 9), CFrame = CFrame.lookAt(w + Vector3.new(0, 0.05, 0), w + dir + Vector3.new(0, 0.05, 0)) * CFrame.new(0, 0, 4.5), Color = DARK, Transparency = 0.2 })
				task.delay(1, function()
					tw(skid, 0.4, { Transparency = 1 })
				end)
				Debris:AddItem(skid, 1.45)
			end
		end
		play(c, "DelUltFlyKick")
		snd("Whoosh", d.pushEnd, 1)
	end)
	-- coup de pied volant : DELIVERED!
	at(d, T.Kick, function()
		if follow then
			follow:Disconnect()
		end
		local p = d.flyEnd
		if box then
			box:destroy()
		end
		KK.shot(d, "orbit", { at = p, r0 = 8, r1 = 22, dur = 0.55, height = 4, angle = 60, speed = 30, basis = CFrame.lookAt(Vector3.zero, dir), fov = 72 })
		snd(SND.Boom, p, 1.4)
		snd(SND.Bass, p, 1.5)
		snd(SND.Sonic, p, 1, 0.9)
		snd(SND.Horn, p, 1.2, 0.9)
		blast(p, 2, 16, YELLOW, 0.3, 0.05)
		blast(p, 1, 10, WHITE, 0.16, 0)
		CFX.bigImpact(p, dir, 1.6, RED)
		CFX.airRing(p, dir, 16, RED, 0.35)
		task.delay(0.06, function()
			CFX.airRing(p + dir * 3, dir, 20, YELLOW, 0.35)
		end)
		Kit.cubes(p, 22, { BOX, BOX2, TAPE }, 1.2, 14, 0.7)
		for _ = 1, 26 do
			local pn = fxPart({ Size = Vector3.new(0.7, 0.35, 0.45), CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = PEANUT })
			local dst = p + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(5, 13) + dir * 4
			tw(pn, 0.8, { CFrame = CFrame.new(dst) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1 })
			Debris:AddItem(pn, 0.85)
		end
		CFX.light(p, YELLOW, 36, 7, 0.4)
		word(p + Vector3.new(0, 3, 0), "DELIVERED!", 1.7)
		-- gros tampon DELIVERED au sol
		local g = Kit.ground(p)
		local st = fxPart({ Size = Vector3.new(14, 0.1, 5), CFrame = CFrame.lookAt(g + Vector3.new(0, 0.08, 0), g + right + Vector3.new(0, 0.08, 0)), Color = RED, Transparency = 0.1 })
		Kit.flatText(st, "DELIVERED", WHITE, Enum.NormalId.Top)
		task.delay(1.3, function()
			tw(st, 0.4, { Transparency = 1 })
		end)
		Debris:AddItem(st, 1.75)
		label(p + Vector3.new(0, 6, 0), "OVERNIGHT EXPRESS", YELLOW, 5, 1.5, 2)
		if isNear then
			KK.impactFrames("WBWB", 0.045)
			CFX.shake(1.5)
		end
		-- le camion repart
		if truck then
			task.delay(0.25, function()
				snd(SND.Horn2, truck.cf.Position, 0.8)
				truck:move(truck.cf * CFrame.new(0, 0, -30), 0.8, function(a)
					return a * a
				end)
				task.delay(0.5, function()
					truck:fade(0.3)
				end)
			end)
		end
	end)
	at(d, T.Kick + 0.35, function()
		play(c, "DelUltSign")
	end)
	at(d, T.End - 0.1, function()
		KK.release(d)
	end)
end

-- attaque : sprint, colis sous le bras
local function clientDash(K, d)
	local c = d.caster
	play(c, "DelUltRun")
	local r = rootOf(c)
	snd("Dash", r and r.Position, 1)
	snd(SND.Horn, r and r.Position, 0.5, 1.3)
	for i = 0, 5 do
		at(d, i * 0.06, function()
			local rr = rootOf(c)
			if rr then
				K.streak(rr.Position - rr.CFrame.LookVector * 3, rr.Position, RED, 0.5, 0.2)
				puff(rr.Position - Vector3.new(0, 2.6, 0), 0.9, 0.4, 0.8, Color3.fromRGB(220, 215, 205))
			end
		end)
	end
	if K.isCaster(d) then
		K.speedLines(0.4, YELLOW)
	end
end

ANIMS.DelUltRun = { -- sprint penché, bras qui pompent
	{ t = 0 },
	{ t = 0.06, RS = { p = 1.4 }, LS = { p = -1.0 }, RJ = { ln = 0.6 }, RH = { p = -0.9 }, LH = { p = 1.0 } },
	{ t = 0.16, RS = { p = -1.0 }, LS = { p = 1.4 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = -0.9 } },
	{ t = 0.26, RS = { p = 1.4 }, LS = { p = -1.0 }, RJ = { ln = 0.6 }, RH = { p = -0.9 }, LH = { p = 1.0 } },
	{ t = 0.36, RS = { p = -1.0 }, LS = { p = 1.4 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = -0.9 } },
	{ t = 0.46 },
}

local function client(K, d)
	KK, CFX, CUR = K, K.CFX, d
	if d.phase == "Cutin" then
		local r = rootOf(d.caster)
		snd(SND.Horn2, r and r.Position, 0.7, 1.15)
	elseif d.phase == "Dash" then
		clientDash(K, d)
	elseif d.phase == "Whiff" then
		clientWhiff(K, d)
	elseif d.phase == "Hit" then
		clientHit(K, d)
	elseif d.phase == "End" then
		finishSeq(d)
	end
end

return {
	Name = "Overnight Express",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Hit = { { 0, "SIGN HERE" }, { T.Stamp[1], "PRIORITY STAMPS" }, { T.Horn, "EXPRESS TRUCK" }, { T.Brake, "FINAL DROP-OFF" } } },
	Anticipate = { Hit = { T.Kick } },
	Desc = "Box them up, stamp them three times, then let the delivery truck and a flying kick ship them far away.",
	Color = RED,
	Color2 = YELLOW,
	Range = 26,
	Angle = 70,
	Startup = 1.0,
	Server = server,
	Client = client,
}
