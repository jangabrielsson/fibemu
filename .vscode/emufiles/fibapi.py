from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.responses import Response
from fastapi import status
from pydantic import BaseModel
from pydantic import typing
import time,json

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
    fibenv.get('fe').postEvent({"type":"onAction","deviceId":id,"actionName":name,"args":args.args})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

''' GlobalVariables methods '''
@app.get("/api/globalVariables", tags=["GlobalVariabes methods"])
async def getGlobalVariables():
    vars,code = fibenv.get('fe').remoteCall("getResource","globalVariables")
    return list(vars.items())

@app.get("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def getGlobalVariable(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","globalVariables",name)
    if code == 404:
        response.status_code = status.HTTP_404_NOT_FOUND
    return var

class GlobalVarParams(BaseModel):
    name: str | None = None
    value: str | None = None
    isEnum: bool | None = False
    readOnly: bool | None = False
    invokeScenes: bool | None = True

@app.post("/api/globalVariables", tags=["GlobalVariabes methods"])
async def createGlobalVariable(data: GlobalVarParams):
    var,code = fibenv.get('fe').remoteCall("createGlobalVariable",json.dumps(data.__dict__))
    if code == 409: 
       return JSONResponse(
        status_code=409,
        content={"type": "ERROR","reason": "CONFLICT","message": "Resource already exists in the system"},
        )
    return var

@app.put("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def createGlobalVariable(name: str, data: GlobalVarParams):
    var,code = fibenv.get('fe').remoteCall("updateGlobalVariable",name,json.dumps(data.__dict__))
    if code == 404:
        response.status_code = status.HTTP_404_NOT_FOUND
    return var

@app.delete("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def createGlobalVariable(name: str):
    var,code = fibenv.get('fe').remoteCall("removeGlobalVariable",name)
    if code == 404:
        response.status_code = status.HTTP_404_NOT_FOUND
    return var

''' Rooms methods '''
@app.get("/api/rooms", tags=["Rooms methods"])
async def getRooms():
    vars = fibenv.get('fe').remoteCall("getResource","rooms")
    return list(vars.items())

@app.get("/api/rooms/{id}", tags=["Rooms methods"])
async def getRooms(id: int):
    var = fibenv.get('fe').remoteCall("getResource","rooms",id)
    return var

''' Sections methods '''
@app.get("/api/sections", tags=["Sections methods"])
async def getSections():
    vars = fibenv.get('fe').remoteCall("getResource","sections")
    return list(vars.items())

@app.get("/api/sections/{id}", tags=["Sections methods"])
async def getSections(id: int):
    var = fibenv.get('fe').remoteCall("getResource","sections",id)
    return var

''' Plugins methods '''
@app.get("/api/plugins/callUIEvent", tags=["Plugins methods"])
async def callUIEvent(deviceID: int, eventType: str, elementName: str, value: str):
    t = time.time()
    fibenv.get('fe').postEvent({"type":"uiEvent","deviceId":deviceID,"eventType":eventType,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class UpdatePropertyParams(BaseModel):
    deviceId: int
    propertyName: str
    value: typing.Any

@app.post("/api/plugins/updateProperty", tags=["Plugins methods"])
async def callUIEvent(args: UpdatePropertyParams):
    t = time.time()
    fibenv.get('fe').remoteCall("updateDeviceProp",json.dumps(args.__dict__))
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class UpdateViewParams(BaseModel):
    deviceId: int
    componentName: str
    propertyName: str
    newValue: str
@app.post("/api/plugins/updateView", tags=["Plugins methods"])
async def callUIEvent(args: UpdateViewParams):
    t = time.time()
    event = dict(args.__dict__)
    event['type'] = 'updateView'
    fibenv.get('fe').postEvent(event)
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

''' QuickApp methods '''
@app.get("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def getQuickAppFiles(id: int):
    f = fibenv.get('fe').remoteCall("getQAfiles",id)
    return f

@app.post("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def postQuickAppFiles(id: int):
    f = fibenv.get('fe').remoteCall("setQAfiles",id)
    return f

@app.get("/api/quickApp/{id}/files/{name}}", tags=["QuickApp methods"])
async def getQuickAppFile(id: int, name: str):
    f = fibenv.get('fe').remoteCall("getQAfiles",id,name)
    return f

@app.put("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def setQuickAppFile(id: int, name: str):
    f = fibenv.get('fe').remoteCall("setQAfiles",id,name)
    return f

@app.put("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def setQuickAppFiles(id: int):
    f = fibenv.get('fe').remoteCall("setQAfiles",id)
    return f

@app.get("/api/quickApp/export/{id}", tags=["QuickApp methods"])
async def getQuickAppFQA(id: int):
    fqa = fibenv.get('fe').remoteCall("exportFQA",id)
    return fqa

@app.post("/api/quickApp/", tags=["QuickApp methods"])
async def installQuickApp():
    t = time.time()
    fibenv.get('fe').postEvent({"type":"importQA","file":""})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.delete("/api/quickApp/{id}/files/{name}}", tags=["QuickApp methods"])
async def deleteQuickAppFile(id: int, name: str):
    f = fibenv.get('fe').remoteCall("deleteQAfile",id,name)
    return f
