
local raw_patterns = {
	"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)",
}

local all_patterns = {}

-- Appends time modifier patterns to each pattern
for k,p in pairs(raw_patterns) do
	table.insert(all_patterns, p .. "%?t=(%d+)m(%d+)s")
	table.insert(all_patterns, p .. "%?t=(%d+)s?")
	table.insert(all_patterns, p .. "#t=(%d+)m(%d+)s")
	table.insert(all_patterns, p .. "#t=(%d+)s?")
	table.insert(all_patterns, p .. "&t=(%d+)m(%d+)s")
	table.insert(all_patterns, p .. "&t=(%d+)s?")
	table.insert(all_patterns, p)
end

wyozimc.AddProvider({
	Name = "Youtube",
	UrlPatterns = all_patterns,
	QueryMeta = function(udata, callback, failCallback)
		local uri = udata.Matches[1]

		local url = "https://www.youtube.com/watch?v="..uri

		wyozimc.Debug("Fetching query for " .. uri .. " from " .. url)
		--print("StartAt = "..udata.StartAt)

		if SERVER then
			http.Post(wyozimc.PostUrl, {url=url,startat=tostring(udata.StartAt)}, function(result, size)
				if size == 0 then
					failCallback("HTTP request failed (size = 0)")
					return
				end
				callback(util.JSONToTable(result))
			end, function(error)
				if size == 0 then
					failCallback("HTTP request failed ("..error..")")
					return
				end
			end)
			return
		end

		http.Fetch(url, function(result, size)
			if size == 0 then
				failCallback("HTTP request failed (size = 0)")
				return
			end

			local data = {}
			data["URL"] = "http://www.youtube.com/watch?v=" .. uri
			data.Title = string.match(result, "<title>(.*) %- YouTube</title>") or "ERROR"
			data.Duration = (string.match(result, ',"approxDurationMs":"(%d+)",') or (60*1000)) / 1000 -- xd
			callback(data)

		end)
	end,
	PlayInMediaType = function(mtype, play_data)
		local data = play_data.udata

		local vqstring = ""
		if cvars.Bool("wyozimc_highquality") then
			vqstring = "hd1080"
		end

		local startat = data.StartAt or 0

		mtype.html:OpenURL(string.format("https://yupi2.github.io/wmc/players/youtube.html?vid=%s&forcehtml5=true&start=%d&vol=%f", wyozimc.JSEscape(data.Matches[1]), startat, wyozimc.GetMasterVolume()*100)) -- dunno.. maybe..
	end,
	ParseUData = function(udata)
		if udata.Matches[2] and udata.Matches[3] then -- Minutes and seconds
			udata.StartAt = math.Round(tonumber(udata.Matches[2])) * 60 + math.Round(tonumber(udata.Matches[3]))
		elseif udata.Matches[2] then -- Seconds
			udata.StartAt = math.Round(tonumber(udata.Matches[2]))
		end
	end,
	MediaType = "web",
	FuncSetVolume = function(mtype, volume)
		mtype.html:RunJavascript([[
		setYoutubeVolume(]] .. (volume*100) .. [[)
		]])
	end,
	FuncQueryElapsed = function(mtype)
		return [[try {
			var player = document.getElementById('player1');
			var state = player.getPlayerState();
			if (state == 0) // ended
				wmc.SetElapsed(player.getDuration() + 2) // Stupid but works?
			else
				wmc.SetElapsed(player.getCurrentTime());
		} catch (e) {
		}
		]]
	end
})
