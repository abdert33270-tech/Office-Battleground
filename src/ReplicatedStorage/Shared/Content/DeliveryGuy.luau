--[[
	The Delivery Guy — personnage complet (format : voir Modules/ContentLoader).
	Passif Express Shipping : +10 % de vitesse en permanence ; les objets qu'il frappe ou lance font +15 % de dégâts.
	Attaques : Hand Truck Rush (ruée au diable : ramasse la 1re victime et l'emporte), Express Parcel (colis lobé qui
	           explose en chips de calage), Bubble Wrap (piège au sol : POP + chute).
	Transformation Same-Day Delivery : Tape Gun (scotch qui attire + SIGNED), Fragile Crate (caisse larguée du ciel qui
	           PLAQUE au sol), Return to Sender (contre : renvoie les projectiles, emballe et expédie l'attaquant).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local RED = Color3.fromRGB(220, 45, 40) -- couleur du perso
local BOX = Color3.fromRGB(200, 150, 90)
local BOX2 = Color3.fromRGB(175, 125, 70)
local TAPE = Color3.fromRGB(230, 200, 130)
local BUBBLE = Color3.fromRGB(190, 230, 255)
local DARK = Color3.fromRGB(40, 36, 34)
local STEEL = Color3.fromRGB(185, 190, 200)
local YELLOW = Color3.fromRGB(255, 205, 40)
local WHITE = Color3.fromRGB(250, 250, 250)
local PEANUT = Color3.fromRGB(250, 240, 215)

local M = { Id = "DeliveryGuy", Order = 10 }

M.Character = {
	DisplayName = "The Delivery Guy",
	Role = "Rushdown courier",
	Color = RED,
	Shirt = Color3.fromRGB(215, 50, 45), Pants = Color3.fromRGB(75, 58, 45), Tie = YELLOW,
	Passive = { Name = "Express Shipping", Desc = "+10% move speed. Items he swings or throws deal +15% damage." },
	Attacks = { "HandTruckRush", "ExpressParcel", "BubbleWrap" },
	Transformation = { Name = "Same-Day Delivery", Desc = "Winged cap and a tower of parcels strapped to his back.", Duration = 20, SpeedMultiplier = 1.2 },
	TransAttacks = { "TapeGun", "FragileCrate", "ReturnToSender" },
}

M.Attacks = {
	HandTruckRush = { Name = "Hand Truck Rush", Kind = "DelDolly", Desc = "Charge with your hand truck: scoop up the first coworker and ram them into whatever is ahead.", Prop = "DelDolly", Cooldown = 9, Anim = "DelDolly", Sound = "Dash",
		Windup = 0.25, Speed = 70, Time = 0.6, HitboxSize = Vector3.new(6, 6, 6), Damage = 10, Knockback = 48, KnockUp = 16, Stun = 1.0, Category = "Heavy", Power = 0.9,
		Words = { "SPECIAL DELIVERY!", "BEEP BEEP!" } },
	ExpressParcel = { Name = "Express Parcel", Kind = "DelParcel", Desc = "Lob a heavy parcel: it bursts into packing peanuts and hits everyone around.", Prop = "DelParcelProp", Cooldown = 7, Anim = "DelParcel", Sound = "Throw",
		Speed = 70, Up = 14, Gravity = 0.8, Range = 70, Radius = 7, Damage = 9, Knockback = 26, KnockUp = 14, Stun = 0.8, Category = "Heavy", Power = 0.7, Words = { "PARCEL!", "THUD!" } },
	BubbleWrap = { Name = "Bubble Wrap", Kind = "DelBubble", Desc = "Roll out bubble wrap: coworkers who step on it get POP-POP-POPPED off their feet.", Prop = "DelWrapRoll", Cooldown = 10, Anim = "DelBubble", Sound = "Whoosh",
		Offset = 2, Width = 9, Length = 16, WrapTime = 7, Damage = 4, Knockback = 6, KnockUp = 12, Stun = 0.9, Category = "Light", Power = 0.45,
		Words = { "POP!", "POP POP!", "SNAP!" }, Effects = { Trip = true } },
	TapeGun = { Name = "Tape Gun", Kind = "DelTape", Desc = "Fire a roll of packing tape: the first coworker hit is taped up in place, then stamped SIGNED.", Prop = "DelTapeGun", Cooldown = 9, Anim = "DelTape", Sound = "Whoosh",
		Windup = 0.25, Speed = 110, Range = 60, WrapTime = 1.4, Damage = 4, StampDamage = 7, Knockback = 32, KnockUp = 14, Stun = 0.9, Category = "Heavy", Power = 0.7, Words = { "SIGN HERE!", "SIGNED!" } },
	FragileCrate = { Name = "Fragile Crate", Kind = "DelCrate", Desc = "Call an air drop: a giant FRAGILE crate crashes down ahead and PINS everyone under it.", Prop = "DelScanner", Cooldown = 13, Anim = "DelCrate", Sound = "Whistle",
		Offset = 13, Radius = 9, Windup = 0.62, Damage = 15, Knockback = 0, Stun = 1.4, Category = "Heavy", GuardBreak = true, Power = 1.25,
		Words = { "FRAGILE!", "HANDLE WITH CARE!" }, Effects = { Pin = true } },
	ReturnToSender = { Name = "Return to Sender", Kind = "DelReturn", Desc = "Hold an open box (1.5s): projectiles bounce back, and whoever hits you gets boxed and shipped.", Prop = "DelOpenBox", Cooldown = 12, Anim = "DelReturn", Sound = "Clang",
		Duration = 1.5, Damage = 9, Knockback = 44, KnockUp = 18, Stun = 1.3, Category = "Heavy", Power = 0.9, Words = { "RETURN TO SENDER!", "NO REFUNDS!" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function dollyAnim()
	local f = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.1, y = 0.2 }, LS = { p = 1.1, y = 0.2 }, RJ = { ln = -0.25 }, RH = { p = -0.4 }, LH = { p = 0.5 } }, -- s'arc-boute
	}
	for i = 1, 4 do -- sprint penché derrière le diable
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.12 + i * 0.13, RS = { p = 0.95, y = 0.2 }, LS = { p = 0.95, y = 0.2 }, RJ = { ln = 0.8 }, RH = { p = 1.0 * s }, LH = { p = -1.0 * s } })
	end
	table.insert(f, { t = 0.78, RS = { p = 1.7, y = 0.1 }, LS = { p = 1.7, y = 0.1 }, RJ = { ln = 0.35 }, RH = { p = 0.7 }, LH = { p = -0.45 } }) -- poussée finale
	table.insert(f, { t = 0.95, RS = { p = 1.6 }, LS = { p = 1.6 }, RJ = { ln = 0.3 }, RH = { p = 0.6 }, LH = { p = -0.4 } })
	table.insert(f, { t = 1.1 })
	return f
end

M.Anims = {
	DelDolly = dollyAnim(), -- s'arc-boute, sprint penché en poussant le diable, grosse poussée
	DelParcel = { -- squat avec le colis en bas, soulève au-dessus de la tête en se cambrant, lob à deux mains
		{ t = 0 },
		{ t = 0.14, RS = { p = 0.35, y = 0.4 }, LS = { p = 0.35, y = 0.4 }, RJ = { ln = 0.6 }, RH = { p = 0.75 }, LH = { p = 0.75 } },
		{ t = 0.27, RS = { p = 3.05 }, LS = { p = 3.05 }, RJ = { ln = -0.5 }, RH = { p = -0.1 }, LH = { p = 0.3 } },
		{ t = 0.35, RS = { p = 2.0, y = 0.2 }, LS = { p = 2.0, y = 0.2 }, RJ = { ln = 0.4 }, LH = { p = 0.65 }, RH = { p = -0.4 } },
		{ t = 0.55, RS = { p = 1.9, y = 0.2 }, LS = { p = 1.9, y = 0.2 }, RJ = { ln = 0.32 }, LH = { p = 0.55 }, RH = { p = -0.35 } },
		{ t = 0.7 },
	},
	DelBubble = { -- rouleau levé, genou à terre en le déroulant, se relève et s'époussette les mains
		{ t = 0 },
		{ t = 0.15, RS = { p = 2.3 }, LS = { p = 2.3 }, RJ = { ln = -0.25 } },
		{ t = 0.3, RS = { p = 0.9, y = 0.3 }, LS = { p = 0.9, y = 0.3 }, RJ = { ln = 0.9 }, RH = { p = 1.05 }, LH = { p = -0.3 } },
		{ t = 0.55, RS = { p = 1.45, y = 0.3 }, LS = { p = 1.45, y = 0.3 }, RJ = { ln = 0.95 }, RH = { p = 1.05 }, LH = { p = -0.35 } },
		{ t = 0.7, RS = { p = 0.9, y = 1.0 }, LS = { p = 0.9, y = 1.0 }, RJ = { ln = -0.1 } },
		{ t = 0.78, RS = { p = 0.8, y = 0.6 }, LS = { p = 1.0, y = 1.2 }, RJ = { ln = -0.1 } },
		{ t = 0.86, RS = { p = 1.0, y = 1.2 }, LS = { p = 0.8, y = 0.6 }, RJ = { ln = -0.1 } },
		{ t = 0.98 },
	},
	DelTape = { -- vise à deux mains, recul du tir, puis souffle fièrement sur le dévidoir
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.6, y = 0.1 }, LS = { p = 1.5, y = 0.6 }, RJ = { ln = 0.1, tw = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.22, RS = { p = 1.62, y = 0.1 }, LS = { p = 1.52, y = 0.6 }, RJ = { ln = 0.12, tw = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.27, RS = { p = 2.1 }, LS = { p = 1.9, y = 0.6 }, RJ = { ln = -0.25, tw = 0.1 }, RH = { p = -0.1 }, LH = { p = 0.3 } },
		{ t = 0.42, RS = { p = 1.7 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = 0 } },
		{ t = 0.55, RS = { p = 2.5, y = 1.0 }, LS = { p = 0.3, r = -0.6 }, RJ = { ln = -0.2, tw = 0.3 }, RH = { p = -0.1 } },
		{ t = 0.85, RS = { p = 2.55, y = 1.0 }, LS = { p = 0.3, r = -0.6 }, RJ = { ln = -0.25, tw = 0.3 }, RH = { p = -0.1 } },
		{ t = 1.0 },
	},
	DelCrate = { -- scanne le ciel bras levé (signal au pilote), puis abat le bras vers le sol devant lui
		{ t = 0 },
		{ t = 0.15, RS = { p = 3.1, r = -0.2 }, LS = { p = 0.5, r = -0.9 }, RJ = { ln = -0.3, sd = 0.1 } },
		{ t = 0.3, RS = { p = 3.0, r = -0.6 }, LS = { p = 0.5, r = -0.9 }, RJ = { ln = -0.35, sd = 0.15 } },
		{ t = 0.45, RS = { p = 3.1, r = 0.15 }, LS = { p = 0.5, r = -0.9 }, RJ = { ln = -0.3, sd = 0.05 } },
		{ t = 0.58, RS = { p = 1.0, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = 0.55 }, RH = { p = 0.55 }, LH = { p = -0.35 } },
		{ t = 0.95, RS = { p = 1.05, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = 0.5 }, RH = { p = 0.5 }, LH = { p = -0.3 } },
		{ t = 1.1 },
	},
	DelReturn = { -- carton ouvert tenu devant à deux mains, accroupi bien calé, petits rebonds
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.6, y = 0.75 }, LS = { p = 1.6, y = 0.75 }, RJ = { ln = 0.3 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
		{ t = 0.5, RS = { p = 1.5, y = 0.75 }, LS = { p = 1.5, y = 0.75 }, RJ = { ln = 0.2 }, RH = { p = -0.4 }, LH = { p = 0.5 } },
		{ t = 0.9, RS = { p = 1.62, y = 0.75 }, LS = { p = 1.62, y = 0.75 }, RJ = { ln = 0.32 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
		{ t = 1.45, RS = { p = 1.55, y = 0.75 }, LS = { p = 1.55, y = 0.75 }, RJ = { ln = 0.25 }, RH = { p = -0.45 }, LH = { p = 0.55 } },
		{ t = 1.6 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
M.Props = {
	DelDolly = { -- diable avec un carton dessus
		{ Vector3.new(0.25, 4.2, 0.25), CFrame.new(-0.15, -3.1, 0), STEEL },
		{ Vector3.new(0.25, 4.2, 0.25), CFrame.new(-1.35, -3.1, 0), STEEL },
		{ Vector3.new(1.45, 0.2, 0.2), CFrame.new(-0.75, -1.2, 0), DARK },
		{ Vector3.new(1.45, 0.2, 0.2), CFrame.new(-0.75, -3.0, 0), STEEL },
		{ Vector3.new(1.6, 0.2, 1.2), CFrame.new(-0.75, -5.2, -0.5), STEEL },
		{ Vector3.new(0.35, 1.1, 1.1), CFrame.new(0.1, -4.95, 0.45), DARK, CYL },
		{ Vector3.new(0.35, 1.1, 1.1), CFrame.new(-1.6, -4.95, 0.45), DARK, CYL },
		{ Vector3.new(1.5, 1.4, 1.2), CFrame.new(-0.75, -4.4, -0.5), BOX },
		{ Vector3.new(1.52, 0.2, 1.22), CFrame.new(-0.75, -4.4, -0.5), TAPE },
	},
	DelParcelProp = { -- gros colis tenu à deux mains
		{ Vector3.new(2.0, 1.6, 1.6), CFrame.new(-0.75, -1.6, -0.6), BOX },
		{ Vector3.new(2.02, 0.25, 1.62), CFrame.new(-0.75, -1.6, -0.6), TAPE },
		{ Vector3.new(0.9, 0.5, 0.05), CFrame.new(-0.75, -1.95, -1.42), RED },
	},
	DelWrapRoll = { -- rouleau de papier bulle
		{ Vector3.new(2.6, 1.3, 1.3), CFrame.new(-0.75, -1.35, -0.45), BUBBLE, CYL },
		{ Vector3.new(2.7, 0.45, 0.45), CFrame.new(-0.75, -1.35, -0.45), WHITE, CYL },
		{ Vector3.new(2.4, 0.06, 1.2), CFrame.new(-0.75, -2.1, -0.9), BUBBLE },
	},
	DelTapeGun = { -- dévidoir de scotch
		{ Vector3.new(0.3, 0.9, 0.35), CFrame.new(0, -1.3, 0), RED },
		{ Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, -1.55, -0.55), TAPE, CYL },
		{ Vector3.new(0.42, 0.5, 0.5), CFrame.new(0, -1.55, -0.55), BOX2, CYL },
		{ Vector3.new(0.35, 0.12, 0.7), CFrame.new(0, -2.05, -0.95), STEEL },
	},
	DelScanner = { -- scanner de colis avec écran
		{ Vector3.new(0.45, 1.1, 0.7), CFrame.new(0, -1.45, -0.25), DARK },
		{ Vector3.new(0.05, 0.45, 0.5), CFrame.new(-0.24, -1.3, -0.25), Color3.fromRGB(120, 255, 140) },
		{ Vector3.new(0.3, 0.2, 0.2), CFrame.new(0, -2.05, -0.5), RED },
	},
	DelOpenBox = { -- grand carton ouvert, rabats écartés
		{ Vector3.new(2.6, 2.0, 2.0), CFrame.new(-0.75, -2.2, 0), BOX },
		{ Vector3.new(2.6, 0.1, 1.0), CFrame.new(-0.75, -3.35, -0.9) * CFrame.Angles(0.6, 0, 0), BOX2 },
		{ Vector3.new(2.6, 0.1, 1.0), CFrame.new(-0.75, -3.35, 0.9) * CFrame.Angles(-0.6, 0, 0), BOX2 },
		{ Vector3.new(1.0, 0.6, 0.05), CFrame.new(-0.75, -2.0, -1.03), RED },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : casquette, lunettes de soleil, sacoche en bandoulière, écusson ; colis sous le bras gauche
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.32, 0.38, 1.32), CFrame.new(0, 0.62, 0), RED) -- casquette
	prop(f, head, Vector3.new(1.22, 0.12, 0.7), CFrame.new(0, 0.48, -0.88), RED)
	prop(f, head, Vector3.new(0.5, 0.25, 0.06), CFrame.new(0, 0.66, -0.67), YELLOW) -- logo
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.42, 0.24, 0.06), CFrame.new(0.25 * s, 0.12, -0.62), DARK) -- lunettes de soleil
	end
	prop(f, head, Vector3.new(0.15, 0.06, 0.06), CFrame.new(0, 0.15, -0.63), DARK)
	prop(f, torso, Vector3.new(0.22, 2.5, 0.08), CFrame.new(0, 0, -0.56) * CFrame.Angles(0, 0, 0.75), DARK) -- bandoulière
	prop(f, torso, Vector3.new(0.5, 1.0, 1.1), CFrame.new(-1.15, -0.85, 0), Color3.fromRGB(110, 80, 55)) -- sacoche
	prop(f, torso, Vector3.new(0.55, 0.35, 0.06), CFrame.new(0.5, 0.5, -0.56), YELLOW) -- écusson
end

M.Signature = { Hand = "Left", Build = function(f, a, prop) -- colis coincé sous le bras gauche
	prop(f, a, Vector3.new(1.3, 1.1, 1.5), CFrame.new(0.15, -1.0, -0.3), BOX)
	prop(f, a, Vector3.new(1.32, 0.2, 1.52), CFrame.new(0.15, -1.0, -0.3), TAPE)
	prop(f, a, Vector3.new(0.05, 0.5, 0.8), CFrame.new(-0.52, -1.1, -0.3), RED) -- étiquette FRAGILE
end }

-- Transformation : casquette ailée, tour de colis dans le dos, bandes de vitesse sur les bras
function M.Transform(f, head, torso, c, prop)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.12, 0.7, 1.1), CFrame.new(0.72 * s, 0.75, 0.2) * CFrame.Angles(0.5, 0, -0.5 * s), WHITE) -- ailes
		prop(f, head, Vector3.new(0.1, 0.45, 0.8), CFrame.new(0.82 * s, 1.05, 0.35) * CFrame.Angles(0.6, 0, -0.7 * s), WHITE)
		local a = c:FindFirstChild(s < 0 and "Left Arm" or "Right Arm")
		if a then
			prop(f, a, Vector3.new(1.06, 0.2, 1.06), CFrame.new(0, 0.3, 0), YELLOW)
			prop(f, a, Vector3.new(1.06, 0.2, 1.06), CFrame.new(0, 0.0, 0), YELLOW)
		end
	end
	prop(f, torso, Vector3.new(1.7, 1.2, 1.1), CFrame.new(0, -0.2, 1.05), BOX) -- tour de colis
	prop(f, torso, Vector3.new(1.4, 1.0, 1.0), CFrame.new(0.1, 0.9, 1.0) * CFrame.Angles(0, 0.2, 0), BOX2)
	prop(f, torso, Vector3.new(1.1, 0.8, 0.9), CFrame.new(-0.1, 1.8, 1.0) * CFrame.Angles(0, -0.25, 0), BOX)
	prop(f, torso, Vector3.new(1.72, 0.2, 1.12), CFrame.new(0, -0.2, 1.05), TAPE)
	prop(f, torso, Vector3.new(0.7, 0.4, 0.05), CFrame.new(0.1, 0.9, 1.52), RED)
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
	-- Hand Truck Rush : ruée ; la 1re victime est chargée sur le diable, emportée, puis projetée
	DelDolly = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		Kit.fx({ id = "DelRun", a = attacker, dur = cfg.Time })
		local carried, release
		Kit.dash(attacker, dir, cfg.Speed, cfg.Time, function(root)
			if not api.CharacterState.isAlive(attacker) then
				return true
			end
			if not carried then
				local v = api.Hitbox.box(root.CFrame * CFrame.new(0, 0, -2.5), cfg.HitboxSize, attacker, 1)[1]
				if v and not Kit.isProtected(v) then
					carried = v
					api.CharacterState.stun(v, cfg.Time + 0.4)
					release = Kit.holdAt(v, attacker, Vector3.new(0, 0.6, -4))
					Kit.fx({ id = "DelScoop", v = v })
				end
			end
		end)
		if carried then
			release(true)
			local root = Kit.root(attacker)
			if api.CharacterState.isAlive(carried) and root then
				api.hit(attacker, carried, cfg, api.flat(Kit.root(carried).Position - root.Position, dir))
			end
			local vh = carried:FindFirstChildOfClass("Humanoid")
			task.delay(0.6, function()
				if vh and vh.Parent and vh.Health > 0 and not api.CharacterState.isStunned(carried) then
					vh.PlatformStand = false
				end
			end)
		end
	end,

	-- Express Parcel : colis lobé, explose en chips de calage à l'impact
	DelParcel = function(attacker, cfg, aim, api)
		task.wait(0.32)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1.5, 0) + dir * 2, dir = dir, speed = cfg.Speed, up = cfg.Up, gravity = cfg.Gravity, range = cfg.Range,
			size = Vector3.new(2.2, 1.7, 1.7), color = BOX, spin = 6,
			decorate = function(part)
				decor(part, Vector3.new(2.22, 0.3, 1.72), CFrame.new(), TAPE)
				decor(part, Vector3.new(1.0, 0.55, 0.05), CFrame.new(0, -0.3, -0.86), RED)
			end,
			onEnd = function(pos)
				Kit.fx({ id = "DelPeanuts", p = pos, r = cfg.Radius, a = attacker })
				for _, v in ipairs(Kit.inCircle(attacker, pos, cfg.Radius, 7)) do
					api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - pos, dir))
				end
			end,
		})
	end,

	-- Bubble Wrap : tapis de papier bulle au sol ; chaque ennemi qui marche dessus éclate des bulles et tombe
	DelBubble = function(attacker, cfg, aim, api)
		task.wait(0.3)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		local startPos = Kit.ground(root.Position + look * cfg.Offset)
		local far = Kit.safePoint(root.Position, root.Position + look * (cfg.Offset + cfg.Length), 1)
		local length = math.max(4, (Vector3.new(far.X, 0, far.Z) - Vector3.new(startPos.X, 0, startPos.Z)).Magnitude)
		local cf = CFrame.lookAt(startPos, startPos + look)
		Kit.fx({ id = "DelWrap", cf = cf, w = cfg.Width, l = length, dur = cfg.WrapTime })
		local last, pops = {}, {}
		local t0 = os.clock()
		while os.clock() - t0 < cfg.WrapTime do
			for _, v in ipairs(Kit.inRect(attacker, cf, cfg.Width, length, 5)) do
				if os.clock() - (last[v] or -10) > 1.3 and (pops[v] or 0) < 2 then -- 2 éclatements max par victime
					last[v] = os.clock()
					pops[v] = (pops[v] or 0) + 1
					local vp = Kit.root(v).Position
					Kit.fx({ id = "DelPop", p = vp - Vector3.new(0, 2.6, 0) })
					api.hit(attacker, v, cfg, look)
				end
			end
			task.wait(0.12)
		end
	end,

	-- Tape Gun : rouleau de scotch ; la 1re victime est scotchée sur place, puis tamponnée SIGNED (et éjectée)
	DelTape = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.new(0.6, 1.3, 1.3), color = TAPE, shape = CYL, spin = 30,
			decorate = function(part)
				decor(part, Vector3.new(0.62, 0.6, 0.6), CFrame.new(), BOX2)
			end,
			onHit = function(v, pos)
				if Kit.isProtected(v) then
					return
				end
				if api.hit(attacker, v, cfg, dir, { Knockback = 0, KnockUp = 0, Stun = cfg.WrapTime + 0.15, Category = "Light", Words = { "TAPED!", "SIGN HERE!" }, hitPos = pos }) == "Hit" then
					Kit.hold(v, cfg.WrapTime)
					Kit.fx({ id = "DelTaped", v = v, dur = cfg.WrapTime })
					task.delay(cfg.WrapTime, function()
						local vr = Kit.root(v)
						if vr and api.CharacterState.isAlive(v) and api.CharacterState.isAlive(attacker) then
							Kit.fx({ id = "DelSigned", v = v, p = vr.Position })
							local ar = Kit.root(attacker)
							api.hit(attacker, v, cfg, api.flat(ar and (vr.Position - ar.Position) or dir, dir), { Damage = cfg.StampDamage, Words = { "SIGNED!", "DELIVERED!" } })
						end
					end)
				end
			end,
		})
	end,

	-- Fragile Crate : caisse géante largée du ciel sur la zone visée : tout le monde dessous est PLAQUÉ
	DelCrate = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "DelCrateFX", p = center, fall = cfg.Windup, r = cfg.Radius, a = attacker, look = dir })
		task.wait(cfg.Windup)
		for _, v in ipairs(Kit.inCircle(attacker, center, cfg.Radius, 9)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir))
		end
		api.ZoneService.shatterAround(center, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
	end,

	-- Return to Sender : posture de contre (le contre lui-même est dans ServerInit)
	DelReturn = function(attacker, cfg, aim, api)
		local untilT = api.now() + cfg.Duration
		attacker:SetAttribute("DelReturnUntil", untilT)
		attacker:SetAttribute("TrayGuardUntil", untilT) -- les projectiles d'attaque rebondissent
		Kit.fx({ id = "DelGuard", a = attacker, dur = cfg.Duration })
		task.wait(cfg.Duration)
		if (attacker:GetAttribute("TrayGuardUntil") or 0) <= untilT then
			attacker:SetAttribute("TrayGuardUntil", 0)
		end
		attacker:SetAttribute("DelReturnUntil", 0)
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) + contre de Return to Sender
------------------------------------------------------------------------
function M.ServerInit(api)
	local CS = api.CombatService
	local now = function()
		return workspace:GetServerTimeNow()
	end
	local ret = M.Attacks.ReturnToSender
	-- Express Shipping : objets +15 %
	table.insert(CS.damageMods, function(p)
		local a = p.attacker
		if a and p.itemId and a:GetAttribute("CharacterName") == "DeliveryGuy" then
			p.damage *= 1.15
		end
	end)
	-- Return to Sender : le coup est annulé, l'attaquant est emballé puis expédié
	table.insert(CS.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if p.delCounter or not a or a == v or v:GetAttribute("CharacterName") ~= "DeliveryGuy" or (v:GetAttribute("DelReturnUntil") or 0) <= now() then
			return
		end
		v:SetAttribute("DelReturnUntil", 0)
		p.damage, p.knockback, p.up, p.stun = 0, 0, 0, 0
		p.launch, p.slam, p.pin, p.air = nil, nil, nil, nil
		p.category, p.power, p.words = "Light", 0.1, { "NOPE!" }
		local dir = -(p.dir or Vector3.new(0, 0, -1))
		task.spawn(function()
			if not a.Parent or Kit.isProtected(a) then
				return
			end
			api.CharacterState.stun(a, 1.1)
			Kit.hold(a, 0.75)
			Kit.fx({ id = "DelBoxed", v = a, dur = 0.75 })
			task.wait(0.75)
			local ar = Kit.root(a)
			if ar and api.CharacterState.isAlive(a) and api.CharacterState.isAlive(v) then
				CS.applyHit({
					attacker = v, victim = a, damage = ret.Damage, dir = dir, knockback = ret.Knockback, up = ret.KnockUp, stun = ret.Stun,
					category = ret.Category, power = ret.Power, words = ret.Words, weapon = ret.Name, delCounter = true, unblockable = true,
					hitPos = ar.Position + Vector3.new(0, 0.5, 0),
				})
			end
		end)
	end)
	-- Express Shipping : +10 % de vitesse tant qu'on joue le Delivery Guy
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
				local c = pl.Character
				if c and api.CharacterState.isAlive(c) then
					local s = api.CharacterState.get(c)
					local want = c:GetAttribute("CharacterName") == "DeliveryGuy"
					if want and s.speedMods.DelExpress == nil then
						api.CharacterState.setSpeedMod(c, "DelExpress", 1.1)
					elseif not want and s.speedMods.DelExpress ~= nil then
						api.CharacterState.setSpeedMod(c, "DelExpress", nil)
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local function boxModel(size)
	local parts = {}
	parts.body = Kit.part({ Size = size, Color = BOX })
	parts.tape = Kit.part({ Size = Vector3.new(size.X + 0.04, size.Y * 0.16, size.Z + 0.04), Color = TAPE })
	parts.label = Kit.part({ Size = Vector3.new(size.X * 0.7, size.Y * 0.3, 0.1), Color = RED })
	Kit.flatText(parts.label, "FRAGILE", WHITE, Enum.NormalId.Front)
	return parts
end

local function placeBox(parts, cf, size)
	parts.body.CFrame = cf
	parts.tape.CFrame = cf
	parts.label.CFrame = cf * CFrame.new(0, -size.Y * 0.18, -size.Z / 2 - 0.06)
end

M.MoveFX = {
	HandTruckRush = function(c, d, api)
		task.delay(0.15, function()
			api.afterimages(c, 0.5, RED)
			if Kit.mine(c) then
				api.CartoonFX.speedLines(0.5, YELLOW)
			end
		end)
	end,
	ExpressParcel = function(c, d, api)
		task.delay(0.3, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "SHIPPED!", YELLOW, 2.4, 0.7, 1.5)
				api.CartoonFX.sparks(r.Position + Vector3.new(0, 3, 0), 10, RED)
			end
		end)
	end,
	BubbleWrap = function(c, d, api)
		task.delay(0.3, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.puff(r.Position + r.CFrame.LookVector * 2.5 - Vector3.new(0, 2.5, 0), 1)
			end
		end)
	end,
	TapeGun = function(c, d, api)
		task.delay(0.22, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				api.CartoonFX.sparks(arm.Position - arm.CFrame.UpVector * 1.6, 10, TAPE)
				api.CartoonFX.sound("Spray", arm.Position, 0.7)
			end
		end)
	end,
	FragileCrate = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "INCOMING!", RED, 2.6, 0.8, 1)
		end
	end,
	ReturnToSender = function(c, d, api)
		api.rings(c, 2, 5, BOX, 0)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	-- poussière + « BEEP BEEP » pendant la ruée au diable
	Kit.on("DelRun", function(d)
		local c = d.a
		task.spawn(function()
			local t0 = os.clock()
			local n = 0
			while os.clock() - t0 < d.dur do
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				n += 1
				local pos = r.Position - Vector3.new(0, 2.7, 0) - r.CFrame.LookVector * 1.5
				local b = Kit.part({ Shape = BALL, Size = Vector3.one * 1.2, Position = pos, Color = Color3.fromRGB(215, 200, 180), Transparency = 0.3 })
				Kit.tween(b, 0.5, { Position = pos + Vector3.new(0, 1.2, 0), Size = Vector3.one * 2.6, Transparency = 1 })
				Debris:AddItem(b, 0.52)
				if n % 6 == 1 then
					Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "BEEP!", YELLOW, 1.8, 0.5, 1.5)
				end
				task.wait(0.035)
			end
		end)
	end)

	Kit.on("DelScoop", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if vr then
			CartoonFX.word(vr.Position + Vector3.new(0, 2.5, 0), "SCOOPED!", 0.8, "Heavy")
			CartoonFX.shards(vr.Position, 10, { BOX, TAPE }, 0.9)
		end
	end)

	-- le colis explose en chips de calage
	Kit.on("DelPeanuts", function(d)
		CartoonFX.sound("Crash", d.p, 1)
		CartoonFX.sound("Splat", d.p, 0.7)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r, RED)
		CartoonFX.puff(d.p, 2)
		for _ = 1, 30 do
			local pea = Kit.part({ Size = Vector3.new(0.45, 0.25, 0.7), CFrame = CFrame.new(d.p) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = PEANUT })
			local dir = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(0.2, 1.2), Kit.rng:NextNumber(-1, 1)).Unit
			local dest = d.p + dir * Kit.rng:NextNumber(3, d.r)
			Kit.tween(pea, 0.45, { CFrame = CFrame.new(dest) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0) })
			task.delay(0.45, function()
				Kit.tween(pea, 0.6, { CFrame = CFrame.new(dest - Vector3.new(0, dest.Y - d.p.Y - 0.2, 0)), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end)
			Debris:AddItem(pea, 1.1)
		end
		Kit.cubes(d.p + Vector3.new(0, 1, 0), 10, { BOX, BOX2, TAPE }, 1, 9, 0.6)
		Kit.floatText(d.p + Vector3.new(0, 3.5, 0), "DELIVERED!", YELLOW, 3, 0.9, 2)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.4)
		end
	end)

	-- tapis de papier bulle (grille de bulles)
	Kit.on("DelWrap", function(d)
		local sheet = Kit.part({ Size = Vector3.new(d.w, 0.1, 0.2), CFrame = d.cf * CFrame.new(0, 0.07, -0.1), Color = BUBBLE, Transparency = 0.35 })
		Kit.tween(sheet, 0.35, { Size = Vector3.new(d.w, 0.1, d.l), CFrame = d.cf * CFrame.new(0, 0.07, -d.l / 2) })
		local bubbles = {}
		task.delay(0.3, function()
			local step = 1.6
			for x = -d.w / 2 + step / 2, d.w / 2, step do
				for z = step / 2, d.l, step do
					local b = Kit.part({ Shape = BALL, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = d.cf * CFrame.new(x, 0.15, -z), Color = Color3.fromRGB(225, 245, 255), Transparency = 0.25 })
					table.insert(bubbles, b)
				end
			end
		end)
		CartoonFX.sound("Whoosh", d.cf.Position, 0.8)
		Kit.floatText(d.cf.Position + d.cf.LookVector * (d.l / 2) + Vector3.new(0, 2.5, 0), "BUBBLE WRAP!", BUBBLE, 3, 0.9, 1)
		task.delay(d.dur, function()
			Kit.tween(sheet, 0.3, { Transparency = 1 })
			for _, b in ipairs(bubbles) do
				Kit.tween(b, 0.3, { Transparency = 1 })
				Debris:AddItem(b, 0.32)
			end
		end)
		Debris:AddItem(sheet, d.dur + 0.35)
	end)

	Kit.on("DelPop", function(d)
		CartoonFX.sound("Squeak", d.p, 1)
		CartoonFX.sound("PlasticHit", d.p, 0.6)
		for i = 1, 3 do
			task.delay(i * 0.08, function()
				local pos = d.p + Vector3.new(Kit.rng:NextNumber(-1.2, 1.2), 0.5, Kit.rng:NextNumber(-1.2, 1.2))
				local ring = Kit.part({ Shape = BALL, Size = Vector3.one * 0.8, Position = pos, Color = WHITE, Transparency = 0.2 })
				Kit.tween(ring, 0.2, { Size = Vector3.one * 2.2, Transparency = 1 })
				Debris:AddItem(ring, 0.22)
				Kit.floatText(pos + Vector3.new(0, 1, 0), "POP!", BUBBLE, 1.8, 0.5, 1.5)
			end)
		end
	end)

	-- victime emballée de scotch (bandes qui tournent autour d'elle)
	Kit.on("DelTaped", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("Spray", vr.Position, 0.9)
		CartoonFX.sparks(vr.Position, 12, TAPE)
		local bands = {}
		for i = 1, 5 do
			bands[i] = Kit.part({ Shape = CYL, Size = Vector3.new(0.45, 3.0, 3.0), Color = i % 2 == 0 and TAPE or Color3.fromRGB(240, 215, 150), Transparency = 0.1 })
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not vr.Parent then
				conn:Disconnect()
				for _, b in ipairs(bands) do
					b:Destroy()
				end
				if vr.Parent then
					Kit.cubes(vr.Position, 14, { TAPE, BOX2 }, 0.6, 8, 0.4)
				end
				return
			end
			local grow = math.clamp(el / 0.25, 0, 1)
			for i, b in ipairs(bands) do
				local y = -2.4 + i * 0.85
				b.Size = Vector3.new(0.45, 3.0, 3.0) * Vector3.new(1, 0.6 + grow * 0.4, 0.6 + grow * 0.4)
				b.CFrame = vr.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, el * 6 * ((i % 2 == 0) and 1 or -1), 0.15 * math.sin(i)) * UP
			end
		end)
		Kit.floatText(vr.Position + Vector3.new(0, 3.5, 0), "TAPED!", TAPE, 2.6, 0.8, 1.2)
	end)

	-- tampon SIGNED sur la victime
	Kit.on("DelSigned", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("Bonk", vr.Position, 1)
		local stamp = Kit.part({ Size = Vector3.new(3.2, 1.2, 0.15), CFrame = vr.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-10)), Color = RED })
		Kit.flatText(stamp, "SIGNED", WHITE, Enum.NormalId.Front)
		Kit.flatText(stamp, "SIGNED", WHITE, Enum.NormalId.Back)
		local start = stamp.Size
		stamp.Size = start * 2
		Kit.tween(stamp, 0.15, { Size = start }, Enum.EasingStyle.Back)
		task.delay(0.9, function()
			Kit.tween(stamp, 0.25, { Transparency = 1 })
		end)
		Debris:AddItem(stamp, 1.2)
	end)

	-- caisse FRAGILE largée du ciel (avec parachute), impact, éclats de planches
	Kit.on("DelCrateFX", function(d)
		local size = Vector3.new(d.r * 1.15, d.r * 0.9, d.r * 1.15)
		local look = d.look or Vector3.new(0, 0, -1)
		local final = CFrame.lookAt(d.p + Vector3.new(0, size.Y / 2, 0), d.p + Vector3.new(0, size.Y / 2, 0) - look)
		local box = boxModel(size)
		local chute = Kit.part({ Shape = BALL, Size = Vector3.new(d.r * 1.6, d.r * 0.9, d.r * 1.6), Color = RED })
		local chute2 = Kit.part({ Size = Vector3.new(d.r * 1.65, 0.3, d.r * 1.65), Color = WHITE })
		local h = 45
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / d.fall, 0, 1)
			local y = h * (1 - k * k)
			local cf = final + Vector3.new(0, y, 0)
			placeBox(box, cf * CFrame.Angles(0, (1 - k) * 0.6, 0), size)
			chute.CFrame = cf + Vector3.new(0, size.Y / 2 + d.r * 0.8, 0)
			chute2.CFrame = cf + Vector3.new(0, size.Y / 2 + d.r * 0.45, 0)
			if k >= 1 then
				conn:Disconnect()
			end
		end)
		Kit.floatText(d.p + Vector3.new(0, 6, 0), "HANDLE WITH CARE!", RED, 3, d.fall, 1)
		task.delay(d.fall, function()
			CartoonFX.sound("GroundSlam", d.p, 1.3)
			CartoonFX.sound("WoodBreak", d.p, 1)
			CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, RED)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.25, BOX)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.8, RED)
			Kit.cubes(d.p + Vector3.new(0, 1, 0), 20, { BOX, BOX2, TAPE, RED }, 1.1, 13, 0.6)
			Kit.tween(chute, 0.4, { Size = chute.Size * Vector3.new(1.3, 0.1, 1.3), Transparency = 1 })
			Kit.tween(chute2, 0.4, { Transparency = 1 })
			if Kit.mine(d.a) then
				CartoonFX.shake(1)
				CartoonFX.impactFrame(0.8)
			end
			task.delay(0.9, function()
				-- la caisse se brise en planches
				Kit.cubes(box.body.Position, 16, { BOX, BOX2 }, 1.4, 8, 0.5)
				for _, p in pairs(box) do
					p:Destroy()
				end
			end)
		end)
		Debris:AddItem(chute, d.fall + 0.45)
		Debris:AddItem(chute2, d.fall + 0.45)
	end)

	-- posture de contre : cadre carton + flèches « RETURN »
	Kit.on("DelGuard", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "RETURN TO SENDER", BOX, 3, 0.9, 1)
		local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.2, 7, 7), Color = BOX, Transparency = 0.45 })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not r.Parent or (d.a:GetAttribute("DelReturnUntil") or 0) <= 0 and el > 0.2 then
				conn:Disconnect()
				ring:Destroy()
				return
			end
			ring.CFrame = CFrame.new(r.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, el * 4, 0) * UP
		end)
	end)

	-- l'attaquant contré est emballé dans un carton, puis expédié
	Kit.on("DelBoxed", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("Clang", vr.Position, 1)
		CartoonFX.word(vr.Position + Vector3.new(0, 3, 0), "RETURN TO SENDER!", 1, "Heavy")
		local size = Vector3.new(4.4, 6, 3.4)
		local box = boxModel(size)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if os.clock() - t0 > d.dur or not vr.Parent then
				conn:Disconnect()
				if vr.Parent then
					Kit.cubes(vr.Position, 18, { BOX, BOX2, TAPE }, 1, 10, 0.5)
				end
				for _, p in pairs(box) do
					p:Destroy()
				end
				return
			end
			placeBox(box, vr.CFrame * CFrame.new(0, -0.4, 0), size)
		end)
	end)

	-- aura de transformation : petits colis qui volent autour
	task.spawn(function()
		while true do
			task.wait(0.35)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "DeliveryGuy" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local a = Kit.rng:NextNumber(0, math.pi * 2)
						local pos = r.Position + Vector3.new(math.cos(a) * 2.5, Kit.rng:NextNumber(-1.5, 1.5), math.sin(a) * 2.5)
						local p = Kit.part({ Size = Vector3.one * 0.5, CFrame = CFrame.new(pos), Color = BOX })
						Kit.tween(p, 0.7, { CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(1, 2, 0), Transparency = 1 })
						Debris:AddItem(p, 0.72)
					end
				end
			end
		end
	end)
end

return M
