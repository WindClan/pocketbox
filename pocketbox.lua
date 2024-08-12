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
function music()
    while true do
        for _,v in pairs(playlist) do
			song = v["title"]
			artist = v["artist"]
            current = v["url"]
            local data = songs[v.url]
            if data then
                local decoder = dfpwm.make_decoder()
                while true do
                    local chunk = data.read(16 * 1024)
                    if not chunk then
                        break
                    end
                    local buffer = decoder(chunk)
                    while not s.playAudio(buffer) do
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
		term.write("pocketbox v1")
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
			songs[v.url] = data
		end
	end
	_G.pocketboxPreloadedMusic = songs
end

parallel.waitForAll(music,display)