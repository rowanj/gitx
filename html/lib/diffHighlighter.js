// If we run from a Safari instance, we don't
// have a Controller object. Instead, we fake it by
// using the console
if (typeof Controller == 'undefined') {
	Controller = console;
	Controller.log_ = console.log;
}

var toggleDiff = function(id)
{
  var content = document.getElementById('content_' + id);
  if (content) {
    var collapsed = (content.style.display == 'none');
	  if (collapsed) {
		  content.style.display = 'box';
		  jQuery(content).fadeTo('slow', 1).slideDown();
	  } else {
		  jQuery(content).fadeTo('fast', 0).slideUp('fast', function () {content.style.display = 'none'});
	  }
	
    var title = document.getElementById('title_' + id);
    if (title) {
      if (collapsed) {
        title.classList.remove('collapsed');
        title.classList.add('expanded');
      }
      else {
        title.classList.add('collapsed');
        title.classList.remove('expanded');
      }
    }
  }
}

var highlightDiff = function(diff, element, callbacks) {
	if (!diff || diff == "")
		return;

	if (!callbacks)
		callbacks = {};
	var start = new Date().getTime();
	element.className = "diff"
	var content = diff.escapeHTML();

	var file_index = 0;

	var startname = "";
	var endname = "";
	var line1 = "";
	var line2 = "";
	var diffContent = "";
	var finalContent = "";
	var lines = content.split('\n');
	var binary = false;
	var mode_change = false;
	var old_mode = "";
	var new_mode = "";
    var linkToTop = "<div class=\"top-link\"><a href=\"#\">Top</a></div>";

	var hunk_start_line_1 = -1;
	var hunk_start_line_2 = -1;

	var header = false;

	var finishContent = function()
	{
		if (!file_index)
		{
			file_index++;
			return;
		}

		if (callbacks["newfile"])
			callbacks["newfile"](startname, endname, "file_index_" + (file_index - 1), mode_change, old_mode, new_mode);

		var title = startname;
		var binaryname = endname;
		if (endname == "/dev/null") {
			binaryname = startname;
			title = startname;
		}
		else if (startname == "/dev/null")
			title = endname;
		else if (startname != endname)
			title = startname + " renamed to " + endname;
		
		if (binary && endname == "/dev/null") {	// in cases of a deleted binary file, there is no diff/file to display
			line1 = "";
			line2 = "";
			diffContent = "";
			file_index++;
			startname = "";
			endname = "";
			return;				// so printing the filename in the file-list is enough
		}

		if (diffContent != "" || binary) {
			finalContent += '<div class="file" id="file_index_' + (file_index - 1) + '">' +
				'<div id="title_' + title + '" class="expanded fileHeader"><a href="javascript:toggleDiff(\'' + title + '\');">' + title + '</a></div>';
		}

		if (!binary && (diffContent != ""))  {
			finalContent +=		'<div id="content_' + title + '" class="diffContent">' +
								'<div class="lineno">' + line1 + "</div>" +
								'<div class="lineno">' + line2 + "</div>" +
								'<div class="lines">' + postProcessDiffContents(diffContent).replace(/\t/g, "    ") + "</div>" +
							'</div>';
		}
		else {
			if (binary) {
				if (callbacks["binaryFile"])
					finalContent += callbacks["binaryFile"](binaryname);
				else
					finalContent += '<div id="content_' + title + '">Binary file differs</div>';
			}
		}

		if (diffContent != "" || binary)
			finalContent += '</div>' + linkToTop;

		line1 = "";
		line2 = "";
		diffContent = "";
		file_index++;
		startname = "";
		endname = "";
	}
	for (var lineno = 0, lindex = 0; lineno < lines.length; lineno++) {
		var l = lines[lineno];

		var firstChar = l.charAt(0);

		if (firstChar == "d" && l.charAt(1) == "i") {			// "diff", i.e. new file, we have to reset everything
			header = true;						// diff always starts with a header

			finishContent(); // Finish last file

			binary = false;
			mode_change = false;

			if(match = l.match(/^diff --git (a\/)+(.*) (b\/)+(.*)$/)) {	// there are cases when we need to capture filenames from
				startname = match[2];					// the diff line, like with mode-changes.
				endname = match[4];					// this can get overwritten later if there is a diff or if
			}								// the file is binary

			continue;
		}

		if (header) {
			if (firstChar == "n") {
				if (l.match(/^new file mode .*$/))
					startname = "/dev/null";

				if (match = l.match(/^new mode (.*)$/)) {
					mode_change = true;
					new_mode = match[1];
				}
				continue;
			}
			if (firstChar == "o") {
				if (match = l.match(/^old mode (.*)$/)) {
					mode_change = true;
					old_mode = match[1];
				}
				continue;
			}

			if (firstChar == "d") {
				if (l.match(/^deleted file mode .*$/))
					endname = "/dev/null";
				continue;
			}
			if (firstChar == "-") {
				if (match = l.match(/^--- (a\/)?(.*)$/))
					startname = match[2];
				continue;
			}
			if (firstChar == "+") {
				if (match = l.match(/^\+\+\+ (b\/)?(.*)$/))
					endname = match[2];
				continue;
			}
			// If it is a complete rename, we don't know the name yet
			// We can figure this out from the 'rename from.. rename to.. thing
			if (firstChar == 'r')
			{
				if (match = l.match(/^rename (from|to) (.*)$/))
				{
					if (match[1] == "from")
						startname = match[2];
					else
						endname = match[2];
				}
				continue;
			}
			if (firstChar == "B") // "Binary files .. and .. differ"
			{
				binary = true;
				// We might not have a diff from the binary file if it's new.
				// So, we use a regex to figure that out

				if (match = l.match(/^Binary files (a\/)?(.*) and (b\/)?(.*) differ$/))
				{
					startname = match[2];
					endname = match[4];
				}
			}

			// Finish the header
			if (firstChar == "@")
				header = false;
			else
				continue;
		}

		sindex = "index=" + lindex.toString() + " ";
		if (firstChar == "+") {
			line1 += "\n";
			line2 += ++hunk_start_line_2 + "\n";
			diffContent += "<div " + sindex + "class='addline'>" + l + "</div>";
		} else if (firstChar == "-") {
			line1 += ++hunk_start_line_1 + "\n";
			line2 += "\n";
			diffContent += "<div " + sindex + "class='delline'>" + l + "</div>";
		} else if (firstChar == "@") {
			if (header) {
				header = false;
			}

			if (m = l.match(/@@ \-([0-9]+),?\d* \+(\d+),?\d* @@/))
			{
				hunk_start_line_1 = parseInt(m[1]) - 1;
				hunk_start_line_2 = parseInt(m[2]) - 1;
			}
			line1 += "...\n";
			line2 += "...\n";
			diffContent += "<div " + sindex + "class='hunkheader'>" + l + "</div>";
		} else if (firstChar == " ") {
			line1 += ++hunk_start_line_1 + "\n";
			line2 += ++hunk_start_line_2 + "\n";
			diffContent += "<div " + sindex + "class='noopline'>" + l + "</div>";
		}
		lindex++;
	}

	finishContent();

	// This takes about 7ms
	element.innerHTML = finalContent;

	// TODO: Replace this with a performance pref call
	if (false)
		Controller.log_("Total time:" + (new Date().getTime() - start));
}

var highlightTrailingWhitespace = function (l) {
	// Highlight trailing whitespace
	l = l.replace(/(\s+)(<\/ins>)?$/, '<span class="whitespace">$1</span>$2');
	return l;
}

var mergeInsDel = function (html) {
	return html
		.replace(/^<\/(ins|del)>|<(ins|del)>$/g,'')
		.replace(/<\/(ins|del)><\1>/g,'');
}

var postProcessDiffContents = function(diffContent) {
	var $ = jQuery;
	var diffEl = $(diffContent);
	var dumbEl = $('<div/>');
	var newContent = "";
	var oldEls = [];
	var newEls = [];
	var flushBuffer = function () {
		if (oldEls.length || newEls.length) {
			var buffer = "";
			if (!oldEls.length || !newEls.length) {
				// hunk only contains additions OR deletions, so there is no need
				// to do any inline-diff. just keep the elements as they are
				buffer = $.map(oldEls.length ? oldEls : newEls, function (e) {
					var prefix = e.text().substring(0,1),
						text = inlinediff.escape(e.text().substring(1)),
						tag = prefix=='+' ? 'ins' : 'del',
						html = prefix+'<'+tag+'>'+(prefix == "+" ? highlightTrailingWhitespace(text) : text)+'</'+tag+'>';
					e.html(html);
					return dumbEl.html(e).html();
				}).join("");
			}
			else {
				// hunk contains additions AND deletions. so we create an inline diff
				// of all the old and new lines together and merge the result back to buffer
				var mapFn = function (e) { return e.text().substring(1).replace(/\r?\n|\r/g,''); };
				var oldText = $.map(oldEls, mapFn).join("\n");
				var newText = $.map(newEls, mapFn).join("\n");
				var diffResult = inlinediff.diffString3(oldText,newText);
					diffLines = (diffResult[1] + "\n" + diffResult[2]).split(/\n/g);
				
				buffer = $.map(oldEls, function (e, i) {
					var di = i;
					e.html("-"+mergeInsDel(diffLines[di]));
					return dumbEl.html(e).html();
				}).join("") + $.map(newEls, function (e, i) {
					var di = i + oldEls.length;
					var line = mergeInsDel(highlightTrailingWhitespace(diffLines[di]));
					e.html("+"+line);
					return dumbEl.html(e).html();
				}).join("");
			}
			newContent+= buffer;
			oldEls = [];
			newEls = [];
		}
	};
	diffEl.each(function (i, e) {
		e = $(e);
		var isAdd = e.is(".addline");
		var isDel = e.is(".delline");
		var text = e.text();
		var html = dumbEl.html(e).html();
		if (isAdd) {
			newEls.push(e);
		}
		else if (isDel) {
			oldEls.push(e);
		}
		else {
			flushBuffer();
			newContent+= html;
		}
	});
	flushBuffer();
	return newContent; 
}


/*
 * Javascript Diff Algorithm
 *  By John Resig (http://ejohn.org/)
 *  Modified by Chu Alan "sprite"
 *  Adapted for GitX by Mathias Leppich http://github.com/muhqu
 *
 * Released under the MIT license.
 *
 * More Info:
 *  http://ejohn.org/projects/javascript-diff-algorithm/
 */

var inlinediff = (function () {
  return {
    diffString: diffString,
    diffString3: diffString3,
    escape: escape
  };

  function escape(s) {
      var n = s;
      n = n.replace(/&/g, "&amp;");
      n = n.replace(/</g, "&lt;");
      n = n.replace(/>/g, "&gt;");
      n = n.replace(/"/g, "&quot;");
      return n;
  }

  function diffString( o, n ) {
    o = o.replace(/\s+$/, '');
    n = n.replace(/\s+$/, '');

    var out = diff(o == "" ? [] : o.split(/\s+/), n == "" ? [] : n.split(/\s+/) );
    var str = "";

    var oSpace = o.match(/\s+/g);
    if (oSpace == null) {
      oSpace = ["\n"];
    } else {
      oSpace.push("\n");
    }
    var nSpace = n.match(/\s+/g);
    if (nSpace == null) {
      nSpace = ["\n"];
    } else {
      nSpace.push("\n");
    }

    if (out.n.length == 0) {
        for (var i = 0; i < out.o.length; i++) {
          str += '<del>' + escape(out.o[i]) + oSpace[i] + "</del>";
        }
    } else {
      if (out.n[0].text == null) {
        for (n = 0; n < out.o.length && out.o[n].text == null; n++) {
          str += '<del>' + escape(out.o[n]) + oSpace[n] + "</del>";
        }
      }

      for ( var i = 0; i < out.n.length; i++ ) {
        if (out.n[i].text == null) {
          str += '<ins>' + escape(out.n[i]) + nSpace[i] + "</ins>";
        } else {
          var pre = "";

          for (n = out.n[i].row + 1; n < out.o.length && out.o[n].text == null; n++ ) {
            pre += '<del>' + escape(out.o[n]) + oSpace[n] + "</del>";
          }
          str += escape(out.n[i].text) + nSpace[i] + pre;
        }
      }
    }
    
    return str;
  }

  function whitespaceAwareTokenize(n) {
    return n !== "" && n.match(/\n| *[\-><!=]+ *|[ \t]+|[<$&#§%]\w+|\w+|\W/g) || [];
  }

  function tag(t,c) {
    if (t === "") return escape(c);
    return c==="" ? '' : '<'+t+'>'+escape(c)+'</'+t+'>';
  }
  
  function diffString3( o, n ) {
    var out = diff(whitespaceAwareTokenize(o), whitespaceAwareTokenize(n));
    var ac = [], ao = [], an = [];
    if (out.n.length == 0) {
        for (var i = 0; i < out.o.length; i++) {
          ac.push(tag('del',out.o[i]));
          ao.push(tag('del',out.o[i]));
        }
    } else {
      if (out.n[0].text == null) {
        for (n = 0; n < out.o.length && out.o[n].text == null; n++) {
          ac.push(tag('del',out.o[n]));
        }
      }

      var added = 0;
      for ( var i = 0; i < out.o.length; i++ ) {
        if (out.o[i].text == null) {
          ao.push(tag('del',out.o[i])); added++;
        } else {
          var moved = (i - out.o[i].row - added);
          ao.push(tag((moved>0) ? 'del' : '',out.o[i].text));
        }
      }

      var removed = 0;
      for ( var i = 0; i < out.n.length; i++ ) {
        if (out.n[i].text == null) {
          ac.push(tag('ins',out.n[i]));
          an.push(tag('ins',out.n[i]));
        } else {
          var moved = (i - out.n[i].row + removed);
          an.push(tag((moved<0)?'ins':'', out.n[i].text));
          ac.push(escape(out.n[i].text));
          for (n = out.n[i].row + 1; n < out.o.length && out.o[n].text == null; n++ ) {
            ac.push(tag('del',out.o[n])); removed++;
          }
        }
      }
    }
    return [
      ac.join(""), // anotated combined additions and deletions
      ao.join(""), // old with highlighted deletions
      an.join("")  // new with highlighted additions
    ];
  }

  function diff( o, n ) {
    var ns = {}, os = {}, k = null, i = 0;
    
    for ( var i = 0; i < n.length; i++ ) {
      k = '"' + n[i]; // prefix keys with a quote to not collide with Object's internal keys, e.g. '__proto__' or 'constructor'
      if ( ns[k] === undefined )
        ns[k] = { rows: [], o: null };
      ns[k].rows.push( i );
    }
    
    for ( var i = 0; i < o.length; i++ ) {
      k = '"' + o[i]
      if ( os[k] === undefined )
        os[k] = { rows: [], n: null };
      os[k].rows.push( i );
    }
    
    for ( var k in ns ) {
      if ( ns[k].rows.length == 1 && os[k] !== undefined && os[k].rows.length == 1 ) {
        n[ ns[k].rows[0] ] = { text: n[ ns[k].rows[0] ], row: os[k].rows[0] };
        o[ os[k].rows[0] ] = { text: o[ os[k].rows[0] ], row: ns[k].rows[0] };
      }
    }
    
    for ( var i = 0; i < n.length - 1; i++ ) {
      if ( n[i].text != null && n[i+1].text == null && n[i].row + 1 < o.length && o[ n[i].row + 1 ].text == null && 
           n[i+1] == o[ n[i].row + 1 ] ) {
        n[i+1] = { text: n[i+1], row: n[i].row + 1 };
        o[n[i].row+1] = { text: o[n[i].row+1], row: i + 1 };
      }
    }
    
    for ( var i = n.length - 1; i > 0; i-- ) {
      if ( n[i].text != null && n[i-1].text == null && n[i].row > 0 && o[ n[i].row - 1 ].text == null && 
           n[i-1] == o[ n[i].row - 1 ] ) {
        n[i-1] = { text: n[i-1], row: n[i].row - 1 };
        o[n[i].row-1] = { text: o[n[i].row-1], row: i - 1 };
      }
    }
    
    return { o: o, n: n };
  }
})();

