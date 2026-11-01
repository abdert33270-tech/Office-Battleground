--[[
	DemoSkins — 2 skins de démonstration des champs v3 de SkinBuilder (Mesh, Asset, Paint, HideFace, HideHair).
	PAS dans SkinList (jamais obtenables) : exemple de référence pour les designers + tests.
	Test : SkinBuilder.dress(model, require(SkinBuilder.DemoSkins).Astro)
]]
local C = Color3.fromRGB
local ORANGE, WHITE, DARK, GOLD = C(255, 140, 40), C(240, 242, 248), C(45, 50, 66), C(255, 196, 40)

local function face(eyeCol, browCol, mouthCol)
	return {
		{ Type = "Circle", Pos = { 0.36, 0.45 }, Size = { 0.15, 0.2 }, Color = WHITE, Stroke = { C(30, 30, 40), 2 } },
		{ Type = "Circle", Pos = { 0.64, 0.45 }, Size = { 0.15, 0.2 }, Color = WHITE, Stroke = { C(30, 30, 40), 2 } },
		{ Type = "Circle", Pos = { 0.37, 0.47 }, Size = { 0.08, 0.12 }, Color = eyeCol },
		{ Type = "Circle", Pos = { 0.63, 0.47 }, Size = { 0.08, 0.12 }, Color = eyeCol },
		{ Type = "Circle", Pos = { 0.385, 0.44 }, Size = { 0.03, 0.04 }, Color = WHITE },
		{ Type = "Circle", Pos = { 0.645, 0.44 }, Size = { 0.03, 0.04 }, Color = WHITE },
		{ Type = "Line", From = { 0.27, 0.3 }, To = { 0.43, 0.27 }, Width = 5, Color = browCol },
		{ Type = "Line", From = { 0.57, 0.27 }, To = { 0.73, 0.3 }, Width = 5, Color = browCol },
		{ Type = "Box", Pos = { 0.5, 0.71 }, Size = { 0.26, 0.07 }, Corner = 1, Color = mouthCol },
		{ Type = "Circle", Pos = { 0.25, 0.62 }, Size = { 0.12, 0.07 }, Color = C(255, 120, 140), Transparency = 0.45 },
		{ Type = "Circle", Pos = { 0.75, 0.62 }, Size = { 0.12, 0.07 }, Color = C(255, 120, 140), Transparency = 0.45 },
	}
end

local Demo = {}

Demo.Astro = {
	Id = "Demo_Astro", Character = "CEO", Name = "Demo Astronaut", Rarity = "Legendary", Desc = "SkinBuilder v3 demo.",
	Outfit = { Shirt = WHITE, Pants = WHITE },
	HideIdentity = true, HideFace = true, HideHair = true, HideAccessories = true,
	Parts = {
		-- casque bulle (Mesh Sphere) + col métallique
		{ Limb = "Head", Shape = "Block", Mesh = "Sphere", Size = Vector3.new(1.8, 1.8, 1.8), Color = C(170, 225, 255), Material = "SmoothPlastic", Transparency = 0.7, Offset = CFrame.new(0, 0.12, 0) },
		{ Limb = "Torso", Shape = "Cylinder", Size = Vector3.new(0.28, 1.5, 1.5), Color = C(200, 205, 218), Material = "Metal", Offset = CFrame.new(0, 1.04, 0) * CFrame.Angles(0, 0, math.pi / 2) },
		-- épaulettes et gants arrondis
		{ Limb = "Left Arm", Mesh = "Sphere", Size = Vector3.new(1.18, 0.7, 1.18), Color = ORANGE, Offset = CFrame.new(0, 0.78, 0) },
		{ Limb = "Right Arm", Mesh = "Sphere", Size = Vector3.new(1.18, 0.7, 1.18), Color = ORANGE, Offset = CFrame.new(0, 0.78, 0) },
		{ Limb = "Left Arm", Mesh = { Type = "Cylinder" }, Size = Vector3.new(0.55, 1.12, 1.12), Color = ORANGE, Offset = CFrame.new(0, -0.72, 0) * CFrame.Angles(0, 0, math.pi / 2) },
		{ Limb = "Right Arm", Mesh = { Type = "Cylinder" }, Size = Vector3.new(0.55, 1.12, 1.12), Color = ORANGE, Offset = CFrame.new(0, -0.72, 0) * CFrame.Angles(0, 0, math.pi / 2) },
		-- bottes (bloc + bout arrondi)
		{ Limb = "Left Leg", Size = Vector3.new(1.08, 0.55, 1.08), Color = C(90, 96, 112), Offset = CFrame.new(0, -0.74, 0) },
		{ Limb = "Right Leg", Size = Vector3.new(1.08, 0.55, 1.08), Color = C(90, 96, 112), Offset = CFrame.new(0, -0.74, 0) },
		{ Limb = "Left Leg", Mesh = "Sphere", Size = Vector3.new(1.06, 0.5, 0.7), Color = C(90, 96, 112), Offset = CFrame.new(0, -0.78, -0.45) },
		{ Limb = "Right Leg", Mesh = "Sphere", Size = Vector3.new(1.06, 0.5, 0.7), Color = C(90, 96, 112), Offset = CFrame.new(0, -0.78, -0.45) },
		-- réacteur dorsal = mesh généré (Asset) qui flotte + flamme
		{ Limb = "Torso", Asset = "Test_Rocket", Size = Vector3.new(1.5, 2.3, 1.3), Offset = CFrame.new(0, 0.1, 1.15) * CFrame.Angles(0, math.pi, 0), Anim = { Bob = 0.06, BobSpeed = 3, Seed = 1 } },
		{ Limb = "Torso", Shape = "Ball", Size = Vector3.new(0.45, 0.45, 0.45), Color = ORANGE, Material = "Neon", Offset = CFrame.new(0, -1.15, 1.15), Anim = { Bob = 0.06, BobSpeed = 3, Seed = 1, Pulse = 0.4, PulseSpeed = 9 },
		  Particles = { Kind = "Fire", Color = ORANGE, Rate = 18, Speed = 4, Dir = "Bottom", Size = 0.5, Life = 0.35, React = true } },
	},
	Paint = {
		{ Limb = "Head", Face = "Front", Elements = face(C(40, 120, 255), C(70, 45, 30), C(60, 30, 30)) },
		{ Limb = "Torso", Face = "Front", Elements = {
			{ Type = "Line", From = { 0.5, 0.06 }, To = { 0.5, 0.84 }, Width = 6, Color = C(150, 155, 170) },
			{ Type = "Circle", Pos = { 0.27, 0.28 }, Size = { 0.28, 0.28 }, Color = C(40, 90, 220), Stroke = { WHITE, 4 } },
			{ Type = "Text", Pos = { 0.27, 0.28 }, Size = { 0.2, 0.14 }, Text = "OB", Font = "Black", Color = WHITE },
			{ Type = "Box", Pos = { 0.73, 0.24 }, Size = { 0.38, 0.13 }, Corner = 0.5, Color = ORANGE },
			{ Type = "Text", Pos = { 0.73, 0.24 }, Size = { 0.32, 0.1 }, Text = "ASTRO", Font = "Display", Color = WHITE },
			{ Type = "Box", Pos = { 0.73, 0.56 }, Size = { 0.32, 0.24 }, Corner = 0.25, Color = DARK, Stroke = { C(150, 155, 170), 3 } },
			{ Type = "Circle", Pos = { 0.64, 0.52 }, Size = { 0.07, 0.07 }, Color = C(255, 70, 70) },
			{ Type = "Circle", Pos = { 0.73, 0.52 }, Size = { 0.07, 0.07 }, Color = C(80, 230, 110) },
			{ Type = "Circle", Pos = { 0.82, 0.52 }, Size = { 0.07, 0.07 }, Color = GOLD },
			{ Type = "Box", Pos = { 0.73, 0.62 }, Size = { 0.24, 0.04 }, Color = C(80, 200, 255) },
			{ Type = "Box", Pos = { 0.5, 0.9 }, Size = { 1, 0.12 }, Color = DARK },
			{ Type = "Box", Pos = { 0.5, 0.9 }, Size = { 0.18, 0.15 }, Corner = 0.3, Color = GOLD, Stroke = { C(120, 80, 10), 3 } },
		} },
		{ Limb = "Left Arm", Face = "Left", Elements = {
			{ Type = "Box", Pos = { 0.5, 0.42 }, Size = { 0.7, 0.24 }, Corner = 0.15, Color = C(40, 90, 220), Stroke = { WHITE, 3 } },
			{ Type = "Circle", Pos = { 0.5, 0.42 }, Size = { 0.22, 0.12 }, Color = GOLD },
		} },
		{ Limb = "Left Arm", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.42 }, Size = { 1, 0.07 }, Color = ORANGE } } },
		{ Limb = "Right Arm", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.42 }, Size = { 1, 0.07 }, Color = ORANGE } } },
		{ Limb = "Left Leg", Face = "Front", Elements = {
			{ Type = "Box", Pos = { 0.5, 0.42 }, Size = { 0.72, 0.2 }, Corner = 0.6, Color = C(190, 195, 210), Stroke = { C(130, 135, 150), 3 } },
			{ Type = "Line", From = { 0.85, 0.05 }, To = { 0.85, 0.55 }, Width = 5, Color = ORANGE },
		} },
		{ Limb = "Right Leg", Face = "Front", Elements = {
			{ Type = "Box", Pos = { 0.5, 0.42 }, Size = { 0.72, 0.2 }, Corner = 0.6, Color = C(190, 195, 210), Stroke = { C(130, 135, 150), 3 } },
			{ Type = "Line", From = { 0.15, 0.05 }, To = { 0.15, 0.55 }, Width = 5, Color = ORANGE },
		} },
	},
	FX = { Light = C(120, 200, 255) },
}

Demo.Monarch = {
	Id = "Demo_Monarch", Character = "Janitor", Name = "Demo Monarch", Rarity = "Epic", Desc = "SkinBuilder v3 demo.",
	Outfit = { Shirt = C(170, 30, 45), Pants = C(70, 35, 110) },
	HideIdentity = true, HideFace = true, HideHair = true,
	Parts = {
		-- couronne générée (texture d'origine) qui flotte doucement
		{ Limb = "Head", Asset = "Test_Crown", Size = Vector3.new(1.3, 0.9, 1.3), Offset = CFrame.new(0, 0.95, 0), Anim = { Bob = 0.04, BobSpeed = 2 } },
		-- barbe 3D (Mesh Sphere)
		{ Limb = "Head", Mesh = "Sphere", Size = Vector3.new(1.0, 0.62, 0.55), Color = C(125, 72, 35), Offset = CFrame.new(0, -0.42, -0.4) },
		-- col d'hermine (sphère aplatie) + cape
		{ Limb = "Torso", Mesh = "Sphere", Size = Vector3.new(2.35, 0.5, 1.35), Color = C(248, 248, 248), Material = "Fabric", Offset = CFrame.new(0, 1.0, 0) },
		{ Limb = "Torso", Size = Vector3.new(2.1, 2.7, 0.12), Color = C(125, 20, 35), Material = "Fabric", Offset = CFrame.new(0, -0.35, 0.6), Anim = { Swing = 4, SwingSpeed = 1.5, SwingAxis = "X" } },
		-- sceptre : tige (Mesh Cylinder) + mesh généré recoloré en or (Color + Material)
		{ Limb = "Right Arm", Mesh = "Cylinder", Size = Vector3.new(1.9, 0.14, 0.14), Color = GOLD, Material = "Foil", Offset = CFrame.new(0, -1.05, -0.55) * CFrame.Angles(0, 0, math.pi / 2) },
		{ Limb = "Right Arm", Asset = "Test_Rocket", Color = GOLD, Material = "Foil", Size = Vector3.new(0.55, 0.8, 0.55), Offset = CFrame.new(0, 0.25, -0.55), Light = GOLD },
		-- bonus transformation : 2e couronne néon au-dessus (Asset + Transform)
		{ Limb = "Head", Asset = "Test_Crown", Color = C(255, 230, 120), Material = "Neon", Size = Vector3.new(0.7, 0.5, 0.7), Offset = CFrame.new(0, 2.0, 0), Transform = true, Anim = { Spin = 90 } },
	},
	Paint = {
		{ Limb = "Head", Face = "Front", Elements = (function()
			local f = face(C(90, 50, 20), C(110, 60, 25), C(90, 30, 30))
			table.insert(f, { Type = "Box", Pos = { 0.5, 0.63 }, Size = { 0.42, 0.09 }, Corner = 1, Color = C(125, 72, 35) })
			return f
		end)() },
		{ Limb = "Torso", Face = "Front", Elements = {
			{ Type = "Box", Pos = { 0.09, 0.5 }, Size = { 0.18, 1 }, Color = C(248, 248, 248) },
			{ Type = "Box", Pos = { 0.91, 0.5 }, Size = { 0.18, 1 }, Color = C(248, 248, 248) },
			{ Type = "Circle", Pos = { 0.08, 0.3 }, Size = { 0.05, 0.07 }, Color = C(20, 20, 20) },
			{ Type = "Circle", Pos = { 0.1, 0.6 }, Size = { 0.05, 0.07 }, Color = C(20, 20, 20) },
			{ Type = "Circle", Pos = { 0.9, 0.42 }, Size = { 0.05, 0.07 }, Color = C(20, 20, 20) },
			{ Type = "Circle", Pos = { 0.92, 0.75 }, Size = { 0.05, 0.07 }, Color = C(20, 20, 20) },
			{ Type = "Box", Pos = { 0.5, 0.45 }, Size = { 0.1, 0.9 }, Color = GOLD },
			{ Type = "Circle", Pos = { 0.5, 0.22 }, Size = { 0.09, 0.09 }, Color = GOLD, Stroke = { C(120, 80, 10), 2 } },
			{ Type = "Circle", Pos = { 0.5, 0.42 }, Size = { 0.09, 0.09 }, Color = GOLD, Stroke = { C(120, 80, 10), 2 } },
			{ Type = "Circle", Pos = { 0.5, 0.62 }, Size = { 0.09, 0.09 }, Color = GOLD, Stroke = { C(120, 80, 10), 2 } },
			{ Type = "Box", Pos = { 0.5, 0.85 }, Size = { 0.64, 0.1 }, Color = C(90, 55, 25) },
			{ Type = "Box", Pos = { 0.5, 0.85 }, Size = { 0.16, 0.13 }, Corner = 0.2, Color = GOLD, Stroke = { C(120, 80, 10), 3 } },
		} },
		{ Limb = "Left Arm", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.86 }, Size = { 1, 0.14 }, Color = C(248, 248, 248) }, { Type = "Line", From = { 0, 0.78 }, To = { 1, 0.78 }, Width = 5, Color = GOLD } } },
		{ Limb = "Right Arm", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.86 }, Size = { 1, 0.14 }, Color = C(248, 248, 248) }, { Type = "Line", From = { 0, 0.78 }, To = { 1, 0.78 }, Width = 5, Color = GOLD } } },
		{ Limb = "Left Leg", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.9 }, Size = { 1, 0.2 }, Color = C(30, 22, 18) }, { Type = "Line", From = { 0.5, 0 }, To = { 0.5, 0.78 }, Width = 4, Color = GOLD, Rotation = 0 } } },
		{ Limb = "Right Leg", Face = "Front", Elements = { { Type = "Box", Pos = { 0.5, 0.9 }, Size = { 1, 0.2 }, Color = C(30, 22, 18) }, { Type = "Line", From = { 0.5, 0 }, To = { 0.5, 0.78 }, Width = 4, Color = GOLD } } },
	},
	FX = { Sparkles = GOLD },
}

return Demo
