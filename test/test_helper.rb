$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'contror'

require 'minitest/autorun'
require "pp"

Parser::Builders::Default.emit_lambda = true

module TestHelper
  def parse(source)
    Parser::CurrentRuby.parse(source)
  end
end

class Minitest::Test
  include TestHelper
end
