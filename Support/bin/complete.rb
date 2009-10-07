#!/usr/bin/env ruby -wKU

require ENV['TM_SUPPORT_PATH'] + '/lib/osx/plist'
require ENV['TM_SUPPORT_PATH'] + '/lib/ui'
require ENV['TM_SUPPORT_PATH'] + '/lib/textmate'

require File.expand_path(File.dirname(__FILE__)) + '/../lib/bundle_locator'

# NOTES
#
# Needs to be invoked on a 'blank' line.
#
# Possible prefixes when invoked:
#	<
# <mx
#	<Ar
#	<mx:
#
# It may well be worth refactoring this to work when following scopes 
# for < and : as this could be more logical for the user (and easier to code).
# 
# Expects and uses the 'mx' namespace prefix to be mapped to the uri 
# 'http://www.adobe.com/2006/mxml', if this has been changed then collision with 
# the internally loaded mx completions list is likely to happen. We load this 
# list as a short cut because it's always going to be used - and it gives us 
# the oppourtunity to snippetize it.

# def trace(msg)
#   `echo '#{msg}'>/Users/$USER/Desktop/flex_completion_debug.txt` #DEBUG
# end

#Load the mxml and flex-config file parsers.
b = BundleLocator.new
e = "Unable to load a script from the 'ActionScript 3.tmbundle'.
Please make sure you have the bundle installed (and named as expected)."

as3_bun = ENV['TM_ACTIONSCRIPT_3_BUNDLE_NAME'] || 'ActionScript 3.tmbundle'
as3_lib = "/#{as3_bun}/Support/lib"

b.require_bundle_item("#{as3_lib}/as3/parsers/config.rb",e)
b.require_bundle_item("#{as3_lib}/as3/parsers/mxml.rb",e)
b.require_bundle_item("#{as3_lib}/as3/parsers/manifest.rb",e)
b.require_bundle_item("#{as3_lib}/as3/source_tools.rb",e)

MX_2006_NAMESPACE_URI = 'http://www.adobe.com/2006/mxml'

raw = STDIN.read.strip
li = ENV['TM_LINE_INDEX'] 
ln = ENV['TM_CURRENT_LINE']

#We need to remove any invalid xml the user may be typing before passing 
#the input to MxmlDoc. WARN: Unless the user has invoked completion on a blank 
#line this is just as likely to break the parsing as fix it.
filtered_doc = raw.split("\n")
cln = ENV['TM_LINE_NUMBER'].to_i-1
filtered_doc[cln] = ''

begin
  @mxml_doc = MxmlDoc.new(filtered_doc.to_s) 
rescue Exception => e
  TextMate.exit_show_tool_tip "The current mxml document has failed parsing.\nIs it valid xml?"
end
 
#Has to have TM_FLEX_FILE_SPECS specified for now.
#Need to wire in work done within the new compiler scripts to get guesstimated docs.
@flex_config = ConfigParser.new(true).flex_config

known_namespaces = ['mx']
@components = []

# For every namespace in the document collect a list of classes mapped to it.
@mxml_doc.namespaces.each { |ns|
  
  uri = ns[:name]
  prefix = ns[:prefix]
  
  known_namespaces << prefix unless known_namespaces.include? prefix or prefix.empty?

  #Were we come accross the mx framework namespace use the predetermined completions list.
  if uri == MX_2006_NAMESPACE_URI
    @components += OSX::PropertyList.load(File.read(ENV['TM_BUNDLE_SUPPORT'] + '/data/components.plist'))    
  else
    tag_ns = ( prefix.empty? ) ? '' : "#{prefix}:"
    @components += @flex_config.class_list(uri).collect { |e|
        { 'display' => e, 'insert' => "<#{tag_ns}#{e}$1>$2</#{tag_ns}#{e}>$0", 'prefix' => prefix }
    }    
  end
}

@components.flatten.uniq!

la = ln.split('')
i = li.to_i-1
found = []

#TM_CURRENT_WORD isn't reliable in this instance so we need to do some extra
#work to locate the characters before the cursor.
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

current_word = ENV['TM_CURRENT_WORD']
current_word = '' unless current_word =~ /\w/

#Look for matches of current word against a list of known namespaces.
#This handles instances of <mx , additionally we don't want these values used
#as the initial_filter for UI.complete.
if current_word =~ /(#{known_namespaces.join('|')})(:)?/
  current_word = ''
  namespace = $1
  print ':' if $2.nil?
end

#Use cases: <     if default ns specified filter on it otherwise present all matches.
#           <mx   use namespace as filter for completions.

#Filter the list that's been collected based on the namespace (if one's provided).
if namespace.empty? && @mxml_doc.using_default_namespace
  
  filter_namespace = ''
  
  #Lookup the default namespace uri and if it's mx filter mx only.
  if @mxml_doc.default_namespace_uri == MX_2006_NAMESPACE_URI
    filter_namespace = 'mx'
  end
  @components.reject! { |e| (e['prefix'] != filter_namespace) }
  
elsif namespace.empty?
  
  #Keep everything.
  
else

  @components.reject! { |e| (e['prefix'] != namespace ) }
  
end

TextMate::UI.complete(@components, {:case_insensitive => true, :initial_filter => current_word } ) { |choice|

  snip = choice['insert']
  inserted = choice['display']
  
  #The string injected by the completion mechanism will already be output
  #so we need to accomodate for it. This will only be the class name which means we
  #have to work out what needs deleting from the start of the string.
  if namespace.empty? && @mxml_doc.using_default_namespace == false
  
    #Where the user is working without explicit namespaces we need to take them 
    #out of the completion string.
    snip.gsub!(/(#{known_namespaces.join('|')})\:/,'')
    snip.sub!("<#{inserted}",'')
    
  elsif @mxml_doc.using_default_namespace

    snip.sub!("<#{inserted}",'')
    
  else
    
    snip.sub!("<#{namespace}:#{inserted}",'')
    
  end
    
  snip
  
}


