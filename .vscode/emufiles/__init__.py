import uvicorn
import sys
import os, socket
import argparse
import fibapi
import json
from fibenv import FibaroEnvironment

app = fibapi.app

# main startup
if __name__ == "__main__":
    global config
    version = "0.36"
    parser = argparse.ArgumentParser(
                    prog='fibemu',
                    description='QA/HC3 emulator for HC3',
                    epilog='jan@gabrielsson.com')

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

    parser.add_argument('-f', "--file", help='initial QA to load')
    parser.add_argument('-f2', "--file2", help='second QA to load')
    parser.add_argument('-f3', "--file3", help='third QA to load')
    parser.add_argument('-l', "--local", help='run with no HC3 connection', action='store_true')
    parser.add_argument('-h3', "--host", help='HC3 host name or IP')
    parser.add_argument('-u', "--user", help='HC3 user name')
    parser.add_argument('-pwd', "--password", help='HC3 user password')
    parser.add_argument('-p', "--port", help='HC3 port', default=80, type=int)
    parser.add_argument('-i', '--init', help='init file')
    parser.add_argument('-e', '--emulator', help='emulator file', default='emu.lua')
    parser.add_argument('-b', "--stop", help='debuger break on load file', action='store_true')
    parser.add_argument('-nw', '--noweb', help='no web api', action='store_true')
    parser.add_argument('-ng', "--nogreet", help='No emulator greet message', action='store_true')
    parser.add_argument('-wp', '--wport', default=5004, help='port for web/api interface', type=int)
    parser.add_argument('-wh', '--whost', default='0.0.0.0', help='host for webserver')
    parser.add_argument('-wlv', '--web_log_level', default='warning', help='log level for webserver',choices=['debug', 'info', 'trace', 'warning', 'error', 'critical'])
    parser.add_argument('-extra', '--extra', nargs='*', help='extra arguments for QA', default=[]) 

    args = parser.parse_args()
    config['local'] = args.local
    config['user'] = args.user or config.get('user') or os.environ.get('HC3_USER')
    config['password'] = args.password or config.get('password') or os.environ.get('HC3_PASSWORD')
    config['host'] = args.host or config.get('host') or os.environ.get('HC3_HOST')
    config['port'] = args.port or config.get('port') or os.environ.get('HC3_PORT')
    config['wport'] = args.wport or config.get('wport') or os.environ.get('FIBEMU_PORT')
    config['whost'] = args.whost or config.get('whost') or os.environ.get('FIBEMU_HOST')
    config['wlog'] = args.web_log_level
    config['emulator'] = args.emulator
    config['init'] = args.init
    config['break'] = args.stop
    config['file1'] = args.file or "qa2.lua"
    config['file2'] = args.file2 or None
    config['file3'] = args.file3 or None
    config['version'] = version
    config['server'] = args.noweb
    config['path'] = ".vscode/emufiles/"
    config['argv'] = sys.argv
    config['extra'] = args.extra
    config['nogreet'] = args.nogreet
    hostname=socket.gethostname()
    config['hostIP'] = socket.gethostbyname(hostname)
    config['hostName']= socket.gethostname()   


    config['apiURL'] =  f"http://localhost:{config['wport']}/api"
    config['apiDocURL'] =  f"http://localhost:{config['wport']}/docs"
    config['webURL'] =  f"http://localhost:{config['wport']}/"
    
    if not config['local'] and  (not config['user'] or not config['password'] or not config['host']):
        print("Missing HC3 connection info for non-local run",file=sys.stderr)
        sys.exit(1)

    f = FibaroEnvironment(config)
    fibapi.fibenv['fe'] = f
    f.run()
    if not args.noweb:
        uvicorn.run("__init__:app", host=config['whost'], port=config['wport'], log_level=config['wlog'])
    else:
        print("Web server disabled",file=sys.stderr)