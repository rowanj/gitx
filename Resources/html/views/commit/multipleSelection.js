var showMultipleFilesSelection = function(files)
{
	hideNotification();
	setTitle("");

	var div = $("diff");

	var contents = '<div id="multiselect">' +
		'<div class="title">Multiple Selection</div>';

	contents += "<ul>";

	for (var i = 0; i < files.length; ++i)
	{
		var file = files[i];
		contents += "<li>" + file.path + "</li>";
	}
	contents += "</ul></div>";

	div.innerHTML = contents;
	div.style.display = "";
}