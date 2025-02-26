local _G = getfenv(0)
local addonName, addonTable = ...

local soundPackName = C_AddOns.GetAddOnMetadata(addonName, 'X-SoundPackName')
local version = tonumber(C_AddOns.GetAddOnMetadata(addonName, 'Version')) or 999

JTS = JTS or {}
JTS.DefaultSoundPack = "JTSound"
JTS.Debug = false
JTS.Spam = {}

JTS.soundPack = JTS.soundPack or false
JTS.SPCount = 9
JTS.version = (JTS.version and version) and ( JTS.version >= version and JTS.version or version ) or (JTS.version or (version and version or 999))

JTS.addonPath = addonName
JTS.alertNewVersion = JTS.alertNewVersion == nil or true
JTS.alertFileMissing = JTS.alertFileMissing == nil or true
JTS.soundPackList = JTS.soundPackList or {}

JTS.isCounting = JTS.isCounting or false

--命令登记
SLASH_JTSound1 = "/jtsound";
SLASH_JTSound2 = "/jts";
SlashCmdList[JTS.DefaultSoundPack] = function(msg)
	JTS_SlashCommandHandler(msg);
end

local JTSFrame, events = CreateFrame("Frame"), {};

--SavedVariables
local function initDB()
	if type(JTSDB) ~= "table" then JTSDB = {} end
	if type(JTSDB.currentSP) ~= "string" then JTSDB.currentSP = addonName end
	if type(JTSDB.soundPackList) ~= "table" then JTSDB.soundPackList = {} end
	if type(JTSDB.isCounting) ~= "boolean" then JTSDB.isCounting = false end
	if type(JTSDB.isDebugging) ~= "boolean" then JTSDB.isDebugging = false end
	if type(JTSDB.playedCount) ~= "table" then JTSDB.playedCount = {} end
	if type(JTSDB.unplayableCount) ~= "table" then JTSDB.unplayableCount = {} end
end

function events:ADDON_LOADED(...)
	local loadedAddOnName, containsBindings = ...
	if loadedAddOnName == addonName then
		JTS_Print("是|RJT系列WA|CFF8FFFA2的语音包插件: |CFFFF53A2"..addonName)
		if initDB then
			initDB() --SavedVariables
			
			--load SavedVariables
			
			JTSDB.currentSP = JTSDB.currentSP == "JTSound" and addonName or (IsAddOnLoaded(JTSDB.currentSP) and JTSDB.currentSP or addonName)
			JTS.addonPath = JTSDB.currentSP 

			JTS.isCounting = JTSDB.isCounting
			JTS.Debug = JTSDB.isDebugging or false

			JTS.soundPackList[addonName] = { 
				name = soundPackName,
				version = C_AddOns.GetAddOnMetadata(addonName, 'Version') or 0
			}
		end
	end
end

--收到JTE发出的检查消息就发送自己的语音包版本情况。
function events:CHAT_MSG_ADDON(...)
	local prefix, text, channel, sender, target, zoneChannelID, localID, channelName, instanceID = ...
	JTS_ReceiveStealthMSG(prefix, text, channel, sender, target, zoneChannelID, localID, channelName, instanceID)
end

function events:PLAYER_ENTERING_WORLD(...)
	if JTS.addonPath == addonName then
		JTS_Print("是|RJT系列WA|CFF8FFFA2的语音包插件: |CFFFF53A2"..addonName)
	end
	JTS_CheckSoundPack(true)
	JTS.SPCount = JTS_RefreshSoundPackList()
	JTSFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

JTSFrame:SetScript("OnEvent", function(self, event, ...)
	events[event](self, ...); -- call one of the functions above
end);

for k, v in pairs(events) do
	JTSFrame:RegisterEvent(k); -- Register all events for which handlers have been defined
end

--刷新soundPackList
JTS_RefreshSoundPackList = JTS_RefreshSoundPackList or function()
	local count = 0
	for k, _ in pairs(JTS.soundPackList) do
		if not IsAddOnLoaded(k) then 
			JTS.soundPackList[k] = nil
		else
			count = count + 1
		end
	end
	JTSDB.soundPackList = JTS.soundPackList
	return count
end

--命令判断
JTS_SlashCommandHandler = JTS_SlashCommandHandler or function(msg)
	if( msg ) then
		local command = string.lower(msg);
		--先用空格拆分指令
		if JTS_SplitString(command," ") then
			--有前缀指令
			local command, pre1, pre2, pre3 = JTS_CmdSplit(command)
			JTS_Print("|CFFFF0000Pre1: |R"..tostring(pre1).." |CFFFF0000Pre2: |R"..(pre2 or ("|CFF7D7D7D"..tostring(pre2).."|R")).." |CFFFF0000Pre3: |R"..(pre3 or ("|CFF7D7D7D"..tostring(pre3).."|R")).." |CFFFF0000Cmd: |R"..command)
			if pre1 == "w" and command ~= "" and command ~= nil then
				JTS_SendResponseMessage(nil,nil,"WHISPER",command)
			end
		else
			--无前缀指令
			if( command == "c" ) then
				JTS_CheckSoundPack()
			elseif( command == "count" ) then
				JTS_ToggleCounting()
			elseif( command == "debug" ) then
				JTS_ToggleDebug()
			elseif( command == "listpc" ) then
				JTS_ListPlayedCount()
			elseif( command == "resetpc" ) then
				JTS_PlayedCountReset()
			elseif( command == "listupc" ) then
				JTS_ListUnplayableCount()
			elseif( command == "resetupc" ) then
				JTS_UnplayableCountReset()
			else
				JTS_CheckSoundPack()
				JTS_Help()
			end
		end
	end
end

--for addonmsg
local regPrefix = function()
    local prefixList = {
        ["JTESAY"] = true,
        ["JTEGUILD"] = true,
        ["JTERAID"] = true,
        ["JTEPARTY"] = true,
        ["JTETTS"] = true,
        ["JTECHECK"] = true,
        ["JTECHECKRESPONSE"] = true,
    }
    for k, _ in pairs(prefixList) do
        local successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(k)
    end
end
regPrefix()

--StealthCheckResponseMSG
JTS_SendResponseMessage = JTS_SendResponseMessage or function(msg,prefix,channel,targetName)
	--pre1:传输频道 pre2:发言频道 pre3:谁
	if not msg then 
		msg = "|CFFFF53A2"..JTS.addonPath.."|R Ver: "..JTS.version.." SP: "..( JTS.soundPack and "|CFFFF53A2OK!|R" or "|CFFFF0000ERROR!|R" )
	end
	if not prefix then
		prefix = "JTECHECKRESPONSE"
	end

	if channel == "WHISPER" and ( targetName == "" or targetName == nil ) then
		JTS_Print("Whisper name error!")
		return
	end

	if not channel or not ( channel == "RAID" or channel == "PARTY" or channel == "GUILD" or channel == "INSTANCE_CHAT" or channel == "WHISPER") then
		if IsInRaid() and not  IsInGroup(LE_PARTY_CATEGORY_INSTANCE)  then
			channel = 'RAID'
		elseif IsInGroup(LE_PARTY_CATEGORY_HOME) and not  IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
			channel = 'PARTY'
		elseif IsInRaid() and  IsInGroup(LE_PARTY_CATEGORY_INSTANCE)  then
			channel = 'INSTANCE_CHAT'
		else
			channel = 'GUILD'
		end
	end

	if msg and channel then
		C_ChatInfo.SendAddonMessage(prefix, msg, channel,targetName)
	end
	return
end

--StealthMSG
JTS_ReceiveStealthMSG = JTS_ReceiveStealthMSG or function(prefix, text, channel, sender, target, zoneChannelID, localID, channelName, instanceID)
    local convertChannel = {
        ["JTESAY"] = "SAY",
        ["JTEGUILD"] = "GUILD",
        ["JTERAID"] = "RAID",
        ["JTEPARTY"] = "PARTY"
    }
    if prefix == "JTECHECK" then
		if text == "soundpack" then
			JTS_SendResponseMessage(nil,nil,channel,nil)
		end
	elseif prefix == "JTETTS" then
		local name, msg = JTS_SplitString(text, ":")
		if msg then
			if name == string.lower(UnitName("player")) or name == "all" then
				C_VoiceChat.SpeakText(0, msg, 0, 2, 100)
			end
		end
	elseif convertChannel[prefix] then
		local name, msg = JTS_SplitString(text, ":")
		local channel = convertChannel[prefix]
		if msg then
			if name == string.lower(UnitName("player")) or name == "all" then
				SendChatMessage(msg, channel, nil,nil)
			end
		end
	end
end

--PlayedCount
JTS_ListPlayedCount = JTS_ListPlayedCount or function()
	if next(JTSDB.playedCount) then
		JTS_Print("==== "..date("%H:%M:%S %Y").." ====")
		local index = 1
		local totalCount = 0
		for key, _ in pairs(JTSDB.playedCount) do
			local text = "|CFFFF0000#: |R|CFFFFFFFF"..index.."|R PC: |CFFFF53A2"..JTSDB.playedCount[key].count.."|R |CFF40FF40File: |R"..key
			JTS_Print(text)
			index = index + 1
			totalCount = totalCount + JTSDB.playedCount[key].count
		end
		JTS_Print("==== =======PlayedCount(Total): "..totalCount.."======= ====")
	else
		JTS_Print("No file played by now")
	end
end

JTS_PlayedCountReset = JTS_PlayedCountReset or function()
	JTSDB.playedCount = {}
	JTS_Print("|CFF1785D1PlayedCount is reset. |R")
end

JTS_ListUnplayableCount = JTS_ListUnplayableCount or function()
	if next(JTSDB.unplayableCount) then
		JTS_Print("==== "..date("%H:%M:%S %Y").." ====")
		local index = 1
		local totalCount = 0
		for key, _ in pairs(JTSDB.unplayableCount) do
			local text = "|CFFFF0000#: |R|CFFFFFFFF"..index.."|R UPC: |CFFFF53A2"..JTSDB.unplayableCount[key].count.."|R |CFF40FF40File: |R"..key
			JTS_Print(text)
			index = index + 1
			totalCount = totalCount + JTSDB.unplayableCount[key].count
		end
		JTS_Print("==== =======UnplayableCount(Total): "..totalCount.."======= ====")
	else
		JTS_Print("No file is unplayable by now")
	end
end

JTS_UnplayableCountReset = JTS_UnplayableCountReset or function()
	JTSDB.unplayableCount = {}
	JTS_Print("|CFF1785D1UnplayableCount is reset. |R")
end

JTS_EnableCount = JTS_EnableCount or function()
	JTS.isCounting = true
	JTSDB.isCounting = true
	JTS_Print("|CFFFF53A2Start|R counting file played/unplayable.")
end

JTS_DisableCount = JTS_DisableCount or function()
	JTS.isCounting = false
	JTSDB.isCounting = false
	JTS_Print("|CFFFFFF00Stop|R counting file played/unplayable.")
end

JTS_ToggleCounting = JTS_ToggleCounting or function()
	if JTS.isCounting then
		JTS_DisableCount()
	else
		JTS_EnableCount()
	end
end


--JTS播放声音文件
JTS_PlaySoundFile = JTS_PlaySoundFile or function(filePath,reqVersion)
	reqVersion = reqVersion or JTS.version
	local currentVersion = JTS.version

	if not filePath or filePath == "" then
		JTS_Debug("filePath nil or ()")
		return false
	else
		if type(filePath) == "string" then
			local path = ([[Interface\AddOns\%s\Sound\]]):format(JTS.addonPath)
			local fullPath = path..([[%s]]):format(filePath)
			--tryPlay other soundpack
			local canplay, soundHandle = PlaySoundFile(fullPath, "Master")
			if not canplay then
				--tryPlay JT default soundpack if JTSound available
				if GetCVar("Sound_EnableAllSound") ~= "1" then
					if (not JTS.Spam["ENABLE_SOUND"] or GetTime() > JTS.Spam["ENABLE_SOUND"]) then
						JTS_Print("语音包需要游戏开启声效: |CFFFF53A2Esc|R-|CFFFF53A2选项|R-|CFFFF53A2音频|R-|CFFFF53A2开启声效|R")
						if not JTS.Spam["ENABLE_SOUND"] then
							JTS.Spam["ENABLE_SOUND"] = GetTime() + 10
						else
							JTS.Spam["ENABLE_SOUND"] = GetTime() + 180
						end
					end
				elseif JTS.addonPath ~= JTS.DefaultSoundPack then 
					path = ([[Interface\AddOns\%s\Sound\]]):format(JTS.DefaultSoundPack)
					fullPath = path..([[%s]]):format(filePath)
					--tryPlay other soundpack
					canplay, soundHandle = PlaySoundFile(fullPath, "Master")
					if not canplay then
						--JTS有，但是播放文件失败，说明文件缺失或者版本低
						if reqVersion > currentVersion and JTS.alertNewVersion then
							JTS_Print("没有找到音频文件，请更新|CFFFF53A2JTSound|R语音插件版本 |CFFFF53A2"..reqVersion)
							JTS.alertNewVersion = false
						end
						if reqVersion <= currentVersion and JTS.alertFileMissing then
							JTS_Print("音频文件缺失，请重新安装|CFFFF53A2JTSound|R语音插件")
							JTS.alertFileMissing = false
						end
					end
				else
					if reqVersion > currentVersion and JTS.alertNewVersion then
						JTS_Print("没有找到音频文件，请更新|CFFFF53A2JTSound|R语音插件版本 |CFFFF53A2"..reqVersion)
						JTS.alertNewVersion = false
					end
					if reqVersion <= currentVersion and JTS.alertFileMissing then
						JTS_Print("音频文件缺失，请重新安装|CFFFF53A2JTSound|R语音插件")
						JTS.alertFileMissing = false
					end
				end
			end
			if JTS.isCounting then
				if canplay then
					if not JTSDB.playedCount[filePath] then
						JTSDB.playedCount[filePath] = {
							count = 1,
						}
					else
						if JTSDB.playedCount[filePath].count > 20000 then
							JTS_DisableCount()
						else
							JTSDB.playedCount[filePath].count = JTSDB.playedCount[filePath].count + 1
						end
					end
				else
					if not JTSDB.unplayableCount[filePath] then
						JTSDB.unplayableCount[filePath] = {
							count = 1,
						}
					else
						if JTSDB.unplayableCount[filePath].count > 20000 then
							JTS_DisableCount()
						else
							JTSDB.unplayableCount[filePath].count = JTSDB.unplayableCount[filePath].count + 1
						end
					end
				end
			end
			return canplay, soundHandle
		end
	end
end
JTS.P = JTS.P or JTS_PlaySoundFile

JTS_Help = JTS_Help or function()
	JTS_Print("JTS是|RJT系列WA|CFF8FFFA2的语音包集合 Ver: |CFFFFFFFF"..JTS.version)
	JTS_Print("命令为: |R/jts");
	JTS_Print("/jts :|R 检测语音包是否成功启用，成功会听到 |CFFFF53A2Biu~biu~biu~|R");
end

--字符串拆分处理
JTS_SplitString = JTS_SplitString or function(str, separator)
	local index = string.find(str, separator)
	if index then
		local part1 = string.sub(str, 1, index - 1)
		local part2 = string.sub(str, index + 1)
		return part1, part2
	else
		return
	end
end

--命令参数拆分
JTS_CmdSplit = JTS_CmdSplit or function(str) --最多3参数
	local msg, pre1, pre2, pre3
	if JTS_SplitString(str," ") then
		pre1, msg = JTS_SplitString(str," ")
		if JTS_SplitString(msg," ") then
			pre2, msg = JTS_SplitString(msg," ")
			
			if JTS_SplitString(msg," ") then
				pre3, msg = JTS_SplitString(msg," ")
				return msg, pre1, pre2, pre3
			else
				return msg, pre1, pre2
			end
		else
			return msg, pre1
		end
	else
		return false
	end
end

--带前缀的JTS_Print()
JTS_Print = JTS_Print or function(msg)
	if not msg then return end
	local header = "|T135975:12:12:0:0:64:64:4:60:4:60|t[|CFF8FFFA2JTS|R]|CFF8FFFA2 : "
	print(header..msg)
end

JTS_ToggleDebug = JTS_ToggleDebug or function()
	JTS.Debug = not JTS.Debug
	JTSDB.isDebugging = JTS.Debug
	
	JTS_Print("Debug : "..(JTS.Debug and "|CFF00FF00ON|R" or "|CFFFF0000OFF|R"))
end

JTS_Debug = JTS_Debug or function(str)
	if not JTS.Debug then return end
	if str then
		JTS_Print("Debug: "..tostring(str))
	else
		JTS_Print("Debug: JTS_Debug(str) str is nil")
	end
end

--语音包检测
JTS.checkedSP = false
JTS_CheckSoundPack = JTS_CheckSoundPack or function(mute)
	local text

	local canplay, soundHandle = JTS.P("Common\\biubiubiu.ogg")
	if canplay then
		if soundHandle and mute then 
			StopSound(soundHandle)
		end
		JTS.soundPack = true
		text = "|CFFFF53A2Perfect!|R |CFF8FFFA2检测到语音包 当前使用|R: |CFFFF53A2"..(JTS.addonPath or "")
	else
		if GetCVar("Sound_EnableAllSound") ~= "1" then
			text = "语音包需要游戏开启声效: |CFFFF53A2Esc|R-|CFFFF53A2选项|R-|CFFFF53A2音频|R-|CFFFF53A2开启声效|R"
		else
			JTS.soundPack = false
			text = "|CFFFFE0B0未找到语音包|R，请检查语音文件或者重新下载安装|CFFFF53A2JTSound|R|R"
		end
	end

	if not JTS.checkedSP then
		JTS_Print(text)
		JTS.checkedSP = true
	end
end
