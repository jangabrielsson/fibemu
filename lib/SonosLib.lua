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
local TEST = true

class 'Sonos'
Sonos.VERSION = "0.86"
function Sonos:__init(IP,initcb,debugFlags)
  self.TIMEOUT = 30
  local colors = {'lightgreen','lightblue','yellow','orange','purple','pink','cyan','magenta','lime','red'}
  local coordinators,eventMap,n = {},{},0
  local SELF,fmt=self,string.format
  print(fmt("SonosLib %s (c)jan@gabrielsson.com",Sonos.VERSION))
  self.debug = debugFlags or {}
  
  local function map(f,l) for k,v in pairs(l) do f(v,k) end end
  local function LIST(t) return setmetatable(t,{__tostring=function() return table.concat(t,",") end}) end
  local function EVENT(str,ev) return setmetatable(ev,{__tostring=function() return str end}) end
  local function PLAYER(p) return setmetatable(p,{__tostring=function(p) return fmt("[%s:%s]",p.name,p.id) end}) end
  local function GROUP(g) return setmetatable(g,{__tostring=function(p) return fmt("[%s:%s]",p.name,p.id) end}) end
  local function Requests() -- Request queue with timeout handling
    local self,map,id = {},{},42
    function self:push(cb,data) local key=tostring(id) id=id+1
      local ref = setTimeout(function() print("TIMEOUT") cb({namespace=data.namespace,response=data.command,success=false},{reason='Timeout'}) map[key]=nil end,SELF.TIMEOUT*1000) -- Timeout
      map[key]={cb,ref} return key
    end
    function self:pop(key) local cb,ref = table.unpack(map[key] or {}) map[key]=nil if ref then clearTimeout(ref) end return cb end
    function self:cancelAll() for key in pairs(map) do self:pop(key) end end
    return self
  end
  
  local function createCoordinator(url)
    if coordinators[url] then return coordinators[url] end
    local connected,started,buffer,cbs = false,false,{},Requests()
    local self = {}
    local sock = net.WebSocketClientTls()
    local color = colors[n%#colors+1] n=n+1
    coordinators[url] = self
    
    local function colorize(col,str) return fmt('<font color="%s">%s</font>',col,str) end
    local function log(tag,fm,...) if SELF.debug[tag] then print(colorize(color,fmt(fm,...))) end end
    function self:log(...) log(...) end --export
    
    local function connect()
      log("socket","Connecting to %s",url)
      sock:connect(url, {
        ["X-Sonos-Api-Key"] = "123e4567-e89b-12d3-a456-426655440000",
        ["Sec-WebSocket-Protocol"] = "v1.api.smartspeaker.audio",
      })
    end
    
    local function dfltCmdLogger(header,obj)
      log("socket","Cmd: %s:%s %s",header.namespace,header.response,header.success and "OK" or colorize("red","FAILED"))
      if header.success == false then
        log("socket","Reason: %s",obj.reason or "")
      end
    end
    
    function self:send(data,opts,cb,nop)
      local cont = function()
        if nop then return end
        data.cmdId = cbs:push(cb or dfltCmdLogger,data)
        sock:send(json.encode({data,opts or {}}))
      end
      if connected then cont() 
      else 
        if not started then started=true connect() end
        buffer[#buffer+1] = cont
      end
    end
    
    function self:cmd(data,opts,cb) cb = cb or SELF._cbhook; SELF._cbhook=nil self:send(data,opts,cb,SELF.debug.noCmd) end
    
    function self:subscribe(resource,id,namespace,cb) self:send({[resource]=id,namespace=namespace,command="subscribe"},nil) end
    
    function self:getGroups(cb) self:cmd({householdId=SELF.householdId,namespace="groups",command="getGroups"},nil,cb) end
    function self:getFavorites(cb) self:cmd({householdId=SELF.householdId,namespace="favorites",command="getFavorites"},nil,cb) end
    function self:getPlaylists(cb) self:cmd({householdId=SELF.householdId,namespace="playlists",command="getPlaylists"},nil,cb) end
    
    function self:close() if connected then sock:close() log("socket","Close") cbs:cancelAll() connected=false coordinators[url]=nil end end
    
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
      if header.cmdId then
        local rcb = cbs:pop(header.cmdId)
        if rcb then rcb(header,obj) end
      elseif eventMap[header.type] then return eventMap[header.type](header,obj,color,self)
      else log("socket","Unknown event: %s",header.type) end
    end)

    sock:addEventListener("error", function(err) 
      fibaro.error(__TAG,"Sonos connection",err)
      SELF.post("connectionError","",{reason="Connection failed",url=url},"red")
    end)

    return self
  end
  
  local function post(typ,id,args,color)
    local name = (SELF.groups and SELF.groups[id] or SELF.players and SELF.players[id] or {name='Sonos'}).name
    color = color or "white"
    local str = fmt('<font color="%s">[%s:"%s",%s]</font>',color,typ,name,json.encode(args):sub(2,-2))
    args.type = typ
    if SELF.eventHandler then SELF.eventHandler(SELF,EVENT(str,args)) else print(str) end
  end
  self.post = post --export

  local players,groups = {},{}
  local function setupPlayers(_players)
    players = {} self.players = players self.playerNames = LIST({})
    for _,p in ipairs(_players) do
      local player = PLAYER({name=p.name, id=p.id, url=p.websocketUrl, coordinator=createCoordinator(p.websocketUrl)})
      player.softwareVersion = p.softwareVersion
      player.apiVersion = p.apiVersion
      player.minApiVersion = p.minApiVersion
      player.capabilities = p.capabilities
      players[p.id],players[p.name] = player,player
      table.insert(self.playerNames,p.name)
      players[p.id].coordinator:subscribe('playerId',p.id,"playerVolume")
    end
  end
  
  local function setupGroups(_groups)
    local oldGroups = groups groups = {} self.groups = groups self.groupNames = LIST({})
    for _,g in ipairs(_groups) do
      local coordinator = players[g.coordinatorId].coordinator
      local group = oldGroups[g.id]
      if not group then -- new group
        group = GROUP({name=g.name, id=g.id, coordinator=coordinator, playerIds=g.playerIds})
        table.insert(self.groupNames,g.name)
        group.coordinator:subscribe('groupId',group.id,"playback")
        group.coordinator:subscribe('groupId',group.id,"groupVolume")
        group.coordinator:subscribe('groupId',group.id,"playbackMetadata")
      end
      groups[g.id],groups[g.name] = group,group
      map(function(id) players[id].groupId=g.id players[id].group=group end,g.playerIds)
    end
    post("groupsUpdated","",{groups=#self.groupNames,players=#self.playerNames})
  end

  function eventMap.groupVolume(header,obj,color)
    local group = SELF.groups[header.groupId] if not group then return end
    group.volume,group.muted=obj.volume,obj.muted post("groupVolume",group.id,{volume=obj.volume,muted=obj.muted},color)
  end
  
  function eventMap.playerVolume(header,obj,color)
    local player = SELF.groups[header.playerId] if not player then return end
    player.volume,player.muted=obj.volume,obj.muted post("playerVolume",player.id,{volume=obj.volume,muted=obj.muted},color)
  end
  
  function eventMap.playbackStatus(header,obj,color)
    local status = obj.playbackState:match("_([%w]*)$"):lower()
    local group = SELF.groups[header.groupId] if not group then return end
    group.playModes = obj.playModes
    group.playModes._objectType = nil
    group.status = status post("playbackStatus",group.id,{status=status,modes=group.playModes},color)
  end
  
  function eventMap.playerVolume(header,obj,color)
    local player = self._player[header.playerId]
    player.volume = obj.volume post("playerVolume",player.id,{volume=obj.volume,muted=obj.muted},color)
  end
  
  function eventMap.metadataStatus(header,obj,color)
    local g = SELF.groups[header.groupId] if not g then return end
    g.currentTrack = obj.currentItem.track.name
    g.currentArtist = (obj.currentItem.track.artist or {}).name or ""
    g.currentMetadata = obj
    g.metadata = obj post("metadata",g.id,{track=g.currentTrack,artist=g.currentArtist},color)
  end
  
  function eventMap.versionChanged(header,obj,color,con)
    if header.namespace == "favorites" then
      con:getFavorites(function(header,obj)
        SELF.favorites = obj.items
        post("favoritesUpdated","",{n=#obj.items})
      end)
    elseif header.namespace == "playlists" then
      con:getPlaylists(function(header,obj)
        SELF.playlists = obj.playlists
        post("playlistsUpdated","",{n=#obj.playlists})
      end)
    end
  end
  
  -- Could probably use this to tear down group/coordinator
  function eventMap.groupCoordinatorChanged(header,obj,color,con) end
  function eventMap.groups(header,obj) -- Groups changed: rebuild coordinators, groups, players and subscriptions
    if setupGroups then setupGroups(obj.groups) end
  end
  
  self._player=setmetatable({},{__index=function(self,name) local p = SELF.players[name] assert(p,"Player not found:"..name) return p end})
  self._group=setmetatable({},{__index=function(self,name) local g = SELF.groups[name] assert(g,"Group not found:"..name) return g end})
  
  -- Start by getting the householdId, and subscribe to groups, favorites and playlists
  local connection = createCoordinator(fmt("wss://%s:1443/websocket/api",IP))
  connection:send({namespace="households",command="getHouseholds"},nil,function(header,data)
    self.householdId = header.householdId
    connection:log("socket","HouseholdId: %s",self.householdId)
    connection:getGroups(function(_,b)
      setupPlayers(b.players)
      setupGroups(b.groups)
      connection:getFavorites(function(_,b)
        self.favorites = b.items
        connection:getPlaylists(function(_,b)
          self.playlists = b.playlists
          connection:subscribe("householdId",self.householdId,"favorites")
          connection:subscribe("householdId",self.householdId,"playlists")
          connection:subscribe("householdId",self.householdId,"groups")
          if initcb then initcb(self) end
        end)
      end)
    end)
  end)
end

local function doCmd(self,rsrc,id,obj,ns,cmd,args)
  local msg = {namespace=ns,command=cmd,[rsrc]=id}
  --for k,v in pairs(args or {}) do msg[k]=v end
  obj.coordinator:cmd(msg,args)
end
local function doGroupCmd(self,playerName,ns,cmd,args) -- Cmds sent to group coordinator
  local group = self._player[playerName].group
  doCmd(self,'groupId',group.id,group,ns,cmd,args) 
end
local function doPlayerCmd(self,playerName,ns,cmd,args) -- Cmds sent to player directly
  local player = self._player[playerName]
  doCmd(self,'playerId',player.id,player,ns,cmd,args)
end
local function find(list,val) for _,i in ipairs(list) do if i.name==val or i.id==val then return i.id end end end

function Sonos:play(playerName) doGroupCmd(self,playerName,"playback","play") end
function Sonos:pause(playerName) doGroupCmd(self,playerName,"playback","pause") end
function Sonos:skipToNextTrack(playerName) doGroupCmd(self,playerName,"playback","skipToNextTrack") end
function Sonos:skipToPreviousTrack(playerName) doGroupCmd(self,playerName,"playback","skipToPreviousTrack") end
function Sonos:volume(playerName,volume) doGroupCmd(self,playerName,"groupVolume","setVolume",{volume=volume}) end
function Sonos:relativeVolume(playerName,delta) doGroupCmd(playerName,"groupVolume","setVolume",{volumeDelta=delta}) end
function Sonos:mute(playerName,state) doGroupCmd(self,playerName,"groupVolume","setMute",{muted=state~=false}) end
function Sonos:togglePlayPause(playerName) doGroupCmd(self,playerName,"playback","togglePlayPause") end
function Sonos:setModes(playerName,m)
  local modes = { ['repeat']=m['repeat'], shuffle=m.shuffle, crossfade=m.crossfade, repeatOne=m.repeatOne }
  doGroupCmd(self,playerName,"playback","setPlayModes",{playModes=modes}) 
end

function Sonos:playFavorite(playerName,favorite,action,modes)
  __assert_type(favorite,'string')
  local favoriteId = find(self.favorites,favorite)
  if not favoriteId then error("Favorite not found: "..favorite) end
  doGroupCmd(self,playerName,"favorites","loadFavorite",{favoriteId = favoriteId,playOnCompletion = true})
end
function Sonos:playPlaylist(playerName,playlist,action,modes)
  __assert_type(playlist,'string')
  local playlistId = find(self.playlists,playlist)
  if not playlistId then error("Playlist not found: "..playlist) end
  doGroupCmd(self,playerName,"playlists","loadPlaylist",{playlistId = playlistId, playOnCompletion=true}) 
end
function Sonos:playerVolume(playerName,volume) doPlayerCmd(self,playerName,"playerVolume","setVolume",{volume=volume}) end
function Sonos:playerMute(playerName,state) doPlayerCmd(self,playerName,"playerVolume","setMute",{muted=state~=false}) end
function Sonos:playerRelativeVolume(playerName,volume) doPlayerCmd(self,playerName,"playerVolume","setRelativeVolume",{volumeDelta=volume}) end
function Sonos:clip(playerName,url,volume) doPlayerCmd(self,playerName,"audioClip","loadAudioClip",{name="SW",appId="com.xyz.sw",streamUrl=url,volume=volume}) end
function Sonos:say(playerName,text,volume,lang)
  local url=string.format("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=%s&q=%s",lang or "en",text:gsub("%s+","+"))
  self:clip(playerName,url,volume)
end
function Sonos:playerGroup(playerName) return self._group[self._player[playerName].groupId].name end
function Sonos:playersInGroup(groupName) return self._group[groupName].playersIds end
function Sonos:createGroup(...)
  local playerIds,p = {},nil
  for _,playerName in ipairs({...}) do p=p or playerName table.insert(playerIds,self._player[playerName].id) end
  local group = self._player[p].group
  local msg = {namespace="groups",command="createGroup",householdId=self.householdId}
  group.coordinator:cmd(msg,{playerIds=playerIds,musicContextGroupId=group.id})
end
function Sonos:removeGroup(groupName)
  local group = self._group[groupName]
  local msg = {namespace="groups",command="modifyGroupMembers",groupId=group.id}
  group.coordinator:cmd(msg,{playerIdsToRemove=group.playerIds})
end
function Sonos:cb(cb) self._cbhook = cb return self end
function Sonos:getPlayerObject(playerName) return self._player[playerName] end
function Sonos:getGroupObject(groupName) return self._group[groupName] end
function Sonos:getPlayer(playerName)
  return setmetatable({},{
    __index=function(t,cmd) return function(...) self[cmd](self,playerName,...) end end
  })
end

------------------------- Test code -----------------------
if TEST then
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
    function Sonos:eventHandler(event)
      print(event) -- Just print out events, could be used to ex. update UI
    end
    Sonos("192.168.1.6",function(sonos)
      self:debug("Sonos Ready")
      print("Players:",sonos.playerNames)
      print("Groups:",sonos.groupNames)
      local playerA = sonos.playerNames[1]
      local playerB = sonos.playerNames[2]
      local PA = sonos:getPlayerObject(playerA)
      print("PlayerA:",PA.name,PA.id)
      local PB = sonos:getPlayerObject(playerB)
      print("PlayerB:",PB.name,PB.id)
      print("PB:",PB)
      local favorite1 = (sonos.favorites[1] or {}).name
      local playlist1 = (sonos.playlists[1] or {}).name
      print(("PlayerA='%s', PlayerB='%s'"):format(playerA,playerB))
      print(("Favorite1='%s', Playlist1='%s'"):format(favorite1,playlist1))
      local function callback(headers,data) -- not used
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
        -- 10,playerA,function() sonos:play(playerA) end, "Play group that playerA belongs to  (both players)",
        -- 4,playerA,function() sonos:removeGroup(sonos:playerGroup(playerA)) end, "Destroy group playerA belongs to",
        -- 4,playerA,function() sonos:play(playerA) end, "Play group that playerA belongs to (only playerA)",
      }
      -- sonos:volume(playerA,40) -- set volume to group that player belongs to
      -- sonos:playerVolume(playerA,30) -- set player volume
      -- local pl = sonos:getPlayer(playerA)
      -- pl:pause()
      -- local group = sonos:playerGroup(playerA) -- get group that player belongs to
      -- local players = sonos:playersInGroup(sonos:playerGroup(playerA)) -- get players in group
    end,{socket=true, _noCmd=true})
  end
end