require "mkmf"

have_func('rb_gc_mark_movable')

# Check if ruby_abi_version symbol is required
# Based on grpc's approach: https://github.com/grpc/grpc/blob/master/src/ruby/ext/grpc/extconf.rb
def have_ruby_abi_version?
  # Only development/preview versions need the symbol
  return false if RUBY_PATCHLEVEL >= 0
  
  # Ruby 3.2+ development versions require ruby_abi_version
  major, minor = RUBY_VERSION.split('.').map(&:to_i)
  if major > 3 || (major == 3 && minor >= 2)
    puts "Ruby version #{RUBY_VERSION} >= 3.2. Using ruby_abi_version symbol."
    return true
  else
    puts "Ruby version #{RUBY_VERSION} < 3.2. Not using ruby_abi_version symbol."
    return false
  end
end

# Determine which export file to use based on Ruby version
def ext_export_filename
  name = 'ext-export'
  name += '-with-ruby-abi-version' if have_ruby_abi_version?
  name
end

$CFLAGS += ' -I. -O3 -std=c99 -DZSTD_STATIC_LINKING_ONLY -DZSTD_MULTITHREAD -pthread -DDEBUGLEVEL=0 -fvisibility=hidden -DZSTDLIB_VISIBLE=\'__attribute__((visibility("hidden")))\' -DZSTDLIB_HIDDEN=\'__attribute__((visibility("hidden")))\''
$CPPFLAGS += " -fdeclspec" if CONFIG['CXX'] =~ /clang/

# macOS specific: Use exported_symbols_list to control symbol visibility
if RUBY_PLATFORM =~ /darwin/
  ext_export_file = File.join(__dir__, "#{ext_export_filename}.txt")
  $LDFLAGS += " -exported_symbols_list #{ext_export_file}"
  puts "Using export file: #{ext_export_file}"
end

Dir.chdir File.expand_path('..', __FILE__) do
  $srcs = Dir['**/*.c', '**/*.S']

    Dir.glob('libzstd/*') do |path|
        if Dir.exist?(path)
            $VPATH << "$(srcdir)/#{path}"
            $INCFLAGS << " -I$(srcdir)/#{path}"
        end
    end

end

# add include path to the internal folder
# $(srcdir) is a root folder, where "extconf.rb" is stored
$INCFLAGS << " -I$(srcdir) -I$(srcdir)/libzstd"
# add folder, where compiler can search source files
$VPATH << "$(srcdir)"

create_makefile("zstd-ruby/zstdruby")
