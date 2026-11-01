--[[
	ContentLoader — charge les modules de ReplicatedStorage.Shared.Content (un module = un personnage complet).
	Format d'un module de contenu (toutes les clés sont optionnelles sauf Id et Character) :
	return {
		Id = "ITGuy", Order = 5,
		Character = { ... fiche comme dans Config/Characters ... },
		Attacks = { MoveId = { ... fiche comme dans Config/Attacks ... }, ... },
		Anims = { AnimName = { keyframes ProcAnim }, ... },
		Props = { PropName = { { taille, décalage (repère bras droit), couleur, forme? }, ... } },  -- accessoires de main (client)
		MoveFX = { MoveId = function(character, data, api) ... end },  -- effets client (api : part, afterimages, trail, rings, CartoonFX, TweenService, Debris, rng)
		Identity = function(folder, head, torso, character, prop) end,   -- accessoires permanents (serveur)
		Signature = { Hand = "Right"|"Left", Build = function(folder, armPart, prop) end }, -- arme fétiche (serveur)
		Transform = function(folder, head, torso, character, prop) end,  -- accessoires de transformation (serveur)
		Kinds = { KindName = function(attacker, cfg, aim, api) end }, -- nouveaux comportements d'attaque (serveur, api d'AbilityService)
		ServerInit = function(api) end,  -- passif côté serveur (api : CombatService, CharacterState, Signals, ZoneService, Net, getItemService)
		ClientInit = function(api) end,  -- passif côté client (api : CartoonFX, ProcAnim, Hitbox, player)
	}
]]
local ContentLoader = {}
local cache

function ContentLoader.all()
	if cache then
		return cache
	end
	cache = {}
	local folder = script.Parent.Parent:FindFirstChild("Content")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("ModuleScript") then
				local ok, def = pcall(require, m)
				if ok and type(def) == "table" and def.Id then
					table.insert(cache, def)
				else
					warn("[ContentLoader] module invalide :", m.Name, def)
				end
			end
		end
	end
	table.sort(cache, function(a, b)
		return (a.Order or 99) < (b.Order or 99)
	end)
	return cache
end

-- fusionne def[key] (table) dans target
function ContentLoader.merge(target, key)
	for _, def in ipairs(ContentLoader.all()) do
		if type(def[key]) == "table" then
			for k, v in pairs(def[key]) do
				target[k] = v
			end
		end
	end
	return target
end

return ContentLoader
