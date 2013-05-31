var showFile = function(txt) {
	$("txt").style.display = "";
	$("txt").innerHTML="<pre>"+txt+"</pre>";
	
	SyntaxHighlighter.defaults['toolbar'] = false;

	SyntaxHighlighter.highlight();
	return;
}

var selectCommit = function(a) {
	Controller.selectCommit_(a);
}