#!/usr/bin/env python
 
# Original work by Rowan James
# This is free and unencumbered software released into the public domain.
# http://unlicense.org

import argparse
import subprocess
import tempfile
import shutil
import os

parser = argparse.ArgumentParser(description='Package an app into a redistributable DMG')
parser.add_argument('--app',
                    required=True,
                    help='the app bundle to package')
parser.add_argument('--output','-o',
                    required=True,
                    help='the destination file name')
parser.add_argument('--name','-n',
                    required=True,
                    help='the name given to the volume')
parser.add_argument('--verbose','-v',
                    help='show details of signing process',
                    action='count')

args = parser.parse_args()

def package(app, bundle, name):
    appBase = os.path.dirname(app)
    appName = os.path.basename(app)
    tmp_dir = tempfile.mkdtemp(dir=appBase)
    movedApp = os.path.join(tmp_dir, appName)
    shutil.move(app, movedApp)

    if args.verbose:
        print 'appBase: ' + appBase
        print 'appName: ' + appName
        print 'tmp_dir: ' + tmp_dir

    hdiutil = ['hdiutil',
               'create', bundle,
               '-srcfolder', tmp_dir,
               '-volname', name]
    
    subprocess.call(hdiutil)
    shutil.move(movedApp, app)
    shutil.rmtree(tmp_dir)

package(args.app, args.output, args.name)
