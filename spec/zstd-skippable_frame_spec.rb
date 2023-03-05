require "spec_helper"
require 'zstd-ruby'
require 'securerandom'

RSpec.describe Zstd do
  describe 'read_skippable_frame' do
    context 'simple string' do
      it '' do
        expect(Zstd.read_skippable_frame('abc')).to eq nil
      end
    end
    context 'compressed string' do
      it '' do
        expect(Zstd.read_skippable_frame(Zstd.compress(SecureRandom.hex(150)))).to eq nil
      end
    end
    context 'compressed string + skippable frame' do
      it '' do
        compressed_data = Zstd.compress(SecureRandom.hex(150))
        compressed_data_with_skippable_frame = Zstd.write_skippable_frame(compressed_data, "sample data")
        expect(Zstd.read_skippable_frame(compressed_data_with_skippable_frame)).to eq "sample data"
      end
    end
  end
end
