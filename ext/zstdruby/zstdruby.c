#include "zstdruby.h"

VALUE rb_mZstd;

void
Init_zstdruby(void)
{
  rb_mZstd = rb_define_module("Zstd");
}
