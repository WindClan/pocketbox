--Epic jukebox software (now on pocket PC!)
--Made by WindClan
settings.define("pocketbox.shuffle",{
	description = "Specifies whether pocketbox should shuffle",
	default = false,
	type = "boolean"
})
settings.save()
if not peripheral.find("speaker") then
	error("No speakers attached!",0)
end

local termX,termY = term.getSize()
local frame = window.create(term.current(), 1, 1, termX, termY)
term.redirect(frame)

local dfpwm
pcall(function()
	dfpwm = require("cc.audio.dfpwm")
end)


local config = {
	textcolor = "lime",
	backgroundcolor = "black"
}
local playlist = {}

local function getSongType(dat)
	return dat:gmatch("%[(.*)%]")()
end
local function parsePlaylistFile(path)
	if not path then
		path = "playlist.cfg"
	end
	local file = fs.open(path,"r")
	local dat = file.readLine(false)
	local song
	while dat do
		local songType = getSongType(dat)
		if songType and songType ~= "" then
			if songType == "config" then
				song = nil
			else
				song = {}
				song.type = songType
				song.title = "Untitled"
				song.artist = "Unknown Artist"
				song.format = "dfpwm"
				song.sr = "48000"
				song.ac = "1"
				table.insert(playlist,song)
				print("["..songType.."]")
			end
		else
			key, value = dat:gmatch("(.*):(.*)")()
			if key and value then
				if song then
					song[key] = value
				else
					config[key] = value
				end
				print(key.." : "..value)
			end
		end
		dat = file.readLine(false)
	end
	file.close()
	for i,v in pairs(playlist) do
		if v.format == "cd_raw" then
			v.format = "pcm_s16le"
			v.sr = "44100"
			v.ac = "2"
		end
	end
end

local current = ""
local song = ""
local artist = ""
if not _G.pocketbox then
	_G.pocketbox = {}
end
local songs = _G.pocketbox
local buffer = nil

local shouldSkip = false
local isPaused = false
local shuffle = settings.get("pocketbox.shuffle")

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
local function resample(originalRate,bit,samples)
	local upperRange = (math.pow(2,bit)/2)-1
	local lowerRange = -(math.pow(2,bit)/2)
	local new = {}
	local rate = 48000/originalRate
	for i=1,#samples*rate do
		local pos = ((i-1) / rate) + 1
		if pos == math.floor(pos) then
			table.insert(new,samples[pos])
		else
			local floored = math.floor(pos)
			local newSample = samples[floored] + ((samples[floored+1] or samples[floored])-samples[floored]) * (pos-floored)
			table.insert(new,newSample)
		end
	end
	for i=1,#new do
		local sample = new[i]
		sample = sample + (math.pow(2,bit)/2)
		sample = sample * (256/math.pow(2,bit))
		sample = sample - 128
		if sample > 127 then
			sample = 127
		elseif sample < -128 then
			sample = -128
		end
		new[i] = math.floor(sample+0.5)
	end
	return new
end

local function playSong(v)
	song = v.title
	artist = v.artist
    current = v.path
	local songType = v.type
	local songFormat = v.format
	local sampleRate = tonumber(v.sr)
	local channels = tonumber(v.ac)
	if songType == "gdrive" and not v.patched then
		driveId = current:gsub("https://drive%.google%.com/file/d/",""):gsub("/view",""):gsub("?usp=sharing","")
		v.path = "https://drive.google.com/uc?export=download&id="..driveId
		current = v.path
		v.patched = true
	end
    local data = songs[v.path]
	local data1
	local isPreloaded = true
	if not data or not data.preloaded then
		isPreloaded = false
		if songType == "file" then
			data1 = fs.open(v.path,"rb")
		else
			data1 = http.get(v.path, nil, true)
		end	
		songs[v.path] = {}
		data = songs[v.path]
	end
	local decoder
	if songFormat == "dfpwm" then
		decoder = dfpwm.make_decoder()
	end
	local speakers = {peripheral.find("speaker")}
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
			if songFormat == "dfpwm" then
				newDat = data1.read(3000)
				if not newDat then
					shouldSkip = false
					isPaused = false
					songs[v.path].preloaded = true
					break
				end
				addFrames(decoder(newDat),songs[v.path])
			elseif songFormat == "pcm_s16le" then
				local sampleTable = {}
				local readSample = 0
				local readAnySamples = false
				for i=1,sampleRate/2 do
					local sample = 0
					for i=1,channels do
						local rawDat = data1.read(2)
						if rawDat then
							readAnySamples = true
							sample = sample + string.unpack("<i2",rawDat)
						end
					end
					table.insert(sampleTable,sample/channels)
				end
				if not readAnySamples then
					shouldSkip = false
					isPaused = false
					songs[v.path].preloaded = true
					break
				end
				addFrames(resample(sampleRate,16,sampleTable),songs[v.path])
			else
				error("Invalid format specified!")
			end
		end
		if last > #data then
			shouldSkip = false
			isPaused = false
			if not isPreloaded then
				songs[v.path].preloaded = true
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
		for i,v in pairs(speakers) do
			v.playAudio(buffer)
		end
		os.pullEvent("speaker_audio_empty")
    end
	if data1 then
		pcall(data1.close)
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
		local success, response = pcall(playSong,song)
		if not success then
			term.clear()
			term.setCursorPos(1,1)
			print(response)
			error("Failed to play song! "..song["artist"].." - "..song["title"],0)
		end
        sleep()
    end
end
local function display()
	term.setTextColor(colors[config.textcolor])
	term.setBackgroundColor(colors[config.backgroundcolor])
	term.setCursorBlink(false)
	while true do
		frame.setVisible(false)
		term.clear()
		term.setCursorPos(1,1)
		term.write("pocketbox v3")
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
		local back = colors.toBlit(colors[config.textcolor])
		local text = colors.toBlit(colors[config.backgroundcolor])
		term.blit(shuffleStr..(" "):rep(termX-#shuffleStr),text:rep(termX),back:rep(termX))
		term.setCursorPos(termX-2,termY)
		term.blit("\16 \26",text:rep(3),back:rep(3))
		frame.setVisible(true)
		sleep()
	end
end
local function input()
	while true do
		local event, button, x, y = os.pullEventRaw("mouse_click","terminate")
		if event == "terminate" then
			error("Terminated.",0)
		end
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

parsePlaylistFile()
parallel.waitForAny(music,display,input)
