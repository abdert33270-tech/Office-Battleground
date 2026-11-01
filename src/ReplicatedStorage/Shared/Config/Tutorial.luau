--[[
	Tutorial — premier match guidé (TutorialService côté serveur, TutorialController côté client).
	Liste d'étapes NON bloquante (en haut au centre). Les étapes requises se font dans l'ordre ;
	l'étape optionnelle (Daily) peut être cochée à tout moment. Le serveur valide chaque étape et sauvegarde
	data.Tutorial = { Done = bool, Steps = {[id] = compte}, Skipped = bool? }.
	Récompense (une seule fois, à la fin des étapes requises) : Reward.Cash + Reward.Crates Mystery Briefcase.
	Texte : Text[device] avec device = "KBM" | "Touch" | "Gamepad" (repli : KBM).
]]
local Tutorial = {
	Reward = { Cash = 500, Crates = 1 },
	BlockHoldTime = 1.2, -- bloquer (F maintenu) pendant ce temps valide l'étape même sans adversaire
	ThrowWindow = 1.5, -- l'objet doit quitter la main en vol dans ce délai après un lancer
	Steps = {
		{
			Id = "HitDummy",
			Title = "HIT THE DUMMY",
			Goal = 5,
			Target = "Dummy",
			Text = { KBM = "CLICK x5 on the Coworker dummy", Touch = "Tap HIT x5 near the dummy", Gamepad = "R2 x5 on the dummy" },
		},
		{
			Id = "Block",
			Title = "BLOCK",
			Goal = 1,
			Target = "Block",
			Text = { KBM = "Hold F to block (or block a real hit)", Touch = "Hold BLOCK (or block a real hit)", Gamepad = "Hold L2 to block" },
		},
		{
			Id = "Dash",
			Title = "DASH",
			Goal = 1,
			Target = "Dash",
			Text = { KBM = "Press Q (+ WASD for direction)", Touch = "Tap DASH", Gamepad = "Press B to dash" },
		},
		{
			Id = "Ability",
			Title = "USE ABILITY 1",
			Goal = 1,
			Target = "Ability1",
			Text = { KBM = "Press 1", Touch = "Tap the 1 button", Gamepad = "Press 1 on a keyboard or tap the 1 slot" },
		},
		{
			Id = "Throw",
			Title = "PICK UP & THROW",
			Goal = 1,
			Target = "Item",
			Text = { KBM = "E near an item, then R to throw", Touch = "PICK UP an item, then THROW", Gamepad = "X to pick up, Y to throw" },
		},
		{
			Id = "Daily",
			Title = "OPEN DAILY",
			Goal = 1,
			Optional = true,
			Target = "Daily",
			Text = { KBM = "Optional: open DAILY (free reward)", Touch = "Optional: open DAILY (free reward)", Gamepad = "Optional: open DAILY" },
		},
	},
}

Tutorial.ById = {}
for i, s in ipairs(Tutorial.Steps) do
	s.Index = i
	Tutorial.ById[s.Id] = s
end

return Tutorial
