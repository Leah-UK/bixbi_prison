ESX = nil
TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)

-- ESX.RegisterCommand('prison', 'superadmin', function(xPlayer, args, showError)
-- 	local xTarget = ESX.GetPlayerFromId(args.target)
-- 	TriggerEvent('bixbi_prison:JailPlayer', xPlayer.playerId, xTarget.playerId, args.time, args.reason)
-- end, true, {help = 'Send player to prison.', validate = false, arguments = {
-- 	{name = 'target', help = 'Player ID', type = 'number'},
--     {name = 'time', help = 'In Minutes (RP: Months)', type = 'number'},
-- 	{name = 'reason', help = 'Reason for the Sentence', type = 'string'}
-- }})

ESX.RegisterCommand('unprison', 'admin', function(xPlayer, args, showError)
	TriggerEvent('bixbi_prison:UnJailPlayer', args.target, true, xPlayer.playerId)

	local xTarget = ESX.GetPlayerFromId(args.target)
	SendDiscordLog("\n\nIndividual: **" .. xTarget.name .. "**\n\n*Released by Government*", Config.DiscordURL2)
	-- TriggerEvent('bixbi_logging:customLog', 'HM Prison Service', 16711680, Config.DiscordURL2, '**' .. xTarget.name .. '** [' .. xTarget.playerId .. '] was released from prison by **' .. xPlayer.name .. '** [' .. xPlayer.playerId .. '] - *ADMIN COMMAND*.')
end, true, {help = 'Release player from prison.', validate = false, arguments = {
	{name = 'target', help = 'Player ID', type = 'any'}
}})

local _ArrestedPlayers = {}
ESX.RegisterServerCallback('bixbi_prison:ReturnPrisoners', function(source, cb)
	cb(_ArrestedPlayers)
end)

RegisterServerEvent('bixbi_prison:JailPlayer')
AddEventHandler('bixbi_prison:JailPlayer', function(source, targetId, timeInput, reason)
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(targetId)
	
	if (xPlayer == nil or xTarget == nil) then return end
	if (xPlayer.job.name ~= 'police') then return end
	if (xTarget.job.name == 'police' or xTarget.job.name == 'ambulance') then
		TriggerClientEvent('bixbi_core:Notify', xPlayer.playerId, 'error', 'You cannot jail this person.')
		return
	end

	if (_ArrestedPlayers[xTarget.playerId] == nil or _ArrestedPlayers[xTarget.playerId] == false) then
		local time = tonumber(timeInput)
		local newJail = {time = time, reason = reason, officer = xPlayer.name}
		exports.oxmysql:execute('UPDATE users SET bixbi_prison = @bixbi_prison WHERE identifier = @identifier', {		
			['@identifier'] = xTarget.identifier,
			['@bixbi_prison'] = json.encode(newJail)
		})

		_ArrestedPlayers[xTarget.playerId] = {pid = xTarget.playerId, time = time, identifier = xTarget.identifier, reason = reason, officer = xPlayer.name, prisoner = xTarget.name}
		-- table.insert(_ArrestedPlayers, _ArrestedPlayers[xTarget.playerId] = {time = time, identifier = xTarget.identifier, reason = reason, officer = xPlayer.name, prisoner = xTarget.name})
		TriggerClientEvent('bixbi_prison:SendToPrison', xTarget.playerId, {time = time, reason = reason, officer = xPlayer.name})

		local chatMessage = ' ' .. xTarget.name .. " | " .. time .. " months | " .. reason .. ' - [' .. xPlayer.job.grade_label .. '] ' .. xPlayer.name
		for _, v in pairs(ESX.GetExtendedPlayers('job', 'police')) do
			TriggerClientEvent('chatMessage', v.playerId, Config.PrisonTag, { 255, 0, 0 }, chatMessage)
		end
		
		SendDiscordLog("\n\nIndividual: **" .. xTarget.name .. "**\nOfficer: **" .. xPlayer.name .. "**\n\n**Reason:** " .. reason .. "\nLength: **" .. time .. "** month(s)", Config.DiscordURL)

		if (Config.OxInventory) then
			-- TriggerEvent('ox_inventory:clearPlayerInventory', xTarget)
            exports.ox_inventory:ClearInventory(xTarget.playerId)
			for k, v in pairs(Config.Items) do
				if (k == 'identification') then
					xTarget.triggerEvent('qidentification:GiveLicense', k)
				else
					exports.bixbi_core:addItem(targetId, k, v)
				end
			end
		end
	else
		TriggerClientEvent('bixbi_core:Notify', xPlayer.playerId, 'error', 'This player is already in prison')
	end
end)

RegisterServerEvent('bixbi_prison:UnJailPlayer')
AddEventHandler('bixbi_prison:UnJailPlayer', function(targetId, automatic, src)
    if (src == nil) then src = source end
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(targetId)
	if ((xPlayer == nil and not automatic) or xTarget == nil) then return end

	if (_ArrestedPlayers[xTarget.playerId] ~= nil and _ArrestedPlayers[xTarget.playerId] ~= false) then
		_ArrestedPlayers[xTarget.playerId].time = 0
		TriggerClientEvent('bixbi_prison:ReleaseFromPrison', xTarget.playerId)

		if (xPlayer ~= nil and xPlayer.job.name ~= 'police' and not automatic) then 
			TriggerClientEvent('chatMessage', -1, Config.PrisonTag, { 255, 0, 0 }, ' ' .. xTarget.name .. ' has broken out of prison, and is now a wanted suspect!') 
			TriggerEvent('bixbi_dispatch:Add', 0, 'police', 'prisonbreak', xTarget.name .. ' has broken out of prison.')
            SendDiscordLog('**' .. xTarget.name .. '** [' .. xTarget.playerId .. '] was **illegally** released from prison by **' .. xPlayer.name .. '** [' .. xPlayer.playerId .. ']', Config.DiscordURL2)
		elseif (xPlayer ~= nil and xPlayer.job.name == 'police' and not automatic) then
            SendDiscordLog('**' .. xTarget.name .. '** [' .. xTarget.playerId .. '] was **legally** released from prison by **' .. xPlayer.name .. '** [' .. xPlayer.playerId .. ']', Config.DiscordURL2)
		end
		_ArrestedPlayers[xTarget.playerId] = false

		TriggerClientEvent('bixbi_core:Notify', xTarget.playerId, 'success', 'You have been released from prison', 10000)
		if (xPlayer ~= nil) then TriggerClientEvent('bixbi_core:Notify', xPlayer.playerId, '', 'You have released ' .. xTarget.name .. ' from prison', 10000) end

		exports.oxmysql:execute('UPDATE users SET bixbi_prison = @bixbi_prison WHERE identifier = @identifier', {		
			['@identifier'] = xTarget.identifier,
			['@bixbi_prison'] = '{"time":0,"reason":"","officer":""}'
		})
	else
		TriggerClientEvent('bixbi_core:Notify', xPlayer.playerId, 'error', 'This player isn\'t in prison')
	end
end)

RegisterServerEvent('bixbi_prison:ServerPrisonerInfo')
AddEventHandler('bixbi_prison:ServerPrisonerInfo', function()
	if (_ArrestedPlayers[source] ~= nil and _ArrestedPlayers[source] ~= false) then
		local info = _ArrestedPlayers[source]
		TriggerClientEvent('bixbi_core:Notify', source, 'error', 'You have: ' .. info.time .. ' month(s) left in prison', 10000)
		TriggerClientEvent('bixbi_core:Notify', source, 'error', 'Reason for Imprisonment: ' .. info.reason)
		TriggerClientEvent('bixbi_core:Notify', source, '', 'Arresting Officer: ' .. info.officer)
	else
		TriggerClientEvent('bixbi_core:Notify', source, 'error', 'You are not in prison')
	end
end)

AddEventHandler('esx:playerLoaded', function(source, xPlayer)
	Citizen.Wait(5000)
	exports.oxmysql:scalar('SELECT bixbi_prison FROM users WHERE identifier = ?', { xPlayer.identifier }, 
	function(result)
		local info = json.decode(result)
		if (info.time > 0) then
			TriggerClientEvent('bixbi_prison:SendToPrison', xPlayer.playerId, {time = info.time, reason = info.reason, officer = info.officer})
			_ArrestedPlayers[xPlayer.playerId] = {pid = xPlayer.playerId, time = tonumber(info.time), identifier = xPlayer.getIdentifier(), reason = info.reason, officer = info.officer, prisoner = xPlayer.name}
			-- table.insert(_ArrestedPlayers, _ArrestedPlayers[xPlayer.playerId])
		end
	end)
end)

Citizen.CreateThread(function()
	while true do
		if (_ArrestedPlayers ~= nil and #_ArrestedPlayers > 0) then
			for _, prisoner in pairs(_ArrestedPlayers) do
				if (prisoner ~= nil and prisoner ~= false) then
					prisoner.time = prisoner.time - 1
					if (prisoner.time < 0) then prisoner.time = 0 end
					local UpdateInfo = {time = prisoner.time, reason = prisoner.reason, officer = prisoner.officer}

					exports.oxmysql:execute('UPDATE users SET bixbi_prison = @bixbi_prison WHERE identifier = @identifier', {		
						['@identifier'] = prisoner.identifier,
						['@bixbi_prison'] = json.encode(UpdateInfo)
					})

					if (prisoner.time < 1) then
						TriggerEvent('bixbi_prison:UnJailPlayer', prisoner.pid, true) 
                    else
						local xPlayer = ESX.GetPlayerFromId(prisoner.pid)
						local coords = xPlayer.getCoords(true)
						local distance = #(coords - Config.PrisonLocation)
						TriggerClientEvent('bixbi_prison:DistanceCheck', prisoner.pid, distance)
					end
				end
			end
			Citizen.Wait(1 * 60000)
		else
			Citizen.Wait(2 * 60000) -- A bit longer for performance reasons. No point checking every minute if the prison is empty.
		end
	end
end)

function SendDiscordLog(message, discordURL)
    if (discordURL == nil or discordURL == "" or message == "") then return end
    local embeds = {
        {
            ["title"]= Config.PrisonName,
            ["description"]= message,
            ["type"]= "rich",
            ["color"] = 16711680,
        }
    }
    PerformHttpRequest(discordURL, function(err, text, headers) end, 'POST', json.encode({ username = Config.PrisonName, embeds = embeds}), { ['Content-Type'] = 'application/json' })
end

AddEventHandler('esx:playerDropped', function(playerId, reason)
	_ArrestedPlayers[playerId] = false
end)

AddEventHandler('onResourceStart', function(resourceName)
	if (GetResourceState('bixbi_core') ~= 'started' ) then
        print('Bixbi_Prison - ERROR: Bixbi_Core hasn\'t been found! This could cause errors!')
    end
end)