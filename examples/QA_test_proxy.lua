--[[
    Simple QA with UI elements
    creating and using a proxy QA on the HC3.
    First time run it creates a proxy QA on the HC3 with the
    UI defined in the %%u section - if any.
    If proxy already exists it will use the UI from the proxy QA on the HC3.
    This way the UI is defined and edited in the QA on the HC3.
    The proxy QA will send all events back to the emulated QA.
    The emulated QA will take on the ID of the proxy QA.
--]]

--%%name=My QA2
--%%type=com.fibaro.binarySwitch
--%%debug=permissions:false,refresh_resource:true

--%%u={{button='t1', text='A', onReleased='t1'},{button='t2', text='B', onReleased='t1'},{button='t3', text='C', onReleased='t1'},{button='t4', text='D', onReleased='t1'},{button='t5', text='E', onReleased='t1'}}
--%%u={button='test', text='Test', onReleased='testFun'}
--%%u={{button='test', text='A', onReleased='testA'},{button='test', text='B', onReleased='testB'}}
--%%u={slider="slider", max="80", onChanged='sliderA'}
--%%u={label="lblA", text='This is a text'}

function QuickApp:onInit()
    self:debug("Started", self.id)
    self:setVariable("test", "HELLO")
    fibaro.setGlobalVariable("A", "HELLO")
    setInterval(function()
        self:updateView("lblA", "text", os.date())
    end, 1000)

    local h = api.get('/devices/hierarchy',"hc3")
    local function printHierarchy(h)
        local res = {}
        local function pr(h, level, arrow)
            local hasChildren = h.children and #h.children > 0
            arrow = hasChildren and arrow:sub(1,-3).."+>" or arrow
            if level > 0 then
                res[#res+1]=string.format("%s%s",string.rep(' ', level), "|")
            end
            res[#res+1]=string.format("%s%s%s",string.rep(' ', level), arrow, h.type)
            if hasChildren then
                for _, c in ipairs(h.children) do
                    pr(c, level + 1, "+->")
                end
            end
        end
        pr(h,0,"-+->")
        --table.sort(res)
        print("Hierarchy:".."\n"..table.concat(res, "\n"))
    end

    --printHierarchy(h)
    local hd,map2 = {},{}
    local function traverse(h)
        if not h.children or #h.children==0 then return end
        local name = h.type
        map2[name] = true
        for _,c in ipairs(h.children) do
            map2[c.type] = true
            hd[#hd+1] = string.format('   "%s" -> "%s"', name, c.type)
            traverse(c)
        end
    end
    traverse(h)
    n=0
    for _,_ in pairs(map2) do n=n+1 end
    print("Nodes:", n)
    table.sort(hd)
    table.insert(hd, 1, "strict digraph tree {")
    table.insert(hd, 2, '   rankdir="LR";')
    table.insert(hd, "}")
    print("\n"..table.concat(hd, "\n"))
end

function QuickApp:testFun()
    self:debug("Test pressed")
end

function QuickApp:testA()
    self:debug("A pressed")
end

function QuickApp:testB()
    self:debug("B pressed")
end

function QuickApp:sliderA(ev)
    self:debug("Slide A", ev.values[1])
end

function QuickApp:turnOn()
    self:debug("Turned on")
    self:updateProperty("value", true)
    setTimeout(function() self:updateView("slider", "value", "10") end, 1000)
    setTimeout(function() self:updateView("slider", "value", "90") end, 5000)
end

function QuickApp:turnOff()
    self:debug("Turned off")
    self:updateProperty("value", false)
end