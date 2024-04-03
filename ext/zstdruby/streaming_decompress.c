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
#ifdef HAVE_RB_GC_MARK_MOVABLE
  rb_gc_mark_movable(sd->buf);
#else
  rb_gc_mark(sd->buf);
#endif
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

#ifdef HAVE_RB_GC_MARK_MOVABLE
static void
streaming_decompress_compact(void *p)
{
  struct streaming_decompress_t *sd = p;
  sd->buf = rb_gc_location(sd->buf);
}
#endif

static const rb_data_type_t streaming_decompress_type = {
  "streaming_decompress",
  {
    streaming_decompress_mark,
    streaming_decompress_free,
    streaming_decompress_memsize,
#ifdef HAVE_RB_GC_MARK_MOVABLE
    streaming_decompress_compact,
#endif
  },
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
      rb_raise(rb_eRuntimeError, "decompress error error code: %s", ZSTD_getErrorName(ret));
    }
    rb_str_cat(result, output.dst, output.pos);
  }
  return result;
}

extern VALUE rb_mZstd, cStreamingDecompress;
void
zstd_ruby_streaming_decompress_init(void)
{
  VALUE cStreamingDecompress = rb_define_class_under(rb_mZstd, "StreamingDecompress", rb_cObject);
  rb_define_alloc_func(cStreamingDecompress, rb_streaming_decompress_allocate);
  rb_define_method(cStreamingDecompress, "initialize", rb_streaming_decompress_initialize, 0);
  rb_define_method(cStreamingDecompress, "decompress", rb_streaming_decompress_decompress, 1);
}
