-- Copyright (c) 2014, Jeffrey Clark. This file is licensed under the
-- Affero General Public License version 3 or later. See the COPYRIGHT file.

include("support.lua")

database = getDatabase()
server = getServer()
motd = { time=0, message=nil }
motd_timer = nil
welcome_message = nil

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
    showWelcome(event.player);
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
    event.prefix = timePrefix{text=decoratePlayerName(event.player)}
    print(timePrefix{text=event.player:getPlayerName()..": " .. event.text})
end

function onPlayerCommand(event)
    print(timePrefix{text=event.player:getPlayerName() .. ": "..event.command})

    if string.sub(event.command,1,1) == "/" then
        local cmd = explode(" ", event.command, 2)
        cmd[1] = string.lower(cmd[1])
    
        if cmd[1] == "/help" then
            if event.player:isAdmin() then
                event.player:sendTextMessage("[#00FFCC]/setWelcome [#00CC88]<message>");
                event.player:sendTextMessage("[#00FFCC]/setMotd [#00CC88]<message>");
                event.player:sendTextMessage("[#00FFCC]/yell [#00CC88]<message>");
            end
            event.player:sendTextMessage("[#00FFCC]/whisper [#00CC88]<player> <message>");
        elseif cmd[1] == "/setmotd" then
            if not event.player:isAdmin() then return msgAccessDenied(event.player) end
            if not cmd[2] then return msgInvalidUsage(event.player) end
            setMotd(cmd[2])
            event.player:sendTextMessage("[#00FFCC]motd set");
        elseif cmd[1] == "/setwelcome" then
            if not event.player:isAdmin() then return msgAccessDenied(event.player) end
            if not cmd[2] then return msgInvalidUsage(event.player) end
            setWelcome(cmd[2])
            event.player:sendTextMessage("[#00FFCC]welcome set");
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
    
            local toPlayer = server:findPlayerByName(args[1])
            if not toPlayer then return msgPlayerNotFound(event.player) end
    
            toPlayer:sendTextMessage(timePrefix{text="[#FFFF00](whisper) "..decoratePlayerName(event.player)..": "..args[2]});
        end
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
    server:brodcastTextMessage(timePrefix{text="[#FFA500]** "..decoratePlayerName(player).." - "..msg})
end

function sendMessage(msg, player)
    player:sendTextMessage(timePrefix{text="[#FF0000]"..msg})
end

function setWelcome(msg)
    database:queryupdate("INSERT OR REPLACE INTO settings (`key`, `value`) VALUES ('welcome', '"..msg.."');");
end

function showWelcome(player)
    result = database:query("SELECT * FROM `settings` WHERE `key` = 'welcome';")
    if result:next() then
        player:sendTextMessage(timePrefix{text="[#FFA500]** ".. result:getString("value")})
    end
end

function setMotd(msg)
    database:queryupdate("INSERT INTO motd (time, message) VALUES ("..os.time()..", '"..msg.."');");
end

function showMotd()
    result = database:query("SELECT * FROM motd ORDER BY time DESC LIMIT 1;")
    if result:next() then
        motd.time = result:getInt("time")
        motd.message = result:getString("message")
    end

    if motd.time > 0 then
        server:brodcastTextMessage(timePrefix{time=motd.time, text="[#FFA500]** ".. motd.message})
    end
end

function timePrefix(opts)
    if not type(opts.time) ~= "number" then
        opts.time = os.time()
    end
    return os.date("%x %X", opts.time) .." ".. opts.text
end

addEvent("PlayerSpawn", onPlayerSpawn);
addEvent("PlayerConnect", onPlayerConnect);
addEvent("PlayerDisconnect", onPlayerDisconnect);
addEvent("PlayerDeath", onPlayerDeath);
addEvent("PlayerText", onPlayerText);
addEvent("PlayerCommand", onPlayerCommand);

function onEnable()
    print(timePrefix{text="Loaded"});

    database:queryupdate("CREATE TABLE IF NOT EXISTS `motd` (`ID` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `time` INTEGER, `message` VARCHAR);");
    database:queryupdate("CREATE TABLE IF NOT EXISTS `settings` (`key` PRIMARY KEY NOT NULL, `value` VARCHAR);");

    -- Broadcast motd every 60 minutes
    motd_timer = setTimer(function() showMotd(); end, 3600, -1);
end