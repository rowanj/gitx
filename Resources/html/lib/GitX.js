/*
 * GitX Javascript library
 * This library contains functions that can be shared across all
 * webviews in GitX.
 * It is written only for Safari 3 and higher.
 */

function $(element) {
	return document.getElementById(element);
}

String.prototype.escapeHTML = function() {
  return this.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
};

String.prototype.unEscapeHTML = function() {
  return this.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
};

Element.prototype.toggleDisplay = function() {
	if (this.style.display != "")
		this.style.display = "";
	else
		this.style.display = "none";
}

Array.prototype.indexOf = function(item, i) {
  i || (i = 0);
  var length = this.length;
  if (i < 0) i = length + i;
  for (; i < length; i++)
    if (this[i] === item) return i;
  return -1;
};

var notify = function(text, state) {
	var n = $("notification");
	n.style.display = "";
	$("notification_message").innerHTML = text;
	
	// Change color
	if (!state) { // Busy
		$("spinner").style.display = "";
		n.setAttribute("class", "");
	}
	else if (state == 1) { // Success
		$("spinner").style.display = "none";
		n.setAttribute("class", "success");
	} else if (state == -1) {// Fail
		$("spinner").style.display = "none";
		n.setAttribute("class", "fail");
	}
}

var hideNotification = function() {
	$("notification").style.display = "none";
}
