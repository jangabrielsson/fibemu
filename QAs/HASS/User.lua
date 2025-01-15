-- Example of a user module, with own classes
function MODULE_1classes()

  class 'MyButton'(Button)
  function MyButton:__init()
    Button.__init(self)
  end

  HASS.classes.MyButton = {
    type = 'com.fibaro.Button',
  }
  
end
