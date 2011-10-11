SUPPORT = ENV['TM_SUPPORT_PATH']
DIALOG = SUPPORT + '/bin/tm_dialog'

require SUPPORT + '/lib/escape'
require SUPPORT + '/lib/exit_codes'
require SUPPORT + '/lib/osx/plist'

def complete_flex_tag(namespace)
  word = "#{namespace}:"
  words = `grep "#{word}" "$TM_BUNDLE_PATH/support/data/mx_completions.txt"`.split("\n")

  words = words.collect { |e|
      mxmlTag = /#{namespace}\:(\w+)(\s(\(\w+\)))?/.match(e)
      suffix = " "
      tag = e
      if mxmlTag[3] != nil
        suffix += mxmlTag[3]
        tag = e.sub(mxmlTag[3],'')
      end
      { 'title' => mxmlTag[1] + suffix, 'data' => tag }
  }
  plist = { 'menuItems' => words }.to_plist

  res = OSX::PropertyList::load(`#{e_sh DIALOG} -up #{e_sh plist}`)

  TextMate.exit_discard() unless res.has_key? 'selectedMenuItem'
  choice = res['selectedMenuItem']['data']

  print choice
end
