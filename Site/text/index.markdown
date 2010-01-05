<% @title = "Home"  %>
<div class="nohover" id="download">
	<div id="version">
	<a href="http://frim.frim.nl/GitXStable.app.zip" title="Latest GitX download" id="download_link" class="nohover">
	<span style="font-size: 125%">Download GitX</span><br>Version <%= ReleaseNotes::last_version %>
	</a></div>
	<p id="donate_link">(you can help GitX by <a href="http://www.pledgie.com/campaigns/1816">donating</a>)</p>
</div>

<h2 class="noclear">GitX</h2>
<p>
	GitX is a git GUI made for Mac OS X. It currently
features a history viewer much like gitk and a commit GUI like git gui. But
then in silky smooth OS X style!
</p>

<h3 class="noclear">Features</h3>
<ul>
	<li>Detailed history viewer</li>
	<li>Nice commit GUI, allowing hunk- and line-wise staging</li>
	<li>Fast workflow</li>
	<li>Explore tree of any revision</li>
	<li>Nice Aqua interface</li>
	<li>Paste commits to <a href="http://gist.github.com/">gist.github.com</a></li>
	<li>QuickLook integration</li>
</ul>

<h3>Requirements</h3>
<p>
	GitX runs on Mac OS X 10.5 Leopard and Mac OS X 10.6 Snow Leopard. Because it uses features like Garbage Collection, you can't compile it on earlier systems. GitX also requires a fairly recent Git -- version 1.6.0 and higher are all supported. 
</p>

<h3>Download</h3>
<p>
	The newest version of GitX is <%= ReleaseNotes::last_version %>. This version can be downloaded from <a href="http://frim.frim.nl/GitXStable.app.zip">here</a>. To see what has changed, read the <a href="release_history.html">Release History</a>.
</p>
<p>
	After starting GitX, you can install the command-line tool through the menu (GitX-&gt;Enable Terminal Usage…). This will install a “gitx” binary in /usr/local/bin.
</p>
