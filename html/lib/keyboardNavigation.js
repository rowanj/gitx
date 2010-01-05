var scrollToCenter = function(element) {
    window.scrollTo(0, element.offsetTop);
}

var scrollToTop = function(element) {
	element.scrollIntoView(true);
}

var handleKeys = function(event) {
	if (event.altKey || event.metaKey || event.shiftKey)
		return;
	if (event.keyCode == 74)
		return changeHunk(true);
	else if (event.keyCode == 75)
		return changeHunk(false);
	else if (event.keyCode == 40 && event.ctrlKey == true) // ctrl-down_arrow
		return changeFile(true);
	else if (event.keyCode == 38 && event.ctrlKey == true) // ctrl-up_arrow
		return changeFile(false);
	else if (event.keyCode == 86) // 'v'
		showDiff();
	else if (event.keyCode == 67) // 'c'
		Controller.copySource();
	return true;
}

var handleKeyFromCocoa = function(key) {
	if (key == 'j')
		changeHunk(true);
	else if (key == 'k')
		changeHunk(false);
	else if (key == 'v')
		showDiff();
	else if (key == 'c')
		Controller.copySource();
}

var changeHunk = function(next) {
	var hunks = document.getElementsByClassName("hunkheader");

	if (hunks.length == 0)
		return;

	var currentHunk = document.getElementById("CurrentHunk");
	var newHunk;

	var index = -1;
	for (; index < hunks.length; ++index) {
		if (hunks[index] == currentHunk)
			break;
	}

	if (currentHunk && index >= 0) {
		currentHunk.id = null;
		if (next)
			newHunk = hunks[index + 1];
		else
			newHunk = hunks[index - 1];
	}
	if (!newHunk)
		newHunk = hunks[0];

	newHunk.id = 'CurrentHunk';
	scrollToCenter(newHunk);
	return false;
}

var changeFile = function(next) {
	var files = document.getElementsByClassName("fileHeader");
	
	if (files.length == 0)
		return;
	
	var currentFile = document.getElementById("CurrentFile");
	var newFile;
	
	var index = -1;
	for (; index < files.length; ++index) {
		if (files[index] == currentFile)
			break;
	}
	
	if (currentFile && index >= 0) {
		currentFile.id = null;
		
		if (next) {
			if (index <= files.length-1)
				newFile = files[index + 1];			
		}
		else {
			newFile = files[index - 1];
			if (!newFile)
				newFile = files[files.length-1];
		}
	}
	if (!newFile)
		newFile = files[0];
	
	newFile.id = 'CurrentFile';
	scrollToTop(newFile);
	return false;
}

document.onkeydown = function(event) {
	return handleKeys(event);
};