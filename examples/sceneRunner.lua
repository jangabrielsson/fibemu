local sceneNames = {
    "examples/Scene_test.lua",
}

fibaro.fibemu.loadScenes(sceneNames) -- load scenes

fibaro.setGlobalVariable("A","57") -- trigger scene