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

    context 'compressed string + skippable frame + magic_variant' do
      it '' do
        compressed_data = Zstd.compress(SecureRandom.hex(150))
        compressed_data_with_skippable_frame = Zstd.write_skippable_frame(compressed_data, "sample data", magic_variant: 1)
        expect(Zstd.read_skippable_frame(compressed_data_with_skippable_frame)).to eq "sample data"
      end
    end

    context 'non-String argument' do
      [nil, 123456789, :symbol, [1, 2, 3], Object.new].each do |arg|
        it "raises TypeError for #{arg.class}" do
          expect { Zstd.read_skippable_frame(arg) }.to raise_error(TypeError)
        end
      end
    end

    context 'String-convertible argument' do
      it 'accepts objects responding to #to_str' do
        compressed_data = Zstd.compress(SecureRandom.hex(150))
        frame = Zstd.write_skippable_frame(compressed_data, "sample data")
        convertible = Object.new
        convertible.define_singleton_method(:to_str) { frame }
        expect(Zstd.read_skippable_frame(convertible)).to eq "sample data"
      end
    end

    context 'large input (heap-allocated) + skippable frame' do
      it 'round-trips without breaking' do
        payload = 'A' * 1024
        skippable = 'sample data'
        frame = Zstd.write_skippable_frame(payload, skippable)
        expect(Zstd.read_skippable_frame(frame)).to eq skippable
      end
    end
  end
end
