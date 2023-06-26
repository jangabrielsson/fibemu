from fastapi import FastAPI, Body
from fastapi.responses import JSONResponse
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.responses import Response
from typing import Any, Dict, Optional, Tuple
from fastapi  import Depends
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
    {"name": "Weather methods", "description": "weather status"},
    {"name": "iosDevices methods", "description": "iosDevices info"},
    {"name": "Home methods", "description": "home info"},
    {"name": "DebugMessages methods", "description": "debugMessages info"},
    {"name": "Settings methods", "description": "settings info"},
    {"name": "Partition methods", "description": "partitions management"},
    {"name": "Alarm devices methods", "description": "alarm device management"},
    {"name": "NotificationCenter methods", "description": "notification management"},
    {"name": "Profiles methods", "description": "profiles management"},
    {"name": "Icons methods", "description": "icons management"},
    {"name": "Users methods", "description": "users management"},
    {"name": "Panels location methods", "description": "location management"},
    {"name": "Panels notifications methods", "description": "notifications management"},
    {"name": "Panels family methods", "description": "family management"},
    {"name": "Panels sprinklers methods", "description": "sprinklers management"},
    {"name": "Panels humidity methods", "description": "humidity management"},
    {"name": "Panels favoriteColors methods", "description": "favoriteColors management"},
    {"name": "Panels favoriteColors/V2 methods", "description": "favoriteColors/v2 management"},
    {"name": "Diagnostics methods", "description": "diagnostics info"},
 ]

app = FastAPI()
app.mount("/static", StaticFiles(directory=".vscode/emufiles/static"), name="static")
templates = Jinja2Templates(directory=".vscode/emufiles/templates")
def timectime(s):
    return datetime.fromtimestamp(s).strftime("%m/%d/%Y/%H:%M:%S") # datetime.datetime.fromtimestamp(s)
templates.env.filters['ctime'] = timectime

def prettyjson(s):
    return fibenv.get('fe').QA.prettyJson(json.dumps(s))
templates.env.filters['prettyjson'] = prettyjson

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

@app.post("/emu/dump", tags=["Emulator methods"])
async def emuDump(response: Response, fname: str = Body(...)):
    res,code = fibenv.get('fe').remoteCall("dumpResources",fname)
    response.status_code = code
    return res

@app.post("/emu/load", tags=["Emulator methods"])
async def emuLoad(response: Response, fname: str = Body(...)):
    res,code = fibenv.get('fe').remoteCall("loadResources",fname)
    response.status_code = code
    return res

''' Device methods '''
class ActionParams(BaseModel):
    args: list

@app.post("/api/devices/{id}/action/{name}", tags=["Device methods"])
async def callOnAction(id: int, name: str, args: ActionParams):
    t = time.time()
    fibenv.get('fe').postEvent({"type":"onAction","deviceId":id,"actionName":name,"args":json.dumps(args.args)})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class DeviceQueryModel(BaseModel):
    id: int | None = None
    parentId: int | None = None

def filterQuery(query: dict, d: dict):
    for k,v in query.items():
        if d[k] != v:
            return False
    return True

@app.get("/api/devices", tags=["Device methods"])
async def getDevices(response: Response, query: DeviceQueryModel = Depends()):
    vars,code = fibenv.get('fe').remoteCall("getResource","devices")
    query = query.dict(exclude_none=True)
    if len(query) > 0:
        res = [d for d in vars.values() if filterQuery(query,d)]
        response.status_code = 200
        return res
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/devices/{id}", tags=["Device methods"])
async def getDevice(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","devices",id)
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/devices/{id}", tags=["Device methods"])
async def deleteDevice(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteResource","devices",id)
    response.status_code = code
    return var if code < 300 else None

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
    return list(vars.values()) if code < 300 else None

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
    return list(vars.values()) if code < 300 else None

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
    return list(vars.values()) if code < 300 else None

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
    return list(vars.values()) if code < 300 else None

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
    return {} if code < 300 else None

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
async def callUIEvent(args: RestartDTO, response: Response):
    var,code = fibenv.get('fe').remoteCall("restartDevice",args.json())
    response.status_code = code
    return var if code < 300 else None

class ChildModel(BaseModel):
    deviceId: int
    childId: int
    childName: str
    childType: str
    childProperties: dict

@app.post("/api/plugins/createChildDevice", tags=["Plugins methods"])
async def createChildDevice(args: ChildModel, response: Response):
    var,code = fibenv.get('fe').remoteCall("createChildDevice",args.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/plugins/removeChildDevice/{id}", tags=["Plugins methods"])
async def deleteChildDevice(id: int, response: Response):
    var,code = fibenv.get('fe').remoteCall("deleteChildDevice",id)
    response.status_code = code
    return var if code < 300 else None

class EventModel(BaseModel):
    deviceId: int
    childId: int
    childName: str
    childType: str
    childProperties: dict

@app.post("/api/plugins/publishEvent", tags=["Plugins methods"])
async def callUIEvent(args: EventModel, response: Response):
    var,code = fibenv.get('fe').remoteCall("publishEvent",args.json())
    response.status_code = code
    return var if code < 300 else None

class DebugMessageModel(BaseModel):
    deviceId: int
    childId: int
    childName: str
    childType: str
    childProperties: dict
@app.post("/api/debugMessages", tags=["DebugMessages methods"])
async def callUIEvent(args: DebugMessageModel, response: Response):
    var,code = fibenv.get('fe').remoteCall("debugMessages",args.json())
    response.status_code = code
    return var if code < 300 else None

''' QuickApp methods '''
@app.get("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def getQuickAppFiles(id: int, response: Response):
    f,code = fibenv.get('fe').remoteCall("getQAfiles",id)
    response.status_code = code
    return f if code < 300 else None

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
    return f if code < 300 else None

@app.get("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def getQuickAppFile(id: int, name: str, response: Response):
    f,code = fibenv.get('fe').remoteCall("getQAfiles",id,name)
    response.status_code = code
    return f if code < 300 else None

@app.put("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def setQuickAppFile(id: int, name: str,response: Response):
    f,code = fibenv.get('fe').remoteCall("setQAfiles",id,name)
    response.status_code = code
    return f if code < 300 else None

@app.put("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def setQuickAppFiles(id: int, response: Response):
    f,code = fibenv.get('fe').remoteCall("setQAfiles",id)
    response.status_code = code
    return f if code < 300 else None

@app.get("/api/quickApp/export/{id}", tags=["QuickApp methods"])
async def getQuickAppFQA(id: int, response: Response):
    fqa,code = fibenv.get('fe').remoteCall("exportFQA",id)
    response.status_code = code
    return fqa if code < 300 else None

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
    return f if code < 300 else None

''' Weather methods '''
@app.get("/api/weather", tags=["Weather methods"])
async def getWeather(response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","weather")
    response.status_code = code
    return var if code < 300 else None

class WeatherParams(BaseModel):
    ConditionCode: float | None = None
    Humidity: float | None = None
    Temperature: float | None = None
    TemperatureUnit: str | None = None
    WeatherCondition: str | None = None
    WeatherConditionConverted: str | None = None
    Wind: float | None = None
    WindUnit: str | None = None

@app.put("/api/weather", tags=["Weather methods"])
async def putWeather(args: WeatherParams, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","weather",None,args.json())
    response.status_code = code
    return var if code < 300 else None

''' iosDevices methods '''
@app.get("/api/iosDevices", tags=["iosDevices methods"])
async def getiosDevices(response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","iosDevices")
    response.status_code = code
    return var if code < 300 else None

''' home methods '''
@app.get("/api/home", tags=["Home methods"])
async def getHome(response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","home")
    response.status_code = code
    return var if code < 300 else None

class DefaultSensorModel(BaseModel):
    light: int | None
    temperature: int | None
    humidity: int | None

class HomeParams(BaseModel):
    defaultSensors: DefaultSensorModel
    #meters	HomeDto_meters{...}
    #example: OrderedMap { "energy": List [ 11, 12, 13 ] }
    #notificationClient	HomeDto_notificationClient{...}
    #example: OrderedMap { "marketingNotificationAllowed": true }
    hcName:	str
    weatherProvider: int
    currency: str
    fireAlarmTemperature: int
    freezeAlarmTemperature: int
    timeFormat: int
    dateFormat: str
    firstRunAfterUpdate: bool

@app.put("/api/home", tags=["Home methods"])
async def putHome(args: HomeParams, response: Response):
    var,code = fibenv.get('fe').remoteCall("modifyResource","home",None,args.json())
    response.status_code = code
    return var if code < 300 else None

''' debugMessages methods '''
@app.get("/api/debugMessages", tags=["debugMessage methods"])
async def getdebugMessages(response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","debugMessages")
    response.status_code = code
    return var if code < 300 else None

''' settings methods '''
@app.get("/api/settings/{name}", tags=["Settings methods"])
async def getSettings(name: str, response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","settings/"+name)
    response.status_code = code
    return var if code < 300 else None

''' partition methods '''
@app.get("/api/alarms/v1/partitions", tags=["Partition methods"])
async def getPartitions(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","alarms/v1/partitions")
    response.status_code = code
    return list(items.values()) if code < 300 else None

@app.get("/api/alarms/v1/partitions/{id}", tags=["Partition methods"])
async def getPartitions(id: int, response: Response):
    item,code = fibenv.get('fe').remoteCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

''' alarm devices methods '''
@app.get("/api/alarms/v1/devices/", tags=["Alarm devices methods"])
async def getPartitions(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","alarms/v1/devices")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' notificationCenter methods '''
@app.get("/api/notificationCenter", tags=["NotificationCenter methods"])
async def getNotificationCenter(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","notificationCenter")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' profiles methods '''
@app.get("/api/profiles", tags=["Profiles methods"])
async def getProfiles(response: Response):
    var,code = fibenv.get('fe').remoteCall("getResource","profiles")
    response.status_code = code
    return var if code < 300 else None

''' icons methods '''
@app.get("/api/icons", tags=["Icons methods"])
async def getIcons(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","icons")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' users methods '''
@app.get("/api/users", tags=["Users methods"])
async def getUsers(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","users")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' energy devices methods '''
@app.get("/api/energy/devices", tags=["Energy devices methods"])
async def getEnergyDevices(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","energy/devices")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/location methods '''
@app.get("/api/panels/location", tags=["Panels location methods"])
async def getPanelsLocation(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/location")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/notification methods '''
@app.get("/api/panels/notifications", tags=["Panels notifications methods"])
async def getPanelsNotifications(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/notifications")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/family methods '''
@app.get("/api/panels/family", tags=["Panels family methods"])
async def getPanelsFamily(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/family")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/sprinklers methods '''
@app.get("/api/panels/sprinklers", tags=["Panels sprinklers methods"])
async def getPanelsSprinklers(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/sprinklers")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/humidity methods '''
@app.get("/api/panels/humidity", tags=["Panels humidity methods"])
async def getPanelsHumidity(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/humidity")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/favoriteColors methods '''
@app.get("/api/panels/favoriteColors", tags=["Panels favoriteColors methods"])
async def getFavoriteColors(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/favoriteColors")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/favoriteColors/v2 methods '''
@app.get("/api/panels/favoriteColors/v2", tags=["Panels favoriteColors/v2 methods"])
async def getFavoriteColorsV2(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","panels/favoriteColors/v2")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' diagnostics methods '''
@app.get("/api/diagnostics", tags=["Diagnostics methods"])
async def getDiagnostics(response: Response):
    items,code = fibenv.get('fe').remoteCall("getResource","diagnostics")
    response.status_code = code
    return list(items.values()) if code < 300 else None