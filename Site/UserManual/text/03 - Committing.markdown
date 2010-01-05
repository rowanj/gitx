### Committing

![GitX's commit view](images/UserManual/commitview.png "The Commit View") The commit-interface of GitX also consists of 
two parts. The top part will show the diff of the currently selected file. The bottom part is a bit more complex.

In the left list you will see files that are _unstaged_. If you are already used to Git's terminology, you will know what 
this means. These are the changes that have not been added to the index, and thus also will not be committed.

The rightmost part shows the _staged changes_. These _will_ be committed in the next commit.

It is possible to have a filename in both lists at the same time. In that case, there are some changes in the file that 
will be committed, and some that have been left out. Clicking on their name will show you what the difference is in the 
top pane.

To stage a file, double-click its icon. This will move the file from the left to the right. In the same way, you can 
unstage changes by double clicking on the name in the right pane. If you prefer, you can also drag and drop the files 
from one list to the other. You can also select multiple files, and then drag them to the other side all at once.

Every file has an icon associated with it. This shows the status of that file:

* A _green_ icon indicates there a changes to a file that is already tracked.
* A _white_ icon indicates a file that is not tracked by Git, but also not ignored.
* A _red_ icon indicates a file that has been deleted.

#### Partial staging

Sometimes you have made more than one change to a file, but would still prefer to create more than one git commit; the 
more specific the commits, the better, right? This is where hunk and line-wise staging comes in. Next to each specific 
change in a file, called a _hunk_, you will see a blue 'Stage' button. If you click on this button, only those specific 
changes will be staged. Clicking the 'Discard' button will irreversibly throw away this change, so use it with care! The 
confirmation can be silenced using Alt-Click.

GitX 0.7 introduced a new way of staging lines: Simply drag-select a few of the lines you want to stage/unstage and a 
'Stage lines' button will appear next to it. This allows for much finer granularity than the hunks determined by diff.
Double-clicking a changed line selects the entire surrounding block of changes. Selecting lines across hunks is not
possible.

#### Committing

Once you have staged all your changes, you can commit them. Supply a commit message in the center pane, but remember to 
use proper commit messages: the first line should be a short description of what you have changed followed by an empty 
line and a longer description. Make sure the subject of your commit is short enough to fit in GitX's history view!  
Pressing the commit button will hopefully convey to you that the commit was successful, and also give you the commit 
hash.

The 'Amend' checkbox represents `git commit --amend`: It enables you to amend the commit on the tip of the current 
branch. Checking 'Amend' will give you the commit-message of mentioned commit and also will display all of the changes 
the commit introduced as staged in the right-hand pane. You may then stage/unstage further changes, change the 
commit-message and hit 'Commit'.
The 'Sign-Off' button adds your signature to the commit which is common practice in a lot of Open-Source projects.
