#!/usr/bin/env ruby -wKU

require ENV['TM_SUPPORT_PATH'] + '/lib/textmate.rb'

#TODO: There's an obvious error with the logic of this as the user could quite easily change the name of the bundle. One way round it would be to use the bundles UUID.

class BundleLocator
  attr_reader :bundle_paths
  def initialize

    @bundle_paths = [ "#{ENV["HOME"]}/Library/Application Support/TextMate/Bundles",
                      "#{ENV["HOME"]}/Library/Application Support/TextMate/Pristine Copy/Bundles",
                      "/Library/Application Support/TextMate/Bundles" ]
    begin
      @bundle_paths << TextMate::app_path.gsub('(.*?)/MacOS/TextMate','\1') + "/Contents/SharedSupport/Bundles"
    rescue
    end

  end

  def find_bundle_dir(target)
    p = @bundle_paths.find { |dir| File.directory? "#{dir}#{target}" }
    return "#{p}#{target}" if p
  end

  def find_bundle_item(target)
    p = @bundle_paths.find { |dir| File.exist? "#{dir}#{target}" }
    return "#{p}#{target}" if p
  end

end

#Legacy Support
def find_bundle_dir(target)
  return BundleLocator.new.find_bundle_dir(target)
end

def find_bundle_item(target)
  return BundleLocator.new.find_bundle_item(target)
end

if __FILE__ == $0

  require "test/unit"

  class TestBundleLocator < Test::Unit::TestCase

    def test_item

      b = BundleLocator.new
      item_a = "/ActionScript 3.tmbundle/Support/lib/flex_env.rb"
      item_b = "/A Non Existent.tmbundle/Support/lib/foo.rb"
      
      assert_equal( "/Users/#{ENV['USER']}/Library/Application Support/TextMate/Bundles/ActionScript 3.tmbundle/Support/lib/flex_env.rb",
                    b.find_bundle_item(item_a))
      
      assert_equal( nil,
                    b.find_bundle_item(item_b))

    end

    def test_dir

      b = BundleLocator.new
      dir_a = "/ActionScript 3.tmbundle/Support/lib"
      dir_b = "/A Non Existent.tmbundle/Support/lib"
      
      assert_equal("/Users/#{ENV['USER']}/Library/Application Support/TextMate/Bundles/ActionScript 3.tmbundle/Support/lib",
                   b.find_bundle_dir(dir_a))

      assert_equal( nil,
                    b.find_bundle_item(dir_b))

    end

  end

end
