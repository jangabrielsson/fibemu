--%%name=QCTest
--%%type=com.fibaro.genericDevice
--%%proxy="QCTestProxy"
--%%file=lib/QwikChild2.lua,UI;
--%%debug=refresh:false

--%%u={{button='b1',text='Create',onReleased='btnCreateChild'},{button='b2',text='Remove children',onReleased='removeChildren'}}

function QuickApp:onInit()
  self:debug(self.name,self.id)
  local chs = self:getChildrenUidMap()
  self:loadExistingChildren(chs)
  for id,_ in pairs(self.childDevices) do 
    print("ID:",id)
  end
end

class 'MyChild'(QwikAppChild)
function MyChild:__init(dev)
  QwikAppChild.__init(self,dev)
  self:updateView("ss","options",{{text='A',type='option',value='A'}})
  self:updateView("sd","options",{{text='B',type='option',value='B'},{text='C',type='option',value='C'}})
end
function MyChild:fopp(ev)
  print(json.encode(ev))
  print("FOPP")
end
function MyChild:slide(ev)
  print(json.encode(ev))
  print("FOPPA")
end
function MyChild:select1(ev)
  print("SELS:",ev.values[1])
end
function MyChild:select2(ev)
  print("SELM:",json.encode(ev.values[1]))
end

local UI = {
  {{label='l1', text="MyLabel"},{button='b1', text='Click', onReleased='fopp'}},
  {slider='s1',text='Slider',onChanged='slide'},
  {select='ss',text='S1',onToggled='select1'},
  {multi='sd',text='S2',onToggled='select2'}
}
function QuickApp:btnCreateChild()
  self:createChild(
  "Id1",
  {
    type = 'com.fibaro.binarySensor',
    name = 'ChildA'
  },
  'MyChild',
  UI
)
end

function QuickApp:removeChildren()
  self:removeAllChildren()
end
