#!/usr/bin/env python
 
# Original work by Rowan James at https://gist.github.com/rowanj/5475988
# This is free and unencumbered software released into the public domain.
# http://unlicense.org

import argparse
import subprocess
import os
import glob
import stat

parser = argparse.ArgumentParser(description='Sign an app and all frameworks therein')
parser.add_argument('--app',
                    required=True,
                    help='the app bundle to sign')
parser.add_argument('--key',
                    help='the key ID to sign with',
                    default='Developer ID Application')
parser.add_argument('--frameworks','-f',
                    help='sign embedded frameworks',
                    action='store_const',const=True)
parser.add_argument('--resources','-r',
                    help='sign embedded executable resources',
                    action='store_const',const=True)
parser.add_argument('--verbose','-v',
                    help='show details of signing process',
                    action='count')

args = parser.parse_args()

if args.verbose:
    print 'Signing configuration:'
    print 'APP = ' + args.app
    print 'ID = ' + args.key
    print 'FRAMEWORKS = %r' % (args.frameworks)
    print 'RESOURCES = %r' % (args.resources)
    print 'VERBOSE = %r' % (args.verbose)

def sign(target):
    print 'Signing ' + os.path.basename(target)
    codesign = ['codesign', '--force', '--verify']
    if args.verbose:
        for i in range(args.verbose):
            codesign = codesign + ['--verbose']
    codesign = codesign + ['--sign', args.key]
    subprocess.call(codesign + [target])

if args.frameworks:
    frameworkDir = os.path.join(args.app, 'Contents/Frameworks')
    for framework in glob.glob(frameworkDir + '/*.framework'):
        sign(framework)

if args.resources:
    executableFlags = stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH
    resourcesDir = os.path.join(args.app, 'Contents/Resources')
    for filename in os.listdir(resourcesDir):
        filename = os.path.join(resourcesDir, filename)
        if os.path.isfile(filename):
            st = os.stat(filename)
            mode = st.st_mode
            if mode & executableFlags:
                sign(filename)

sign(args.app)
