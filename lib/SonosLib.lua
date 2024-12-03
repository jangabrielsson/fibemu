---@diagnostic disable: undefined-global
--%%name=Sonos Test
--%%type=com.fibaro.binarySwitch
--%%var=IP:config.Sonos_IP
--%%var=API:config.Sonos_API
--%%var=SECRET:config.Sonos_Secret
--%%debug=refresh:false

fibaro.debugFlags = fibaro.debugFlags or {}
fibaro.debugFlags.test = true

local fmt = string.format
local function urlencode(str) -- very useful
  if str then
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w %-%_%.%~])", function(c)
      return ("%%%02X"):format(string.byte(c))
    end)
    str = str:gsub(" ", "%%20")
  end
  return str
end

local function __assert_type(value, typeOfValue)
  if type(value) ~= typeOfValue then
    error(fmt("Wrong parameter type, %s required. Provided param '%s' is type of %s",typeOfValue, tostring(value), type(value)),3)
  end
end

------------------- Group class ------------------------
--- groups can :setVolume, :play, :pause, :skipToNextTrack, :skipToPreviousTrack
class 'Group'
function Group:__init(sonos,data)
  self.id = data.id
  self.name = data.name
  self.coordinatorId = data.coordinatorId
  self.playerIds = data.playerIds
  self.sonos = sonos
  sonos:_subscribe('groupId',self.id,"playback:1")
  sonos:_subscribe('groupId',self.id,"groupVolume:1")
  sonos:_subscribe('groupId',self.id,"playbackMetadata:1")
end
local statusMap = {
  PLAYBACK_STATE_PLAYING = "playing",
  PLAYBACK_STATE_PAUSED = "paused",
  PLAYBACK_STATE_BUFFERING = "buffering",
  PLAYBACK_STATE_IDLE = "idle",
}
function Group:_setStatus(data)
  self.playbackState = statusMap[data.playbackState]
  self.sonos:_postEvent("PlaybackStatus",{ id=self.id, status=self.playbackState })
end
function Group:_setVolume(data)
  self.volume, self.muted  = data.volume, data.muted
  self.sonos:_postEvent("GroupVolume",{ id=self.id,volume=self.volume, muted=self.muted })
end
function Group:_setMetadata(data)
  self.currentTrack = data.currentItem.track.name
  self.currentArtist = data.currentItem.track.artist.name
  self.currentMetadata = data
  self.sonos:_postEvent("MetadataStatus",{ id=self.id, track=self.currentTrack, artist=self.currentArtist })
end
function Group:setVolume(volume)
  __assert_type(volume,'number')
  self.sonos:_send({ groupId=self.id, namespace="groupVolume", command="setVolume" },{ volume = volume })
end
function Group:play()
  self.sonos:_send({ groupId=self.id,namespace="playback", command="play" })
end
function Group:togglePlayPause()
  self.sonos:_send({ groupId=self.id, namespace="playback", command="togglePlayPause" })
end
function Group:playFavorite(favorite)
  __assert_type(favorite,'string')
  local favoriteId = self.sonos:findFavorite(favorite)
  if not favoriteId then return self.sonos:ERRORF("Favorite not found: %s",favoriteName) end
  self.sonos:_send({
    groupId=self.id, namespace="favorites", command="loadFavorite" 
  },{ favoriteId = favoriteId, playOnCompletion=true 
})
end
function Group:playPlaylist(playlist)
  __assert_type(playlist,'string')
  local playlistId = self.sonos:findPlayList(playlist)
  if not playlistId then return self.sonos:ERRORF("Playlist not found: %s",playlist) end
  self.sonos:_send({ 
    groupId=self.id, namespace="playlists", command="loadPlaylist" 
  },{ 
    playlistId = playlistId, playOnCompletion=true 
  })
end
function Group:pause()
  self.sonos:_send({ groupId=self.id, namespace="playback", command="pause" })
end
function Group:skipToNextTrack()
  self.sonos:_send({ groupId=self.id, namespace="playback", command="skipToNextTrack" })
end
function Group:skipToPreviousTrack()
  self.sonos:_send({ groupId=self.id, namespace="playback", command="skipToPreviousTrack" })
end
function Group:__tostring()
  return fmt("[Group:%s:%s]",self.name,self.id)
end
------------ End Group class ----------------------------

------------------- Player class ------------------------
--- players can :playClip, :playTTS, :setVolume
class 'Player'
function Player:__init(sonos,data)
  self.id = data.id
  self.name = data.name
  self.sonos = sonos
  sonos:_subscribe('playerId',self.id,"playerVolume:1")
end
function Player:_setVolume(data)
  self.volume, self.muted  = data.volume, data.muted
  self.sonos:_postEvent("PlayerVolume",{ id=self.id, volume=self.volume, muted=self.muted })
end
function Player:setVolume(volume)
  __assert_type(volume,'number')
  self.sonos:_send({
    playerId=self.id,
    namespace="playerVolume",
    command="setVolume",
  },{ volume = volume })
end
function Player:playClip(uri,volume)
  __assert_type(uri,'string')
  self.sonos:_send({
    playerId=self.id,
    namespace="audioClip",
    command="loadAudioClip",
  },{
    name = "Sonos Websocket",
    appId =  "com.gabrielsson.sonos_websocket",
    streamUrl = uri,
    volume = volume -- optional
  })
end

function Player:playTTS(args)
  __assert_type(args,'table')
  args.lang = args.lang or "en"
  local uri = fmt("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=%s&q=%s",args.lang,urlencode(args.text))
  self:playClip(uri,args.volume)
end

function Player:__tostring()
  return fmt("[Player:%s:%s]",self.name,self.id)
end
------------ End Player class ----------------------------

-------------------- Sonos class --------------------
--- contains groups, players, favorites, and playlists
local responders = {}

class 'Sonos'
function Sonos:__init(IP,API_KEY)
  __assert_type(IP,'string')
  __assert_type(API_KEY,'string')
  self.IP = IP
  self.API_KEY = API_KEY
  self.groups = {}
  self.players = {}
end

function Sonos:DEBUGF(tag,fmt,...) if fibaro.debugFlags[tag] then print(fmt:format(...)) end end
function Sonos:ERRORF(fmt,...) fibaro.error(__TAG,fmt:format(...)) end

local EVMT = { -- Event tostring function
__tostring = function(t)
  local tt,ti
  tt,ti,t.type,t.id = t.type,t.id,nil,nil
  local str = fmt("%s:%s %s",tt,ti,json.encode(t):sub(2,-2))
  t.type,t.id = tt,ti
  return str
end
}

function Sonos:_postEvent(typ,event)
  __assert_type(typ,'string')
  event.type = typ
  if self.eventHandler then self:eventHandler(setmetatable(event,EVMT)) end
end

function Sonos:_listen(connectCB)
  self:DEBUGF('test',"Websocket connect")
  local url = fmt("wss://%s:1443/websocket/api",self.IP)
  local headers = {
    ["X-Sonos-Api-Key"] = self.API_KEY,
    ["Sec-WebSocket-Protocol"] = "v1.api.smartspeaker.audio",
  }
  local function handleConnected(...)
    self:DEBUGF('test',"Connected")
    if connectCB then connectCB() end
  end

  local function handleDisconnected()
    self:DEBUGF('test',"Disconnected")
    self:warning("Disconnected - will restart in 5s")
    setTimeout(function()
      plugin.restart()
    end,5000)
  end
  local function handleError(err)
    self:ERRORF("Error: %s", err)
  end

  local eventHandler = {}
  function eventHandler.playbackStatus(header,obj)
    if self.groups[header.groupId] then self.groups[header.groupId]:_setStatus(obj) end
  end
  function eventHandler.groupVolume(header,obj)
    if self.groups[header.groupId] then self.groups[header.groupId]:_setVolume(obj) end
  end
  function eventHandler.playerVolume(header,obj)
    if self.players[header.playerId] then self.players[header.playerId]:_setVolume(obj) end
  end
  function eventHandler.metadataStatus(header,obj)
    if self.groups[header.groupId] then self.groups[header.groupId]:_setMetadata(obj) end
  end
  function eventHandler.versionChanged(header,obj)
    if header.namespace == "favorites" then
      self:_send({namespace="favorites",command="getFavorites",householdId=self.householdId})
    elseif header.namespace == "playlists" then
      self:_send({namespace="playlists",command="getPlaylists",householdId=self.householdId})
    end
  end
  function eventHandler.favoritesList(header,obj)
    self.favorites = obj.items
    self:_postEvent("FavoritesList",{id=self.householdId,n=#self.favorites})
  end
  function eventHandler.playlistsList(header,obj)
    self.playlists = obj.playlists
    self:_postEvent("PlaylistList",{id=self.householdId,n=#self.playlists})
  end

  local function handleDataReceived(data)
    --print(data)
    data = json.decode(data)
    local header,obj = data[1],data[2]
    if eventHandler[header.type] then eventHandler[header.type](header,obj) end
    local cb = responders[1]
    if cb and cb.cb then
      table.remove(responders,1)
      cb.cb(data)
    elseif header.success == false then
      self:ERRORF("Error: %s:%s",obj.errorCode,obj.reason)
    end
    if not cb then self:DEBUGF('test',"No responder %s",json.encode(data)) end
  end

  self.sock = net.WebSocketClient({verify_ssl=false})
  self.sock:addEventListener("connected", handleConnected)
  self.sock:addEventListener("disconnected", handleDisconnected)
  self.sock:addEventListener("error", handleError)
  self.sock:addEventListener("dataReceived", handleDataReceived)

  self:DEBUGF('test',"Connect: %s",url)
  self.sock:connect(url, headers)
end

function Sonos:_addGroup(group)
  self:DEBUGF('test',"Adding group: %s (%s)",group.name,group.id)
  local g = Group(self,group)
  self.groups[g.id] = g
end

function Sonos:_addPlayer(player)
  self:DEBUGF('test',"Adding player: %s (%s)",player.name,player.id)
  local p = Player(self,player)
  self.players[p.id] = p
end

function Sonos:_send(data,opts,cb)
  responders[#responders+1] = {cb=cb}
  data = {data,opts or {}}
  self.sock:send((json.encode(data)))
end
function Sonos:_subscribe(resource,id,namespace)
  self:_send({
    [resource]=id,
    namespace=namespace,
    command="subscribe",
  })
end

local function findItem(list,name)
  for _,item in ipairs(list) do
    if item.name == name or item.id == name then return item.id end
  end
end
function Sonos:findPlayList(playlist) return findItem(self.playlists,playlist) end
function Sonos:findFavorite(favorite) return findItem(self.favorites,favorite) end

function Sonos:init(cb)
  self:_listen(function()
    self:_send({},nil
    ,function(data)
      data = data[1]
      self.householdId = data.householdId
      self:_send({
        namespace="groups",
        command="getGroups",
        householdId=self.householdId
      },nil,function(data)
        self:_subscribe('householdId',self.householdId,"favorites")
        self:_subscribe('householdId',self.householdId,"playlists")
        local header,data = data[1],data[2]
        for _,group in ipairs(data.groups) do self:_addGroup(group) end
        for _,player in ipairs(data.players) do self:_addPlayer(player) end
        if cb then cb() end
      end)
    end)
  end)
end
------------- End Sonos class --------------------------

------------- Test code --------------------------------
function QuickApp:onInit()
  self:debug("Sonos Websocket test")

  local IP = self:getVariable("IP")
  local API_KEY = "123e4567-e89b-12d3-a456-426655440000"

  local sonos = Sonos(IP,API_KEY)

  sonos:init(function() -- Init Sonos player object
    print("Sonos object inited")
    for _,group in pairs(sonos.groups) do print(group) end -- Print groups
    for _,player in pairs(sonos.players) do print(player) end -- Print Players
    function sonos:eventHandler(event) -- Add event handler
      print("Event",event) -- Here we could update ex. the UI
    end
    setTimeout(function() -- Delay....
      local _,player = next(sonos.players) -- Get first player
      local _,group = next(sonos.groups)   -- Get first group
      --player:playClip("https://github.com/joepv/fibaro/raw/refs/heads/master/sonos-tts-example-eng.mp3")
      --player:playTTS{text="Hello again world",lang="en",volume=40}
      --group:setVolume(10)
      --player:setVolume(10)
      --group:playFavorite("Montecristo")
      --group:playPlaylist("Time Capsule2")
    end,3000)
  end)
end



