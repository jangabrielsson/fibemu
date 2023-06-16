import uvicorn
import sys
import fibapi
from fibenv import FibaroEnvironment

app = fibapi.app

# main startup
if __name__ == "__main__":
    fname = sys.argv[1]
    stop=False
    for arg in sys.argv: # poor man's arg parser
        match arg:
            case "-s":
                stop = True
    stop = len(sys.argv)==3 and sys.argv[2] == "-s"
    f = FibaroEnvironment("lua/emu.lua",fname,{"stopOnLoad":stop,"path":".vscode/emufiles/"})
    fibapi.fibenv['fe'] = f
    f.run()
    uvicorn.run("__init__:app", host="127.0.0.1", port=5000, log_level="info")