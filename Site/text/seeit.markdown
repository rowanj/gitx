<% @title = "See It"  %>
<script type="text/javascript" charset="utf-8">
	var screenshots = screenshots = [["The Commit View", 968], ["The History View", 967]];

	var screencasts = [
		[1, "History View", "This video demonstrates basic GitX features that you can use to browse your repository's history"],
		[2, "Branch control", "This video shows how you can use GitX to modify your branches"],
		[3, "Committing", "This video shows you how you can commit your changes using GitX"],
		[4, "Terminal Usage", "This video shows some of the features available when using the gitx command-line utility"],
		[5, "Advanced Features", "This feature shows some of the advanced features available in GitX"]
	]

	var show_video = function(num)
	{
		var sc = screencasts[num];
		document.getElementById("video").innerHTML = '<embed type="video/quicktime" src="http://gitx.frim.nl/Movies/screencasts/GitX' + sc[0] + '.mov" pluginspage="http://www.apple.com/quicktime/download/" scale="aspect" cache="False" width="568" height="426" autoplay="True" />'
		document.getElementById("video_description").innerHTML = sc[2];
		return false;
	}
</script>

<h2>
	See it
</h2>
<p>
	Here you can have a look at what GitX looks like. There are <a href="#screenshots">screenshots</a> and <a href="#screencasts">screencasts</a> for you to enjoy!
</p>
<h3 id="screenshots">
	Screenshots
</h3>
<div id="screenshots_div"></div>
<script type="text/javascript" charset="utf-8">
	var screenshots_div = document.getElementById("screenshots_div");
	for (screenshot in screenshots)
	{
		var s = screenshots[screenshot];
		screenshots_div.innerHTML += '<h4>' + s[0] + '</h4>' + '<img width="500px" src="http://ss.frim.nl/==' + s[1] +'">';
		
	}
</script>

<h3 id="screencasts">Screencasts</h3>
<div id="episodediv">
	<div id="video_display">
		<div id="video"><img src="images/qtime.png" alt="Screencast" width="568"></div>
		<div id="video_description"></div>
	</div>
	<div id="episodebar">
		<ul id="episodelist"></ul>
	</div>
</div>

<div style="clear: both"></div>
<script type="text/javascript" charset="utf-8">
	var episodelist = document.getElementById("episodelist");
	for (screencast in screencasts)
	{
		var s = screencasts[screencast];
		episodelist.innerHTML += '<li><a href="#" onclick="return show_video(' + screencast + ')">' + s[1] + '</a></li>';
		
	}
</script>
