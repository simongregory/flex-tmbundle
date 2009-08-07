#!/usr/bin/env ruby -wKU
require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'

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

#`echo '#{prefix}'>/Users/$USER/Desktop/flex_completion_debug.txt` #DEBUG

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


