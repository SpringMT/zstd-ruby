require "mkmf"

$CFLAGS = '-I. -O3 -std=c99'

Dir.chdir File.expand_path('..', __FILE__) do
    $srcs = Dir['**/*.c']

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
