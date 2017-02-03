#include "zstd_ruby.h"

VALUE rb_mZstdRuby;

void
Init_zstd_ruby(void)
{
  rb_mZstdRuby = rb_define_module("ZstdRuby");
}
