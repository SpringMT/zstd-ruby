require "mkmf"

have_func('rb_gc_mark_movable')

$CFLAGS = '-I. -O3 -std=c99 -DZSTD_STATIC_LINKING_ONLY -DZSTD_MULTITHREAD -pthread -DDEBUGLEVEL=0 -fvisibility=hidden -DZSTDLIB_VISIBLE=\'__attribute__((visibility("hidden")))\' -DZSTDLIB_HIDDEN=\'__attribute__((visibility("hidden")))\''
$CPPFLAGS += " -fdeclspec" if CONFIG['CXX'] =~ /clang/

# macOS specific: Use exported_symbols_list to control symbol visibility
if RUBY_PLATFORM =~ /darwin/
  $LDFLAGS += " -exported_symbols_list #{File.expand_path('exports.txt', __dir__)}"
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
