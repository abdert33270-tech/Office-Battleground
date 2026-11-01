--[[
	Signals — bus d'événements serveur entre services (passage par référence, pas de copie).
	N'importe quel nom peut être utilisé : Signals.X:Connect(fn) / Signals.X:Fire(...)

	Signaux standards :
		Died(victim: Model, killer: Model?, weapon: string?, cause: "Combat"|"Event"|"Fall")
		Hit(attacker: Model?, victim: Model, damage: number, info: {weapon, category, combo, finisher})
		CharacterSpawned(character: Model, player: Player?)
		FloorChanged(floorNumber: number, floorName: string, floorModel: Model)
		CollapseWarning(floorNumber: number)
		SurvivedCollapse(character: Model)
		EventStarted(name: string) / EventEnded(name: string)
		Transformed(character: Model, characterName: string)
		Parried(defender: Model, attacker: Model)
		ItemPickedUp(character: Model, itemId: string) / ItemBroken(itemId: string)
		Blocked(attacker: Model?, victim: Model) — coup bloqué sans casser la garde (CombatService, branche "Blocked")
]]
local function newSignal()
	local s = { _c = {} }
	function s:Connect(fn)
		table.insert(self._c, fn)
		return {
			Disconnect = function()
				local i = table.find(self._c, fn)
				if i then
					table.remove(self._c, i)
				end
			end,
		}
	end
	function s:Fire(...)
		for _, fn in ipairs(self._c) do
			task.spawn(fn, ...)
		end
	end
	return s
end

return setmetatable({}, {
	__index = function(t, k)
		local s = newSignal()
		rawset(t, k, s)
		return s
	end,
})
