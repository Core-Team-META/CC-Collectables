--[[

local propTrigger = script:GetCustomProperty("Trigger"):WaitForObject()
local propGeometry = script:GetCustomProperty("Geometry"):WaitForObject()

local root = script.parent

local collisionEventName = "COLLIDE:" .. script.parent.id


function OnOverlap()
	Events.Broadcast(collisionEventName, script.parent.id)
end





propTrigger.interactedEvent:Connect(OnInteract)
propTrigger.beginOverlapEvent:Connect(BeginOverlap)
]]