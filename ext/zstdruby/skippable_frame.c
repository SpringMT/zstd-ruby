#include "common.h"

extern VALUE rb_mZstd;

static VALUE rb_write_skippable_frame(int argc, VALUE *argv, VALUE self)
{
  VALUE input_value;
  VALUE skip_value;
  VALUE kwargs;
  rb_scan_args(argc, argv, "2:", &input_value, &skip_value, &kwargs);

  ID kwargs_keys[1];
  kwargs_keys[0] = rb_intern("magic_variant");
  VALUE kwargs_values[1];
  rb_get_kwargs(kwargs, kwargs_keys, 0, 1, kwargs_values);
  unsigned magic_variant = (kwargs_values[0] != Qundef) ? (NUM2INT(kwargs_values[0])) : 0;

  StringValue(input_value);
  StringValue(skip_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);
  char* skip_data = RSTRING_PTR(skip_value);
  size_t skip_size = RSTRING_LEN(skip_value);

  size_t dst_size = input_size + ZSTD_SKIPPABLEHEADERSIZE + skip_size;
  VALUE output = rb_str_new(input_data, dst_size);
  char* output_data = RSTRING_PTR(output);
  size_t output_size = ZSTD_writeSkippableFrame((void*)output_data, dst_size, (const void*)skip_data, skip_size, magic_variant);
  if (ZSTD_isError(output_size)) {
    rb_raise(rb_eRuntimeError, "%s: %s", "write skippable frame failed", ZSTD_getErrorName(output_size));
  }

  rb_str_resize(output, output_size);
  return output;
}

static VALUE rb_read_skippable_frame(VALUE self, VALUE input_value)
{
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);

  if (ZSTD_isSkippableFrame(input_data, input_size) == 0) {
    return Qnil;
  }
  // ref https://github.com/facebook/zstd/blob/321490cd5b9863433b3d44816d04012874e5ecdb/tests/fuzzer.c#L2096
  size_t const skipLen = 129 * 1024;
  VALUE output = rb_str_new(NULL, skipLen);
  char* output_data = RSTRING_PTR(output);
  unsigned readMagic;
  size_t output_size = ZSTD_readSkippableFrame((void*)output_data, skipLen, &readMagic, (const void*)input_data, input_size);
  if (ZSTD_isError(output_size)) {
    rb_raise(rb_eRuntimeError, "%s: %s", "read skippable frame failed", ZSTD_getErrorName(output_size));
  }
  rb_str_resize(output, output_size);
  return output;
}

void
zstd_ruby_skippable_frame_init(void)
{
  rb_define_module_function(rb_mZstd, "write_skippable_frame", rb_write_skippable_frame, -1);
  rb_define_module_function(rb_mZstd, "read_skippable_frame", rb_read_skippable_frame, 1);
}
