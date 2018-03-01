var showFile = function(txt) {
	$("source").style.display = "";
	$("source").innerHTML="<pre class='first-line: 1;brush: objc'>"+txt+"</pre>";
	
	SyntaxHighlighter.defaults['toolbar'] = false;
	SyntaxHighlighter.highlight();
	
	return;
}
