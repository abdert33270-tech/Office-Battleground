--[[
	SkinBuilder — habille un modèle R6 avec un skin (partagé serveur + client).
	Fonctionne sur un vrai perso (Humanoid : BodyColors, parts soudées) ET sur un mannequin sans Humanoid
	(ViewportFrame : couleurs posées sur les parts, parts ancrées placées directement).

	API :
		SkinBuilder.dress(model, skinIdOrDef, opts?) -> Folder "SkinParts" | nil
			skinIdOrDef : id de Config/Skins, une table de skin (même format que SkinList), ou "Avatar"/nil (= retirer).
			opts.snapshot : instantané de SkinBuilder.snapshot (vrai perso) => sert de référence pour la peau / "Avatar".
		SkinBuilder.undress(model)                 -- détruit SkinParts et ré-affiche les chapeaux cachés
		SkinBuilder.snapshot(model) -> snap        -- vêtements + BodyColors d'origine (vrai perso)
		SkinBuilder.restore(model, snap)           -- remet l'avatar d'origine (vêtements + couleurs)
		SkinBuilder.identity(model, charId)        -- accessoires de métier (Folder "IdentityProps")
		SkinBuilder.clearIdentity(model)
		SkinBuilder.mannequin() -> Model           -- 6 parts R6 ancrées + visage, PrimaryPart = Torso
	Côté client, le simple fait de require ce module anime les FX "Orbit" (tag CollectionService "SkinOrbit").
	Toutes les parts : Massless, CanCollide/CanQuery/CanTouch = false (aucun effet sur le combat).

	Options de skin (toutes facultatives, rétro-compatibles avec l'ancien format) :
		Part.Anim = { Spin = deg/s, Axis = "X"|"Y"|"Z", Bob = studs, BobSpeed, Swing = deg, SwingSpeed, SwingAxis,
		              Circle = rad/s (la pièce tourne autour de l'axe Y du membre : drone en orbite), Pulse = 0..1
		              (transparence qui pulse), PulseSpeed, Float = true (flottement doux), React = true (x2.5 en transformation) }
		Part.Transform = true   -- pièce visible seulement quand le perso est Transformed (toujours visible dans l'aperçu du menu)
		Part.Text = "LIVE" | { Text, Color, Bg, Font = "Fredoka"|"Arcade"|"Code"|"Bangers"|"Black"|"Serif"|"SciFi"|"Cartoon",
		              Face = "Front"|"Back"|"Both"|"Top"|"Left"|"Right", Scroll = vitesse (bandeau défilant), Width, Blink = Hz }
		Part.Trail = Color3 | { Color, Width }      Part.Light = Color3
		Part.Particles = { Kind = "Sparkle"|"Smoke"|"Fire"|"Spark", Color, Rate, Speed, Size, Life, Spread, Dir, Accel,
		                   React (x3 en transformation), TransformOnly (n'émet qu'en transformation) }
		Part.Anim.Seed = nombre : même Seed => pièces animées en phase (groupe rigide). Part.Reflect = 0..1
		def.Highlight = { Outline = Color3, Fill = Color3? }   -- contour lumineux allumé pendant la transformation
		def.HitColor = Color3   -- copié dans l'attribut du perso "SkinHitColor" (pour les VFX de combat)
		def.FX.PowerAura = Color3 (aura qui s'intensifie pendant la transformation), FX.Spotlight = Color3 (faisceau de scène),
		FX.HandTrails = Color3 (traînées aux deux mains)
	Animation : UNE seule boucle client (RenderStepped) pour tout (orbites, pièces animées, textes). Le Script enfant
	"SkinAnimatorBoot" (RunContext Client) require ce module sur chaque client pour la démarrer.
	La réaction à la transformation (pièces Transform, Highlight, PowerAura, Particles.React) est gérée côté serveur.

	=== SKINS v3 : nouveaux champs (tous facultatifs, rétro-compatibles) ===
	Limites : def.Parts Rare 30 / Epic 40 / Legendary 60 pièces (autres 30) ; def.Paint 160 éléments max.

	Part.Mesh = { Type = "Sphere"|"Cylinder"|"Wedge"|"Brick"|"Head"|"Torso", Scale = Vector3?, Offset = Vector3? }
	        (ou Mesh = "Sphere") -> SpecialMesh sur la pièce : formes lisses (cheveux, casques, manches, chaussures).
	        Le mesh s'étire à Size (Scale multiplie, défaut 1,1,1). "Sphere" = ellipsoïde de taille Size.
	        "Cylinder" = axe X local (comme Shape Cylinder) mais section ELLIPTIQUE (Size.Y ≠ Size.Z permis).
	        "Head" = forme de tête R6 arrondie. Marche avec Anim / Transform / Text / Light / Particles / Trail.
	Part.Asset = "NomAsset" -> clone ReplicatedStorage.SkinAssets[NomAsset] (MeshPart, Part ou Model) au lieu d'une Part.
	        Size = boîte englobante : mise à l'échelle UNIFORME pour tenir dedans (proportions gardées) ; sans Size =
	        taille d'origine. Offset = centre de l'asset relatif au membre (tourner avec CFrame.Angles si besoin ;
	        l'avant des meshes générés est en général -Z). Color = Color3 -> recolore en uni (retire la texture
	        générée sauf KeepTexture = true) ; Material = override ; Transparency. Soudé, Massless, sans collision.
	        Anim / Transform / Light / Particles / Trail marchent comme sur une Part. Voir scratchpad MESH_NOTES.md.
	def.Paint = { Couche, ... }  -- détails peints sur le corps (vêtements, logos fictifs, visages)
	    Couche  = { Limb = "Torso"|"Head"|"Left Arm"|..., Face = "Front"|"Back"|"Left"|"Right"|"Top"|"Bottom",
	                Glow = true? (non affecté par la lumière : visières, néons), Elements = { Element, ... } }
	    Element = { Type = "Box"|"Circle"|"Text"|"Line",
	                Pos = {x, y}    -- CENTRE, 0..1 sur la face vue de face (0,0 = haut-gauche pour quelqu'un qui
	                                --  REGARDE cette face ; Front : x=0 = côté droit du perso)
	                Size = {w, h}   -- 0..1 de la largeur / hauteur de la face
	                Color = Color3, Transparency = 0..1?, Rotation = degrés? (sens horaire),
	                Corner = 0..1? (0 = carré, 1 = pilule ; Circle = ellipse dans Size),
	                Stroke = {Color3, px}?  (1 stud = 100 px),
	                Text = "...", Font = "Display"|"Body"|"Bold"|"Black"|"Arcade"|"Code"|"Bangers"|"Serif"|"SciFi"|
	                       "Cartoon"|"Marker"|"Creepy"|"Hand"|"Tech"|"Lucky"|"Condensed"  (Text : taille auto dans Size)
	                Line : From = {x,y}, To = {x,y}, Width = px  (ou Pos/Size/Rotation, Size h = épaisseur) }
	    Dimensions des faces (studs) : Torso Front/Back 2x2, Left/Right 1x2, Top 2x1 ; bras/jambes 1x2 (Top 1x1).
	    TÊTE : la tête R6 est ronde (~1.2 de large/haut) -> sur Head, Front/Back/Left/Right = zone 1.2 x 1.2
	        enroulée sur le cylindre de la tête (chaque élément posé tangent à la surface) ; Top = dessus (1.2 x 1.2).
	        Repères visage (Head Front) : yeux y≈0.42 x≈0.36/0.64, sourcils y≈0.3, bouche y≈0.68. Garder les éléments
	        de tête petits (< 0.5 de large) ; visière / bandeau large -> Parts avec Mesh.
	    Rendu : vrai perso = SurfaceGui dans le dossier SkinParts (Adornee = membre ; tête : petites plaques
	        invisibles soudées) ; mannequin sans Humanoid (aperçus ViewportFrame) = fines Parts colorées (les
	        SurfaceGui ne s'affichent pas en ViewportFrame) ; les Text du mannequin restent en SurfaceGui
	        (visibles dans le monde, pas en ViewportFrame). Peinture statique : aucun coût d'animation.
	def.HideFace = true  -- cache le visage (Decals de la tête) ; dessiner le visage avec Paint sur Head Front.
	    Si le skin a HideFace ou une couche Paint sur Head (ou ClassicHead = true), une tête d'avatar personnalisée
	    (SpecialMesh FileMesh) est remplacée par la tête R6 classique pendant que le skin est porté (restaurée au undress).
	def.HideHair = true  -- cache cheveux / chapeaux / tout accessoire soudé à la tête (auto pour chapeaux+cheveux si une
	                     --  pièce Head a Offset.Y >= 0.45).
	def.HideAccessories = true -- cache TOUS les accessoires de l'avatar (costumes complets, objets dans le dos...).
	Défaut (vrai perso, tout skin sauf "Avatar") : Epic / Legendary => TOUS les accessoires cachés ; Base / Rare =>
	    accessoires Back / Waist / Shoulder / Front cachés (chapeaux / cheveux gardés sauf HideHair / HideAccessories).
	def.KeepAccessories = true -- désactive ce défaut. Tout est restauré au undress.
	Part.Transform = true : les textes (SurfaceGui), particules, lumières et traînées de la pièce sont aussi cachés hors
	    transformation (toujours visibles dans les aperçus du menu).
	=== SKINS v4 (moteur) ===
	- Échelle : les pièces suivent la taille du perso (buste.Size.Y / 2) : tailles, offsets, assets ; l'animateur
	  client recalcule l'offset des pièces animées avec l'échelle courante (perso agrandi par Model:ScaleTo).
	- Shape "Ball" aux dimensions non uniformes (ou "Cylinder" avec Y ~= Z) => bloc + SpecialMesh Sphere / Cylinder :
	  l'ellipsoïde voulu est respecté (Roblox forcerait sinon une sphère / une section ronde).
	- Legendary : reflet (« shimmer ») qui balaie les pièces Metal / Foil (attribut ShimmerBase, tag SkinShimmer) ;
	  def.Shimmer = false pour le couper. Les Highlight ne s'affichent pas en ViewportFrame (aperçus du menu).
	Astuce : pas de Material "Glass" devant un visage peint (casque bulle...) : en jeu le verre masque les SurfaceGui
	derrière lui ; utiliser SmoothPlastic + Transparency ~0.7. Exemple complet : module enfant DemoSkins.
]]
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent

local SkinBuilder = {}
SkinBuilder.FOLDER = "SkinParts"
SkinBuilder.AVATAR = "Avatar"

local PART_CAPS = { Rare = 30, Epic = 40, Legendary = 60 }
local DEFAULT_CAP = 30
local MAX_PAINT = 160
local PPS = 100 -- pixels par stud des SurfaceGui de peinture (Stroke en px)
local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local LIMB_SET = {}
for _, n in ipairs(LIMBS) do
	LIMB_SET[n] = true
end
local SHAPES = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}
local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Metal = Enum.Material.Metal,
	ForceField = Enum.Material.ForceField,
	Foil = Enum.Material.Foil,
	Wood = Enum.Material.Wood,
	Fabric = Enum.Material.Fabric,
	Plastic = Enum.Material.Plastic,
	Marble = Enum.Material.Marble,
	DiamondPlate = Enum.Material.DiamondPlate,
	Ice = Enum.Material.Ice,
}
local FONTS = {
	Fredoka = Enum.Font.FredokaOne,
	Arcade = Enum.Font.Arcade,
	Code = Enum.Font.Code,
	Bangers = Enum.Font.Bangers,
	Black = Enum.Font.GothamBlack,
	Serif = Enum.Font.Garamond,
	SciFi = Enum.Font.SciFi,
	Cartoon = Enum.Font.Cartoon,
}
-- polices supplémentaires (pcall : une police absente ne casse pas le module)
for alias, enumName in pairs({
	Display = "FredokaOne", Body = "GothamMedium", Bold = "GothamBold", Marker = "PermanentMarker",
	Creepy = "Creepster", Hand = "IndieFlower", Tech = "Michroma", Lucky = "LuckiestGuy", Condensed = "Oswald",
}) do
	local ok, f = pcall(function()
		return Enum.Font[enumName]
	end)
	if ok and f then
		FONTS[alias] = f
	end
end
local MESH_TYPES = {
	Sphere = Enum.MeshType.Sphere,
	Cylinder = Enum.MeshType.Cylinder,
	Wedge = Enum.MeshType.Wedge,
	Brick = Enum.MeshType.Brick,
	Head = Enum.MeshType.Head,
	Torso = Enum.MeshType.Torso,
}
local FACES = {
	Front = Enum.NormalId.Front,
	Back = Enum.NormalId.Back,
	Top = Enum.NormalId.Top,
	Bottom = Enum.NormalId.Bottom,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
}
local TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Spark = "rbxasset://textures/particles/fire_sparks_main.dds",
}
local DEFAULT_SKIN = Color3.fromRGB(255, 204, 153)

local skinsMod
local function getSkins()
	if not skinsMod then
		skinsMod = require(Shared.Config.Skins)
	end
	return skinsMod
end

local function resolve(skin)
	if type(skin) == "table" then
		return skin
	end
	if type(skin) == "string" and skin ~= SkinBuilder.AVATAR then
		return getSkins().get(skin)
	end
	return nil
end

-- mode "statique" = modèle sans Humanoid (mannequin de menu) : parts ancrées, pas de soudures
local function isStatic(model)
	return model:FindFirstChildOfClass("Humanoid") == nil
end

local function basePart(className)
	local p = Instance.new(className)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	return p
end

local function attach(p, limb, offset, static, parent)
	p.CFrame = limb.CFrame * offset
	if static then
		p.Anchored = true
	else
		local w = Instance.new("WeldConstraint")
		w.Part0 = limb
		w.Part1 = p
		w.Parent = p
	end
	p.Parent = parent
	return p
end

-- helper au format de CharacterService (utilisé par les Identity des modules de Content)
local function makeProp(static)
	return function(parent: Instance, attachTo: BasePart, size: Vector3, offset: CFrame, color: Color3, shape)
		local p = basePart("Part")
		p.Size = size
		p.Color = color
		if shape then
			p.Shape = shape
		end
		return attach(p, attachTo, offset, static, parent)
	end
end
SkinBuilder.prop = makeProp(false)

------------------------------------------------------------------------
-- Accessoires de métier (anciennement dans CharacterService)
------------------------------------------------------------------------
local IDENTITY = {
	Intern = function(f, head, torso, c, prop)
		prop(f, torso, Vector3.new(0.7, 0.9, 0.1), CFrame.new(0, -0.2, -0.56), Color3.fromRGB(255, 255, 255)) -- badge
		prop(f, torso, Vector3.new(0.12, 1.1, 0.1), CFrame.new(-0.3, 0.45, -0.55) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(40, 110, 230))
		prop(f, torso, Vector3.new(0.12, 1.1, 0.1), CFrame.new(0.3, 0.45, -0.55) * CFrame.Angles(0, 0, -0.4), Color3.fromRGB(40, 110, 230))
	end,
	Janitor = function(f, head, torso, c, prop)
		prop(f, head, Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 0.62, 0), Color3.fromRGB(60, 120, 210)) -- casquette
		prop(f, head, Vector3.new(1.2, 0.12, 0.7), CFrame.new(0, 0.5, -0.85), Color3.fromRGB(60, 120, 210))
	end,
	LunchLady = function(f, head, torso, c, prop)
		prop(f, head, Vector3.new(1.35, 0.3, 1.35), CFrame.new(0, 0.55, 0.05), Color3.fromRGB(245, 245, 250)) -- charlotte
	end,
	SecurityGuard = function(f, head, torso, c, prop)
		prop(f, torso, Vector3.new(0.45, 0.45, 0.1), CFrame.new(-0.5, 0.4, -0.56) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 200, 40)) -- insigne
		prop(f, head, Vector3.new(1.35, 0.4, 1.35), CFrame.new(0, 0.62, 0), Color3.fromRGB(30, 40, 80))
		prop(f, head, Vector3.new(1.25, 0.12, 0.6), CFrame.new(0, 0.48, -0.85), Color3.fromRGB(20, 20, 30))
	end,
}
local contentLoaded = false
local function identityFor(charId)
	if not contentLoaded then
		contentLoaded = true
		local ok, all = pcall(function()
			return require(Shared.Modules.ContentLoader).all()
		end)
		if ok then
			for _, def in ipairs(all) do
				if type(def.Identity) == "function" and def.Id then
					IDENTITY[def.Id] = def.Identity
				end
			end
		end
	end
	return IDENTITY[charId]
end

function SkinBuilder.clearIdentity(model: Model)
	local f = model:FindFirstChild("IdentityProps")
	if f then
		f:Destroy()
	end
end

function SkinBuilder.identity(model: Model, charId: string)
	SkinBuilder.clearIdentity(model)
	local builder = identityFor(charId)
	local head, torso = model:FindFirstChild("Head"), model:FindFirstChild("Torso")
	if not builder or not head or not torso then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "IdentityProps"
	f.Parent = model
	local ok, err = pcall(builder, f, head, torso, model, makeProp(isStatic(model)))
	if not ok then
		warn("[SkinBuilder] Identity de", charId, err)
	end
	return f
end

------------------------------------------------------------------------
-- Avatar d'origine
------------------------------------------------------------------------
local BC_FIELDS = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

function SkinBuilder.snapshot(model: Model)
	local snap = { clothes = {}, colors = {} }
	for _, ch in ipairs(model:GetChildren()) do
		if ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") then
			table.insert(snap.clothes, ch:Clone())
		end
	end
	local bc = model:FindFirstChildOfClass("BodyColors")
	for i, field in ipairs(BC_FIELDS) do
		local limb = model:FindFirstChild(LIMBS[i])
		snap.colors[field] = bc and bc[field] or (limb and limb.Color) or DEFAULT_SKIN
	end
	return snap
end

local function clearClothes(model)
	for _, ch in ipairs(model:GetChildren()) do
		if ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") then
			ch:Destroy()
		end
	end
end

local function bodyColors(model)
	local bc = model:FindFirstChildOfClass("BodyColors")
	if not bc then
		bc = Instance.new("BodyColors")
		bc.Parent = model
	end
	return bc
end

-- couleurs d'origine d'un modèle statique (mémorisées au 1er habillage)
local function staticRestore(model)
	for _, n in ipairs(LIMBS) do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			local c = p:GetAttribute("_SkinOrig")
			if typeof(c) == "Color3" then
				p.Color = c
			else
				p:SetAttribute("_SkinOrig", p.Color)
			end
		end
	end
end

function SkinBuilder.restore(model: Model, snap)
	SkinBuilder.undress(model)
	if isStatic(model) then
		staticRestore(model)
		return
	end
	if not snap then
		return
	end
	clearClothes(model)
	for _, c in ipairs(snap.clothes) do
		c:Clone().Parent = model
	end
	local bc = bodyColors(model)
	for field, c in pairs(snap.colors) do
		bc[field] = c
	end
end

------------------------------------------------------------------------
-- Tenue
------------------------------------------------------------------------
local function applyOutfit(model, outfit, opts)
	outfit = type(outfit) == "table" and outfit or {}
	local shirt = typeof(outfit.Shirt) == "Color3" and outfit.Shirt or nil
	local pants = typeof(outfit.Pants) == "Color3" and outfit.Pants or nil
	local skin = typeof(outfit.Skin) == "Color3" and outfit.Skin or nil
	if isStatic(model) then
		staticRestore(model)
		local function set(n, c)
			local p = model:FindFirstChild(n)
			if p and p:IsA("BasePart") and c then
				p.Color = c
			end
		end
		local head = model:FindFirstChild("Head")
		local tone = skin or (head and head.Color) or DEFAULT_SKIN
		set("Head", skin)
		set("Torso", shirt)
		set("Left Arm", outfit.ArmsSkin and tone or shirt)
		set("Right Arm", outfit.ArmsSkin and tone or shirt)
		set("Left Leg", pants)
		set("Right Leg", pants)
		return
	end
	clearClothes(model)
	local bc = bodyColors(model)
	local orig = opts and opts.snapshot and opts.snapshot.colors or nil
	if orig then
		for field, c in pairs(orig) do
			bc[field] = c
		end
	end
	local tone = skin or bc.HeadColor3
	if skin then
		bc.HeadColor3 = skin
	end
	if shirt then
		bc.TorsoColor3 = shirt
		bc.LeftArmColor3 = outfit.ArmsSkin and tone or shirt
		bc.RightArmColor3 = outfit.ArmsSkin and tone or shirt
	elseif skin then
		bc.LeftArmColor3 = tone
		bc.RightArmColor3 = tone
	end
	if pants then
		bc.LeftLegColor3 = pants
		bc.RightLegColor3 = pants
	end
end

local BODY_ACCESSORIES = {
	[Enum.AccessoryType.Back] = true,
	[Enum.AccessoryType.Waist] = true,
	[Enum.AccessoryType.Shoulder] = true,
	[Enum.AccessoryType.Front] = true,
}
-- accessoires de l'avatar cachés selon le skin (restaurés par undress / unhideHats)
local function hideHats(model, def)
	local covers = false
	for _, pd in ipairs(def.Parts or {}) do
		if type(pd) == "table" and pd.Limb == "Head" and typeof(pd.Offset) == "CFrame" and pd.Offset.Position.Y >= 0.45 then
			covers = true
			break
		end
	end
	-- défaut v3 : Epic / Legendary => tous les accessoires cachés ; autres skins => dos / taille / épaules / devant
	-- cachés (chapeaux et cheveux gardés sauf HideHair, HideAccessories ou pièce sur le haut de la tête).
	-- KeepAccessories = true désactive ce défaut (HideHair / HideAccessories explicites restent appliqués).
	local keep = def.KeepAccessories == true
	local hideAll = def.HideAccessories == true or (not keep and (def.Rarity == "Epic" or def.Rarity == "Legendary"))
	local hideBody = not keep
	local hatsToo = covers or def.HideHair == true
	if not hideAll and not hideBody and not hatsToo then
		return
	end
	local head = model:FindFirstChild("Head")
	local function onHead(h)
		for _, j in ipairs(h:GetChildren()) do
			if (j:IsA("JointInstance") or j:IsA("WeldConstraint")) and head and (j.Part0 == head or j.Part1 == head) then
				return true
			end
		end
		return false
	end
	for _, acc in ipairs(model:GetChildren()) do
		if acc:IsA("Accessory") then
			local t = acc.AccessoryType
			local h = acc:FindFirstChild("Handle")
			-- HideAccessories : tout ; HideHair : tout ce qui est sur la tête ; auto (pièce sur la tête) : chapeaux / cheveux
			local hide = hideAll
				or (hideBody and BODY_ACCESSORIES[t] == true)
				or (hatsToo and (t == Enum.AccessoryType.Hat or t == Enum.AccessoryType.Hair))
				or (def.HideHair == true and h ~= nil and onHead(h))
			if hide then
				if h and h:IsA("BasePart") and h:GetAttribute("_SkinHid") == nil then
					h:SetAttribute("_SkinHid", h.Transparency)
					h.Transparency = 1
				end
			end
		end
	end
end

local function unhideHats(model)
	for _, acc in ipairs(model:GetChildren()) do
		if acc:IsA("Accessory") then
			local h = acc:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				local t = h:GetAttribute("_SkinHid")
				if t ~= nil then
					h.Transparency = t
					h:SetAttribute("_SkinHid", nil)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Options avancées des pièces (texte, traînée, particules, animation)
------------------------------------------------------------------------
local function addParticles(host, cfg, ctx)
	local e = Instance.new("ParticleEmitter")
	e.Name = "SkinParticles"
	e.Texture = TEXTURES[cfg.Kind] or TEXTURES.Sparkle
	e.Color = ColorSequence.new(typeof(cfg.Color) == "Color3" and cfg.Color or Color3.new(1, 1, 1))
	e.LightEmission = cfg.Kind == "Smoke" and 0.3 or 1
	local rate = tonumber(cfg.Rate) or 10
	e.Rate = rate
	local life = tonumber(cfg.Life) or 0.8
	e.Lifetime = NumberRange.new(life * 0.7, life)
	local sp = tonumber(cfg.Speed) or 2
	e.Speed = NumberRange.new(sp * 0.6, sp)
	local spread = tonumber(cfg.Spread) or 25
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = FACES[cfg.Dir] or Enum.NormalId.Top
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	local size = tonumber(cfg.Size) or 0.4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	if tonumber(cfg.Accel) then
		e.Acceleration = Vector3.new(0, cfg.Accel, 0)
	end
	e.Parent = host
	if cfg.TransformOnly and ctx then
		-- n'émet que pendant la transformation (dans l'aperçu statique : émet normalement)
		e.Rate = 0
		table.insert(ctx.reactive, function(on)
			e.Rate = on and rate or 0
		end)
	elseif cfg.React and ctx then
		table.insert(ctx.reactive, function(on)
			e.Rate = on and rate * 3 or rate
		end)
	end
	return e
end

local function addTrail(p, cfg)
	local col, width = cfg, 0.8
	if type(cfg) == "table" then
		col, width = cfg.Color, tonumber(cfg.Width) or width
	end
	if typeof(col) ~= "Color3" then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(col)
	t.LightEmission = 1
	t.Lifetime = 0.3
	t.MinLength = 0.05
	t.FaceCamera = true
	t.Transparency = NumberSequence.new(0.2, 1)
	t.WidthScale = NumberSequence.new(1, 0.1)
	t.Parent = p
end

local function addText(p, cfg)
	if type(cfg) == "string" then
		cfg = { Text = cfg }
	end
	local faces = cfg.Face == "Both" and { Enum.NormalId.Front, Enum.NormalId.Back } or { FACES[cfg.Face] or Enum.NormalId.Front }
	for _, face in ipairs(faces) do
		local g = Instance.new("SurfaceGui")
		g.Name = "SkinText"
		g.Face = face
		g.LightInfluence = 0
		g.Brightness = tonumber(cfg.Brightness) or 2
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 80
		g.ClipsDescendants = true
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Label"
		lbl.BorderSizePixel = 0
		lbl.BackgroundColor3 = typeof(cfg.Bg) == "Color3" and cfg.Bg or Color3.new(0, 0, 0)
		lbl.BackgroundTransparency = typeof(cfg.Bg) == "Color3" and 0 or 1
		lbl.Font = FONTS[cfg.Font] or Enum.Font.FredokaOne
		lbl.Text = tostring(cfg.Text or "")
		lbl.TextColor3 = typeof(cfg.Color) == "Color3" and cfg.Color or Color3.new(1, 1, 1)
		lbl.TextScaled = true
		lbl.TextStrokeTransparency = cfg.Stroke == false and 1 or 0.5
		lbl.Size = UDim2.fromScale(1, 1)
		local scroll = tonumber(cfg.Scroll)
		if scroll then
			local w = tonumber(cfg.Width) or 3
			lbl.Size = UDim2.fromScale(w, 1)
			lbl.BackgroundTransparency = 1
			lbl:SetAttribute("Scroll", scroll)
			lbl:SetAttribute("Width", w)
		end
		if tonumber(cfg.Blink) then
			lbl:SetAttribute("Blink", tonumber(cfg.Blink))
		end
		lbl.Parent = g
		g.Parent = p
		if scroll or tonumber(cfg.Blink) then
			CollectionService:AddTag(lbl, "SkinText")
		end
	end
end

-- effets attachés à une pièce (textes, particules, lumières, traînées...) : visibles seulement avec elle
local function setAttachedVisible(p, on)
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("LayerCollector") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail") or d:IsA("Beam")
			or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then
			if d.Enabled ~= on then
				d.Enabled = on
			end
		end
	end
end

-- pièce animée : Weld (C0 modifié par l'animateur client) ou, en mode statique, CFrame recalculé chaque frame
local function attachAnimated(p, limb, offset, static, parent, pd, ctx, design)
	local a = type(pd.Anim) == "table" and pd.Anim or {}
	p.CFrame = limb.CFrame * offset
	-- AnimBase = offset « design » (perso R6 standard) ; l'animateur l'adapte à l'échelle courante du perso
	p:SetAttribute("AnimBase", design or offset)
	p:SetAttribute("AnimLimb", limb.Name)
	-- Seed identique => pièces synchronisées (groupe rigide : drone, écran + cadre...)
	p:SetAttribute("AnimSeed", tonumber(a.Seed) or math.random() * 10)
	p:SetAttribute("AnimTr", p.Transparency)
	local function setNum(attr, v, scale)
		v = tonumber(v)
		if v then
			p:SetAttribute(attr, v * (scale or 1))
		end
	end
	setNum("AnimSpin", a.Spin, math.pi / 180)
	setNum("AnimBob", a.Bob)
	setNum("AnimBobSpeed", a.BobSpeed)
	setNum("AnimSwing", a.Swing, math.pi / 180)
	setNum("AnimSwingSpeed", a.SwingSpeed)
	setNum("AnimCircle", a.Circle)
	setNum("AnimPulseSpeed", a.PulseSpeed)
	if a.Axis then
		p:SetAttribute("AnimAxis", tostring(a.Axis))
	end
	if a.SwingAxis then
		p:SetAttribute("AnimSwingAxis", tostring(a.SwingAxis))
	end
	if a.Pulse then
		p:SetAttribute("AnimPulse", a.Pulse == true and 0.5 or tonumber(a.Pulse) or 0.5)
	end
	if a.Float then
		if p:GetAttribute("AnimBob") == nil then
			p:SetAttribute("AnimBob", 0.15)
		end
		if p:GetAttribute("AnimSwing") == nil then
			p:SetAttribute("AnimSwing", math.rad(6))
			p:SetAttribute("AnimSwingSpeed", 1.3)
		end
	end
	if a.React then
		p:SetAttribute("AnimReact", true)
	end
	if pd.Transform then
		p:SetAttribute("AnimTransform", true)
	end
	if static then
		p.Anchored = true
		p:SetAttribute("AnimStatic", true)
	else
		local w = Instance.new("Weld")
		w.Name = "SkinAnimWeld"
		w.Part0 = limb
		w.Part1 = p
		w.C0 = offset
		w.Parent = p
		if pd.Transform and ctx then
			local base = p.Transparency
			p.Transparency = 1
			table.insert(ctx.reactive, function(on)
				p.Transparency = on and base or 1
				setAttachedVisible(p, on)
			end)
		end
	end
	p.Parent = parent
	CollectionService:AddTag(p, "SkinAnim")
	return p
end

------------------------------------------------------------------------
-- Assets 3D (ReplicatedStorage.SkinAssets) : MeshPart / Part / Model clonés, mis à l'échelle, soudés
------------------------------------------------------------------------
local warnedAssets = {}
local function assetSource(name)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("SkinAssets")
	local src = folder and folder:FindFirstChild(name)
	if not src and not warnedAssets[name] then
		warnedAssets[name] = true
		warn("[SkinBuilder] asset introuvable dans ReplicatedStorage.SkinAssets :", name)
	end
	return src
end

local function sanitize(bp)
	bp.Anchored = false
	bp.CanCollide = false
	bp.CanQuery = false
	bp.CanTouch = false
	bp.Massless = true
	bp.CastShadow = false
end

local function overrideLook(bp, pd)
	if typeof(pd.Color) == "Color3" then
		bp.Color = pd.Color
		if not pd.KeepTexture then
			if bp:IsA("MeshPart") then
				bp.TextureID = ""
			end
			for _, d in ipairs(bp:GetChildren()) do
				if d:IsA("SurfaceAppearance") or d:IsA("Decal") then
					d:Destroy()
				elseif d:IsA("SpecialMesh") then
					d.TextureId = ""
				end
			end
		end
	end
	if MATERIALS[pd.Material] then
		bp.Material = MATERIALS[pd.Material]
	end
	if type(pd.Transparency) == "number" then
		bp.Transparency = pd.Transparency
	end
end

local function stripJunk(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
end

local function fitScale(size, want)
	if typeof(want) ~= "Vector3" then
		return 1
	end
	return math.min(want.X / math.max(size.X, 1e-3), want.Y / math.max(size.Y, 1e-3), want.Z / math.max(size.Z, 1e-3))
end

-- renvoie la part racine (le MeshPart lui-même, ou une part invisible portant le Model) + isModel
-- scale = échelle du perso (1 = R6 standard) : la boîte voulue (pd.Size) est agrandie d'autant
local function makeAsset(pd, scale)
	scale = scale or 1
	local src = assetSource(pd.Asset)
	if not src then
		return nil
	end
	local want = typeof(pd.Size) == "Vector3" and pd.Size * scale or nil
	if src:IsA("BasePart") then
		local p = src:Clone()
		stripJunk(p)
		local k = want and fitScale(p.Size, want) or scale
		p.Size = p.Size * k
		local sm = p:FindFirstChildOfClass("SpecialMesh")
		if sm and sm.MeshType == Enum.MeshType.FileMesh then
			sm.Scale = sm.Scale * k
		end
		sanitize(p)
		overrideLook(p, pd)
		p.Name = "SkinAsset"
		return p, false
	elseif src:IsA("Model") then
		local mdl = src:Clone()
		stripJunk(mdl)
		local cf, size = mdl:GetBoundingBox()
		local k = want and fitScale(size, want) or scale
		if math.abs(k - 1) > 1e-3 then
			mdl:ScaleTo(mdl:GetScale() * k)
			cf, size = mdl:GetBoundingBox()
		end
		local root = basePart("Part")
		root.Name = "SkinAsset"
		root.Size = size
		root.Transparency = 1
		root:SetAttribute("AssetModel", true)
		for _, d in ipairs(mdl:GetDescendants()) do
			if d:IsA("BasePart") then
				sanitize(d)
				overrideLook(d, pd)
				d:SetAttribute("_AssetRel", cf:ToObjectSpace(d.CFrame))
			end
		end
		mdl.Parent = root
		return root, true
	end
	return nil
end

-- après placement de la racine : place / soude les parts du Model
local function finishAssetModel(root, static, pd, ctx)
	local parts = {}
	for _, d in ipairs(root:GetDescendants()) do
		local rel = d:IsA("BasePart") and d:GetAttribute("_AssetRel")
		if typeof(rel) == "CFrame" then
			d.CFrame = root.CFrame * rel
			if static then
				d.Anchored = true
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
			table.insert(parts, { d, d.Transparency })
		end
	end
	if pd.Transform and ctx and not static then
		table.insert(ctx.reactive, function(on)
			for _, e in ipairs(parts) do
				e[1].Transparency = on and e[2] or 1
			end
		end)
	end
end

local function buildPart(folder, model, pd, static, ctx)
	if type(pd) ~= "table" or not LIMB_SET[pd.Limb] then
		return
	end
	local limb = model:FindFirstChild(pd.Limb)
	if not limb or not limb:IsA("BasePart") then
		return
	end
	local k = ctx and ctx.scale or 1
	local p, isModel
	if type(pd.Asset) == "string" then
		p, isModel = makeAsset(pd, k)
		if not p then
			return
		end
	else
		local shape = pd.Shape
		local size = typeof(pd.Size) == "Vector3" and pd.Size or Vector3.one
		local mesh = pd.Mesh
		if type(mesh) == "string" then
			mesh = { Type = mesh }
		end
		-- Ball / Cylinder aux dimensions non uniformes : Roblox les forcerait (sphère / section ronde) ;
		-- on garde la forme voulue (ellipsoïde / cylindre elliptique) avec un bloc + SpecialMesh.
		if mesh == nil and shape == "Ball" and (math.abs(size.X - size.Y) > 1e-3 or math.abs(size.Y - size.Z) > 1e-3) then
			shape, mesh = "Block", { Type = "Sphere" }
		elseif mesh == nil and shape == "Cylinder" and math.abs(size.Y - size.Z) > 1e-3 then
			shape, mesh = "Block", { Type = "Cylinder" }
		end
		local className = (shape == "Wedge" and "WedgePart") or (shape == "CornerWedge" and "CornerWedgePart") or "Part"
		p = basePart(className)
		p.Name = "SkinPart"
		if className == "Part" then
			p.Shape = SHAPES[shape] or Enum.PartType.Block
		end
		p.Size = size * k
		p.Color = typeof(pd.Color) == "Color3" and pd.Color or Color3.new(1, 1, 1)
		p.Material = MATERIALS[pd.Material] or Enum.Material.SmoothPlastic
		p.Transparency = type(pd.Transparency) == "number" and pd.Transparency or 0
		if type(mesh) == "table" then
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = MESH_TYPES[mesh.Type] or Enum.MeshType.Sphere
			if typeof(mesh.Scale) == "Vector3" then
				sm.Scale = mesh.Scale
			end
			if typeof(mesh.Offset) == "Vector3" then
				sm.Offset = mesh.Offset * k
			end
			sm.Parent = p
		end
	end
	if pd.Reflect then
		p.Reflectance = tonumber(pd.Reflect) or 0.3
	end
	local design = typeof(pd.Offset) == "CFrame" and pd.Offset or CFrame.new()
	-- offset à l'échelle du perso (les animations repartent de l'offset « design », mis à l'échelle à chaque frame)
	local offset = k == 1 and design or (CFrame.new(design.Position * k) * design.Rotation)
	if type(pd.Text) == "string" or type(pd.Text) == "table" then
		addText(p, pd.Text)
	end
	if pd.Trail ~= nil then
		addTrail(p, pd.Trail)
	end
	if typeof(pd.Light) == "Color3" then
		local l = Instance.new("PointLight")
		l.Color = pd.Light
		l.Range = 7
		l.Brightness = 1.3
		l.Shadows = false
		l.Parent = p
	end
	if type(pd.Particles) == "table" then
		addParticles(p, pd.Particles, ctx)
	end
	if type(pd.Anim) == "table" or pd.Transform == true then
		attachAnimated(p, limb, offset, static, folder, pd, ctx, design)
	else
		attach(p, limb, offset, static, folder)
	end
	if isModel then
		finishAssetModel(p, static, pd, ctx)
	end
end

-- part invisible soudée au buste qui porte les effets
local function fxHost(folder, torso, static, name, size, offset)
	local p = basePart("Part")
	p.Name = name
	p.Size = size or Vector3.new(2, 2, 1)
	p.Transparency = 1
	return attach(p, torso, offset or CFrame.new(), static, folder)
end

local function buildFX(folder, model, fx, static, ctx)
	local torso = model:FindFirstChild("Torso")
	if type(fx) ~= "table" or not torso then
		return
	end
	-- aura de puissance : discrète au repos, explose pendant la transformation (géré côté serveur)
	if typeof(fx.PowerAura) == "Color3" then
		local host = fxHost(folder, torso, static, "FXPowerAura", Vector3.new(2.6, 5, 1.6), CFrame.new(0, -0.5, 0))
		local e = addParticles(host, { Kind = "Sparkle", Color = fx.PowerAura, Rate = 6, Speed = 3, Size = 0.6, Life = 1, Spread = 10 })
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		local ring = addParticles(host, { Kind = "Spark", Color = fx.PowerAura, Rate = 0, Speed = 6, Size = 0.35, Life = 0.6, Spread = 180 })
		local l = Instance.new("PointLight")
		l.Color = fx.PowerAura
		l.Range = 9
		l.Brightness = 0.7
		l.Shadows = false
		l.Parent = host
		if ctx then
			table.insert(ctx.reactive, function(on)
				e.Rate = on and 40 or 6
				e.Speed = on and NumberRange.new(4, 8) or NumberRange.new(1.8, 3)
				ring.Rate = on and 25 or 0
				l.Brightness = on and 3 or 0.7
				l.Range = on and 14 or 9
			end)
		end
	end
	-- faisceau de projecteur au-dessus de la tête
	if typeof(fx.Spotlight) == "Color3" then
		local host = fxHost(folder, torso, static, "FXSpotlight", Vector3.new(0.2, 0.2, 0.2), CFrame.new())
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 7, 0)
		a0.Parent = host
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -3, 0)
		a1.Parent = host
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(fx.Spotlight)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.95), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.85) })
		beam.Width0 = 0.6
		beam.Width1 = 5
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = host
	end
	-- traînées aux mains
	if typeof(fx.HandTrails) == "Color3" then
		for _, n in ipairs({ "Left Arm", "Right Arm" }) do
			local arm = model:FindFirstChild(n)
			if arm then
				local h = fxHost(folder, arm, static, "FXHandTrail", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, -1, 0))
				addTrail(h, { Color = fx.HandTrails, Width = 0.9 })
			end
		end
	end
	if typeof(fx.Sparkles) == "Color3" then
		local s = Instance.new("Sparkles")
		s.SparkleColor = fx.Sparkles
		s.Parent = fxHost(folder, torso, static, "FXSparkles")
	end
	if typeof(fx.Aura) == "Color3" then
		local host = fxHost(folder, torso, static, "FXAura", Vector3.new(2.4, 4.5, 1.4), CFrame.new(0, -0.6, 0))
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(fx.Aura)
		e.LightEmission = 1
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1, 2.5)
		e.SpreadAngle = Vector2.new(15, 15)
		e.EmissionDirection = Enum.NormalId.Top
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = host
	end
	if typeof(fx.Trail) == "Color3" then
		local host = fxHost(folder, torso, static, "FXTrail")
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.9, 0.3)
		a0.Parent = host
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.9, 0.3)
		a1.Parent = host
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(fx.Trail)
		t.LightEmission = 0.8
		t.Lifetime = 0.35
		t.MinLength = 0.1
		t.Transparency = NumberSequence.new(0.3, 1)
		t.WidthScale = NumberSequence.new(1, 0.2)
		t.FaceCamera = true
		t.Parent = host
	end
	if typeof(fx.Light) == "Color3" then
		local l = Instance.new("PointLight")
		l.Color = fx.Light
		l.Range = 10
		l.Brightness = 1.6
		l.Shadows = false
		l.Parent = fxHost(folder, torso, static, "FXLight")
	end
	if typeof(fx.Fire) == "Color3" then
		local f = Instance.new("Fire")
		f.Color = fx.Fire
		f.SecondaryColor = fx.Fire:Lerp(Color3.new(1, 1, 1), 0.5)
		f.Size = 3
		f.Heat = 4
		f.Parent = fxHost(folder, torso, static, "FXFire")
	end
	local orbit = fx.Orbit
	if type(orbit) == "table" then
		local count = math.clamp(tonumber(orbit.Count) or 3, 1, 8)
		local size = math.clamp(tonumber(orbit.Size) or 0.4, 0.1, 1.5)
		local radius = 2
		local hub = basePart("Part")
		hub.Name = "OrbitHub"
		hub.Size = Vector3.one * 0.2
		hub.Transparency = 1
		hub.CFrame = torso.CFrame * CFrame.new(0, 0.6, 0)
		hub:SetAttribute("Radius", radius)
		hub:SetAttribute("Count", count)
		hub:SetAttribute("Y", 0.6)
		hub:SetAttribute("Speed", tonumber(orbit.Speed) or 2.2)
		if static then
			hub.Anchored = true
		else
			local w = Instance.new("Weld")
			w.Name = "OrbitWeld"
			w.Part0 = torso
			w.Part1 = hub
			w.C0 = CFrame.new(0, 0.6, 0)
			w.Parent = hub
		end
		hub.Parent = folder
		for i = 1, count do
			local p = basePart("Part")
			p.Name = "Orb"
			p.Shape = SHAPES[orbit.Shape] or Enum.PartType.Ball
			p.Size = Vector3.one * size
			p.Color = typeof(orbit.Color) == "Color3" and orbit.Color or Color3.new(1, 1, 1)
			p.Material = MATERIALS[orbit.Material] or Enum.Material.Neon
			p:SetAttribute("OrbitIndex", i)
			p.CFrame = hub.CFrame * CFrame.Angles(0, (i - 1) * math.pi * 2 / count, 0) * CFrame.new(radius, 0, 0)
			if static then
				p.Anchored = true
			else
				local w = Instance.new("WeldConstraint")
				w.Part0 = hub
				w.Part1 = p
				w.Parent = p
			end
			p.Parent = hub
		end
		CollectionService:AddTag(hub, "SkinOrbit")
	end
end

------------------------------------------------------------------------
-- Peinture (def.Paint) : SurfaceGui sur vrai perso, fines Parts sur mannequin (ViewportFrame)
------------------------------------------------------------------------
-- n = normale sortante, u = « droite » et v = « bas » pour quelqu'un qui regarde la face (espace local du membre)
local PAINT_FACES = {
	Front = { n = Vector3.new(0, 0, -1), u = Vector3.new(-1, 0, 0), v = Vector3.new(0, -1, 0) },
	Back = { n = Vector3.new(0, 0, 1), u = Vector3.new(1, 0, 0), v = Vector3.new(0, -1, 0) },
	Right = { n = Vector3.new(1, 0, 0), u = Vector3.new(0, 0, -1), v = Vector3.new(0, -1, 0) },
	Left = { n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 0, 1), v = Vector3.new(0, -1, 0) },
	Top = { n = Vector3.new(0, 1, 0), u = Vector3.new(0, 0, -1), v = Vector3.new(1, 0, 0), flat = true },
	Bottom = { n = Vector3.new(0, -1, 0), u = Vector3.new(0, 0, -1), v = Vector3.new(-1, 0, 0), flat = true },
}
local HEAD_R, HEAD_W = 0.6, 1.2 -- tête R6 ronde : rayon / zone peinte (studs)
local GEO_T = 0.01 -- épaisseur des parts de peinture (mannequin)

local function faceDims(F, size)
	local function ax(v)
		return math.abs(v.X) * size.X + math.abs(v.Y) * size.Y + math.abs(v.Z) * size.Z
	end
	return ax(F.u), ax(F.v), ax(F.n)
end

local function roundHead(limb)
	if limb.Name ~= "Head" then
		return false
	end
	return limb:IsA("MeshPart") or limb:FindFirstChildOfClass("SpecialMesh") ~= nil
end

-- géométrie d'un élément : centre (0..1), taille (studs), rotation (deg)
local function elemGeom(e, W, H)
	local rot = tonumber(e.Rotation) or 0
	if e.Type == "Line" and type(e.From) == "table" and type(e.To) == "table" then
		local x1, y1 = (tonumber(e.From[1]) or 0) * W, (tonumber(e.From[2]) or 0) * H
		local x2, y2 = (tonumber(e.To[1]) or 0) * W, (tonumber(e.To[2]) or 0) * H
		local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
		local th = (tonumber(e.Width) or 4) / PPS
		return (x1 + x2) / 2 / W, (y1 + y2) / 2 / H, math.max(len, 0.01), th, math.deg(math.atan2(y2 - y1, x2 - x1)) + rot
	end
	local pos = type(e.Pos) == "table" and e.Pos or {}
	local size = type(e.Size) == "table" and e.Size or {}
	local sw = (tonumber(size[1]) or 0.2) * W
	local sh = (tonumber(size[2]) or 0.2) * H
	if e.Type == "Line" and tonumber(e.Width) then
		sh = tonumber(e.Width) / PPS
	end
	return tonumber(pos[1]) or 0.5, tonumber(pos[2]) or 0.5, math.max(sw, 0.005), math.max(sh, 0.005), rot
end

-- repère local (membre) d'un élément : X = droite, Y = haut, Z = sortant
local function flatFrame(F, W, H, D, cx, cy, lift)
	local pos = F.n * (D / 2 + lift) + F.u * ((cx - 0.5) * W) + F.v * ((cy - 0.5) * H)
	return CFrame.fromMatrix(pos, F.u, -F.v, F.n)
end
local function headFrame(F, cx, cy, lift)
	if F.flat then
		return flatFrame(F, HEAD_W, HEAD_W, HEAD_W, cx, cy, lift)
	end
	local th = ((cx - 0.5) * HEAD_W) / HEAD_R
	local dir = F.n * math.cos(th) + F.u * math.sin(th)
	local tan = F.u * math.cos(th) - F.n * math.sin(th)
	local pos = dir * (HEAD_R + lift) + F.v * ((cy - 0.5) * HEAD_W)
	return CFrame.fromMatrix(pos, tan, -F.v, dir)
end

local function newPaintGui(face, glow, z)
	local g = Instance.new("SurfaceGui")
	g.Name = "SkinPaint"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = PPS
	g.LightInfluence = glow and 0 or 1
	g.Brightness = glow and 1.6 or 1
	g.ZOffset = z or 0
	g.ClipsDescendants = false
	pcall(function()
		g.MaxDistance = 150
	end)
	return g
end

local function guiElement(parent, e, cx, cy, sw, sh, rot, W, H, z)
	local isText = e.Type == "Text"
	local o = Instance.new(isText and "TextLabel" or "Frame")
	o.Name = tostring(e.Type or "Box")
	o.BorderSizePixel = 0
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromScale(cx, cy)
	o.Size = UDim2.fromScale(sw / W, sh / H)
	o.Rotation = rot
	o.ZIndex = z
	local col = typeof(e.Color) == "Color3" and e.Color or Color3.new(1, 1, 1)
	local tr = tonumber(e.Transparency) or 0
	if isText then
		o.BackgroundTransparency = 1
		o.Text = tostring(e.Text or "")
		o.Font = FONTS[e.Font] or Enum.Font.FredokaOne
		o.TextColor3 = col
		o.TextTransparency = tr
		if e.Wrap == true then
			o.TextScaled = true
			o.TextWrapped = true
		else
			-- taille calculée (TextScaled est peu fiable sur les petits canevas de SurfaceGui)
			local wPx, hPx = sw * PPS, sh * PPS
			local size = math.clamp(math.floor(hPx * 0.95), 1, 100)
			local ok, b = pcall(TextService.GetTextSize, TextService, o.Text, size, o.Font, Vector2.new(4000, 4000))
			if ok and b.X > wPx and b.X > 0 then
				size = math.max(1, math.floor(size * wPx / b.X))
			end
			o.TextSize = size
		end
	else
		o.BackgroundColor3 = col
		o.BackgroundTransparency = tr
		local corner = e.Type == "Circle" and 0.5 or (tonumber(e.Corner) and math.clamp(e.Corner, 0, 1) * 0.5) or 0
		if corner > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(corner, 0)
			c.Parent = o
		end
	end
	if type(e.Stroke) == "table" and typeof(e.Stroke[1]) == "Color3" then
		local s = Instance.new("UIStroke")
		s.Color = e.Stroke[1]
		s.Thickness = tonumber(e.Stroke[2]) or 2
		s.Transparency = tr
		s.ApplyStrokeMode = isText and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = o
	end
	o.Parent = parent
	return o
end

-- petite plaque invisible tangente portant un SurfaceGui (tête ronde, textes du mannequin)
local function paintPlate(folder, limb, frame, e, cx, cy, sw, sh, rot, glow, static)
	local r = math.rad(rot)
	local bw = math.abs(sw * math.cos(r)) + math.abs(sh * math.sin(r))
	local bh = math.abs(sw * math.sin(r)) + math.abs(sh * math.cos(r))
	local p = basePart("Part")
	p.Name = "SkinPaintPlate"
	p.Transparency = 1
	p.Size = Vector3.new(math.max(bw, 0.02), math.max(bh, 0.02), 0.02)
	attach(p, limb, frame, static, folder)
	local g = newPaintGui(Enum.NormalId.Back, glow, 0)
	guiElement(g, e, 0.5, 0.5, sw, sh, rot, p.Size.X, p.Size.Y, 1)
	g.Parent = p
end

-- élément en géométrie (mannequin) : fine Part (Box / Line) ou disque elliptique (Circle, Corner >= 0.45)
local function paintGeo(folder, limb, frame, e, sw, sh, rot, glow)
	local base = limb.CFrame * frame * CFrame.Angles(0, 0, -math.rad(rot))
	local tr = tonumber(e.Transparency) or 0
	local mat = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local function piece(col, cf)
		local p = basePart("Part")
		p.Name = "SkinPaintGeo"
		p.Color = col
		p.Transparency = tr
		p.Material = mat
		p.CFrame = cf
		p.Anchored = true
		return p
	end
	local function rect(w, h, col, cf)
		local p = piece(col, cf)
		p.Size = Vector3.new(w, h, GEO_T)
		p.Parent = folder
	end
	-- ellipse : cylindre (axe = normale) étiré par l'échelle du SpecialMesh
	local function disc(w, h, col, cf)
		local d = math.max(math.min(w, h), 0.002)
		local p = piece(col, cf * CFrame.Angles(0, math.pi / 2, 0))
		p.Size = Vector3.new(GEO_T, d, d)
		local sm = Instance.new("SpecialMesh")
		sm.MeshType = Enum.MeshType.Cylinder
		sm.Scale = Vector3.new(1, h / d, w / d)
		sm.Parent = p
		p.Parent = folder
	end
	local function shape(w, h, col, back, r)
		local cf = base * CFrame.new(0, 0, back)
		if e.Type == "Circle" then
			disc(w, h, col, cf)
		elseif r < 0.012 then
			rect(w, h, col, cf)
		else
			-- rectangle arrondi = 2 rectangles en croix + 4 disques d'angle
			if w - 2 * r > 0.004 then
				rect(w - 2 * r, h, col, cf)
			end
			if h - 2 * r > 0.004 then
				rect(w, h - 2 * r, col, cf)
			end
			local seen = {}
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					local x, y = sx * math.max(w / 2 - r, 0), sy * math.max(h / 2 - r, 0)
					local k = string.format("%.3f_%.3f", x, y)
					if not seen[k] then
						seen[k] = true
						disc(2 * r, 2 * r, col, cf * CFrame.new(x, y, 0))
					end
				end
			end
		end
	end
	local r = math.clamp(tonumber(e.Corner) or 0, 0, 1) * 0.5 * math.min(sw, sh)
	if type(e.Stroke) == "table" and typeof(e.Stroke[1]) == "Color3" then
		local st = (tonumber(e.Stroke[2]) or 2) / PPS
		shape(sw + st * 2, sh + st * 2, e.Stroke[1], -0.0015, r > 0 and r + st or 0)
	end
	shape(sw, sh, typeof(e.Color) == "Color3" and e.Color or Color3.new(1, 1, 1), 0, r)
end

local function buildPaint(folder, model, paint, static)
	local count = 0
	local stack = {} -- empilement par face (chaque élément un peu plus haut que le précédent)
	for li, layer in ipairs(paint) do
		if type(layer) ~= "table" or type(layer.Elements) ~= "table" then
			continue
		end
		local limb = model:FindFirstChild(layer.Limb or "Torso")
		local faceName = layer.Face or "Front"
		local F = PAINT_FACES[faceName]
		if not (limb and limb:IsA("BasePart") and LIMB_SET[limb.Name] and F) then
			continue
		end
		local glow = layer.Glow == true
		local head = roundHead(limb)
		local W, H, D
		if head then
			W, H, D = HEAD_W, HEAD_W, HEAD_W
		else
			W, H, D = faceDims(F, limb.Size)
		end
		local key = limb.Name .. faceName
		local gui
		for ei, e in ipairs(layer.Elements) do
			if type(e) ~= "table" then
				continue
			end
			count += 1
			if count > MAX_PAINT then
				return
			end
			local cx, cy, sw, sh, rot = elemGeom(e, W, H)
			stack[key] = (stack[key] or 0) + 1
			local lift = 0.004 + stack[key] * 0.002
			if not static and not head then
				-- vrai perso, face plate : un SurfaceGui par couche, Adornee = membre (undress le détruit avec le dossier)
				if not gui then
					gui = newPaintGui(FACES[faceName], glow, li)
					gui.Adornee = limb
					gui.Parent = folder
				end
				guiElement(gui, e, cx, cy, sw, sh, rot, W, H, ei)
			else
				local frame = head and headFrame(F, cx, cy, lift) or flatFrame(F, W, H, D, cx, cy, lift)
				if not static or e.Type == "Text" then
					paintPlate(folder, limb, frame, e, cx, cy, sw, sh, rot, glow, static)
				else
					paintGeo(folder, limb, frame, e, sw, sh, rot, glow)
				end
			end
		end
	end
end

-- visage (Decals de la tête) caché / restauré
local function setFaceHidden(model, hide)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then
			local t = d:GetAttribute("_SkinFaceT")
			if hide then
				if t == nil then
					d:SetAttribute("_SkinFaceT", d.Transparency)
					d.Transparency = 1
				end
			elseif t ~= nil then
				d.Transparency = t
				d:SetAttribute("_SkinFaceT", nil)
			end
		end
	end
end

-- tête d'avatar personnalisée (FileMesh) -> tête R6 classique tant que le skin peint le visage (restaurée au undress)
local function setClassicHead(model, on)
	-- On ne modifie JAMAIS le mesh de l'avatar (les changements MeshId/MeshType répliquent mal) : l'original est rangé
	-- (clone) dans Head._SkinOrigMesh puis remplacé par une SpecialMesh NEUVE de type Head ; undress fait l'inverse.
	-- Tête MeshPart (tête dynamique) : la tête est rendue invisible et une tête R6 classique soudée la remplace.
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	if on then
		if head:FindFirstChild("_SkinOrigMesh") or head:GetAttribute("_SkinHeadT") ~= nil then
			return -- déjà en tête classique
		end
		if head:IsA("MeshPart") then
			head:SetAttribute("_SkinHeadT", head.Transparency)
			head.Transparency = 1
			local folder = model:FindFirstChild(SkinBuilder.FOLDER)
			local proxy = basePart("Part")
			proxy.Name = "SkinClassicHead"
			proxy.Size = Vector3.new(2, 1, 1)
			proxy.Color = head.Color
			local bc = model:FindFirstChildOfClass("BodyColors")
			if bc then
				proxy.Color = bc.HeadColor3
			end
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.Head
			sm.Scale = Vector3.new(1.25, 1.25, 1.25)
			sm.Parent = proxy
			attach(proxy, head, CFrame.new(), false, folder or model)
			return
		end
		local orig = head:FindFirstChildOfClass("SpecialMesh")
		if not orig or orig.MeshType ~= Enum.MeshType.FileMesh then
			return -- tête déjà classique (ou sans mesh) : rien à faire
		end
		local store = Instance.new("Folder")
		store.Name = "_SkinOrigMesh"
		orig:Clone().Parent = store
		local sm = Instance.new("SpecialMesh")
		sm.Name = orig.Name
		sm.MeshType = Enum.MeshType.Head
		sm.Scale = Vector3.new(1.25, 1.25, 1.25)
		sm:SetAttribute("_SkinClassic", true)
		orig:Destroy()
		store.Parent = head
		sm.Parent = head
	else
		local t = head:GetAttribute("_SkinHeadT")
		if t ~= nil then
			head.Transparency = t
			head:SetAttribute("_SkinHeadT", nil)
			local proxy = model:FindFirstChild("SkinClassicHead", true)
			if proxy then
				proxy:Destroy()
			end
		end
		local store = head:FindFirstChild("_SkinOrigMesh")
		if store then
			for _, d in ipairs(head:GetChildren()) do
				if d:IsA("SpecialMesh") and d:GetAttribute("_SkinClassic") then
					d:Destroy()
				end
			end
			local orig = store:FindFirstChildOfClass("SpecialMesh")
			if orig then
				orig:Clone().Parent = head
			end
			store:Destroy()
		end
	end
end

local function paintsHead(def)
	if def.HideFace or def.ClassicHead then
		return true
	end
	for _, layer in ipairs(type(def.Paint) == "table" and def.Paint or {}) do
		if type(layer) == "table" and layer.Limb == "Head" then
			return true
		end
	end
	return false
end

function SkinBuilder.undress(model: Model)
	if not model then
		return
	end
	local f = model:FindFirstChild(SkinBuilder.FOLDER)
	if f then
		f:Destroy()
	end
	setFaceHidden(model, false)
	setClassicHead(model, false)
	if model:GetAttribute("SkinHitColor") ~= nil then
		model:SetAttribute("SkinHitColor", nil)
	end
	unhideHats(model)
end

-- contour (Highlight) + couleur d'impact
local function buildExtras(folder, model, def, static, ctx)
	if typeof(def.HitColor) == "Color3" and not static then
		model:SetAttribute("SkinHitColor", def.HitColor)
	end
	local hl = def.Highlight
	if type(hl) == "table" and not static then
		local h = Instance.new("Highlight")
		h.Name = "SkinHighlight"
		h.Adornee = model
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineColor = typeof(hl.Outline) == "Color3" and hl.Outline or Color3.new(1, 1, 1)
		h.FillColor = typeof(hl.Fill) == "Color3" and hl.Fill or h.OutlineColor
		h.FillTransparency = typeof(hl.Fill) == "Color3" and 0.82 or 1
		h.OutlineTransparency = 0.1
		h.Enabled = false
		h.Parent = folder
		table.insert(ctx.reactive, function(on)
			h.Enabled = on or hl.Always == true
		end)
	end
end

-- réactions à la transformation (attribut "Transformed" du perso), côté serveur => répliqué à tous
local function hookReactive(model, folder, list)
	if #list == 0 then
		return
	end
	local function apply()
		local on = model:GetAttribute("Transformed") == true
		for _, fn in ipairs(list) do
			pcall(fn, on)
		end
	end
	local conn = model:GetAttributeChangedSignal("Transformed"):Connect(function()
		if folder.Parent then
			apply()
		end
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)
	apply()
end

-- échelle du perso par rapport au R6 standard (buste 2 studs de haut) : 1 en temps normal, 1.15 si le perso a été
-- agrandi (Model:ScaleTo), etc. Les pièces (tailles, offsets, assets) suivent cette échelle.
local function bodyScale(model)
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return 1
	end
	local k = math.clamp(torso.Size.Y / 2, 0.25, 4)
	return math.abs(k - 1) < 0.01 and 1 or k
end

-- Legendary : reflet qui balaie les pièces métal / dorure (animateur client, attribut ShimmerBase)
local SHIMMER_MATS = { [Enum.Material.Metal] = true, [Enum.Material.Foil] = true, [Enum.Material.DiamondPlate] = true }
local MAX_SHIMMER = 24
local function markShimmer(folder)
	local n = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and SHIMMER_MATS[d.Material] and d.Transparency < 0.5 then
			d:SetAttribute("ShimmerBase", d.Reflectance)
			CollectionService:AddTag(d, "SkinShimmer")
			n += 1
			if n >= MAX_SHIMMER then
				break
			end
		end
	end
end

function SkinBuilder.dress(model: Model, skin, opts)
	if not model then
		return nil
	end
	opts = opts or {}
	local def = resolve(skin)
	if not def then
		if skin ~= nil and skin ~= SkinBuilder.AVATAR then
			warn("[SkinBuilder] skin inconnu :", skin)
		end
		SkinBuilder.restore(model, opts.snapshot)
		return nil
	end
	SkinBuilder.undress(model)
	local static = isStatic(model)
	applyOutfit(model, def.Outfit, opts)
	if not static then
		hideHats(model, def)
	end
	local folder = Instance.new("Folder")
	folder.Name = SkinBuilder.FOLDER
	folder:SetAttribute("SkinId", def.Id)
	folder:SetAttribute("HideIdentity", def.HideIdentity == true)
	folder.Parent = model
	local ctx = { reactive = {}, scale = bodyScale(model) }
	local n = 0
	local cap = PART_CAPS[def.Rarity] or DEFAULT_CAP
	for _, pd in ipairs(type(def.Parts) == "table" and def.Parts or {}) do
		n += 1
		if n > cap then
			warn("[SkinBuilder] trop de pièces dans", def.Id, "(max " .. cap .. ")")
			break
		end
		local ok, err = pcall(buildPart, folder, model, pd, static, ctx)
		if not ok then
			warn("[SkinBuilder] part ignorée dans", def.Id, err)
		end
	end
	local ok, err = pcall(buildFX, folder, model, def.FX, static, ctx)
	if not ok then
		warn("[SkinBuilder] FX ignorés dans", def.Id, err)
	end
	local ok2, err2 = pcall(buildExtras, folder, model, def, static, ctx)
	if not ok2 then
		warn("[SkinBuilder] extras ignorés dans", def.Id, err2)
	end
	if not static and paintsHead(def) then
		setClassicHead(model, true)
	end
	if type(def.Paint) == "table" then
		local ok3, err3 = pcall(buildPaint, folder, model, def.Paint, static)
		if not ok3 then
			warn("[SkinBuilder] peinture ignorée dans", def.Id, err3)
		end
	end
	if def.HideFace then
		setFaceHidden(model, true)
	end
	if def.Rarity == "Legendary" and def.Shimmer ~= false then
		markShimmer(folder)
	end
	if not static then
		hookReactive(model, folder, ctx.reactive)
	end
	return folder
end

------------------------------------------------------------------------
-- Mannequin pour ViewportFrame
------------------------------------------------------------------------
function SkinBuilder.mannequin()
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local function part(name, size, color, cf)
		local p = basePart("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Anchored = true
		p.Massless = false
		p.CFrame = cf
		p:SetAttribute("_SkinOrig", color)
		p.Parent = model
		return p
	end
	local skin = DEFAULT_SKIN
	local base = CFrame.new(0, 3, 0)
	-- proportions R6 exactes (Torso 2x2x1, tête 2x1x1 + mesh Head, membres 1x2x1)
	local torso = part("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(236, 238, 244), base)
	local head = part("Head", Vector3.new(2, 1, 1), skin, base * CFrame.new(0, 1.5, 0))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	-- bras très légèrement écartés (pivot à l'épaule) : pose plus vivante dans les aperçus
	local spread = math.rad(3.5)
	part("Left Arm", Vector3.new(1, 2, 1), skin, base * CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, 0, -spread) * CFrame.new(-0.5, -0.5, 0))
	part("Right Arm", Vector3.new(1, 2, 1), skin, base * CFrame.new(1, 0.5, 0) * CFrame.Angles(0, 0, spread) * CFrame.new(0.5, -0.5, 0))
	part("Left Leg", Vector3.new(1, 2, 1), Color3.fromRGB(70, 82, 112), base * CFrame.new(-0.5, -2, 0))
	part("Right Leg", Vector3.new(1, 2, 1), Color3.fromRGB(70, 82, 112), base * CFrame.new(0.5, -2, 0))
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.CastShadow = true
		end
	end
	model.PrimaryPart = torso
	model:SetAttribute("SkinMannequin", true)
	return model
end

------------------------------------------------------------------------
-- Animateur client UNIQUE (orbites + pièces animées + textes défilants) : une seule boucle RenderStepped
------------------------------------------------------------------------
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
local CULL = 160 -- au-delà, on n'anime pas (perf)

local function stepOrbits(t)
	for _, hub in ipairs(CollectionService:GetTagged("SkinOrbit")) do
		local speed = hub:GetAttribute("Speed") or 2.2
		local y = hub:GetAttribute("Y") or 0.6
		local angle = (t * speed) % (math.pi * 2)
		local weld = hub:FindFirstChild("OrbitWeld")
		if weld then
			weld.C0 = CFrame.new(0, y + math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, angle, 0)
		else
			local model = hub.Parent and hub.Parent.Parent
			local torso = model and model:FindFirstChild("Torso")
			if torso then
				local count = hub:GetAttribute("Count") or 3
				local radius = hub:GetAttribute("Radius") or 2
				local center = torso.CFrame * CFrame.new(0, y + math.sin(t * 2) * 0.25, 0)
				hub.CFrame = center
				for _, orb in ipairs(hub:GetChildren()) do
					local i = orb:GetAttribute("OrbitIndex")
					if i and orb:IsA("BasePart") then
						orb.CFrame = center * CFrame.Angles(0, angle + (i - 1) * math.pi * 2 / count, 0) * CFrame.new(radius, 0, 0)
					end
				end
			end
		end
	end
end

local animCache = setmetatable({}, { __mode = "k" })
local function readAnim(p)
	local function g(n)
		return p:GetAttribute(n)
	end
	local base = g("AnimBase")
	return {
		base = typeof(base) == "CFrame" and base or CFrame.new(),
		limb = g("AnimLimb") or "Torso",
		ph = g("AnimSeed") or 0,
		tr = g("AnimTr") or 0,
		spin = g("AnimSpin"),
		axis = AXES[g("AnimAxis") or "Y"] or Vector3.yAxis,
		bob = g("AnimBob"),
		bobSpeed = g("AnimBobSpeed") or 2,
		swing = g("AnimSwing"),
		swingSpeed = g("AnimSwingSpeed") or 2,
		swingAxis = AXES[g("AnimSwingAxis") or "Z"] or Vector3.zAxis,
		circle = g("AnimCircle"),
		pulse = g("AnimPulse"),
		pulseSpeed = g("AnimPulseSpeed") or 3,
		react = g("AnimReact") == true,
		transform = g("AnimTransform") == true,
		static = g("AnimStatic") == true,
		weld = p:FindFirstChild("SkinAnimWeld"),
		follow = (g("AssetModel") == true and g("AnimStatic") == true) and (function()
			-- asset Model sur mannequin : les parts suivent la racine animée
			local list = {}
			for _, d in ipairs(p:GetDescendants()) do
				local rel = d:IsA("BasePart") and d:GetAttribute("_AssetRel")
				if typeof(rel) == "CFrame" then
					table.insert(list, { d, rel })
				end
			end
			return list
		end)() or nil,
	}
end

local function stepParts(dt, camPos)
	local trCache = {}
	local scaleCache = {}
	for _, p in ipairs(CollectionService:GetTagged("SkinAnim")) do
		local a = animCache[p]
		if not a then
			a = readAnim(p)
			animCache[p] = a
		end
		local model = p.Parent and p.Parent.Parent
		if not model then
			continue
		end
		if not a.static then
			if not a.weld or a.weld.Parent ~= p then
				animCache[p] = nil -- soudure pas encore répliquée : on réessaie
				continue
			end
			if (p.Position - camPos).Magnitude > CULL then
				continue
			end
		end
		local on = false
		if (a.react or a.transform) and not a.static then
			on = trCache[model]
			if on == nil then
				on = model:GetAttribute("Transformed") == true
				trCache[model] = on
			end
		end
		if a.transform and not a.static then
			if a.vis ~= on then
				a.vis = on
				setAttachedVisible(p, on)
			end
			if not on then
				if p.Transparency ~= 1 then
					p.Transparency = 1
				end
				continue
			end
		end
		a.ph += dt * ((on and a.react) and 2.5 or 1)
		local ph = a.ph
		local cf = a.base
		if a.circle then
			cf = CFrame.Angles(0, ph * a.circle, 0) * cf
		end
		if a.bob then
			cf = cf + Vector3.new(0, math.sin(ph * a.bobSpeed) * a.bob, 0)
		end
		if a.swing then
			cf = cf * CFrame.fromAxisAngle(a.swingAxis, math.sin(ph * a.swingSpeed) * a.swing)
		end
		if a.spin then
			cf = cf * CFrame.fromAxisAngle(a.axis, ph * a.spin)
		end
		-- perso agrandi / réduit (Model:ScaleTo) : l'offset suit l'échelle du buste
		local k = scaleCache[model]
		if k == nil then
			k = bodyScale(model)
			scaleCache[model] = k
		end
		if k ~= 1 then
			cf = CFrame.new(cf.Position * k) * cf.Rotation
		end
		if a.static then
			local limb = model:FindFirstChild(a.limb)
			if limb and limb:IsA("BasePart") then
				p.CFrame = limb.CFrame * cf
				if a.follow then
					for _, f in ipairs(a.follow) do
						f[1].CFrame = p.CFrame * f[2]
					end
				end
			end
		else
			a.weld.C0 = cf
		end
		if a.pulse then
			p.Transparency = math.clamp(a.tr + (0.5 + 0.5 * math.sin(ph * a.pulseSpeed)) * a.pulse, 0, 1)
		elseif a.transform and not a.static and p.Transparency ~= a.tr then
			p.Transparency = a.tr
		end
	end
end

-- reflet Legendary : un éclat qui monte le long du perso toutes les ~3,5 s
local function stepShimmer(t, camPos)
	for _, p in ipairs(CollectionService:GetTagged("SkinShimmer")) do
		local base = p:GetAttribute("ShimmerBase")
		if type(base) ~= "number" or not p:IsA("BasePart") then
			continue
		end
		if (p.Position - camPos).Magnitude > CULL * 0.5 then
			continue
		end
		local wave = math.sin(t * 1.8 - p.Position.Y * 0.9)
		local glint = wave > 0.9 and (wave - 0.9) * 10 or 0
		local r = math.clamp(base + glint * 0.3, 0, 1)
		if math.abs(p.Reflectance - r) > 0.005 then
			p.Reflectance = r
		end
	end
end

local function stepTexts(t)
	for _, lbl in ipairs(CollectionService:GetTagged("SkinText")) do
		local s = lbl:GetAttribute("Scroll")
		if s then
			local w = lbl:GetAttribute("Width") or 3
			lbl.Position = UDim2.fromScale(1 - ((t * s) % (1 + w)), 0)
		end
		local b = lbl:GetAttribute("Blink")
		if b then
			lbl.TextTransparency = ((t * b) % 1 < 0.6) and 0 or 0.85
		end
	end
end

if RunService:IsClient() and RunService:IsRunning() and not _G.__SkinAnimator then
	_G.__SkinAnimator = true
	_G.__SkinOrbitAnimator = true
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		local ok, err = pcall(function()
			stepOrbits(t)
			stepParts(math.min(dt, 0.1), camPos)
			stepTexts(t)
			stepShimmer(t, camPos)
		end)
		if not ok and not _G.__SkinAnimWarned then
			_G.__SkinAnimWarned = true
			warn("[SkinBuilder] animateur :", err)
		end
	end)
end

return SkinBuilder
