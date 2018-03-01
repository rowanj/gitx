//
//  PBGitGrapher.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#include <vector>
#include <algorithm>

#import "PBGraphCellInfo.h"
#import "PBGitGrapher.h"
#import "PBGitCommit.h"
#import "PBGitLane.h"
#import "PBGitGraphLine.h"

#import <vector>
#import <git2/oid.h>
#include <algorithm>
#import <ObjectiveGit/GTOID.h>

using namespace std;
typedef std::vector<PBGitLane *> LaneCollection;

@interface PBGitGrapher ()

@property (nonatomic, strong) PBGraphCellInfo *previous;
@property (nonatomic, assign) LaneCollection *pl;
@property (nonatomic, assign) int curLane;
@property (nonatomic, assign) int laneIndex;

@end

@implementation PBGitGrapher

- (id) initWithRepository: (PBGitRepository*) repo
{
	self = [super init];
	if (!self) {
		return nil;
	}
	
	self.pl = new LaneCollection;
	
	return self;
}

int long_to_integer_bound(long input, int min, int max)
{
	if (input < (long)min) {
		return min;
	} else if (input > (long)max) {
		return max;
	}
	return (int)input;
}

void add_line(struct PBGitGraphLine *lines, int *nLines, int upper, long from, long to, int index)
{
	// TODO: put in one thing
	struct PBGitGraphLine a = {
		long_to_integer_bound(upper, 0, 1),
		long_to_integer_bound(from, INT8_MIN, INT8_MAX),
		long_to_integer_bound(to, INT8_MIN, INT8_MAX),
		index
	};
	lines[(*nLines)++] = a;
}

- (void) decorateCommit: (PBGitCommit *) commit
{
	int i = 0;
	long newPos = -1;
	LaneCollection *currentLanes = new LaneCollection;
	LaneCollection *previousLanes = self.pl;
	NSArray <GTOID *> *parents = [commit parents];
	NSUInteger nParents = [parents count];

	unsigned long maxLines = (previousLanes->size() + nParents + 2) * 2;
	struct PBGitGraphLine *lines = (struct PBGitGraphLine *)calloc(maxLines, sizeof(struct PBGitGraphLine));
	int currentLine = 0;

	PBGitLane *currentLane = NULL;
	BOOL didFirst = NO;
	const git_oid *commit_oid = commit.OID.git_oid;
	
	// First, iterate over earlier columns and pass through any that don't want this commit
	if (self.previous != nil) {
		// We can't count until numColumns here, as it's only used for the width of the cell.
		LaneCollection::iterator it = previousLanes->begin();
		for (; it != previousLanes->end(); ++it) {
			i++;
			if (!*it) // This is an empty lane, created when the lane previously had a parentless(root) commit
				continue;

			// This is our commit! We should do a "merge": move the line from
			// our upperMapping to their lowerMapping
			if ((*it)->isCommit(commit_oid)) {
				if (!didFirst) {
					didFirst = YES;
					currentLanes->push_back(*it);
					currentLane = currentLanes->back();
					newPos = currentLanes->size();
					add_line(lines, &currentLine, 1, i, newPos, (*it)->index());
					if (nParents)
						add_line(lines, &currentLine, 0, newPos, newPos, (*it)->index());
				}
				else {
					add_line(lines, &currentLine, 1, i, newPos, (*it)->index());
					delete *it;
				}
			}
			else {
				// We are not this commit.
				currentLanes->push_back(*it);
				add_line(lines, &currentLine, 1, i, currentLanes->size(), (*it)->index());
				add_line(lines, &currentLine, 0, currentLanes->size(), currentLanes->size(), (*it)->index());
			}
			// For existing columns, we always just continue straight down
			// ^^ I don't know what that means anymore :(
		}
	}
	//Add your own parents

	// If we already did the first parent, don't do so again
	if (!didFirst && nParents) {
		const git_oid *parentOID = [(GTOID*)[parents objectAtIndex:0] git_oid];
		PBGitLane *newLane = new PBGitLane(_laneIndex++, parentOID);
		currentLanes->push_back(newLane);
		newPos = currentLanes->size();
		add_line(lines, &currentLine, 0, newPos, newPos, newLane->index());
	}

	// Add all other parents

	// If we add at least one parent, we can go back a single column.
	// This boolean will tell us if that happened
	BOOL addedParent = NO;

	int parentIndex = 0;
	for (parentIndex = 1; parentIndex < nParents; ++parentIndex) {
		const git_oid *parentOID = [(GTOID*)[parents objectAtIndex:parentIndex] git_oid];
		int i = 0;
		BOOL was_displayed = NO;
		LaneCollection::iterator it = currentLanes->begin();
		for (; it != currentLanes->end(); ++it) {
			i++;
			if ((*it)->isCommit(parentOID)) {
				add_line(lines, &currentLine, 0, i, newPos,(*it)->index());
				was_displayed = YES;
				break;
			}
		}
		if (was_displayed)
			continue;
		
		// Really add this parent
		addedParent = YES;
		PBGitLane *newLane = new PBGitLane(_laneIndex++, parentOID);
		currentLanes->push_back(newLane);
		add_line(lines, &currentLine, 0, currentLanes->size(), newPos, newLane->index());
	}

	if (commit.lineInfo) {
		self.previous = commit.lineInfo;
		self.previous.position = newPos;
		self.previous.lines = lines;
	}
	else
		self.previous = [[PBGraphCellInfo alloc] initWithPosition:newPos andLines:lines];

	if (currentLine > maxLines)
		NSLog(@"Number of lines: %i vs allocated: %lu", currentLine, maxLines);

	self.previous.nLines = currentLine;

	// If a parent was added, we have room to not indent.
	if (addedParent)
		self.previous.numColumns = currentLanes->size() - 1;
	else
		self.previous.numColumns = currentLanes->size();

	// Update the current lane to point to the new parent
	if (currentLane) {
		if (nParents > 0)
			currentLane->setSha( [(GTOID*)[parents objectAtIndex:0] git_oid]);
		else {
			// The current lane's commit does not have any parents
			// AKA, this is a first commit
			// Empty the entry and free the lane.
			// We empty the lane in the case of a subtree merge, where
			// multiple first commits can be present. By emptying the lane,
			// we allow room to create a nice merge line.
			std::replace(currentLanes->begin(), currentLanes->end(), currentLane, (PBGitLane *)0);
			delete currentLane;
		}
	}

	delete previousLanes;

	self.pl = currentLanes;
	commit.lineInfo = self.previous;
}

- (void) dealloc
{
	LaneCollection *lanes = self.pl;
	LaneCollection::iterator it = lanes->begin();
	for (; it != lanes->end(); ++it)
		delete *it;

	delete lanes;
}
@end
