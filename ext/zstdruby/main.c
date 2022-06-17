#include <common.h>
VALUE rb_mZstd;
void zstd_ruby_init(void);
void zstd_ruby_streaming_compress_init(void);

void
Init_zstdruby(void)
{
  rb_mZstd = rb_define_module("Zstd");
  zstd_ruby_init();
  zstd_ruby_streaming_compress_init();
}
