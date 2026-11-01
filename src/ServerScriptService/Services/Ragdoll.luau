--[[
	Ragdoll — ragdoll R6 au coup final + éjection cartoon en tournoyant.
]]
local Ragdoll = {}

local JOINTS = { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

function Ragdoll.apply(character: Model, launch: Vector3?)
	if character:GetAttribute("Ragdolled") then
		return
	end
	character:SetAttribute("Ragdolled", true)
	local torso = character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not torso then
		return
	end
	for _, name in ipairs(JOINTS) do
		local m = torso:FindFirstChild(name)
		if m and m:IsA("Motor6D") and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = name == "Neck" and 45 or 90
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in ipairs(character:GetChildren()) do
		if p:IsA("BasePart") and p ~= root then
			p.CanCollide = true
		end
	end
	if root then
		local rj = root:FindFirstChild("RootJoint")
		if rj then
			rj:Destroy()
		end
		root.CanCollide = false
		root.Massless = true
		-- garde le root collé au torse (caméra qui suit)
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = root
		w.Parent = root
	end
	-- le serveur prend la physique pour une éjection fiable
	for _, p in ipairs(character:GetChildren()) do
		if p:IsA("BasePart") then
			pcall(function()
				p:SetNetworkOwner(nil)
			end)
		end
	end
	if launch then
		torso.AssemblyLinearVelocity = launch
		torso.AssemblyAngularVelocity = Vector3.new(math.random(-14, 14), math.random(-14, 14), math.random(-14, 14))
	end
end

return Ragdoll
