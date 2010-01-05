#!/usr/bin/env arch -i386 macruby

require 'fileutils'

TEST_DIR = File.dirname(__FILE__)
FRAMEWORK_DIR = File.join(TEST_DIR, "..", "build", "Debug", "GitXTesting.framework")

framework FRAMEWORK_DIR
framework 'Cocoa'

TEST_TMP_DIR = File.join(TEST_DIR, "tmp")
FileUtils.mkdir_p(TEST_TMP_DIR)