--[[
	Announce — annonces serveur -> clients (affichées par le HUD client).
	Announce.banner(text, sub?, color?, duration?, style?)  grosse bannière cartoon en haut (style: "Event"|"Floor"|"Overtime"|"Big")
	Announce.killfeed(entry)   entry = {killer=string?, victim=string, weapon=string?, kind="Fired"|"Resigned"|"HR"|"Streak"}
	Announce.toast(player, text, color?)   petit message pour un seul joueur (conseils, XP, tâches)
]]
local Net = require(game.ReplicatedStorage.Shared.Modules.Net)

local Announce = {}

function Announce.banner(text: string, sub: string?, color: Color3?, duration: number?, style: string?)
	Net.get("Banner"):FireAllClients({ text = text, sub = sub, color = color, duration = duration or 3, style = style or "Event" })
end

function Announce.killfeed(entry)
	Net.get("KillFeed"):FireAllClients(entry)
end

function Announce.toast(player: Player, text: string, color: Color3?)
	Net.get("Toast"):FireClient(player, { text = text, color = color })
end

return Announce
