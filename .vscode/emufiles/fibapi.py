from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.responses import Response
from fastapi import status 
from fastapi import Request
from pydantic import BaseModel
from pydantic import typing
import time,json
from datetime import datetime

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
    {"name": "CustomEvents methods", "description": "managing custom events"},
    {"name": "RefreshStates methods", "description": "getting events"},
    {"name": "Plugins methods", "description": "plugin methods"},
    {"name": "QuickApp methods", "description": "managing QuickApps"},
]

app = FastAPI()
app.mount("/static", StaticFiles(directory=".vscode/emufiles/static"), name="static")
templates = Jinja2Templates(directory=".vscode/emufiles/templates")
def timectime(s):
    return datetime.fromtimestamp(s).strftime("%m/%d/%Y/%H:%M:%S") # datetime.datetime.fromtimestamp(s)
templates.env.filters['ctime'] = timectime

fibenv = dict()
fibenv['fe']=42
fibenv['app']=app

@app.get("/", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse("main.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/events", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse("events.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/globals", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse("globals.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/config", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse("config.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/about", response_class=HTMLResponse)
async def read_item(request: Request):
    return templates.TemplateResponse("about.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/info/qa/{id}", response_class=HTMLResponse)
async def read_item(id: int, request: Request):
    emu = fibenv.get('fe')
    qa = emu.DIR[id]
    return templates.TemplateResponse("infoqa.html", {"request": request, "emu": emu, "qa": qa})

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
    fibenv.get('fe').postEvent({"type":"onAction","deviceId":id,"actionName":name,"args":json.dumps(args.args)})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

''' GlobalVariables methods '''
class GlobalVarSpec(BaseModel):
    name: str | None = None
    value: str | None = None
    isEnum: bool | None = False
    readOnly: bool | None = False
    invokeScenes: bool | None = True

@app.get("/api/globalVariables", tags=["GlobalVariabes methods"])
async def getGlobalVariables(response: Response):
    vars,code = fibenv.get('fe').remoteCall("getResource","globalVariables")
    response.status_code = code
    return list(vars.items()) if code < 300 else None

@app.get("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def getGlobalVariable(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","globalVariables",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/globalVariables", tags=["GlobalVariabes methods"])
async def createGlobalVariable(data: GlobalVarSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("createResource","globalVariables",data.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def modifyGlobalVariable(name: str, data: GlobalVarSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","globalVariables",name,data.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def deleteGlobalVariable(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteResource","globalVariables",name)
    response.status_code = code
    return var if code < 300 else None

''' Rooms methods '''
class RoomSpec(BaseModel):
    id : int | None = None
    name: str | None = None
    sectionID: int | None = None
    category: str | None = None
    icon: str | None = None
    visible: bool | None = True

@app.get("/api/rooms", tags=["Rooms methods"])
async def getRoom(response: Response):
    vars,code = fibenv.get('fe').remoteCall("getResource","rooms")
    response.status_code = code
    return list(vars.items()) if code < 300 else None

@app.get("/api/rooms/{id}", tags=["Rooms methods"])
async def getRooms(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","rooms",id)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/rooms", tags=["Rooms methods"])
async def createRoom(room: RoomSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("createResource","rooms",room.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/rooms/{id}", tags=["Rooms methods"])
async def modifyRoom(id: int, room: RoomSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","rooms",id,room.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/rooms/{id}", tags=["Rooms methods"])
async def deleteRoom(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteResource","rooms",id)
    response.status_code = code
    return var if code < 300 else None

''' Sections methods '''
class SectionSpec(BaseModel):
    name: str | None = None
    id: int | None = None

@app.get("/api/sections", tags=["Sections methods"])
async def getSection(response: Response):
    vars,code = fibenv.get('fe').remoteCall("getResource","sections")
    response.status_code = code
    return list(vars.items()) if code < 300 else None

@app.get("/api/sections/{id}", tags=["Sections methods"])
async def getSections(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","sections",id)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/sections", tags=["Sections methods"])
async def createSection(section: SectionSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("createResource","sections",section.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/sections/{id}", tags=["Sections methods"])
async def modifySection(id: int, section: SectionSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","sections",id,section.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/sections/{id}", tags=["Sections methods"])
async def deleteSection(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteResource","sections",id)
    response.status_code = code
    return var if code < 300 else None

''' CustomEvent methods '''
class CustomEventSpec(BaseModel):
    name: str
    userDescription: str | None = ""

@app.get("/api/customEvents", tags=["CustomEvents methods"])
async def getCustomEvent(response: Response):
    vars,code = fibenv.get('fe').remoteCall("getResource","customEvents")
    response.status_code = code
    return list(vars.items()) if code < 300 else None

@app.get("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def getCustomEvents(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","customEvents",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/customEvents", tags=["CustomEvents methods"])
async def createCustomEvent(customEvent: CustomEventSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("createResource","customEvents",customEvent.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def modifyCustomEvent(name: str, customEvent: CustomEventSpec, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","customEvents",name,customEvent.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def deleteCustomEvent(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteResource","customEvents",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def deleteCustomEvent(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("emitCustomEvent",name)
    response.status_code = code
    return {},code

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
    fibenv.get('fe').remoteCall("updateDeviceProp",args.json())
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

class RestartDTO(BaseModel):
    deviceId: int
    
@app.post("/api/plugins/restart", tags=["Plugins methods"])
async def callUIEvent(args: RestartDTO):
    fibenv.get('fe').remoteCall("restartDevice",args.json())

''' QuickApp methods '''
@app.get("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def getQuickAppFiles(id: int, response: Response):
    f,code = fibenv.get('fe').remoteCall("getQAfiles",id)
    response.status_code = code
    return f

class QAFileParam(BaseModel):
    name: str
    isMain: bool
    content: str
    isOpen: bool | None = False
    type: str | None = "lua"

@app.post("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def postQuickAppFiles(id: int, file: QAFileParam, response: Response):
    f,code = fibenv.get('fe').remoteCall("setQAfiles",id,json.dumps(file.__dict__))
    response.status_code = code
    return f

@app.get("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def getQuickAppFile(id: int, name: str, response: Response):
    f,code = fibenv.get('fe').remoteCall("getQAfiles",id,name)
    response.status_code = code
    return f

@app.put("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def setQuickAppFile(id: int, name: str,response: Response):
    f,code = fibenv.get('fe').remoteCall("setQAfiles",id,name)
    response.status_code = code
    return f

@app.put("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def setQuickAppFiles(id: int, response: Response):
    f,code = fibenv.get('fe').remoteCall("setQAfiles",id)
    response.status_code = code
    return f

@app.get("/api/quickApp/export/{id}", tags=["QuickApp methods"])
async def getQuickAppFQA(id: int, response: Response):
    fqa,code = fibenv.get('fe').remoteCall("exportFQA",id)
    response.status_code = code
    return fqa

@app.post("/api/quickApp/", tags=["QuickApp methods"])
async def installQuickApp():
    t = time.time()
    fibenv.get('fe').postEvent({"type":"importFQA","file":""})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class QAImportData(BaseModel):
    file: str
    roomId : int | None = None
@app.post("/api/quickApp/import", tags=["QuickApp methods"])
async def installQuickApp(file: QAImportData, response: Response):
    t = time.time()
    fibenv.get('fe').postEvent({"type":"importFQA","file":file.file,"roomId":file.roomId})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.delete("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def deleteQuickAppFile(id: int, name: str, response: Response):
    f,code = fibenv.get('fe').remoteCall("deleteQAfile",id,name)
    response.status_code = code
    return f
