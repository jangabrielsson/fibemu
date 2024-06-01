from threading import Thread
from threading import Timer
import requests_async
import requests
from requests import exceptions
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
import asyncio
import socket, ssl
import errno
import os, json
import sys
import websocket
import logging
import paho.mqtt.client as mqtt
import fibapi

requests.packages.urllib3.disable_warnings()

def requests_retry_session(
    retries=3,
    backoff_factor=0.3,
    status_forcelist=(500, 502, 504),
    session=None,
):
    session = session or requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
        backoff_factor=backoff_factor,
        status_forcelist=status_forcelist,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

def callCB(fibemu, cb, *args):
    largs = list(args)
    ##print(f"CALLBACK: {largs}", file=sys.stderr)
    fibemu.postEvent({"type": "luaCallback", "args": largs}, extra=cb)


def httpCall(method, url, options, data, local):
    ''' http called from lua, async-wait if we call our own api (local, Fast API) '''
    headers = options['headers']
    headers = dict(headers)
    timeout = options['timeout'] if options['timeout'] else 60
    verify = options['checkCertificate'] if options['checkCertificate']==False else True
    req = None
    if not local:
        req = requests_retry_session()
    else:
        req = requests_async.ASGISession(fibapi.app)
    #req = requests if not local else requests_async.ASGISession(fibapi.app)
    if data:
        if headers and 'Content-Type' in headers and 'utf-8' in headers['Content-Type']:
            data = data.encode('utf-8')
            #pass
    try:
        match method:
            case 'GET':
                res = req.get(url, headers=headers, timeout=timeout, verify=verify)
            case 'PUT':
                res = req.put(url, headers=headers, data=data, timeout=timeout, verify=verify)
            case 'POST':
                res = req.post(url, data=data, headers=headers, timeout=timeout, verify=verify)
            case 'DELETE':
                res = req.delete(url, headers=headers, data=data, timeout=timeout, verify=verify)

        res = asyncio.run(res) if local else res
        if res.text.startswith("<!DOCTYPE html>"):
            return 500, "Internal Server Error", res.headers
        return res.status_code, res.text, res.headers
    except Exception as e:
        return 500, e.__doc__, {}


def httpCallAsync(fibemu, method, url, options, data, local):
    ''' http call in separate thread and post back to lua '''
    def runner():
        try:
            status, text, headers = httpCall(method, url, options, data, local)
            headers = dict(headers)
            fibemu.postEvent({"type": "luaCallback", "args": [
                             status, text, headers]}, extra=options)
        except Exception as e:
            fibemu.postEvent({"type": "luaCallback", "args": [
                             404, str(e)]}, extra=options)
    rthread = Thread(target=runner, args=())
    rthread.start()


class LuaTCPSocket:
    def __init__(self, fibemu):
        self.fibemu = fibemu
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setblocking(False)

    def settimeout(self, value):
        self.sock.settimeout(value/1000)
        self.sock.setblocking(False)

    def connect(self, ip, port, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            try:
                await loop.sock_connect(self.sock, (ip, port))
                callCB(self.fibemu, cb, 0, 'connected')
            except Exception as e:
                callCB(self.fibemu, cb, 1, str(e))
        Thread(target=asyncio.run, args=(runner(),)).start()

    def send(self, msg):
        try:
            msg = bytes(msg.values())
            self.sock.sendall(msg)
            return 0, len(msg)
        except Exception as e:
            return 1, "Bad file descriptor"

    def close(self):
        self.sock.close()

    def recieve(self, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            try:
                msg = await loop.sock_recv(self.sock, 4096)
                msg = list(msg)
                if len(msg) == 0:
                    callCB(self.fibemu, cb, 1, "End of file")
                else:
                    callCB(self.fibemu, cb, 0, msg)
            except socket.timeout:
                callCB(self.fibemu, cb, 1, "operation cancelled")
            except Exception as e:
                callCB(self.fibemu, cb, 1, str(e))
        Thread(target=asyncio.run, args=(runner(),)).start()

    def receieveUntil(self, until, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            callCB(self.fibemu, cb, 1, "not implemented")
        Thread(target=asyncio.run, args=(runner(),)).start()


class LuaTCPSocketServer:  # should implement tcp server...
    def __init__(self, fibemu):
        self.fibemu = fibemu
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setblocking(False)

    def settimeout(self, value):
        self.socket.settimeout(value/1000)
        self.sock.setblocking(False)

    def connect(self, ip, port, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            try:
                await loop.sock_connect(self.sock, (ip, port))
                callCB(self.fibemu, cb, 0, 'connected')
            except Exception as e:
                callCB(self.fibemu, cb, 1, str(e))
        Thread(target=asyncio.run, args=(runner(),)).start()

    def send(self, msg):
        try:
            msg = bytes(msg.values())
            self.sock.sendall(msg)
            return 0, len(msg)
        except Exception as e:
            return 1, "Bad file descriptor"

    def close(self):
        self.sock.close()

    def recieve(self, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            try:
                msg = await loop.sock_recv(self.sock, 4096)
                msg = list(msg)
                if len(msg) == 0:
                    callCB(self.fibemu, cb, 1, "End of file")
                else:
                    callCB(self.fibemu, cb, 0, msg)
            except socket.timeout:
                callCB(self.fibemu, cb, 1, "operation cancelled")
            except Exception as e:
                callCB(self.fibemu, cb, 1, str(e))
        Thread(target=asyncio.run, args=(runner(),)).start()

    def receieveUntil(self, until, cb):
        async def runner():
            loop = asyncio.get_running_loop()
            callCB(self.fibemu, cb, 1, "not implemented")
        Thread(target=asyncio.run, args=(runner(),)).start()


class LuaUDPSocket:
    def __init__(self, fibemu):
        self.fibemu = fibemu
        self.sock = socket.socket(
            family=socket.AF_INET, type=socket.SOCK_DGRAM)
        self.sock.setblocking(False)

    def bind(self, localIP, localPort):
        try:
            self.sock.bind((localIP, localPort))
            return 0, ""
        except Exception as e:
            return 1, str(e)

    def settimeout(self, value):
        self.sock.settimeout(value/1000)
        self.sock.setblocking(False)

    def setoption(self, option, flag):
        if option == "broadcast":
            self.sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_BROADCAST, flag and 1 or 0)
        elif option == "reuseport":
            self.sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_REUSEPORT, flag and 1 or 0)
        elif option == "reuseaddr":
            self.sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_REUSEADDR, flag and 1 or 0)
        self.sock.setblocking(False)

    async def _sendto(self, msg, ip, port, cb):
        try:
            loop = asyncio.get_running_loop()
            # for b in msg.values():
            #     print(f"{b:02x} ",end="", file=sys.stderr)
            # print(file=sys.stderr)
            msg = bytes(msg.values())
            await loop.sock_sendto(self.sock, msg, (ip, port))
            callCB(self.fibemu, cb, 0, len(msg))
        except Exception as e:
            # print(str(e), file=sys.stderr)
            callCB(self.fibemu, cb, 1, "Bad file descriptor", str(e))

    def sendto(self, msg, ip, port, cb):
        Thread(target=asyncio.run, args=(
            self._sendto(msg, ip, port, cb),)).start()

    def close(self):
        self.sock.close()

    def recieve(self, cb):
        async def runner():
            try:
                loop = asyncio.get_running_loop()
                msgFromServer, addr = await loop.sock_recvfrom(self.sock, 4096)
                msg = list(msgFromServer)
                if len(msg) == 0:
                    callCB(self.fibemu, cb, 1, "End of file")
                else:
                    callCB(self.fibemu, cb, 0, msg, addr[0], addr[1])
            except socket.timeout:
                callCB(self.fibemu, cb, 1, "operation cancelled")
            except Exception as e:
                callCB(self.fibemu, cb, 1, str(e))
        Thread(target=asyncio.run, args=(runner(),)).start()


class LuaWebSocket:
    #    websocket.enableTrace(True)
    def __init__(self, fibemu, url, headers, cb):
        # websocket.enableTrace(True)
        self.closed = True
        self.fibemu = fibemu
        self.cb = cb
        headers = json.loads(headers) if headers else {}
        sslCon=ssl.SSLContext(ssl.PROTOCOL_TLS)
        sslCon.options |= (
            ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1 | ssl.OP_NO_TLSv1_2
        )
        self.ws = websocket.WebSocketApp(url=url,  # "wss://api.gemini.com/v1/marketdata/BTCUSD",
                                         header=headers,
                                         on_open=lambda ws: self.on_open(ws),
                                         on_message=lambda ws, msg: self.on_message(
                                             ws, msg),
                                         on_error=lambda ws, err: self.on_error(
                                             ws, err),
                                         on_close=lambda ws, stat, msg: self.on_close(ws, stat, msg))
        self.closed = False
        print(f"SSL VERSION: {ssl.OPENSSL_VERSION}", file=sys.stderr)
        Thread(target=self.ws.run_forever, kwargs={'sslopt':{"cert_reqs": ssl.CERT_NONE}}).start()

    def on_message(self, ws, message):
        callCB(self.fibemu, self.cb, "dataReceived", message)

    def on_error(self, ws, error):
        callCB(self.fibemu, self.cb, "error", str(error))

    def on_close(self, ws, close_status_code, close_msg):
        self.closed = True
        self.close()
        callCB(self.fibemu, self.cb, "disconnected", str(close_status_code))

    def on_open(self, ws):
        callCB(self.fibemu, self.cb, "connected")

    def send(self, msg):
        return self.ws.send(msg)

    def close(self):
        self.ws.close()

    def isOpen(self):
        return self.closed


class LuaMQTTClient:
    def __init__(self, fibemu, cb):
        self.fibemu = fibemu
        self.cb = cb
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        client.enable_logger()
        client.on_connect = lambda client, userdata, flags, rc, props: self.on_connect(
            client, userdata, flags, rc)
        client.on_message = lambda client, userdata, msg: self.on_message(
            client, userdata, msg)
        self.client = client

    def connect(self, url, port, keepalive):
        self.client.connect(url, port, keepalive)
        Thread(target=self.client.loop_forever).start()

    def disconnect(self):
        self.client.disconnect()

# The callback for when the client receives a CONNACK response from the server.
    def on_connect(self, client, userdata, flags, rc):
        print(f"Connected with result code {rc}", file=sys.stderr)
        callCB(self.fibemu, self.cb, "on_connect", flags.session_present, rc.value)

    def on_message(self, client, userdata, msg):
        topic = msg.topic
        resp = { 
            "topic": msg.topic, 
            "payload": msg.payload.decode('utf-8'),
            "qos": msg.qos,
            "retain": msg.retain,
            "dup": msg.dup
        }
        callCB(self.fibemu, self.cb, "on_message", resp)

    def on(self, cbs):
        self.callbacks = cbs

    # client.subscribe("$SYS/#")
    def subscribe(self, topic, options):
        try:
            self.client.subscribe(topic)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)

    # client.unsubscribe("$SYS/#")
    def unsubscribe(self, topic):
        return self.client.subscribe(topic)

    def publish(self, topic, message):
        return self.client.publish(topic, message)