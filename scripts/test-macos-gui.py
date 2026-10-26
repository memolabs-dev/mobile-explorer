#!/usr/bin/env python3
"""Opt-in non-destructive GUI smoke; uses a temporary app and no real observations."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time

NAME="MobileExplorerUITest"
def osa(script):
    return subprocess.run(["/usr/bin/osascript","-e",script],capture_output=True,text=True,timeout=18)
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--allow-gui",action="store_true")
    args=parser.parse_args()
    if not args.allow_gui:
        parser.error("Explicit --allow-gui required: a test app briefly opens on screen")
    if sys.platform!="darwin":
        print("macOS is required",file=sys.stderr)
        return 2
    current=osa('tell application "System Events" to get name of first application process whose frontmost is true')
    previous=current.stdout.strip() if current.returncode==0 else ""
    repo=Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="mobileexplorer-gui-") as workspace:
        tmp=Path(workspace)
        shutil.copy2(repo/"Package.swift",tmp/"Package.swift")
        shutil.copytree(repo/"Sources",tmp/"Sources")
        shutil.copytree(repo/"Tests",tmp/"Tests")
        build=subprocess.run(["swift","build","-j","2"],cwd=tmp,capture_output=True,text=True,timeout=220)
        if build.returncode!=0:
            print("GUI_BUILD_FAIL: temporary Swift package failed to build",file=sys.stderr)
            return 1
        d=tmp/(NAME+".app")/"Contents"/"MacOS"
        d.mkdir(parents=True)
        binary=d/NAME
        shutil.copy2(tmp/".build"/"debug"/"MobileExplorer",binary)
        binary.chmod(0o755)
        (d.parent/"Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable":NAME, "CFBundleName":NAME,
            "CFBundleIdentifier":"dev.memolabs.mobileexplorer.disposable-test",
            "CFBundlePackageType":"APPL"
        }))
        try:
            opened=subprocess.run(["/usr/bin/open","-n",str(d.parent.parent)],
                                  capture_output=True,text=True,timeout=18)
            if opened.returncode:
                print("GUI_SMOKE_FAIL: launch failed",file=sys.stderr)
                return 1
            path="of group 1 of splitter group 1 of group 1 of window 1"
            expected={"manual.app-name","manual.create","draft.open","device.read-apps"}
            found=set()
            stop=time.monotonic()+16
            while time.monotonic()<stop:
                field=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get value of attribute "AXIdentifier" of text field 1 '+path)
                if field.returncode==0 and field.stdout.strip()=="manual.app-name":
                    found.add("manual.app-name")
                    for i in range(1,10):
                        button=osa('tell application "System Events" to tell process "'+NAME+
                            '" to get value of attribute "AXIdentifier" of button '+str(i)+' '+path)
                        if button.returncode==0 and button.stdout.strip() in expected:
                            found.add(button.stdout.strip())
                    break
                time.sleep(.7)
            if found!=expected:
                print("GUI_SMOKE_FAIL: expected accessible controls missing",file=sys.stderr)
                return 1
            print("GUI_SMOKE_PASS: native app window with four stable controls, no user data read")
            return 0
        finally:
            osa('tell application "System Events" to tell process "'+NAME+'" to quit')
            subprocess.run(["/usr/bin/pkill","-f",str(binary)],capture_output=True,text=True,timeout=10)
            if previous and previous!=NAME and all(c.isalnum() or c in " ._-" for c in previous):
                osa("tell application "+json.dumps(previous)+" to activate")

if __name__=="__main__":
    sys.exit(main())
