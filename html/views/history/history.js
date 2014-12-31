var commit,
    fileElementPrototype;

// Create a new Commit object
// obj: PBGitCommit object
var Commit = function(obj) {
	this.object = obj;

	this.refs = obj.refs();
	this.author_name = obj.author();
	this.committer_name = obj.committer();
	this.sha = obj.realSha();
	this.parents = obj.parents();
	this.subject = obj.subject();
	this.notificationID = null;

	// TODO:
	// this.author_date instant

	this.parseSummary = function(summaryString) {
		this.summaryRaw = summaryString;
		
		// Get the header info and the full commit message
		var messageStart = this.summaryRaw.indexOf("\n\n") + 2;
		this.header = this.summaryRaw.substring(0, messageStart);
		var afterHeader = this.summaryRaw.substring(messageStart);
		var numstatStart = afterHeader.indexOf("\n\n") + 2;
		if (numstatStart > 1) {
			this.message = afterHeader.substring(0, numstatStart).replace(/^    /gm, "").escapeHTML();;
			var afterMessage = afterHeader.substring(numstatStart);
			var filechangeStart = afterMessage.indexOf("\n ") + 1;
			if (filechangeStart > 1) {
				this.numstatRaw = afterMessage.substring(0, filechangeStart);
				this.filechangeRaw = afterMessage.substring(filechangeStart);
			}
			else {
				this.numstatRaw = afterMessage;
				this.filechangeRaw = "";
			}
		}
		else {
			this.message = afterHeader;
			this.numstatRaw = "";
			this.filechangeRaw = "";
		}
		
		
        if (typeof this.header !== 'undefined') {
            var matches = this.header.match(/\nauthor (.*) <(.*@.*|.*)> ([0-9].*)/);
            if (matches !== null && matches[2] !== null) {
                if (!(matches[2].match(/@[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/)))
                    this.author_email = matches[2];
				
				if (typeof matches[3] !== 'undefined')
                	this.author_date = new Date(parseInt(matches[3]) * 1000);
				
                matches = this.header.match(/\ncommitter (.*) <(.*@.*|.*)> ([0-9].*)/);
				if (typeof matches[2] !== 'undefined')
					this.committer_email = matches[2];
				if (typeof matches[3] !== 'undefined')
					this.committer_date = new Date(parseInt(matches[3]) * 1000);
            } 
        }
		
		// Parse the --numstat part to get the list of files and lines changed.
		this.filesInfo = [];
		var lines = this.numstatRaw.split('\n');
		for (var lineno=0; lineno < lines.length; lineno++) {
			var columns = lines[lineno].split('\t');
			if (columns.length >= 2) {
				if (columns[0] == "-" && columns[1] == "-") {
					this.filesInfo.push({"filename": columns[2],
										"changeType": "modified",
										"binary": true});
				}
				else {
					this.filesInfo.push({"numLinesAdded": parseInt(columns[0]),
										"numLinesRemoved": parseInt(columns[1]),
										"filename": columns[2],
										"changeType": "modified",
										"binary": false});
				}
			}
		}
		
		// Parse the filechange part (from --summary) to get info about files
		// that were added/deleted/etc.
		// Sample text:
		//  create mode 100644 GitXTextFieldCell.h
		//  delete mode 100644 someDir/filename with spaces.txt
		//  rename fielname with spaces.txt => filename_without_spaces.txt (98%)
		var lines = this.filechangeRaw.split('\n');
		for (var lineno=0; lineno < lines.length; lineno++) {
			var line = lines[lineno];
			var filename="", changeType="";
			if (line.indexOf("delete") == 1) {
				filename = line.match(/ delete mode \d+ (.*)$/)[0];
				changeType = "removed";
			}
			else if (line.indexOf("create") == 1) {
				filename = line.match(/ create mode \d+ (.*)/)[0];
				changeType = "added";
			}
			else if (line.indexOf("rename") == 1) {
				// get the new name of the file (the part after the " => ")
				filename = line.match(/ rename (.*) \(.+\)$/)[0];
				changeType = "renamed";
			}
			
			if (filename != "") {
				// Update the appropriate filesInfo with the actual changeType.
				for (var i=0; i < commit.filesInfo.length; i+=1) {
					if (commit.filesInfo[i].filename == filename) {
						commit.filesInfo[i].changeType = changeType;
						if (changeType == "renamed") {
							var names = filename.split(" => ");
							commit.filesInfo[i].oldFilename = names[0];
							commit.filesInfo[i].newFilename = names[1];
						}
						break;
					}
				}
			}
		}
	}

	// This can be called later with the output of
	// 'git show' to get the full diff
	this.parseFullDiff = function(fullDiff) {
		this.fullDiffRaw = fullDiff;

		var diffStart = this.fullDiffRaw.indexOf("\ndiff ");
		if (diffStart > 0) {
			this.diff = this.fullDiffRaw.substring(diffStart);
		} else {
			this.diff = "";
		}
	}

	this.reloadRefs = function() {
		this.refs = this.object.refs();
	}

};

var extractPrototypes = function() {
	// Grab an element from the DOM, save it in a global variable (with its
	// id removed) so it can be copied later, and remove it from the DOM.
	fileElementPrototype = $('file_prototype');
	fileElementPrototype.removeAttribute('id');
	fileElementPrototype.parentNode.removeChild(fileElementPrototype);
}

var confirm_gist = function(confirmation_message) {
	if (!Controller.isFeatureEnabled_("confirmGist")) {
		gistie();
		return;
	}

	// Set optional confirmation_message
	confirmation_message = confirmation_message || "Yes. Paste this commit.";
	var deleteMessage = Controller.getConfig_("github.token") ? " " : "You might not be able to delete it after posting.<br>";
	var publicMessage = Controller.isFeatureEnabled_("publicGist") ? "<b>public</b>" : "private";
	// Insert the verification links into div#notification_message
	var notification_text = 'This will create a ' + publicMessage + ' paste of your commit to <a href="http://gist.github.com/">http://gist.github.com/</a><br>' +
	deleteMessage +
	'Are you sure you want to continue?<br/><br/>' +
	'<a href="#" onClick="hideNotification();return false;" style="color: red;">No. Cancel.</a> | ' +
	'<a href="#" onClick="gistie();return false;" style="color: green;">' + confirmation_message + '</a>';

	notify(notification_text, 0);
	// Hide img#spinner, since it?s visible by default
	$("spinner").style.display = "none";
}

var gistie = function() {
	notify("Uploading code to Gistie..", 0);

	var parameters = {public:false, files:{}};
	var filename = commit.object.subject.replace(/[^a-zA-Z0-9]/g, "-") + ".patch";
	parameters.files[filename] = {content: commit.object.patch()};

	var accessToken = Controller.getConfig_("github.token"); // obtain a personal access token from https://github.com/settings/applications
	// TODO: Replace true with private preference
	if (Controller.isFeatureEnabled_("publicGist"))
		parameters.public = true;

	var t = new XMLHttpRequest();
	t.onreadystatechange = function() {
		if (t.readyState == 4) {
			var success = t.status >= 200 && t.status < 300;
			var response = JSON.parse(t.responseText);
			if (success && response.html_url) {
				notify("Code uploaded to <a target='_new' href='"+response.html_url+"'>"+response.html_url+"</a>", 1);
			} else {
				notify("Pasting to Gistie failed :(.", -1);
				Controller.log_(t.responseText);
			}
		}
	}

	t.open('POST', "https://api.github.com/gists");
	if (accessToken)
		t.setRequestHeader('Authorization', 'token '+accessToken);
	t.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
	t.setRequestHeader('Accept', 'text/javascript, text/html, application/xml, text/xml, */*');
	t.setRequestHeader('Content-type', 'application/x-www-form-urlencoded;charset=UTF-8');

	try {
		t.send(JSON.stringify(parameters));
	} catch(e) {
		notify("Pasting to Gistie failed: " + e, -1);
	}
}

var setGravatar = function(email, image) {
	if(Controller && !Controller.isFeatureEnabled_("gravatar")) {
		image.src = "";
		return;
	}

	if (!email) {
		image.src = "http://www.gravatar.com/avatar/?d=wavatar&s=60";
		return;
	}

	image.src = "http://www.gravatar.com/avatar/" +
		hex_md5(email.toLowerCase().replace(/ /g, "")) + "?d=wavatar&s=60";
}

var selectCommit = function(a) {
	Controller.selectCommit_(a);
}

// Relead only refs
var reload = function() {
	$("notification").style.display = "none";
	commit.reloadRefs();
	showRefs();
}

var showRefs = function() {
	var refs = $("refs");
	if (commit.refs) {
		refs.parentNode.style.display = "";
		refs.innerHTML = "";
		for (var i = 0; i < commit.refs.length; i++) {
			var ref = commit.refs[i];
			refs.innerHTML += '<span class="refs ' + ref.type() + (commit.currentRef == ref.ref ? ' currentBranch' : '') + '">' + ref.shortName() + '</span> ';
		}
	} else
		refs.parentNode.style.display = "none";
}

var loadCommit = function(commitObject, currentRef) {
	// These are only the things we can do instantly.
	// Other information will be loaded later by loadCommitSummary
	// and loadCommitFullDiff, which will be called from the
	// controller once the commit details are in.

	if (commit && commit.notificationID)
		clearTimeout(commit.notificationID);

	commit = new Commit(commitObject);
	commit.currentRef = currentRef;

	$("commitID").innerHTML = commit.sha;
	$("authorID").innerHTML = commit.author_name;
	$("subjectID").innerHTML = commit.subject.escapeHTML();
	$("diff").innerHTML = "";
	$("message").innerHTML = "";
	$("date").innerHTML = "";
	$("files").style.display = "none";
	var filelist = $("filelist");
	while (filelist.hasChildNodes())
		filelist.removeChild(filelist.lastChild);
	showRefs();

	for (var i = 0; i < $("commit_header").rows.length; ++i) {
		var row = $("commit_header").rows[i];
		if (row.innerHTML.match(/Parent:/)) {
			row.parentNode.removeChild(row);
			--i;
		}
	}

	// Scroll to top
	scroll(0, 0);

	if (!commit.parents)
		return;

	for (var i = 0; i < commit.parents.length; i++) {
		var newRow = $("commit_header").insertRow(-1);
		newRow.innerHTML = "<td class='property_name'>Parent:</td><td>" +
			"<a class=\"SHA\" href='' onclick='selectCommit(this.innerHTML); return false;'>" +
			commit.parents[i].SHA() + "</a></td>";
	}

	commit.notificationID = setTimeout(function() { 
		if (!commit.fullyLoaded)
			notify("Loading commit…", 0);
		commit.notificationID = null;
	}, 500);

}

var commonPrefix = function(a, b) {
    if (a === b) return a;
    var i = 0;
    while (a.charAt(i) == b.charAt(i))++i;
    return a.substring(0, i);
};
var commonSuffix = function(a, b) {
    if (a === b) return "";
    var i = a.length - 1,
        k = b.length - 1;
    while (a.charAt(i) == b.charAt(k)) {
        --i;
        --k;
    }
    return a.substring(i + 1, a.length);
};
var renameDiff = function(a, b) {
    var p = commonPrefix(a, b),
        s = commonSuffix(a, b),
        o = a.substring(p.length, a.length - s.length),
        n = b.substring(p.length, b.length - s.length);
    return [p, o, n, s];
};
var formatRenameDiff = function(d) {
    var p = d[0],
        o = d[1],
        n = d[2],
        s = d[3];
    if (o === "" && n === "" && s === "") {
        return p;
    }
    return [p, "{ ", o, " → ", n, " }", s].join("");
};

var showDiff = function() {

	// Callback for the diff highlighter. Used to generate a filelist
	var binaryDiff = function(filename) {
		if (filename.match(/\.(png|jpg|icns|psd)$/i))
			return '<a href="#" onclick="return showImage(this, \'' + filename + '\')">Display image</a>';
		else
			return "Binary file differs";
	}
	
	highlightDiff(commit.diff, $("diff"), { "binaryFile" : binaryDiff });
}

var showImage = function(element, filename)
{
	element.outerHTML = '<img src="GitX://' + commit.sha + '/' + filename + '">';
	return false;
}

var enableFeature = function(feature, element)
{
	if(!Controller || Controller.isFeatureEnabled_(feature)) {
		element.style.display = "";
	} else {
		element.style.display = "none";
	}
}

var enableFeatures = function()
{
	enableFeature("gist", $("gist"))
	enableFeature("gravatar", $("author_gravatar").parentNode)
	enableFeature("gravatar", $("committer_gravatar").parentNode)
}

var loadCommitSummary = function(data)
{
	commit.parseSummary(data);
	
	if (commit.notificationID)
		clearTimeout(commit.notificationID)
		else
			$("notification").style.display = "none";
	
	var formatEmail = function(name, email) {
		return email ? name + " &lt;<a href='mailto:" + email + "'>" + email + "</a>&gt;" : name;
	}
	
	$("authorID").innerHTML = formatEmail(commit.author_name, commit.author_email);
	$("date").innerHTML = commit.author_date;
	setGravatar(commit.author_email, $("author_gravatar"));
	
	if (commit.committer_name != commit.author_name) {
		$("committerID").parentNode.style.display = "";
		$("committerID").innerHTML = formatEmail(commit.committer_name, commit.committer_email);
		
		$("committerDate").parentNode.style.display = "";
		$("committerDate").innerHTML = commit.committer_date;
		setGravatar(commit.committer_email, $("committer_gravatar"));
	} else {
		$("committerID").parentNode.style.display = "none";
		$("committerDate").parentNode.style.display = "none";
	}

	$("message").innerHTML = commit.message.replace(/\b(https?:\/\/[^\s<]*)/ig, "<a href=\"$1\">$1</a>").replace(/\n/g,"<br>");

	if (commit.filesInfo.length > 0) {
		// Create the file list
		for (var i=0; i < commit.filesInfo.length; i+=1) {
			var fileInfo = commit.filesInfo[i];
			var fileElem = fileElementPrototype.cloneNode(true); // this is a <li>
			fileElem.targetFileId = "file_index_"+i;
			
			var displayName, representedFile;
			if (fileInfo.changeType == "renamed") {
				displayName = fileInfo.filename;
				representedFile = fileInfo.newFilename;
			}
			else {
				displayName = fileInfo.filename;
				representedFile = fileInfo.filename;
			}
			fileElem.title = fileInfo.changeType + ": " + displayName; // set tooltip
			fileElem.setAttribute("representedFile", representedFile);
			
			if (i % 2)
				fileElem.className += "even";
			else
				fileElem.className += "odd";
			fileElem.onclick = function () {
				// Show the full diff in case it's not already visisble.
				showDiff();
				// Scroll to that file.
				$(this.targetFileId).scrollIntoView(true);
			}
			
			// Start with a modified icon, and update it later when the
			// `diff --summary` info comes back.
			var imgElement = fileElem.getElementsByClassName("changetype-icon")[0];
			imgElement.src = "../../images/"+fileInfo.changeType+".svg";
			
			var filenameElement = fileElem.getElementsByClassName("filename")[0];
			filenameElement.innerText = displayName;
			
			var diffstatElem = fileElem.getElementsByClassName("diffstat-info")[0];
			var binaryElem = fileElem.getElementsByClassName("binary")[0]
			if (fileInfo.binary) {
				// remove the diffstat-info element
				diffstatElem.parentNode.removeChild(diffstatElem);
			}
			else {
				// remove the binary element
				binaryElem.parentNode.removeChild(binaryElem);
				
				// Show the num of lines added/removed
				var addedWidth = 2 * fileInfo.numLinesAdded;
				var removedWidth = 2 * fileInfo.numLinesRemoved;
				// Scale them down proportionally if they're too wide.
				var maxWidth = 350;
				var minWidth = 5;
				if (addedWidth+removedWidth > maxWidth) {
					var scaleBy = maxWidth/(addedWidth+removedWidth);
					addedWidth *= scaleBy;
					removedWidth *= scaleBy;
				}
				if (addedWidth > 0 && addedWidth < minWidth) addedWidth = minWidth;
				if (removedWidth > 0 && removedWidth < minWidth) removedWidth = minWidth;
				
				// show lines changed info
				var numLinesAdded = fileInfo.numLinesAdded;
				var numLinesRemoved = fileInfo.numLinesRemoved;
				var numLinesChanged = numLinesAdded + numLinesRemoved;
				// summarize large numbers
				if (numLinesChanged > 999) numLinesChanged = "~" + Math.round(numLinesChanged / 1000) + "k";
				// fill in numbers
				var diffstatSummary = diffstatElem.getElementsByClassName("diffstat-numbers")[1];
				diffstatSummary.innerText = numLinesChanged;
				var diffstatDetails = diffstatElem.getElementsByClassName("diffstat-numbers")[0];
				diffstatDetails.getElementsByClassName("added")[0].innerText = "+"+numLinesAdded;
				diffstatDetails.getElementsByClassName("removed")[0].innerText = "-"+numLinesRemoved;
				
				// Size the bars
				var addedBar = diffstatElem.getElementsByClassName("changes-bar")[0];
				if (addedWidth >= minWidth)
					addedBar.style.width = addedWidth;
				else
					addedBar.style.visibility = "hidden";
			
				var removedBar = diffstatElem.getElementsByClassName("changes-bar")[1];
				if (removedWidth >= minWidth)
					removedBar.style.width = removedWidth;
				else
					removedBar.style.visibility = "hidden";
			}
			$("filelist").appendChild(fileElem);
		}
		$("files").style.display = "";
	}
}

var loadCommitFullDiff = function(data)
{
	commit.parseFullDiff(data);

	if (commit.diff.length < 200000)
		showDiff();
	else
		$("diff").innerHTML = "<a class='showdiff' href='' onclick='showDiff(); return false;'>This is a large commit.<br>Click here or press 'v' to view.</a>";

	hideNotification();
	enableFeatures();
}
