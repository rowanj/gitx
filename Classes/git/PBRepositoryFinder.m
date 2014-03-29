//
//  PBRepositoryFinder.m
//  GitX
//
//  Created by Rowan James on 13/11/2012.
//
//

#import "PBRepositoryFinder.h"

@implementation PBRepositoryFinder

+ (NSURL *)workDirForURL:(NSURL *)fileURL;
{
  if (!fileURL.isFileURL) {
    return nil;
  }

  git_repository *repo = NULL;
  git_repository_open_ext(&repo, fileURL.path.UTF8String, GIT_REPOSITORY_OPEN_CROSS_FS, NULL);
  if (!repo) {
    return NULL;
  }

  const char *workdir = git_repository_workdir(repo);
  NSURL *result = nil;
  if (workdir) {
    result = [NSURL fileURLWithPath:[NSString stringWithUTF8String:workdir]];
  }

  git_repository_free(repo); repo = nil;
  return result;
}

+ (NSURL *)gitDirForURL:(NSURL *)fileURL
{
  if (!fileURL.isFileURL)
  {
    return nil;
  }
  git_buf path_buffer = {NULL, 0, 0};
  int gitResult = git_repository_discover(&path_buffer,
                                          [fileURL.path UTF8String],
                                          GIT_REPOSITORY_OPEN_CROSS_FS,
                                          nil);

  NSData *repoPathBuffer = nil;
  if (path_buffer.ptr) {
    repoPathBuffer = [NSData dataWithBytes:path_buffer.ptr length:path_buffer.asize];
    git_buf_free(&path_buffer);
  }

  if (gitResult == GIT_OK && repoPathBuffer.length)
  {
    NSString* repoPath = [NSString stringWithUTF8String:repoPathBuffer.bytes];
    BOOL isDirectory;
    if ([[NSFileManager defaultManager] fileExistsAtPath:repoPath
                                             isDirectory:&isDirectory] && isDirectory)
    {
      NSURL* result = [NSURL fileURLWithPath:repoPath
                                 isDirectory:isDirectory];
      return result;
    }
  }
  return nil;
}

+ (NSURL *)fileURLForURL:(NSURL *)inputURL
{
  NSURL* gitDir = [self gitDirForURL:inputURL];
  if (!gitDir) {
    return nil; // not a Git directory at all
  }

  NSURL *workDir = [self workDirForURL:inputURL];
  if (workDir) {
    return workDir; // root of this working copy or deepest submodule
  }

  return gitDir; // bare repo
}

@end
