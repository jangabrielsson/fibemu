COND =
{
    operator = "all",
    conditions = {
        {
            type = "global-variable",
            property = "A",
            operator = "==",
            value = "57",
            isTrigger = true
        },
        -- {
        --     type = "device",
        --     id = 25,
        --     property = "value",
        --     operator = "==",
        --     value = true,
        --     isTrigger = true
        -- },
        {
            operator = "all",
            conditions = { --Every day between 9:00 and 10:00.
                {
                    type = "date",
                    property = "cron",
                    operator = "match>=",
                    value = { "0", "9", "*", "*", "*", "*" }
                },
                {
                    type = "date",
                    property = "cron",
                    operator = "match<=",
                    value = { "05", "12", "*", "*", "*", "*" }
                }
            }
        }
    }
}

fibaro.debug(_sceneId, "Hello, the condition did match!")
setTimeout(function()
    fibaro.debug(_sceneId, "Hello2 -  one second later")
end, 1000)
print(sourceTrigger and json.encode(sourceTrigger))
