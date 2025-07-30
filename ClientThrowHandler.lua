local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')

local Player = Players.LocalPlayer

local module = {}

function module.Start(tool)
	local character = Player.Character or Player.CharacterAdded:Wait()
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local throwEvent = tool:WaitForChild("RequestThrow")

	local db = false

	local function throwKnife()
		if db then return end
		db = true

		local targetPoint = humanoid.TargetPoint
		throwEvent:FireServer(targetPoint)

		-- Client-side visual knife
		local handle = tool:FindFirstChild("Handle")
		if not handle then return end

		local throwingHandle = handle:Clone()
		task.delay(0.1, function()
			if handle then
				handle.Transparency = 1
				task.wait(0.9)
				if handle then
					handle.Transparency = 0
				end
			end
		end)
		task.delay(1.5, function()
			db = false
		end)

		throwingHandle.Name = "ClientKnife"
		throwingHandle.CanCollide = false
		throwingHandle.Anchored = false
		throwingHandle.Parent = game.Workspace:FindFirstChild("thrownKnives") or game.Workspace
		throwingHandle.CFrame = CFrame.lookAt(handle.Position, targetPoint)

		-- Client-side Physics
		local floatingForce = Instance.new('BodyForce', throwingHandle)
		floatingForce.force = Vector3.new(0, workspace.Gravity * throwingHandle:GetMass(), 0)

		local spin = Instance.new('BodyAngularVelocity', throwingHandle)
		spin.angularvelocity = throwingHandle.CFrame:VectorToWorldSpace(Vector3.new(-10, 0, 0))

		local direction = (targetPoint - throwingHandle.Position).Unit
		throwingHandle.AssemblyLinearVelocity = direction * 72.5

		-- Client-side Raycasting and Sticking
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {character, throwingHandle, handle}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local heartbeatConnection
		heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
			if not throwingHandle or not throwingHandle.Parent then
				heartbeatConnection:Disconnect()
				return
			end

			local velocity = throwingHandle.AssemblyLinearVelocity
			local rayLength = velocity.Magnitude * dt
			if rayLength < 0.1 then return end

			local hitRay
			for _, point in ipairs(throwingHandle:GetChildren()) do
				if point:IsA("Attachment") and point.Name == "DmgPoint" then
					local origin = point.WorldPosition
					local ray = workspace:Raycast(origin, velocity.Unit * rayLength, raycastParams)
					if ray then
						hitRay = ray
						break
					end
				end
			end

			if hitRay then
				if floatingForce and floatingForce.Parent then floatingForce:Destroy() end
				if spin and spin.Parent then spin:Destroy() end

				throwingHandle.AssemblyLinearVelocity = Vector3.zero
				throwingHandle.AssemblyAngularVelocity = Vector3.zero
				throwingHandle.CanTouch = false

				local hitPart = hitRay.Instance
				if hitPart and hitPart.Parent then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = throwingHandle
					weld.Part1 = hitPart
					weld.Parent = throwingHandle
				end

				heartbeatConnection:Disconnect()
			end
		end)
		
		while task.wait() do
			-- Hide server knife from the thrower
			for _, v in ipairs(game.Workspace.thrownKnives:GetChildren()) do
				if (v.Name == `ServerKnife_{Player.UserId}`) then
					v.LocalTransparencyModifier = 1
				end
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then return end

		if (input.KeyCode == Enum.KeyCode.E) then
			throwKnife()
		end
	end)
end

return module
