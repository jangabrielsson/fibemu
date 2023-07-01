from threading import Thread
from threading import Timer
import requests_async
import requests
from requests import exceptions
import asyncio
import socket, errno, os
import websocket
import fibapi

def callCB(fibemu,cb,*args):
    fibemu.postEvent({"type":"luaCallback","args":list(args)}, extra=cb)

def httpCall(method, url, options, data, local):
    ''' http called from lua, async-wait if we call our own api (local, Fast API) '''
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

def httpCallAsync(fibemu, method, url, options, data, local):
    ''' http call in separate thread and post back to lua '''
    def runner():
        status, text, headers = httpCall(method, url, options, data, local)
        headers = dict(headers)
        fibemu.postEvent({"type":"luaCallback","args":[status,text,headers]}, extra=options)
    rthread = Thread(target=runner, args=())
    rthread.start()

class LuaTCPSocket:
    def __init__(self, fibemu):
        self.fibemu = fibemu
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    def settimeout(self,value):
        self.socket.settimeout(value/1000)
    def connect(self, ip, port, cb):
        def runner():
            err = self.sock.connect_ex((ip, port))
            errstr = os.strerror(err)
            callCB(self.fibemu,cb,err,errstr)
        Thread(target=runner, args=()).run()
    def send(self,msg):
        try:
            self.sock.sendall(msg.encode())
            return 0,len(msg)
        except Exception as e:
            return 1,"Bad file descriptor"
    def close(self):
        self.sock.close()
    def recieve(self,cb):
        def runner():
            msg = self.sock.recv(2048)
            msg = msg.decode('utf-8')
            if msg=="":
                callCB(self.fibemu,cb,1,"End of file")
            else:
                callCB(self.fibemu,cb,0,msg)
        Thread(target=runner, args=()).run()
    def receieveUntil(self,until,cb):
        def runner():
            callCB(self.fibemu,cb,"")
        Thread(target=runner, args=()).run()

class LuaUDPSocket:
    def __init__(self, fibemu):
        self.fibemu = fibemu
        self.sock = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
    def bind(self, localIP, localPort):
        bind((localIP, localPort))
    def settimeout(self,value):
        self.socket.settimeout(value/1000)
    def setoption(option, flag):
        if option == "broadcast":
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, flag and 1)
    def sendto(self,msg, ip, port):
        try:
            self.sock.sendto(msg.encode(), (ip, port))
            return 0,len(msg)
        except Exception as e:
            return 1,"Bad file descriptor"
    def close(self):
        self.sock.close()
    def recieve(self,cb):
        def runner():
            msgFromServer = self.socket.recvfrom(2048)
            msg = msgFromServer[0].decode('utf-8')
            if msg=="":
                callCB(self.fibemu,cb,1,"End of file")
            else:
                callCB(self.fibemu,cb,0,msg)
        Thread(target=runner, args=()).run()

class LuaWebSocket:
    #    websocket.enableTrace(True)
    def __init__(self, fibemu, url):
        self.ws = websocket.WebSocketApp(url,#"wss://api.gemini.com/v1/marketdata/BTCUSD",
                              on_open=lambda ws: on_open(self,ws),
                              on_message=lambda ws,msg: on_message(self,ws,msg),
                              on_error=lambda ws,err: on_error(self,ws,err),
                              on_close=lambda ws,stat,msg: on_close(self,ws,stat,msg))

    def on_message(self, ws, message):
        callCB(self.fibemu,self.cb,"dataReceived",message)

    def on_error(self, ws, error):
        callCB(self.fibemu,self.cb,"error",error)

    def on_close(self, ws, close_status_code, close_msg):
        callCB(self.fibemu,self.cb,"disconnected")

    def on_open(self, ws):
        callCB(self.fibemu,self.cb,"connected")
