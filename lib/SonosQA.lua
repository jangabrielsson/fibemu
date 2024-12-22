---@diagnostic disable: undefined-global
-- Player type should handle actions: play, pause, stop, next, prev, setVolume, setMute
--%%name=SonosPlayer
--%%type=com.fibaro.player
--%%proxy="SonosProxy"

--%%u={button="button_ID_10_1",text="Shuffle",onReleased="doShuffle"}
--%%u={label="modesLabel",text="Modes:"}
--%%u={button="btnSay",text="Speak time",onReleased="speakTime"}
--%%u={label="statusLabel",text="Status:"}
--%%u={label="artistLabel",text="Artist"}
--%%u={label="trackLabel",text="Track"}
--%%u={label="playerLabel",text="Player"}
--%%u={select="playerSelector",text="Player",onToggled="selectPlayer",options={{text="a",value="a",type="option"}}}
--%%u={select="favoriteSelector",text="Favorite",onToggled="favoriteSelected",options={}}
--%%u={select="playlistSelector",text="Playlists",onToggled="playlistSelected",options={}}
--%%u={multi="groupSelector",text="Group",onToggled="groupSelected",options={}}
--%%u={button="groupBtn",text="Apply group",onReleased="applyGrouping"}

--%%debug=refresh:false
--%%file=lib/SonosLib.lua,SonosLib;

local player,sonos
-- UI buttons - send command to Sonos
--fibaro.fibemu.dumpUIfromQA(1918)
function QuickApp:play() sonos:play(player) end
function QuickApp:pause() sonos:pause(player) end
function QuickApp:stop() sonos:pause(player) end
function QuickApp:next() sonos:skipToNextTrack(player) end
function QuickApp:prev() sonos:skipToPreviousTrack(player) end
function QuickApp:setVolume(volume) sonos:volume(player,volume) end
function QuickApp:setMute(mute) sonos:mute(player,mute~=0) end

function QuickApp:selectPlayer(ev)
  player = ev.values[1]
  self:updatePlayer()
end

local function mode(m) 
   local group = sonos._group[sonos._player[player].groupId]
   return (group.playModes or {})[m]==true
end
function QuickApp:doShuffle() sonos:setModes(player,{shuffle=not mode('shuffle')}) end
function QuickApp:doRepeat() sonos:setModes(player,{['repeat']=not mode('repeat')}) end
function QuickApp:doRepeat1() sonos:setModes(player,{repeatOne=not mode('repeatOne')}) end
function QuickApp:doCrossFade() sonos:setModes(player,{crossfade=not mode('crossfade')}) end
function QuickApp:speakTime() sonos:say(player,"Time is "..os.date("%H:%M")) end
function QuickApp:favoriteSelected(ev) sonos:playFavorite(player,tostring(ev.values[1])) end
function QuickApp:playlistSelected(ev) sonos:playPlaylist(player,tostring(ev.values[1])) end

local groupsSelected = {}
function QuickApp:groupSelected(ev) groupsSelected=ev.values[1] end
function QuickApp:applyGrouping(ev)
   print("SEL:",json.encode(groupsSelected))
   -- sonos.createGroup(groupsSelected)
end

function QuickApp:setLabel(name,str)
   --self:updateView(name,"text",string.format("<font size='2'><b>%s</b></font>",str))
  self:updateView(name,"text",str)
end

function QuickApp:updatePlayer()
  local group = sonos._group[sonos._player[player].groupId]
  self:updateView('playerLabel','text',"Player: "..(player or ""))
  self:updateView("statusLabel","text","Status: "..(group.status or ""))
  self:updateView("artistLabel","text","Artist: "..(group.currentArtist or ""))
  self:updateView("trackLabel","text","Track: "..(group.currentTrack or ""))
  self:updateProperty("state",group.status or "")
  self:updateProperty("volume",group.volume or 0)
  self:updateProperty("mute",group.muted or false)
  local modes = group.playModes or {}
  local m = {}
  for k,v in pairs(modes) do if v then m[#m+1]=k end end
  self:updateView("modesLabel","text","Modes: "..table.concat(m,","))
end

function QuickApp:setOptions(name,list,fun)
   local options = {}
   for _,item in ipairs(list) do
     local text,value = fun(item)
     options[#options+1] = {text=text,type='option',value=value}
   end
   self:updateView(name,"options",options)
end

-- Events from the Sonos player
local EVENT = {}
function EVENT.groupVolume(event) quickApp:updatePlayer() end
function EVENT.playerVolume(event) end
function EVENT.playbackStatus(event) quickApp:updatePlayer() end
function EVENT.metadata(event) quickApp:updatePlayer() end
function EVENT.favoritesUpdated()
   local function fun(i) return i.name,i.id end
   quickApp:setOptions("favoriteSelector",sonos.favorites,fun)
end
function EVENT.playlistsUpdated()
   local function fun(i) return i.name,i.id end
   quickApp:setOptions("playlistSelector",sonos.playlists,fun)
end

function QuickApp:onInit()
    self:debug("Player")
    quickApp = self
    Sonos("192.168.1.6",function(_sonos)
      self:debug("Sonos Ready")
      sonos = _sonos
      function sonos:eventHandler(event)
        if EVENT[event.type] then EVENT[event.type](event)
        else print("Unhandled event:",json.encode(event)) end
      end
      local function fun(i) return i,i end
      self:setOptions("playerSelector",sonos.playerNames,fun)
      self:setOptions("groupSelector",sonos.playerNames,fun)
       player = sonos.playerNames[1]
       self:updateView("playerSelector","selectedItem", player)
       self:updateView("playerLabel","text","Player:"..player)
    end,{socket=true})
end
