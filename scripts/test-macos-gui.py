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
            # The main window can temporarily move from window 1 when macOS
            # displays an auxiliary input popover. Always target it by name.
            win='window "'+NAME+'"'
            sidebar="of group 1 of splitter group 1 of group 1 of "+win
            value=osa('tell application "System Events" to tell process "'+NAME+
                '" to set value of text field 1 '+sidebar+' to "Synthetic GUI Fixture"')
            if value.returncode!=0:
                print("GUI_CREATE_FAIL: unable to enter synthetic app name",file=sys.stderr)
                return 1
            create_index=None
            for i in range(1,10):
                button=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get value of attribute "AXIdentifier" of button '+str(i)+' '+sidebar)
                if button.returncode==0 and button.stdout.strip()=="manual.create":
                    create_index=i
                    break
            if create_index is None:
                print("GUI_CREATE_FAIL: create action missing",file=sys.stderr)
                return 1
            clicked=osa('tell application "System Events" to tell process "'+NAME+
                '" to click button '+str(create_index)+' '+sidebar)
            if clicked.returncode!=0:
                print("GUI_CREATE_FAIL: create action rejected",file=sys.stderr)
                return 1
            osa('tell application "'+NAME+'" to activate')
            osa('tell application "System Events" to tell process "'+NAME+'" to key code 53')
            right="of scroll area 1 of group 2 of splitter group 1 of group 1 of "+win
            workspace=False
            stop=time.monotonic()+13
            while time.monotonic()<stop:
                text=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get entire contents of scroll area 1 of group 2 of splitter group 1 of group 1 of '+win)
                if text.returncode==0 and "FICHE D'OBSERVATION" in text.stdout and "Synthetic GUI Fixture" in text.stdout:
                    workspace=True
                    break
                time.sleep(.7)
            if not workspace:
                print("GUI_CREATE_FAIL: no observation workspace after create",file=sys.stderr)
                return 1
            print("GUI_CREATE_PASS: synthetic manual app visible in real SwiftUI workspace")
            add_index=None
            for i in range(1,8):
                control=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get value of attribute "AXIdentifier" of button '+str(i)+' '+right)
                if control.returncode==0 and control.stdout.strip()=="observation.add":
                    add_index=i
                    break
            if add_index is None:
                print("GUI_ADD_FAIL: add observation button unavailable",file=sys.stderr)
                return 1
            add=osa('tell application "System Events" to tell process "'+NAME+
                '" to click button '+str(add_index)+' '+right)
            if add.returncode!=0:
                print("GUI_ADD_FAIL: click was rejected",file=sys.stderr)
                return 1
            stop=time.monotonic()+9
            fields=0
            while time.monotonic()<stop:
                res=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get count of text fields '+right)
                if res.returncode==0:
                    try: fields=int(res.stdout.strip())
                    except ValueError: fields=0
                if fields>=4:break
                time.sleep(.5)
            if fields<4:
                print("GUI_ADD_FAIL: observation fields were not available",file=sys.stderr)
                return 1
            print("GUI_ADD_PASS: new observation with four editable fields")
            return 0
        finally:
            osa('tell application "System Events" to tell process "'+NAME+'" to quit')
            subprocess.run(["/usr/bin/pkill","-f",str(binary)],capture_output=True,text=True,timeout=10)
            if previous and previous!=NAME and all(c.isalnum() or c in " ._-" for c in previous):
                osa("tell application "+json.dumps(previous)+" to activate")

if __name__=="__main__":
    sys.exit(main())
