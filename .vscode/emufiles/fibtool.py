import sys
import argparse
import requests
import io
import json
import os
import signal
import re
from datetime import datetime

TIMEOUT = 20
now = datetime.now()

tqaeHeader = """
_=loadfile and loadfile("TQAE.lua"){
  refreshStates=true,
  debug = {
    onAction=true, http=false, UIEevent=true, trigger=true, post=true, dailys=true, pubsub=true, qa=true-- timersSched=true
  },
  --startTime="18:10:00",
  --offline=true
}"""

def dict2lua(d: dict, simple=False) -> str:
    s = "{"
    for k, v in d.items():
        key = k if simple else f"[\"{k}\"]"
        if isinstance(v, str):
            s += f"{key}=\"{v}\","
        else:
            s += f"{key}={v},"
    s += "}"
    return s


def arr2lua(d: dict) -> str:
    s = "{"
    for v in d:
        s += dict2lua(v)+","
    s += "}"
    return s


def httpGet(path: str) -> str:
    global config
    url = f"http://{config['host']}/api{path}"
    try:
        resp = requests.get(
            url,
            timeout=TIMEOUT,
            auth=(config['user'], config['password']),
            headers={'Content-Type': 'application/json', 'X-Fibaro-Version': '2'})
    except requests.exceptions.ReadTimeout:
        return httpGet(str)  # add tail recursion? decorator?
    if resp.status_code != 200:
        raise Exception('GET {} {}'.format(url, resp.status_code))
    else:
        return resp.text


def httpPost(path: str, data: dict) -> str:
    global config
    url = f"http://{config['host']}/api{path}"
    resp = requests.post(
        url,
        auth=(config['user'], config['password']),
        timeout=TIMEOUT,
        headers={'Content-Type': 'application/json', 'X-Fibaro-Version': '2'},
        data=json.dumps(data))
    if resp.status_code != 200:
        raise Exception('GET {} {}'.format(url, resp.status_code))
    else:
        return resp.text


def httpPut(path: str, data: dict) -> str:
    global config
    url = f"http://{config['host']}/api{path}"
    resp = requests.put(
        url,
        auth=(config['user'], config['password']),
        timeout=TIMEOUT,
        headers={'Content-Type': 'application/json', 'X-Fibaro-Version': '2'},
        data=json.dumps(data))
    if resp.status_code != 200:
        raise Exception('PUT {} {}'.format(url, resp.status_code))
    else:
        return resp.text


def httpDelete(path: str, data: dict) -> str:
    global config
    url = f"http://{config['host']}/api{path}"
    resp = requests.delete(
        url,
        auth=(config['user'], config['password']),
        timeout=TIMEOUT,
        headers={'Content-Type': 'application/json', 'X-Fibaro-Version': '2'})
    if resp.status_code != 200:
        raise Exception('DELETE {} {}'.format(url, resp.status_code))
    else:
        return resp.text


def ui(view: dict, uiCallbacks: dict) -> list:
    d = {}
    for cb in uiCallbacks:
        d[cb['name']] = cb['callback']
    rows = []
    for row in view:
        line = []
        for item in row['components']:
            if item.get('name'):
                match item['type']:
                    case 'button':
                        line.append({"button": item['name'], "text": item['text'], "onReleased": d[item['name']]})
                    case 'slider':
                        line.append({"slider": item['name'], "text": item['text'], "onChanged": d[item['name']]})
                    case 'label':
                        line.append({"label": item['name'], "text": item['text']})
        rows.append(line)
    return rows


def addTQAEheader(fqa: dict, params: dict, fns: dict) -> dict:
    if not params.tqae:
        return fqa
    header = io.StringIO()
    header.write(tqaeHeader+"\n\n")
    header.write(f"--%%name=\"{fqa['name']}\"\n")
    header.write(f"--%%type=\"{fqa['type']}\"\n")
    header.write(f"--%%version={fqa['apiVersion']}\n")
    props = fqa.get('initialProperties')

    if props:
        qv0 = props.get('quickAppVariables')
        if qv0:
            qv1 = {}
            for qv in qv0:
                qv1[qv['name']] = qv['value']
            header.write(f"--%%quickVars={dict2lua(qv1)}\n")

        viewLayout = props.get('viewLayout')
        uiCallbacks = props.get('uiCallbacks')
        n = 0
        if viewLayout:
            rows = ui(viewLayout['$jason']['body']['sections']['items'], uiCallbacks)
            for row in rows:
                n += 1
                if len(row) == 1:
                    header.write(f"--%%ui{n}={dict2lua(row[0],True)}\n")
                else:
                    header.write(f"--%%ui{n}={arr2lua(row)}\n")

    files = fqa.get('files')
    for file in files:
        if file.get('isMain'):
            continue
        header.write(f"--FILE:{fns[file['name']]},{file['name']};\n")

    header.write("---------- Code ----------\n\n")
    for f in fqa['files']:
        if f.get('isMain') and f['content'].find('_=loadfile and loadfile("TQAE.lua")') < 0:
            f['content'] = header.getvalue() + f['content']
            break
    return fqa


def showTrigger(args: dict):
    # catch SIGTERM
    signal.signal(signal.SIGTERM, lambda a, b: sys.exit(0))
    signal.signal(signal.SIGINT, lambda a, b: sys.exit(0))

    last = 0
    while (True):
        data = httpGet("/refreshStates?last="+str(last))
        data = json.loads(data)
        last = data['last']
        if data.get('events'):
            for e in data['events']:
                epoc = e['createdMillis']
                date = datetime.fromtimestamp(epoc // 1000)
                h = f"{date.strftime('%m-%d/%H:%M:%S/')}{(epoc % 1000):03d}:{e['type']}"
                d = json.dumps(e['data'])
                styp = e.get('sourceType')
                who = ""
                if styp:
                    if styp == 'system':
                        who = "S:"
                    elif styp == 'user':
                        who = f"U{e.get('sourceId')}:"
                    else:
                        who = styp + ":"
                st = f"{h:<45}:{who}{d}"
                # print(e)
                print(st[:160])


def dumpResource(rsrc: dict, params, ext, hook=None) -> None:
    rid = rsrc['keyid']
    rsrc = rsrc['rsrc']
    if not params.split:
        if hook:
            rsrc = hook(rsrc, params, {})
        rname = rsrc['name'].replace(" ", "_")
        name = params.template.replace("%N", rname)
        name = name.replace("%ID", rid)
        name = now.strftime(name)
        if params.dir:
            params.dir = now.strftime(params.dir)
            os.makedirs(params.dir, exist_ok=True)
        fname = os.path.join(params.dir, name) if params.dir else name
        print(f"Saving {fname}.{ext}")
        if not params.dry:
            with open(f"{fname}.{ext}", "w") as f:
                f.write(json.dumps(rsrc, indent=2))
    else:
        rname = rsrc['name'].replace(" ", "_")
        sname = params.split.replace("%N", rname)
        sname = sname.replace("%ID", rid)
        sname = now.strftime(sname)
        if params.dir:
            params.dir = now.strftime(params.dir)
        sname = os.path.join(params.dir, sname) if params.dir else sname
        if not params.dry:
            os.makedirs(sname, exist_ok=True)
        files = rsrc.get('files')
        fns = {}
        for file in files:
            fns[file['name']] = f"{sname}/{file['name']}.lua"
        if hook:
            rsrc = hook(rsrc, params, fns)
        for file in files:
            print(f"Saving {fns[file['name']]}")
            if not params.dry:
                with open(fns[file['name']], "w") as f:
                    f.write(file['content'])
        print(f"Saving {sname}/{rname}.json")
        rsrc['files'] = []
        if not params.dry:
            with open(f"{sname}/{rname}.json", "w") as f:
                f.write(json.dumps(rsrc, indent=2))


def deleteResource(rid: str, path: str, params: dict) -> None:
    print(f"Deleting {path}/{rid}")
    if params.dry:
        return


def dumpFqa(data, params) -> None:
    dumpResource(data, params, 'fqa', addTQAEheader)


def dumpScene(data, params) -> None:
    dumpResource(data, params, 'scene')


def dumpGV(data, params) -> None:
    dumpResource(data, params, 'gv')


def deleteFqa(data, params) -> None:
    deleteResource(data['id'], "/devices", params)


def deleteScene(data, params) -> None:
    deleteResource(data['id'], "/scenes", params)


def deleteGV(data, params) -> None:
    deleteResource(data['name'], "/globalVariables", params)


def getResource(path1: str, path2: str, key: str, args) -> list:
    if args.id:
        rsrcs = []
        simple = path1 == path2
        rid = args.id
        if rid.isdigit():
            rsrcs.append(rid)
        else:
            rid = ".*" if rid == "." else rid
            res = json.loads(httpGet(path1))
            for rsrc in res:
                keyid = str(rsrc[key])
                if re.search(id, keyid):
                    rsrcs.append({'rsrc': rsrc, 'keyid': keyid} if simple else rsrc[key])
            if simple:
                return rsrcs
        res = []
        for rid in rsrcs:
            res.append({'rsrc': json.loads(httpGet(path2+"/"+str(rid))), 'keyid': str(rid)})
        return res
    else:
        return []


def parse_cmd() -> None:
    global config
    parser = argparse.ArgumentParser(
                    prog='fibtool',
                    description='command line tool for fibaro HC3',
                    epilog='jan@gabrielsson.com')

    try:
        with open(os.path.expanduser('~') + '/.fibtool') as f:
            config = json.load(f)
    except Exception:
        config = {}

    parser.add_argument('resource', help='hc3 resource', choices=['qa', 'scene', 'gv', 'trigger'])
    parser.add_argument('command', help='command to execute', choices=['get', 'upload', 'patch', 'delete', 'info', 'show'])
    parser.add_argument('-id', '--id', help='resource id on HC3')
    parser.add_argument('-n', '--name', help='resource name on hc3')
    parser.add_argument('-f', '--file', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
    parser.add_argument('-s', '--split', nargs='?', action='store', const='%N', help='split directory name, supports Supports %%ID,%%N and strftime args. Default "%%N"')
    parser.add_argument('-d', '--dir', help='directory for output, template supporting strftime args')
    parser.add_argument('-ip', '--ip', help='ip address to hc3')
    parser.add_argument('-u', '--user', help='user at hc3')
    parser.add_argument('-p', '--password', help='password at hc3')
    parser.add_argument('-t', '--template', default="%ID_%N", help='name template for output file. Supports %%ID,%%N and strftime args. Default "%%ID_%%N"')
    parser.add_argument('-tqae', '--tqae', action='store_const', const=True,  help='add TQAE headers to main file of QA if missing')
    parser.add_argument('-dry', '--dry', action='store_const', const=True, help="don't write any file or make changes on hc3")
    args = parser.parse_args()
    config['ip'] = args.ip or config.get('ip') or os.environ.get('FIBTOOL_IP')
    config['host'] = config['ip']
    config['user'] = args.ip or config.get('user') or os.environ.get('FIBTOOL_USER')
    config['password'] = args.ip or config.get('password') or os.environ.get('FIBTOOL_PASSWORD')

    match args.resource:
        case 'qa':
            match args.command:
                case 'get':
                    for qa in getResource("/devices?interface=quickApp", "/quickApp/export", "id", args):
                        dumpFqa(qa, args)
                case 'upload':
                    pass
                case 'patch':
                    pass
                case 'delete':
                    pass
                case 'info':
                    pass

        case 'scene':
            match args.command:
                case 'get':
                    for scene in getResource("/scenes", "/scenes", "id", args):
                        dumpScene(scene, args)
                case 'upload':
                    pass
                case 'patch':
                    pass
                case 'delete':
                    pass
                case 'info':
                    pass

        case 'gv':
            if args.template == "%ID_%N":
                args.template = "%N"
            match args.command:
                case 'get':
                    for gv in getResource("/globalVariables", "/globalVariables", "name", args):
                        dumpGV(gv, args)
                case 'upload':
                    pass
                case 'patch':
                    pass
                case 'delete':
                    for gv in getResource("/globalVariables", "/globalVariables", "name", args):
                        deleteGV(gv, args)
                case 'info':
                    pass

        case 'trigger':
            showTrigger(args)


if __name__ == "__main__":
    global config

    try:
        with open(os.path.expanduser('~') + '/.fibemu.json') as f:
            config = json.load(f)
    except Exception:
        config = {}

    try:
        with open('config.json') as f:
            config_d = json.load(f)
            for key, value in config_d.items():
                config[key] = value
    except Exception as e:
        print(e)

    print(config)

    if len(sys.argv) == 1:
        """
        sys.argv="fibtool --help".split()
        sys.argv="fibtool qa -f /Users/jangabrielsson/Desktop/dev/fibtool/TelegramBot.fqa".split()
        sys.argv="fibtool qa get -id . -d test -t QA%ID_%Y_%N".split()
        sys.argv="fibtool gv get -id . -d test".split()
        sys.argv="fibtool gv delete -id RPC_.* -d test -dry".split()
        sys.argv="fibtool qa get -id 54 -s -d test -tqae".split()
        sys.argv="fibtool -h".split()
        """
        #sys.argv = "fibtool trigger show".split()
        sys.argv="fibtool qa get -id 1111 -d test -t QA%ID_%Y_%N".split()
    parse_cmd()
