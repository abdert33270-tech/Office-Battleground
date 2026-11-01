--[[
	Levels — niveau numérique 1..100 calculé depuis l'XP totale (la même que les grades de carrière).
	XP pour passer du niveau L à L+1 : need(L) = 40 + 12 * L (courbe douce).
	Récompense en Cash à chaque niveau atteint : reward(L) = 100 + 20 * L.
	Les niveaux ne donnent JAMAIS de puissance (titre + Cash seulement).
	API : Levels.need(L) | Levels.total(L) (XP totale pour atteindre L) | Levels.levelFor(xp) -> level, into, need
	      Levels.reward(L)
]]
local Levels = {}

Levels.Max = 100

function Levels.need(L)
	return 40 + 12 * L
end

function Levels.reward(L)
	return 100 + 20 * L
end

-- XP totale pour atteindre chaque niveau (précalculée)
local totals = { [1] = 0 }
for L = 2, Levels.Max do
	totals[L] = totals[L - 1] + Levels.need(L - 1)
end

function Levels.total(L)
	L = math.clamp(math.floor(tonumber(L) or 1), 1, Levels.Max)
	return totals[L]
end

-- niveau pour une XP totale -> level, XP déjà faite dans ce niveau, XP nécessaire pour le suivant (0 au max)
function Levels.levelFor(xp)
	xp = math.max(0, tonumber(xp) or 0)
	local lo, hi = 1, Levels.Max
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if totals[mid] <= xp then
			lo = mid
		else
			hi = mid - 1
		end
	end
	if lo >= Levels.Max then
		return Levels.Max, xp - totals[Levels.Max], 0
	end
	return lo, xp - totals[lo], Levels.need(lo)
end

return Levels
