--Epic jukebox software (now on pocket PC!)
--Made by Featherwhisker
local s = peripheral.find("speaker")
local current = ""
local song = ""
local artist = ""
local dfpwm = require("cc.audio.dfpwm")
local config = require("playlist")
local playlist = config.playlist
local songs = {}
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
	sleep()
end
function music()
    while true do
        for _,v in pairs(playlist) do
			song = v["title"]
			artist = v["artist"]
            current = v["url"]
            local data = songs[v.url]
            if data then
                local decoder = dfpwm.make_decoder()
				local last = 0
                while true do
					if last > #data then
                        break
                    end
                    local chunk = getFrames(last+1,last+48000,data)
					if #chunk == 0 then
						break
					end
					last = last + 48000
					while not s.playAudio(chunk) do
						os.pullEvent("speaker_audio_empty")
					end 
                end
               current = ""
            end
        end
        sleep()
    end
end
function display()
	term.setTextColor(config.textcolor)
	term.setBackgroundColor(config.backgroundcolor)
	term.setCursorBlink(false)
	while true do
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
		sleep()
	end
end
if _G.pocketboxPreloadedMusic and #songs == #_G.pocketboxPreloadedMusic then
	songs = _G.pocketboxPreloadedMusic
else
	print("Preloading songs...")
	for _,v in pairs(playlist) do
		local data = http.get(v.url, nil, true)
		if data then
			term.write(v.title.."...")
			local data1 = data.read(6000)
			songs[v.url] = {}
			local encoder = dfpwm.make_decoder()
			while data1 do
				addFrames(encoder(data1),songs[v.url])
				data1 = data.read(6000)
			end
			if data and data.close then
				pcall(data.close)
			end
			term.write("done")
			print("")
		end
	end
	_G.pocketboxPreloadedMusic = songs
end

parallel.waitForAny(music,display)