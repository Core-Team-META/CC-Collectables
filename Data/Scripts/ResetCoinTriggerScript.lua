local trigger = script.parent

trigger.interactedEvent:Connect(function(trigger, other)
	print("Resetting coins!")
	Events.Broadcast("ResetCollectables")
end)