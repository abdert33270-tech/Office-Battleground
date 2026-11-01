--[[
	CharacterSelectController — menu PERSONNAGES & SKINS + ouverture de la MALLETTE MYSTÈRE.
	Ouverture : bouton « CHARACTER » du menu du HUD, et automatiquement à l'arrivée (choix auto après 8 s
	si le joueur ne touche à rien ; dès qu'il clique, le compte à rebours s'arrête).
	PC + téléphone : fenêtre dessinée en 1000x576 « unités design », mise à l'échelle par UIScale selon l'écran,
	listes qui défilent (grille des persos, infos).
	  Gauche : grille des persos (Config/Characters.Order), portrait 3D = skin équipé (Base si « Avatar »).
	  Centre : aperçu 3D qui tourne (glisser pour tourner). Droite : passif, 3 attaques, transformation + 3 attaques.
	  Bas : skins (MY AVATAR, Base, Rare, Epic, Legendary), EQUIP, PLAY AS <NOM>.
	Boutique de caisses (Config/Skins.Crates) : 7 cartes (caisse 3D, prix, chances, pool, OPEN), rouleau (result.reel,
	gagnant à l'index 25) puis révélation cinématique ctx.SkinRevealController.play (secours : panneau interne).
	SHOWCASE (rangée des skins) rejoue la cinématique d'un skin possédé.
	Réseau (contrat skins) : RemoteFunction SkinRequest ("State" | "Equip" | "OpenCrate", crateId), RemoteEvent SkinState,
	RemoteEvent SelectCharacter(name) (CharacterService).
	API : Select.open(withTimer), Select.close(), Select.choose(name), Select.openBriefcase(crateId?) (= openCrateShop), Select.showcase(skinId)
	DÉBLOCAGE (Config/Unlocks, RemoteFunction UnlockRequest "State" | "BuyCash" | "BuyRobux", RemoteEvent UnlockState) :
	  cartes verrouillées (cadenas + pastille "$2,500" / "R$ 299" / "FREE" / "OWNED"), skins consultables,
	  PLAY seulement si possédé sinon BUY (fenêtre de confirmation pour le Cash, Game Pass pour Robux,
	  "COMING SOON" tant que GamePassId = 0). Le choix auto de l'arrivée ne prend qu'un perso possédé.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local UIKit = require(script.Parent.UIKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared:WaitForChild("Config"):WaitForChild("Characters"))

-- polices : UITheme s'il existe (agent « uipolish »), sinon celles d'UIKit. Aucune autre police codée en dur.
local Theme = nil
do
	local mods = Shared:FindFirstChild("Modules")
	local m = mods and mods:FindFirstChild("UITheme")
	if m then
		local ok, t = pcall(require, m)
		Theme = ok and type(t) == "table" and t or nil
	end
end
local FONT = Theme and typeof(Theme.Font) == "EnumItem" and Theme.Font or UIKit.Font -- Enum.Font (propriété .Font)
local BODY = Theme and typeof(Theme.FontBody) == "EnumItem" and Theme.FontBody or UIKit.Body

local Select = {}
Select.Priority = 45

local player = Players.LocalPlayer
local hud
local AVATAR = "Avatar"
local W, H = 1000, 576 -- taille « design » des fenêtres
local REEL_WIN, STEP, REEL_CARD = 25, 140, 130 -- rouleau : gagnant à l'index 25, une carte tous les 140 px

local COL = {
	Panel = UIKit.Colors.Panel,
	Dark = UIKit.Colors.PanelDark,
	Card = UIKit.Colors.Slot,
	CardOn = UIKit.Colors.PanelLight,
	Yellow = UIKit.Colors.Yellow,
	Green = Color3.fromRGB(70, 200, 90),
	Red = Color3.fromRGB(235, 60, 50),
	Grey = Color3.fromRGB(110, 115, 130),
	Avatar = Color3.fromRGB(70, 200, 160),
	Gold = Color3.fromRGB(255, 185, 30),
	Skin = Color3.fromRGB(255, 204, 153),
	CashBg = Color3.fromRGB(40, 140, 60),
}
local LIMB_SET = { Head = true, Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }

------------------------------------------------------------------------
-- Modules chargés à la demande (les fichiers skins peuvent arriver plus tard)
------------------------------------------------------------------------
local loaded = {}
local function lazy(folder, name)
	local v = loaded[name]
	if v ~= nil then
		return v or nil
	end
	local f = Shared:FindFirstChild(folder)
	local m = f and f:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, res = pcall(require, m)
	if not ok then
		warn("[CharacterSelect] " .. name .. " : " .. tostring(res))
	end
	loaded[name] = ok and res or false
	return loaded[name] or nil
end
local function SkinsCfg()
	return lazy("Config", "Skins")
end
local function Builder()
	return lazy("Modules", "SkinBuilder")
end
local function AttacksCfg()
	return lazy("Config", "Attacks")
end
local function SoundsCfg()
	return lazy("Config", "Sounds")
end

local RARITY_FALLBACK = {
	Order = { "Base", "Rare", "Epic", "Legendary" },
	Base = { Color = Color3.fromRGB(170, 170, 170), Weight = 0, Label = "BASE" },
	Rare = { Color = Color3.fromRGB(60, 140, 255), Weight = 70, Label = "RARE" },
	Epic = { Color = Color3.fromRGB(170, 70, 255), Weight = 25, Label = "EPIC" },
	Legendary = { Color = Color3.fromRGB(255, 190, 30), Weight = 5, Label = "LEGENDARY" },
}
local function rarity(r)
	local S = SkinsCfg()
	local R = S and S.Rarities or RARITY_FALLBACK
	return R[r or ""] or RARITY_FALLBACK[r or ""] or RARITY_FALLBACK.Base
end
local curCrate, ctxRef = "Briefcase", nil
local crateCards = {} -- [crateId] = carte de la boutique
local CRATE_FALLBACK = { Id = "Briefcase", Name = "Mystery Briefcase", Price = 300, Shape = "Briefcase", Color = Color3.fromRGB(70, 130, 255), Accent = Color3.fromRGB(255, 205, 60), Desc = "The classic. Any skin from any coworker.", Odds = { Rare = 70, Epic = 25, Legendary = 5 }, Refund = { Rare = 60, Epic = 150, Legendary = 400 } }
local function defaultCrate()
	local S = SkinsCfg()
	return S and S.DEFAULT_CRATE or "Briefcase"
end
local function crateList()
	local S = SkinsCfg()
	return S and type(S.Crates) == "table" and #S.Crates > 0 and S.Crates or { CRATE_FALLBACK }
end
local function crateDef(id)
	local S = SkinsCfg()
	local by = S and S.CrateById
	return by and (by[id or ""] or by[defaultCrate()]) or CRATE_FALLBACK
end
-- caisse « de service » d'un perso (pool limité qui le contient), sinon nil
local function crateFor(charId)
	for _, c in ipairs(crateList()) do
		if type(c.Pool) == "table" and table.find(c.Pool, charId) then
			return c
		end
	end
	return nil
end
local function crateHint(charId)
	local c = crateFor(charId)
	return c and ("Find it in the " .. c.Name) or "Find it in a crate"
end
local function crate()
	local S = SkinsCfg()
	return crateDef(curCrate)
end

-- les 4 skins d'un perso (Base, Rare, Epic, Legendary) ; secours = Base seul
local function skinsOf(charId)
	local S = SkinsCfg()
	local list = S and S.ByCharacter and S.ByCharacter[charId]
	if type(list) == "table" and #list > 0 then
		return list
	end
	local kit = Characters[charId]
	return { { Id = charId .. "_Base", Character = charId, Name = "Uniform", Rarity = "Base", Outfit = { Shirt = kit and kit.Shirt, Pants = kit and kit.Pants } } }
end
local function skinDef(id)
	if not id or id == AVATAR then
		return nil
	end
	local S = SkinsCfg()
	if S and S.List and S.List[id] then
		return S.List[id]
	end
	local c = string.match(id, "^(.+)_Base$")
	if c and Characters[c] then
		return skinsOf(c)[1]
	end
	return nil
end
local function baseId(charId)
	local l = skinsOf(charId)
	return l[1] and l[1].Id or (charId .. "_Base")
end
local function shortName(charId)
	local kit = Characters[charId]
	local n = kit and kit.DisplayName or tostring(charId)
	return (string.gsub(n, "^The ", ""))
end

------------------------------------------------------------------------
-- État du joueur (SkinRequest "State" + SkinState + attributs Cash / Crates)
------------------------------------------------------------------------
local state = { Cash = 0, Crates = 0, Owned = {}, Equipped = {} }
local function cash()
	return tonumber(player:GetAttribute("Cash")) or state.Cash or 0
end
local function crates()
	return tonumber(player:GetAttribute("Crates")) or state.Crates or 0
end
local function owns(id)
	if id == AVATAR then
		return true
	end
	local d = skinDef(id)
	if d and d.Rarity == "Base" then
		return true
	end
	return state.Owned[id] == true
end
local function equippedOf(charId)
	local e = state.Equipped[charId]
	if e == nil or e == "" then
		return AVATAR
	end
	return e
end
local function ownedCount()
	local S = SkinsCfg()
	local total, have = 0, 0
	if S and S.List then
		for id in pairs(S.List) do
			total += 1
			if owns(id) then
				have += 1
			end
		end
	end
	return have, total
end
local function money(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return (n < 0 and "-$" or "$") .. s .. out
end

local function remote(name)
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	return f and f:FindFirstChild(name)
end
local function request(...)
	local rf = remote("SkinRequest")
	if not rf or not rf:IsA("RemoteFunction") then
		return nil
	end
	local args = table.pack(...)
	local ok, a, b = pcall(function()
		return rf:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[CharacterSelect] SkinRequest " .. tostring(args[1]) .. " : " .. tostring(a))
		return nil
	end
	return a, b
end

------------------------------------------------------------------------
-- Déblocage des persos (Config/Unlocks + UnlockRequest / UnlockState)
------------------------------------------------------------------------
local unlock = { Owned = {} }
local function UnlocksCfg()
	return lazy("Config", "Unlocks")
end
local function unlockOf(id)
	local U = UnlocksCfg()
	return U and U.get(id) or { Tier = "Free" }
end
local function ownsChar(id)
	if unlockOf(id).Tier == "Free" then
		return true
	end
	return unlock.Owned[id] == true
end
local function priceText(id)
	local U = UnlocksCfg()
	return U and U.priceText(id) or "FREE"
end
-- perso jouable : pref s'il est possédé, sinon le perso par défaut (Intern), sinon le premier possédé
local function firstOwned(pref)
	if pref and Characters[pref] and ownsChar(pref) then
		return pref
	end
	local U = UnlocksCfg()
	if U and Characters[U.DEFAULT] and ownsChar(U.DEFAULT) then
		return U.DEFAULT
	end
	for _, id in ipairs(Characters.Order) do
		if Characters[id] and ownsChar(id) then
			return id
		end
	end
	return Characters.Order[1]
end
local function unlockRequest(...)
	local rf = remote("UnlockRequest")
	if not rf or not rf:IsA("RemoteFunction") then
		return nil
	end
	local args = table.pack(...)
	local ok, a, b, c = pcall(function()
		return rf:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[CharacterSelect] UnlockRequest " .. tostring(args[1]) .. " : " .. tostring(a))
		return nil
	end
	return a, b, c
end

------------------------------------------------------------------------
-- Sons (Config/Sounds)
------------------------------------------------------------------------
local sounds, soundParent = {}, nil
local function sfx(key, speed, volume)
	local S = SoundsCfg()
	local list = S and S[key]
	if type(list) ~= "table" or #list == 0 or not soundParent then
		return
	end
	local s = sounds[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = key
		s.SoundId = list[1]
		s.Parent = soundParent
		sounds[key] = s
	end
	s.PlaybackSpeed = speed or 1
	s.Volume = volume or 0.5
	SoundService:PlayLocalSound(s)
end

------------------------------------------------------------------------
-- Mannequins 3D (SkinBuilder) dans des ViewportFrames réutilisés
------------------------------------------------------------------------
local LIMBS = {
	Head = { Vector3.new(2, 1, 1), CFrame.new(0, 1.5, 0) },
	Torso = { Vector3.new(2, 2, 1), CFrame.new() },
	["Left Arm"] = { Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0) },
	["Right Arm"] = { Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0) },
	["Left Leg"] = { Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0) },
	["Right Leg"] = { Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0) },
}
local function fallbackMannequin()
	local m = Instance.new("Model")
	m.Name = "Mannequin"
	for name, d in pairs(LIMBS) do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = d[1]
		p.CFrame = d[2]
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = COL.Skin
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = p
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png"
			face.Parent = p
		end
	end
	return m
end

-- en ViewportFrame les soudures ne sont pas résolues : on place chaque pièce une fois, puis tout est ancré
local function fixJoints(m)
	local function isLimb(p)
		return LIMB_SET[p.Name] and p.Parent == m
	end
	for _ = 1, 2 do
		for _, j in ipairs(m:GetDescendants()) do
			if j:IsA("JointInstance") and j.Part0 and j.Part1 then
				if isLimb(j.Part1) and not isLimb(j.Part0) then
					j.Part0.CFrame = j.Part1.CFrame * j.C1 * j.C0:Inverse()
				elseif not isLimb(j.Part1) then
					j.Part1.CFrame = j.Part0.CFrame * j.C0 * j.C1:Inverse()
				end
			end
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function buildModel(skinId)
	local m
	local B = Builder()
	if B and B.mannequin then
		local ok, res = pcall(B.mannequin)
		if ok and typeof(res) == "Instance" then
			m = res
		end
	end
	m = m or fallbackMannequin()
	local done = false
	if B and B.dress then
		local ok, err = pcall(B.dress, m, skinId, { preview = true })
		done = ok
		if not ok then
			warn("[CharacterSelect] SkinBuilder.dress " .. tostring(skinId) .. " : " .. tostring(err))
		end
	end
	local def = skinDef(skinId)
	if done and def and not def.HideIdentity and def.Character and B.identity then
		local ok, err = pcall(B.identity, m, def.Character)
		if not ok then
			warn("[CharacterSelect] SkinBuilder.identity : " .. tostring(err))
		end
	end
	if not done then
		local d = def
		local o = d and d.Outfit or {}
		for name in pairs(LIMB_SET) do
			local p = m:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				if name == "Torso" or (string.find(name, "Arm") and not o.ArmsSkin) then
					p.Color = o.Shirt or p.Color
				elseif string.find(name, "Leg") then
					p.Color = o.Pants or p.Color
				elseif name == "Head" and o.Skin then
					p.Color = o.Skin
				end
			end
		end
	end
	fixJoints(m)
	local torso = m:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		m.PrimaryPart = torso
	end
	return m
end

local function newView(parent, full, z)
	local vf = UIKit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(165, 165, 175),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.4, -0.6, 1),
		ZIndex = z or 2,
		Parent = parent,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	return { vf = vf, cam = cam, full = full, yaw = full and 0 or 22, dist = 16.5 }
end
local function frameView(v)
	if not v.model then
		return
	end
	v.model:PivotTo(CFrame.Angles(0, math.rad(v.yaw), 0))
	if v.full then
		v.cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.9, -v.dist), Vector3.new(0, -0.2, 0))
	else
		v.cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.9, -7.4), Vector3.new(0, 1.2, 0))
	end
end
local function showView(v, skinId)
	if v.skinId == skinId and v.model and v.model.Parent then
		return
	end
	if v.model then
		v.model:Destroy()
	end
	v.skinId = skinId
	v.model = buildModel(skinId)
	frameView(v)
	v.model.Parent = v.vf
end

local thumbs, thumbWait = {}, {}
local function thumb(kind, cb)
	if thumbs[kind] then
		cb(thumbs[kind])
		return
	end
	if thumbWait[kind] then
		table.insert(thumbWait[kind], cb)
		return
	end
	thumbWait[kind] = { cb }
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				math.max(player.UserId, 1),
				kind == "Head" and Enum.ThumbnailType.HeadShot or Enum.ThumbnailType.AvatarThumbnail,
				Enum.ThumbnailSize.Size420x420
			)
		end)
		thumbs[kind] = ok and url or ""
		for _, f in ipairs(thumbWait[kind]) do
			task.spawn(f, thumbs[kind])
		end
		thumbWait[kind] = nil
	end)
end

------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------
local gui, dim, root
local ui = {}
local cards = {} -- [charId] = carte de la grille
local skinCards = {}
local previewView, revealView
local selChar, selSkin
local token, autoToken = 0, 0
local built, compact, spinning = false, false, false
local dragging, dragX, lastDrag = false, 0, 0
local shineT, revealRarity, lastWin = 0, nil, nil
local refreshAll, refreshCase, openCrate, equip, selectChar, selectSkin, showcase
local buyChar -- achat d'un perso verrouillé (défini avant l'API)

local function toast(t, c, d)
	if hud and hud.toast then
		hud.toast(t, c, d)
	end
end

local function interacted()
	if autoToken ~= 0 then
		autoToken = 0
		if ui.timer then
			ui.timer.Text = ""
		end
	end
end

local function viewportSize()
	if Select._fakeViewport then
		return Select._fakeViewport
	end
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end
local function applyScale()
	local vp = viewportSize()
	local s = math.clamp(math.min(vp.X * 0.97 / W, vp.Y * 0.95 / H), 0.3, 1.45)
	compact = s < 0.8
	for _, o in ipairs({ root, ui.caseWin }) do
		local sc = o and o:FindFirstChild("AutoScale")
		if sc then
			sc:SetAttribute("Base", s)
			sc.Scale = s
		end
	end
end

local function pill(parent, color, pos, size, text)
	local f = UIKit.new("Frame", { BackgroundColor3 = color, Position = pos, Size = size, Parent = parent })
	UIKit.corner(f, UDim.new(0, 6))
	UIKit.stroke(f, 3, UIKit.Black, true)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185)), Rotation = 90, Parent = f })
	local l = UIKit.label({ Name = "Label", Text = text or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -18, 0.66, 0), Stroke = 2.5, ZIndex = 2 })
	l.Parent = f
	return f, l
end

local function lockIcon(parent, y, z)
	local holder = UIKit.new("Frame", { Name = "LockIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.fromOffset(30, 34), BackgroundTransparency = 1, ZIndex = z, Parent = parent })
	local shackle = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(20, 26), BackgroundTransparency = 1, ZIndex = z, Parent = holder })
	UIKit.corner(shackle, UDim.new(0.5, 0))
	UIKit.stroke(shackle, 4, Color3.fromRGB(215, 215, 225), true)
	local body = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(30, 21), BackgroundColor3 = Color3.fromRGB(255, 200, 50), ZIndex = z + 1, Parent = holder })
	UIKit.corner(body, UDim.new(0, 5))
	UIKit.stroke(body, 2.5, UIKit.Black, true)
	local hole = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(6, 9), BackgroundColor3 = UIKit.Black, ZIndex = z + 2, Parent = body })
	UIKit.corner(hole, UDim.new(0.5, 0))
	return holder
end

local function notify(text, color)
	if root and root.Visible and ui.notice then
		ui.noticeL.Text = text
		ui.noticeL.TextColor3 = color or UIKit.White
		ui.notice.Visible = true
		UIKit.pop(ui.notice, 1.15)
		local my = os.clock()
		ui.notice:SetAttribute("T", my)
		task.delay(2.4, function()
			if ui.notice:GetAttribute("T") == my then
				ui.notice.Visible = false
			end
		end)
	else
		toast(text, color)
	end
end

---------------------------------------------------------------- grille
local function buildCard(charId, order)
	local kit = Characters[charId]
	local b = UIKit.new("TextButton", { Name = charId, Text = "", AutoButtonColor = false, BackgroundColor3 = COL.Card, LayoutOrder = order, Parent = ui.grid })
	UIKit.corner(b, UDim.new(0, 6))
	local st = UIKit.stroke(b, 3, UIKit.Black, true)
	local band = UIKit.new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 80), BackgroundColor3 = kit.Color, ClipsDescendants = true, Parent = b })
	UIKit.corner(band, UDim.new(0, 6))
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)), Rotation = 90, Parent = band })
	local view = newView(band, false, 2)
	local nm = UIKit.label({ Text = string.upper(shortName(charId)), Position = UDim2.fromOffset(5, 86), Size = UDim2.new(1, -10, 0, 22), Stroke = 2 })
	nm.Parent = b
	local role = UIKit.label({ Text = kit.Role or "", Font = BODY, Position = UDim2.fromOffset(5, 108), Size = UDim2.new(1, -10, 0, 15), TextColor3 = Color3.fromRGB(200, 205, 220), Stroke = 1.5 })
	role.Parent = b
	local tag = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(66, 16), BackgroundColor3 = COL.Avatar, ZIndex = 3, Parent = band })
	UIKit.corner(tag, UDim.new(0, 6))
	UIKit.stroke(tag, 2, UIKit.Black, true)
	local tagL = UIKit.label({ Text = "AVATAR", Size = UDim2.new(1, -8, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 1.5, ZIndex = 4 })
	tagL.Parent = tag
	local playing = UIKit.new("Frame", { Position = UDim2.fromOffset(4, 60), Size = UDim2.fromOffset(64, 16), BackgroundColor3 = COL.Green, ZIndex = 3, Visible = false, Parent = band })
	UIKit.corner(playing, UDim.new(0, 6))
	UIKit.stroke(playing, 2, UIKit.Black, true)
	local pl = UIKit.label({ Text = "PLAYING", Size = UDim2.new(1, -8, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 1.5, ZIndex = 4 })
	pl.Parent = playing
	-- verrou : voile sombre + cadenas sur le portrait, pastille de prix / FREE / OWNED en haut à gauche
	local lock = UIKit.new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.45, Visible = false, ZIndex = 5, Parent = band })
	UIKit.corner(lock, UDim.new(0, 6))
	lockIcon(lock, 44, 6)
	local chip = UIKit.new("Frame", { Name = "Price", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(58, 16), BackgroundColor3 = COL.Grey, ZIndex = 8, Parent = band })
	UIKit.corner(chip, UDim.new(0, 6))
	UIKit.stroke(chip, 2, UIKit.Black, true)
	local chipL = UIKit.label({ Text = "FREE", Size = UDim2.new(1, -6, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 1.5, ZIndex = 9 })
	chipL.Parent = chip
	local sc = UIKit.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		UIKit.tween(sc, 0.1, { Scale = 1.04 })
	end)
	b.MouseLeave:Connect(function()
		UIKit.tween(sc, 0.1, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		interacted()
		sfx("UIClick", 1.1, 0.4)
		selectChar(charId)
	end)
	cards[charId] = { btn = b, stroke = st, view = view, tag = tag, tagL = tagL, playing = playing, order = order, lock = lock, chip = chip, chipL = chipL, name = nm }
end

-- état de déblocage des cartes
local function paintLocks()
	for id, c in pairs(cards) do
		local e = unlockOf(id)
		local own = ownsChar(id)
		c.lock.Visible = not own
		c.name.TextColor3 = own and UIKit.White or Color3.fromRGB(170, 170, 185)
		if e.Tier == "Free" then
			c.chipL.Text = "FREE"
			c.chip.BackgroundColor3 = Color3.fromRGB(90, 130, 200)
		elseif own then
			c.chipL.Text = "OWNED"
			c.chip.BackgroundColor3 = COL.Green
		elseif e.Tier == "Robux" then
			c.chipL.Text = priceText(id)
			c.chip.BackgroundColor3 = Color3.fromRGB(0, 176, 111)
		else
			c.chipL.Text = priceText(id)
			c.chip.BackgroundColor3 = COL.CashBg
		end
	end
end

local function paintCards()
	local cur = player.Character and player.Character:GetAttribute("CharacterName")
	for id, c in pairs(cards) do
		local on = id == selChar
		c.stroke.Color = on and COL.Yellow or UIKit.Black
		c.stroke.Thickness = on and 4 or 3
		c.btn.BackgroundColor3 = on and COL.CardOn or COL.Card
		c.playing.Visible = cur == id
	end
	paintLocks()
end

local function refreshGrid()
	for id, c in pairs(cards) do
		local eq = equippedOf(id)
		local d = skinDef(eq)
		showView(c.view, d and eq or baseId(id))
		if eq == AVATAR or not d then
			c.tag.BackgroundColor3 = COL.Avatar
			c.tagL.Text = "AVATAR"
		else
			local r = rarity(d.Rarity)
			c.tag.BackgroundColor3 = r.Color
			c.tagL.Text = r.Label
		end
	end
	paintCards()
end

local function scrollToSelected()
	local c = selChar and cards[selChar]
	if not c then
		return
	end
	local k = 0
	for _, id in ipairs(Characters.Order) do
		if cards[id] then
			k += 1
			if id == selChar then
				break
			end
		end
	end
	local y = 6 + math.floor((k - 1) / 2) * 136
	ui.grid.CanvasPosition = Vector2.new(0, math.max(0, y - 180))
end

---------------------------------------------------------------- infos
local function fillInfo(charId)
	for _, c in ipairs(ui.info:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local kit = Characters[charId]
	if not kit then
		return
	end
	local k = compact and 1.25 or 1
	local order = 0
	local A = AttacksCfg()
	local function add(o, parent)
		order += 1
		o.LayoutOrder = order
		o.Parent = parent or ui.info
		return o
	end
	local function line(txt, font, size, color, stroke, parent)
		return add(UIKit.label({
			Text = txt or "",
			Font = font,
			TextScaled = false,
			TextSize = math.floor(size * k),
			TextWrapped = true,
			TextColor3 = color or UIKit.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Stroke = stroke or 1.5,
		}), parent)
	end
	local function gap(h)
		add(UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h) }))
	end
	-- ligne d'attaque : icône illustrée (Theme.attackIcon) + pastille de touche, nom, description
	local function attackRow(i, id, color, nm, desc)
		local a = A and type(A[id]) == "table" and A[id] or nil
		local row = add(UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }))
		local isz = math.floor(50 * k)
		local box = UIKit.new("Frame", { Name = "IconBox", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(isz, isz), BackgroundTransparency = 1, Parent = row })
		local okIcon, icon = false, nil
		if Theme and type(Theme.attackIcon) == "function" then
			okIcon, icon = pcall(Theme.attackIcon, id, box, nil, { Color = kit.Color })
		end
		if not (okIcon and icon) then
			box:ClearAllChildren()
			box.BackgroundTransparency = 0
			box.BackgroundColor3 = color
			UIKit.corner(box, UDim.new(0, 6))
			UIKit.stroke(box, 2, UIKit.Black, true)
		end
		local key = UIKit.new("Frame", { Name = "Key", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(math.floor(20 * k), math.floor(18 * k)), BackgroundColor3 = color, ZIndex = 6, Parent = box })
		UIKit.corner(key, UDim.new(0, 4))
		UIKit.stroke(key, 2, UIKit.Black, true)
		local bl = UIKit.label({ Text = tostring(i), Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Stroke = 1.5, ZIndex = 7 })
		bl.Parent = key
		local off = isz + math.floor(14 * k)
		local col = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(off, 0), Size = UDim2.new(1, -off, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row })
		UIKit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = col })
		line(string.upper(nm or (a and a.Name) or (hud and hud.attackName and hud.attackName(id)) or UIKit.pretty(id)), FONT, 15, UIKit.White, 2, col)
		local d = desc or (a and a.Desc)
		if d then
			line(d, BODY, 13, Color3.fromRGB(200, 205, 220), 1.5, col)
		end
	end
	line(string.upper(kit.DisplayName), FONT, 28, kit.Color, 3)
	line(kit.Role or "", BODY, 15, Color3.fromRGB(205, 210, 225))
	gap(4)
	if kit.Passive then
		line("PASSIVE: " .. tostring(kit.Passive.Name), FONT, 16, COL.Yellow, 2)
		line(kit.Passive.Desc, BODY, 13, Color3.fromRGB(225, 225, 235))
		gap(4)
	end
	line("ATTACKS", FONT, 16, Color3.fromRGB(150, 210, 255), 2)
	for i, id in ipairs(kit.Attacks or {}) do
		attackRow(i, id, kit.Color)
	end
	gap(4)
	if kit.Transformation then
		line("OVERTIME: " .. tostring(kit.Transformation.Name), FONT, 16, Color3.fromRGB(255, 150, 60), 2)
		if kit.Transformation.Desc then
			line(kit.Transformation.Desc, BODY, 13, Color3.fromRGB(225, 225, 235))
		end
	end
	for i, id in ipairs(kit.TransAttacks or {}) do
		attackRow(i, id, Color3.fromRGB(255, 120, 40))
	end
	-- ultime (G pendant l'Overtime) avec son icône
	local ultName, ultDesc = nil, nil
	if Theme and type(Theme.ultInfo) == "function" then
		local okU, n, d = pcall(Theme.ultInfo, charId)
		if okU then
			ultName, ultDesc = n, d
		end
	end
	if ultName then
		gap(4)
		line("ULTIMATE (G IN OVERTIME)", FONT, 16, COL.Gold, 2)
		attackRow("G", "Ult:" .. charId, COL.Gold, ultName, ultDesc)
	end
	ui.info.CanvasPosition = Vector2.zero
end

---------------------------------------------------------------- aperçu
local function refreshPreview()
	local kit = Characters[selChar]
	if not kit then
		return
	end
	ui.previewGrad.Color = ColorSequence.new(kit.Color:Lerp(Color3.new(0, 0, 0), 0.2), COL.Dark)
	if selSkin == AVATAR then
		previewView.vf.Visible = false
		ui.previewImg.Visible = true
		thumb("Body", function(url)
			ui.previewImg.Image = url
		end)
		ui.previewName.Text = "MY AVATAR"
		ui.previewTag.BackgroundColor3 = COL.Avatar
		ui.previewTagL.Text = "YOUR ROBLOX LOOK"
	else
		previewView.vf.Visible = true
		ui.previewImg.Visible = false
		showView(previewView, selSkin)
		local d = skinDef(selSkin)
		local r = rarity(d and d.Rarity)
		ui.previewName.Text = string.upper(d and d.Name or tostring(selSkin))
		ui.previewTag.BackgroundColor3 = r.Color
		ui.previewTagL.Text = r.Label
	end
	ui.previewLock.Visible = not owns(selSkin)
	if ui.previewLockL and selSkin ~= AVATAR then
		local dd = skinDef(selSkin)
		ui.previewLockL.Text = "LOCKED\n" .. crateHint(dd and dd.Character or selChar)
	end
	ui.previewHint.Visible = selSkin ~= AVATAR and owns(selSkin)
	local d = skinDef(selSkin)
	local rk = d and d.Rarity
	ui.previewGlow.Visible = rk == "Rare" or rk == "Epic" or rk == "Legendary"
	if ui.previewGlow.Visible then
		ui.previewGlow.BackgroundColor3 = rarity(rk).Color
	end
end

---------------------------------------------------------------- skins
local function buildSkinCard(i)
	local b = UIKit.new("TextButton", { Name = "Skin" .. i, Text = "", AutoButtonColor = false, BackgroundColor3 = COL.Card, Size = UDim2.fromOffset(126, 130), LayoutOrder = i, Parent = ui.skins })
	UIKit.corner(b, UDim.new(0, 6))
	local st = UIKit.stroke(b, 3, COL.Grey, true)
	local shine = UIKit.new("UIGradient", {
		Enabled = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 20)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 20)),
		}),
		Parent = st,
	})
	local top = UIKit.new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 20), BackgroundColor3 = COL.Grey, Parent = b })
	UIKit.corner(top, UDim.new(0, 6))
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Rotation = 90, Parent = top })
	local topL = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0.8, 0), Stroke = 2, ZIndex = 2 })
	topL.Parent = top
	local port = UIKit.new("Frame", { Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 76), BackgroundColor3 = COL.Dark, ClipsDescendants = true, Parent = b })
	UIKit.corner(port, UDim.new(0, 6))
	local glow = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.Grey, BorderSizePixel = 0, ZIndex = 1, Parent = port })
	UIKit.corner(glow, UDim.new(0, 6))
	UIKit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.3), Parent = glow })
	local view = newView(port, false, 2)
	local img = UIKit.new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 2, Parent = port })
	local lock = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.3, Visible = false, ZIndex = 4, Parent = port })
	lockIcon(lock, 22, 5)
	local lt = UIKit.label({ Text = "Find it in a crate", Font = BODY, Position = UDim2.new(0, 3, 1, -32), Size = UDim2.new(1, -6, 0, 30), TextWrapped = true, Stroke = 1.5, TextColor3 = Color3.fromRGB(255, 225, 120), ZIndex = 6 })
	lt.Parent = lock
	local eq = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.fromOffset(86, 18), BackgroundColor3 = COL.Green, Visible = false, ZIndex = 6, Parent = port })
	UIKit.corner(eq, UDim.new(0, 6))
	UIKit.stroke(eq, 2, UIKit.Black, true)
	local eqL = UIKit.label({ Text = "EQUIPPED", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0.8, 0), Stroke = 1.5, ZIndex = 7 })
	eqL.Parent = eq
	local name = UIKit.label({ Text = "", Font = BODY, Position = UDim2.fromOffset(4, 106), Size = UDim2.new(1, -8, 0, 20), Stroke = 1.5 })
	name.Parent = b
	local sc = UIKit.new("UIScale", { Parent = b })
	local card = { btn = b, stroke = st, shine = shine, top = top, topL = topL, glow = glow, view = view, img = img, lock = lock, eq = eq, name = name, scale = sc, lt = lt }
	b.Activated:Connect(function()
		interacted()
		if card.id then
			sfx("UIClick", 1.25, 0.4)
			selectSkin(card.id)
		end
	end)
	skinCards[i] = card
end

local function refreshSkins()
	if not selChar then
		return
	end
	local list = skinsOf(selChar)
	local entries = { AVATAR }
	for i = 1, 4 do
		entries[i + 1] = list[i] and list[i].Id or nil
	end
	local eq = equippedOf(selChar)
	for i, sc in ipairs(skinCards) do
		local id = entries[i]
		sc.id = id
		sc.btn.Visible = id ~= nil
		if id then
			local color, label, nameText, rk
			if id == AVATAR then
				color, label, nameText, rk = COL.Avatar, "MY AVATAR", player.DisplayName, "Avatar"
				sc.view.vf.Visible = false
				sc.img.Visible = true
				thumb("Head", function(url)
					sc.img.Image = url
				end)
			else
				local d = skinDef(id)
				rk = d and d.Rarity or "Base"
				local r = rarity(rk)
				color, label, nameText = r.Color, r.Label, d and d.Name or id
				sc.view.vf.Visible = true
				sc.img.Visible = false
				showView(sc.view, id)
			end
			sc.top.BackgroundColor3 = color
			sc.topL.Text = label
			sc.glow.BackgroundColor3 = color
			sc.name.Text = nameText
			local owned = owns(id)
			sc.lock.Visible = not owned
			if not owned and id ~= AVATAR then
				local dd = skinDef(id)
				sc.lt.Text = crateHint(dd and dd.Character or selChar)
			end
			sc.name.TextColor3 = owned and UIKit.White or Color3.fromRGB(150, 150, 165)
			sc.eq.Visible = eq == id
			local sel = selSkin == id
			sc.stroke.Color = sel and UIKit.White or color
			sc.stroke.Thickness = sel and 4.5 or 3
			sc.shine.Enabled = rk == "Legendary"
			sc.scale.Scale = sel and 1.04 or 1
		end
	end
end

local function refreshButtons()
	if not selChar then
		return
	end
	local eq = equippedOf(selChar)
	if selSkin == eq then
		ui.equip.Label.Text = "EQUIPPED"
		ui.equip.BackgroundColor3 = COL.Grey
	elseif not owns(selSkin) then
		ui.equip.Label.Text = "GET IT!"
		ui.equip.BackgroundColor3 = COL.Gold
	else
		ui.equip.Label.Text = "EQUIP"
		ui.equip.BackgroundColor3 = COL.Green
	end
	if ui.showcase then
		local sd = skinDef(selSkin)
		local can = sd ~= nil and sd.Rarity ~= "Base" and owns(selSkin)
		ui.showcase.Visible = can
		ui.status.Size = UDim2.fromOffset(can and 150 or 276, 50)
	end
	local ed = skinDef(eq)
	local nm = eq == AVATAR and "My Avatar" or (ed and ed.Name or tostring(eq))
	local c = eq == AVATAR and COL.Avatar or rarity(ed and ed.Rarity).Color
	ui.status.Text = 'EQUIPPED ON ' .. UIKit.escape(string.upper(shortName(selChar))) .. ':\n<font color="' .. UIKit.hex(c) .. '">' .. UIKit.escape(nm) .. "</font>"
	-- PLAY si possédé, sinon BUY / COMING SOON
	local ue = unlockOf(selChar)
	local owned = ownsChar(selChar)
	if owned then
		ui.play.Label.Text = "PLAY AS " .. string.upper(shortName(selChar))
		ui.play.BackgroundColor3 = Color3.fromRGB(255, 150, 30)
	elseif ue.Tier == "Robux" and (not ue.GamePassId or ue.GamePassId == 0) then
		ui.play.Label.Text = "COMING SOON"
		ui.play.BackgroundColor3 = COL.Grey
	elseif ue.Tier == "Robux" then
		ui.play.Label.Text = "BUY  " .. priceText(selChar)
		ui.play.BackgroundColor3 = Color3.fromRGB(0, 176, 111)
	else
		ui.play.Label.Text = "BUY  " .. priceText(selChar)
		ui.play.BackgroundColor3 = cash() >= (ue.Price or 0) and COL.Green or Color3.fromRGB(60, 120, 70)
	end
	if ui.charLock then
		ui.charLock.Visible = not owned
		if not owned then
			ui.charLockL.Text = ue.Tier == "Robux" and ((ue.GamePassId or 0) == 0 and "LOCKED  -  ROBUX (SOON)" or ("LOCKED  -  " .. priceText(selChar)))
				or ("LOCKED  -  " .. priceText(selChar))
		end
	end
end

local function refreshHeader()
	if not built then
		return
	end
	ui.cashL.Text = money(cash())
	local have, total = ownedCount()
	ui.countL.Text = total > 0 and ("SKINS " .. have .. "/" .. total) or "SKINS"
	local n = crates()
	ui.freeBadge.Visible = n > 0
	ui.freeBadgeL.Text = "FREE x" .. n
end

selectChar = function(charId)
	if not Characters[charId] then
		return
	end
	selChar = charId
	selSkin = equippedOf(charId)
	if selSkin ~= AVATAR and not skinDef(selSkin) then
		selSkin = AVATAR
	end
	previewView.yaw = 0
	paintCards()
	fillInfo(charId)
	refreshSkins()
	refreshPreview()
	refreshButtons()
end

selectSkin = function(id)
	selSkin = id
	refreshSkins()
	refreshPreview()
	refreshButtons()
end

local function applyState(s)
	if type(s) ~= "table" then
		return
	end
	if tonumber(s.Cash) then
		state.Cash = tonumber(s.Cash)
	end
	if tonumber(s.Crates) then
		state.Crates = tonumber(s.Crates)
	end
	if type(s.Owned) == "table" then
		state.Owned = s.Owned
	end
	if type(s.Equipped) == "table" then
		state.Equipped = s.Equipped
	end
	if refreshAll then
		refreshAll()
	end
end

equip = function(charId, skinId, quiet)
	if not remote("SkinRequest") then
		notify("Skins are still loading, try again!", COL.Red)
		return false
	end
	local ok, st = request("Equip", charId, skinId)
	if type(st) == "table" then
		applyState(st)
	end
	if ok == true then
		state.Equipped[charId] = skinId
		if not quiet then
			local d = skinDef(skinId)
			notify((skinId == AVATAR and "My Avatar" or (d and d.Name or tostring(skinId))) .. " equipped on " .. shortName(charId) .. "!", Color3.fromRGB(140, 255, 150))
			sfx("Ding", 1.2, 0.45)
		end
	else
		notify("You don't own that skin yet!", COL.Red)
	end
	refreshAll()
	return ok == true
end

refreshAll = function()
	if not built then
		return
	end
	refreshHeader()
	if root.Visible and selChar then
		refreshGrid()
		refreshSkins()
		refreshPreview()
		refreshButtons()
	end
	refreshCase()
end

---------------------------------------------------------------- fenêtre principale
local function buildMain()
	dim = UIKit.new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.4, Active = true, Visible = false, ZIndex = 1, Parent = gui })
	root = UIKit.panel({ Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 0.04, Visible = false, ZIndex = 2, Parent = gui })
	root:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
	root:FindFirstChildOfClass("UIStroke").Thickness = 4
	UIKit.new("UIScale", { Name = "AutoScale", Parent = root })

	-- en-tête
	ui.title = UIKit.label({ Text = "CHOOSE YOUR JOB", Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(400, 36), TextColor3 = COL.Yellow, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4 })
	ui.title.Parent = root
	ui.timer = UIKit.label({ Text = "", Font = BODY, Position = UDim2.fromOffset(18, 43), Size = UDim2.fromOffset(400, 16), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5 })
	ui.timer.Parent = root
	local _, countL = pill(root, Color3.fromRGB(80, 90, 140), UDim2.fromOffset(426, 13), UDim2.fromOffset(146, 36), "SKINS")
	ui.countL = countL
	local _, cashL = pill(root, COL.CashBg, UDim2.fromOffset(580, 13), UDim2.fromOffset(148, 36), "$0")
	ui.cashL = cashL
	ui.caseBtn = UIKit.button({ Name = "BriefcaseButton", Text = "CRATE SHOP", Color = COL.Gold, Position = UDim2.fromOffset(736, 11), Size = UDim2.fromOffset(198, 40), TextSize = UDim2.fromScale(0.9, 0.55), Parent = root })
	ui.caseBtn.Activated:Connect(function()
		interacted()
		Select.openBriefcase()
	end)
	ui.freeBadge = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 8, 0, 0), Size = UDim2.fromOffset(70, 20), BackgroundColor3 = COL.Red, Visible = false, ZIndex = 5, Parent = ui.caseBtn })
	UIKit.corner(ui.freeBadge, UDim.new(0, 6))
	UIKit.stroke(ui.freeBadge, 2, UIKit.Black, true)
	ui.freeBadgeL = UIKit.label({ Text = "FREE", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0.8, 0), Stroke = 1.5, ZIndex = 6 })
	ui.freeBadgeL.Parent = ui.freeBadge
	local close = UIKit.button({ Name = "Close", Text = "X", Color = COL.Red, Position = UDim2.fromOffset(944, 9), Size = UDim2.fromOffset(44, 44), Parent = root })
	close.Activated:Connect(function()
		if player.Character and not player.Character:GetAttribute("CharacterName") then
			Select.choose(firstOwned(selChar))
		else
			Select.close()
		end
	end)

	-- grille des persos
	ui.grid = UIKit.new("ScrollingFrame", {
		Name = "Grid",
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.fromOffset(300, 500),
		BackgroundColor3 = COL.Dark,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COL.Yellow,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = root,
	})
	UIKit.corner(ui.grid, UDim.new(0, 6))
	UIKit.stroke(ui.grid, 3, UIKit.Black, true)
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(137, 128), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.grid })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = ui.grid })
	for i, id in ipairs(Characters.Order) do
		if Characters[id] then
			buildCard(id, i)
		end
	end

	-- aperçu 3D
	local p = UIKit.new("Frame", { Name = "Preview", Position = UDim2.fromOffset(322, 66), Size = UDim2.fromOffset(250, 300), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Active = true, Parent = root })
	UIKit.corner(p, UDim.new(0, 6))
	UIKit.stroke(p, 3, UIKit.Black, true)
	ui.previewGrad = UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(COL.Card, COL.Dark), Parent = p })
	local ped = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.fromOffset(160, 28), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.55, ZIndex = 1, Parent = p })
	UIKit.corner(ped, UDim.new(0.5, 0))
	-- halo de rareté derrière le mannequin (les particules ne s'affichent pas dans un ViewportFrame)
	ui.previewGlow = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(210, 210), BackgroundColor3 = COL.Gold, BackgroundTransparency = 0.7, Visible = false, ZIndex = 1, Parent = p })
	UIKit.corner(ui.previewGlow, UDim.new(0.5, 0))
	UIKit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(1, 0.7) }), Parent = ui.previewGlow })
	previewView = newView(p, true, 2)
	ui.previewImg = UIKit.new("ImageLabel", { Position = UDim2.fromOffset(5, 50), Size = UDim2.new(1, -10, 1, -70), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 2, Parent = p })
	ui.previewName = UIKit.label({ Text = "", Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 24), Stroke = 2.5, ZIndex = 4 })
	ui.previewName.Parent = p
	ui.previewTag = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(130, 18), BackgroundColor3 = COL.Grey, ZIndex = 4, Parent = p })
	UIKit.corner(ui.previewTag, UDim.new(0, 6))
	UIKit.stroke(ui.previewTag, 2, UIKit.Black, true)
	ui.previewTagL = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 0.8, 0), Stroke = 1.5, ZIndex = 5 })
	ui.previewTagL.Parent = ui.previewTag
	ui.previewHint = UIKit.label({ Text = "DRAG TO ROTATE", Font = BODY, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -20, 0, 14), TextTransparency = 0.35, Stroke = 1, ZIndex = 4 })
	ui.previewHint.Parent = p
	ui.previewLock = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 50), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.25, Visible = false, ZIndex = 6, Parent = p })
	UIKit.corner(ui.previewLock, UDim.new(0, 6))
	lockIcon(ui.previewLock, 25, 7).Position = UDim2.new(0, 22, 0.5, 0)
	local plt = UIKit.label({ Text = "LOCKED\nFind it in a crate", Font = BODY, Position = UDim2.fromOffset(44, 4), Size = UDim2.new(1, -50, 1, -8), TextColor3 = Color3.fromRGB(255, 225, 120), Stroke = 1.5, ZIndex = 8 })
	plt.Parent = ui.previewLock
	ui.previewLockL = plt
	-- bandeau « perso verrouillé » en haut de l'aperçu
	ui.charLock = UIKit.new("Frame", { Name = "CharLock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.new(1, -14, 0, 30), BackgroundColor3 = Color3.fromRGB(150, 30, 30), BackgroundTransparency = 0.1, Visible = false, ZIndex = 6, Parent = p })
	UIKit.corner(ui.charLock, UDim.new(0, 6))
	UIKit.stroke(ui.charLock, 2.5, UIKit.Black, true)
	ui.charLockL = UIKit.label({ Text = "LOCKED", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0.62, 0), TextColor3 = Color3.fromRGB(255, 230, 120), Stroke = 2, ZIndex = 7 })
	ui.charLockL.Parent = ui.charLock
	p.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragX = input.Position.X
			lastDrag = os.clock()
			interacted()
		end
	end)

	-- infos (passif, attaques, transformation)
	ui.info = UIKit.new("ScrollingFrame", {
		Name = "Info",
		Position = UDim2.fromOffset(582, 66),
		Size = UDim2.fromOffset(406, 300),
		BackgroundColor3 = COL.Dark,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COL.Yellow,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = root,
	})
	UIKit.corner(ui.info, UDim.new(0, 6))
	UIKit.stroke(ui.info, 3, UIKit.Black, true)
	UIKit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = ui.info })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8), Parent = ui.info })

	-- rangée de skins
	ui.skins = UIKit.new("Frame", { Name = "Skins", Position = UDim2.fromOffset(322, 374), Size = UDim2.fromOffset(666, 130), BackgroundTransparency = 1, Parent = root })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = ui.skins })
	for i = 1, 5 do
		buildSkinCard(i)
	end

	-- boutons
	ui.status = UIKit.label({ Text = "", Font = BODY, RichText = true, Position = UDim2.fromOffset(324, 514), Size = UDim2.fromOffset(276, 50), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5 })
	ui.status.Parent = root
	ui.equip = UIKit.button({ Name = "Equip", Text = "EQUIP", Color = COL.Green, Position = UDim2.fromOffset(606, 512), Size = UDim2.fromOffset(140, 54), Parent = root })
	-- SHOWCASE : rejoue la révélation cinématique d'un skin possédé (hors Base)
	ui.showcase = UIKit.button({ Name = "Showcase", Text = "SHOWCASE", Color = UIKit.Colors.Purple, Position = UDim2.fromOffset(480, 512), Size = UDim2.fromOffset(120, 54), TextSize = UDim2.fromScale(0.86, 0.36), Visible = false, Parent = root })
	ui.showcase.Activated:Connect(function()
		interacted()
		if selSkin and selSkin ~= AVATAR then
			showcase(selSkin)
		end
	end)
	ui.equip.Activated:Connect(function()
		interacted()
		if not selChar or selSkin == equippedOf(selChar) then
			return
		end
		if not owns(selSkin) then
			local hc = skinDef(selSkin)
			local cf = crateFor(hc and hc.Character or selChar)
			Select.openBriefcase(cf and cf.Id or nil)
			return
		end
		equip(selChar, selSkin)
	end)
	ui.play = UIKit.button({ Name = "Play", Text = "PLAY", Color = Color3.fromRGB(255, 150, 30), Position = UDim2.fromOffset(752, 512), Size = UDim2.fromOffset(236, 54), TextSize = UDim2.fromScale(0.9, 0.55), Parent = root })
	ui.play.Activated:Connect(function()
		interacted()
		if not selChar then
			return
		end
		if not ownsChar(selChar) then
			buyChar(selChar)
			return
		end
		-- jouer avec le skin regardé s'il est possédé
		if selSkin ~= equippedOf(selChar) and owns(selSkin) then
			equip(selChar, selSkin, true)
		end
		sfx("UIClick", 0.9, 0.5)
		Select.choose(selChar)
	end)

	-- petite notification interne
	ui.notice = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(655, 72), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(25, 28, 40), Visible = false, ZIndex = 20, Parent = root })
	UIKit.corner(ui.notice, UDim.new(0, 6))
	UIKit.stroke(ui.notice, 3, UIKit.Black, true)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = ui.notice })
	ui.noticeL = UIKit.label({ Text = "", TextScaled = false, TextSize = 20, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Stroke = 2, ZIndex = 21 })
	ui.noticeL.Parent = ui.notice
end

---------------------------------------------------------------- boutique de caisses (CRATE SHOP)
-- 7 caisses (Config/Skins.Crates) : carte avec caisse 3D (ViewportFrame de Parts), prix, chances, pool, OPEN.
-- Ouverture : rouleau aux couleurs de la caisse, puis révélation cinématique (ctx.SkinRevealController),
-- puis panneau EQUIP NOW / OPEN AGAIN / BACK TO CRATES. Secours : ancien panneau de révélation.
local CARD_W, CARD_H, CARD_GAP, CARD_Y = 132, 432, 8, 62
local MSG_Y = 500
local Theme = UIKit.Theme

local function revealCtl()
	local R = ctxRef and ctxRef.SkinRevealController
	if type(R) == "table" and type(R.play) == "function" then
		return R
	end
	return nil
end

local function setCaseView(name)
	ui.idle.Visible = name == "shop" or name == "idle"
	ui.reelView.Visible = name == "reel"
	ui.reveal.Visible = name == "reveal"
	if name ~= "reveal" then
		revealRarity = nil
	end
end

local function caseMessage(text, color, shake)
	ui.caseMsg.Text = text or ""
	ui.caseMsg.TextColor3 = color or COL.Red
	if shake and text then
		task.spawn(function()
			for i = 1, 6 do
				ui.caseMsg.Position = UDim2.fromOffset(500 + (i % 2 == 0 and 8 or -8) * (1 - i / 7), MSG_Y)
				task.wait(0.035)
			end
			ui.caseMsg.Position = UDim2.fromOffset(500, MSG_Y)
		end)
	end
end

local function shakeCard(id)
	local cc = crateCards[id]
	if not cc then
		return
	end
	task.spawn(function()
		for i = 1, 7 do
			cc.face.Position = UDim2.fromOffset((i % 2 == 0 and 7 or -7) * (1 - i / 8), 0)
			task.wait(0.03)
		end
		cc.face.Position = UDim2.fromOffset(0, 0)
	end)
end

local function noCash(id)
	local def = crateDef(id)
	setCaseView("shop")
	local price = def.Price or 300
	caseMessage("NOT ENOUGH CASH! " .. string.upper(def.Name or "Crate") .. " costs " .. money(price) .. " (" .. money(math.max(0, price - cash())) .. " more)", COL.Red, true)
	shakeCard(def.Id)
	local cc = crateCards[def.Id]
	if cc then
		local my = os.clock()
		cc.flashT = my
		cc.btn.Label.Text = "NEED " .. money(price)
		cc.btn.BackgroundColor3 = COL.Red
		task.delay(1.4, function()
			if cc.flashT == my then
				cc.flashT = nil
				refreshCase()
			end
		end)
	end
	sfx("Thud", 1, 0.5)
end

local CONFETTI = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 205, 40), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 230, 120), Color3.fromRGB(220, 110, 255), Color3.new(1, 1, 1) }
local function confetti(n, gold)
	for _ = 1, n do
		local c = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(math.random(7, 13), math.random(12, 20)),
			BackgroundColor3 = gold and math.random() < 0.5 and Color3.fromRGB(255, 200, 40) or CONFETTI[math.random(#CONFETTI)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 15,
			Parent = ui.case,
		})
		local x = 0.5 + (math.random() - 0.5) * 0.8
		local y = 0.42 - math.random() * 0.4
		UIKit.tween(c, 0.35, { Position = UDim2.fromScale(x, y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local dur = 1.4 + math.random() * 1.2
		task.delay(0.35, function()
			if c.Parent then
				UIKit.tween(c, dur, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, 1.1), Rotation = c.Rotation + math.random(-600, 600) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		task.delay(0.4 + dur, function()
			c:Destroy()
		end)
	end
end

-- rouleau de secours (si le serveur n'en envoie pas) : skins du pool de la caisse
local function localReel(win, crateId)
	local pool = {}
	local def = crateDef(crateId)
	if type(def.SkinPool) == "table" then
		for _, k in ipairs({ "Rare", "Epic", "Legendary" }) do
			if (def.Odds and def.Odds[k] or 0) > 0 then
				for _, id in ipairs(def.SkinPool[k] or {}) do
					table.insert(pool, id)
				end
			end
		end
	else
		local S = SkinsCfg()
		if S and S.List then
			for id, d in pairs(S.List) do
				if d.Rarity ~= "Base" then
					table.insert(pool, id)
				end
			end
		end
	end
	if #pool == 0 then
		pool = { win }
	end
	local r = {}
	for i = 1, 30 do
		r[i] = pool[math.random(#pool)]
	end
	r[REEL_WIN] = win
	return r
end

local function reelCard(i, id)
	local d = skinDef(id)
	local r = rarity(d and d.Rarity)
	local kit = d and Characters[d.Character]
	local c = UIKit.new("Frame", { Name = "C" .. i, Position = UDim2.fromOffset((i - 1) * STEP + 5, 0), Size = UDim2.fromOffset(REEL_CARD, 180), BackgroundColor3 = r.Color, Parent = ui.strip })
	UIKit.corner(c, UDim.new(0, 6))
	UIKit.stroke(c, 3, UIKit.Black, true)
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)), Parent = c })
	local top = UIKit.label({ Text = r.Label, Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, 20), Stroke = 2 })
	top.Parent = c
	local inner = UIKit.new("Frame", { Position = UDim2.fromOffset(6, 26), Size = UDim2.new(1, -12, 0, 106), BackgroundColor3 = COL.Dark, ClipsDescendants = true, Parent = c })
	UIKit.corner(inner, UDim.new(0, 6))
	if math.abs(i - REEL_WIN) <= 4 then
		showView(newView(inner, false, 2), id)
	else
		-- silhouette légère (pas de viewport pour les cartes qui défilent trop vite)
		local o = d and d.Outfit or {}
		local head = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = o.Skin or COL.Skin, Parent = inner })
		UIKit.corner(head, UDim.new(0, 6))
		UIKit.stroke(head, 2, UIKit.Black, true)
		local body = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 43), Size = UDim2.fromOffset(54, 38), BackgroundColor3 = o.Shirt or (kit and kit.Color) or COL.Grey, Parent = inner })
		UIKit.corner(body, UDim.new(0, 6))
		UIKit.stroke(body, 2, UIKit.Black, true)
		local legs = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(40, 26), BackgroundColor3 = o.Pants or COL.Dark, Parent = inner })
		UIKit.stroke(legs, 2, UIKit.Black, true)
	end
	local nm = UIKit.label({ Text = d and d.Name or "?", Position = UDim2.fromOffset(6, 134), Size = UDim2.new(1, -12, 0, 22), Stroke = 2 })
	nm.Parent = c
	local who = UIKit.label({ Text = d and string.upper(shortName(d.Character)) or "", Font = BODY, Position = UDim2.fromOffset(6, 157), Size = UDim2.new(1, -12, 0, 17), TextColor3 = kit and kit.Color:Lerp(Color3.new(1, 1, 1), 0.35) or UIKit.White, Stroke = 1.5 })
	who.Parent = c
	return c
end

-- panneau de résultat (après la cinématique : quiet = true => pas de flash / sons / confettis)
local function reveal(res, quiet)
	local d = skinDef(res.skinId)
	local rk = res.rarity or (d and d.Rarity) or "Rare"
	local r = rarity(rk)
	setCaseView("reveal")
	revealRarity = rk
	for i, ray in ipairs(ui.rays) do
		ray.BackgroundColor3 = (rk == "Legendary" and i % 2 == 0) and Color3.fromRGB(255, 250, 210) or r.Color
	end
	for _, g in ipairs(ui.glows) do
		g.BackgroundColor3 = r.Color
	end
	revealView.yaw = 0
	revealView.spin = quiet and 200 or 720
	showView(revealView, res.skinId)
	ui.revRarity.Text = r.Label .. "!"
	ui.revRarity.TextColor3 = r.Color
	ui.revName.Text = string.upper(d and d.Name or tostring(res.skinId))
	local kit = d and Characters[d.Character]
	ui.revChar.Text = kit and ("Skin for " .. kit.DisplayName) or ""
	ui.revChar.TextColor3 = kit and kit.Color:Lerp(Color3.new(1, 1, 1), 0.35) or UIKit.White
	if res.showcase then
		ui.revResult.Text = "SHOWCASE"
		ui.revResult.TextColor3 = COL.Yellow
	elseif res.duplicate then
		ui.revResult.Text = "DUPLICATE  +" .. money(res.refund or 0)
		ui.revResult.TextColor3 = COL.Yellow
	else
		ui.revResult.Text = "NEW!"
		ui.revResult.TextColor3 = Color3.fromRGB(120, 255, 130)
	end
	ui.againBtn.Visible = not res.showcase
	lastWin = { id = res.skinId, char = d and d.Character }
	ui.equipNow.Visible = lastWin.char ~= nil
	ui.equipNow.Label.Text = (lastWin.char and equippedOf(lastWin.char) == lastWin.id) and "EQUIPPED" or "EQUIP NOW"
	ui.equipNow.BackgroundColor3 = (lastWin.char and equippedOf(lastWin.char) == lastWin.id) and COL.Grey or COL.Green
	refreshCase()
	for _, l in ipairs({ ui.revRarity, ui.revName, ui.revResult }) do
		UIKit.pop(l, 1.35)
	end
	UIKit.pop(ui.revealHolder, 1.2)
	if quiet then
		return
	end
	ui.flash.BackgroundColor3 = r.Color:Lerp(Color3.new(1, 1, 1), 0.55)
	ui.flash.BackgroundTransparency = 0
	UIKit.tween(ui.flash, 0.7, { BackgroundTransparency = 1 })
	if rk == "Legendary" then
		sfx("LevelUp", 1, 0.7)
		sfx("PowerUp", 1.1, 0.5)
		confetti(110, true)
	elseif rk == "Epic" then
		sfx("LevelUp", 1.1, 0.6)
		confetti(35)
	else
		sfx("Ding", 1.1, 0.6)
	end
end

------------------------------------------------------------------------ dessin 3D des caisses
local function vpPart(model, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Parent = model
	return p
end

-- modèle selon crate.Shape : "Box" (carton) | "Briefcase" (mallette) | "Crate" (caisse en bois) | "Safe" (coffre-fort)
local function buildCrateModel(def)
	local m = Instance.new("Model")
	local col = def.Color or Color3.fromRGB(200, 160, 100)
	local acc = def.Accent or Color3.fromRGB(255, 210, 60)
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.38)
	local C, A = CFrame.new, CFrame.Angles
	local shape = def.Shape or "Crate"
	if shape == "Box" then
		vpPart(m, Vector3.new(4, 3, 3.2), C(0, 0, 0), col)
		vpPart(m, Vector3.new(4.04, 3.04, 0.55), C(0, 0, 0), col:Lerp(Color3.new(1, 1, 1), 0.35)) -- scotch
		vpPart(m, Vector3.new(4, 0.15, 1.6), C(0, 1.55, -1.6) * A(math.rad(-35), 0, 0) * C(0, 0, -0.75), dark)
		vpPart(m, Vector3.new(4, 0.15, 1.6), C(0, 1.55, 1.6) * A(math.rad(35), 0, 0) * C(0, 0, 0.75), dark)
		vpPart(m, Vector3.new(1.3, 0.7, 0.06), C(-1.1, -0.6, -1.63), Color3.new(1, 1, 1)) -- étiquette
		vpPart(m, Vector3.new(0.9, 0.12, 0.06), C(-1.1, -0.5, -1.67), Color3.fromRGB(40, 40, 40))
		vpPart(m, Vector3.new(0.9, 0.12, 0.06), C(-1.1, -0.75, -1.67), Color3.fromRGB(40, 40, 40))
	elseif shape == "Briefcase" then
		vpPart(m, Vector3.new(4.6, 3, 1.3), C(0, 0, 0), col)
		vpPart(m, Vector3.new(4.66, 0.2, 1.36), C(0, 0.55, 0), dark)
		vpPart(m, Vector3.new(0.3, 0.8, 0.4), C(-0.75, 1.85, 0), dark)
		vpPart(m, Vector3.new(0.3, 0.8, 0.4), C(0.75, 1.85, 0), dark)
		vpPart(m, Vector3.new(1.8, 0.3, 0.4), C(0, 2.2, 0), dark)
		vpPart(m, Vector3.new(0.55, 0.45, 0.16), C(-1.5, 0.55, -0.72), acc, { material = Enum.Material.Neon })
		vpPart(m, Vector3.new(0.55, 0.45, 0.16), C(1.5, 0.55, -0.72), acc, { material = Enum.Material.Neon })
		for _, x in ipairs({ -2.2, 2.2 }) do
			for _, y in ipairs({ -1.4, 1.4 }) do
				vpPart(m, Vector3.new(0.38, 0.38, 1.42), C(x, y, 0), acc)
			end
		end
	elseif shape == "Safe" then
		vpPart(m, Vector3.new(3.6, 3.6, 3.2), C(0, 0, 0), col, { material = Enum.Material.Metal })
		vpPart(m, Vector3.new(3.0, 3.0, 0.2), C(0, 0, -1.65), dark, { material = Enum.Material.Metal })
		vpPart(m, Vector3.new(0.25, 1.2, 1.2), C(0.4, 0.2, -1.8) * A(0, math.rad(90), 0), acc, { shape = Enum.PartType.Cylinder })
		vpPart(m, Vector3.new(0.14, 0.55, 0.14), C(0.4, 0.55, -1.95), Color3.fromRGB(30, 30, 30))
		vpPart(m, Vector3.new(0.28, 1.1, 0.28), C(-1.0, 0, -1.88), acc)
		vpPart(m, Vector3.new(3.66, 0.22, 3.26), C(0, 1.75, 0), acc, { material = Enum.Material.Neon })
		vpPart(m, Vector3.new(3.66, 0.22, 3.26), C(0, -1.75, 0), acc)
		for _, x in ipairs({ -1.4, 1.4 }) do
			for _, z in ipairs({ -0.9, 0.9 }) do
				vpPart(m, Vector3.new(0.45, 0.35, 0.45), C(x, -2.0, z), Color3.fromRGB(30, 30, 30))
			end
		end
	else
		vpPart(m, Vector3.new(3.4, 3.4, 3.4), C(0, 0, 0), col)
		local e = 0.42
		for _, a in ipairs({ -1.6, 1.6 }) do
			for _, b in ipairs({ -1.6, 1.6 }) do
				vpPart(m, Vector3.new(e, 3.52, e), C(a, 0, b), dark)
				vpPart(m, Vector3.new(3.52, e, e), C(0, a, b), dark)
				vpPart(m, Vector3.new(e, e, 3.52), C(a, b, 0), dark)
			end
		end
		vpPart(m, Vector3.new(4.3, 0.38, 0.16), C(0, 0, -1.72) * A(0, 0, math.rad(45)), dark)
		vpPart(m, Vector3.new(1.1, 1.1, 1.1), C(0, 0, -1.75), acc, { material = Enum.Material.Neon, shape = Enum.PartType.Ball })
	end
	return m
end

-- ViewportFrame avec la caisse ; renvoie vp et un « spinner » (t, speed, place) animé par step()
local function crateViewport(parent, def, props)
	local vp = UIKit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(175, 175, 190),
		LightColor = Color3.fromRGB(255, 250, 235),
		LightDirection = Vector3.new(-1, -2, 1.2),
	})
	for k, v in pairs(props or {}) do
		vp[k] = v
	end
	buildCrateModel(def).Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local sp = { t = math.random() * 6, speed = 0.6 }
	function sp.place()
		local a = sp.t
		cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 12, 4.6, -math.cos(a) * 12), Vector3.new(0, 0.1, 0))
	end
	sp.place()
	vp.Parent = parent
	return vp, sp
end

------------------------------------------------------------------------ rouleau
local function themeReel(def)
	local c = def.Color or COL.Gold
	ui.reelTitle.Text = "OPENING " .. string.upper(def.Name or "CRATE") .. "..."
	ui.reelTitle.TextColor3 = Theme.lighten(c, 0.3)
	local bg = Theme.darken(c, 0.72)
	ui.reelClip.BackgroundColor3 = bg
	for _, f in ipairs(ui.reelFades) do
		f.BackgroundColor3 = bg
	end
	local hi = Theme.lighten(c, 0.35)
	ui.reelMarker.BackgroundColor3 = hi
	for _, t in ipairs(ui.reelTris) do
		t.BackgroundColor3 = hi
	end
	ui.reelBand.BackgroundColor3 = c
	for _, ch in ipairs(ui.reelArt:GetChildren()) do
		ch:Destroy()
	end
	local _, sp = crateViewport(ui.reelArt, def, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	sp.speed = 3
	ui.reelSpin = sp
end

local function spin(res)
	local def = crateDef(res.crateId or curCrate)
	setCaseView("reel")
	caseMessage("")
	themeReel(def)
	for _, ch in ipairs(ui.strip:GetChildren()) do
		ch:Destroy()
	end
	local reel = (type(res.reel) == "table" and #res.reel >= REEL_WIN) and res.reel or localReel(res.skinId, def.Id)
	local list = {}
	for i, id in ipairs(reel) do
		list[i] = reelCard(i, id)
	end
	ui.strip.Size = UDim2.fromOffset(#reel * STEP + 10, 180)
	local CENTER = 460
	local function xFor(idx, jitter)
		return CENTER - ((idx - 0.5) * STEP + (jitter or 0))
	end
	local startX = xFor(3)
	local endX = xFor(REEL_WIN, (math.random() - 0.5) * (REEL_CARD - 36))
	local T, t0, lastIdx, lastTick = 5.2, os.clock(), -1, 0
	ui.strip.Position = UDim2.fromOffset(startX, 10)
	while true do
		local t = math.min((os.clock() - t0) / T, 1)
		local e = 1 - (1 - t) ^ 4
		local x = startX + (endX - startX) * e
		ui.strip.Position = UDim2.fromOffset(x, 10)
		local idx = math.floor((CENTER - x) / STEP)
		if idx ~= lastIdx then
			lastIdx = idx
			local nowc = os.clock()
			if nowc - lastTick > 0.035 then
				lastTick = nowc
				sfx("UIClick", 1.6 - 0.5 * e, 0.35)
			end
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	UIKit.tween(ui.strip, 0.35, { Position = UDim2.fromOffset(xFor(REEL_WIN), 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	task.wait(0.4)
	local win = list[REEL_WIN]
	if win then
		UIKit.stroke(win, 5, Color3.new(1, 1, 1), true)
		UIKit.pop(win, 1.15)
	end
	task.wait(0.5)
	-- révélation cinématique (SkinRevealController), puis le panneau avec les boutons
	local R = revealCtl()
	if R then
		local done = false
		gui.Enabled = false
		local ok, err = pcall(R.play, res.skinId, {
			isNew = not res.duplicate,
			refund = res.refund,
			crateId = res.crateId or def.Id,
			onDone = function()
				done = true
			end,
		})
		if not ok then
			warn("[CharacterSelect] SkinRevealController.play : " .. tostring(err))
			done = true
		end
		local tw = os.clock()
		while not done and os.clock() - tw < 25 do
			task.wait(0.05)
		end
		gui.Enabled = true
		reveal(res, true)
	else
		reveal(res)
	end
end

openCrate = function(crateId)
	if spinning then
		return
	end
	if type(crateId) ~= "string" then
		crateId = curCrate -- Activated passe un InputObject
	end
	local def = crateDef(crateId)
	curCrate = def.Id
	interacted()
	caseMessage("")
	if not remote("SkinRequest") then
		caseMessage("Crates are not available yet!", COL.Red, true)
		return
	end
	local free = def.Id == defaultCrate() and crates() > 0
	if not free and cash() < (def.Price or 300) then
		noCash(def.Id)
		return
	end
	spinning = true
	sfx("UIClick", 1, 0.5)
	local res = request("OpenCrate", def.Id)
	if type(res) ~= "table" or not res.ok then
		spinning = false
		if type(res) == "table" and res.reason == "NOT_ENOUGH_CASH" then
			noCash(def.Id)
		else
			setCaseView("shop")
			caseMessage("Couldn't open the crate. Try again!", COL.Red, true)
		end
		return
	end
	if res.skinId then
		state.Owned[res.skinId] = true
	end
	task.spawn(function()
		local ok, err = pcall(spin, res)
		spinning = false
		if not ok then
			warn("[CharacterSelect] spin : " .. tostring(err))
			gui.Enabled = true
			setCaseView("shop")
		end
		refreshAll()
	end)
end

refreshCase = function()
	if not built then
		return
	end
	ui.caseCashL.Text = money(cash())
	local n = crates()
	local function freeFor(id)
		return id == defaultCrate() and n > 0
	end
	for _, def in ipairs(crateList()) do
		local cc = crateCards[def.Id]
		if cc then
			local free = freeFor(def.Id)
			local afford = free or cash() >= (def.Price or 0)
			if not cc.flashT then
				cc.btn.Label.Text = free and "OPEN FREE" or ("OPEN " .. money(def.Price))
				cc.btn.BackgroundColor3 = afford and COL.Green or COL.Grey
			end
			cc.tagL.Text = free and "FREE" or money(def.Price)
			cc.tag.BackgroundColor3 = free and COL.Green or COL.Red
			if cc.badge then
				cc.badge.Visible = free
				cc.badgeL.Text = "FREE x" .. n
			end
			if not cc.shine then
				local on = def.Id == curCrate
				cc.stroke.Color = on and Theme.lighten(def.Color or COL.Gold, 0.4) or UIKit.Black
				cc.stroke.Thickness = on and 4 or 3
			end
		end
	end
	local cur = crateDef(curCrate)
	local free = freeFor(cur.Id)
	ui.againBtn.Label.Text = free and ("OPEN AGAIN (FREE x" .. n .. ")") or ("OPEN AGAIN " .. money(cur.Price))
	if (free or cash() >= (cur.Price or 0)) and string.find(ui.caseMsg.Text, "NOT ENOUGH", 1, true) then
		caseMessage("")
	end
end

------------------------------------------------------------------------ cartes de caisses
local function ribbonText(def)
	if def.Odds and (def.Odds.Rare or 0) == 0 then
		return "EPIC+"
	elseif def.Pool then
		return #def.Pool .. " JOBS"
	elseif def.Id == "SupplyBox" then
		return "CHEAP!"
	end
	return "CLASSIC"
end

local function poolArea(face, def, y)
	local head = UIKit.label({ Text = def.Pool and "POOL" or "POOL: EVERYONE", Font = BODY, Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 4 })
	head.Parent = face
	local area = UIKit.new("Frame", { Position = UDim2.fromOffset(8, y + 16), Size = UDim2.new(1, -16, 0, 64), BackgroundTransparency = 1, ZIndex = 3, Parent = face })
	if def.Pool then
		UIKit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -2, 0, 30), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = area })
		for j, charId in ipairs(def.Pool) do
			local kit = Characters[charId]
			local chip = UIKit.new("Frame", { BackgroundColor3 = kit and kit.Color or COL.Grey, LayoutOrder = j, ZIndex = 3, Parent = area })
			UIKit.corner(chip, UDim.new(0, 4))
			UIKit.stroke(chip, 2, UIKit.Black, true)
			Theme.bevel(chip, 0.7, 0.75)
			local l = UIKit.label({ Text = string.upper(shortName(charId)), Font = BODY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.new(1, -6, 1, -10), TextWrapped = true, Stroke = 1.5, ZIndex = 4 })
			l.Parent = chip
		end
	else
		-- tous les persos : une mosaïque de pastilles aux couleurs des métiers
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(12, 12), CellPadding = UDim2.fromOffset(2, 3), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = area })
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = area })
		for j, charId in ipairs(Characters.Order) do
			local kit = Characters[charId]
			if kit then
				local dot = UIKit.new("Frame", { BackgroundColor3 = kit.Color or COL.Grey, LayoutOrder = j, ZIndex = 3, Parent = area })
				UIKit.corner(dot, UDim.new(0, 3))
				UIKit.stroke(dot, 1.5, UIKit.Black, true)
			end
		end
	end
end

local function buildCrateCard(def, i, count)
	local total = count * CARD_W + (count - 1) * CARD_GAP
	local x = math.floor((W - total) / 2) + (i - 1) * (CARD_W + CARD_GAP)
	local col = def.Color or COL.Gold
	local holder = UIKit.new("Frame", { Name = def.Id, Position = UDim2.fromOffset(x, CARD_Y), Size = UDim2.fromOffset(CARD_W, CARD_H), BackgroundTransparency = 1, Parent = ui.shop })
	local hover = UIKit.new("UIScale", { Name = "HoverScale", Parent = holder })
	local shadow = UIKit.new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Colors.Shadow, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 1, Parent = holder })
	UIKit.corner(shadow, UDim.new(0, 6))
	local face = UIKit.new("TextButton", { Name = "Face", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.Card, ZIndex = 2, Parent = holder })
	UIKit.corner(face, UDim.new(0, 6))
	local st = UIKit.stroke(face, 3, UIKit.Black, true)
	local shine
	if (def.Odds and (def.Odds.Rare or 0) == 0) or def.Shape == "Safe" then
		-- liseré doré qui tourne (caisse premium)
		st.Color = Color3.new(1, 1, 1)
		st.Thickness = 4
		shine = UIKit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 20)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 20)),
			}),
			Parent = st,
		})
	end
	-- haut coloré (couleur de la caisse)
	local tint = UIKit.new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 156), BackgroundColor3 = col, ZIndex = 2, Parent = face })
	UIKit.corner(tint, UDim.new(0, 5))
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 95, 110)), Parent = tint })
	local nm = UIKit.label({ Text = string.upper(def.Name or def.Id), Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 32), TextWrapped = true, Stroke = 2.5, ZIndex = 5, MaxText = 15 })
	nm.Parent = face
	local glow = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CARD_W / 2, 100), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = Theme.lighten(col, 0.55), BackgroundTransparency = 0.55, ZIndex = 2, Parent = face })
	UIKit.corner(glow, UDim.new(0.5, 0))
	local _, sp = crateViewport(face, def, { Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 0, 118), ZIndex = 3 })
	local rib = UIKit.new("Frame", { Position = UDim2.fromOffset(-6, 42), Size = UDim2.fromOffset(66, 20), Rotation = -10, BackgroundColor3 = COL.Yellow, ZIndex = 7, Parent = face })
	UIKit.corner(rib, UDim.new(0, 4))
	UIKit.stroke(rib, 2, UIKit.Black, true)
	local ribL = UIKit.label({ Text = ribbonText(def), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 0.7, 0), TextColor3 = UIKit.Black, Stroke = false, ZIndex = 8 })
	ribL.Parent = rib
	local tag = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 2, 0, 162), Size = UDim2.fromOffset(70, 26), Rotation = -7, BackgroundColor3 = COL.Red, ZIndex = 7, Parent = face })
	UIKit.corner(tag, UDim.new(0, 5))
	UIKit.stroke(tag, 2.5, UIKit.Black, true)
	local tagL = UIKit.label({ Text = money(def.Price), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 0.68, 0), Stroke = 2, ZIndex = 8 })
	tagL.Parent = tag

	-- barre des chances + lignes (Legendary en or)
	local odds = def.Odds or {}
	local bar = UIKit.new("Frame", { Position = UDim2.fromOffset(8, 168), Size = UDim2.new(1, -16, 0, 14), BackgroundColor3 = COL.Dark, ClipsDescendants = true, ZIndex = 3, Parent = face })
	UIKit.corner(bar, UDim.new(0, 4))
	UIKit.stroke(bar, 2, UIKit.Black, true)
	local acc = 0
	for _, k in ipairs({ "Rare", "Epic", "Legendary" }) do
		local w = (odds[k] or 0) / 100
		if w > 0 then
			-- le 1 % / 5 % reste visible : largeur mini de 4 px
			local seg = UIKit.new("Frame", { Position = UDim2.fromScale(acc, 0), Size = UDim2.new(w, k == "Legendary" and 4 or 0, 1, 0), BackgroundColor3 = k == "Legendary" and COL.Gold or rarity(k).Color, BorderSizePixel = 0, ZIndex = 4, Parent = bar })
			UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Parent = seg })
			acc += w
		end
	end
	for j, k in ipairs({ "Rare", "Epic", "Legendary" }) do
		local v = odds[k] or 0
		local c = k == "Legendary" and COL.Gold or Theme.lighten(rarity(k).Color, 0.25)
		local l = UIKit.label({
			Text = rarity(k).Label .. "  " .. (v > 0 and (v .. "%") or "--"),
			Font = BODY,
			Position = UDim2.fromOffset(8, 186 + (j - 1) * 16),
			Size = UDim2.new(1, -16, 0, 15),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = v > 0 and c or Color3.fromRGB(110, 110, 125),
			Stroke = 1.5,
			ZIndex = 4,
		})
		l.Parent = face
	end
	poolArea(face, def, 238)
	local desc = UIKit.label({ Text = def.Desc or "", Font = BODY, Position = UDim2.fromOffset(8, 322), Size = UDim2.new(1, -16, 0, 46), TextWrapped = true, TextColor3 = Color3.fromRGB(205, 210, 228), Stroke = 1.5, ZIndex = 4, MaxText = 13 })
	desc.Parent = face
	local btn = UIKit.button({ Name = "Open", Text = "OPEN", Color = COL.Green, Position = UDim2.new(0, 8, 1, -58), Size = UDim2.new(1, -16, 0, 50), TextSize = UDim2.fromScale(0.86, 0.42), ZIndex = 5, Parent = face })
	btn.Activated:Connect(function()
		openCrate(def.Id)
	end)
	local badge, badgeL
	if def.Id == defaultCrate() then
		badge = UIKit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 10, 0, -10), Size = UDim2.fromOffset(82, 26), Rotation = 8, BackgroundColor3 = COL.Red, Visible = false, ZIndex = 12, Parent = holder })
		UIKit.corner(badge, UDim.new(0, 5))
		UIKit.stroke(badge, 2.5, UIKit.Black, true)
		badgeL = UIKit.label({ Text = "FREE", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -10, 0.7, 0), Stroke = 2, ZIndex = 13 })
		badgeL.Parent = badge
	end
	face.MouseEnter:Connect(function()
		UIKit.tween(hover, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		sp.speed = 2.6
	end)
	face.MouseLeave:Connect(function()
		UIKit.tween(hover, 0.12, { Scale = 1 })
		sp.speed = 0.6
	end)
	face.Activated:Connect(function()
		interacted()
		curCrate = def.Id
		sfx("UIClick", 1.2, 0.35)
		refreshCase()
	end)
	crateCards[def.Id] = { holder = holder, face = face, stroke = st, shine = shine, btn = btn, tag = tag, tagL = tagL, badge = badge, badgeL = badgeL, spin = sp, glow = glow, order = i }
end

local function buildCase()
	local c = UIKit.new("Frame", { Name = "CrateShop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.35, Active = true, Visible = false, ZIndex = 10, Parent = gui })
	ui.case = c
	local win = UIKit.panel({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 0, ClipsDescendants = true, Parent = c })
	win:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 18)
	win:FindFirstChildOfClass("UIStroke").Thickness = 4
	UIKit.new("UIScale", { Name = "AutoScale", Parent = win })
	ui.caseWin = win
	local title = UIKit.label({ Text = "CRATE SHOP", Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(300, 40), TextColor3 = COL.Gold, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 4, ZIndex = 6 })
	title.Parent = win
	local hint = UIKit.label({ Text = "Different crates, different odds! Legendary is never above 5%. Duplicates give cash back.", Font = BODY, Position = UDim2.fromOffset(326, 12), Size = UDim2.fromOffset(450, 38), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(210, 215, 235), Stroke = 1.5, ZIndex = 6 })
	hint.Parent = win
	local _, caseCashL = pill(win, COL.CashBg, UDim2.fromOffset(786, 13), UDim2.fromOffset(148, 36), "$0")
	ui.caseCashL = caseCashL
	local close = UIKit.button({ Name = "Close", Text = "X", Color = COL.Red, Position = UDim2.fromOffset(944, 9), Size = UDim2.fromOffset(44, 44), ZIndex = 6, Parent = win })
	close.Activated:Connect(function()
		if not spinning then
			c.Visible = false
			setCaseView("shop")
			refreshAll()
		end
	end)

	-- boutique : les caisses côte à côte
	local shop = UIKit.new("Frame", { Name = "Shop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = win })
	ui.idle = shop
	ui.shop = shop
	local list = crateList()
	for i, def in ipairs(list) do
		buildCrateCard(def, i, #list)
	end
	ui.caseMsg = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, MSG_Y), Size = UDim2.fromOffset(900, 26), TextColor3 = COL.Red, Stroke = 2.5, ZIndex = 9 })
	ui.caseMsg.Parent = shop -- message propre à la boutique (caché pendant le rouleau / le résultat)
	local S = SkinsCfg()
	local E = S and S.Earn or { KO = 30, Per100Damage = 10, SurviveCollapse = 15, Task = 50, GradeUp = 150 }
	local earn = UIKit.label({
		Text = string.format("Earn cash by playing: K.O. +%s  -  100 damage +%s  -  survive a collapse +%s  -  daily task +%s  -  grade up +%s", money(E.KO), money(E.Per100Damage), money(E.SurviveCollapse), money(E.Task), money(E.GradeUp)),
		Font = BODY,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(500, 532),
		Size = UDim2.fromOffset(900, 34),
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(190, 200, 215),
		Stroke = 1.5,
	})
	earn.Parent = shop

	-- rouleau (aux couleurs de la caisse ouverte)
	local rv = UIKit.new("Frame", { Name = "Reel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win })
	ui.reelView = rv
	ui.reelBand = UIKit.new("Frame", { Position = UDim2.fromOffset(0, 380), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = COL.Gold, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = rv })
	ui.reelArt = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 396), Size = UDim2.fromOffset(170, 150), BackgroundTransparency = 1, Parent = rv })
	ui.reelTitle = UIKit.label({ Text = "OPENING...", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 92), Size = UDim2.fromOffset(820, 40), TextColor3 = COL.Yellow, Stroke = 3 })
	ui.reelTitle.Parent = rv
	local clip = UIKit.new("Frame", { Position = UDim2.fromOffset(40, 150), Size = UDim2.fromOffset(920, 200), BackgroundColor3 = COL.Dark, ClipsDescendants = true, Parent = rv })
	UIKit.corner(clip, UDim.new(0, 6))
	UIKit.stroke(clip, 4, UIKit.Black, true)
	ui.reelClip = clip
	ui.strip = UIKit.new("Frame", { Name = "Strip", Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(4200, 180), BackgroundTransparency = 1, ZIndex = 1, Parent = clip })
	ui.reelFades = {}
	for side = 0, 1 do
		local f = UIKit.new("Frame", { AnchorPoint = Vector2.new(side, 0), Position = UDim2.fromScale(side, 0), Size = UDim2.new(0, 130, 1, 0), BackgroundColor3 = COL.Dark, BorderSizePixel = 0, ZIndex = 3, Parent = clip })
		UIKit.new("UIGradient", { Transparency = side == 0 and NumberSequence.new(0, 1) or NumberSequence.new(1, 0), Parent = f })
		table.insert(ui.reelFades, f)
	end
	ui.reelMarker = UIKit.new("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(460, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = COL.Yellow, BorderSizePixel = 0, ZIndex = 4, Parent = clip })
	ui.reelTris = {}
	for _, y in ipairs({ 150, 350 }) do
		local tri = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, y), Size = UDim2.fromOffset(26, 26), Rotation = 45, BackgroundColor3 = COL.Yellow, ZIndex = 5, Parent = rv })
		UIKit.stroke(tri, 3, UIKit.Black, true)
		table.insert(ui.reelTris, tri)
	end

	-- résultat (après la cinématique) : skin qui tourne + EQUIP NOW / OPEN AGAIN / BACK TO CRATES
	local rev = UIKit.new("Frame", { Name = "Reveal", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win })
	ui.reveal = rev
	ui.rays = {}
	for i = 1, 12 do
		local ray = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 210), Size = UDim2.fromOffset(50, 440), BackgroundColor3 = COL.Gold, BorderSizePixel = 0, ZIndex = 1, Parent = rev })
		UIKit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }), Parent = ray })
		ui.rays[i] = ray
	end
	ui.glows = {}
	for i, s in ipairs({ 330, 250, 180 }) do
		local g = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 210), Size = UDim2.fromOffset(s, s), BackgroundColor3 = COL.Gold, BackgroundTransparency = 0.88 - i * 0.1, ZIndex = 2, Parent = rev })
		g:SetAttribute("Base", s)
		UIKit.corner(g, UDim.new(0.5, 0))
		ui.glows[i] = g
	end
	ui.revealHolder = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 210), Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 1, ZIndex = 3, Parent = rev })
	revealView = newView(ui.revealHolder, true, 3)
	revealView.dist = 16
	local shineClip = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = ui.revealHolder })
	ui.shine = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.5), Size = UDim2.fromScale(0.16, 1.6), Rotation = 20, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = shineClip })
	ui.revRarity = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 344), Size = UDim2.fromOffset(600, 44), Stroke = 4, ZIndex = 5 })
	ui.revRarity.Parent = rev
	ui.revName = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 388), Size = UDim2.fromOffset(700, 34), Stroke = 3, ZIndex = 5 })
	ui.revName.Parent = rev
	ui.revChar = UIKit.label({ Text = "", Font = BODY, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 423), Size = UDim2.fromOffset(600, 22), Stroke = 2, ZIndex = 5 })
	ui.revChar.Parent = rev
	ui.revResult = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 447), Size = UDim2.fromOffset(600, 30), Stroke = 3, ZIndex = 5 })
	ui.revResult.Parent = rev
	ui.equipNow = UIKit.button({ Name = "EquipNow", Text = "EQUIP NOW", Color = COL.Green, Position = UDim2.fromOffset(130, 498), Size = UDim2.fromOffset(210, 58), ZIndex = 6, Parent = rev })
	ui.equipNow.Activated:Connect(function()
		if not lastWin or not lastWin.char or spinning then
			return
		end
		if equip(lastWin.char, lastWin.id) then
			ui.equipNow.Label.Text = "EQUIPPED"
			ui.equipNow.BackgroundColor3 = COL.Grey
			if root.Visible then
				selectChar(lastWin.char)
			end
		end
	end)
	ui.againBtn = UIKit.button({ Name = "OpenAgain", Text = "OPEN AGAIN", Color = COL.Gold, Position = UDim2.fromOffset(352, 498), Size = UDim2.fromOffset(270, 58), TextSize = UDim2.fromScale(0.9, 0.46), ZIndex = 6, Parent = rev })
	ui.againBtn.Activated:Connect(function()
		openCrate(curCrate)
	end)
	local back = UIKit.button({ Name = "BackToCrates", Text = "BACK TO CRATES", Color = Color3.fromRGB(80, 120, 230), Position = UDim2.fromOffset(634, 498), Size = UDim2.fromOffset(236, 58), TextSize = UDim2.fromScale(0.9, 0.46), ZIndex = 6, Parent = rev })
	back.Activated:Connect(function()
		if not spinning then
			setCaseView("shop")
			refreshAll()
		end
	end)
	ui.flash = UIKit.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = c })
end

------------------------------------------------------------------------
-- Boucle (aperçu qui tourne, liserés, rayons)
------------------------------------------------------------------------
local function step(dt)
	if root and root.Visible then
		if previewView.model and previewView.vf.Visible then
			if not dragging and os.clock() - lastDrag > 1.2 then
				previewView.yaw += dt * 40
			end
			frameView(previewView)
		end
		shineT += dt
		for _, sc in ipairs(skinCards) do
			if sc.shine.Enabled then
				sc.shine.Rotation = (shineT * 140) % 360
			end
		end
	end
	if ui.case and ui.case.Visible then
		local t = os.clock()
		if ui.idle.Visible then
			for _, cc in pairs(crateCards) do
				if cc.spin then
					cc.spin.t += dt * cc.spin.speed
					cc.spin.place()
				end
				if cc.shine then
					cc.shine.Rotation = (t * 140) % 360
				end
				if cc.badge and cc.badge.Visible then
					cc.badge.Rotation = 8 + math.sin(t * 6) * 5
				end
				if cc.glow then
					local g = 96 * (1 + 0.08 * math.sin(t * 3 + cc.order))
					cc.glow.Size = UDim2.fromOffset(g, g)
				end
			end
		end
		if ui.reelView.Visible and ui.reelSpin then
			ui.reelSpin.t += dt * ui.reelSpin.speed
			ui.reelSpin.place()
		end
		if ui.reveal.Visible then
			local rot = t * 22
			for i, ray in ipairs(ui.rays) do
				ray.Rotation = rot + i * (180 / #ui.rays)
			end
			for i, g in ipairs(ui.glows) do
				local s = (g:GetAttribute("Base") or 200) * (1 + 0.06 * math.sin(t * 3 + i))
				g.Size = UDim2.fromOffset(s, s)
			end
			if revealView.model then
				revealView.spin = math.max(45, (revealView.spin or 45) * (1 - math.min(dt * 2.2, 0.5)))
				revealView.yaw += dt * revealView.spin
				frameView(revealView)
			end
			ui.shine.Visible = revealRarity == "Legendary"
			if ui.shine.Visible then
				ui.shine.Position = UDim2.fromScale(((t * 0.8) % 1.8) - 0.3, 0.5)
			end
		end
	end
end

------------------------------------------------------------------------
-- Achat d'un perso (Cash : confirmation ; Robux : Game Pass ; COMING SOON si GamePassId = 0)
------------------------------------------------------------------------
local function unlockConfetti()
	for _ = 1, 36 do
		local c = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.45, 0.4),
			Size = UDim2.fromOffset(math.random(7, 12), math.random(12, 18)),
			BackgroundColor3 = math.random() < 0.5 and COL.Gold or Color3.fromHSV(math.random(), 0.7, 1),
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 40,
			Parent = root,
		})
		local x = 0.45 + (math.random() - 0.5) * 0.7
		local y = 0.4 - math.random() * 0.35
		UIKit.tween(c, 0.3, { Position = UDim2.fromScale(x, y) })
		local dur = 1.2 + math.random()
		task.delay(0.3, function()
			if c.Parent then
				UIKit.tween(c, dur, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.15, 1.05), Rotation = c.Rotation + math.random(-500, 500) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		task.delay(0.35 + dur, function()
			c:Destroy()
		end)
	end
end

function Select.applyUnlock(s)
	if type(s) ~= "table" then
		return
	end
	if type(s.Owned) == "table" then
		unlock.Owned = s.Owned
	end
	if built and root.Visible then
		paintCards()
		refreshButtons()
	end
end

local function doBuyCash(charId)
	local ok, reason, st = unlockRequest("BuyCash", charId)
	Select.applyUnlock(st)
	if ok == true then
		unlock.Owned[charId] = true
		sfx("LevelUp", 1.1, 0.6)
		notify("UNLOCKED " .. string.upper(shortName(charId)) .. "!", COL.Gold)
		unlockConfetti()
		if cards[charId] then
			UIKit.pop(cards[charId].btn, 1.15)
		end
	elseif reason == "NOT_ENOUGH_CASH" then
		notify("Not enough Cash!", COL.Red)
	elseif reason == "OWNED" then
		notify("You already own " .. shortName(charId) .. "!", COL.Green)
	else
		notify("Purchase failed, try again!", COL.Red)
	end
	paintCards()
	refreshButtons()
	refreshHeader()
end

local function confirmBuy(charId)
	local kit = Characters[charId]
	local e = unlockOf(charId)
	if not ui.confirm then
		local c = UIKit.new("Frame", { Name = "Confirm", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.45, Active = true, Visible = false, ZIndex = 30, Parent = root })
		UIKit.corner(c, UDim.new(0, 18))
		local box = UIKit.panel({ Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 250), Accent = COL.Gold, Parent = c })
		local title = UIKit.label({ Name = "Title", Text = "", Position = UDim2.fromOffset(20, 22), Size = UDim2.new(1, -40, 0, 34), TextColor3 = COL.Yellow, Stroke = 3 })
		title.Parent = box
		local sub = UIKit.label({ Name = "Sub", Text = "", Font = BODY, RichText = true, Position = UDim2.fromOffset(24, 66), Size = UDim2.new(1, -48, 0, 74), TextWrapped = true, Stroke = 1.5 })
		sub.Parent = box
		local yes = UIKit.button({ Name = "Yes", Text = "BUY", Color = COL.Green, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.new(0.5, -32, 0, 56), TextSize = UDim2.fromScale(0.86, 0.42), Parent = box })
		local no = UIKit.button({ Name = "No", Text = "CANCEL", Color = COL.Red, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -20), Size = UDim2.new(0.5, -32, 0, 56), TextSize = UDim2.fromScale(0.86, 0.42), Parent = box })
		no.Activated:Connect(function()
			c.Visible = false
		end)
		yes.Activated:Connect(function()
			c.Visible = false
			local id = c:GetAttribute("CharId")
			if id then
				doBuyCash(id)
			end
		end)
		ui.confirm, ui.confirmBox, ui.confirmTitle, ui.confirmSub, ui.confirmYes = c, box, title, sub, yes
	end
	ui.confirm:SetAttribute("CharId", charId)
	ui.confirmTitle.Text = "UNLOCK " .. string.upper(shortName(charId)) .. "?"
	ui.confirmSub.Text = "Unlock <b>" .. UIKit.escape(kit and kit.DisplayName or charId) .. "</b> forever for <font color=\"#6EEB78\">" .. money(e.Price or 0) .. "</font>?\nYou have " .. money(cash()) .. "."
	ui.confirmYes.Label.Text = "BUY " .. money(e.Price or 0)
	ui.confirm.Visible = true
	UIKit.pop(ui.confirmBox, 1.08)
end

buyChar = function(charId)
	local e = unlockOf(charId)
	if ownsChar(charId) then
		return
	end
	if e.Tier == "Cash" then
		local price = e.Price or 0
		if cash() < price then
			notify("Not enough Cash! You need " .. money(price - cash()) .. " more.", COL.Red)
			UIKit.Theme.wobble(ui.play, 4, 0)
			return
		end
		confirmBuy(charId)
	elseif e.Tier == "Robux" then
		if not e.GamePassId or e.GamePassId == 0 then
			notify("COMING SOON! Robux unlocks are on the way.", COL.Gold)
			UIKit.Theme.wobble(ui.play, 4, 0)
			return
		end
		local ok, reason = unlockRequest("BuyRobux", charId)
		if not ok then
			notify(reason == "COMING_SOON" and "COMING SOON!" or "Purchase unavailable right now.", COL.Gold)
		end
	end
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
function Select.close()
	token += 1
	autoToken = 0
	if root then
		root.Visible = false
	end
	if dim then
		dim.Visible = false
	end
end

function Select.choose(name)
	local kit = Characters[name]
	if not kit then
		return
	end
	if not ownsChar(name) then
		notify("LOCKED! Unlock " .. shortName(name) .. " first.", COL.Red)
		return
	end
	local r = remote("SelectCharacter")
	if r then
		r:FireServer(name)
	end
	Select.close()
	toast("You are " .. kit.DisplayName .. "!", kit.Color)
end

function Select.open(withTimer: boolean?)
	if not built then
		return
	end
	token += 1
	local my = token
	applyScale()
	dim.Visible = true
	root.Visible = true
	UIKit.pop(root, 1.04)
	local cur = player.Character and player.Character:GetAttribute("CharacterName")
	selectChar((cur and Characters[cur] and cur) or selChar or Characters.Order[1])
	refreshAll()
	scrollToSelected()
	task.spawn(function()
		local st = request("State")
		if type(st) == "table" then
			applyState(st)
		end
	end)
	task.spawn(function()
		local us = unlockRequest("State")
		if type(us) == "table" then
			Select.applyUnlock(us)
		end
	end)
	ui.title.Text = withTimer and "PICK YOUR JOB!" or "CHOOSE YOUR JOB"
	ui.timer.Text = ""
	if withTimer then
		autoToken = my
		task.spawn(function()
			for t = 8, 1, -1 do
				if token ~= my or autoToken ~= my then
					return
				end
				ui.timer.Text = "Auto-pick: " .. string.upper(shortName(firstOwned(selChar))) .. " in " .. t .. "s  -  click anything to browse"
				task.wait(1)
			end
			if token == my and autoToken == my then
				-- seulement un perso possédé (sinon l'Intern)
				Select.choose(firstOwned(selChar))
			end
		end)
	end
end

local showToken = 0
showcase = function(skinId)
	local d = skinDef(skinId)
	if not d or spinning then
		return
	end
	local R = revealCtl()
	if R then
		if type(R.isPlaying) == "function" and R.isPlaying() then
			return
		end
		showToken += 1
		local my = showToken
		gui.Enabled = false
		local function restore()
			if showToken == my then
				showToken += 1
				gui.Enabled = true
			end
		end
		-- rejouer : pas de remboursement (refund = 0 => pas de « DUPLICATE ») ; opts.showcase = id d'attaque côté révélation, donc non utilisé
		local ok, err = pcall(R.play, skinId, { isNew = true, refund = 0, replay = true, onDone = restore })
		if not ok then
			warn("[CharacterSelect] SkinRevealController.play : " .. tostring(err))
			restore()
		end
		task.delay(25, restore)
	else
		-- secours : panneau de révélation de la boutique
		applyScale()
		ui.case.Visible = true
		reveal({ skinId = skinId, rarity = d.Rarity, duplicate = false, showcase = true })
	end
end
function Select.showcase(skinId)
	showcase(skinId)
end

-- ouvre la boutique de caisses (crateId optionnel = caisse mise en avant)
function Select.openBriefcase(crateId)
	if not built then
		return
	end
	local S = SkinsCfg()
	local pick = type(crateId) == "string" and S and S.CrateById and S.CrateById[crateId] or nil
	if pick then
		curCrate = pick.Id
	end
	applyScale()
	ui.case.Visible = true
	if not spinning then
		setCaseView("shop")
		caseMessage("")
	end
	refreshCase()
	UIKit.pop(ui.caseWin, 1.05)
	if pick and crateCards[pick.Id] then
		task.delay(0.22, function()
			UIKit.pop(crateCards[pick.Id].face, 1.12)
		end)
	end
	task.spawn(function()
		local st = request("State")
		if type(st) == "table" then
			applyState(st)
		end
	end)
end
Select.openCrateShop = Select.openBriefcase

-- test : simule une taille d'écran (ex. Vector2.new(844, 390) = téléphone) ; nil = écran réel
function Select.debugViewport(v)
	Select._fakeViewport = v
	applyScale()
	if root and root.Visible and selChar then
		fillInfo(selChar)
	end
end

function Select.init(ctx)
	hud = ctx.HUDController
	ctxRef = ctx
	Builder() -- require au démarrage : anime les FX « Orbit » côté client
	gui = UIKit.screen("CharacterSelect", 8)
	soundParent = gui
	buildMain()
	buildCase()
	built = true
	applyScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local was = compact
			applyScale()
			if was ~= compact and root.Visible and selChar then
				fillInfo(selChar)
			end
		end)
	end
	if hud and hud.addMenuButton then
		hud.addMenuButton("CHARACTER", Color3.fromRGB(90, 160, 255), function()
			if root.Visible then
				Select.close()
			else
				Select.open(false)
			end
		end, 10)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		refreshHeader()
		refreshCase()
	end)
	player:GetAttributeChangedSignal("Crates"):Connect(function()
		refreshHeader()
		refreshCase()
	end)
	local function hookChar(c)
		c:GetAttributeChangedSignal("CharacterName"):Connect(function()
			if root.Visible then
				paintCards()
			end
		end)
	end
	if player.Character then
		hookChar(player.Character)
	end
	player.CharacterAdded:Connect(hookChar)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local dx = input.Position.X - dragX
			dragX = input.Position.X
			previewView.yaw += dx * 0.8
			lastDrag = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			lastDrag = os.clock()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok and not Select._warned then
			Select._warned = true
			warn("[CharacterSelect] " .. tostring(err))
		end
	end)
	-- réseau skins (threads séparés : ne bloque pas les autres contrôleurs)
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local ev = rem and rem:WaitForChild("SkinState", 60)
		if ev then
			ev.OnClientEvent:Connect(applyState)
		end
	end)
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local rf = rem and rem:WaitForChild("SkinRequest", 60)
		if rf then
			applyState((request("State")))
		end
	end)
	-- déblocage des persos
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local ev = rem and rem:WaitForChild("UnlockState", 60)
		if ev then
			ev.OnClientEvent:Connect(Select.applyUnlock)
		end
	end)
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local rf = rem and rem:WaitForChild("UnlockRequest", 60)
		if rf then
			Select.applyUnlock((unlockRequest("State")))
		end
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if root.Visible and selChar then
			refreshButtons()
		end
	end)
	task.delay(1.5, function()
		if not root.Visible then
			Select.open(true)
		end
	end)
end

return Select
