--%%name=SonosTest
--%%var=ip:"192.168.1.6"
--%%file=lib/SonosLib.lua,SonosLib;

QuickApp.preloadSonos={ip="qvar:ip",debug={socket=true}}

function QuickApp:onInit()
  self:debug("Player")
  self.sonos:say("TV Room","Hello")
end