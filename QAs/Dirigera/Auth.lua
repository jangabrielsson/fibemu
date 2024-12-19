---------------------------------------------------------------
---  Authorization --------------------------------------------
---------------------------------------------------------------
local fmt = string.format

local function codeChallenge(codeVerifier)
  local hash = sha.sha256(codeVerifier)
  local binhash = sha.hex2bin(hash)
  local base64hash = sha.bin2base64(binhash)
  return base64hash
end

local function getToken(IP, code, codeVerifier, cb)
  local data = 
  "code="..urlencode(code)
  .."&name="..urlencode("127.0.0.1") ---fibaro.getIPaddress()
  .."&grant_type=authorization_code"
  .."&code_verifier="..urlencode(codeVerifier)
  local headers = { 
    ['Content-Type'] = "application/x-www-form-urlencoded;charset=UTF-8",
    --['Content-Length'] = #data
    --["Accept"] = "application/json"
  }
  local tokenURL = fmt("https://%s:8443/v1/oauth/token",IP)
  -- print(code)
  -- print(data)
  net.HTTPClient():request(tokenURL, {
    options = {
      method = 'POST',
      headers = headers,
      data = data,
      timeout = 10000,
      checkCertificate = false
    },
    success = function(response)
      local stat,res = pcall(json.decode,response.data)
      if not stat then
        ERRORF("Error get token: %s ", json.encode(response))
        return
      end
      local data = res
      cb(data.access_token)
    end,
    error = function(err)
      ERRORF("Error get token: %s", err)
    end
  })
end

local function sendChallenge(IP, codeVerifier)
  local authUrl = fmt("https://%s:8443/v1/oauth/authorize",IP)
  local params = "?audience=homesmart.local&response_type=code&code_challenge=%s&code_challenge_method=S256"
  local cc = codeChallenge(codeVerifier)
  cc = cc:sub(1, -2)
  params = fmt(params, cc)
  Hub.lastRequest = nil
  net.HTTPClient():request(authUrl..params, {
    options = {
      method = 'GET',
      headers = {
      },
      checkCertificate = false,
      timeout = 10000
    },
    success = function(response)
      local data = json.decode(response.data)
      if data == nil then 
        ERRORF("Error requesting token: %s", json.encode(response))
        return
      end
      print("Press the action button on the bottom of the Dirigera hub, then press QA button 'Get token'' ..." )
      Hub.lastRequest = { IP=IP, codeVerifier=codeVerifier, code=data.code}
      --getToken(IP, data.code, codeVerifier, cb)
    end,
    error = function(err)
      ERRORF("Error requesting token: %s", err)
    end
  })
end

function QuickApp:requestToken()
  local randomCode = {}
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  for i=1,128 do
    local n = math.random(1, #chars)
    randomCode[#randomCode+1] = chars:sub(n, n)
  end
  local codeVerifier = table.concat(randomCode)
  DEBUGF('test',"%s %s",#codeVerifier,codeVerifier)
  sendChallenge(Hub.IP, codeVerifier)
end

function QuickApp:getToken()
  local lastRequest = Hub.lastRequest
  if not lastRequest then
    ERRORF("No last request")
    return
  end
  getToken(Hub.lastRequest.IP, lastRequest.code, lastRequest.codeVerifier, function(token)
    DEBUGF('test',"Token %s",token)
    self.store.token = token
    plugin.restart()
  end)
end
