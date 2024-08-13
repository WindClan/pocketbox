--Epic jukebox software (now on pocket PC!)
--Made by Featherwhisker
settings.define("pocketbox.shuffle",{
	description = "Specifies whether pocketbox should shuffle",
	default = false,
	type = "boolean"
})
settings.save()
local s = peripheral.find("speaker")

local termX,termY = term.getSize()
local frame = window.create(term.current(), 1, 1, termX, termY)
term.redirect(frame)

local current = ""
local song = ""
local artist = ""
local dfpwm = require("cc.audio.dfpwm")
local config = require("playlist")
local playlist = config.playlist
if not _G.pocketbox then
	_G.pocketbox = {}
end
local songs = _G.pocketbox
local buffer = nil

local shouldSkip = false
local isPaused = false
local shuffle = settings.get("pocketbox.shuffle")

--Taken from speakerlib
local function speakerFuncMono(speaker)
	while not speaker.playAudio(buffer) do
		os.pullEvent("speaker_audio_empty")
	end
end

local function getMonoFunctions()
	local speakers = {}
	for i,v in pairs(peripheral.getNames()) do
		if peripheral.hasType(v,"speaker") then
			table.insert(speakers,function()
				speakerFuncMono(peripheral.wrap(v))
			end)
		end
	end
	return speakers
end

local function getFrames(first,last,dat)
	local a = {}
	for i=first,last do
		table.insert(a,dat[i])
	end
	return a 
end
local function addFrames(new,old)
	for _,v in pairs(new) do
		table.insert(old,v)
	end
end

local function playSong(v)
    local data = songs[v.url]
	local isPreloaded = true
	if not data or not data.preloaded then
		isPreloaded = false
		data1 = http.get(v.url, nil, true)
		songs[v.url] = {}
		data = songs[v.url]
	end
	song = v["title"]
	artist = v["artist"]
    current = v["url"]
    local decoder = dfpwm.make_decoder()
	local speakers = getMonoFunctions()
	local last = 0
    while true do
		if isPaused then
			while isPaused do
				sleep()
			end
		end
		if shouldSkip then
			shouldSkip = false
			isPaused = false
			break
		end
		if not isPreloaded then
			newDat = data1.read(3000)
			if not newDat then
				shouldSkip = false
				isPaused = false
				songs[v.url].preloaded = true
				break
			end
			addFrames(decoder(newDat),songs[v.url])
		end
		if last > #data then
			shouldSkip = false
			isPaused = false
			if not isPreloaded then
				songs[v.url].preloaded = true
			end
            break
        end
        buffer = getFrames(last+1,last+24000,data)
		if #buffer == 0 then
			isPaused = false
			shouldSkip = false
			break
		end
		last = last + 24000
		parallel.waitForAll(table.unpack(speakers))
    end
    current = ""
end
local lastSong = 0
local shuffleList = {}
local function getSong()
	lastSong = lastSong + 1
	if lastSong > #playlist then
		lastSong = 1
	end
	if shuffle and #shuffleList == 0 and #playlist ~= 0 then
		for i=1,#playlist do
			table.insert(shuffleList,tostring(i))
		end
	end
	if not shuffle then
		return playlist[lastSong]
	else
		lastSong = math.random(1,#shuffleList)
		local song = playlist[tonumber(shuffleList[math.random(1,#shuffleList)])]
		table.remove(shuffleList,lastSong)
		return song
	end
end
local function music()
    while true do
		local song = getSong()
		playSong(song)
        sleep()
    end
end
local function display()
	term.setTextColor(config.textcolor)
	term.setBackgroundColor(config.backgroundcolor)
	term.setCursorBlink(false)
	while true do
		frame.setVisible(false)
		term.clear()
		term.setCursorPos(1,1)
		term.write("pocketbox v2")
		term.setCursorPos(1,4)
		term.write("Now playing:")
		if current then
			term.setCursorPos(1,5)
			term.write(song)
			term.setCursorPos(1,6)
			term.write(artist)
		else
			term.setCursorPos(1,5)
			term.write("Nothing is playing")
		end
		
		
		term.setCursorPos(1,termY)
		local shuffleStr = "shuffle: "..tostring(shuffle)
		local back = colors.toBlit(config.textcolor)
		local text = colors.toBlit(config.backgroundcolor)
		term.blit(shuffleStr..(" "):rep(termX-#shuffleStr),text:rep(termX),back:rep(termX))
		term.setCursorPos(termX-2,termY)
		term.blit("\16 \26",text:rep(3),back:rep(3))
		frame.setVisible(true)
		sleep()
	end
end
local function input()
	while true do
		local event, button, x, y = os.pullEvent("mouse_click")
		if y == termY then
			if x == termX-2 then
				isPaused = not isPaused
			elseif x == termX then
				isPaused = false
				shouldSkip = true
			elseif x ~= termX-1 then
				shuffle = not shuffle
				settings.set("pocketbox.shuffle",shuffle)
				settings.save()			
			end
		end
	end
end

parallel.waitForAny(music,display,input)