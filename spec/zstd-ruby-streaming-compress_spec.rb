require "spec_helper"
require 'zstd-ruby'

RSpec.describe Zstd::StreamingCompress do
  describe 'new' do
    it 'shoud work' do
      stream = Zstd::StreamingCompress.new
      stream << "test" << "test"
      res = stream.finish
      expect(Zstd.decompress(res)).to eq('testtest')
    end
  end

end

