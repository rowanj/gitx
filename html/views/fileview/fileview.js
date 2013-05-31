var showFile = function(txt, fileName) {
  $("source").style.display = "";
  var suffix_map = {
    "m": "objc",
	"mm": "objc",
    "h": "objc",
	"pch": "objc",

    "rb": "ruby",
    "rbx": "ruby",
    "rjs": "ruby",
    "Rakefile": "ruby",
    "rake": "ruby",
    "gemspec": "ruby",
    "irbrc": "ruby",
    "capfile": "ruby",

    "xml": "xml",
    "tld": "xml",
    "jsp": "xml",
    "pt": "xml",
    "cpt": "xml",
    "dtml": "xml",
    "rss": "xml",
    "opml": "xml",
    "xsl": "xml",
    "xslt": "xml",
	  
	  "htm": "xml",
	  "html": "xml",
	  "plist": "xml",
    
    "js": "javascript",
    "htc": "javascript",
    "jsx": "javascript",
    "jscript": "javascript",
    "javascript": "javascript",
    
    "sql": "sql",
    "ddl": "sql",
    "dml": "sql",
    
    "sass": "sass",
    "scss": "sass",

    "sh": "bash",
    "bash": "bash",
    "zsh": "bash",
    "bashrc": "bash",
    "bash_profile": "bash",
    "bash_login": "bash",
    "profile": "bash",
    "bash_logout": "bash",

    "diff": "diff",
    "patch": "diff",

    "java": "java",
    "bsh": "java",

    "css": "css",
    "css":  "css.erb",
    "pl": "perl",
    "pm": "perl",
    "pod": "perl",
    "t": "perl",
    "PL": "perl",
    
    "erl": "erlang",
    "hrl": "erlang",

    "php": "php",

    "py": "python",
    "rpy": "python",
    "pyw": "python",
    "cpy": "python",
    "SConstruct": "python",
    "Sconstruct": "python",
    "sconstruct": "python",
    "SConscript": "python",

    "cc": "cpp",
    "cpp": "cpp",
    "cp": "cpp",
    "cxx": "cpp",
    "c++":"cpp",
    "C": "cpp",
//    "h": "cpp",
    "hh": "cpp",
    "hpp": "cpp",
    "h++": "cpp",
    "c": "cpp"
  }

  var suffix = "";
  if (fileName && fileName != '') {
    suffix = fileName.substr(fileName.lastIndexOf('.') + 1);
  }
  
  var brush = suffix_map[suffix] ? suffix_map[suffix] : "plain";
  
  $("source").innerHTML="<pre class='first-line: 1;brush: " + brush + "'>" + txt + "</pre>";

  SyntaxHighlighter.defaults['toolbar'] = false;
  SyntaxHighlighter.highlight();

  return;
}

var test=function(txt) {
  SyntaxHighlighter.defaults['toolbar'] = false;
  SyntaxHighlighter.highlight();

  return;
}

var get_keys = function(obj) {
  var keys = [];
  for (var key in obj) {
    keys.push(key);
  }
  return keys;
}
