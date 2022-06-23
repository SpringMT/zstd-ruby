#ifndef ZSTD_RUBY_H
#define ZSTD_RUBY_H 1

#include "ruby.h"
#include "./libzstd/zstd.h"

static int convert_compression_level(VALUE compression_level_value)
{
  if (NIL_P(compression_level_value)) {
    return ZSTD_CLEVEL_DEFAULT;
  }
  return NUM2INT(compression_level_value);
}

#endif /* ZSTD_RUBY_H */
