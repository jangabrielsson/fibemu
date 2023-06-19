import lupa
from lupa import LuaRuntime
from threading import Thread
from threading import Timer
import queue
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
        self.queue = queue.Queue()

    def postEvent(self,event): # called from another thread
        self.queue.put(event)

    def onAction(self,event): # {"deviceId":<id>, "actionName":<name>, "args":<args>}
        ev = {"deviceId":event["deviceId"],"actionName":event['actionName'],"args":event['args']}
        self.postEvent({"type":"action","payload":ev})

    def onUIEvent(self,event): # {"deviceID":<id>, "elementName":<name>, "values":<args>}
        ev = {"deviceId":event["deviceId"],"elementName":event['elementName'],"values":event['values']}
        self.postEvent({"type":"uievent","payload":ev})

    def onEvent(self,event):  # called from another thread
        self.postEvent({"type":"event","payload":event})

    def getResource(self,typ,id=None):  # called from another thread
        fun = self.QA.getResource
        res = tofun(fun)(typ,id)
        res = convertTable(res)
        return res

    def createResource(self,typ,data):  # called from another thread
        fun = self.QA.createResource
        res = tofun(fun)(typ,data)
        res = convertTable(res)
        return res

    def deleteResource(self,typ,id):  # called from another thread
        fun = self.QA.deleteResource
        res = tofun(fun)(typ,id)
        res = convertTable(res)
        return res

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
                try:
                    event = self.queue.get(block=True, timeout=delay)
                except queue.Empty:
                    event = None
                # print(f", {self.event}")
                if event:
                    match event['type']:
                        case 'action':
                            QA.onAction(json.dumps(event['payload']))
                        case 'uievent':
                            QA.UIEvent(json.dumps(event['payload']))
                        case 'event':
                            QA.onEvent(json.dumps(event['payload']))

        self.thread = Thread(target=runner, args=())
        self.thread.start()
