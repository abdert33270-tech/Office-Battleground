--[[
	UltKit — boîte à outils CLIENT des ULTIMES (signature moves façon Anime Battle Arena).
	Passée en 1er argument (K) à la fonction Client de chaque module de ReplicatedStorage.Shared.Ultimates.
	Aucun effet de bord au require (le serveur peut le require sans danger, mais n'utilise rien d'ici).

	═════════════════════════════  DONNÉES REÇUES (data)  ═════════════════════════════
	Client = function(K, data) ... end est appelé pour CHAQUE phase envoyée par U.fx côté serveur.
	data = {
		phase   = "Cutin" | "End" | <tes phases à toi : "Rush", "Whiff", "Connect", "Strike", ...>,
		id      = Id du perso (nom du module), seq = numéro unique de cette ulti,
		caster  = Model du lanceur, target = Model de la victime (ou nil),
		t0      = heure serveur (workspace:GetServerTimeNow()) de l'envoi de la phase,
		name, color, color2 = nom de l'ulti + palette du module,
		... + tout ce que le serveur a mis dans le payload de U.fx (positions, index de coup…)
	}
	"Cutin" et "End" sont gérés AUTOMATIQUEMENT par UltimateController (panneau cut-in, assombrissement,
	caméra du lanceur ; puis nettoyage caméra / bandes noires / objets suivis). Ton Client les reçoit
	quand même pour ajouter tes effets (ex. : le perso boit son café pendant le cut-in).

	═════════════════════════════  TEMPS  ═════════════════════════════
	K.at(data, dt, fn)        lance fn() à t0 + dt (compense la latence ; tout de suite si déjà passé)
	K.wait(data, dt)          attend jusqu'à t0 + dt (à utiliser dans la fonction Client, qui tourne dans son propre thread)
	K.since(data)             secondes écoulées depuis t0

	═════════════════════════════  QUI REGARDE  ═════════════════════════════
	K.isCaster(data), K.isVictim(data), K.involved(data) (lanceur ou victime), K.near(pos, radius)
	K.mine(model)             model == mon personnage

	═════════════════════════════  CAMÉRA (seulement pour lanceur + victime, sauf opts.everyone)  ═════════════════════════════
	K.shot(data, kind, opts)  prend la caméra (Scriptable) jusqu'au prochain K.shot ou K.release / fin de l'ulti
		kind "orbit"  : opts.at (Vector3 | BasePart | Model | function), radius (ou r0 -> r1), height, angle (deg, 0 = devant
		                l'axe opts.basis ou -Z monde), speed (deg/s), lookOffset (Vector3), dur (pour r0->r1), fov
		kind "fixed"  : opts.cf (CFrame) ou opts.pos + opts.lookAt, fov
		kind "track"  : opts.from, opts.at (positions/objets/fonctions) – suit les deux chaque image, fov
		kind "dolly"  : opts.from (CFrame), opts.to (CFrame), dur, style (Enum.EasingStyle), fov0 -> fov1
		kind "follow" : opts.subject (Model/BasePart), offset (CFrame dans le repère du sujet), lookOffset, fov
		opts.only = "caster" | "victim" pour limiter ; opts.everyone = true pour tout le monde à proximité (opts.radius, 80 par défaut)
	K.release(data)           rend la caméra (normal). Fait automatiquement à "End".
	K.shake(amount)           tremblement (0.3 léger … 2 énorme) ; K.fov(amount) coup de zoom (degrés)
	K.letterbox(data, on, t)  bandes noires cinéma (lanceur + victime)

	═════════════════════════════  ÉCRAN  ═════════════════════════════
	K.cutin(data, opts)       panneau cut-in (portrait 3D du lanceur, lignes de vitesse, nom géant) — déjà joué au "Cutin" ;
	                          opts = { title, sub, color, color2, dur, subject (Model, défaut data.caster), small = true }
	K.impactFrames(pattern, step)  images d'impact anime : pattern = "BWB" (B = noir/silhouettes, W = blanc cramé,
	                          R = rouge, I = contraste inversé) ; step = durée d'une image (0.04 par défaut)
	K.flash(color, dur, alpha) plein écran ; K.darken(on, strength, t) assombrit le monde (ColorCorrection)
	K.speedLines(dur, color)  lignes de vitesse manga ; K.slowmo(chars, dur) gèle les animations (hit-stop)

	═════════════════════════════  VFX MONDE (parts locales, auto-nettoyées)  ═════════════════════════════
	K.part(props, life)       Part locale ancrée (SmoothPlastic, sans collision) dans workspace.FX, détruite après life (3 s)
	K.tween(obj, t, props, style, dir)
	K.track(data, inst)       détruit inst automatiquement à la fin de l'ulti ("End")
	K.prop(data, character, limbName, size, offset, color, shape, material) part soudée à un membre (suivie, détruite à "End")
	K.shockwave(pos, radius, color)          anneau au sol (CartoonFX)
	K.ring(cf, size, color, dur, thick)      anneau qui s'élargit ; cf.LookVector = normale de l'anneau
	K.sphere(pos, size, color, dur, startSize) boule lumineuse qui gonfle et s'efface
	K.crater(pos, radius, color, life)       cratère : disque sombre, blocs soulevés, fissures, poussière
	K.debris(pos, n, colors, speed, size)    blocs projetés ; K.sparks(pos, n, color) ; K.shards(pos, n, colors, speed)
	K.light(pos, color, range, brightness, dur)
	K.beam(from, to, width, color, dur)      rayon ; K.streak(from, to, color, width, life) traînée de ruée
	K.pillar(pos, radius, height, color, dur) ; K.swirl(...) ; K.implode(pos, radius, colors, count, dur)
	K.dust(pos, radius, color, count) ; K.quake(pos, radius, color, power) ; K.bigImpact(pos, dir, power, color)
	K.airRing(pos, dir, size, color, dur) ; K.slashArc(cf, radius, color, a0, a1, dur, tilt, width)
	K.afterimage(character, color, life, transparency)  silhouette fantôme néon du perso (pose actuelle)
	K.bolt(from, to, color, width, life, jag)          éclair en zigzag
	K.word(pos, text, power, category)       onomatopée BD (CartoonFX / ComicWords)
	K.CFX = CartoonFX complet si besoin.

	═════════════════════════════  ANIMATIONS  ═════════════════════════════
	K.anim(character, frames, speed)   joue une piste ProcAnim (même format que ProcAnim/ANIMS :
	                                   { {t=0}, {t=0.1, RS={p,y,r}, LS=…, RH=…, LH=…, RJ={tw,ln,sd}}, … })
	K.freezeAnim(character, dur)

	═════════════════════════════  SONS  ═════════════════════════════
	K.sound(what, pos, volume, pitch)  what = clé de Config/Sounds ("PunchHeavy"…), clé de K.SFX ("Boom"…),
	                                   "rbxassetid://…" ou un nombre. pos nil = son 2D (plein volume).
	K.layer(list, pos)                 plusieurs sons d'un coup : { {"Boom", 1.2}, {"Bass", 1, 0.9, delay}, … }
	                                   (= what, volume, pitch, délai)
	K.SFX = sons d'ultimes vérifiés (ils se chargent) : Charge, Charge2, ChargeShort, CutIn, FinalCharge, Windup,
	        Punch, Punch2, Hit, Barrage, Explosion, Explosion2, Boom, Bass, Whoosh, Whoosh2, Whoosh3, Teleport,
	        Lightning, Lightning2, Splash, Sting

	Couleurs pratiques : K.WHITE, K.BLACK, K.rng (Random), K.UITheme, K.ProcAnim, K.Sounds
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CartoonFX = require(Shared.Modules.CartoonFX)
local ProcAnim = require(Shared.Modules.ProcAnim)
local UITheme = require(Shared.Modules.UITheme)
local Sounds = require(Shared.Config.Sounds)

local K = {}
K.CFX = CartoonFX
K.ProcAnim = ProcAnim
K.UITheme = UITheme
K.Sounds = Sounds
K.rng = Random.new()
K.WHITE = Color3.new(1, 1, 1)
K.BLACK = Color3.new(0, 0, 0)
K.CYL = Enum.PartType.Cylinder
K.BALL = Enum.PartType.Ball
K.UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local player = Players.LocalPlayer
local rng = K.rng

-- sons d'ultimes (Creator Store, vérifiés : ils se chargent)
K.SFX = {
	Charge = "rbxassetid://104978317706432",
	Charge2 = "rbxassetid://72706642917206",
	ChargeShort = "rbxassetid://70524473469772",
	CutIn = "rbxassetid://134190240007878",
	FinalCharge = "rbxassetid://123642599201457",
	Windup = "rbxassetid://115891857308043",
	Punch = "rbxassetid://123732376743848",
	Punch2 = "rbxassetid://98168954865521",
	Hit = "rbxassetid://113670234271181",
	Barrage = "rbxassetid://126111468668751",
	Explosion = "rbxassetid://93530870983093",
	Explosion2 = "rbxassetid://18872474050",
	Boom = "rbxassetid://73620401949114",
	Bass = "rbxassetid://106271204257379",
	Whoosh = "rbxassetid://109827819756282",
	Whoosh2 = "rbxassetid://77673379143813",
	Whoosh3 = "rbxassetid://79352427112835",
	Teleport = "rbxassetid://130014565062904",
	Lightning = "rbxassetid://138132512434499",
	Lightning2 = "rbxassetid://168586586",
	Splash = "rbxassetid://9117941569",
	Sting = "rbxassetid://9047102381",
}

------------------------------------------------------------------------
-- Temps
------------------------------------------------------------------------
local function serverNow()
	return workspace:GetServerTimeNow()
end

function K.since(data)
	return serverNow() - (data.t0 or serverNow())
end

function K.at(data, dt, fn)
	local delay = (data.t0 or serverNow()) + dt - serverNow()
	if delay <= 0.01 then
		task.spawn(fn)
	else
		task.delay(delay, fn)
	end
end

function K.wait(data, dt)
	local delay = (data.t0 or serverNow()) + dt - serverNow()
	if delay > 0.01 then
		task.wait(delay)
	end
end

------------------------------------------------------------------------
-- Qui regarde
------------------------------------------------------------------------
function K.mine(model)
	return player ~= nil and model ~= nil and model == player.Character
end
function K.isCaster(data)
	return K.mine(data.caster)
end
function K.isVictim(data)
	return data.target ~= nil and K.mine(data.target)
end
function K.involved(data)
	return K.isCaster(data) or K.isVictim(data)
end
function K.root(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end
function K.near(pos, radius)
	local cam = workspace.CurrentCamera
	local c = player and player.Character
	local r = K.root(c)
	local p = r and r.Position or (cam and cam.CFrame.Position)
	return p ~= nil and (p - pos).Magnitude <= (radius or 80)
end

------------------------------------------------------------------------
-- Parts / suivi
------------------------------------------------------------------------
local function fxFolder()
	return workspace:FindFirstChild("FX") or workspace
end

function K.part(props, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = fxFolder()
	Debris:AddItem(p, life or 3)
	return p
end

function K.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local tracked = {} -- [seq] = { instances }
function K.track(data, inst)
	local seq = data.seq or 0
	tracked[seq] = tracked[seq] or {}
	table.insert(tracked[seq], inst)
	return inst
end

-- part soudée à un membre du personnage (accessoire d'ulti), détruite à "End"
function K.prop(data, character, limbName, size, offset, color, shape, material)
	local limb = character and character:FindFirstChild(limbName)
	if not limb then
		return nil
	end
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color or K.WHITE
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = limb.CFrame * (offset or CFrame.new())
	local w = Instance.new("WeldConstraint")
	w.Part0 = limb
	w.Part1 = p
	w.Parent = p
	p.Parent = fxFolder()
	K.track(data, p)
	Debris:AddItem(p, 12)
	return p
end

------------------------------------------------------------------------
-- VFX (enveloppes CartoonFX + nouveautés)
------------------------------------------------------------------------
K.shockwave = CartoonFX.shockwave
K.debris = CartoonFX.debris
K.sparks = CartoonFX.sparks
K.shards = CartoonFX.shards
K.light = CartoonFX.light
K.beam = CartoonFX.beam
K.pillar = CartoonFX.pillar
K.swirl = CartoonFX.swirl
K.implode = CartoonFX.implode
K.dust = CartoonFX.dust
K.quake = CartoonFX.quake
K.bigImpact = CartoonFX.bigImpact
K.airRing = CartoonFX.airRing
K.slashArc = CartoonFX.slashArc
K.cracks = CartoonFX.cracks
K.puff = CartoonFX.puff
K.groundPos = CartoonFX.groundPos

function K.word(pos, text, power, category)
	CartoonFX.word(pos, text, power or 1, category or "Heavy")
end

-- anneau qui s'élargit (cf.LookVector = normale)
function K.ring(cf, size, color, dur, thick)
	dur = dur or 0.35
	local r = K.part({ Shape = K.CYL, Size = Vector3.new(thick or 0.4, 1, 1), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = color or K.WHITE, Material = Enum.Material.Neon, Transparency = 0.1 }, dur + 0.05)
	K.tween(r, dur, { Size = Vector3.new((thick or 0.4) * 0.3, size, size), Transparency = 1 })
	-- anneau creux : disque intérieur plus sombre qui disparaît vite
	return r
end

function K.sphere(pos, size, color, dur, startSize)
	dur = dur or 0.3
	local s = K.part({ Shape = K.BALL, Size = Vector3.one * (startSize or 1), Position = pos, Color = color or K.WHITE, Material = Enum.Material.Neon, Transparency = 0.05 }, dur + 0.05)
	K.tween(s, dur, { Size = Vector3.one * size, Transparency = 1 })
	return s
end

function K.streak(from, to, color, width, life)
	life = life or 0.25
	local d = to - from
	if d.Magnitude < 0.1 then
		return
	end
	width = width or 0.6
	local p = K.part({ Size = Vector3.new(width, width, d.Magnitude), CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to), Color = color or K.WHITE, Material = Enum.Material.Neon, Transparency = 0.1 }, life + 0.05)
	K.tween(p, life, { Size = Vector3.new(0.05, 0.05, d.Magnitude), Transparency = 1 })
	local core = K.part({ Size = Vector3.new(width * 0.35, width * 0.35, d.Magnitude), CFrame = p.CFrame, Color = K.WHITE, Material = Enum.Material.Neon }, life * 0.7)
	K.tween(core, life * 0.6, { Transparency = 1 })
	return p
end

function K.bolt(from, to, color, width, life, jag)
	life = life or 0.18
	width = width or 0.3
	local n = 6
	local prev = from
	for i = 1, n do
		local a = i / n
		local pt = from:Lerp(to, a)
		if i < n then
			pt += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * (jag or 1.2)
		end
		local d = pt - prev
		local seg = K.part({ Size = Vector3.new(width, width, d.Magnitude + width), CFrame = CFrame.lookAt(prev:Lerp(pt, 0.5), pt), Color = color or Color3.fromRGB(180, 230, 255), Material = Enum.Material.Neon }, life + 0.05)
		K.tween(seg, life, { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, d.Magnitude) })
		prev = pt
	end
end

local BODY = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
function K.afterimage(character, color, life, transparency)
	life = life or 0.35
	if not character then
		return
	end
	for _, n in ipairs(BODY) do
		local b = character:FindFirstChild(n)
		if b and b:IsA("BasePart") then
			local g = K.part({ Size = b.Size * (n == "Head" and Vector3.new(1, 1, 1) or Vector3.one), CFrame = b.CFrame, Color = color or K.WHITE, Material = Enum.Material.Neon, Transparency = transparency or 0.35 }, life + 0.05)
			K.tween(g, life, { Transparency = 1, Size = g.Size * 1.08 })
		end
	end
end

-- cratère : disque sombre + blocs soulevés en couronne + fissures + poussière
function K.crater(pos, radius, color, life)
	radius = radius or 8
	life = life or 4
	local g = CartoonFX.groundPos and CartoonFX.groundPos(pos) or pos
	local disk = K.part({ Shape = K.CYL, Size = Vector3.new(0.12, radius * 1.3, radius * 1.3), CFrame = CFrame.new(g + Vector3.new(0, 0.06, 0)) * K.UPRIGHT, Color = Color3.fromRGB(40, 36, 34), Transparency = 0.15 }, life + 0.6)
	local glow = K.part({ Shape = K.CYL, Size = Vector3.new(0.14, radius * 0.6, radius * 0.6), CFrame = CFrame.new(g + Vector3.new(0, 0.08, 0)) * K.UPRIGHT, Color = color or Color3.fromRGB(255, 160, 60), Material = Enum.Material.Neon, Transparency = 0.2 }, life * 0.5 + 0.1)
	K.tween(glow, life * 0.5, { Transparency = 1 })
	local n = math.clamp(math.floor(radius * 1.4), 8, 16)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local s = rng:NextNumber(1.2, 2.4) * radius / 8
		local rock = K.part({ Size = Vector3.new(s * 1.3, s, s * 1.1), CFrame = CFrame.new(g + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.62 - Vector3.new(0, s, 0)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), a, rng:NextNumber(-0.6, 0.6)), Color = Color3.fromRGB(110 + rng:NextInteger(-12, 12), 104, 98) }, life + 0.6)
		K.tween(rock, 0.12, { CFrame = rock.CFrame + Vector3.new(0, s * 0.95, 0) }, Enum.EasingStyle.Back)
		task.delay(life, function()
			if rock.Parent then
				K.tween(rock, 0.5, { CFrame = rock.CFrame - Vector3.new(0, s * 1.2, 0), Transparency = 1 })
			end
		end)
	end
	task.delay(life, function()
		if disk.Parent then
			K.tween(disk, 0.5, { Transparency = 1 })
		end
	end)
	CartoonFX.cracks(g, 8, radius * 0.9, life)
	CartoonFX.dust(g, radius, Color3.fromRGB(220, 210, 200), 10)
end

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
function K.anim(character, frames, speed)
	if ProcAnim.playFrames then
		ProcAnim.playFrames(character, frames, speed)
	end
end
function K.freezeAnim(character, dur)
	ProcAnim.freeze(character, dur)
end
function K.slowmo(chars, dur)
	for _, c in ipairs(chars) do
		if c then
			ProcAnim.freeze(c, dur)
		end
	end
end

------------------------------------------------------------------------
-- Sons
------------------------------------------------------------------------
local function resolveSound(what)
	if type(what) == "number" then
		return "rbxassetid://" .. what
	end
	if type(what) ~= "string" then
		return nil
	end
	if what:find("rbxasset") then
		return what
	end
	if K.SFX[what] then
		return K.SFX[what]
	end
	local list = Sounds[what]
	if type(list) == "table" and #list > 0 then
		return list[rng:NextInteger(1, #list)]
	end
	return nil
end

function K.sound(what, pos, volume, pitch)
	local id = resolveSound(what)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 1
	s.PlaybackSpeed = pitch or 1
	s.RollOffMinDistance = 20
	s.RollOffMaxDistance = 200
	if pos then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = workspace.Terrain
		s.Parent = att
		Debris:AddItem(att, 7)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 7)
	end
	s:Play()
	return s
end

function K.layer(list, pos)
	for _, e in ipairs(list) do
		if (e[4] or 0) > 0 then
			task.delay(e[4], function()
				K.sound(e[1], pos, e[2], e[3])
			end)
		else
			K.sound(e[1], pos, e[2], e[3])
		end
	end
end

------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------
local function playerGui()
	return player and player:FindFirstChild("PlayerGui")
end

local overlayGui
local function overlay()
	if overlayGui and overlayGui.Parent then
		return overlayGui
	end
	local pg = playerGui()
	if not pg then
		return nil
	end
	overlayGui = Instance.new("ScreenGui")
	overlayGui.Name = "UltOverlay"
	overlayGui.IgnoreGuiInset = true
	overlayGui.ResetOnSpawn = false
	overlayGui.DisplayOrder = 40
	overlayGui.Parent = pg
	return overlayGui
end

function K.flash(color, dur, alpha)
	local g = overlay()
	if not g then
		return
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or K.WHITE
	f.BackgroundTransparency = 1 - (alpha or 0.85)
	f.BorderSizePixel = 0
	f.ZIndex = 20
	f.Parent = g
	K.tween(f, dur or 0.25, { BackgroundTransparency = 1 })
	Debris:AddItem(f, (dur or 0.25) + 0.05)
end

function K.speedLines(dur, color)
	CartoonFX.speedLines(dur, color)
end
function K.shake(amount)
	CartoonFX.shake(amount)
end
function K.fov(amount)
	CartoonFX.fovKick(amount)
end

-- images d'impact
local ifCC
local IF_STYLES = {
	B = { Saturation = -1, Contrast = 4, Brightness = -0.35, TintColor = Color3.new(1, 1, 1), overlay = Color3.new(0, 0, 0), alpha = 0.35 },
	W = { Saturation = -1, Contrast = 2.5, Brightness = 0.55, TintColor = Color3.new(1, 1, 1), overlay = Color3.new(1, 1, 1), alpha = 0.45 },
	R = { Saturation = -1, Contrast = 3, Brightness = -0.1, TintColor = Color3.fromRGB(255, 70, 70), overlay = Color3.fromRGB(120, 0, 0), alpha = 0.3 },
	I = { Saturation = 1, Contrast = -2.2, Brightness = 0.3, TintColor = Color3.fromRGB(200, 230, 255), overlay = Color3.new(1, 1, 1), alpha = 0.15 },
}
function K.impactFrames(pattern, step)
	step = step or 0.04
	pattern = pattern or "BW"
	if not ifCC or not ifCC.Parent then
		ifCC = Instance.new("ColorCorrectionEffect")
		ifCC.Name = "UltImpactFrame"
		ifCC.Enabled = false
		ifCC.Parent = Lighting
	end
	local g = overlay()
	local f
	if g then
		f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.ZIndex = 19
		f.Parent = g
		-- rayons radiaux (style manga) pendant les images d'impact
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local l = Instance.new("Frame")
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.62, 0.5 + math.sin(a) * 0.62)
			l.Size = UDim2.fromScale(rng:NextNumber(0.35, 0.6), rng:NextNumber(0.008, 0.02))
			l.Rotation = math.deg(a)
			l.BorderSizePixel = 0
			l.ZIndex = 20
			l.Name = "Ray"
			l.Parent = f
		end
	end
	task.spawn(function()
		for i = 1, #pattern do
			local st = IF_STYLES[pattern:sub(i, i)] or IF_STYLES.B
			ifCC.Enabled = true
			ifCC.Saturation = st.Saturation
			ifCC.Contrast = st.Contrast
			ifCC.Brightness = st.Brightness
			ifCC.TintColor = st.TintColor
			if f then
				f.BackgroundColor3 = st.overlay
				f.BackgroundTransparency = 1 - st.alpha
				for _, r in ipairs(f:GetChildren()) do
					r.BackgroundColor3 = st.overlay == K.BLACK and K.WHITE or K.BLACK
					r.BackgroundTransparency = 0.2
				end
			end
			task.wait(step)
		end
		ifCC.Enabled = false
		if f then
			f:Destroy()
		end
	end)
end

-- assombrit le monde (cut-in) ; on = false pour revenir
local darkCC
function K.darken(on, strength, t)
	if not darkCC or not darkCC.Parent then
		darkCC = Instance.new("ColorCorrectionEffect")
		darkCC.Name = "UltDarken"
		darkCC.Parent = Lighting
	end
	strength = strength or 1
	if on then
		darkCC.Enabled = true
		K.tween(darkCC, t or 0.15, { Brightness = -0.28 * strength, Contrast = 0.25 * strength, Saturation = -0.35 * strength })
	else
		K.tween(darkCC, t or 0.3, { Brightness = 0, Contrast = 0, Saturation = 0 })
	end
end

-- bandes noires cinéma (lanceur + victime)
local lbGui
function K.letterbox(data, on, t)
	if data and not K.involved(data) then
		return
	end
	local pg = playerGui()
	if not pg then
		return
	end
	if not lbGui or not lbGui.Parent then
		lbGui = Instance.new("ScreenGui")
		lbGui.Name = "UltLetterbox"
		lbGui.IgnoreGuiInset = true
		lbGui.ResetOnSpawn = false
		lbGui.DisplayOrder = 30
		lbGui.Parent = pg
		for i, y in ipairs({ 0, 1 }) do
			local b = Instance.new("Frame")
			b.Name = i == 1 and "Top" or "Bottom"
			b.AnchorPoint = Vector2.new(0, y)
			b.Position = UDim2.fromScale(0, y)
			b.Size = UDim2.fromScale(1, 0)
			b.BackgroundColor3 = K.BLACK
			b.BorderSizePixel = 0
			b.Parent = lbGui
		end
	end
	for _, b in ipairs(lbGui:GetChildren()) do
		K.tween(b, t or 0.2, { Size = UDim2.fromScale(1, on and 0.11 or 0) })
	end
end

------------------------------------------------------------------------
-- Caméra
------------------------------------------------------------------------
local cam = { owner = nil, shot = nil, t0 = 0, prevType = nil, prevFov = nil, bound = false }

local function resolvePos(x)
	local tx = typeof(x)
	if tx == "Vector3" then
		return x
	elseif tx == "CFrame" then
		return x.Position
	elseif tx == "Instance" then
		if x:IsA("BasePart") then
			return x.Position
		elseif x:IsA("Model") then
			local r = x:FindFirstChild("HumanoidRootPart") or x.PrimaryPart
			return r and r.Position or x:GetPivot().Position
		end
	elseif tx == "function" then
		return resolvePos(x())
	end
	return nil
end
K.resolvePos = resolvePos

local function easeAlpha(a, style)
	style = style or Enum.EasingStyle.Quad
	return TweenService:GetValue(math.clamp(a, 0, 1), style, Enum.EasingDirection.Out)
end

local function evalShot(s, el)
	local o = s.opts
	local kind = s.kind
	if kind == "fixed" then
		if o.cf then
			return o.cf, o.fov
		end
		local p, at = resolvePos(o.pos), resolvePos(o.lookAt)
		if p and at then
			return CFrame.lookAt(p, at), o.fov
		end
	elseif kind == "orbit" then
		local c = resolvePos(o.at)
		if not c then
			return nil
		end
		local r = o.radius or 10
		if o.r0 and o.r1 then
			r = o.r0 + (o.r1 - o.r0) * easeAlpha(el / (o.dur or 1), o.style)
		end
		local ang = math.rad((o.angle or 0) + (o.speed or 0) * el)
		local basis = o.basis and (o.basis - o.basis.Position) or CFrame.new()
		local off = basis * Vector3.new(math.sin(ang) * r, o.height or 2, -math.cos(ang) * r)
		local look = c + (o.lookOffset or Vector3.zero)
		return CFrame.lookAt(c + off, look), o.fov
	elseif kind == "track" then
		local a, b = resolvePos(o.from), resolvePos(o.at)
		if a and b then
			return CFrame.lookAt(a, b + (o.lookOffset or Vector3.zero)), o.fov
		end
	elseif kind == "dolly" then
		local a = easeAlpha(el / (o.dur or 1), o.style)
		local fov = o.fov0 and o.fov1 and (o.fov0 + (o.fov1 - o.fov0) * a) or o.fov
		return o.from:Lerp(o.to, a), fov
	elseif kind == "follow" then
		local subj = o.subject
		local part = subj and (subj:IsA("Model") and (subj:FindFirstChild("HumanoidRootPart") or subj.PrimaryPart) or subj)
		if part then
			local base = part.CFrame
			if o.flat then
				local lv = base.LookVector
				local f = Vector3.new(lv.X, 0, lv.Z)
				base = CFrame.lookAt(base.Position, base.Position + (f.Magnitude > 0.05 and f.Unit or Vector3.new(0, 0, -1)))
			end
			local p = (base * (o.offset or CFrame.new(0, 2, 8))).Position
			return CFrame.lookAt(p, base.Position + (o.lookOffset or Vector3.zero)), o.fov
		end
	end
	return nil
end

local function bindCam()
	if cam.bound then
		return
	end
	cam.bound = true
	RunService:BindToRenderStep("UltCamera", Enum.RenderPriority.Camera.Value, function()
		if not cam.shot then
			return
		end
		local c = workspace.CurrentCamera
		if not c then
			return
		end
		if c.CameraType ~= Enum.CameraType.Scriptable then
			c.CameraType = Enum.CameraType.Scriptable
		end
		local ok, cf, fov = pcall(evalShot, cam.shot, os.clock() - cam.t0)
		if ok and cf then
			c.CFrame = cf
			if fov then
				c.FieldOfView = fov
			end
		end
	end)
end

local function releaseCam()
	if not cam.shot then
		return
	end
	cam.shot = nil
	cam.owner = nil
	local c = workspace.CurrentCamera
	if c then
		c.CameraType = cam.prevType or Enum.CameraType.Custom
		if cam.prevFov then
			c.FieldOfView = cam.prevFov
		end
		local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			c.CameraSubject = hum
		end
	end
	local fovBack = cam.prevFov
	cam.prevType, cam.prevFov = nil, nil
	-- le coup de zoom de CartoonFX peut remettre une vieille valeur : on repasse derrière
	task.delay(0.6, function()
		local cc = workspace.CurrentCamera
		if not cam.shot and cc and fovBack and math.abs(cc.FieldOfView - fovBack) > 0.5 then
			cc.FieldOfView = fovBack
		end
	end)
end

function K.shot(data, kind, opts)
	opts = opts or {}
	local allowed
	if opts.everyone then
		local p = resolvePos(data.caster)
		allowed = p ~= nil and K.near(p, opts.radius or 80)
	elseif opts.only == "caster" then
		allowed = K.isCaster(data)
	elseif opts.only == "victim" then
		allowed = K.isVictim(data)
	else
		allowed = K.involved(data)
	end
	if not allowed then
		return false
	end
	bindCam()
	local c = workspace.CurrentCamera
	if not cam.shot and c then
		cam.prevType = c.CameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or c.CameraType
		cam.prevFov = c.FieldOfView
	end
	cam.owner = data.seq
	cam.shot = { kind = kind, opts = opts }
	cam.t0 = os.clock()
	return true
end

function K.release(data)
	if cam.shot and (data == nil or cam.owner == data.seq) then
		releaseCam()
	end
end

function K.cameraBusy()
	return cam.shot ~= nil
end

-- opts.tag du plan en cours (le cut-in automatique utilise "cutin")
function K.shotTag()
	return cam.shot and cam.shot.opts.tag or nil
end

------------------------------------------------------------------------
-- Cut-in
------------------------------------------------------------------------
local function portrait(model)
	if not model then
		return nil
	end
	local old = model.Archivable
	model.Archivable = true
	local ok, clone = pcall(function()
		return model:Clone()
	end)
	model.Archivable = old
	if not ok or not clone then
		return nil
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("Highlight") or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter") or d:IsA("Constraint") or d:IsA("Light") or d:IsA("Trail") or d:IsA("Beam") then
			d:Destroy()
		end
	end
	return clone
end

local cutGui
function K.cutin(data, opts)
	opts = opts or {}
	local pg = playerGui()
	if not pg then
		return
	end
	local color = opts.color or data.color or Color3.fromRGB(255, 200, 40)
	local color2 = opts.color2 or data.color2 or K.WHITE
	local dur = opts.dur or 1.0
	local title = string.upper(opts.title or data.name or "ULTIMATE")
	local small = opts.small
	if cutGui and cutGui.Parent then
		cutGui:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UltCutin"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45
	gui.Parent = pg
	cutGui = gui
	Debris:AddItem(gui, dur + 0.6)
	local ink = UITheme.Colors and UITheme.Colors.Ink or Color3.fromRGB(18, 14, 30)

	if small then
		-- version courte pour les spectateurs : bandeau en haut de l'écran
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.fromScale(0.5, -0.12)
		bar.Size = UDim2.fromScale(0.62, 0.085)
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = ink
		st.Parent = bar
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.94, 0.7)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.FontFace = UITheme.Display
		l.TextScaled = true
		l.TextColor3 = K.WHITE
		l.Text = (opts.sub and (string.upper(opts.sub) .. ": ") or "") .. title
		l.Parent = bar
		local ls = Instance.new("UIStroke")
		ls.Thickness = 3
		ls.Color = ink
		ls.Parent = l
		K.tween(bar, 0.2, { Position = UDim2.fromScale(0.5, 0.04) }, Enum.EasingStyle.Back)
		task.delay(dur, function()
			if bar.Parent then
				K.tween(bar, 0.2, { Position = UDim2.fromScale(0.5, -0.12) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		return
	end

	-- voile sombre
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = K.BLACK
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = gui
	K.tween(dim, 0.12, { BackgroundTransparency = 0.5 })
	-- flash d'entrée
	local fl = Instance.new("Frame")
	fl.Size = UDim2.fromScale(1, 1)
	fl.BackgroundColor3 = K.WHITE
	fl.BackgroundTransparency = 0.1
	fl.BorderSizePixel = 0
	fl.ZIndex = 30
	fl.Parent = gui
	K.tween(fl, 0.14, { BackgroundTransparency = 1 })

	-- bande principale (dégradé couleur du perso)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.fromScale(1, 0)
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.ClipsDescendants = true
	band.ZIndex = 2
	band.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(K.BLACK, 0.35)),
		ColorSequenceKeypoint.new(0.45, color),
		ColorSequenceKeypoint.new(1, color:Lerp(color2, 0.35)),
	})
	grad.Parent = band
	-- bords noir + blanc
	for i, y in ipairs({ 0, 1 }) do
		local e = Instance.new("Frame")
		e.AnchorPoint = Vector2.new(0, y)
		e.Position = UDim2.fromScale(0, y)
		e.Size = UDim2.new(1, 0, 0, 10)
		e.BackgroundColor3 = ink
		e.BorderSizePixel = 0
		e.ZIndex = 8
		e.Parent = band
		local w = Instance.new("Frame")
		w.AnchorPoint = Vector2.new(0, y)
		w.Position = UDim2.new(0, 0, y, i == 1 and 10 or -10)
		w.Size = UDim2.new(1, 0, 0, 4)
		w.BackgroundColor3 = K.WHITE
		w.BorderSizePixel = 0
		w.ZIndex = 8
		w.Parent = band
	end
	-- rayures diagonales qui défilent
	local stripes = Instance.new("Frame")
	stripes.BackgroundTransparency = 1
	stripes.Size = UDim2.fromScale(1.4, 1)
	stripes.ZIndex = 3
	stripes.Parent = band
	for i = 0, 13 do
		local s = Instance.new("Frame")
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(i / 13, 0.5)
		s.Size = UDim2.new(0, 26, 2.2, 0)
		s.Rotation = 28
		s.BackgroundColor3 = K.WHITE
		s.BackgroundTransparency = 0.88
		s.BorderSizePixel = 0
		s.ZIndex = 3
		s.Parent = stripes
	end
	K.tween(stripes, dur + 0.3, { Position = UDim2.fromScale(-0.35, 0) }, Enum.EasingStyle.Linear)
	-- lignes de vitesse horizontales
	for i = 1, 22 do
		local l = Instance.new("Frame")
		local y = rng:NextNumber(0.05, 0.95)
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.fromScale(rng:NextNumber(0.2, 1.2), y)
		l.Size = UDim2.new(rng:NextNumber(0.15, 0.4), 0, 0, rng:NextInteger(2, 5))
		l.BackgroundColor3 = i % 4 == 0 and color2 or K.WHITE
		l.BackgroundTransparency = rng:NextNumber(0.1, 0.5)
		l.BorderSizePixel = 0
		l.ZIndex = 4
		l.Parent = band
		local sp = rng:NextNumber(0.25, 0.55)
		K.tween(l, dur + 0.2, { Position = UDim2.fromScale(-0.6 - sp, y) }, Enum.EasingStyle.Linear)
	end
	-- portrait 3D du lanceur
	local subject = opts.subject or data.caster
	local vpf = Instance.new("ViewportFrame")
	vpf.Name = "Portrait"
	vpf.BackgroundTransparency = 1
	vpf.AnchorPoint = Vector2.new(0, 0.5)
	vpf.Position = UDim2.fromScale(-0.45, 0.5)
	vpf.Size = UDim2.fromScale(0.42, 1.25)
	vpf.ZIndex = 5
	vpf.Ambient = Color3.fromRGB(200, 200, 210)
	vpf.LightColor = Color3.new(1, 1, 1)
	vpf.LightDirection = Vector3.new(-0.4, -0.6, -1)
	vpf.Parent = band
	local clone = portrait(subject)
	local head = clone and clone:FindFirstChild("Head")
	if clone and head then
		local wm = Instance.new("WorldModel")
		wm.Parent = vpf
		clone.Parent = wm
		local vc = Instance.new("Camera")
		vc.FieldOfView = 30
		vc.Parent = vpf
		vpf.CurrentCamera = vc
		local hcf = head.CFrame
		local function camAt(dist, side)
			local p = (hcf * CFrame.new(side, 0.1, -dist)).Position
			return CFrame.lookAt(p, hcf.Position + Vector3.new(0, -0.15, 0))
		end
		vc.CFrame = camAt(5.2, 1.6)
		K.tween(vc, dur, { CFrame = camAt(3.6, 0.9) }, Enum.EasingStyle.Quad)
	end
	K.tween(vpf, 0.22, { Position = UDim2.fromScale(0.02, 0.5) }, Enum.EasingStyle.Quint)
	task.delay(0.22, function()
		if vpf.Parent then
			K.tween(vpf, dur - 0.2, { Position = UDim2.fromScale(0.06, 0.5) }, Enum.EasingStyle.Linear)
		end
	end)
	-- trait de couleur derrière le portrait
	local slash = Instance.new("Frame")
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.24, 0.5)
	slash.Size = UDim2.new(0, 70, 1.6, 0)
	slash.Rotation = 18
	slash.BackgroundColor3 = color2
	slash.BackgroundTransparency = 0.35
	slash.BorderSizePixel = 0
	slash.ZIndex = 4
	slash.Parent = band
	-- textes
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0, 0)
	sub.Position = UDim2.fromScale(1.1, 0.12)
	sub.Size = UDim2.fromScale(0.5, 0.15)
	sub.FontFace = UITheme.Display
	sub.TextScaled = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = color2 == K.WHITE and Color3.fromRGB(255, 240, 120) or color2
	sub.Text = string.upper(opts.sub or "ULTIMATE")
	sub.ZIndex = 7
	sub.Parent = band
	local ss = Instance.new("UIStroke")
	ss.Thickness = 3
	ss.Color = ink
	ss.Parent = sub
	local shadowT = Instance.new("TextLabel")
	shadowT.BackgroundTransparency = 1
	shadowT.AnchorPoint = Vector2.new(0, 0.5)
	shadowT.Position = UDim2.fromScale(1.12, 0.6)
	shadowT.Size = UDim2.fromScale(0.56, 0.48)
	shadowT.FontFace = UITheme.Display
	shadowT.TextScaled = true
	shadowT.TextXAlignment = Enum.TextXAlignment.Left
	shadowT.TextColor3 = ink
	shadowT.Text = title
	shadowT.ZIndex = 6
	shadowT.Parent = band
	local t = shadowT:Clone()
	t.TextColor3 = K.WHITE
	t.ZIndex = 7
	t.Parent = band
	local ts = Instance.new("UIStroke")
	ts.Thickness = 5
	ts.Color = ink
	ts.LineJoinMode = Enum.LineJoinMode.Miter
	ts.Parent = t
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(K.WHITE, Color3.fromRGB(255, 236, 150))
	tg.Rotation = 90
	tg.Parent = t
	local sc = Instance.new("UIScale")
	sc.Scale = 1.6
	sc.Parent = t

	-- entrée
	K.tween(band, 0.12, { Size = UDim2.fromScale(1, 0.36) }, Enum.EasingStyle.Back)
	K.tween(sub, 0.25, { Position = UDim2.fromScale(0.43, 0.12) }, Enum.EasingStyle.Quint)
	K.tween(shadowT, 0.2, { Position = UDim2.fromScale(0.435, 0.62) }, Enum.EasingStyle.Quint)
	K.tween(t, 0.2, { Position = UDim2.fromScale(0.42, 0.6) }, Enum.EasingStyle.Quint)
	K.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.22, function()
		if t.Parent then
			-- petit tremblement du titre
			for _ = 1, 4 do
				t.Position = UDim2.fromScale(0.42 + rng:NextNumber(-0.004, 0.004), 0.6 + rng:NextNumber(-0.01, 0.01))
				task.wait(0.03)
			end
			t.Position = UDim2.fromScale(0.42, 0.6)
			K.tween(t, dur - 0.4, { Position = UDim2.fromScale(0.39, 0.6) }, Enum.EasingStyle.Linear)
			K.tween(shadowT, dur - 0.4, { Position = UDim2.fromScale(0.405, 0.62) }, Enum.EasingStyle.Linear)
		end
	end)
	-- sortie
	task.delay(dur, function()
		if not band.Parent then
			return
		end
		K.tween(band, 0.14, { Size = UDim2.fromScale(1.05, 0), Position = UDim2.fromScale(0.45, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		K.tween(dim, 0.2, { BackgroundTransparency = 1 })
		local fl2 = fl:Clone()
		fl2.BackgroundTransparency = 0.3
		fl2.Parent = gui
		K.tween(fl2, 0.18, { BackgroundTransparency = 1 })
	end)
end

------------------------------------------------------------------------
-- Nettoyage d'une ulti (appelé par UltimateController à "End")
------------------------------------------------------------------------
function K._cleanup(data)
	K.release(data)
	K.letterbox(nil, false, 0.25)
	K.darken(false, nil, 0.35)
	local list = tracked[data.seq or 0]
	tracked[data.seq or 0] = nil
	if list then
		for _, inst in ipairs(list) do
			if typeof(inst) == "Instance" and inst.Parent then
				inst:Destroy()
			end
		end
	end
end

return K
