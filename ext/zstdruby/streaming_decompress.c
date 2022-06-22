#include <common.h>

struct streaming_decompress_t {
  ZSTD_DCtx* ctx;
  VALUE buf;
  size_t buf_size;
};

static void
streaming_decompress_mark(void *p)
{
  struct streaming_decompress_t *sd = p;
  // rb_gc_mark((VALUE)sd->ctx);
  rb_gc_mark(sd->buf);
  // rb_gc_mark(sd->buf_size);
}

static void
streaming_decompress_free(void *p)
{
  struct streaming_decompress_t *sd = p;
  ZSTD_DCtx* ctx = sd->ctx;
  if (ctx != NULL) {
    ZSTD_freeDCtx(ctx);
  }
  xfree(sd);
}

static size_t
streaming_decompress_memsize(const void *p)
{
    return sizeof(struct streaming_decompress_t);
}

static const rb_data_type_t streaming_decompress_type = {
    "streaming_decompress",
    { streaming_decompress_mark, streaming_decompress_free, streaming_decompress_memsize, },
     0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
rb_streaming_decompress_allocate(VALUE klass)
{
  struct streaming_decompress_t* sd;
  VALUE obj = TypedData_Make_Struct(klass, struct streaming_decompress_t, &streaming_decompress_type, sd);
  sd->ctx = NULL;
  sd->buf = Qnil;
  sd->buf_size = 0;
  return obj;
}

static VALUE
rb_streaming_decompress_initialize(VALUE obj)
{
  struct streaming_decompress_t* sd;
  TypedData_Get_Struct(obj, struct streaming_decompress_t, &streaming_decompress_type, sd);
  size_t const buffOutSize = ZSTD_DStreamOutSize();

  ZSTD_DCtx* ctx = ZSTD_createDCtx();
  if (ctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDCtx error");
  }
  sd->ctx = ctx;
  sd->buf = rb_str_new(NULL, buffOutSize);
  sd->buf_size = buffOutSize;

  return obj;
}

static VALUE
rb_streaming_decompress_decompress(VALUE obj, VALUE src)
{
  StringValue(src);
  const char* input_data = RSTRING_PTR(src);
  size_t input_size = RSTRING_LEN(src);
  ZSTD_inBuffer input = { input_data, input_size, 0 };

  struct streaming_decompress_t* sd;
  TypedData_Get_Struct(obj, struct streaming_decompress_t, &streaming_decompress_type, sd);
  const char* output_data = RSTRING_PTR(sd->buf);
  VALUE result = rb_str_new(0, 0);
  while (input.pos < input.size) {
    ZSTD_outBuffer output = { (void*)output_data, sd->buf_size, 0 };
    size_t const ret = ZSTD_decompressStream(sd->ctx, &output, &input);
    if (ZSTD_isError(ret)) {
      rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(ret));
    }
    rb_str_cat(result, output.dst, output.pos);
  }
  return result;
}

static VALUE
rb_streaming_decompress_addstr(VALUE obj, VALUE src)
{
  StringValue(src);
  const char* input_data = RSTRING_PTR(src);
  size_t input_size = RSTRING_LEN(src);
  ZSTD_inBuffer input = { input_data, input_size, 0 };

  struct streaming_decompress_t* sd;
  TypedData_Get_Struct(obj, struct streaming_decompress_t, &streaming_decompress_type, sd);
  const char* output_data = RSTRING_PTR(sd->buf);

  while (input.pos < input.size) {
    ZSTD_outBuffer output = { (void*)output_data, sd->buf_size, 0 };
    size_t const result = ZSTD_decompressStream(sd->ctx, &output, &input);
    if (ZSTD_isError(result)) {
      rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(result));
    }
  }
  return obj;
}

extern VALUE rb_mZstd, cStreamingDecompress;
void
zstd_ruby_streaming_decompress_init(void)
{
  VALUE cStreamingDecompress = rb_define_class_under(rb_mZstd, "StreamingDecompress", rb_cObject);
  rb_define_alloc_func(cStreamingDecompress, rb_streaming_decompress_allocate);
  rb_define_method(cStreamingDecompress, "initialize", rb_streaming_decompress_initialize, 0);
  rb_define_method(cStreamingDecompress, "decompress", rb_streaming_decompress_decompress, 1);
  rb_define_method(cStreamingDecompress, "<<", rb_streaming_decompress_addstr, 1);
}

