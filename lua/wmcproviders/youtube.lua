
local raw_patterns = {
	"^https?://[A-Za-z0-9%.%-]*%.?youtu%.be/([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/watch%?.*v=([A-Za-z0-9_%-]+)",
	"^https?://[A-Za-z0-9%.%-]*%.?youtube%.com/v/([A-Za-z0-9_%-]+)",
}

local all_patterns = {}

-- Appends time modifier patterns to each pattern
for _,p in pairs(raw_patterns) do
	table.insert(all_patterns, p .. "#t=(%d+)m(%d+)s")
	table.insert(all_patterns, p .. "#t=(%d+)")
	table.insert(all_patterns, p)
end

wyozimc.AddProvider({
	Name = "Youtube",
	UrlPatterns = all_patterns,
	QueryMeta = function(data, callback, failCallback)
		local uri = data.Matches[1]
		
		local url = Format("http://gdata.youtube.com/feeds/api/videos/%s?alt=json", uri)

		wyozimc.Debug("Fetching query for " .. uri .. " from " .. url)

		http.Fetch(url, function(result, size)
			if size == 0 then
				failCallback("HTTP request failed (size = 0)")
				return
			end

			local data = {}
			data["URL"] = "http://www.youtube.com/watch?v=" .. uri
			
			local jsontbl = util.JSONToTable(result)

			if jsontbl and jsontbl.entry then
				local entry = jsontbl.entry
				data.Title = entry["title"]["$t"]
				data.Duration = tonumber(entry["media$group"]["yt$duration"]["seconds"])
			else
				data.Title = "ERROR"
				data.Duration = 60 -- lol wat
			end

			callback(data)

		end)
	end,
	TranslateUrl = function(data, callback)
		local vqstring = ""
		if cvars.Bool("wyozimc_highquality") then
			vqstring = "hd1080"
		end

		local startat = data.StartAt

		if cvars.Bool("wyozimc_forcehtml5") then
			callback("http://www.youtube.com/embed/" .. wyozimc.JSEscape(data.Matches[1]) .. "?html5=1&autoplay=1&controls=0&rel=0&showinfo=0&start=" .. tostring(startat), startat)
		else
			callback("http://www.youtube.com/watch_popup?v=" .. wyozimc.JSEscape(data.Matches[1]) .. "&controls=0&rel=0&showinfo=0&vq=" .. vqstring .. "&start=" .. tostring(startat), startat)
		end
	end,
	ParseUData = function(udata)
		if udata.Matches[2] and udata.Matches[3] then -- Minutes and seconds
			udata.StartAt = math.Round(tonumber(udata.Matches[2])) * 60 + math.Round(tonumber(udata.Matches[3]))
		elseif udata.Matches[2] then -- Seconds
			udata.StartAt = math.Round(tonumber(udata.Matches[2]))
		end
	end,
	FuncSetVolume = function(volume)
		return [[try {
		document.getElementById('player1').setVolume(]] .. (volume*100) .. [[);
		} catch (e) {}
		]]
	end,
	FuncQueryElapsed = function()
		return [[try {
		var player = document.getElementById('player1');
		if (player.getPlayerState() == 0) // ended
			wmc.SetElapsed(player.getDuration() + 2) // Stupid but works?
		else
			wmc.SetElapsed(player.getCurrentTime());
		} catch (e) {}
		]]
	end
})