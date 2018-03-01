var selectCommit = function(a) {
	window.Controller.selectCommit_(a);
	return false;
}

var showFile = function(txt) {
	$("log").style.display = "";
	$("log").innerHTML=txt;
	return;
}
