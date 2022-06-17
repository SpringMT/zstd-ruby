#include <common.h>
#include <streaming_compress.h>

struct streaming_compress_t {
  ZSTD_CCtx* ctx;
  VALUE buf;
  size_t buf_size;
  size_t pos;
};


static void
streaming_compress_mark(void *p)
{
  struct streaming_compress_t *sc = p;
  rb_gc_mark(sc->buf);
  rb_gc_mark(sc->buf_size);
  rb_gc_mark(sc->pos);
}

static void
streaming_compress_free(void *p)
{
  struct streaming_compress_t *sc = p;
  ZSTD_CCtx* ctx = sc->ctx;
  if (ctx != NULL) {
    ZSTD_freeCCtx(ctx);
  }
  xfree(sc);
}

static size_t
streaming_compress_memsize(const void *p)
{
    /* n.b. this does not track memory managed via zalloc/zfree callbacks */
    return sizeof(struct streaming_compress_t);
}

static const rb_data_type_t streaming_compress_type = {
    "streaming_compress",
    { streaming_compress_mark, streaming_compress_free, streaming_compress_memsize, },
     0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
rb_streaming_compress_allocate(VALUE klass)
{
  struct streaming_compress_t* sc;
  VALUE obj = TypedData_Make_Struct(klass, struct streaming_compress_t, &streaming_compress_type, sc);
  sc->ctx = NULL;
  sc->buf = Qnil;
  sc->buf_size = 0;
  sc->pos = 0;
  return obj;
}

static VALUE
rb_streaming_compress_initialize(int argc, VALUE *argv, VALUE obj)
{
  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  size_t const buffOutSize = ZSTD_CStreamOutSize();

  ZSTD_CCtx* ctx = ZSTD_createCCtx();
  if (ctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCCtx error");
  }
  ZSTD_CCtx_setParameter(ctx, ZSTD_c_compressionLevel, 1);
  sc->ctx = ctx;
  sc->buf = rb_str_new(NULL, buffOutSize);
  sc->buf_size = buffOutSize;

  return obj;
}

static VALUE
rb_streaming_compress_compress(VALUE obj, VALUE src)
{
  StringValue(src);
  const char* input_data = RSTRING_PTR(src);
  size_t input_size = RSTRING_LEN(src);
  ZSTD_inBuffer input = { input_data, input_size, 0 };

  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  const char* output_data = RSTRING_PTR(sc->buf);
  ZSTD_outBuffer output = { (void*)output_data, sc->buf_size, 0 };

  size_t const result = ZSTD_compressStream2(sc->ctx, &output, &input, ZSTD_e_continue);
  if (ZSTD_isError(result)) {
    rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(result));
  }
  sc->pos += output.pos;
  return obj;
}

static VALUE
rb_streaming_compress_finish(VALUE obj)
{
  ZSTD_inBuffer input = { NULL, 0, 0 };

  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  const char* output_data = RSTRING_PTR(sc->buf);
  ZSTD_outBuffer output = { (void*)output_data, sc->buf_size, 0 };

  size_t const result = ZSTD_compressStream2(sc->ctx, &output, &input, ZSTD_e_end);
  if (ZSTD_isError(result)) {
    rb_raise(rb_eRuntimeError, "finish error error code: %s", ZSTD_getErrorName(result));
  }
  sc->pos += output.pos;
  rb_str_resize(sc->buf, sc->pos);
  return sc->buf;
}

extern VALUE rb_mZstd, cStreamingCompress;
void
zstd_ruby_streaming_compress_init(void)
{
  VALUE cStreamingCompress = rb_define_class_under(rb_mZstd, "StreamingCompress", rb_cObject);
  rb_define_alloc_func(cStreamingCompress, rb_streaming_compress_allocate);
  rb_define_method(cStreamingCompress, "initialize", rb_streaming_compress_initialize, -1);
  rb_define_method(cStreamingCompress, "<<", rb_streaming_compress_compress, 1);
  rb_define_method(cStreamingCompress, "finish", rb_streaming_compress_finish, 0);
}

