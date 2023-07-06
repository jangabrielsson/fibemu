from threading import Thread
from threading import Timer
import requests_async
import requests
from requests import exceptions
import asyncio
import socket, errno, os
import websocket
import paho.mqtt.client as mqtt
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
            msg = bytes(msg.values())
            self.sock.sendall(msg)
            return 0,len(msg)
        except Exception as e:
            return 1,"Bad file descriptor"
    def close(self):
        self.sock.close()
    def recieve(self,cb):
        def runner():
            try:
                msg = self.sock.recv(4096)
                msg = list(msg)
                if len(msg)==0:
                    callCB(self.fibemu,cb,1,"End of file")
                else:
                    callCB(self.fibemu,cb,0,msg)
            except socket.timeout:
                callCB(self.fibemu,cb,1,"operation cancelled")
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
        try:
            self.sock.bind((localIP, localPort))
            return 0,""
        except Exception as e:
            return 1,str(e)
    def settimeout(self,value):
        self.sock.settimeout(value/1000)
    def setoption(self, option, flag):
        if option == "broadcast":
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, flag and 1)
    def sendto(self, msg, ip, port):
        try:
            msg = bytes(msg.values())
            self.sock.sendto(msg, (ip, port))
            return 0,len(msg)
        except Exception as e:
            return 1,"Bad file descriptor"
    def close(self):
        self.sock.close()
    def recieve(self,cb):
        def runner():
            try:
                msgFromServer, addr = self.sock.recvfrom(4096)
                msg = list(msgFromServer)
                if len(msg)==0:
                    callCB(self.fibemu,cb,1,"End of file")
                else:
                    callCB(self.fibemu,cb,0,msg,addr[0],addr[1])
            except socket.timeout:
                callCB(self.fibemu,cb,1,"operation cancelled")
        Thread(target=runner, args=()).run()

class LuaWebSocket:
    #    websocket.enableTrace(True)
    def __init__(self, fibemu, url, headers, cb):
        #websocket.enableTrace(True)
        self.closed = True
        self.fibemu = fibemu
        self.cb = cb
        self.ws = websocket.WebSocketApp(url=url,#"wss://api.gemini.com/v1/marketdata/BTCUSD",
                         #     header=headers,
                              on_open=lambda ws: self.on_open(ws),
                              on_message=lambda ws,msg: self.on_message(ws,msg),
                              on_error=lambda ws,err: self.on_error(ws,err),
                              on_close=lambda ws,stat,msg: self.on_close(ws,stat,msg))
        self.closed = False
        Thread(target=self.ws.run_forever).start()

    def on_message(self, ws, message):
        callCB(self.fibemu,self.cb,"dataReceived",message)

    def on_error(self, ws, error):
        callCB(self.fibemu,self.cb,"error",str(error))

    def on_close(self, ws, close_status_code, close_msg):
        self.closed = True
        self.close()
        callCB(self.fibemu,self.cb,"disconnected")

    def on_open(self, ws):
        callCB(self.fibemu,self.cb,"connected")

    def send(self,msg):
        return self.ws.send(msg)

    def close(self):
        self.ws.close()

    def isOpen(self):
        return self.closed

class LuaMQTT:
    def __init__(self, fibemu, cb):
        self.fibemu = fibemu
        self.cb = cb
        client = mqtt.Client()
        client.on_connect = lambda client,userdata,flags,rc: self.on_connect(client, userdata, flags, rc)
        client.on_message = lambda client,userdata,msg: self.on_message(client, userdata, msg)
        self.client = client

    #client.connect("mqtt.eclipseprojects.io", 1883, 60)
    def connect(self, url, port, keepalive):
        self.client.connect(url, port, keepalive)
        Thread(target=self.client.loop_forever).start()

# The callback for when the client receives a CONNACK response from the server.
    def on_connect(self, client, userdata, flags, rc):
        callCB(self.fibemu,self.cb,"on_connect",userdata, flags, rc)

    def on_message(self, client, userdata, msg):
        callCB(self.fibemu,self.cb,"on_message",userdata, msg)

    # client.subscribe("$SYS/#")
    def subscribe(self, topic):
        return self.client.subscribe(topic)

       
