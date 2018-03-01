#!/usr/bin/env python

from email.utils import formatdate
from string import Template
from argparse import ArgumentParser
from hashlib import sha1
import subprocess
import base64


def generate_appcast(bundle_file, template_file, build_number, signing_key_file=None):
    bundle = open(bundle_file, 'rb').read()
    templateSource = open(template_file, 'r').read()

    attrs = dict()
    attrs['build_number'] = build_number
    attrs['pub_date'] = formatdate()
    attrs['file_size'] = len(bundle)

    if signing_key_file:
        hash = sha1(bundle).digest()
        signProc = subprocess.Popen(['openssl',
                                     'dgst',
                                     '-dss1',
                                     '-sign',
                                     signing_key_file],
                                    stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE)
        signProc.stdin.write(hash)
        binsig = signProc.communicate()[0]
        attrs['file_sig'] = base64.b64encode(binsig).decode()

    result = Template(templateSource).substitute(attrs)
    return result


def main():
    parser = ArgumentParser(description='Create an appcast XML file from a template')
    parser.add_argument('--bundle_file', '-f',
                        required=True,
                        help='The bundle file to generate the appcast for')
    parser.add_argument('--build_number', '-n',
                        required=True,
                        help='The build number of the app')
    parser.add_argument('--signing_key',
                        help='The DSA key to sign the update with')
    parser.add_argument('--template_file',
                        required=True,
                        help='The template XML file')
    parser.add_argument('--output', '-o',
                        help='Write the output to this file instead of STDOUT')

    args = parser.parse_args()

    result = generate_appcast(args.bundle_file, args.template_file, args.build_number, args.signing_key)

    if args.output:
        outputFile = open(args.output, 'w')
        outputFile.write(result)
    else:
        print(result)


if __name__ == '__main__':
    main()
