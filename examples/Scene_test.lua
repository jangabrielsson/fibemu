COND =
{
    operator = "any",
    conditions = {
        {
            type = "global-variable",
            property = "A",
            operator = "==",
            value = "57",
            isTrigger = true
        },
        {
            type = "device",
            id = 25,
            property = "value",
            operator = "==",
            value = true,
            isTrigger = true
        },
        {
            operator = "any",
            conditions = {
                {
                    type = "device",
                    id = 26,
                    property = "value",
                    operator = "==",
                    value = true,
                    isTrigger = true
                },
                {
                    type = "device",
                    id = 27,
                    property = "value",
                    operator = "==",
                    value = true,
                    isTrigger = true
                }
            }
        }
    }
}

fibaro.debug(_sceneId,"Hello")
setTimeout(function()
    fibaro.debug(_sceneId,"Hello2")
end,1000)
print("OK")
print(sourceTrigger and json.encode(sourceTrigger))