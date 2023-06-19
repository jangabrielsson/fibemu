from fastapi import FastAPI
from pydantic import BaseModel
import time

from fastapi.openapi.docs import (
    get_redoc_html,
    get_swagger_ui_html,
    get_swagger_ui_oauth2_redirect_html,
)
from fastapi.staticfiles import StaticFiles

tags_metadata = [
    {"name": "Emulator methods", "description": "Probe the emulator"},
    {"name": "Device methods", "description": "Device and QuickApp methods"},
    {"name": "GlobalVariabes methods", "description": "managing global variables"},
    {"name": "Rooms methods", "description": "managing rooms"},
    {"name": "Section methods", "description": "managing sections"},
    {"name": "RefreshStates methods", "description": "getting events"},
    {"name": "Plugins methods", "description": "plugin methods"},
    {"name": "QuickApp methods", "description": "managing QuickApps"},
]

app = FastAPI()
app.mount("/static", StaticFiles(directory=".vscode/emufiles/static"), name="static")

fibenv = dict()
fibenv['fe']=42
fibenv['app']=app

''' Emulator methods '''
@app.get("/", tags=["Emulator methods"])
async def root():
    return {"message": "Hello from FibEmu!"}

''' Device methods '''
class ActionParams(BaseModel):
    args: list

@app.post("/api/devices/{id}/action/{name}", tags=["Device methods"])
async def callOnAction(id: int, name: str, args: ActionParams):
    t = time.time()
    fibenv.get('fe').onAction({"deviceId":id,"actionName":name,"args":args.args})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

''' GlobalVariables methods '''
@app.get("/api/globalVariables", tags=["GlobalVariabes methods"])
async def getGlobalVariables():
    vars = fibenv.get('fe').getResource("globalVariables")
    return list(vars.items())

@app.get("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def getGlobalVariable(name: str):
    var = fibenv.get('fe').getResource("globalVariables",name)
    return var

class GlobalVarParams(BaseModel):
    name: str
    value: str | None = None
@app.post("/api/globalVariables", tags=["GlobalVariabes methods"])
async def createGlobalVariable(data: GlobalVarParams):
    var = fibenv.get('fe').createResource("globalVariables",data)
    return var

''' Rooms methods '''
@app.get("/api/rooms", tags=["Rooms methods"])
async def getRooms():
    vars = fibenv.get('fe').getResource("rooms")
    return list(vars.items())

''' Sections methods '''
@app.get("/api/sections", tags=["Sections methods"])
async def getSections():
    vars = fibenv.get('fe').getResource("sections")
    return list(vars.items())

''' Plugins methods '''
@app.get("/api/plugins/callUIEvent", tags=["Plugins methods"])
async def callUIEvent(deviceID: int, eventType: str, elementName: str, value: str):
    t = time.time()
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

''' QuickApp methods '''
@app.get("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def getQuickAppFiles(id: int):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.post("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def postQuickAppFiles(id: int):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.get("/api/quickApp/{id}/files/{name}}", tags=["QuickApp methods"])
async def getQuickAppFile(id: int, name: str):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.put("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def setQuickAppFile(id: int, name: str):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.put("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def setQuickAppFiles(id: int):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.get("/api/quickApp/export/{id}", tags=["QuickApp methods"])
async def getQuickAppFQA(id: int):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.post("/api/quickApp/", tags=["QuickApp methods"])
async def installQuickApp():
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.delete("/api/quickApp/{id}/files/{name}}", tags=["QuickApp methods"])
async def deleteQuickAppFile(id: int, name: str):
    fibenv.get('fe').onUIEvent({"deviceId":deviceID,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }
