--[[
	M1Style — résolution des styles de M1 (client ET serveur ; données dans Config/M1Styles, voir docs/M1-Styles.md).

	M1Style.remap(character, baseAnim) -> nom d'animation à jouer pour ce personnage
		baseAnim = un nom de Config/Combat (M1.Anim[i], Uppercut.Anim, Downslam.Anim, Air.Anim[i], DashStrike.Anim) ; tout autre nom est
		rendu tel quel. Arme fétiche en main gauche -> version miroir « <Nom>_L » (générée par ProcAnim).
	M1Style.resolve(character) -> style résolu (objet tenu > arme fétiche > Fists), source ("Item"|"Signature"|"Fists"), itemId?
	M1Style.forCharacter(name) / M1Style.forItem(itemId) -> style résolu (mis en cache)
	M1Style.itemAnim(character, useAnim) -> animation du Use d'objet (alterne selon Config/M1Styles.ItemChains)
	M1Style.info(animName) -> méta de Moves, mirrored (vrai pour un « _L »), nom de base ; ou nil
	M1Style.hand(character) -> "Right" | "Left" (main de l'arme fétiche)
	Aucune dépendance au client (pas de ProcAnim ici) : utilisable par CombatService.
]]
local Config = script.Parent.Parent.Config
local Data = require(Config.M1Styles)
local CombatConfig = require(Config.Combat)
local ItemsConfig = require(Config.Items)

local M1Style = {}
M1Style.Data = Data

-- noms de base (Config/Combat) -> emplacement dans un style
local BASE = {}
for i, n in ipairs(CombatConfig.M1.Anim) do
	BASE[n] = { "M1", i }
end
for i, n in ipairs(CombatConfig.Air.Anim) do
	BASE[n] = { "Air", i }
end
BASE[CombatConfig.Uppercut.Anim] = { "Up" }
BASE[CombatConfig.Downslam.Anim] = { "Slam" }
BASE[CombatConfig.DashStrike.Anim] = { "Dash" }

local function copyStyle(id, s)
	local out = table.clone(s)
	out.Id = id
	out.Anims = table.clone(s.Anims or Data.Styles.Fists.Anims)
	out.Trail = table.clone(s.Trail or Data.Styles.Fists.Trail)
	out.Whoosh = s.Whoosh and table.clone(s.Whoosh) or nil
	return out
end

local charCache, itemCache = {}, {}

function M1Style.forCharacter(name: string?)
	local key = name or "?"
	local cached = charCache[key]
	if cached then
		return cached
	end
	local def = name and Data.Characters[name]
	local styleId = def and def.Style or Data.Default
	local style = copyStyle(styleId, Data.Styles[styleId] or Data.Styles.Fists)
	if def then
		style.Character = name
		style.Hand = def.Hand or "Right"
		for i, a in pairs(def.Hits or {}) do
			style.Anims[i] = a
		end
		if def.Colors then
			style.Trail.Colors = def.Colors
		end
		style.Impact = def.Impact or style.Impact
		style.Whoosh = def.Whoosh or style.Whoosh
	else
		style.Hand = "Right"
	end
	charCache[key] = style
	return style
end

function M1Style.forItem(itemId: string?)
	if not itemId then
		return nil
	end
	local cached = itemCache[itemId]
	if cached ~= nil then
		return cached or nil
	end
	local cfg = ItemsConfig[itemId]
	local use = cfg and cfg.Use
	local styleId = cfg and (Data.Items[itemId] or Data.Families[cfg.Family or ""])
	if not use or not styleId or Data.NoStyleSpecials[use.Special or ""] or not Data.Styles[styleId] then
		itemCache[itemId] = false
		return nil
	end
	local style = copyStyle(styleId, Data.Styles[styleId])
	style.Item = itemId
	style.Hand = "Right"
	local tint = Data.MaterialTint[cfg.Material or ""]
	if tint then
		style.Trail.Colors = { style.Trail.Colors[1], tint }
	end
	itemCache[itemId] = style
	return style
end

function M1Style.hand(character: Model): string
	local sig = character and character:FindFirstChild("Signature")
	local h = sig and sig:GetAttribute("Hand")
	if h == "Left" or h == "Right" then
		return h
	end
	return M1Style.forCharacter(character and character:GetAttribute("CharacterName")).Hand
end

function M1Style.resolve(character: Model)
	local itemId = character and character:GetAttribute("HeldItem")
	local itemStyle = M1Style.forItem(itemId)
	if itemStyle then
		return itemStyle, "Item", itemId
	end
	local name = character and character:GetAttribute("CharacterName")
	local style = M1Style.forCharacter(name)
	return style, (name and Data.Characters[name]) and "Signature" or "Fists", nil
end

function M1Style.remap(character: Model, baseAnim: string): string
	local slot = BASE[baseAnim]
	if not slot or not character then
		return baseAnim
	end
	local style = M1Style.forCharacter(character:GetAttribute("CharacterName"))
	local name
	if slot[1] == "M1" then
		name = style.Anims[slot[2]]
	elseif slot[1] == "Air" then
		name = style.Air and style.Air[slot[2]]
	elseif slot[1] == "Up" then
		name = style.Uppercut
	elseif slot[1] == "Dash" then
		name = style.Dash
	else
		name = style.Downslam
	end
	name = name or baseAnim
	if M1Style.hand(character) == "Left" and Data.Moves[name] then
		name ..= "_L"
	end
	return name
end

-- mini-chaîne d'objet : alterne les animations de Data.ItemChains[baseAnim] à chaque Use. Appelée au même moment
-- logique par le serveur (ItemService.onUse) et par le client local (CombatController) -> même choix, sauf Use refusé
-- par le serveur (le compteur client avance seul ; il se recale à la remise à zéro, ItemChainReset s sans Use).
local itemChain = setmetatable({}, { __mode = "k" }) -- [personnage] = { n, last, item }
function M1Style.itemAnim(character: Model, baseAnim: string): string
	local list = Data.ItemChains[baseAnim]
	if not list or not character then
		return baseAnim
	end
	local now = os.clock()
	local item = character:GetAttribute("HeldItem")
	local st = itemChain[character]
	if not st or st.item ~= item or now - st.last > (Data.ItemChainReset or 1.2) then
		st = { n = 0, last = now, item = item }
		itemChain[character] = st
	end
	st.n += 1
	st.last = now
	return list[((st.n - 1) % #list) + 1]
end

function M1Style.info(animName: string?)
	if type(animName) ~= "string" then
		return nil
	end
	local m = Data.Moves[animName]
	if m then
		return m, false, animName
	end
	local base = string.match(animName, "^(.+)_L$")
	m = base and Data.Moves[base]
	if m then
		return m, true, base
	end
	return nil
end

return M1Style
