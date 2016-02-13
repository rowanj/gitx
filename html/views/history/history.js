var commit;

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

	// This can be called later with the output of
	// 'git show' to fill in missing commit details (such as a diff)
	this.parseDetails = function(details) {
		this.raw = details;

		var diffStart = this.raw.indexOf("\ndiff ");
		var messageStart = this.raw.indexOf("\n\n") + 2;

		if (diffStart > 0) {
			this.message = this.raw.substring(messageStart, diffStart).replace(/^    /gm, "").escapeHTML();
			this.diff = this.raw.substring(diffStart);
		} else {
			this.message = this.raw.substring(messageStart).replace(/^    /gm, "").escapeHTML();
			this.diff = "";
		}
		this.header = this.raw.substring(0, messageStart);

        if (typeof this.header !== 'undefined') {
            var match = this.header.match(/\nauthor (.*) <(.*@.*|.*)> ([0-9].*)/);
            if (typeof match !== 'undefined' && typeof match[2] !== 'undefined') {
                if (!(match[2].match(/@[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/)))
                    this.author_email = match[2];

				if (typeof match[3] !== 'undefined')
                	this.author_date = new Date(parseInt(match[3]) * 1000);

                match = this.header.match(/\ncommitter (.*) <(.*@.*|.*)> ([0-9].*)/);
				if (typeof match[2] !== 'undefined')
					this.committer_email = match[2];
				if (typeof match[3] !== 'undefined')
					this.committer_date = new Date(parseInt(match[3]) * 1000);
            } 
        }
	}

	this.reloadRefs = function() {
		this.refs = this.object.refs();
	}

};


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
	// Other information will be loaded later by loadCommitDetails,
	// Which will be called from the controller once
	// the commit details are in.

	if (commit && commit.notificationID)
		clearTimeout(commit.notificationID);

	commit = new Commit(commitObject);
	commit.currentRef = currentRef;

	$("commitID").innerHTML = commit.sha;
	$("authorID").innerHTML = commit.author_name;
	$("subjectID").innerHTML = commit.subject.escapeHTML();
	$("diff").innerHTML = ""
	$("message").innerHTML = ""
	$("files").innerHTML = ""
	$("date").innerHTML = ""
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

	$("files").innerHTML = "";

	// Callback for the diff highlighter. Used to generate a filelist
	var newfile = function(name1, name2, id, mode_change, old_mode, new_mode) {
		var img = document.createElement("img");
		var p = document.createElement("p");
		var link = document.createElement("a");
		link.setAttribute("href", "#" + id);
		p.appendChild(link);
		var finalFile = "";
		var renamed = false;
		if (name1 == name2) {
			finalFile = name1;
			img.src = "../../images/modified.svg";
			img.title = "Modified file";
			p.title = "Modified file";
			if (mode_change)
				p.appendChild(document.createTextNode(" mode " + old_mode + " → " + new_mode));
		}
		else if (name1 == "/dev/null") {
			img.src = "../../images/added.svg";
			img.title = "Added file";
			p.title = "Added file";
			finalFile = name2;
		}
		else if (name2 == "/dev/null") {
			img.src = "../../images/removed.svg";
			img.title = "Removed file";
			p.title = "Removed file";
			finalFile = name1;
		}
		else {
			renamed = true;
		}
		if (renamed) {
			img.src = "../../images/renamed.svg";
			img.title = "Renamed file";
			p.title = "Renamed file";
			finalFile = name2;
			var rfd = renameDiff(name1.unEscapeHTML(), name2.unEscapeHTML());
			var html = [
					'<span class="renamed">',
					rfd[0].escapeHTML(),
					'<span class="meta"> { </span>',
					'<span class="old">', rfd[1].escapeHTML(), '</span>',
					'<span class="meta"> -&gt; </span>',
					'<span class="new">', rfd[2].escapeHTML(), '</span>',
					'<span class="meta"> } </span>',
					rfd[3].escapeHTML(),
                    '</span>'
				].join("");
			link.innerHTML = html;
		} else {
			link.appendChild(document.createTextNode(finalFile.unEscapeHTML()));
		}
		link.setAttribute("representedFile", finalFile);

		p.insertBefore(img, link);
		$("files").appendChild(p);
	}

	var binaryDiff = function(filename) {
		if (filename.match(/\.(png|jpg|icns|psd)$/i))
			return '<a href="#" onclick="return showImage(this, \'' + filename + '\')">Display image</a>';
		else
			return "Binary file differs";
	}
	
	highlightDiff(commit.diff, $("diff"), { "newfile" : newfile, "binaryFile" : binaryDiff });
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

var loadCommitDetails = function(data)
{
	commit.parseDetails(data);

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

	if (commit.diff.length < 200000)
		showDiff();
	else
		$("diff").innerHTML = "<a class='showdiff' href='' onclick='showDiff(); return false;'>This is a large commit. Click here or press 'v' to view.</a>";

	hideNotification();
	enableFeatures();
}
