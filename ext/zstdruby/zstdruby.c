#include <common.h>

extern VALUE rb_mZstd;

static VALUE zstdVersion(VALUE self)
{
  unsigned version = ZSTD_versionNumber();
  return INT2NUM(version);
}

static VALUE rb_compress(int argc, VALUE *argv, VALUE self)
{
  VALUE input_value;
  VALUE compression_level_value;
  rb_scan_args(argc, argv, "11", &input_value, &compression_level_value);
  int compression_level = convert_compression_level(compression_level_value);

  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);
  size_t max_compressed_size = ZSTD_compressBound(input_size);

  VALUE output = rb_str_new(NULL, max_compressed_size);
  char* output_data = RSTRING_PTR(output);
  size_t compressed_size = ZSTD_compress((void*)output_data, max_compressed_size,
                                         (void*)input_data, input_size, compression_level);
  if (ZSTD_isError(compressed_size)) {
    rb_raise(rb_eRuntimeError, "%s: %s", "compress failed", ZSTD_getErrorName(compressed_size));
  }

  rb_str_resize(output, compressed_size);
  return output;
}

static VALUE rb_compress_using_dict(int argc, VALUE *argv, VALUE self)
{
  VALUE input_value;
  VALUE dict;
  VALUE compression_level_value;
  rb_scan_args(argc, argv, "21", &input_value, &dict, &compression_level_value);
  int compression_level = convert_compression_level(compression_level_value);

  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);
  size_t max_compressed_size = ZSTD_compressBound(input_size);

  char* dict_buffer = RSTRING_PTR(dict);
  size_t dict_size = RSTRING_LEN(dict);

  ZSTD_CDict* const cdict = ZSTD_createCDict(dict_buffer, dict_size, compression_level);
  if (cdict == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCDict failed");
  }
  ZSTD_CCtx* const ctx = ZSTD_createCCtx();
  if (ctx == NULL) {
    ZSTD_freeCDict(cdict);
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCCtx failed");
  }

  VALUE output = rb_str_new(NULL, max_compressed_size);
  char* output_data = RSTRING_PTR(output);
  size_t const compressed_size = ZSTD_compress_usingCDict(ctx, (void*)output_data, max_compressed_size,
                                             (void*)input_data, input_size, cdict);

  if (ZSTD_isError(compressed_size)) {
    ZSTD_freeCDict(cdict);
    ZSTD_freeCCtx(ctx);
    rb_raise(rb_eRuntimeError, "%s: %s", "compress failed", ZSTD_getErrorName(compressed_size));
  }

  rb_str_resize(output, compressed_size);
  ZSTD_freeCDict(cdict);
  ZSTD_freeCCtx(ctx);
  return output;
}


static VALUE decompress_buffered(const char* input_data, size_t input_size)
{
  const size_t outputBufferSize = 4096;

  ZSTD_DStream* const dstream = ZSTD_createDStream();
  if (dstream == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDStream failed");
  }

  size_t initResult = ZSTD_initDStream(dstream);
  if (ZSTD_isError(initResult)) {
    ZSTD_freeDStream(dstream);
    rb_raise(rb_eRuntimeError, "%s: %s", "ZSTD_initDStream failed", ZSTD_getErrorName(initResult));
  }

  VALUE output_string = rb_str_new(NULL, 0);
  ZSTD_outBuffer output = { NULL, 0, 0 };

  ZSTD_inBuffer input = { input_data, input_size, 0 };
  while (input.pos < input.size) {
    output.size += outputBufferSize;
    rb_str_resize(output_string, output.size);
    output.dst = RSTRING_PTR(output_string);

    size_t readHint = ZSTD_decompressStream(dstream, &output, &input);
    if (ZSTD_isError(readHint)) {
      ZSTD_freeDStream(dstream);
      rb_raise(rb_eRuntimeError, "%s: %s", "ZSTD_decompressStream failed", ZSTD_getErrorName(readHint));
    }
  }

  ZSTD_freeDStream(dstream);
  rb_str_resize(output_string, output.pos);
  return output_string;
}

static VALUE rb_decompress(VALUE self, VALUE input_value)
{
  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);

  unsigned long long const uncompressed_size = ZSTD_getFrameContentSize(input_data, input_size);
  if (uncompressed_size == ZSTD_CONTENTSIZE_ERROR) {
    rb_raise(rb_eRuntimeError, "%s: %s", "not compressed by zstd", ZSTD_getErrorName(uncompressed_size));
  }
  if (uncompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
    return decompress_buffered(input_data, input_size);
  }

  VALUE output = rb_str_new(NULL, uncompressed_size);
  char* output_data = RSTRING_PTR(output);
  size_t const decompress_size = ZSTD_decompress((void*)output_data, uncompressed_size,
                                           (void*)input_data, input_size);

  if (ZSTD_isError(decompress_size)) {
    rb_raise(rb_eRuntimeError, "%s: %s", "decompress error", ZSTD_getErrorName(decompress_size));
  }

  return output;
}

static VALUE rb_decompress_using_dict(int argc, VALUE *argv, VALUE self)
{
  VALUE input_value;
  VALUE dict;
  rb_scan_args(argc, argv, "20", &input_value, &dict);

  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);
  unsigned long long const uncompressed_size = ZSTD_getFrameContentSize(input_data, input_size);
  if (uncompressed_size == ZSTD_CONTENTSIZE_ERROR) {
    rb_raise(rb_eRuntimeError, "%s: %s", "not compressed by zstd", ZSTD_getErrorName(uncompressed_size));
  }
  if (uncompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
    return decompress_buffered(input_data, input_size);
  }
  VALUE output = rb_str_new(NULL, uncompressed_size);
  char* output_data = RSTRING_PTR(output);

  char* dict_buffer = RSTRING_PTR(dict);
  size_t dict_size = RSTRING_LEN(dict);
  ZSTD_DDict* const ddict = ZSTD_createDDict(dict_buffer, dict_size);
  if (ddict == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDDict failed");
  }

  unsigned const expected_dict_id = ZSTD_getDictID_fromDDict(ddict);
  unsigned const actual_dict_id = ZSTD_getDictID_fromFrame(input_data, input_size);
  if (expected_dict_id != actual_dict_id) {
    ZSTD_freeDDict(ddict);
    rb_raise(rb_eRuntimeError, "%s: %s", "DictID mismatch", ZSTD_getErrorName(uncompressed_size));
  }

  ZSTD_DCtx* const ctx = ZSTD_createDCtx();
  if (ctx == NULL) {
    ZSTD_freeDDict(ddict);
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDCtx failed");
  }
  size_t const decompress_size = ZSTD_decompress_usingDDict(ctx, output_data, uncompressed_size, input_data, input_size, ddict);
  if (ZSTD_isError(decompress_size)) {
    ZSTD_freeDDict(ddict);
    ZSTD_freeDCtx(ctx);
    rb_raise(rb_eRuntimeError, "%s: %s", "decompress error", ZSTD_getErrorName(decompress_size));
  }
  ZSTD_freeDDict(ddict);
  ZSTD_freeDCtx(ctx);
  return output;
}

void
zstd_ruby_init(void)
{
  rb_define_module_function(rb_mZstd, "zstd_version", zstdVersion, 0);
  rb_define_module_function(rb_mZstd, "compress", rb_compress, -1);
  rb_define_module_function(rb_mZstd, "compress_using_dict", rb_compress_using_dict, -1);
  rb_define_module_function(rb_mZstd, "decompress", rb_decompress, 1);
  rb_define_module_function(rb_mZstd, "decompress_using_dict", rb_decompress_using_dict, -1);
}
