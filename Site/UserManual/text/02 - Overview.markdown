### Overview

When you open GitX for the first time, you will be greeted by an open-dialog. In this dialog, you should select the Git 
repository you want to open. You can select either a directory containing a .git directory, or a .git directory itself.  
After doing this, you will be greeted by the default GitX view, which is the history-view. The history-view consists of 
two main parts. The top part is used for displaying commits on branches and the bottom-view displays details about the 
selected commit. The window-title will always show you the currently checked-out branch (or indicate a detached HEAD).

![Menubar](images/UserManual/menubar.png)
The menu contains buttons to switch between history/commit-view, a selector for specifying which branch to show and an 
'Add branch' button. Branches can be checked-out and deleted within GitX by right-clicking their colored bubbles the 
commit-list.

You can double-click the divider between these areas to collapse the smaller-one or you can use Command-Shift-Up and 
Command-Shift-Down to do so.

#### The commit list

![History View](images/UserManual/historyview.png)
On the left side in the commit list you can see the _branch lines_. These show you how your history has diverged and 
merged. As newer commits are on top, two lines joining each other from the bottom is a merge. This way you see which 
branches were merged in without any effort.

![Branches](images/UserManual/branch-lanes.png)
On some commits, to the right of the branch lines you will find _commit labels_. These indicate references to these 
commits, for example branch heads and remote heads. _Green_ labels indicate local branches. _Blue_ labels indicate 
remote branches (it will be in the form of remote/branch). _Yellow_ labels indicate tags. The _orange_ label indicates 
the currently checked-out branch.

There are four columns, the first showing the commit _subject_ (which is the top line of your commit message), the 
second the _author name_, the third the commit date and the last showing the abbreviated SHA of the commit. You can sort 
on any of these columns. However, if you sort the branch lines will disappear. Repeatedly clicking the row will revert 
the ordering and the original order will be restored, including the branch lines.

In the top right you will also find the search bar. Here you can search on subject, author or SHA. If you do this, the 
branch lines will also disappear.

#### The detail view

![The detail switch controller](images/UserManual/detailswitcher.png "The detail switch controller")
Below the list of commits rests the detail view which shows information about the currently selected commit. The detail 
view can switch between three different ways of displaying the commit using the three buttoms at the bottom.  The first 
tab shows information about the current commit in a nice markup and will probably be the view you use most. In this 
mode, you can see a pretty diff of the commit, and information such as the parent SHA and the author's email address.

![The diff display](images/UserManual/display_diff.png "Displaying a diff")The view is pretty much self-explanatory but 
it does contain some features which might not be obvious. You can right-click the refs and files to get a context-menu. 
The "Gist it" buton will upload the current patch to [gist.github.com](http://gist.github.com "Gist"). This will use 
your `github.user` and `github.token` git-config options if those are set. Otherwise it will create an anonymous gist. 
Have a look at the _Preferences_ to set options for Gisting your patches.

The second detailed view will simply show the raw content of the commit, much like `git show --pretty=raw` would.

The third detailed view is more interesting: It allows you to browse your history in tree-view and export files/trees 
from certain commits. To do so, select the commit and then simply drag-and-drop the wanted dir/files from the tree to a 
folder in the Finder. This is also where the Quicklook button in the bottom right comes in: pressing it while selecting 
a file that can be QuickLooked (an image, for example), will display it in the same way as the Finder's quicklook. GitX 
even imitates this behaviour by allowing you to press space to quicklook a file.
