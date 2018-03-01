var commit,
    fileElementPrototype;

// Create a new Commit object
// obj: PBGitCommit object
var Commit = function(obj) {
	this.object = obj;

	this.refs = obj.refs();
	this.author_name = obj.author();
	this.author_email = obj.authorEmail();
	this.author_date = obj.authorDate();
	this.committer_name = obj.committer();
	this.committer_email = obj.committerEmail();
	this.committer_date = obj.committerDate();
	this.sha = obj.SHA();
	this.parents = obj.parents();
	this.subject = obj.subject();
	this.message = obj.message();
	this.notificationID = null;

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
	var notification_text = 'This will create a ' + publicMessage + ' paste of your commit to <a href="https://gist.github.com/">https://gist.github.com/</a><br>' +
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
	image.src=(createGravatarUrl(email, image));
};

var createGravatarUrl = function(email, image) {
	if(Controller && !Controller.isFeatureEnabled_("gravatar")) {
		return "";
	}
	
	var gravatarBaseUrl = "https://www.gravatar.com/avatar/";
	var gravatarParameter = "?d=wavatar&s=60";
	
	var gravatarID = (email && hex_md5(email.toLowerCase().replace(/ /g, ""))) ||  "";
	
	return gravatarBaseUrl + gravatarID + gravatarParameter;
};

var selectCommit = function(a) {
	Controller.selectCommit_(a);
};

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
	$("date").innerHTML = "";
	$("files").style.display = "none";

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

    var textToHTML = function (txt) {
        return (" "+txt+" ")
            .replace(/(https?:\/\/([^\s\.\)\]\<]+|\.[^\s])+)/ig, "<a href=\"$1\">$1</a>")
            .replace(/\n/g,"<br>")
            .trim();
    }

    $("message").innerHTML = textToHTML(commit.message);

	jQuery("#commit").show();
	jQuery("#no-commit-message").hide();
	var filelist = $("filelist");
	while (filelist.hasChildNodes())
		filelist.removeChild(filelist.lastChild);
	showRefs();
	removeParentsFromCommitHeader();

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

var removeParentsFromCommitHeader = function() {
	for (var i = 0; i < $("commit_header").rows.length; ++i) {
		var row = $("commit_header").rows[i];
		if (row.innerHTML.match(/Parent:/)) {
			row.parentNode.removeChild(row);
			--i;
		}
	}
};

var showMultipleSelectionMessage = function(messageParts) {
	jQuery("#commit").hide();
	jParagraphs = jQuery.map(messageParts, function(message) {
		return jQuery( '<p/>', { text:message } )
	});
	jQuery("#no-commit-message").empty().append(jParagraphs).show();
};

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

var loadCommitDiff = function(jsonData)
{
	var diffData = JSON.parse(jsonData)
	commit.filesInfo = diffData.filesInfo;
	commit.diff = diffData.fullDiff;

	if (commit.notificationID)
		clearTimeout(commit.notificationID)
		else
			$("notification").style.display = "none";

	if (commit.filesInfo.length > 0) {
		// Create the file list
		for (var i=0; i < commit.filesInfo.length; i+=1) {
			var fileInfo = commit.filesInfo[i];
			var fileElem = fileElementPrototype.cloneNode(true); // this is a <li>
			fileElem.targetFileId = "file_index_"+i;
			
			var displayName, representedFile;
			if (fileInfo.changeType === "renamed") {
				displayName = formatRenameDiff(renameDiff(fileInfo.oldFilename, fileInfo.newFilename));
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
				binaryElem.innerText =
				    fileInfo.oldFileSize + " \u2192 " + fileInfo.newFileSize + " bytes";
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

	if (commit.diff.length < 200000)
		showDiff();
	else
		$("diff").innerHTML = "<a class='showdiff' href='' onclick='showDiff(); return false;'>This is a large commit.<br>Click here or press 'v' to view.</a>";

	hideNotification();
	enableFeatures();
}
