--[[
	Basic script for making the coins spin continuously.
]]

local propRoot = script:GetCustomProperty("root"):WaitForObject()

propRoot:RotateContinuous(Rotation.New(0, 0, 120))