require "spec_helper"
require 'zstd-ruby'
require 'pry'

RSpec.describe Zstd::StreamReader do
  describe 'read' do
    it 'shoud work' do
      io = StringIO.new
      writer = Zstd::StreamWriter.new(io)
      writer.write("abc")
      writer.write("def")
      writer.finish
      io.rewind

      reader = Zstd::StreamReader.new(io)
      expect(reader.read(10)).to eq('a')
      expect(reader.read(10)).to eq('bcdef')
      expect(reader.read(10)).to eq('')
    end
  end
end
