--%%name="MMQTT"
--%%type="com.fibaro.binarySwitch"

function QuickApp:onInit()
    self:debug(self.name,self.id)
    local function handleConnect(event)
        self:debug("connected: "..json.encode(event))
        self.client:subscribe("test/#",{qos=1})
        self.client:publish("test/blah", "test".. os.time(),{qos=1})
    end
    self.client = mqtt.Client.connect('mqtt://192.168.1.181', {port="1883",clientId="HC3"})
    self.client._debug = true
    self.client:addEventListener('published', function(event) self:debug("published: "..json.encode(event)) end)  
    self.client:addEventListener('message', function(event) self:debug("message: "..json.encode(event)) end)
    self.client:addEventListener('connected', handleConnect)
end