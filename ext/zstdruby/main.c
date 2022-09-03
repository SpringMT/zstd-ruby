#include <common.h>
VALUE rb_mZstd;
void zstd_ruby_init(void);
void zstd_ruby_streaming_compress_init(void);
void zstd_ruby_streaming_decompress_init(void);

void
Init_zstdruby(void)
{
#ifdef HAVE_RB_EXT_RACTOR_SAFE
  rb_ext_ractor_safe(true);
#endif

  rb_mZstd = rb_define_module("Zstd");
  zstd_ruby_init();
  zstd_ruby_streaming_compress_init();
  zstd_ruby_streaming_decompress_init();
}
