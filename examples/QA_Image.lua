--%%name=ImageQA
--%%type=com.fibaro.genericDevice
--%%u={label="label1", text='Image paceholder'}

--%%image=examples/dog.png,dog

function QuickApp:onInit()
  local image = _IMAGES['dog']
  local d = string.format('<img alt="Dog" src="%s"/>',image.data)
  print("Image size",image.w,image.h)
  self:updateView('label1','text',d)
end