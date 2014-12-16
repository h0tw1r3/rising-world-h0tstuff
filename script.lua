-- Copyright (c) 2014, Jeffrey Clark. This file is licensed under the
-- Affero General Public License version 3 or later. See the COPYRIGHT file.

include("support.lua")

server = getServer()

-- Didn't use the builtin yell api because it's not customizable
yellLabel = Gui:createLabel("", 0.99, 0.99);
yellLabel:setFontColor(0xCCFF00FF);
yellLabel:setBorderColor(0xFF000088);
yellLabel:setBorderThickness(4);
yellLabel:setFontsize(30);
yellLabel:setPivot(4);

function onPlayerSpawn(event)
    event.player:addGuiElement(yellLabel)
    broadcastPlayerStatus(event.player, " joined the world")
end

function onPlayerConnect(event)
    broadcastPlayerStatus(event.player, " is connecting")
end

function onPlayerDisconnect(event)
    event.player:removeGuiElement(yellLabel);
    broadcastPlayerStatus(event.player, " disconnected")
end

function onPlayerDeath(event)
    broadcastPlayerStatus(event.player, " is dead")
end

function onPlayerText(event)
    event.prefix = decoratePlayerName(event.player)
    print(event.player:getPlayerName()..": " .. event.text)
end

function onPlayerCommand(event)
    print(event.player:getPlayerName() .. ": "..event.command)

    local cmd = explode(" ", event.command, 2)

    if cmd[1] == "/help" then
        event.player:sendTextMessage("[#00FFCC]/yell [#00CC88]<message>");
        event.player:sendTextMessage("[#00FFCC]/whisper [#00CC88]<player> <message>");
    elseif cmd[1] == "/yell" then
        if not event.player:isAdmin() then return msgAccessDenied(event.player) end
        if not cmd[2] then return msgInvalidUsage(event.player) end

        yellLabel:setText(" "..event.player:getPlayerName()..": "..cmd[2].." ");
        yellLabel:setX(0.5);
        yellLabel:setY(0.3);
        yellLabel:setVisible(true)
        setTimer(function()
                yellLabel:setVisible(false);
        end, 5, 1);
    elseif cmd[1] == "/whisper" then
        if not cmd[2] then return msgInvalidUsage(event.player) end
        local args = explode(" ", cmd[2], 2)
        if not args[2] then return msgInvalidUsage(event.player) end

	--local toPlayer = server:findPlayerByName(args[1])
	local toPlayer =server:findPlayerByName(args[1])
	if not toPlayer then return msgPlayerNotFound(event.player) end

	toPlayer:sendTextMessage("[#FFFF00](whisper) "..decoratePlayerName(event.player)..": "..args[2]);
    end
end

function decoratePlayerName(player)
    local str = "[#CCCCCC]"..player:getPlayerName()
    if player:isAdmin() then
        str = str.."[#FF0000] (admin)"
    end

    return str.."[#FFFFFF]"
end

function msgInvalidUsage(player)
    sendMessage("Invalid command usage.", player)
end

function msgAccessDenied(player)
    sendMessage("Access denied.", player)
end

function msgPlayerNotFound(player)
    sendMessage("Player not found.", player)
end

function broadcastPlayerStatus(player, msg)
    server:brodcastTextMessage("[#FFA500]** "..decoratePlayerName(player).." - "..msg)
end

function sendMessage(msg, player)
    player:sendTextMessage("[#FF0000]"..msg)
end

addEvent("PlayerSpawn", onPlayerSpawn);
addEvent("PlayerConnect", onPlayerConnect);
addEvent("PlayerDisconnect", onPlayerDisconnect);
addEvent("PlayerDeath", onPlayerDeath);
addEvent("PlayerText", onPlayerText);
addEvent("PlayerCommand", onPlayerCommand);

function onEnable()
    print("Loaded");
end
