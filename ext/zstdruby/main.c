#include "common.h"

VALUE rb_mZstd;
VALUE rb_cCDict;
VALUE rb_cDDict;
void zstd_ruby_init(void);
void zstd_ruby_skippable_frame_init(void);
void zstd_ruby_streaming_compress_init(void);
void zstd_ruby_streaming_decompress_init(void);

void
Init_zstdruby(void)
{
#ifdef HAVE_RB_EXT_RACTOR_SAFE
  rb_ext_ractor_safe(true);
#endif

  rb_mZstd = rb_define_module("Zstd");
  rb_cCDict = rb_define_class_under(rb_mZstd, "CDict", rb_cObject);
  rb_cDDict = rb_define_class_under(rb_mZstd, "DDict", rb_cObject);
  zstd_ruby_init();
  zstd_ruby_skippable_frame_init();
  zstd_ruby_streaming_compress_init();
  zstd_ruby_streaming_decompress_init();
}
