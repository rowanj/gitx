#!/usr/bin/env python

import argh
import subprocess
import os

import package
import sign

app = "GitX"
product = "%s.app" % (app,)
label = "dev"
base_version = "0.15"
signing_key = "Developer ID Application: Rowan James"

artifact_prefix = "%s-%s" % (app, label)
workspace = "%s.xcodeproj/project.xcworkspace" % (app,)
debug_scheme = "Debug"
release_scheme = "Release"
agvtool = "xcrun agvtool"
release_branch = "master"

updates_template_file = os.path.join('updates', 'GitX-dev.xml.tmpl')
release_notes_file = os.path.join('updates', 'GitX-dev.html')
updates_signing_key_file = os.path.expanduser(os.path.join('~', 'Documents', 'gitx-updates.key'))
updates_appcast_file = 'GitX-dev.xml'

clean = ""
pause = 3

build_base_dir = os.path.join(os.getcwd(), "build")


class BuildError(RuntimeError):
    pass


def clean():
    clean_scheme(debug_scheme)
    clean_scheme(release_scheme)


def release():
    try:
        assert_clean()
        assert_branch(release_branch)
        build_number = commit_count()
        set_versions(base_version, build_number, "dev")

        build_scheme(release_scheme)

        build_dir = os.path.join(build_base_dir, release_scheme)
        built_product = os.path.join(build_dir, product)
        sign_app(built_product)

        image_path = os.path.join(build_dir, "%s-%s.dmg" % (artifact_prefix, build_number))
        image_name = "%s %s" % (app, build_number)
        package_app(built_product, image_path, image_name)

        prepare_release(build_number, image_path)

    except BuildError as e:
        print("error: %s" % (str(e),))


def debug():
    try:
        build_scheme(debug_scheme)

    except BuildError as e:
        print("error: %s" % (str(e),))


def prepare_release(build_number, image_source_path):
    release_dir = "release"
    try:
        os.makedirs(release_dir)
    except FileExistsError:
        pass

    tag = 'builds/%s/%s' % (base_version, build_number)
    subprocess.check_call(['git', 'tag', tag])

    import appcast
    appcast_text = appcast.generate_appcast(image_source_path, updates_template_file, build_number, updates_signing_key_file)
    with open(os.path.join(release_dir, updates_appcast_file), 'w') as appcast_file:
        appcast_file.write(appcast_text)

    import shutil
    copied_image = os.path.join(release_dir, os.path.basename(image_source_path))
    unversioned_image = os.path.join(release_dir, artifact_prefix + ".dmg")
    shutil.copyfile(image_source_path, copied_image)
    shutil.copyfile(image_source_path, unversioned_image)

    publish_release_notes_file = os.path.join(release_dir, os.path.basename(release_notes_file))
    shutil.copyfile(release_notes_file, publish_release_notes_file)
    publish_release_notes_filebase, publish_release_notes_ext = os.path.splitext(publish_release_notes_file)
    publish_release_notes_version_file = "%s-%s%s" % (publish_release_notes_filebase, build_number, publish_release_notes_ext)
    shutil.copyfile(release_notes_file, publish_release_notes_version_file)


@argh.arg("scheme", choices=['debug', 'release'])
def build(scheme):
    if scheme == "debug":
        debug()
    if scheme == "release":
        release()


def assert_clean():
    status = check_string_output(["git", "status", "--porcelain"])
    if len(status):
        raise BuildError("Working copy must be clean")


def assert_branch(branch="master"):
    ref = check_string_output(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    if ref != branch:
        raise BuildError("HEAD must be %s, but is %s" % (branch, ref))


def build_scheme(scheme):
    build_dir = os.path.join(build_base_dir, scheme)
    xcodebuild(scheme, workspace, ["build"], build_dir)


def clean_scheme(scheme):
    build_dir = os.path.join(build_base_dir, scheme)
    xcodebuild(scheme, workspace, ["clean"], build_dir)


def commit_count():
    count = check_string_output(["git", "rev-list", "HEAD", "--count"])
    return count


def set_versions(base_version, build_number, label):
    print("mvers: " + check_string_output(["agvtool", "mvers", "-terse1"]))
    print("vers:  " + check_string_output(["agvtool", "vers", "-terse"]))
    marketing_version = "%s.%s %s" % (base_version, build_number, label)
    build_version = "%s.%s" % (base_version, build_number)
    subprocess.check_call(["agvtool", "new-marketing-version", marketing_version])
    subprocess.check_call(["agvtool", "new-version", "-all", build_version])


def xcodebuild(scheme, workspace, commands, build_dir):
    cmd = ["xcrun", "xcodebuild", "-scheme", scheme, "-workspace", workspace]
    cmd = cmd + commands
    cmd.append('CONFIGURATION_BUILD_DIR=%s' % (build_dir))
    try:
        output = check_string_output(cmd)
        return output
    except subprocess.CalledProcessError as e:
        raise BuildError(str(e))


def check_string_output(command):
    return subprocess.check_output(command).decode().strip()


def sign_app(app_path):
    sign.sign_everything_in_app(app_path, key=signing_key)


def package_app(app_path, image_path, image_name):
    package.package(app_path, image_path, image_name)

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    argh.dispatch_commands([clean, build])
