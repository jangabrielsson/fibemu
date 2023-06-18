import lupa
from lupa import LuaRuntime
from threading import Thread
from threading import Timer
from threading import Event
import json
import requests_async
import requests
import asyncio
import time
from datetime import datetime
import fibapi

def httpCall(method, url, options, data, local):
    headers = options['headers']
    req = requests if not local else requests_async.ASGISession(fibapi.app)
    match method:
        case 'GET':
            res = req.get(url, headers = headers)
        case 'PUT':
            res = req.put(url, headers = headers, data = data)
        case 'POST':
            res = req.post(url, headers = headers, data = data)
        case 'DELETE':
            res = req.delete(url, headers = headers, data = data)
    res = asyncio.run(res) if local else res
    return res.status_code, res.text , res.headers

def convertTable(obj):
    if lupa.lua_type(obj) == 'table':
        d = dict()
        for k,v in obj.items():
            d[k] = convertTable(v)
        return d
    else:
        return obj

def tofun(fun):
    a = type(fun)
    return fun[1] if type(fun) == tuple else fun

class FibaroEnvironment:
    def __init__(self, config):
        self.config = config
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.event = Event()
        self.task = None

    def onAction(self,event): # {"deviceId":<id>, "actionName":<name>, "args":<args>}
        self.task = {"type":"action","payload":json.dumps({"deviceId":event["deviceId"],"actionName":event['actionName'],"args":event['args']})}
        self.event.set()

    def onUIEvent(self,event): # {"deviceID":<id>, "elementName":<name>, "values":<args>}
        self.task = {"type":"uievent","payload":json.dumps({"deviceId":event["deviceId"],"elementName":event['elementName'],"values":event['values']})}
        self.event.set()

    def getResource(self,name,id=None):
        fun = self.QA.getResource
        res = tofun(fun)(name,id)
        res = convertTable(res)
        return res

    def onEvent(self,event):
        self.task = {"type":"event","payload":json.dumps(event)}
        self.event.set()

    def refreshStates(self,start,url,options):
        options = convertTable(options)
        def refreshRunner():
            last = 0
            while True:
                try:
                    nurl = url + str(last)
                    code,data,h = httpCall("GET", nurl, options, None, False)
                    if code == 200:
                        data = json.loads(data)
                        last = data['last'] if data['last'] else last
                        if data['events']:
                            for event in data['events']:
                                self.onEvent(event)
                except Exception as e:
                    print(f"Error: {e}")
                    
        self.rthread = Thread(target=refreshRunner, args=())
        self.rthread.start()

    def run(self):

        def runner():
            config = self.config
            globals = self.lua.globals()
            globals['clock'] = time.time
            globals['__HTTP'] = httpCall
            globals['__REFRESH'] = lambda start, url, options: self.refreshStates(start,url,options)
            emulator = config['path'] + "lua/" + config['emulator']
            f = self.lua.eval(f'function(config) loadfile("{emulator}")(config) end')
            f(self.lua.table_from(config))
            QA = globals.QA
            self.QA = QA
            if config['file1']:
                QA.start(config['file1'])
            if config['file2']:
                QA.start(config['file2'])
            if config['file2']:
                QA.start(config['file3'])
            while True:
                delay = QA.loop()
                # print(f"event: {delay}s", end='')
                self.event.wait(delay)
                # print(f", {self.task}")
                if self.task:
                    match self.task['type']:
                        case 'action':
                            QA.onAction(self.task['payload'])
                        case 'uievent':
                            QA.UIEvent(self.task['payload'])
                        case 'event':
                            QA.onEvent(self.task['payload'])
                    self.task = None # Should be a queue?
                    self.event.clear()

        self.thread = Thread(target=runner, args=())
        self.thread.start()
