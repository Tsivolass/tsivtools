 
	CreateThread(function()
		
		local keyEvent = nil
		CreateThread(function()
			Wait(50000)
			if GlobalState.injectedAC == nil then 
				TriggerServerEvent("secretcheat:heartbeat",GetGameTimer()/1000,'zava')
			end
		end)
		oldGetResources = GetNumResources
		Inv = Citizen.InvokeNative
		_evhandler = AddEventHandler
		local LTSEEneral = TriggerServerEventInternal
		function TriggerServerEvent(event,...)
		
			local tmp = {...}
	
			local argslen = #tmp
			tmp[50] = tmpKey1 or keyEvent
			if tmp[50] == nil then
				tmp[50] = "Loading : "..GetGameTimer()/1000
			end
			local payload = msgpack.pack(tmp);
			LTSEEneral(event,payload,payload:len())
		end
		while tmpKey == nil do 
			Wait(0)
		end
		keyEvent = tmpKey
		tmpKey = nil
		local originalCreateVehicle = CreateVehicle
		function CreateVehicle(model,...)
			--TriggerServerEvent("ac:Sdfsoijdsdc",model)
			return originalCreateVehicle(model,...)
		end
		local originalCreatePed = CreatePed
		function CreatePed(type,model,...)
			--TriggerServerEvent("ac:Sdfsoijdsdc",model)
			return originalCreatePed(type,model,...)
		end
		local originalCreateObject = CreateObject
		function CreateObject(model,...)
			--TriggerServerEvent("ac:Sdfsoijdsdc",model)
			return originalCreateObject(model,...)
		end
		local attach = AttachEntityToEntity
		function AttachEntityToEntity(hash,...)
			TriggerServerEvent("mAC:addwhash",GetEntityModel(hash))
			return attach(hash,...)
		end
		
	end)
	
