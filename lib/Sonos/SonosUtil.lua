-----https://my_sonos_ip:1443/api/v1/groups/groupId/favorites
  --"RINCON_38420B9E676C01400:3756136457"
  --/groups/RINCON_38420B9E676C01400:3756136457/favorites
  function urlencode(str) -- very useful
    if str then
      str = str:gsub("\n", "\r\n")
      str = str:gsub("([^%w %-%_%.%~])", function(c)
          return ("%%%02X"):format(string.byte(c))
        end)
      str = str:gsub(" ", "%%20")
    end
    return str	
  end

  --control/api/v1/groups/groupId/groupVolume
  local function httpCall(path,cb)
    local url = string.format("https://%s:1443/api/v1%s","192.168.1.225",path)
    net.HTTPClient():request(url,{
      options={
        headers={
          ["X-Sonos-Api-Key"]="123e4567-e89b-12d3-a456-426655440000",
          ["Content-Type"] ="application/json",
          -- ["Authorization"] = "Bearer <Access-Token>",
          ["Sec-WebSocket-Protocol"] = "v1.api.smartspeaker.audio",
        },
        method="GET",
        timeout = 10000,
        checkCertificate = false,
      },
      success=function(resp)
        cb(json.decode(resp.data))
      end,
      error=function(err) 
        print("Error",err,url) 
      end
    })
  end

  