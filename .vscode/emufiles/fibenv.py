import lupa
from lupa import LuaRuntime
from threading import Thread
from threading import Timer
from threading import Event
import json
import requests
import time
from datetime import datetime

configs = {
    'host': '127.0.0.1:5000',  #"192.168.1.57" 
    'user': 'admin',
    'pwd': 'admin'
}

headers = {
    'Accept': "*/*",
    'Content-type': "application/json",
    'X-Fibaro-Version': '2',
}

def config(host, user, pwd):
    configs['host'] = host
    configs['user'] = user
    configs['pwd'] = pwd
    
def httpCall(method, url, options, data = None):
    headers = options['headers']
    match method:
        case 'GET':
            res = requests.get(url, headers = options.headers)
        case 'PUT':
            res = requests.put(url, headers = options.headers, data = data)
        case 'POST':
            res = requests.post(url, headers = options.headers, data = data)
        case 'DELETE':
            res, code = requests.delete(url, headers = options.headers, data = data)
    return res.status_code, res.text, res.headers

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

    def run(self):

        def runner():
            config = self.config
            globals = self.lua.globals()
            globals['clock'] = time.time
            globals['__HTTP'] = httpCall
            emulator = config['path'] + "lua/" + config['emulator']
            print(emulator)
            f = self.lua.eval(f'function(config) loadfile("{emulator}")(config) end')
            f(self.lua.table_from(config))
            QA = globals.QA
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
                self.event.clear()
                if self.task:
                    match self.task['type']:
                        case 'action':
                            QA.onAction(self.task['payload'])
                        case 'uievent':
                            QA.UIEvent(self.task['payload'])
                    self.task = None # Should be a queue?

        self.thread = Thread(target=runner, args=())
        self.thread.start()
