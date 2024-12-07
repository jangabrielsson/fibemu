--[[
Sonos code lib for the Fibaro Home Center 3
Copyright (c) 2024 Jan Gabrielsson
Email: jan@gabrielsson.com
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.
--]]

---@diagnostic disable: undefined-global
--%%name=Sonos

----- Sonos commands
-- sonos:play(playerName)                  -- Start playing group that player belong to
-- sonos:pause(playerName)                 -- Pause group that player belong to
-- sonos:volume(playerName,volume)         -- Set volume to group that player belong to
-- sonos:relativeVolume(playerName,delta)  -- Set relative volume to group that player belong to
-- sonos:mute(playerName,state)            -- Mute group that player belong to
-- sonos:togglePlayPause(playerName)       -- Toggle play/pause group that player belong to
-- sonos:skipToNextTrack(playerName)       -- Skip to next track in group that player belong to
-- sonos:skipToPreviousTrack(playerName)   -- Skip to previous track in group that player belong to
-- sonos:playFavorite(playerName,favorite,action,modes) -- Play favorite on group that player belong to
-- sonos:playPlaylist(playerName,playlist,action,modes) -- Play playlist on group that player belong to
-- sonos:playerVolume(playerName,volume)   -- Set volume of player
-- sonos:playerRelativeVolume(playerName,delta)         -- Set relative volume of player
-- sonos:playerMute(playerName,state)      -- Mute player
-- sonos:clip(playerName,url,volume)       -- Play audio clip on player
-- sonos:say(playerName,text,volume,lang)  -- Play TTS on player
-- sonos:playerGroup(playerName)           -- group that player belong to
-- sonos:playersInGroup(playerName)        -- players in group that player belong to
-- sonos:createGroup(playerNames,...)      -- group players.
-- sonos:removeGroup(groupName)            -- remove group. Ex. sonos:removeGroup(sonos:playerGroup(playerName))
-- sonos:getPlayer(playerName)             -- Get player object. Ex. p = sonos:getPlayer(playerName); p:pause()
-- sonos:cb(cb)                            -- Set callback function. Ex. sonos:cb(function(h,data) print(event) end):pause(playerName)

class 'Sonos'
Sonos.VERSION = "0.8"
function Sonos:__init(IP,initcb,debugFlags)
  local colors = {'green','blue','yellow','red','orange','purple','pink','cyan','magenta','lime'}
  local coordinators,eventMap,n = {},{},0
  local SELF,fmt=self,string.format
  print(fmt("SonosLib %s (c)jan@gabrielsson.com",Sonos.VERSION))
  self.debug = debugFlags or {}
  local function LIST(t) return setmetatable(t,{__tostring=function() return table.concat(t,",") end}) end
  local function keyedQueue()
    local self = { map={} }
    function self:push(key,val) self.map[key]=self.map[key] or {}; table.insert(self.map[key],val) end
    function self:pop(key) if self.map[key] then return table.remove(self.map[key],1) end end
    return self
  end
  local done = 0
  local function initDone() done=done+1 if done==3 then initcb(SELF) end end
  local function createCoordinator(url)
    if coordinators[url] then return coordinators[url] end
    local connected,buffer,cbs = false,{},keyedQueue()
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
        cbs:push(tag,cb or function() end)
        sock:send(json.encode({data,opts or {}}))
      end
      if connected then cont() else buffer[#buffer+1] = cont end
    end
    function self:cmd(data,opts,cb) cb = cb or SELF._cbhook; SELF._cbhook=nil self:send(data,opts,cb,debugFlags.noCmd) end
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
      local rcb = cbs:pop(tag)
      if rcb then log("socket","Rec: %s %s",tag,header.success) return rcb(header,obj) end
      if eventMap[header.type] then return eventMap[header.type](header,obj,color,self) end
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
        initDone()
      end)
    elseif header.namespace == "playlists" then
      con:cmd({namespace="playlists",command="getPlaylists",householdId=SELF.householdId},nil,function(header,obj)
        SELF.playlists = obj.playlists
        post("playlistsUpdated","",{n=#obj.playlists})
        initDone()
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
    initDone()
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

local function doCmd(self,rsrc,id,playerName,ns,cmd,args)
  local player = self._player[playerName]
  local msg = {namespace=ns,command=cmd,[rsrc]=player[id]}
  for k,v in pairs(args or {}) do msg[k]=v end
  player.coordinator:cmd(msg,nil)
end
local function doGroupCmd(self,playerName,ns,cmd,args) doCmd(self,'groupId','groupId',playerName,ns,cmd,args) end
local function doPlayerCmd(self,playerName,ns,cmd,args) doCmd(self,'playerId','id',playerName,ns,cmd,args) end
function Sonos:play(playerName) doGroupCmd(self,playerName,"playback","play") end
function Sonos:pause(playerName) doGroupCmd(self,playerName,"playback","pause") end
function Sonos:skipToNextTrack(playerName) doGroupCmd(self,playerName,"playback","skipToNextTrack") end
function Sonos:skipToPreviousTrack(playerName) doGroupCmd(self,playerName,"playback","skipToPreviousTrack") end
function Sonos:volume(playerName,volume) doGroupCmd(self,playerName,"groupVolume","setVolume",{volume=volume}) end
function Sonos:relativeVolume(playerName,delta) doGroupCmd(playerName,"groupVolume","setVolume",{volumeDelta=delta}) end
function Sonos:mute(playerName,state) doGroupCmd(self,playerName,"groupVolume","mute",{muted=state~=false}) end
function Sonos:togglePlayPause(playerName) doGroupCmd(self,playerName,"playback","togglePlayPause") end

local function find(list,val) for _,i in ipairs(list) do if i.name==val or i.id==val then return i.id end end end
function Sonos:playFavorite(playerName,favorite,action,modes)
  __assert_type(favorite,'string')
  local favoriteId = find(self.favorites,favorite)
  if not favoriteId then error("Favorite not found: "..favorite) end
  local player = self._player[playerName]
  player.coordinator:cmd(
  {groupId=player.groupId, namespace="favorites", command="loadFavorite"},{favoriteId = favoriteId, playOnCompletion=true}
)
end
function Sonos:playPlaylist(playerName,playlist,action,modes)
  __assert_type(playlist,'string')
  local playlistId = find(self.playlists,playlist)
  if not playlistId then error("Playlist not found: "..playlist) end
  local player = self._player[playerName]
  player.coordinator:cmd({groupId=player.groupId, namespace="playlists", command="loadPlaylist"},{playlistId = playlistId, playOnCompletion=true})
end
function Sonos:playerVolume(playerName,volume) doPlayerCmd(self,playerName,"playerVolume","setVolume",{volume=volume}) end
function Sonos:playerMute(playerName,state) doPlayerCmd(self,playerName,"playerVolume","setMute",{muted=state~=false}) end
function Sonos:playerRelativeVolume(playerName,volume) doPlayerCmd(self,playerName,"playerVolume","setRelativeVolume",{volumeDelta=volume}) end
function Sonos:clip(playerName,url,volume)
  local player = self._player[playerName]
  player.coordinator:cmd(
  {namespace="audioClip",playerId=player.id,command="loadAudioClip"},{name="SW",appId="com.xyz.sw",streamUrl=url,volume=volume}
)
end
function Sonos:say(playerName,text,volume,lang)
  local url=string.format("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=%s&q=%s",lang or "en",text:gsub("%s+","+"))
  self:clip(playerName,url,volume)
end
function Sonos:playerGroup(playerName) return self._group[self._player[playerName].groupId].name end
function Sonos:playersInGroup(groupName) return self._group[groupName].playersIds end
function Sonos:createGroup(...)
  local playerIds,p = {},nil
  for _,playerName in ipairs({...}) do p=p or playerName table.insert(playerIds,self._player[playerName].id) end
  local player = self._player[p]
  local msg = {namespace="groups",command="createGroup",householdId=self.householdId}
  player.coordinator:cmd(msg,{playerIds=playerIds,musicContextGroupId=player.groupId})
end
function Sonos:removeGroup(groupName)
  local group = self._group[groupName]
  local msg = {namespace="groups",command="modifyGroupMembers",groupId=group.id}
  group.coordinator:cmd(msg,{playerIdsToRemove=group.playerIds})
end
function Sonos:cb(cb) self._cbhook = cb return self end
function Sonos:getPlayer(playerName)
  return setmetatable({},{
    __index=function(t,cmd) return function(...) self[cmd](self,playerName,...) end end
  })
end

-- Testing
local function delay(args)
  local t=0
  for i=1,#args,4 do
    local d,cond,f,doc=args[i],args[i+1],args[i+2],args[i+3]
    local function f0() print(">"..doc) f() end
    if cond then t=t+d setTimeout(f0,1000*t) end
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
    print(("PlayerA='%s', PlayerB='%s'"):format(playerA,playerB))
    print(("Favorite1='%s', Playlist1='%s'"):format(favorite1,playlist1))
    local function callback(headers,data)
      print("Callback",headers,data)
    end
    delay{
      -- 1,playerA,function() sonos:say(playerA,"Hello world",25) end, "TTS clip to player",
      -- 2,playerB,function() sonos:say(playerB,"Hello world again",25) end, "TTS clip to player",
      -- 2,playerA,function() sonos:clip(playerA,clip,25) end, "Audio clip to player with volume",
      -- 2,playerA,function() sonos:play(playerA) end, "Play group that player belongs to",
      -- 2,playerA,function() sonos:pause(playerA) end, "Pause group that player belongs to",
      -- 2,playerB,function() sonos:play(playerB) end, "Play group that player belongs to",
      --2,playerB,function() sonos:cb(callback):pause(playerB) end, "Pause group that player belongs to",
      -- 2,playerB and favorite1,function() sonos:playFavorite(playerB,favorite1) end, "Play favorite in group that player belongs to",
      -- 4,playerB,function() sonos:pause(playerB) end, "Pause group that player belongs to",
      -- 4,playerB and playlist1,function() sonos:playPlaylist(playerB,playlist1) end, "Play favorite in group that player belongs to",
      -- 4,playerB,function() sonos:pause(playerB) end, "Pause group that player belongs to",
      -- 5,playerA and playerB,function() sonos:createGroup(playerB,playerA) end, "Create group with players",
      -- 10,playerA,function() sonos:play(playerA) end, "Play both players in group",
      -- 4,playerA,function() sonos:destroyGroup(sonos:playerGroup(playerA)) end, "Destroy group player belongs to",
      -- 4,playerA,function() sonos:play(playerA) end, "Player group that player belongs to",
    }
    -- sonos:volume(playerA,40) -- set volume to group that player belongs to
    -- sonos:playerVolume(playerA,30) -- set player volume
    -- local pl = sonos:getPlayer(playerA)
    -- pl:pause()
    -- local group = sonos:playerGroup(playerA) -- get group that player belongs to
    -- local players = sonos:playersInGroup(sonos:playerGroup(playerA)) -- get players in group
  end,{socket=true, _noCmd=true})
end
