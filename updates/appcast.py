#!/usr/bin/env python

from email.Utils import formatdate
from string import Template
from argparse import ArgumentParser
from hashlib import sha1
import subprocess
import base64

parser = ArgumentParser(description='Create an appcast XML file from a template')
parser.add_argument('--bundle_file','-f',
		    required=True,
		    help='The bundle file to generate the appcast for')
parser.add_argument('--build_number','-n',
		    required=True,
		    help='The build number of the app')
parser.add_argument('--signing_key',
		    help='The DSA key to sign the update with')
parser.add_argument('--template_file',
		    required=True,
		    help='The template XML file')
parser.add_argument('--output','-o',
		    help='Write the output to this file instead of STDOUT')

args = parser.parse_args()

bundle = open(args.bundle_file, 'r').read()

templateSource = open(args.template_file, 'r').read()

attrs = dict()
attrs['build_number'] = args.build_number
attrs['pub_date'] = formatdate()
attrs['file_size'] = len(bundle)

if args.signing_key:
    hash = sha1(bundle).digest()
    keyFile = open(args.signing_key, 'r')
    signProc = subprocess.Popen(['openssl',
				 'dgst',
				 '-dss1',
				 '-sign',
				 args.signing_key],
		     stdin=subprocess.PIPE,
		     stdout=subprocess.PIPE)
    signProc.stdin.write(hash)
    binsig = signProc.communicate()[0]
    attrs['file_sig'] = base64.b64encode(binsig)

result = Template(templateSource).substitute(attrs)

if args.output:
    outputFile = open(args.output, 'w')
    outputFile.write(result)
else:
    print result
