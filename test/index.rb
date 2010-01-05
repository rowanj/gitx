#!/usr/bin/env arch -i386 macruby

require 'framework.rb'
require 'test/unit'
require 'tmpdir'

# Setup a temporary directory
TMP_DIR = File.join(TEST_TMP_DIR, "index_test")

def do_git(cmd)
	puts "Running: #{cmd}"
	`cd #{TMP_DIR} && #{cmd}`
end

def setup_git_repository
	`rm -rf #{TMP_DIR}`
	FileUtils.mkdir_p(TMP_DIR)
	do_git('git init && touch a && touch b && git add a b && git commit -m"First Commit"')
end

class IndexTest < Test::Unit::TestCase

	def setup
		setup_git_repository

		@path = NSURL.alloc.initFileURLWithPath(TMP_DIR)
		@repo = PBGitRepository.alloc.initWithURL(@path)
		assert(@repo, "Repository creation failed")
		@controller = PBGitIndex.alloc.initWithRepository(@repo, workingDirectory:@path)
		assert(@controller, "Controller creation failed")

		# Setup escape from run loop
		NSNotificationCenter.defaultCenter.addObserver(self,
			selector:"stopRunLoop:",
			name:"PBGitIndexFinishedIndexRefresh",
			object:@controller);
	end

	# Run the default run loop, for up to 2 seconds
	def run_loop
		@finished = false
		runloop = NSRunLoop.currentRunLoop
		now = NSDate.date
		date = runloop.limitDateForMode("kCFRunLoopDefaultMode")

		while date = runloop.limitDateForMode("kCFRunLoopDefaultMode") && !@finished
			date = runloop.limitDateForMode("kCFRunLoopDefaultMode")
			 return false if (date.timeIntervalSinceDate(now)) > 2.0
		end
		return true
	end

	# Callback method to stop run loop
	def stopRunLoop(notification)
		@finished = true
	end

	def wait_for_refresh
		@controller.refresh
		assert(run_loop, "Refresh finishes in 2 seconds")
	end





	def test_refresh
		wait_for_refresh
		assert(@controller.indexChanges.empty?, "No changes")

		do_git('rm a')
		wait_for_refresh
		assert(@controller.indexChanges.count == 1, "One change")

		do_git('touch a')
		wait_for_refresh
		assert(@controller.indexChanges.empty?, "No changes anymore")

		do_git('echo "waa" > a')
		wait_for_refresh
		assert(@controller.indexChanges.count == 1, "Another change")
		previous_state = @controller.indexChanges[0].status

		do_git('rm a')
		wait_for_refresh
		assert(@controller.indexChanges.count == 1, "Still one change")
		# 2 == DELETED, see PBChangedFile.h
		assert_equal(@controller.indexChanges[0].status, 2, "File status has changed")
		do_git('git checkout a')
	end

	def test_refresh_new_file
		do_git('touch c')
		wait_for_refresh
		assert(@controller.indexChanges.count == 1)
		file = @controller.indexChanges[0]
		assert_equal(file.status, 0, "File is new")
		
		do_git('git add c')
		wait_for_refresh
		assert_equal(1, @controller.indexChanges.count, "Just one file changed")
		assert_equal(file, @controller.indexChanges[0], "Still the same file")
		assert_equal(file.status, 0, "Still new")

		do_git('git rm --cached c')
		wait_for_refresh
		assert_equal(1, @controller.indexChanges.count, "Shouldn't be tracked anymore, but still in other list")
		assert_equal(file, @controller.indexChanges[0], "Still the same file")
		assert_equal(file.status, 0, "Still new (but only local)")

		# FIXME: The things below should actually be true / false, but macruby return 0 / 1
		assert(file.hasUnstagedChanges == 1, "Has unstaged changes")
		assert(@controller.indexChanges[0].hasStagedChanges == 0, "But no staged changes")

		do_git('rm c')
		wait_for_refresh
		assert(@controller.indexChanges.empty?, "All files should be gone")

		# Test an add -> git rm deletion
		do_git("touch d && git add d")
		wait_for_refresh
		assert_equal(1, @controller.indexChanges.count, "Just one changed file")

		do_git("git rm -f d")
		wait_for_refresh
		assert(@controller.indexChanges.empty?, "Should be gone again")
	end

	def test_remove_existing_file
		wait_for_refresh
		do_git("rm a")
		wait_for_refresh
		assert_equal(1, @controller.indexChanges.count, "Change was noticed")
		file = @controller.indexChanges[0]
		assert_equal(2, file.status, "File was DELETED")
		assert(file.hasUnstagedChanges == 1)
		assert(file.hasStagedChanges == 0)

		do_git("git rm a")
		wait_for_refresh
		assert_equal(1, @controller.indexChanges.count, "File was removed")
		assert_equal(file, @controller.indexChanges[0], "Still the same")
		assert(file.hasUnstagedChanges == 0)
		assert(file.hasStagedChanges == 1)
	end

end