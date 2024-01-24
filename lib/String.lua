
function string:fromHTML()
  local str = self:gsub("(</?font.->)", "")
  str = str:gsub("(&nbsp;)", " ") 
  return (str:gsub("</br>", "\n")) 
end

function string:toHTML()
  local  str = self:gsub("(%s)","&nbsp;")
  return (str:gsub("(\n)","</br>"))
end

