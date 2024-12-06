--[[
Sonos code lib for the Fibaro Home Center 3
Copyright (c) 2021 Jan Gabrielsson
Email: jan@gabrielsson.com
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

---@diagnostic disable: undefined-global
--%%name=Sonos

class 'Sonos'
function Sonos:__init(IP,cb,debugFlags)
  local colors = {'green','blue','yellow','red','orange','purple','pink','cyan','magenta','lime'}
  local coordinators,eventMap,n = {},{},0
  local done = 0
  local SELF,fmt=self,string.format
  self.debug = debugFlags or {}
  local function debug(tag,f,...) if debugFlags[tag] then print("Sonos: "..fmt(f,...)) end end
  local function LIST(t) return setmetatable(t,{__tostring=function() return table.concat(t,",") end}) end

  local function createCoordinator(url)
    if coordinators[url] then return coordinators[url] end
    local connected,buffer,cbs = false,{},{}
    local self = {}
    coordinators[url] = self
    local color = colors[n%#colors+1] n=n+1
    local function log(tag,fm,...) if debugFlags[tag] then print(fmt('<font color="%s">%s</font>',color,fmt(fm,...))) end end
    local sock = net.WebSocketClientTls()
    local function connect()
      sock:connect(url, {
        ["X-Sonos-Api-Key"] = "123e4567-e89b-12d3-a456-426655440000",
        ["Sec-WebSocket-Protocol"] = "v1.api.smartspeaker.audio",
      })
    end
    function self:send(data,opts,cb,nop)
      local cont = function()
        local tag=fmt("%s:%s",data.namespace,data.command)
        log("socket","Send: %s",tag)
        if nop then return end
        cbs[tag]=cb or function() end
        sock:send(json.encode({data,opts or {}}))
      end
      if connected then cont() else buffer[#buffer+1] = cont end
    end
    function self:cmd(data,opts,cb) self:send(data,opts,cb,debugFlags.noCmd) end
    function self:subscribe(resource,id,namespace,cb) self:send({[resource]=id,namespace=namespace,command="subscribe"},nil,cb) end
    function self:close() if connected then sock:close() log("socket","Close") connected=false coordinators[url]=nil end end
    sock:addEventListener("connected",function()
      connected = true log("socket","Connected")
      for _,cont in ipairs(buffer) do cont() buffer={} end
    end)
    sock:addEventListener("disconnected",function()
      log("socket","Disconnected")
      if connected then -- Socket was involuntarily disconnected, try to reconnect
        fibaro.warning(__TAG,"Disconnected - reconnect in 3s")
        connected=false
        setTimeout(function() connect() end,3000)
      end
    end)
    sock:addEventListener("dataReceived", function(data)
      data = json.decode(data)
      local header,obj = data[1],data[2]
      local tag = fmt("%s:%s",header.namespace,header.response or "")
      if cbs[tag] then log("socket","Rec: %s",tag) cbs[tag](header,obj) cbs[tag]=nil return end
      if eventMap[header.type] then
        eventMap[header.type](header,obj,color,self)
        if done==3 then done=4 setTimeout(function() cb(SELF) end,0) end -- every thing ready to call callback
        return
      end
      if header.success==false then log("socket","Rec error: %s",tag) end
    end)
    sock:addEventListener("error", function(err) fibaro.error(__TAG,"Sonos connection",error) log("socket","Error") end)
    log("socket","Connecting to %s",url)
    connect()
    return self
  end

  local function EVENT(str,ev) return setmetatable(ev,{__tostring=function() return str end}) end
  local function post(typ,id,args,color)
    local name = (SELF.groups[id] or SELF.players[id] or {name='Sonos'}).name
    local str = fmt('<font color="%s">[%s:"%s",%s]</font>',color,typ,name,json.encode(args):sub(2,-2))
    args.typ = typ
    if SELF.eventHandler then SELF.eventHandler(SELF,EVENT(str,args)) else print(str) end
  end

  function eventMap.groupVolume(header,obj,color)
    local group = SELF.groups[header.groupId] if not group then return end
    group.volume=obj.volume post("groupVolume",group.id,{volume=obj.volume,muted=obj.muted},color)
  end
  function eventMap.playbackStatus(header,obj,color)
    local status = obj.playbackState:match("_([%w]*)$"):lower()
    local group = SELF.groups[header.groupId] if not group then return end
    group.status = status post("playbackStatus",group.id,{state=status},color)
  end
  function eventMap.playerVolume(header,obj,color)
    local player = self._player[header.playerId]
    player.volume = obj.volume post("playerVolume",player.id,{volume=obj.volume,muted=obj.muted},color)
  end
  function eventMap.metadataStatus(header,obj,color)
    local g = SELF.groups[header.groupId] if not g then return end
    g.currentTrack = obj.currentItem.track.name
    g.currentArtist = obj.currentItem.track.artist.name
    g.currentMetadata = obj
    g.metadata = obj post("metadata",g.id,{track=g.currentTrack,artist=g.currentArtist},color)
  end
  function eventMap.versionChanged(header,obj,color,con)
    if header.namespace == "favorites" then
      con:cmd({namespace="favorites",command="getFavorites",householdId=SELF.householdId},nil,function(header,obj)
        SELF.favorites = obj.items
        post("favoritesUpdated","",{n=#obj.items})
        done=done+1
      end)
    elseif header.namespace == "playlists" then
      con:cmd({namespace="playlists",command="getPlaylists",householdId=SELF.householdId},nil,function(header,obj)
        SELF.playlists = obj.playlists
        post("playlistsUpdated","",{n=#obj.playlists})
        done=done+1
      end)
    end
  end
  function eventMap.groups(header,obj) -- Groups changed
    local newCoordinators = {}
    local groups,players = {},{}
    self.players,self.groups,self.groupNames,self.playerNames=players,groups,LIST({}),LIST({})
    for _,player in ipairs(obj.players) do
      players[player.id] = {name=player.name, id=player.id, url=player.websocketUrl}
      players[player.name] = players[player.id]
      table.insert(self.playerNames,player.name)
    end
    for _,g in ipairs(obj.groups) do
      local coordinator = createCoordinator(players[g.coordinatorId].url)
      coordinator.groupId = g.id
      newCoordinators[players[g.coordinatorId].url] = true
      local group = {name=g.name, id=g.id, coordinator=coordinator, playerIds=g.playerIds}
      groups[g.id] = group
      groups[g.name] = group
      table.insert(self.groupNames,g.name)
      for _,playerId in ipairs(group.playerIds) do
        players[playerId].coordinator=coordinator
        players[playerId].groupId=group.id
      end
    end
    for url,c in pairs(coordinators) do
      if not newCoordinators[url] then c:close()
      elseif not c.isSubcribed then
        c:subscribe('groupId',c.groupId,"playback")
        c:subscribe('groupId',c.groupId,"groupVolume")
        c:subscribe('groupId',c.groupId,"playbackMetadata")
        c.isSubscribed = true
      end
    end
    post("groupsUpdated","",{groups=#self.groupNames,players=#self.playerNames})
    done = done+1
  end

  self._player=setmetatable({},{__index=function(self,name) local p = SELF.players[name] assert(p,"Player not found:"..name) return p end})
  self._group=setmetatable({},{__index=function(self,name) local g = SELF.groups[name] assert(g,"Group not found:"..name) return g end})

  local connection = createCoordinator(fmt("wss://%s:1443/websocket/api",IP))
  connection:send({namespace="households",command="getHouseholds"},nil,function(header,data)
    self.householdId = header.householdId
    connection:send({namespace="groups", command="subscribe", householdId = header.householdId},nil,function(header,obj)
      connection:send({namespace="favorites", command="subscribe", householdId = header.householdId},nil,function (header,obj)
        connection:send({namespace="playlists", command="subscribe", householdId = header.householdId})
      end)
    end)
  end)
end

----- Sonos commands
-- sonos:play(playerName)                  -- Start playing group that player belong to
-- sonos:pause(playerName)                 -- Pause group that player belong to
-- sonos:volume(playerName,volume)         -- Set volume to group that player belong to
-- sonos:togglePlayPause(playerName)       -- Toggle play/pause group that player belong to
-- sonos:skipToNextTrack(playerName)       -- Skip to next track in group that player belong to
-- sonos:skipToPreviousTrack(playerName)   -- Skip to previous track in group that player belong to
-- sonos:playFavorite(playerName,favorite) -- Play favorite on group that player belong to
-- sonos:playPlaylist(playerName,playlist) -- Play playlist on group that player belong to
-- sonos:playerVolume(playerName,volume)   -- Set volume to player
-- sonos:clip(playerName,url,volume)       -- Play audio clip on player
-- sonos:say(playerName,text,volume,lang)  -- Play TTS on player
-- sonos:playerGroup(playerName)           -- group that player belong to
-- sonos:playersInGroup(playerName)        -- players in group that player belong to
-- sonos:group(groupName,{playerNames,...})-- group players. TBD

function Sonos:clip(playerName,url,volume)
  local player = self._player[playerName]
  player.coordinator:cmd(
  {namespace="audioClip",playerId=player.id,command="loadAudioClip"},
  {name="SW",appId="com.xyz.sw",streamUrl=url,volume=volume}
)
end
function Sonos:say(playerName,text,volume,lang)
  local url=string.format("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=%s&q=%s",lang or "en",text:gsub("%s+","+"))
  self:clip(playerName,url,volume)
end
function Sonos:play(playerName)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playback",command="play",groupId=player.groupId})
end
function Sonos:pause(playerName)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playback",command="pause",groupId=player.groupId})
end
function Sonos:skipToNextTrack(playerName)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playback",command="skipToNextTrack",groupId=player.groupId})
end
function Sonos:skipToPreviousTrack(playerName)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playback", command="skipToPreviousTrack",groupId=player.groupId})
end
function Sonos:volume(playerName,volume)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="groupVolume",command="setVolume",groupId=player.groupId,volume=volume})
end
function Sonos:togglePlayPause(playerName)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playback", command="togglePlayPause",groupId=player.groupId})
end
local function find(list,val) for _,i in ipairs(list) do if i.name==val or i.id==val then return i.id end end end
function Sonos:playFavorite(playerName,favorite)
  __assert_type(favorite,'string')
  local favoriteId = find(self.favorites,favorite)
  if not favoriteId then error("Favorite not found: "..favorite) end
  local player = self._player[playerName]
  player.coordinator:cmd({
    groupId=player.groupId, namespace="favorites", command="loadFavorite"
  },{ favoriteId = favoriteId, playOnCompletion=true
})
end
function Sonos:playPlaylist(playerName,playlist)
  __assert_type(playlist,'string')
  local playlistId = find(self.playlists,playlist)
  if not playlistId then error("Playlist not found: "..playlist) end
  local player = self._player[playerName]
  player.coordinator:cmd({
    groupId=player.groupId, namespace="playlists", command="loadPlaylist"
  },{
    playlistId = playlistId, playOnCompletion=true
  })
end
function Sonos:playerVolume(playerName,volume)
  local player = self._player[playerName]
  player.coordinator:cmd({namespace="playerVolume",command="setVolume",playerId=player.id,volume=volume})
end
function Sonos:playerGroup(playerName) return self._group[self._player[playerName].groupId].name end
function Sonos:playersInGroup(groupName) return self._group[groupName].playersIds end
function Sonos:group(groupName,playerNames) end --TBD

-- Testing
local function delay(args)
  local t=0
  for i=1,#args,4 do
    local d,cond,f,doc=args[i],args[i+1],args[i+2],args[i+3]
    if cond then t=t+d setTimeout(f,1000*t) end
  end
end

function QuickApp:onInit()
  self:debug("onInit",self.name,self.id)
  local clip = "https://github.com/joepv/fibaro/raw/refs/heads/master/sonos-tts-example-eng.mp3"
  Sonos("192.168.1.225",function(sonos)
    self:debug("Sonos Ready")
    function sonos:eventHandler(event)
      print(event) -- Just print out events, could be used to ex. update UI
    end
    print("Players:",sonos.playerNames)
    print("Groups:",sonos.groupNames)
    local playerA = sonos.playerNames[1]
    local playerB = sonos.playerNames[2]
    local favorite1 = (sonos.favorites[1] or {}).name
    local playlist1 = (sonos.playlists[1] or {}).name
    delay{
      1,playerA,function() sonos:say(playerA,"Hello world",25) end, "TTS clip to player",
      2,playerB,function() sonos:say(playerB,"Hello world again",25) end, "TTS clip to player",
      2,playerA,function() sonos:clip(playerA,clip,25) end, "Audio clip to player with volume",
      2,playerA,function() sonos:play(playerA) end, "Play group that player belongs to",
      2,playerA,function() sonos:pause(playerA) end, "Pause group that player belongs to",
      2,playerB,function() sonos:play(playerB) end, "Play group that player belongs to",
      2,playerB,function() sonos:pause(playerB) end, "Pause group that player belongs to",
      2,playerB and favorite1,function() sonos:playFavorite(playerB,favorite1) end, "Play favorite in group that player belongs to",
      4,playerB,function() sonos:pause(playerB) end, "Pause group that player belongs to",
      4,playerB and playlist1,function() sonos:playPlaylist(playerB,playlist1) end, "Play favorite in group that player belongs to",
      4,playerB,function() sonos:pause(playerB) end, "Pause group that player belongs to",
    }
    -- sonos:volume("TV Room",vol) -- set volume to group that player belongs to
    -- sonos:playerVolume("TV Room",vol) -- set player volume
    local group = sonos:playerGroup("Kontor") -- get group that player belongs to
    local players = sonos:playersInGroup(sonos:playerGroup("Kontor")) -- get players in group
    sonos:group("MyGroup",{"Kontor","TV Room"}) -- group players
  end,{socket=true, noCmd7=true})
end
