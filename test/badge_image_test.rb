# Standalone validator regression checks; downloader/image metadata are stubbed.
require "minitest/autorun"
require "ostruct"
require_relative "permissions_test"
class Integer
  def megabytes; self * 1024 * 1024; end
end
module FileHelper
  class << self; attr_accessor :file; end
  def self.download(*, **); file; end
end
module FastImage
  class << self; attr_accessor :image_size, :image_type; end
  def self.size(*); image_size; end
  def self.type(*); image_type; end
end
$LOADED_FEATURES.concat(%w[file_helper.rb fastimage.rb])
require_relative "../lib/westan_vip_painel/badge_image"

class BadgeMinimumSizeTest < Minitest::Test
  URL = "https://example.org/badge.png"
  Validator = WestanVipPainel::BadgeImage
  def setup
    file = OpenStruct.new
    def file.rewind; end
    def file.close!; self.closed = true; end
    FileHelper.file = file
    FastImage.image_type = :png
  end
  def test_accepts_minimum_and_larger_dimensions_without_fixed_ratio
    { logo: [[230, 90], [460, 180], [300, 300]], background: [[455, 120], [910, 240], [600, 600]] }.each do |kind, sizes|
      sizes.each do |size|
        FastImage.image_size = size
        assert_equal URL, Validator.validate!(URL, kind: kind)
      end
    end
    assert FileHelper.file.closed
  end
  def test_rejects_either_dimension_below_minimum_and_unreadable_metadata
    { logo: [[229, 300], [600, 89], nil], background: [[454, 600], [900, 119], nil] }.each do |kind, sizes|
      sizes.each do |size|
        FastImage.image_size = size
        error = assert_raises(Validator::Invalid) { Validator.validate!(URL, kind: kind) }
        assert_match(/no mínimo/, error.message)
      end
    end
    assert FileHelper.file.closed
  end
  def test_preserves_format_restrictions
    FastImage.image_size = [1000, 1000]
    FastImage.image_type = :gif
    assert_raises(Validator::Invalid) { Validator.validate!(URL, kind: :logo) }
    assert_equal URL, Validator.validate!(URL, kind: :background)
  end
end
