--[[
	DailyRewards — calendrier de connexion sur 7 jours (DailyRewardService / DailyRewardController).
	- Une récompense par jour UTC (os.time() // 86400 côté serveur).
	- Série perdue si plus de GraceHours depuis la dernière réclamation : on repart du jour 1.
	- Après le jour 7 : nouveau cycle (jour 1), mêmes montants.
	Crates = Mystery Briefcases gratuites (SkinService.addCrates).
	Repères économie : perso 1 500-5 000 Cash, niveau = 100 + 20 x niveau, Briefcase = 300 Cash.
]]
return {
	GraceHours = 48,
	Days = {
		{ Cash = 100 },
		{ Cash = 150 },
		{ Cash = 200 },
		{ Cash = 300 },
		{ Cash = 400 },
		{ Cash = 500 },
		{ Cash = 1000, Crates = 2, Big = true }, -- jour 7 : gros lot
	},
}
