import lupa
from lupa import LuaRuntime
from threading import Thread
from threading import Timer
import queue
import json
import requests_async
import requests
import asyncio
import time, sys
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
        self.queue.put(event)  # safely qeued for lua thread

    def remoteCall(self,method,*args): # called from another thread
        try:
            fun = self.QA.fun              # unsafe call to lua function in other thread
            fun = tofun(fun)[method]
            res,code = tofun(fun)(*args)
            res = convertTable(res)
        except Exception as e:
            print(f"Remote Call Error: {e}",file=sys.stderr)
        return res,code

    def refreshStates(self,start,url,options):
        if self.config.get('local'):
            return
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
                                self.postEvent({"type":"refreshStates","event":event})
                except Exception as e:
                    print(f"Error: {e}")
                    
        self.rthread = Thread(target=refreshRunner, args=())
        self.rthread.start()

    def run(self):

        def runner():
            config = self.config
            globals = self.lua.globals()
            hooks = {
                'clock':time.time,
                'http':httpCall,
                'refreshStates':lambda start, url, options: self.refreshStates(start,url,options)
            }
            config['hooks'] = hooks
            emulator = config['path'] + "lua/" + config['emulator']
            f = self.lua.eval(f'function(config) loadfile("{emulator}")(config) end')
            f(self.lua.table_from(config))
            QA = globals.QA
            self.QA = QA
            if config['file1']:
                QA.install(config['file1'])
            if config['file2']:
                QA.install(config['file2'])
            if config['file2']:
                QA.install(config['file3'])
            while True:
                delay = QA.loop()
                # print(f"event: {delay}s", end='')
                try:
                    event = self.queue.get(block=True, timeout=delay)
                except queue.Empty:
                    event = None
                # print(f", {self.event}")
                if event:
                    try:
                        QA.onEvent(json.dumps(event))
                    except Exception as e:
                        print(f"onEvent Error: {e}")

        self.thread = Thread(target=runner, args=())
        self.thread.start()
