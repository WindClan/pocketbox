----pocketbox v4----
-- basic network music player for computercraft
-- now rewritten to actually work well
--------------------

local x,y = term.getSize()

if not _G.PLAYBACKCACHE then
	_G.PLAYBACKCACHE = {}
end

-- for craftos pc testing
if periphemu then
	periphemu.create("left","speaker")
	periphemu.create("right","speaker")
	periphemu.create("top","speaker")
end

-- basic speaker wrapper
local audioengine = {}
audioengine.speakers = {peripheral.find("speaker")}
audioengine.volume = 1
function audioengine.playChunk(this, chunk)
	local fin = {}
	local worked = false
	while not worked do
		worked = true
		for _,speaker in pairs(this.speakers) do
			if not speaker.playAudio(chunk,this.volume) then
				worked = false
			end
		end
		if worked == false then
			while not #fin == #this.speakers do
				table.insert(fin,{os.pullEvent("speaker_audio_empty")})
			end
		end
		sleep()
	end
	
end
function audioengine.stop(this)
	for _,speaker in pairs(this.speakers) do
		speaker.stop()
	end
end
function audioengine.downsample(chunk)
	local new = {}
	for i=1,math.floor(#chunk/2) do
		if chunk[i*2] and chunk[(i*2)-1] then
			new[i] = math.floor((chunk[i*2] + chunk[(i*2)-1])/2)
		else
			new[i] = chunk[(i*2)-1]
		end
	end
	return new
end

-- audio player section
local playback = {}
playback.dfpwm = require("cc.audio.dfpwm")
playback.frame = nil
playback.cache = _G.PLAYBACKCACHE
playback.currentSong = {}
playback.shuffled = false
playback.paused = false
function playback.parsePlaylist(path)
	local playlist = {}
	local file = fs.open(path,"r")
	local dat = file.readLine(false)
	local song = nil
	while dat do
		local songType = dat:gmatch("%[(.*)%]")()
		if songType and songType ~= "" then
			song = {}
			song.type = songType
			song.title = "Untitled"
			song.artist = "Unknown Artist"
			song.dfpwm96 = "false"
			song.chunkSize = 6000
			table.insert(playlist,song)
			print("["..songType.."]")
		else
			key, value = dat:gmatch("([a-z0-9]*):(.*)")()
			if key and value then
				if song then
					song[key] = value
					print(key.." : "..value)
				end
			end
		end
		dat = file.readLine(false)
	end
	file.close()
	for _,song in pairs(playlist) do
		if song.type == "gdrive" then
			driveId = song.path:gsub("https://drive%.google%.com/file/d/",""):gsub("/view",""):gsub("?usp=","&")
			song.path = "https://drive.google.com/uc?export=download&id="..driveId
		end
		if song["dfpwm96"] == "true" then
			song.chunkSize = 12000
		end
	end
	return playlist
end
function playback.drawScreen(this)
	local f = this.frame
	local title = this.currentSong.title
	local artist = this.currentSong.artist
	if not title or not artist then
		return
	end
	f.setVisible(false)
	f.clear()
	f.setCursorPos(1,1)
	f.write("pocketbox v4")
	
	local str = "shuffled: "..tostring(this.shuffled)
	f.setCursorPos(x+1-#str,1)
	f.write(str)
	
	if #title < x then
		f.setCursorPos(x/2 - #title/2,math.floor(y/2))
	else
		f.setCursorPos(1,4)
	end
	f.write(title)
	
	if #artist < x then
		f.setCursorPos(x/2 - #artist/2,math.floor(y/2)+1)
	else
		f.setCursorPos(1,5)
	end
	f.write(artist)
	
	f.setCursorPos(1,y)
	f.write("paused: "..tostring(this.paused))
	
	local isDfpwm96 = this.currentSong.chunkSize == 12000
	local str = isDfpwm96 and "dfpwm96" or "dfpwm"
	f.setCursorPos(x+1-#str,y)
	f.write(str)
	
	f.setVisible(true)
end
function playback.playSong(this,song)
	local file
	local chunks
	local decoder = this.dfpwm.make_decoder()
	if not this.cache[song.path] then
		file,err = http.get(song.path)
		chunks = {}
		if file then
			local dat = file.read(song.chunkSize)
			if dat then
				table.insert(chunks,decoder(dat))
			end
		else
			print(song.path)
			error(err)
		end
	else
		chunks = this.cache[song.path]
	end
	this.currentSong = song
	local isDfpwm96 = song.chunkSize == 12000
	local curChunk = 1
	while curChunk <= #chunks do
		audioengine:playChunk(isDfpwm96 and audioengine.downsample(chunks[curChunk]) or chunks[curChunk])
		curChunk = curChunk + 1
		if this.paused then
			audioengine:stop()
			while this.paused do
				sleep()
			end
		end
		if not this.cache[song.path] then
			local dat = file.read(song.chunkSize)
			if dat ~= nil then
				table.insert(chunks,decoder(dat))
			end
		end
	end
	if not this.cache[song.path] then
		this.cache[song.path] = chunks
		file.close()
	end
end
function playback.playTask(this,song)
	parallel.waitForAny(function()
		playback:playSong(song)
	end, function()
		while true do
			playback:drawScreen()
			sleep(1/10)
		end
	end, function()
		while true do
			os.pullEvent("mouse_click")
			this.paused = not this.paused
		end
	end, function()
		os.pullEvent("key")
	end)
end
function playback.play(this,pbfile,shuffled)
	this.frame.setVisible(false)
	local pb = playback.parsePlaylist(pbfile)
	print("Shuffled playback: "..tostring(shuffled))
	this.shuffled = shuffled
	if not shuffled then
		for _,v in pairs(pb) do
			playback:playTask(v)
			sleep()
			audioengine:stop()
			sleep()
		end
	else
		local shuffle1 = {}
		local shuffle2 = {}
		for _,v in pairs(pb) do
			table.insert(shuffle1,v)
		end
		while #shuffle1 > 0 do
			local a = math.random(1,#shuffle1)
			table.insert(shuffle2,shuffle1[a])
			table.remove(shuffle1,a)
		end
		for _,v in pairs(shuffle2) do
			playback:playTask(v)
			sleep()
			audioengine:stop()
			sleep()
		end
	end
end


--start the thing!!!
playback.frame = window.create(term.current(),1,1,x,y,false)

local arguments = {...}
if arguments[1] and fs.exists(arguments[1]) then
	local shouldShuffle = true
	if arguments[2] then
		shouldShuffle = arguments[2] == "true" or arguments[2] == "yes" or arguments[2] == "y" or arguments[2] == "shuffle"
	end
	playback:play(arguments[1],shouldShuffle)
else 
	if fs.exists("autoplay.pb") then
		while true do
			playback:play("autoplay.pb",false)
		end
	elseif fs.exists("autoshuffle.pb") then
		while true do
			playback:play("autoshuffle.pb",true)
		end
	else
		printError("No playlist found! Please refer to the README.md on how to use Pocketbox!")
	end
end