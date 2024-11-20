--%%name='BetterQA'
--%%type=com.fibaro.binarySwitch

--%%file=lib/BetterQA.lua,BetterQA;

QuickApp.translations = {
  en = {
    ["BetterQA"] = "Better QA",
  },
  sv = {
    ["BetterQA"] = "Bättre QA",
  }
}

function QuickApp:onInit()
  self.language='sv'
  self:debug(self.lng.BetterQA)
end