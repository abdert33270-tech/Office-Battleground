--[[
	UltimateService — ULTIMES (signature moves façon Anime Battle Arena), côté serveur.

	═════════════════════════════  RÈGLES  ═════════════════════════════
	- Pendant l'Overtime (attribut Transformed), appuyer encore sur G (remote "Ultimate") lance l'ulti du perso.
	- UNE fois par transformation, disponible 1,5 s après la transformation.
	  Attributs du personnage : UltReady (bool), UltName (string, nom de l'ulti), UltActive (true pendant l'ulti),
	  UltHeld (= seq, sur la victime tenue), UltAnchor (true quand le serveur ancre ce perso ; le client le garde ancré).
	- Déroulé : 1) CUT-IN automatique (def.Startup s, 1.0 par défaut, ≤ 1.2) : lanceur invulnérable + figé + tourné vers la cible,
	  panneau cut-in, caméra, assombrissement (UltimateController). 2) def.Server(U, caster, target, ctx) : l'attaque + la cinématique.
	  3) Nettoyage automatique (ancrages, prises, caméra, bandes noires…) même si quelqu'un meurt / quitte, puis phase "End".
	  Si la victime tenue meurt / part / est téléportée avant le finisher (ou le lanceur est téléporté), l'ulti s'arrête (0,5 s).
	- Le lanceur reste invulnérable et ne peut ni attaquer ni utiliser d'attaque pendant toute l'ulti.
	- Dégâts : 30–40 au total sur la cible, 8–12 de zone au finisher. TOUT passe par U.hit / U.finish / U.splash
	  (CombatService.applyHit : cause "Combat", weapon = nom de l'ulti, category "Ultimate", imparable, sans parade).

	═════════════════════════════  MODULE D'ULTI  (ReplicatedStorage.Shared.Ultimates.<IdDuPerso>)  ═════════════════════════════
	return {
		Name = "Caffeine Overload", Desc = "One line.",   -- nom affiché (cut-in, HUD)
		Color = Color3, Color2 = Color3?,                  -- palette des VFX
		Range = 25, Angle = 70,                            -- verrouillage de la cible (facultatif)
		Startup = 1.0,                                     -- durée du cut-in (facultatif, ≤ 1.2)
		Server = function(U, caster, target, ctx) ... end, -- target = cible verrouillée encore valide après le cut-in, ou nil
		Client = function(K, data) ... end,                -- K = UltKit (voir son en-tête), data = phase envoyée par U.fx
		Beats = { Connect = "GOTCHA", Impact = "OVERLOADED" }, -- titres de temps forts affichés à ces phases (facultatif)
		Tempo = 1.12,                                      -- allongement des U.wait après le cut-in (facultatif, 1 par défaut)
	}
	Le Server tourne dans son propre thread : il enchaîne U.fx (effets clients) et U.wait (temps), et S'ARRÊTE dès
	qu'un U.wait renvoie false (ulti annulée : lanceur mort / parti / trop long). Durée max conseillée : 0,5 s d'attaque
	+ 4 s de cinématique (au-delà de 10 s l'ulti est coupée de force).

	═════════════════════════════  API SERVEUR  U  ═════════════════════════════
	ctx = { caster, player, target, id, def, name, color, color2, seq, t0, range, angle, data = {} (libre) }

	Temps / effets
		U.fx(ctx, phase, payload?)        envoie la phase à TOUS les clients -> def.Client(K, data) (payload copié dans data)
		                                  payload.beat = "TEXTE" affiche un titre de temps fort (sinon def.Beats[phase])
		U.wait(ctx, seconds) -> bool      attend ; false = ulti annulée -> fais `if not U.wait(ctx, 0.2) then return end`
		                                  v3 : le PREMIER U.wait après un coup ajoute un hit-stop (0,05 s ; 0,12 s au finisher) ;
		                                  si def.Tempo est donné, les attentes après le cut-in sont multipliées par Tempo
		                                  (uniquement pour les modules à attentes RELATIVES ; les modules à minutage absolu
		                                  « T » partagé client/serveur ralentissent plutôt leur table T)
		U.windup(ctx, seconds, payload?) -> bool   pose d'anticipation automatique du lanceur (client) puis U.wait
		U.alive(ctx) -> bool

	Lecture
		U.root(model), U.valid(model) (vivant, pas protégé, hors zone AFK, pas tenu par une autre ulti)
		U.flat(v, fallback) (vecteur horizontal unitaire), U.ground(pos) (sol sous pos), U.headroom(pos, want) (hauteur libre)
		U.facing(pos, lookAt) (CFrame à pos tournée vers lookAt, à plat), U.around(center, angleDeg, dist, dy, basisCF?)
		U.inFront(ctx, range, angle) (meilleure cible devant le lanceur), U.currentCF(ctx, model), U.wallSafe(from, to, margin)

	Mouvements (le serveur ANCRE la racine et la place ; tout est relâché automatiquement à la fin)
		U.anchor(ctx, model, cf?)         ancre (et place) un perso jusqu'à U.release / fin d'ulti
		U.place(ctx, model, cf)           téléporte (ancre si besoin)
		U.glide(ctx, model, cf, time, style?)  glisse en douceur vers cf (non bloquant ; style "Linear"|"Out"|"In"|"InOut")
		U.release(ctx, model, keepDown?)  relâche (keepDown = reste à terre : PlatformStand gardé)
		U.rush(ctx, target, opts?) -> bool    ruée du lanceur vers target (suit la cible) ; true = contact.
		                                      opts = { speed = 120, contact = 4.5, maxTime = 0.45, maxDist = Range+6, whiffDist = 16, whiffTime = 0.25 }
		                                      Sans cible / trop loin : ruée dans le vide (whiff) puis false.
		U.hold(ctx, victim, cf?) -> bool  tient la victime (ancrée, étourdie, sans combo breaker) à cf (ou là où elle est)
		                                  Rappelle U.hold / U.place / U.glide pour la déplacer.

	Dégâts (retournent "Hit" / nil)
		U.hit(ctx, victim, damage, opts?)     coup pendant la prise (pas de recul). opts = { words = {"POW!"}, power, category, hitPos, stun }
		U.finish(ctx, victim, damage, opts)   relâche + coup final : opts.pin = true (plaque au sol + onde de choc)
		                                      OU opts.launch = Vector3 (vitesse d'éjection) OU opts.knockback/up ;
		                                      opts.splash = { radius = 12, damage = 10, center = Vector3? } (dégâts de zone)
		U.splash(ctx, center, radius, damage, opts?)  dégâts de zone (exclut lanceur ; opts.exclude = Model)

	Exemple minimal (voir Ultimates.Intern pour un exemple COMPLET) :
		Server = function(U, caster, target, ctx)
			U.fx(ctx, "Rush")
			if not U.rush(ctx, target) then U.fx(ctx, "Whiff"); U.wait(ctx, 0.8); return end
			local vr = U.root(target)
			U.hold(ctx, target)
			U.fx(ctx, "Connect", { p = vr.Position })
			for i = 1, 5 do
				if not U.wait(ctx, 0.2) then return end
				U.fx(ctx, "Strike", { i = i, p = vr.Position })
				U.hit(ctx, target, 4)
			end
			if not U.wait(ctx, 0.3) then return end
			U.fx(ctx, "Finish", { p = vr.Position })
			U.finish(ctx, target, 14, { pin = true, splash = { radius = 12, damage = 10 } })
			U.wait(ctx, 0.6)
		end
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local CharacterState = require(script.Parent.CharacterState)
local CombatService = require(script.Parent.CombatService)
local Signals = require(script.Parent.Signals)

local UltimateService = {}
UltimateService.Priority = 60

local U = {}
UltimateService.api = U

local FXR
local READY_DELAY = 1.5
local MAX_TIME = 10
local DEFAULT_TEMPO = 1
local HITSTOP, HITSTOP_FIN = 0.05, 0.12
local TELEPORT_DIST = 25
local active = {} -- [caster] = ctx
local tokens = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local defs = {}
local seqCounter = 0

local function now()
	return workspace:GetServerTimeNow()
end

------------------------------------------------------------------------
-- Modules d'ulti
------------------------------------------------------------------------
local function getDef(id)
	if type(id) ~= "string" then
		return nil
	end
	if defs[id] ~= nil then
		return defs[id] or nil
	end
	local folder = Shared:FindFirstChild("Ultimates")
	local m = folder and folder:FindFirstChild(id)
	local def = false
	if m and m:IsA("ModuleScript") then
		local ok, res = pcall(require, m)
		if ok and type(res) == "table" and type(res.Server) == "function" then
			def = res
		elseif not ok then
			warn("[UltimateService] module", id, res)
		end
	end
	defs[id] = def
	return def or nil
end
UltimateService.getDef = getDef

------------------------------------------------------------------------
-- Lecture
------------------------------------------------------------------------
function U.root(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

function U.flat(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		f = fallback and Vector3.new(fallback.X, 0, fallback.Z) or Vector3.new(0, 0, -1)
	end
	return f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)
end

local function excludeList()
	local ex = { workspace:FindFirstChild("FX"), workspace:FindFirstChild("Zones"), workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	return ex
end

function U.ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local r = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	return r and r.Position or (pos - Vector3.new(0, 3, 0))
end

function U.headroom(pos, want)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local r = workspace:Raycast(pos, Vector3.new(0, want, 0), params)
	return r and math.max(0, (r.Position - pos).Magnitude - 3) or want
end

local function wallSafe(from, to, margin)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local d = to - from
	if d.Magnitude < 0.05 then
		return to
	end
	local r = workspace:Raycast(from, d, params)
	if r and r.Instance.CanCollide then
		return r.Position - d.Unit * (margin or 2)
	end
	return to
end
U.wallSafe = wallSafe

function U.facing(pos, lookAt)
	local d = U.flat(lookAt - pos, Vector3.new(0, 0, -1))
	return CFrame.lookAt(pos, pos + d)
end

function U.around(center, angleDeg, dist, dy, basis)
	local a = math.rad(angleDeg)
	local off = Vector3.new(math.sin(a) * dist, dy or 0, -math.cos(a) * dist)
	if basis then
		off = (basis - basis.Position) * off
	end
	return center + off
end

local function isHeldByOther(v, ctx)
	local h = v:GetAttribute("UltHeld")
	return h ~= nil and (not ctx or h ~= ctx.seq)
end

function U.valid(v, ctx)
	return v ~= nil and v.Parent ~= nil and CharacterState.isAlive(v) and U.root(v) ~= nil
		and not CharacterState.isProtected(v) and not CharacterState.inSafeZone(v) and not isHeldByOther(v, ctx)
end

local function pickTarget(caster, range, angle, hint)
	local cr = U.root(caster)
	if not cr then
		return nil
	end
	local look = U.flat(cr.CFrame.LookVector)
	local function score(v, rMax, aMax)
		if v == caster or not U.valid(v) then
			return nil
		end
		local vr = U.root(v)
		local to = Vector3.new(vr.Position.X - cr.Position.X, 0, vr.Position.Z - cr.Position.Z)
		local d = to.Magnitude
		if d > rMax or math.abs(vr.Position.Y - cr.Position.Y) > 14 then
			return nil
		end
		local ang = d < 0.5 and 0 or math.deg(math.acos(math.clamp(to.Unit:Dot(look), -1, 1)))
		if ang > aMax then
			return nil
		end
		return d + ang * 0.08
	end
	if typeof(hint) == "Instance" and hint:IsA("Model") and score(hint, range + 6, 150) then
		return hint
	end
	local best, bestS = nil, math.huge
	for _, v in ipairs(Hitbox.characters()) do
		local s = score(v, range, angle)
		if s and s < bestS then
			best, bestS = v, s
		end
	end
	return best
end

function U.inFront(ctx, range, angle)
	return pickTarget(ctx.caster, range or ctx.range, angle or ctx.angle)
end

------------------------------------------------------------------------
-- Temps / effets
------------------------------------------------------------------------
function U.alive(ctx)
	return not ctx.done and not ctx.aborted
end

function U.wait(ctx, t)
	t = t or 0
	if ctx.paced then
		-- rythme v3 : temps forts un peu plus lents + hit-stop après chaque coup
		t *= ctx.tempo or 1
		if (ctx.debt or 0) > 0 then
			t += ctx.debt
			ctx.debt = 0
		end
	end
	local t1 = os.clock() + t
	repeat
		if ctx.done or ctx.aborted then
			return false
		end
		task.wait()
	until os.clock() >= t1
	return not (ctx.done or ctx.aborted)
end

function U.fx(ctx, phase, payload)
	local d = {}
	if type(payload) == "table" then
		for k, v in pairs(payload) do
			d[k] = v
		end
	end
	d.id, d.seq, d.phase = ctx.id, ctx.seq, phase
	d.caster = ctx.caster
	if d.target == nil then
		d.target = ctx.target
	end
	d.t0 = now()
	d.name, d.color, d.color2 = ctx.name, ctx.color, ctx.color2
	FXR:FireAllClients(d)
end

-- anticipation : le client joue une pose d'armement sur le lanceur, puis on attend
function U.windup(ctx, t, payload)
	t = t or 0.2
	local d = {}
	if type(payload) == "table" then
		for k, v in pairs(payload) do
			d[k] = v
		end
	end
	d.t = t * (ctx.paced and ctx.tempo or 1)
	U.fx(ctx, "_Windup", d)
	return U.wait(ctx, t)
end

-- hit-stop : prévient les clients (gel des animations) et allonge la prochaine attente
local function hitStop(ctx, v, fin)
	ctx.debt = math.max(ctx.debt or 0, fin and HITSTOP_FIN or HITSTOP)
	pcall(U.fx, ctx, "_Hit", { victim = v, fin = fin })
end

------------------------------------------------------------------------
-- Ancrages / prises
------------------------------------------------------------------------
local function clearForces(r)
	for _, o in ipairs(r:GetChildren()) do
		if o:IsA("LinearVelocity") or o:IsA("AngularVelocity") or o:IsA("BodyVelocity") or o:IsA("AlignPosition") or o:IsA("BodyPosition") then
			o:Destroy()
		end
	end
end

local function pinOf(ctx, model, create)
	local pin = ctx.pins[model]
	if not pin and create then
		local r = U.root(model)
		if not r then
			return nil
		end
		pin = { cf = r.CFrame, set = r.CFrame }
		ctx.pins[model] = pin
		clearForces(r)
		model:SetAttribute("UltAnchor", true)
		r.AssemblyLinearVelocity = Vector3.zero
		r.Anchored = true
	end
	return pin
end

function U.anchor(ctx, model, cf)
	if ctx.done then
		return false
	end
	local pin = pinOf(ctx, model, true)
	if not pin then
		return false
	end
	if cf then
		pin.cf = cf
		pin.glide = nil
		pin.set = cf
		local r = U.root(model)
		if r then
			r.CFrame = cf
		end
	end
	return true
end

function U.place(ctx, model, cf)
	return U.anchor(ctx, model, cf)
end

function U.glide(ctx, model, cf, time, style)
	if ctx.done then
		return 0
	end
	local pin = pinOf(ctx, model, true)
	if not pin then
		return 0
	end
	time = math.max(time or 0.2, 0.01)
	pin.glide = { from = pin.cf, to = cf, t0 = os.clock(), dur = time, style = style or "Out" }
	return time
end

function U.currentCF(ctx, model)
	local pin = ctx.pins[model]
	if pin then
		return pin.cf
	end
	local r = U.root(model)
	return r and r.CFrame
end

function U.release(ctx, model, keepDown)
	ctx.pins[model] = nil
	local wasHeld = ctx.held[model]
	ctx.held[model] = nil
	if not model then
		return
	end
	model:SetAttribute("UltAnchor", nil)
	if wasHeld then
		model:SetAttribute("UltHeld", nil)
	end
	local r = U.root(model)
	if r and r.Parent then
		r.Anchored = false
		r.AssemblyLinearVelocity = Vector3.zero
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		if keepDown then
			-- filet de sécurité : on ne reste jamais couché indéfiniment
			task.delay(1.8, function()
				if hum.Parent and hum.Health > 0 and hum.PlatformStand and not CharacterState.isStunned(model) and not model:GetAttribute("UltAnchor") then
					hum.PlatformStand = false
				end
			end)
		else
			hum.PlatformStand = false
		end
	end
end

function U.hold(ctx, v, cf)
	-- jamais un joueur de la zone AFK (ancré + caméra prise alors qu'il ne joue pas)
	if ctx.done or not v or not CharacterState.isAlive(v) or isHeldByOther(v, ctx) or CharacterState.inSafeZone(v) then
		return false
	end
	if not ctx.held[v] then
		ctx.held[v] = true
		ctx.everHeld[v] = true
		v:SetAttribute("UltHeld", ctx.seq)
		CharacterState.setBlocking(v, false)
		CharacterState.setRunning(v, false)
		CharacterState.stun(v, 0.5)
		local hum = v:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = true
		end
	end
	return U.anchor(ctx, v, cf)
end

------------------------------------------------------------------------
-- Dégâts
------------------------------------------------------------------------
local function antiBreak(v)
	local s = CharacterState.get(v)
	s.hitStreak = 0
	s.nextBreak = math.max(s.nextBreak or 0, os.clock() + 1.2)
	v:SetAttribute("CanBreak", false)
end

local function baseHit(ctx, v, dmg, o)
	local cr, vr = U.root(ctx.caster), U.root(v)
	if not vr then
		return nil
	end
	local dir = cr and U.flat(vr.Position - cr.Position, cr.CFrame.LookVector) or Vector3.new(0, 0, -1)
	-- plafond : une même victime ne prend jamais plus de 40 dégâts par ultime (passifs et zone compris)
	ctx.dealt = ctx.dealt or {}
	local already = ctx.dealt[v] or 0
	dmg = math.max(0, math.min(dmg, 40 - already))
	ctx.dealt[v] = already + dmg
	CharacterState.setBlocking(v, false)
	local p = {
		attacker = ctx.caster, victim = v, damage = dmg, dir = o.dir or dir,
		knockback = o.knockback or 0, up = o.up or 0, stun = o.stun or 0.6,
		category = o.category or "Ultimate", power = o.power or 0.6, words = o.words,
		hitPos = o.hitPos or vr.Position + Vector3.new(0, 0.5, 0),
		unblockable = true, weapon = ctx.name, cause = "Combat", finisher = o.finisher,
	}
	if o.pin then
		p.pin = true
		p.knockback = 0
	end
	if o.launch then
		p.launch = o.launch
	end
	local res = CombatService.applyHit(p)
	antiBreak(v)
	return res
end

function U.hit(ctx, v, dmg, o)
	o = o or {}
	if ctx.done or not v or not CharacterState.isAlive(v) then
		return nil
	end
	local hum = v:FindFirstChildOfClass("Humanoid")
	-- coup fatal : on relâche d'abord (le ragdoll / l'éjection K.O. doit pouvoir partir)
	if hum and hum.Health - dmg <= 0 then
		U.release(ctx, v, true)
	end
	local res = baseHit(ctx, v, dmg, o)
	if res then
		hitStop(ctx, v, false)
	end
	return res
end

function U.finish(ctx, v, dmg, o)
	o = o or {}
	if ctx.done or not v then
		return nil
	end
	local vr = U.root(v)
	local center = (o.splash and o.splash.center) or (vr and vr.Position)
	ctx.finished = true
	U.release(ctx, v, true)
	local res = nil
	if CharacterState.isAlive(v) then
		local p = table.clone(o)
		p.finisher = true
		p.power = p.power or 1.4
		p.stun = p.stun or 1.3
		res = baseHit(ctx, v, dmg, p)
		if res then
			hitStop(ctx, v, true)
		end
	end
	if o.splash and center then
		U.splash(ctx, center, o.splash.radius or 12, o.splash.damage or 10, { exclude = v })
	end
	return res
end

function U.splash(ctx, center, radius, dmg, o)
	o = o or {}
	local hits = {}
	for _, c in ipairs(Hitbox.characters()) do
		if c ~= ctx.caster and c ~= o.exclude and not ctx.held[c] and U.valid(c, ctx) then
			local r = U.root(c)
			local d = Vector3.new(r.Position.X - center.X, 0, r.Position.Z - center.Z)
			if d.Magnitude <= radius and math.abs(r.Position.Y - center.Y) <= 10 then
				local dir = U.flat(d, Vector3.new(0, 0, -1))
				local res = baseHit(ctx, c, dmg, { dir = dir, knockback = o.knockback or 42, up = o.up or 18, stun = 0.8, power = 0.9, words = o.words })
				if res == "Hit" then
					table.insert(hits, c)
				end
			end
		end
	end
	return hits
end

------------------------------------------------------------------------
-- Ruée
------------------------------------------------------------------------
function U.rush(ctx, target, o)
	o = o or {}
	local c = ctx.caster
	local cr = U.root(c)
	if ctx.done or not cr then
		return false
	end
	U.anchor(ctx, c)
	local speed = o.speed or 120
	local contact = o.contact or 4.5
	local maxDist = o.maxDist or (ctx.range + 6)
	local cur = U.currentCF(ctx, c)
	if target and U.valid(target, ctx) and (U.root(target).Position - cur.Position).Magnitude <= maxDist then
		local t0 = os.clock()
		local last = os.clock()
		while U.alive(ctx) do
			local vr = U.root(target)
			if not vr or not U.valid(target, ctx) then
				break
			end
			cur = U.currentCF(ctx, c)
			local d = vr.Position - cur.Position
			local fd = Vector3.new(d.X, 0, d.Z)
			if fd.Magnitude <= contact and math.abs(d.Y) < 8 then
				U.place(ctx, c, U.facing(cur.Position, vr.Position))
				return true
			end
			if os.clock() - t0 > (o.maxTime or 0.45) then
				break
			end
			local dt = math.min(os.clock() - last, 0.05)
			last = os.clock()
			local step = math.min(speed * math.max(dt, 1 / 60), fd.Magnitude - contact * 0.8)
			local np = cur.Position + fd.Unit * step
			np = Vector3.new(np.X, cur.Position.Y + (vr.Position.Y - cur.Position.Y) * 0.35, np.Z)
			local safe = wallSafe(cur.Position, np, 1.5)
			if (safe - np).Magnitude > 0.05 then
				U.place(ctx, c, CFrame.lookAt(safe, safe + fd.Unit))
				break
			end
			U.place(ctx, c, CFrame.lookAt(np, np + fd.Unit))
			RunService.Heartbeat:Wait()
		end
		return false
	end
	-- ruée dans le vide
	local dir = U.flat(cur.LookVector)
	if target and U.root(target) then
		dir = U.flat(U.root(target).Position - cur.Position, dir)
	end
	local dest = wallSafe(cur.Position, cur.Position + dir * (o.whiffDist or 16), 2)
	local time = o.whiffTime or 0.25
	U.glide(ctx, c, CFrame.lookAt(dest, dest + dir), time, "Out")
	U.wait(ctx, time)
	return false
end

------------------------------------------------------------------------
-- Boucle de l'ulti (ancrages, verrous, annulation)
------------------------------------------------------------------------
local EASE = {
	Linear = function(a) return a end,
	Out = function(a) return 1 - (1 - a) * (1 - a) end,
	In = function(a) return a * a end,
	InOut = function(a) return a < 0.5 and 2 * a * a or 1 - (-2 * a + 2) ^ 2 / 2 end,
}

local cleanup
local function step(ctx)
	local c = ctx.caster
	if not c.Parent or not CharacterState.isAlive(c) or (ctx.player and ctx.player.Parent == nil) then
		ctx.aborted = true
	end
	if os.clock() - ctx.clock0 > MAX_TIME then
		ctx.aborted = true
	end
	-- lanceur entré dans la zone AFK : ulti annulée
	if CharacterState.inSafeZone(c) then
		ctx.aborted = true
	end
	local t = os.clock()
	-- victime perdue (morte, partie) avant le finisher : on arrête l'ulti après un court délai
	if not ctx.finished and not ctx.lostAt then
		for v in pairs(ctx.everHeld) do
			if not v.Parent or not CharacterState.isAlive(v) then
				ctx.lostAt = t
				break
			end
		end
	end
	if ctx.lostAt and not ctx.finished and t - ctx.lostAt > 0.5 then
		ctx.aborted = true
	end
	if ctx.aborted then
		task.spawn(cleanup, ctx)
		return
	end
	for model, pin in pairs(ctx.pins) do
		local r = U.root(model)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not r or not model.Parent or not hum or hum.Health <= 0 then
			U.release(ctx, model, true)
		elseif model ~= c and CharacterState.inSafeZone(model) then
			-- victime entrée dans la zone AFK : relâchée tout de suite (comme une victime perdue)
			U.release(ctx, model, false)
			if not ctx.finished then
				ctx.lostAt = ctx.lostAt or t
				ctx.everHeld[model] = nil
			end
		elseif pin.set and (r.Position - pin.set.Position).Magnitude > TELEPORT_DIST then
			-- téléporté par autre chose (fin de manche, zone…) : on ne le ramène pas de force
			U.release(ctx, model, false)
			if model == c then
				ctx.aborted = true
			elseif not ctx.finished then
				ctx.lostAt = ctx.lostAt or t
				ctx.everHeld[model] = nil
			end
		else
			if pin.glide then
				local g = pin.glide
				local a = math.clamp((t - g.t0) / g.dur, 0, 1)
				pin.cf = g.from:Lerp(g.to, (EASE[g.style] or EASE.Out)(a))
				if a >= 1 then
					pin.glide = nil
				end
			end
			if not r.Anchored then
				r.Anchored = true
			end
			r.CFrame = pin.cf
			pin.set = pin.cf
		end
	end
	-- verrous (toutes les 0,2 s) : lanceur sans attaque, victimes étourdies sans combo breaker
	if t - ctx.lastLock > 0.2 then
		ctx.lastLock = t
		local s = CharacterState.get(c)
		s.nextAttack = math.max(s.nextAttack, t + 0.4)
		s.gcdUntil = math.max(s.gcdUntil or 0, t + 0.4)
		for v in pairs(ctx.held) do
			if v.Parent and CharacterState.isAlive(v) then
				CharacterState.stun(v, 0.45)
				antiBreak(v)
			end
		end
	end
end

function cleanup(ctx)
	if ctx.done then
		return
	end
	ctx.done = true
	if ctx.conn then
		ctx.conn:Disconnect()
	end
	for model in pairs(ctx.pins) do
		U.release(ctx, model, ctx.held[model] ~= nil)
	end
	for model in pairs(ctx.held) do
		U.release(ctx, model, true)
	end
	local c = ctx.caster
	if active[c] == ctx then
		active[c] = nil
	end
	if c.Parent then
		c:SetAttribute("UltActive", nil)
		local s = CharacterState.get(c)
		s.nextAttack = math.min(s.nextAttack, os.clock() + 0.15)
	end
	if ctx.guard then
		local g = ctx.guard
		task.delay(0.35, function()
			if g.Parent then
				g:Destroy()
			end
		end)
	end
	pcall(U.fx, ctx, "End", {})
end

local function run(player, c, def, hint)
	seqCounter += 1
	local ctx = {
		caster = c, player = player, id = c:GetAttribute("CharacterName"), def = def, name = def.Name or "Ultimate",
		color = def.Color or Color3.new(1, 1, 1), color2 = def.Color2 or Color3.new(1, 1, 1),
		seq = seqCounter, t0 = now(), clock0 = os.clock(), lastLock = 0,
		range = def.Range or 25, angle = def.Angle or 70,
		pins = {}, held = {}, everHeld = {}, data = {},
		tempo = math.clamp(tonumber(def.Tempo) or DEFAULT_TEMPO, 0.8, 1.4), debt = 0,
	}
	active[c] = ctx
	c:SetAttribute("UltActive", true)
	-- invulnérable (bouclier invisible : CharacterState.isProtected le voit)
	local ff = Instance.new("ForceField")
	ff.Name = "UltGuard"
	ff.Visible = false
	ff.Parent = c
	ctx.guard = ff
	CharacterState.setBlocking(c, false)
	CharacterState.setRunning(c, false)
	CharacterState.clearStun(c)

	local ok0, err0 = pcall(function()
		local target = pickTarget(c, ctx.range, ctx.angle, hint)
		ctx.target = target
		local cr = U.root(c)
		if not cr then
			ctx.aborted = true
			return
		end
		local cf = cr.CFrame
		local tr = target and U.root(target)
		if tr then
			cf = U.facing(cr.Position, tr.Position)
		end
		U.anchor(ctx, c, cf)
		ctx.conn = RunService.Heartbeat:Connect(function()
			step(ctx)
		end)
	end)
	if not ok0 then
		warn("[UltimateService] start", ctx.id, err0)
		ctx.aborted = true
	end
	local startup = math.clamp(def.Startup or 1.0, 0.4, 1.2)
	if not ctx.aborted then
		pcall(U.fx, ctx, "Cutin", { dur = startup })
	end
	if not ctx.aborted and U.wait(ctx, startup) then
		ctx.paced = true
		-- la cible doit encore être valable (vivante, non protégée, à portée)
		local t = ctx.target
		local cr2 = U.root(c)
		if t and not (cr2 and U.valid(t, ctx) and (U.root(t).Position - cr2.Position).Magnitude <= ctx.range + 8) then
			t = nil
		end
		ctx.target = t
		local ok, err = pcall(def.Server, U, c, t, ctx)
		if not ok then
			warn("[UltimateService]", ctx.id, err)
		end
	end
	cleanup(ctx)
end

------------------------------------------------------------------------
-- Disponibilité (UltReady / UltName)
------------------------------------------------------------------------
local function onTransformed(c, name)
	local def = getDef(name)
	tokens[c] = nil
	if not def then
		c:SetAttribute("UltName", nil)
		c:SetAttribute("UltReady", false)
		return
	end
	c:SetAttribute("UltName", def.Name or "Ultimate")
	c:SetAttribute("UltReady", false)
	local token = {}
	tokens[c] = token
	if not hooked[c] then
		hooked[c] = true
		c:GetAttributeChangedSignal("Transformed"):Connect(function()
			if not c:GetAttribute("Transformed") then
				tokens[c] = nil
				c:SetAttribute("UltReady", false)
			end
		end)
	end
	task.delay(READY_DELAY, function()
		if tokens[c] == token and c.Parent and c:GetAttribute("Transformed") and CharacterState.isAlive(c) then
			c:SetAttribute("UltReady", true)
		end
	end)
end

local function onRequest(player, hint)
	if not Net.allow(player, "Ultimate", 3) then
		return
	end
	local c = player.Character
	if not c or not CharacterState.isAlive(c) or active[c] then
		return
	end
	if not c:GetAttribute("Transformed") or c:GetAttribute("UltReady") ~= true then
		return
	end
	if CharacterState.isStunned(c) or CharacterState.inSafeZone(c) then
		return -- étourdi, ou dans la zone AFK (ni ulti ni coups là-bas)
	end
	local def = getDef(c:GetAttribute("CharacterName"))
	if not def then
		return
	end
	c:SetAttribute("UltReady", false)
	tokens[c] = nil
	task.spawn(run, player, c, def, hint)
end

function UltimateService.isActive(c)
	return active[c] ~= nil
end

function UltimateService.init()
	FXR = Net.get("UltFX")
	Net.get("Ultimate").OnServerEvent:Connect(onRequest)
	Signals.Transformed:Connect(onTransformed)
	Signals.Died:Connect(function(c)
		if c then
			tokens[c] = nil
			if c:GetAttribute("UltReady") then
				c:SetAttribute("UltReady", false)
			end
		end
	end)
end

return UltimateService
