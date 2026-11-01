--[[
	The Accountant — personnage complet (format : voir Modules/ContentLoader).
	Passif Compound Interest : chaque coup sur la même cible (moins de 2 s d'écart) ajoute +10 % de dégâts (max +50 %).
	Attaques : Calculator Throw (rebondit sur les murs puis vers une 2e cible), Tax Audit (saisie + 3 coups de tampon : +4 sur les 3 prochains coups),
	Spreadsheet Slam (grille au sol qui envoie en l'air).
	Transformation Fiscal Year End : Number Crunch (rafale), Budget Cut (ruée ciseaux en avant qui traverse tout le monde),
	Bankrupt (coffre-fort géant qui tombe du ciel : plaque au sol, vole de l'Overtime).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL = Kit.CYL, Kit.BALL
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local GREEN = Color3.fromRGB(90, 200, 90)
local DGREEN = Color3.fromRGB(40, 140, 60)
local CALC = Color3.fromRGB(60, 65, 75)
local LCD = Color3.fromRGB(175, 205, 150)
local PAPER = Color3.fromRGB(250, 250, 245)
local RED = Color3.fromRGB(220, 40, 40)
local GOLD = Color3.fromRGB(255, 205, 50)
local DIGITS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "+", "-", "%", "=", "$" }

local M = { Id = "Accountant", Order = 6 }

M.Character = {
	DisplayName = "The Accountant",
	Role = "Combo stacker",
	Color = GREEN,
	Shirt = Color3.fromRGB(235, 225, 190), Pants = Color3.fromRGB(115, 95, 75), Tie = DGREEN,
	Passive = { Name = "Compound Interest", Desc = "Each hit on the same target within 2s adds +10% damage (up to +50%)." },
	Attacks = { "CalculatorThrow", "TaxAudit", "SpreadsheetSlam" },
	Transformation = { Name = "Fiscal Year End", Desc = "LCD glasses, receipt tape and a storm of numbers.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "NumberCrunch", "BudgetCut", "Bankrupt" },
}

M.Attacks = {
	CalculatorThrow = { Name = "Calculator Throw", Kind = "AcctCalc", Desc = "Hurl a calculator that ricochets off walls and bounces into a second coworker.", Prop = "AcctCalc", Cooldown = 6, Anim = "CalcThrow", Sound = "Throw",
		Windup = 0.14, Speed = 95, Range = 60, Bounces = 2, Damage = 6, Knockback = 12, KnockUp = 5, Stun = 0.7, Category = "Projectile", Power = 0.5, Words = { "CLACK!", "DO THE MATH!" } },
	TaxAudit = { Name = "Tax Audit", Kind = "AcctStampGrab", Desc = "Grab the closest coworker and stamp AUDIT on them 3 times: your next 3 hits on them deal +4 damage.", Prop = "AcctStamp", Cooldown = 9, Anim = "TaxAudit", Sound = "Whoosh", Unblockable = true,
		Windup = 0.1, HitboxOffset = 3.5, HitboxSize = Vector3.new(5, 6, 6), StampDamage = 2, Damage = 5, Knockback = 34, KnockUp = 10, Stun = 0.9, Category = "Heavy", Power = 0.75, Words = { "AUDITED!", "FILED!" },
		AuditHits = 3, AuditBonus = 4, AuditTime = 8 },
	SpreadsheetSlam = { Name = "Spreadsheet Slam", Kind = "Melee", Desc = "Slam a giant spreadsheet on the floor: everyone on the grid gets launched.", Prop = "AcctSheet", Cooldown = 8, Anim = "SpreadsheetSlam", Sound = "Whoosh",
		Windup = 0.32, HitboxOffset = 6, HitboxSize = Vector3.new(12, 6, 12), Damage = 10, Knockback = 6, Launch = Vector3.new(6, 46, 0), Stun = 1.0, Category = "Heavy", Power = 0.85,
		Words = { "SPREADSHEET SLAM!", "CTRL+S!" } },
	NumberCrunch = { Name = "Number Crunch", Kind = "Melee", Desc = "Hammer them with calculator bonks while numbers fly, then hit the TOTAL.", Prop = "AcctCalc", Cooldown = 8, Anim = "NumberCrunch", Sound = "Punch",
		Hits = 7, Interval = 0.08, HitboxOffset = 3, HitboxSize = Vector3.new(6, 6, 6.5), Damage = 2, Knockback = 3, Stun = 0.45, Category = "Light", Power = 0.3,
		Words = { "1+1!", "x2!", "%!", "+7!", "=!" },
		Final = { Damage = 7, Knockback = 48, KnockUp = 16, Stun = 0.9, Category = "Heavy", Power = 1, Words = { "TOTAL!", "SUM!" } } },
	BudgetCut = { Name = "Budget Cut", Kind = "Lunge", Desc = "Charge forward with giant open scissors and snip through EVERYONE in your path.", Prop = "AcctScissors", Cooldown = 8, Pierce = true, Anim = "BudgetCut", Sound = "Dash",
		Speed = 92, Time = 0.38, HitboxSize = Vector3.new(8, 6, 8), Damage = 11, Knockback = 42, KnockUp = 14, Stun = 0.9, Category = "Heavy", Power = 0.95, Material = "Metal",
		Words = { "BUDGET CUT!", "SNIP!" } },
	Bankrupt = { Name = "Bankrupt", Kind = "AcctBankrupt", Desc = "A giant safe crashes down on the coworker in front of you: PINS everyone under it, steals 20 Overtime from each (paid back when your Overtime ends) and heals you.", Cooldown = 15, Anim = "Bankrupt", Sound = "Ding",
		Windup = 0.6, Range = 32, Offset = 12, Radius = 9, Steal = 20, HealPer = 5, Damage = 14, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", Power = 1.2, Words = { "BANKRUPT!", "CHA-CHING!" }, Effects = { Pin = true } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function crunchAnim()
	local f = { { t = 0 } }
	local t = 0
	for i = 1, 6 do -- coups de marteau verticaux alternés
		local right = i % 2 == 1
		t += 0.04
		table.insert(f, { t = t, RS = { p = right and 2.8 or 1.0 }, LS = { p = right and 1.0 or 2.8 }, RJ = { ln = 0.1, tw = right and 0.15 or -0.15 }, LH = { p = 0.4 }, RH = { p = -0.2 } })
		t += 0.04
		table.insert(f, { t = t, RS = { p = right and 1.1 or 2.4 }, LS = { p = right and 2.4 or 1.1 }, RJ = { ln = 0.35, tw = right and -0.1 or 0.1 }, LH = { p = 0.4 }, RH = { p = -0.2 } })
	end
	table.insert(f, { t = t + 0.12, RS = { p = 3.2 }, LS = { p = 3.2 }, RJ = { ln = -0.4 }, RH = { p = 0.3 }, LH = { p = 0.3 } }) -- les deux mains en l'air
	table.insert(f, { t = t + 0.2, RS = { p = 1.0, y = 0.2 }, LS = { p = 1.0, y = 0.2 }, RJ = { ln = 0.75 }, LH = { p = 0.8 }, RH = { p = -0.3 } }) -- TOTAL !
	table.insert(f, { t = t + 0.42, RS = { p = 1.0, y = 0.2 }, LS = { p = 1.0, y = 0.2 }, RJ = { ln = 0.65 }, LH = { p = 0.7 } })
	table.insert(f, { t = t + 0.58 })
	return f
end

M.Anims = {
	CalcThrow = { -- lancer de base-ball : genou levé, bras très en arrière, lancer par-dessus
		{ t = 0 },
		{ t = 0.1, RS = { p = -0.6, r = -0.5 }, LS = { p = 1.4 }, RJ = { tw = -0.7, ln = -0.15 }, LH = { p = 1.3 } },
		{ t = 0.15, RS = { p = 3.1, r = -0.3 }, LS = { p = 0.6 }, RJ = { tw = -0.4, ln = -0.2 }, LH = { p = 0.6 } },
		{ t = 0.22, RS = { p = 1.2, y = 0.3 }, LS = { p = -0.4 }, RJ = { tw = 0.7, ln = 0.35 }, LH = { p = 0.7 }, RH = { p = -0.4 } },
		{ t = 0.42, RS = { p = 0.9, y = 0.3 }, RJ = { tw = 0.6, ln = 0.3 }, LH = { p = 0.6 } },
		{ t = 0.58 },
	},
	TaxAudit = { -- attrape au col de la main gauche, trois coups de tampon de haut en bas, puis repousse à deux mains
		{ t = 0 },
		{ t = 0.08, LS = { p = 1.85, y = 0.3 }, RS = { p = 0.6 }, RJ = { ln = 0.35 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.2, LS = { p = 1.7, y = 0.3 }, RS = { p = 3.1, r = -0.2 }, RJ = { ln = -0.15, tw = 0.25 }, LH = { p = 0.5 } },
		{ t = 0.28, LS = { p = 1.7, y = 0.3 }, RS = { p = 1.2, y = 0.2 }, RJ = { ln = 0.45, tw = -0.1 }, LH = { p = 0.6 } },
		{ t = 0.4, LS = { p = 1.7, y = 0.3 }, RS = { p = 3.1, r = -0.2 }, RJ = { ln = -0.15, tw = 0.25 }, LH = { p = 0.5 } },
		{ t = 0.48, LS = { p = 1.7, y = 0.3 }, RS = { p = 1.2, y = 0.2 }, RJ = { ln = 0.45, tw = -0.1 }, LH = { p = 0.6 } },
		{ t = 0.6, LS = { p = 1.7, y = 0.3 }, RS = { p = 3.25, r = -0.25 }, RJ = { ln = -0.25, tw = 0.35 }, LH = { p = 0.5 } },
		{ t = 0.68, LS = { p = 1.7, y = 0.3 }, RS = { p = 1.1, y = 0.2 }, RJ = { ln = 0.6, tw = -0.15 }, LH = { p = 0.7 }, RH = { p = -0.4 } },
		{ t = 0.78, RS = { p = 0.4, y = -0.6 }, LS = { p = 0.4, y = -0.6 }, RJ = { ln = -0.2 } },
		{ t = 0.86, RS = { p = 1.95, y = 0.45 }, LS = { p = 1.95, y = 0.45 }, RJ = { ln = 0.55 }, LH = { p = 0.85 }, RH = { p = -0.5 } },
		{ t = 1.05, RS = { p = 1.85, y = 0.45 }, LS = { p = 1.85, y = 0.45 }, RJ = { ln = 0.45 }, LH = { p = 0.7 } },
		{ t = 1.2 },
	},
	SpreadsheetSlam = { -- feuille brandie, le buste penché sur le côté, puis claquée en diagonale au sol
		{ t = 0 },
		{ t = 0.16, RS = { p = 3.0, r = -0.4 }, LS = { p = 3.0, r = 0.1 }, RJ = { ln = -0.3, sd = -0.25, tw = -0.4 }, RH = { r = -0.25 } },
		{ t = 0.3, RS = { p = 3.2, r = -0.3 }, LS = { p = 3.1 }, RJ = { ln = -0.38, sd = -0.3, tw = -0.45 }, RH = { r = -0.25 } },
		{ t = 0.38, RS = { p = 0.9, y = 0.4 }, LS = { p = 0.9, y = 0.4 }, RJ = { ln = 0.85, sd = 0.15, tw = 0.25 }, RH = { p = 1.0 }, LH = { p = -0.3 } },
		{ t = 0.7, RS = { p = 0.9, y = 0.4 }, LS = { p = 0.9, y = 0.4 }, RJ = { ln = 0.75, sd = 0.12, tw = 0.2 }, RH = { p = 0.9 }, LH = { p = -0.3 } },
		{ t = 0.88 },
	},
	NumberCrunch = crunchAnim(),
	BudgetCut = { -- accroupi ciseaux armés, ruée ciseaux ouverts devant, grand « snip » qui balaie en fin de course
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.2, y = -1.2, r = -0.6 }, LS = { p = 0.6 }, RJ = { tw = -0.9, ln = 0.5 }, RH = { p = 1.0 }, LH = { p = -0.5 } },
		{ t = 0.12, RS = { p = 1.75, y = 0.1 }, LS = { p = -0.9 }, RJ = { tw = 0.3, ln = 0.6 }, RH = { p = -0.8 }, LH = { p = 1.1 } },
		{ t = 0.24, RS = { p = 1.75, y = 0.1 }, LS = { p = -0.9 }, RJ = { tw = 0.3, ln = 0.6 }, RH = { p = 1.0 }, LH = { p = -0.8 } },
		{ t = 0.36, RS = { p = 1.55, y = 1.35 }, LS = { p = -0.6, r = -0.4 }, RJ = { tw = 1.15, ln = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.8 } },
		{ t = 0.55, RS = { p = 1.45, y = 1.2 }, LS = { p = -0.5, r = -0.4 }, RJ = { tw = 0.95, ln = 0.25 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.72 },
	},
	Bankrupt = { -- se frotte les mains, lève le bras… et tire le levier de la machine à sous : cha-ching !
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.4, y = 0.9 }, LS = { p = 1.4, y = 0.9 }, RJ = { ln = 0.2 } },
		{ t = 0.18, RS = { p = 1.55, y = 1.0 }, LS = { p = 1.3, y = 0.8 }, RJ = { ln = 0.22 } },
		{ t = 0.26, RS = { p = 1.3, y = 0.85 }, LS = { p = 1.55, y = 1.0 }, RJ = { ln = 0.2 } },
		{ t = 0.4, RS = { p = 3.2, r = -0.2 }, LS = { p = 1.2, r = -0.6 }, RJ = { ln = -0.35, tw = 0.3 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.55, RS = { p = 3.35, r = -0.25 }, LS = { p = 1.2, r = -0.6 }, RJ = { ln = -0.42, tw = 0.35 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.62, RS = { p = 0.55, y = 0.3 }, LS = { p = 1.0, r = -0.6 }, RJ = { ln = 0.75, tw = -0.2 }, RH = { p = 0.95 }, LH = { p = -0.4 } },
		{ t = 0.9, RS = { p = 0.65, y = 0.3 }, LS = { p = 1.0, r = -0.55 }, RJ = { ln = 0.62, tw = -0.15 }, RH = { p = 0.85 }, LH = { p = -0.35 } },
		{ t = 1.05 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
local SHEET = { { Vector3.new(3.6, 0.1, 2.8), CFrame.new(-0.7, -1.35, 0), PAPER }, { Vector3.new(3.62, 0.12, 0.55), CFrame.new(-0.7, -1.35, -1.12), DGREEN } }
for i = -1, 1 do
	table.insert(SHEET, { Vector3.new(3.62, 0.12, 0.07), CFrame.new(-0.7, -1.35, i * 0.6 + 0.2), GREEN })
	table.insert(SHEET, { Vector3.new(0.07, 0.12, 2.82), CFrame.new(-0.7 + i * 1.1, -1.35, 0), GREEN })
end

M.Props = {
	AcctCalc = {
		{ Vector3.new(0.95, 1.35, 0.25), CFrame.new(0, -1.55, -0.2), CALC },
		{ Vector3.new(0.72, 0.32, 0.05), CFrame.new(0, -1.1, -0.34), LCD },
		{ Vector3.new(0.72, 0.62, 0.05), CFrame.new(0, -1.72, -0.34), Color3.fromRGB(215, 215, 220) },
		{ Vector3.new(0.2, 0.2, 0.06), CFrame.new(0.22, -1.95, -0.35), Color3.fromRGB(255, 150, 40) },
	},
	AcctStamp = {
		{ Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, -1.1, 0), Color3.fromRGB(120, 70, 40), BALL },
		{ Vector3.new(0.3, 0.7, 0.3), CFrame.new(0, -1.5, 0), Color3.fromRGB(120, 70, 40) },
		{ Vector3.new(1.0, 0.25, 0.8), CFrame.new(0, -1.95, 0), RED },
	},
	AcctSheet = SHEET,
	AcctScissors = {
		{ Vector3.new(0.18, 0.8, 0.8), CFrame.new(0.28, -1.15, 0), RED, CYL },
		{ Vector3.new(0.18, 0.8, 0.8), CFrame.new(-0.28, -1.15, 0), RED, CYL },
		{ Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -1.75, 0), GOLD, BALL },
		{ Vector3.new(0.16, 3.4, 0.45), CFrame.new(0, -1.75, 0) * CFrame.Angles(0, 0, 0.22) * CFrame.new(0, -1.7, 0), Color3.fromRGB(205, 210, 220) },
		{ Vector3.new(0.16, 3.4, 0.45), CFrame.new(0, -1.75, 0) * CFrame.Angles(0, 0, -0.22) * CFrame.new(0, -1.7, 0), Color3.fromRGB(205, 210, 220) },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : visière verte + lunettes rondes + pochette de stylos ; calculatrice à la main gauche
------------------------------------------------------------------------
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.32, 0.18, 1.32), CFrame.new(0, 0.38, 0), DGREEN) -- bandeau
	local brim = prop(f, head, Vector3.new(1.25, 0.08, 0.7), CFrame.new(0, 0.36, -0.85) * CFrame.Angles(-0.25, 0, 0), GREEN)
	brim.Transparency = 0.25
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.05, 0.4, 0.4), CFrame.new(0.26 * s, 0.05, -0.62) * ALONG_Z, Color3.fromRGB(90, 60, 40), CYL)
		prop(f, head, Vector3.new(0.05, 0.3, 0.3), CFrame.new(0.26 * s, 0.05, -0.64) * ALONG_Z, Color3.fromRGB(215, 240, 255), CYL)
	end
	prop(f, head, Vector3.new(0.14, 0.05, 0.05), CFrame.new(0, 0.08, -0.63), Color3.fromRGB(90, 60, 40))
	prop(f, torso, Vector3.new(0.5, 0.5, 0.08), CFrame.new(0.5, 0.35, -0.56), PAPER) -- pochette
	prop(f, torso, Vector3.new(0.09, 0.4, 0.09), CFrame.new(0.38, 0.65, -0.56), RED)
	prop(f, torso, Vector3.new(0.09, 0.4, 0.09), CFrame.new(0.52, 0.68, -0.56), Color3.fromRGB(40, 90, 230))
	prop(f, torso, Vector3.new(0.09, 0.4, 0.09), CFrame.new(0.65, 0.63, -0.56), Color3.fromRGB(30, 30, 30))
end

M.Signature = { Hand = "Left", Build = function(f, a, prop) -- calculatrice de bureau
	-- tenue devant la main, écran tourné vers l'avant (lisible de face)
	prop(f, a, Vector3.new(1.0, 1.4, 0.28), CFrame.new(0, -1.55, -0.62), Color3.fromRGB(80, 90, 110))
	prop(f, a, Vector3.new(0.78, 0.34, 0.06), CFrame.new(0, -1.08, -0.78), LCD)
	prop(f, a, Vector3.new(0.78, 0.66, 0.06), CFrame.new(0, -1.7, -0.78), Color3.fromRGB(225, 225, 230))
	prop(f, a, Vector3.new(0.22, 0.22, 0.07), CFrame.new(0.24, -1.92, -0.79), Color3.fromRGB(255, 150, 40))
	prop(f, a, Vector3.new(0.22, 0.22, 0.07), CFrame.new(-0.24, -1.92, -0.79), GREEN)
end }

-- Transformation : lunettes LCD, rouleau de ticket de caisse en bandoulière, insigne $
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.3, 0.36, 0.1), CFrame.new(0, 0.07, -0.68), CALC)
	for _, s in ipairs({ -1, 1 }) do
		local l = prop(f, head, Vector3.new(0.48, 0.24, 0.06), CFrame.new(0.28 * s, 0.07, -0.74), Color3.fromRGB(120, 255, 140))
		l.Transparency = 0.1
	end
	prop(f, torso, Vector3.new(0.6, 2.8, 0.06), CFrame.new(0.05, 0, -0.56) * CFrame.Angles(0, 0, 0.6), PAPER) -- ticket
	prop(f, torso, Vector3.new(0.6, 2.8, 0.06), CFrame.new(0.05, 0, 0.56) * CFrame.Angles(0, 0, -0.6), PAPER)
	prop(f, torso, Vector3.new(0.5, 0.7, 0.7), CFrame.new(-0.95, 1.0, 0) * Kit.UPRIGHT, PAPER, CYL) -- rouleau sur l'épaule
	prop(f, torso, Vector3.new(0.5, 0.5, 0.1), CFrame.new(-0.55, 0.45, -0.6), GOLD) -- insigne
end

------------------------------------------------------------------------
-- Serveur
------------------------------------------------------------------------
local function calcDecor(part)
	local function add(size, off, color)
		local p = Kit.sPart({ Size = size, CFrame = part.CFrame * off, Color = color })
		local w = Instance.new("WeldConstraint")
		w.Part0 = part
		w.Part1 = p
		w.Parent = p
		p.Anchored = false
		p.Massless = true
		p.Parent = part
	end
	add(Vector3.new(0.8, 0.05, 0.4), CFrame.new(0, 0.15, -0.4), LCD)
	add(Vector3.new(0.8, 0.05, 0.6), CFrame.new(0, 0.15, 0.25), Color3.fromRGB(215, 215, 220))
end

local function stampDecor(part)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = "AUDIT"
	l.Parent = gui
end

M.Kinds = {
	-- Calculator Throw : rebondit sur 2 murs, et après une cible file vers la plus proche
	AcctCalc = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local hits = 0
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range, bounces = cfg.Bounces,
			size = Vector3.new(1.1, 0.28, 1.5), color = CALC, spin = 16, decorate = calcDecor,
			onHit = function(v, pos, vel)
				hits += 1
				api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos })
				if hits >= 2 then
					return nil
				end
				-- rebond vers la cible la plus proche
				local best, bestD = nil, 20
				for _, o in ipairs(Kit.enemies(attacker)) do
					if o ~= v then
						local d = (Kit.root(o).Position - pos).Magnitude
						if d < bestD then
							best, bestD = o, d
						end
					end
				end
				if best then
					return (Kit.root(best).Position - pos).Unit * cfg.Speed
				end
				return nil
			end,
		})
	end,

	-- Tax Audit : saisie + 3 coups de tampon (marque la cible : bonus sur nos 3 prochains coups, voir passif), puis repousse
	AcctStampGrab = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local cf = root.CFrame * CFrame.new(0, 0, -cfg.HitboxOffset)
		local victim = api.Hitbox.box(cf, cfg.HitboxSize + Vector3.one * 2, attacker, 1)[1]
		if not victim or Kit.isProtected(victim) then
			Kit.fx({ id = "AcctStampMiss", a = attacker })
			return
		end
		local vr = Kit.root(victim)
		local look = Kit.flat(root.CFrame.LookVector)
		Kit.rawFX({ k = "Grab", v = victim, a = attacker, p = vr.Position })
		api.CharacterState.stun(victim, 1.1)
		Kit.hold(victim, 0.8)
		local stamp = { Name = cfg.Name, Damage = cfg.StampDamage, Knockback = 0, KnockUp = 0, Stun = 0.6, Category = "Light", Power = 0.3, Words = { "STAMP!", "AUDIT!", "FINED!" }, Unblockable = true }
		for _, t in ipairs({ 0.18, 0.2, 0.2 }) do
			task.wait(t)
			if not api.CharacterState.isAlive(attacker) or api.CharacterState.isStunned(attacker) or not api.CharacterState.isAlive(victim) then
				return
			end
			Kit.hold(victim, 0.4)
			api.hit(attacker, victim, stamp, look, { hitPos = vr.Position + Vector3.new(0, 1, 0) })
			Kit.fx({ id = "AcctStampHit", v = victim, a = attacker })
		end
		victim:SetAttribute("AuditBy", attacker.Name)
		victim:SetAttribute("AuditHits", cfg.AuditHits)
		victim:SetAttribute("AuditBonus", cfg.AuditBonus)
		victim:SetAttribute("AuditUntil", Kit.now() + cfg.AuditTime)
		Kit.fx({ id = "AcctStamped", v = victim })
		task.wait(0.17)
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) then
			local h = vr:FindFirstChild("ContentHold")
			if h then
				h:Destroy()
			end
			api.hit(attacker, victim, cfg, Kit.flat(root.CFrame.LookVector), { Words = { "FILED!", "NEXT!" } })
		end
	end,

	-- Bankrupt : coffre-fort géant qui tombe du ciel sur la cible devant ; plaque, vole de l'Overtime (rendu à la fin) et soigne
	AcctBankrupt = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local best, bestD = nil, math.huge
		for _, v in ipairs(Kit.enemies(attacker)) do
			local to = Kit.root(v).Position - root.Position
			if to.Magnitude <= cfg.Range and not Kit.isProtected(v) and (Kit.flat(to):Dot(dir) >= 0.35 or to.Magnitude < 8) and to.Magnitude < bestD then
				best, bestD = v, to.Magnitude
			end
		end
		local spot = best and Kit.root(best).Position or (root.Position + dir * cfg.Offset)
		local center = Kit.ground(Kit.safePoint(root.Position + Vector3.new(0, 1, 0), spot, 2))
		Kit.fx({ id = "CoreDrop", p = center, r = cfg.Radius, fall = cfg.Windup, model = "Safe", a = attacker, look = dir })
		task.wait(cfg.Windup)
		if not root.Parent or not api.CharacterState.isAlive(attacker) then
			return
		end
		local victims, total = {}, 0
		for _, v in ipairs(Kit.enemies(attacker)) do
			local vp = Kit.root(v).Position
			if Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude <= cfg.Radius and math.abs(vp.Y - center.Y) < 10 then
				if api.hit(attacker, v, cfg, api.flat(vp - center, dir), { hitPos = vp + Vector3.new(0, 1, 0) }) == "Hit" then
					table.insert(victims, v)
					if not v:GetAttribute("Transformed") then
						local ot = v:GetAttribute("Overtime") or 0
						local steal = math.min(cfg.Steal, ot)
						v:SetAttribute("Overtime", ot - steal)
						total += steal
					end
				end
			end
		end
		api.ZoneService.shatterAround(center, cfg.Radius * 0.8, Vector3.new(0, 30, 0))
		Kit.fx({ id = "AcctBankrupt", a = attacker, vs = victims, p = center + Vector3.new(0, 2.8, 0), n = total })
		local hum = attacker:FindFirstChildOfClass("Humanoid")
		if hum and #victims > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + cfg.HealPer * #victims)
		end
		if total > 0 then
			attacker:SetAttribute("BankedOvertime", (attacker:GetAttribute("BankedOvertime") or 0) + total)
			if not attacker:GetAttribute("BankWaiting") then
				attacker:SetAttribute("BankWaiting", true)
				task.spawn(function()
					local t0 = os.clock()
					while attacker.Parent and attacker:GetAttribute("Transformed") and os.clock() - t0 < 30 do
						task.wait(0.25)
					end
					task.wait(0.3)
					if attacker.Parent and api.CharacterState.isAlive(attacker) then
						api.CombatService.addOvertime(attacker, attacker:GetAttribute("BankedOvertime") or 0)
						local head = attacker:FindFirstChild("Head")
						if head then
							Kit.fx({ id = "AcctPayout", p = head.Position, n = attacker:GetAttribute("BankedOvertime") or 0 })
						end
					end
					attacker:SetAttribute("BankedOvertime", nil)
					attacker:SetAttribute("BankWaiting", nil)
				end)
			end
		end
	end,
}

function M.ServerInit(api)
	local streak = setmetatable({}, { __mode = "k" }) -- [attaquant] = { victim, stacks, last, lastInc }
	table.insert(api.CombatService.damageMods, function(p)
		local a, v = p.attacker, p.victim
		if not a then
			return
		end
		-- Tax Audit : +bonus sur les 3 prochains coups de l'auditeur
		if v:GetAttribute("AuditBy") == a.Name and (v:GetAttribute("AuditHits") or 0) > 0 and (v:GetAttribute("AuditUntil") or 0) > Kit.now() and p.weapon ~= "Tax Audit" then
			p.damage += v:GetAttribute("AuditBonus") or 4
			p.words = { "PENALTY!", "AUDITED!", "FINED!" }
			p.power = (p.power or 0.5) + 0.2
			local left = v:GetAttribute("AuditHits") - 1
			v:SetAttribute("AuditHits", left)
			if left <= 0 then
				v:SetAttribute("AuditBy", nil)
			end
		end
		-- Compound Interest
		if a:GetAttribute("CharacterName") == "Accountant" then
			local s = streak[a]
			local t = os.clock()
			if not s or s.victim ~= v or t - s.last > 2 then
				s = { victim = v, stacks = 0, last = t, lastInc = t }
				streak[a] = s
			elseif t - s.lastInc >= 0.25 and s.stacks < 5 then
				s.stacks += 1
				s.lastInc = t
				local head = v:FindFirstChild("Head")
				if head then
					Kit.fx({ id = "AcctInterest", p = head.Position, n = s.stacks })
				end
			end
			s.last = t
			p.damage *= 1 + 0.1 * s.stacks
		end
	end)
end

------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------
local function rndDigit(rng)
	return DIGITS[rng:NextInteger(1, #DIGITS)]
end

M.MoveFX = {
	CalculatorThrow = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), GREEN, 0.4, 1, 1)
		task.delay(0.15, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), r.CFrame.LookVector, 6, GREEN, 0.2)
				Kit.cubes(r.Position + r.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), 6, { GREEN, LCD }, 0.4, 5, 0.35)
			end
		end)
	end,
	TaxAudit = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), RED, 0.9, 1.4, 0.8)
	end,
	SpreadsheetSlam = function(c, d, api)
		task.delay(0.34, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			api.CartoonFX.sound("GroundSlam", r.Position, 1)
			local base = (r.CFrame - r.Position + (r.Position - Vector3.new(0, 2.9, 0))) * CFrame.new(0, 0, -6)
			for gx = -1, 1 do
				for gz = -1, 1 do
					local cell = Kit.part({ Size = Vector3.new(3.7, 0.3, 3.7), CFrame = base * CFrame.new(gx * 4, -0.2, gz * 4), Color = (gz == -1) and DGREEN or PAPER })
					if gz ~= -1 and api.rng:NextNumber() < 0.7 then
						Kit.flatText(cell, rndDigit(api.rng) .. rndDigit(api.rng), DGREEN, Enum.NormalId.Top)
					end
					local delay = (gz + 1) * 0.05
					task.delay(delay, function()
						Kit.tween(cell, 0.12, { CFrame = base * CFrame.new(gx * 4, 0.6, gz * 4) }, Enum.EasingStyle.Back)
					end)
					task.delay(0.7 + delay, function()
						Kit.tween(cell, 0.25, { Transparency = 1, CFrame = base * CFrame.new(gx * 4, -0.3, gz * 4) })
					end)
					api.Debris:AddItem(cell, 1.1)
				end
			end
			api.CartoonFX.shockwave(base.Position + Vector3.new(0, 0.3, 0), 9, GREEN)
			api.CartoonFX.bigImpact(base.Position + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.1, GREEN)
			api.CartoonFX.cracks(base.Position, 6, 5)
			Kit.cubes(base.Position + Vector3.new(0, 1, 0), 14, { GREEN, PAPER, DGREEN }, 0.6, 10, 0.5)
			api.CartoonFX.casterShake(c, 0.7)
		end)
	end,
	NumberCrunch = function(c, d, api)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), GREEN, 0.7, 1, 0.9)
		api.CartoonFX.trailOn(c:FindFirstChild("Left Arm"), GREEN, 0.7, 1, 0.9)
		task.delay(0.56, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.airRing(r.Position + r.CFrame.LookVector * 2.5, r.CFrame.LookVector, 10, GOLD, 0.3)
				Kit.floatText(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 3, 0), "= TOTAL", GOLD, 3, 0.7, 1.5)
				api.CartoonFX.casterShake(c, 0.7)
			end
		end)
		task.spawn(function()
			for _ = 1, 9 do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local pos = r.Position + r.CFrame.LookVector * 3 + r.CFrame.RightVector * api.rng:NextNumber(-2, 2) + Vector3.new(0, api.rng:NextNumber(0, 2), 0)
				Kit.floatText(pos, rndDigit(api.rng), GREEN, 1.8, 0.5, 2.5)
				task.wait(0.06)
			end
		end)
	end,
	BudgetCut = function(c, d, api)
		api.afterimages(c, d.dur or 0.4, GREEN)
		api.CartoonFX.trailOn(c:FindFirstChild("Right Arm"), Color3.fromRGB(220, 230, 240), (d.dur or 0.4) + 0.2, 1.5, 2.6)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			api.CartoonFX.dust(r.Position - Vector3.new(0, 2.8, 0), 5, nil, 8)
			api.CartoonFX.airRing(r.Position + r.CFrame.LookVector, r.CFrame.LookVector, 7, GREEN, 0.25)
		end
		if Kit.mine(c) then
			api.CartoonFX.speedLines(d.dur or 0.4, GREEN)
		end
		task.delay(0.34, function()
			local r2 = c:FindFirstChild("HumanoidRootPart")
			if not r2 then
				return
			end
			-- grand « snip » blanc en fin de course
			api.CartoonFX.slashArc(r2.CFrame * CFrame.new(0, 0.4, 0), 6, Color3.new(1, 1, 1), -80, 80, 0.06, 0, 0.5)
			api.CartoonFX.slashArc(r2.CFrame * CFrame.new(0, 0.2, 0), 5, GREEN, 80, -80, 0.06, 0, 0.35)
			api.CartoonFX.sound("Clang", r2.Position, 0.7)
			Kit.floatText(r2.Position + r2.CFrame.LookVector * 4 + Vector3.new(0, 2, 0), "SNIP!", Color3.new(1, 1, 1), 2.6, 0.5, 1.5)
			api.CartoonFX.casterShake(c, 0.5)
		end)
	end,
	Bankrupt = function(c, d, api)
		task.spawn(function()
			-- billets aspirés pendant la charge
			for _ = 1, 8 do
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local off = Vector3.new(api.rng:NextNumber(-1, 1), 0, api.rng:NextNumber(-1, 1)).Unit * 9 + Vector3.new(0, api.rng:NextNumber(-1, 2), 0)
				local bill = Kit.part({ Size = Vector3.new(1.2, 0.08, 0.6), CFrame = CFrame.new(r.Position + off), Color = GREEN })
				Kit.tween(bill, 0.3, { CFrame = CFrame.new(r.Position) * CFrame.Angles(2, 1, 0) })
				api.Debris:AddItem(bill, 0.32)
				task.wait(0.05)
			end
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	Kit.on("AcctInterest", function(d)
		Kit.floatText(d.p + Vector3.new(Kit.rng:NextNumber(-1, 1), 1.2, 0), "+" .. (d.n * 10) .. "%", GREEN, 1.6 + d.n * 0.2, 0.7, 2)
	end)

	Kit.on("AcctStamped", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if vr then
			CartoonFX.word(vr.Position + Vector3.new(0, 2.5, 0), "AUDITED!", 0.9, "Heavy")
			CartoonFX.sound("Ding", vr.Position, 0.8)
		end
	end)

	Kit.on("AcctStampHit", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		local p = vr.Position + Vector3.new(0, 1, 0)
		local mark = Kit.part({ Size = Vector3.new(1.6, 0.9, 0.08), CFrame = vr.CFrame * CFrame.new(Kit.rng:NextNumber(-0.5, 0.5), Kit.rng:NextNumber(0, 1.2), -0.62) * CFrame.Angles(0, 0, Kit.rng:NextNumber(-0.3, 0.3)), Color = RED })
		Kit.flatText(mark, "AUDIT", Color3.new(1, 1, 1), Enum.NormalId.Front)
		Kit.tween(mark, 0.6, { Transparency = 1 })
		Debris:AddItem(mark, 0.62)
		CartoonFX.sound("Bonk", p, 0.9)
		CartoonFX.airRing(p, Vector3.new(0, -1, 0), 4, RED, 0.15)
		Kit.cubes(p, 5, { RED, Color3.new(1, 1, 1) }, 0.4, 5, 0.3)
	end)

	Kit.on("AcctStampMiss", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + r.CFrame.LookVector * 3 + Vector3.new(0, 2, 0), "VOID", RED, 2, 0.5, 1)
		end
	end)

	Kit.on("AcctBankrupt", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		CartoonFX.sound("Ding", d.p, 1)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.7, 0), 16, GREEN)
		Kit.cubes(d.p, 24, { GREEN, GOLD, DGREEN }, 0.7, 14, 0.6)
		-- pièces et billets qui volent des victimes vers le comptable
		for _, v in ipairs(d.vs or {}) do
			local vr = v:FindFirstChild("HumanoidRootPart")
			if vr and r then
				for i = 1, 6 do
					task.delay(0.15 + i * 0.05, function()
						if not vr.Parent or not r.Parent then
							return
						end
						local coin = Kit.part({ Shape = CYL, Size = Vector3.new(0.15, 0.7, 0.7), CFrame = CFrame.new(vr.Position + Vector3.new(0, 1, 0)), Color = (i % 2 == 0) and GOLD or GREEN })
						Kit.tween(coin, 0.35, { CFrame = CFrame.new(r.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						Debris:AddItem(coin, 0.37)
					end)
				end
				Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "-OT", Color3.fromRGB(255, 80, 60), 2, 0.8, 2)
			end
		end
		if r and (d.n or 0) > 0 then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "+" .. math.floor(d.n) .. " OT BANKED", GOLD, 3, 1.2, 2)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(0.8)
		end
	end)

	Kit.on("AcctPayout", function(d)
		Kit.floatText(d.p + Vector3.new(0, 1.5, 0), "PAYOUT +" .. math.floor(d.n) .. " OT", GOLD, 3, 1.4, 2.5)
		CartoonFX.sound("Ding", d.p, 1)
	end)

	-- marque AUDIT au-dessus des cibles + aura de chiffres en transformation
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.15)
			tick += 1
			local nowS = workspace:GetServerTimeNow()
			for _, c in ipairs(api.Hitbox.characters()) do
				local left = c:GetAttribute("AuditHits") or 0
				if c:GetAttribute("AuditBy") and left > 0 and (c:GetAttribute("AuditUntil") or 0) > nowS then
					Kit.mark(c, "AuditMark", "AUDIT x" .. left, RED)
				else
					Kit.mark(c, "AuditMark", nil)
				end
				if tick % 2 == 0 and c:GetAttribute("CharacterName") == "Accountant" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						local off = Vector3.new(Kit.rng:NextNumber(-2.2, 2.2), Kit.rng:NextNumber(-2, 1), Kit.rng:NextNumber(-2.2, 2.2))
						Kit.floatText(r.Position + off, rndDigit(Kit.rng), GREEN, 1.1, 0.9, 2.5)
					end
				end
			end
		end
	end)
end

return M
