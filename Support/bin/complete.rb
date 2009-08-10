#!/usr/bin/env ruby -wKU

require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'

require File.expand_path(File.dirname(__FILE__)) + '/../lib/bundle_locator'

def trace(msg)
  `echo '#{msg}'>/Users/$USER/Desktop/flex_completion_debug.txt` #DEBUG
end

#Load the mxml and mxmlc-config file parsers.
b = BundleLocator.new
as3_lib = "/ActionScript 3.tmbundle/Support/lib"
config_path = b.find_bundle_item("#{as3_lib}/as3/parsers/config.rb")
mxml_path = b.find_bundle_item("#{as3_lib}/ActionScript 3.tmbundle/Support/lib/as3/parsers/mxml.rb")

#trace config_path
trace mxml_path

if config_path && mxml_path
	require config_path
	require mxml_path
else
	TextMate.exit_show_tool_tip("Unable to load a script from the ActionScript 3 bundle.\nPlease make sure you have the bundle installed.")
end

doc = STDIN.read.strip
mxml_doc = MxmlDoc.new(doc) 

op = ''
op << mxml_doc.super_namespace
op << mxp.super_class
trace op

#Returned selection.
#{ display = 'Parallel'; insert = '<mx:Parallel>$0</mx:Parallel>' }

#Possible prefixes when invoked:
#	<
#	<mx
#	<Ar
#	<mx:

li = ENV['TM_LINE_INDEX'] 
ln = ENV['TM_CURRENT_LINE']
la = ln.split('')
i = li.to_i-1
found = []

#TM_CURRENT_WORD isn't reliable in this instance so we need to do some extra
#work to locate the characaters before the cursor.

while i >= 0

	current_letter = la[i]
	if current_letter =~ /(\<|\s)/
		found << "<"

		#Inject the opening bracket when there isn't one (and there is no ns/initial filter)
		#NOTE: Ideally it would be good to add the < before any existing input
		#but it doesn't seem an easy thing to do with DIALOG2
		print '<' if current_letter  != '<' && found.length == 1
		
		break
	end
	
	found << current_letter
	i -= 1

end

namespace = ''
prefix = found.reverse.to_s

if prefix =~ /^\<(\w+:)/
	namespace = $1
end

#TODO: Collect namespaces in the document, 
known_namespaces = ['mx']
ns_completions = OSX::PropertyList.load(File.read(ENV['TM_BUNDLE_SUPPORT'] + '/data/components.plist'))

current_word = ENV['TM_CURRENT_WORD']
current_word = '' unless current_word =~ /\w/

#Look for matches of current word against a list of known namespaces.
#This handles instances of <mx , additionally we don't want these values used
#as the initial_filter for UI.complete.
if current_word =~ /(#{known_namespaces.join('|')})(:)?/
  current_word = ''
  namespace = $1 + ':'
  print ':' if $2.nil?
end

TextMate::UI.complete(ns_completions, {:case_insensitive => true, :initial_filter => current_word } ) { |choice|

  snip = choice['insert']
  inserted = choice['display']
  
  #The string injected by the completion mechanism will already be output
  #so we need to accomodate for it. This will only be the class name which means we
  #have to work out what needs deleting from the start of the string.
  
  if namespace.empty?

    #Where the user is working without explicit namespaces we need to take them 
    #out of the completion string.
    snip.gsub!(/#{known_namespaces.join('|')}\:/,'')
    snip.sub!("<#{inserted}",'')
        
  else
    
    snip.sub!("<#{namespace+inserted}",'')
    
  end
    
  snip
  
}


