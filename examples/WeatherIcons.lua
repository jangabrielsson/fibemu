--%%name=Weather

--%%u={label='icon',text=''}

function QuickApp:onInit()
  self:debug('onInit')
  local a,b = api.get("/proxy?http://localhost:11112/assets/icon/weather/circle-set/1.svg")
  print(a,b)
  --self:loadIcon()
end