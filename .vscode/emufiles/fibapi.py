from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware  # NEW
import logging
from fastapi.responses import JSONResponse
from fastapi.responses import HTMLResponse
from fastapi.responses import FileResponse
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates
from fastapi.responses import Response
from fastapi.openapi.utils import get_openapi
from typing import Any, Dict, List, Optional, Tuple
from fastapi  import Depends
from fastapi import status 
from fastapi import Request
from pydantic import BaseModel
from pydantic import Field
from pydantic import typing
import time,json,sys
from datetime import datetime
from fibenv import convertLuaTable

from fastapi.openapi.docs import (
    get_redoc_html,
    get_swagger_ui_html,
    get_swagger_ui_oauth2_redirect_html,
)
from fastapi.staticfiles import StaticFiles

class EndpointFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        return record.getMessage().find("/refreshStates") == -1

#Filter out /endpoint
logging.getLogger("uvicorn.access").addFilter(EndpointFilter())

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

app = FastAPI(openapi_tags=tags_metadata, swagger_ui_parameters = {"docExpansion":"none"})
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def my_schema():
   DOCS_TITLE = "Fibemu API"
   DOCS_VERSION = "0.2"
   openapi_schema = get_openapi(
       title=DOCS_TITLE,
       version=DOCS_VERSION,
       routes=app.routes,
   )
   openapi_schema["info"] = {
       "title" : DOCS_TITLE,
       "version" : DOCS_VERSION,
       "description" : "HC3 compatible API for Fibaro Home Center 3 emulator",
       "termsOfService": "https://forum.fibaro.com/topic/66394-visual-studio-code-vscode-for-quickapp-development/",
       "contact": {
           "name": "Get Help with this API",
           "url": "https://forum.fibaro.com/topic/66394-visual-studio-code-vscode-for-quickapp-development/",
          ## "email": 
       },
       "license": {
           "name": "Apache 2.0",
           "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
       },
   }
   app.openapi_schema = openapi_schema
   return app.openapi_schema

app.openapi = my_schema

app.mount("/static", StaticFiles(directory=".vscode/emufiles/static"), name="static")
app.mount("/frontend", StaticFiles(directory=".vscode/emufiles/frontend/dist"), name="frontend")
app.mount("/assets", StaticFiles(directory=".vscode/emufiles/frontend/dist/assets"), name="frontend")

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

@app.get("/", response_class=HTMLResponse,include_in_schema=False)
async def read_item1(request: Request):
    return templates.TemplateResponse("main.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/events", response_class=HTMLResponse,include_in_schema=False)
async def read_item2(request: Request):
    return templates.TemplateResponse("events.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/globals", response_class=HTMLResponse,include_in_schema=False)
async def read_item3(request: Request):
    return templates.TemplateResponse("globals.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/config", response_class=HTMLResponse,include_in_schema=False)
async def read_item4(request: Request):
    return templates.TemplateResponse("config.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/about", response_class=HTMLResponse,include_in_schema=False)
async def read_item5(request: Request):
    return templates.TemplateResponse("about.html", {"request": request, "emu": fibenv.get('fe')})

@app.get("/js/{file}", response_class=HTMLResponse,include_in_schema=False)
async def read_item6(file,request: Request):
    return templates.TemplateResponse(file, {"request": request, "emu": fibenv.get('fe')})

# @app.get("/frontend", response_class=FileResponse)
# async def catch_all2(request: Request):
#     return ".vscode/emufiles/frontend/dist/index.html"

# @app.get("/frontend/{path:path}", response_class=FileResponse)
# async def catch_all(path: str, request: Request):
#     return ".vscode/emufiles/frontend/dist/index.html"

@app.exception_handler(404)
async def custom_404_handler(request: Request, exc: Exception):
    path = request.url.path
    #if path.startswith("/frontend"):
    return FileResponse(".vscode/emufiles/frontend/dist/index.html")
    #else:
    #    raise exc

@app.get("/info/qa/{id}", response_class=HTMLResponse,include_in_schema=False)
async def read_item(id: int, request: Request):
    emu = fibenv.get('fe')
    qa = emu.DIR[id]
    ui = qa.UI
    ui = convertLuaTable(ui)
    #print(ui,file=sys.stderr)
    d = convertLuaTable(qa.dev)
    d = d.get('properties') if d.get('properties') else dict()
    qvs = d.get('quickAppVariables') if d.get('quickAppVariables') else dict()
    return templates.TemplateResponse("infoqa.html", {"request": request, "emu": emu, "qa": qa, "ui": ui, "qvs":qvs})

''' Emulator methods '''
@app.get("emu/info", tags=["Emulator methods"])
async def get_emulator_info():
    return {"message": "Hello from FibEmu!"}

@app.post("/emu/dump", tags=["Emulator methods"])
async def dump_emulator_resources(response: Response, fname: str = Body(...)):
    res,code = fibenv.get('fe').luaCall("dumpResources",fname)
    response.status_code = code
    return res

@app.post("/emu/load", tags=["Emulator methods"])
async def load_emulator_resources(response: Response, fname: str = Body(...)):
    res,code = fibenv.get('fe').luaCall("loadResources",fname)
    response.status_code = code
    return res

# @app.get("/emu/test", tags=["Emulator methods"])
# async def load_emulator_resources(response: Response):
#     res,code = {},200
#     response.status_code = code
#     response.headers['Via'] = '1.1 google'
#     response.headers['X-RateLimit-Limit'] = '131072'
#     response.headers['X-RateLimit-Remaining'] = '130794'
#     response.headers['X-RateLimit-Reset'] = '1690014525'
#     response.headers['Content-Type'] = 'application/json; charset=utf-8'
#     response.headers['Alt-Svc'] = 'h3=":443"; ma=2592000,h3-29=":443"; ma=2592000'
#     return res

@app.get("/emu/button/{id}/{elm}/{val}", tags=["Emulator methods"])
async def invoke_ui_button(id:int, elm: str, val:int, response: Response):
    eventType = "onReleased" if val == 0 else "onChanged"
    value = [val] if val > 0 else []
    fibenv.get('fe').postEvent({"type":"uiEvent","deviceId":id,"eventType":eventType,"elementName":elm,"values":value})
    return "OK"

@app.get("/emu/qa", tags=["Emulator methods"])
async def emu_list_qas(request: Request):
    emu = fibenv.get('fe')
    if not hasattr(emu,'DIR'): # at startup, if ui is polling
        return {}
    d = emu.DIR
    qas = [{'id': id, 'name':d[id].dev.name, 'type':d[id].dev.type, 'parent':d[id].dev.parentId} for id in d]
    return qas

@app.get("/emu/qa/{id}", tags=["Emulator methods"])
async def emu_get_qa(id: int, request: Request):
    emu = fibenv.get('fe')
    if not (hasattr(emu,'DIR') and emu.DIR[id]): # at startup, if ui is polling
        return {}
    qa = emu.DIR[id]
    ui = qa.UI
    uiMap = qa.uiMap
    ui = convertLuaTable(ui)
    #print(json.dumps(ui),file=sys.stderr)
    uiMap = convertLuaTable(uiMap)
    d = convertLuaTable(qa.dev)
    props = d.get('properties') if d.get('properties') else dict()
    qvs = props.get('quickAppVariables') if props.get('quickAppVariables') else dict()
    return {"ui": ui, "uiMap": uiMap, "quickVars":qvs, "dev": d}

@app.get("/emu/events", tags=["Emulator methods"])
async def emu_get_events(request: Request):
    emu = fibenv.get('fe')
    if not hasattr(emu,'events'): # at startup, if ui is polling
        return {}
    return emu.events

@app.get("/emu/types", tags=["Emulator methods"])
async def emu_get_types(request: Request):
    with open('.vscode/emufiles/lua/types.json') as f:
        types = json.load(f)
        return types
    return {}

''' Device methods '''
class ActionParams(BaseModel):
    args: list

@app.post("/api/devices/{id}/action/{name}", tags=["Device methods"])
async def call_quickapp_method(id: int, name: str, args: ActionParams):
    t = time.time()
    fibenv.get('fe').postEvent({"type":"onAction","deviceId":id,"actionName":name,"args":json.dumps(args.args)})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

## /api/callAction?deviceID=${QA.value}&name=eval&arg1=${encodeURIComponent(command)}`
@app.get("/api/callAction", tags=["Device methods"])
async def callAction_quickapp_method(response: Response, request: Request):
    qps = request.query_params._dict
    id = qps['deviceID']; del qps['deviceID']
    name = qps['name']; del qps['name']
    args = [a for a in qps.values()]
    t = time.time()
    fibenv.get('fe').postEvent({"type":"onAction","deviceId":int(id),"actionName":name,"args":json.dumps(args)})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class DeviceQueryParams(BaseModel):
    id: int | None = None
    parentId: int | None = None
    name: str | None = None
    baseType: str | None = None
    interface: str | None = None
    name: str | None = None
    type: str | None = None

paramMap = dict(interface ='interfaces')
def filterQuery(query: dict, d: dict): # need to support lists too
    for k,v in query.items():
        if k in paramMap:
            if not v in d[paramMap.get(k)]:
                return False
        elif d[k] != v:
            return False
    return True

@app.get("/api/devices", tags=["Device methods"])
async def get_devices(response: Response, query: DeviceQueryParams = Depends()):
    ''' Get devices'''
    vars,code = fibenv.get('fe').luaCall("getResource","devices")
    query = query.dict(exclude_none=True)
    if len(query) > 0:
        res = [d for d in vars.values() if filterQuery(query,d)]
        response.status_code = 200
        return res
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/devices/hierarchy", tags=["Device methods"])
async def get_Device_Hierarchy():
    with open('.vscode/emufiles/lua/hierarchy.json') as f:
        data = json.load(f)
    return data

@app.get("/api/devices/{id}", tags=["Device methods"])
async def get_Device(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","devices",id)
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/devices/{id}", tags=["Device methods"])
async def delete_Device(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteResource","devices",id)
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
async def get_Global_Variables(response: Response):
    vars,code = fibenv.get('fe').luaCall("getResource","globalVariables")
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def get_Global_Variable(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","globalVariables",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/globalVariables", tags=["GlobalVariabes methods"])
async def create_Global_Variable(data: GlobalVarSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("createResource","globalVariables",data.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def modify_Global_Variable(name: str, data: GlobalVarSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","globalVariables",name,data.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/globalVariables/{name}", tags=["GlobalVariabes methods"])
async def delete_Global_Variable(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteResource","globalVariables",name)
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
async def get_Rooms(response: Response):
    vars,code = fibenv.get('fe').luaCall("getResource","rooms")
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/rooms/{id}", tags=["Rooms methods"])
async def get_Room(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","rooms",id)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/rooms", tags=["Rooms methods"])
async def create_Room(room: RoomSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("createResource","rooms",room.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/rooms/{id}", tags=["Rooms methods"])
async def modify_Room(id: int, room: RoomSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","rooms",id,room.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/rooms/{id}", tags=["Rooms methods"])
async def delete_Room(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteResource","rooms",id)
    response.status_code = code
    return var if code < 300 else None

''' Sections methods '''
class SectionSpec(BaseModel):
    name: str | None = None
    id: int | None = None

@app.get("/api/sections", tags=["Sections methods"])
async def get_Sections(response: Response):
    vars,code = fibenv.get('fe').luaCall("getResource","sections")
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/sections/{id}", tags=["Sections methods"])
async def get_Section(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","sections",id)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/sections", tags=["Sections methods"])
async def create_Section(section: SectionSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("createResource","sections",section.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/sections/{id}", tags=["Sections methods"])
async def modify_Section(id: int, section: SectionSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","sections",id,section.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/sections/{id}", tags=["Sections methods"])
async def delete_Section(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteResource","sections",id)
    response.status_code = code
    return var if code < 300 else None

''' CustomEvent methods '''
class CustomEventSpec(BaseModel):
    name: str
    userdescription: str | None = ""

@app.get("/api/customEvents", tags=["CustomEvents methods"])
async def get_CustomEvents(response: Response):
    vars,code = fibenv.get('fe').luaCall("getResource","customEvents")
    response.status_code = code
    return list(vars.values()) if code < 300 else None

@app.get("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def get_CustomEvent(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","customEvents",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/customEvents", tags=["CustomEvents methods"])
async def create_CustomEvent(customEvent: CustomEventSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("createResource","customEvents",customEvent.json())
    response.status_code = code
    return var if code < 300 else None

@app.put("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def modify_CustomEvent(name: str, customEvent: CustomEventSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","customEvents",name,customEvent.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def delete_CustomEvent(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteResource","customEvents",name)
    response.status_code = code
    return var if code < 300 else None

@app.post("/api/customEvents/{name}", tags=["CustomEvents methods"])
async def emit_CustomEvent(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("emitCustomEvent",name)
    response.status_code = code
    return {} if code < 300 else None

''' RefreshStates methods '''
class RefreshStatesQuery(BaseModel):
    last: int = 0
    lang: str = "en"
    rand: float = 0.09580020181569104
    logs: bool = False  

@app.get("/api/refreshStates", tags=["RefreshStates methods"])
async def get_refreshStates_events(response: Response, query: RefreshStatesQuery = Depends()):
    res = fibenv.get('fe').getEvents(query.last)
    #print(f"API: {res}",file=sys.stderr)
    code = 200
    response.status_code = code
    return res if code < 300 else None

''' Plugins methods '''
@app.get("/api/plugins/callUIEvent", tags=["Plugins methods"])
async def call_UI_Event(deviceID: int, eventType: str, elementName: str, value: str | None = None):
    t = time.time()
    #print(f"call_UI_Event: {deviceID} {eventType} {elementName} {value}",file=sys.stderr)
    value = [value] if value else []
    fibenv.get('fe').postEvent({"type":"uiEvent","deviceId":deviceID,"eventType":eventType,"elementName":elementName,"values":value})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class UpdatePropertyParams(BaseModel):
    deviceId: int
    propertyName: str
    value: Any

@app.post("/api/plugins/updateProperty", tags=["Plugins methods"])
async def update_qa_property(args: UpdatePropertyParams):
    t = time.time()
    fibenv.get('fe').luaCall("updateDeviceProp",args.json())
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class UpdateViewParams(BaseModel):
    deviceId: int
    componentName: str
    propertyName: str
    newValue: str

@app.post("/api/plugins/updateView", tags=["Plugins methods"])
async def update_qa_view(args: UpdateViewParams):
    t = time.time()
    event = dict(args.__dict__)
    event['type'] = 'updateView'
    fibenv.get('fe').postEvent(event)
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

class RestartParams(BaseModel):
    deviceId: int
    
@app.post("/api/plugins/restart", tags=["Plugins methods"])
async def restart_qa(args: RestartParams, response: Response):
    args = dict(args)
    var,code = fibenv.get('fe').luaCall("restartDevice",args.get('deviceId'))
    response.status_code = code
    return {} if code < 300 else None

class ChildParams(BaseModel):
    parentId: int | None = None
    name: str
    type: str
    initialProperties: Dict[str, Any] | None = None
    initialInterfaces: List[str] | None = None

@app.post("/api/plugins/createChildDevice", tags=["Plugins methods"])
async def create_Child_Device(args: ChildParams, response: Response):
    var,code = fibenv.get('fe').luaCall("createChildDevice",args.json())
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/plugins/removeChildDevice/{id}", tags=["Plugins methods"])
async def delete_Child_Device(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteChildDevice",id)
    response.status_code = code
    return var if code < 300 else None

class EventParams(BaseModel):
    type: str
    source: int | None = None
    data: Any

@app.post("/api/plugins/publishEvent", tags=["Plugins methods"])
async def publish_event(args: EventParams, response: Response):
    var,code = fibenv.get('fe').luaCall("publishEvent",args.json())
    response.status_code = code
    return var if code < 300 else None

@app.get("/api/plugins/{id}/variables", tags=["Plugins methods"])
async def internal_storage_set(id: int,response: Response):
    var,code = fibenv.get('fe').luaCall("getQAKey",id)
    response.status_code = code
    if code < 300:
        var = [{'name':k,'value':v} for k,v in var.items()]
    return var if code < 300 else None

@app.get("/api/plugins/{id}/variables/{name}", tags=["Plugins methods"])
async def internal_storage_set(id: int, name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("getQAKey",id,name)
    response.status_code = code
    if code < 300:
        var = {'name':name,'value':var}
    return var if code < 300 else None

class InternalStorageParams(BaseModel):
    name: str
    value: Any
    isHidden: bool = False

@app.post("/api/plugins/{id}/variables", tags=["Plugins methods"])
async def internal_storage_create(id: int, args: InternalStorageParams, response: Response):
    var,code = fibenv.get('fe').luaCall("createQAKey",id,args.json())
    response.status_code = code
    if code < 300:
        var = {'name':args.name,'value':args.value}
    return var if code < 300 else None

@app.put("/api/plugins/{id}/variables/{name}", tags=["Plugins methods"])
async def internal_storage_set(id: int, name: str, args: InternalStorageParams, response: Response):
    var,code = fibenv.get('fe').luaCall("setQAKey",id,name,args.json())
    response.status_code = code
    if code < 300:
        var = {'name':args.name,'value':args.value}
    return var if code < 300 else None

@app.delete("/api/plugins/{id}/variables/{name}", tags=["Plugins methods"])
async def internal_storage_delete(id: int, name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteQAKey",id,name)
    response.status_code = code
    return var if code < 300 else None

@app.delete("/api/plugins/{id}/variables", tags=["Plugins methods"])
async def internal_storage_delete(id: int, response: Response):
    var,code = fibenv.get('fe').luaCall("deleteQAKey",id)
    response.status_code = code
    return var if code < 300 else None

class DebugMessageSpec(BaseModel):
    message: str
    messageType: str
    tag: str

@app.post("/api/debugMessages", tags=["DebugMessages methods"])
async def add_debug_message(args: DebugMessageSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("debugMessages",args.json())
    response.status_code = code
    return var if code < 300 else None

''' DebugMsgQuery methods '''
class DebugMsgQuery(BaseModel):
    filter: list[str] = []
    fromfield: int = Field(alias='from', default=0)
    to: int = 0
    last: int = 0
    offset: int = 0

@app.get("/api/debugMessages", tags=["DebugMessages methods"])
async def get_debug_message(response: Response, request: Request):
    fe = fibenv.get('fe')
    res = fe.getDebugMessages(request.query_params._dict)
    code = 200
    response.status_code = code
    return res if code < 300 else None


''' QuickApp methods '''
@app.get("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def get_QuickApp_Files(id: int, response: Response):
    f,code = fibenv.get('fe').luaCall("getQAfiles",id)
    response.status_code = code
    return f if code < 300 else None

class QAFileSpec(BaseModel):
    name: str
    isMain: bool
    content: str
    isOpen: bool | None = False
    type: str | None = "lua"

@app.post("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def create_QuickApp_Files(id: int, file: QAFileSpec, response: Response):
    f,code = fibenv.get('fe').luaCall("setQAfiles",id,file.json())
    response.status_code = code
    return f if code < 300 else None

@app.get("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def get_QuickApp_File(id: int, name: str, response: Response):
    f,code = fibenv.get('fe').luaCall("getQAfiles",id,name)
    response.status_code = code
    return f if code < 300 else None

@app.put("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def modify_QuickApp_File(id: int, name: str, file: QAFileSpec, response: Response):
    f,code = fibenv.get('fe').luaCall("setQAfiles",id,name,file.json())
    response.status_code = code
    return f if code < 300 else None

@app.put("/api/quickApp/{id}/files", tags=["QuickApp methods"])
async def modify_QuickApp_Files(id: int, args: List[QAFileSpec], response: Response):
    files = [f.__dict__ for f in args]
    f,code = fibenv.get('fe').luaCall("setQAfiles",id,json.dumps(files))
    response.status_code = code
    return f if code < 300 else None

@app.get("/api/quickApp/export/{id}", tags=["QuickApp methods"])
async def export_QuickApp_FQA(id: int, response: Response):
    fqa,code = fibenv.get('fe').luaCall("exportFQA",id)
    response.status_code = code
    return fqa if code < 300 else None

class QAImportSpec(BaseModel):
    name: str
    type: str
    apiVersion: str
    files: List[QAFileSpec]
    initialProperties: Any | None = None
    initialInterfaces: Any | None = None

@app.post("/api/quickApp/", tags=["QuickApp methods"])
async def import_QuickApp(file: QAImportSpec, response: Response):
    t = time.time()
    fqa,code = fibenv.get('fe').luaCall("importFQA",file.json())
    response.status_code = code
    return fqa if code < 300 else None

class QAImportParams(BaseModel):
    file: str
    roomId : int | None = None
@app.post("/api/quickApp/import", tags=["QuickApp methods"])
async def import_QuickApp(file: QAImportParams, response: Response):
    t = time.time()
    fibenv.get('fe').postEvent({"type":"importFQA","file":file.file,"roomId":file.roomId})
    return { "endTimestampMillis": time.time(), "message": "Accepted", "startTimestampMillis": t }

@app.delete("/api/quickApp/{id}/files/{name}", tags=["QuickApp methods"])
async def delete_QuickApp_File(id: int, name: str, response: Response):
    f,code = fibenv.get('fe').luaCall("deleteQAfile",id,name)
    response.status_code = code
    return f if code < 300 else None

''' Weather methods '''
@app.get("/api/weather", tags=["Weather methods"])
async def get_Weather(response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","weather")
    response.status_code = code
    return var if code < 300 else None

class WeatherSpec(BaseModel):
    ConditionCode: float | None = None
    Humidity: float | None = None
    Temperature: float | None = None
    TemperatureUnit: str | None = None
    WeatherCondition: str | None = None
    WeatherConditionConverted: str | None = None
    Wind: float | None = None
    WindUnit: str | None = None

@app.put("/api/weather", tags=["Weather methods"])
async def modify_Weather(args: WeatherSpec, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","weather",None,args.json())
    response.status_code = code
    return var if code < 300 else None

''' iosDevices methods '''
@app.get("/api/iosDevices", tags=["iosDevices methods"])
async def get_ios_Devices(response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","iosDevices")
    response.status_code = code
    return var if code < 300 else None

''' home methods '''
@app.get("/api/home", tags=["Home methods"])
async def get_Home(response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","home")
    response.status_code = code
    return var if code < 300 else None

class DefaultSensorParams(BaseModel):
    light: int | None
    temperature: int | None
    humidity: int | None

class HomeParams(BaseModel):
    defaultSensors: DefaultSensorParams
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
async def modify_Home(args: HomeParams, response: Response):
    var,code = fibenv.get('fe').luaCall("modifyResource","home",None,args.json())
    response.status_code = code
    return var if code < 300 else None

''' settings methods '''
@app.get("/api/settings/{name}", tags=["Settings methods"])
async def get_Settings(name: str, response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","settings/"+name)
    response.status_code = code
    return var if code < 300 else None

''' partition methods '''
@app.get("/api/alarms/v1/partitions", tags=["Partition methods"])
async def get_Partitions(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions")
    response.status_code = code
    return list(items.values()) if code < 300 else None

@app.get("/api/alarms/v1/partitions/{id}", tags=["Partition methods"])
async def get_Partition(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.post("/alarms/v1/partitions/actions/arm", tags=["Partition methods"]) ## Arm all partitions
async def post_PartitionArm0(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.post("/alarms/v1/partitions/{id}/actions/arm", tags=["Partition methods"]) ## Arm id partition
async def post_PartitionArm(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.delete("/alarms/v1/partitions/actions/arm", tags=["Partition methods"]) ## Unarm all partitions
async def delete_PartitionArm0(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.delete("/alarms/v1/partitions/{id}/actions/arm", tags=["Partition methods"]) ## Unarm id partition
async def delete_PartitionArm(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.post("/alarms/v1/partitions/actions/tryArm", tags=["Partition methods"]) ## Tryarm all partitions
async def post_PartitionTryArm0(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None

@app.post("/alarms/v1/partitions/{id}/actions/arm", tags=["Partition methods"]) ## Tryarm id partition
async def post_PartitionTryArm(id: int, response: Response):
    item,code = fibenv.get('fe').luaCall("getResource","alarms/v1/partitions",id)
    response.status_code = code
    return item if code < 300 else None
    
''' alarm devices methods '''
@app.get("/api/alarms/v1/devices/", tags=["Alarm devices methods"])
async def get_alarm_devices(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","alarms/v1/devices")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' notificationCenter methods '''
@app.get("/api/notificationCenter", tags=["NotificationCenter methods"])
async def get_Notification_Center(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","notificationCenter")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' profiles methods '''
@app.get("/api/profiles", tags=["Profiles methods"])
async def get_Profiles(response: Response):
    var,code = fibenv.get('fe').luaCall("getResource","profiles")
    response.status_code = code
    return var if code < 300 else None

''' icons methods '''
@app.get("/api/icons", tags=["Icons methods"])
async def get_Icons(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","icons")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' users methods '''
@app.get("/api/users", tags=["Users methods"])
async def get_Users(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","users")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' energy devices methods '''
@app.get("/api/energy/devices", tags=["Energy devices methods"])
async def get_Energy_Devices(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","energy/devices")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/location methods '''
@app.get("/api/panels/location", tags=["Panels location methods"])
async def get_Panels_Location(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/location")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/notification methods '''
@app.get("/api/panels/notifications", tags=["Panels notifications methods"])
async def get_Panels_Notifications(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/notifications")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/family methods '''
@app.get("/api/panels/family", tags=["Panels family methods"])
async def get_Panels_Family(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/family")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/sprinklers methods '''
@app.get("/api/panels/sprinklers", tags=["Panels sprinklers methods"])
async def get_Panels_Sprinklers(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/sprinklers")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/humidity methods '''
@app.get("/api/panels/humidity", tags=["Panels humidity methods"])
async def get_Panels_Humidity(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/humidity")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/favoriteColors methods '''
@app.get("/api/panels/favoriteColors", tags=["Panels favoriteColors methods"])
async def get_Favorite_Colors(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/favoriteColors")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' panels/favoriteColors/v2 methods '''
@app.get("/api/panels/favoriteColors/v2", tags=["Panels favoriteColors/v2 methods"])
async def get_Favorite_ColorsV2(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","panels/favoriteColors/v2")
    response.status_code = code
    return list(items.values()) if code < 300 else None

''' diagnostics methods '''
@app.get("/api/diagnostics", tags=["Diagnostics methods"])
async def get_Diagnostics(response: Response):
    items,code = fibenv.get('fe').luaCall("getResource","diagnostics")
    response.status_code = code
    return list(items.values()) if code < 300 else None

# ''' mobile push methods '''
# @app.get("/api/mobile/push", tags=["Mobile push methods"])
# async def get_Mobile_Push(response: Response):
#     items,code = fibenv.get('fe').luaCall("getResource","mobile/push")
#     response.status_code = code
#     return list(items.values()) if code < 300 else None

''' proxy methods '''
class ProxyParams(BaseModel):
    url: str
@app.get("/api/proxy", tags=["Proxy method"])
async def call_via_proxy(response: Response, query: ProxyParams = Depends()):
    fe = fibenv.get('fe')
    query = query.dict(exclude_none=True)
    url = query['url']
    url = url[url.index('/api'):]
    response = RedirectResponse(url=url)
    return response