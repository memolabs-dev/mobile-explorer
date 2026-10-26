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
    parser.add_argument("--native-roundtrip",action="store_true",
                        help="synthetic native Save/Open acceptance in temporary app")
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
        if args.native_roundtrip:
            # The production model remains unchanged; only scratch DEBUG
            # source has a test-specific initial directory for panels.
            source=tmp/"Sources"/"MobileExplorer"/"ExplorerModel.swift"
            body=source.read_text()
            additional='        #if DEBUG\n        if let dir = ProcessInfo.processInfo.environment["ME_GUI_SCRATCH"] {\n            panel.directoryURL = URL(fileURLWithPath: dir, isDirectory: true)\n        }\n        #endif\n'
            for anchor in ['        panel.nameFieldStringValue = "mobile-explorer-draft.json"',
                           '        panel.allowsMultipleSelection = false']:
                if body.count(anchor)!=1:
                    print("NATIVE_FAIL: model panel source changed",file=sys.stderr)
                    return 1
                body=body.replace(anchor,additional+anchor)
            source.write_text(body)
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
            start=["/usr/bin/open","-n"]
            if args.native_roundtrip:
                start.extend(["--env","ME_GUI_SCRATCH="+str(tmp)])
            start.append(str(d.parent.parent))
            opened=subprocess.run(start,capture_output=True,text=True,timeout=18)
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
            if not args.native_roundtrip:
                return 0
            def locate(parent,key):
                for i in range(1,10):
                    c=osa('tell application "System Events" to tell process "'+NAME+
                        '" to get value of attribute "AXIdentifier" of button '+str(i)+' '+parent)
                    if c.returncode==0 and c.stdout.strip()==key:return i
                return None
            # Dismiss auxiliary post-create AXDialog before opening Save.
            osa('tell application "'+NAME+'" to activate')
            osa('tell application "System Events" to tell process "'+NAME+'" to key code 53')
            time.sleep(.3)
            save_idx=locate(right,"draft.save")
            if save_idx is None:
                print("NATIVE_SAVE_FAIL: missing Save button",file=sys.stderr)
                return 1
            q=osa('tell application "System Events" to tell process "'+NAME+
                '" to click button '+str(save_idx)+' '+right)
            visible=False
            for _ in range(22):
                c=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get entire contents of window 1')
                if c.returncode==0 and "Save As" in c.stdout:
                    visible=True
                    break
                time.sleep(.25)
            if q.returncode or not visible:
                print("NATIVE_SAVE_FAIL: Save As dialog not confirmed",file=sys.stderr)
                return 1
            osa('tell application "'+NAME+'" to activate')
            enter=osa('tell application "System Events" to tell process "'+NAME+'" to key code 36')
            draft=tmp/"mobile-explorer-draft.json"
            until=time.monotonic()+10
            while time.monotonic()<until and not draft.is_file():time.sleep(.35)
            if enter.returncode or not draft.is_file():
                print("NATIVE_SAVE_FAIL: draft not written into test directory",file=sys.stderr)
                return 1
            from stat import S_IMODE
            try:body=json.loads(draft.read_text())
            except (ValueError,OSError):
                print("NATIVE_SAVE_FAIL: draft content unreadable",file=sys.stderr)
                return 1
            if (body.get("schemaVersion")!="1"
                or body.get("applicationName")!="Synthetic GUI Fixture"
                or len(body.get("steps",[]))!=1
                or S_IMODE(draft.stat().st_mode)!=0o600):
                print("NATIVE_SAVE_FAIL: file structure or mode incorrect",file=sys.stderr)
                return 1
            print("NATIVE_SAVE_PASS: NSSavePanel wrote a private JSON draft")
            osa('tell application "System Events" to tell process "'+NAME+'" to quit')
            subprocess.run(["/usr/bin/pkill","-f",str(binary)],
                           capture_output=True,text=True,timeout=10)
            restart=subprocess.run(start,capture_output=True,text=True,timeout=20)
            if restart.returncode:
                print("NATIVE_OPEN_FAIL: fresh app not launched",file=sys.stderr)
                return 1
            open_idx=None
            until=time.monotonic()+15
            while time.monotonic()<until and open_idx is None:
                open_idx=locate(sidebar,"draft.open")
                if open_idx is None:time.sleep(.55)
            if open_idx is None:
                print("NATIVE_OPEN_FAIL: missing Open button",file=sys.stderr)
                return 1
            action=osa('tell application "System Events" to tell process "'+NAME+
                '" to click button '+str(open_idx)+' '+sidebar)
            time.sleep(.75)
            kind=osa('tell application "System Events" to tell process "'+NAME+
                '" to get subrole of window 1')
            if action.returncode or kind.stdout.strip()!="AXDialog":
                print("NATIVE_OPEN_FAIL: Open panel not confirmed",file=sys.stderr)
                return 1
            picked=osa('tell application "System Events" to tell process "'+NAME+
                '" to keystroke "mobile-explorer-draft.json"')
            time.sleep(.45)
            accept=osa('tell application "System Events" to tell process "'+NAME+'" to key code 36')
            if picked.returncode or accept.returncode:
                print("NATIVE_OPEN_FAIL: selection keystrokes failed",file=sys.stderr)
                return 1
            until=time.monotonic()+12
            okay=False
            while time.monotonic()<until:
                contents=osa('tell application "System Events" to tell process "'+NAME+
                    '" to get entire contents of scroll area 1 of group 2 of splitter group 1 of group 1 of '+win)
                if contents.returncode==0 and "Synthetic GUI Fixture" in contents.stdout:
                    n=osa('tell application "System Events" to tell process "'+NAME+
                        '" to get count of text fields '+right)
                    try:okay=n.returncode==0 and int(n.stdout.strip())>=4
                    except ValueError:okay=False
                    if okay:break
                time.sleep(.55)
            if not okay:
                print("NATIVE_OPEN_FAIL: saved workspace not restored in fresh process",file=sys.stderr)
                return 1
            print("NATIVE_OPEN_PASS: NSOpenPanel restored editable observation in fresh process")
            print("GUI_NATIVE_ROUNDTRIP_PASS: create, Save, restart, Open")
            return 0
        finally:
            osa('tell application "System Events" to tell process "'+NAME+'" to quit')
            subprocess.run(["/usr/bin/pkill","-f",str(binary)],capture_output=True,text=True,timeout=10)
            if previous and previous!=NAME and all(c.isalnum() or c in " ._-" for c in previous):
                osa("tell application "+json.dumps(previous)+" to activate")

if __name__=="__main__":
    sys.exit(main())
