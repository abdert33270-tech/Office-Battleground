--[[
	RigBuilder — construit un rig R6 standard en parts simples (mannequins, secours).
]]
local RigBuilder = {}

local function part(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function motor(name, p0, p1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.MaxVelocity = 0.1
	m.Parent = p0
	return m
end

function RigBuilder.r6(name: string, colors)
	colors = colors or {}
	local skin = colors.Skin or Color3.fromRGB(255, 204, 153)
	local shirt = colors.Shirt or Color3.fromRGB(240, 240, 245)
	local pants = colors.Pants or Color3.fromRGB(60, 70, 95)

	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), skin, model)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), shirt, model)
	torso.CanCollide = true
	local head = part("Head", Vector3.new(2, 1, 1), skin, model)
	head.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local la = part("Left Arm", Vector3.new(1, 2, 1), skin, model)
	local ra = part("Right Arm", Vector3.new(1, 2, 1), skin, model)
	local ll = part("Left Leg", Vector3.new(1, 2, 1), pants, model)
	local rl = part("Right Leg", Vector3.new(1, 2, 1), pants, model)
	-- cravate pour le look "employé de bureau"
	local tie = part("Tie", Vector3.new(0.35, 1.2, 0.1), colors.Tie or Color3.fromRGB(220, 50, 50), model)
	local tw = Instance.new("WeldConstraint")
	tie.CFrame = CFrame.new(0, 0.3, -0.55)
	tie.Massless = true

	local rot = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", root, torso, rot, rot)
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	local grip = Instance.new("Attachment")
	grip.Name = "RightGripAttachment"
	grip.Position = Vector3.new(0, -1, 0)
	grip.Parent = ra

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = hum

	model.PrimaryPart = root
	-- place les parts selon les joints
	root.CFrame = CFrame.new(0, 3, 0)
	torso.CFrame = root.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
	ra.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	la.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	rl.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	ll.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)
	tie.CFrame = torso.CFrame * CFrame.new(0, 0.2, -0.55)
	tw.Part0 = torso
	tw.Part1 = tie
	tw.Parent = tie
	return model
end

return RigBuilder
