-- Copyright (c) 2014, Jeffrey Clark. This file is licensed under the
-- Affero General Public License version 3 or later. See the COPYRIGHT file.

include("support.lua")

database = getDatabase()
server = getServer()
motd = { time=0, message=nil }
motd_timer = nil
welcome_message = nil

playersOnline = {}

-- Didn't use the builtin yell api because it's not customizable
yellLabel = Gui:createLabel("", 0.99, 0.99);
yellLabel:setFontColor(0xCCFF00FF);
yellLabel:setBorderColor(0xFF000088);
yellLabel:setBorderThickness(4);
yellLabel:setFontsize(30);
yellLabel:setPivot(4);

function onPlayerSpawn(event)
    playersOnline[string.lower(event.player:getPlayerName())] = event.player:getPlayerID()
    event.player:addGuiElement(yellLabel)
    broadcastPlayerStatus(event.player, " joined the world")
    showWelcome(event.player);
    -- check for players that were offline when banned
    checkban(event.player)
end

function onPlayerConnect(event)
    lastlog('connect', event.player)
    broadcastPlayerStatus(event.player, " is connecting")
    -- I should be able to set value to event.player, but banning myself is throwing errors so no way to really test :(
    --- need a second account to really test this stuff.
end

function onPlayerDisconnect(event)
    lastlog('disconnect', event.player)
    -- TODO: compact the table
    playersOnline[string.lower(event.player:getPlayerName())] = nil
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
                event.player:sendTextMessage("[#00FFCC]/ban [#00CC88]<player> <duration in minutes, -1 is permenant> <reason>");
                event.player:sendTextMessage("[#00FFCC]/unban [#00CC88]<player>");
                event.player:sendTextMessage("[#00FFCC]/setWelcome [#00CC88]<message>");
                event.player:sendTextMessage("[#00FFCC]/setMotd [#00CC88]<message>");
                event.player:sendTextMessage("[#00FFCC]/yell [#00CC88]<message>");
            end
            event.player:sendTextMessage("[#00FFCC]/last [#00CC88][player]");
            event.player:sendTextMessage("[#00FFCC]/whisper [#00CC88]<player> <message>");
        elseif cmd[1] == "/ban" then
            if not event.player:isAdmin() then return msgAccessDenied(event.player) end
            if not cmd[2] then return msgInvalidUsage(event.player) end
            local args = explode(" ", cmd[2], 3)
	    if not args[1] or not args[2] or not args[3] then return msgInvalidUsage(event.player) end
	    ban(args[1], args[2], args[3], event.player)
	elseif cmd[1] == "/unban" then
            if not event.player:isAdmin() then return msgAccessDenied(event.player) end
            if not cmd[2] then return msgInvalidUsage(event.player) end
            unban(cmd[2], event.player)
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
        elseif cmd[1] == "/last" then
            if not cmd[2] then cmd[2] = nil end
	    sendTableMessage{player=event.player, messages=getLastText{name=cmd[2]}}
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

function sendTableMessage(opts)
    for i=1,#opts.messages do
        opts.player:sendTextMessage(opts.messages[i])
    end
end

function decoratePlayerName(player)
    local str = "[#CCCCCC]"
    if type(player) == "string" then
        str = str..player
    else
        str = str..player:getPlayerName()
        if player:isAdmin() then
            str = str.."[#FF0000] (admin)"
        end
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
    print(timePrefix{text="** ".. player:getPlayerName() .." - ".. msg})
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
    result:close()
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
    result:close()
end

function timePrefix(opts)
    if not type(opts.time) ~= "number" then
        opts.time = os.time()
    end
    return os.date("%x %X", opts.time) .." ".. opts.text
end

function getLastText(opts)
    local result = nil
    local last = Table.new()

    if not type(opts.name) ~= "string" then
        result = database:query("SELECT * FROM `lastlog` WHERE `disconnect_at` > -1 ORDER BY `id` DESC LIMIT 5")
    else
        result = database:query("SELECT * FROM `lastlog` WHERE `name` LIKE '".. opts.name .."' AND `disconnect_at` > -1 ORDER BY `id` DESC LIMIT 5;")
    end

    while result:next() do
        local offtime = result:getInt("disconnect_at")
	if offtime == 0 then
            offtime = "[#CC0000]Lost Connection"
        else
            offtime = os.date("%x %X", time)
	end
        last:insert("[#00FFCC]".. result:getString("name") .."[#00CC88] ".. os.date("%x %X", result:getInt("connect_at")) .." - ".. offtime)
    end
    result:close()

    return last
end

-- checked on join
function checkban(player)
    local result = database:query("SELECT * FROM `banlist` WHERE `playername` = '".. player:getPlayerName() .."' AND (`applied_at` < 0 OR (`applied_at` + `duration`) > ".. os.time() .." OR `duration` < 0) COLLATE NOCASE;")
    if result:next() then
	duration = (result:getInt("duration") / 60)
	reason = result:getString("reason")

        local message = " banned by ".. result:getString("admin")
        if duration > 0 then
            message = message .." for ".. duration .." minutes"
        else
            message = message .." permenantly"
        end
	message = message .." (".. reason ..")"
        broadcastPlayerStatus(player, message)
	if result:getInt("applied_at") < 0 then
	    database:queryupdate("UPDATE `banlist` SET `applied_at` = ".. os.time() .." WHERE `id` = ".. result:getString("id") ..";")
	end
        setTimer(function() player:ban(reason, duration); end, 1, 1);
    end
    result:close()
end

function unban(playername, adminPlayer)
    --- TODO: confirm player is banned
    database:queryupdate("DELETE FROM `banlist` WHERE `playername` = '".. playername .."' COLLATE NOCASE;")
    server:brodcastTextMessage(timePrefix{text="[#FF0000]** ".. decoratePlayerName(playername) .." ban removed by ".. decoratePlayerName(adminPlayer)})
end

function ban(playername, duration, reason, adminPlayer)
    --- Queue ban for next login attempt
    if duration == 0 then duration = 1 end
    database:queryupdate("INSERT INTO `banlist` (`playername`, `admin`, `serial`, `date`, `duration`, `reason`) VALUES ('".. playername .."', '".. adminPlayer:getPlayerName() .."', '', ".. os.time() ..", ".. (duration * 60) ..", '".. reason .."');")

    -- Ban immediately if online
    --- Don't use server:findPlayerByName because it's currently case sensitive
    local banPlayer = findOnlinePlayerByName(playername)
    if banPlayer then
        checkban(banPlayer)
    else
        server:brodcastTextMessage(timePrefix{text="[#FF0000]** ".. decoratePlayerName(playername) .." banned by ".. decoratePlayerName(adminPlayer)})
    end
end

function findOnlinePlayerByName(playername)
    local lname = string.lower(playername)
    if playersOnline[lname] then
        if server:findPlayerByID(playersOnline[lname]) then
            return server:findPlayerByID(playersOnline[i])
        else
            -- actually shouldn't happen, see onPlayerDisconnect
            playersOnline[lname] = nil
        end
    end
end

function lastlog(action, player)
    if action == "connect" then
        database:queryupdate("INSERT INTO `lastlog` (`player_id`, `name`, `ip`, `connect_at`) VALUES (".. player:getPlayerDBID() ..", '".. player:getPlayerName() .."', '".. player:getPlayerIP() .."', ".. os.time() ..");")
    else
        database:queryupdate("UPDATE `lastlog` SET `disconnect_at` = ".. os.time() .." WHERE `id` = (SELECT `id` FROM `lastlog` WHERE `ip` = '".. player:getPlayerIP() .."' ORDER BY `id` DESC LIMIT 1);")
    end
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
    database:queryupdate("CREATE TABLE IF NOT EXISTS `banlist` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `playername` NOT NULL, `admin` VARCHAR, `serial` VARCHAR, `date` INTEGER NOT NULL, `duration` LONG DEFAULT -1, `reason` VARCHAR, `applied_at` BOOLEAN DEFAULT 0);");
    database:queryupdate("CREATE TABLE IF NOT EXISTS `lastlog` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `player_id` INTEGER, `name` VARCHAR, `ip` VARCHAR, `connect_at` INTEGER, `disconnect_at` INTEGER DEFAULT -1)");

    -- Cleanup lost connections (server crash)
    database:queryupdate("UPDATE `lastlog` SET `disconnect_at` = 0 WHERE `disconnect_at` = -1")

    -- Broadcast motd every 60 minutes
    motd_timer = setTimer(function() showMotd(); end, 3600, -1);
end
