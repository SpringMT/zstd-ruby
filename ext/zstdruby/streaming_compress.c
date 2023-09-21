#include <common.h>
#include <streaming_compress.h>
#include <ruby/thread.h>

struct streaming_compress_t {
  ZSTD_CCtx* ctx;
  VALUE buf;
  size_t buf_size;
  char nogvl;
};

static void
streaming_compress_mark(void *p)
{
  struct streaming_compress_t *sc = p;
  rb_gc_mark(sc->buf);
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
  return obj;
}

static VALUE
rb_streaming_compress_initialize(int argc, VALUE *argv, VALUE obj)
{
  VALUE compression_level_value;
  VALUE kwargs;
  rb_scan_args(argc, argv, "01:", &compression_level_value, &kwargs);
  int compression_level = convert_compression_level(compression_level_value);

  ID kwargs_keys[2];
  kwargs_keys[0] = rb_intern("no_gvl");
  kwargs_keys[1] = rb_intern("dict");
  VALUE kwargs_values[2];
  rb_get_kwargs(kwargs, kwargs_keys, 0, 2, kwargs_values);

  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  sc->nogvl = kwargs_values[0] != Qundef && RTEST(kwargs_values[0]);
  size_t const buffOutSize = ZSTD_CStreamOutSize();

  ZSTD_CCtx* ctx = ZSTD_createCCtx();
  if (ctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCCtx error");
  }
  if (kwargs_values[1] != Qundef && kwargs_values[1] != Qnil) {
    char* dict_buffer = RSTRING_PTR(kwargs_values[1]);
    size_t dict_size = RSTRING_LEN(kwargs_values[1]);
    size_t load_dict_ret = ZSTD_CCtx_loadDictionary(ctx, dict_buffer, dict_size);
    if (ZSTD_isError(load_dict_ret)) {
      rb_raise(rb_eRuntimeError, "%s", "ZSTD_CCtx_loadDictionary failed");
    }
  }
  ZSTD_CCtx_setParameter(ctx, ZSTD_c_compressionLevel, compression_level);
  sc->ctx = ctx;
  sc->buf = rb_str_new(NULL, buffOutSize);
  sc->buf_size = buffOutSize;

  return obj;
}

#define FIXNUMARG(val, ifnil) \
    (NIL_P((val)) ? (ifnil) \
    : (FIX2INT((val))))
#define ARG_CONTINUE(val)     FIXNUMARG((val), ZSTD_e_continue)

struct compress_stream_nogvl_t {
  ZSTD_CCtx* ctx;
  ZSTD_outBuffer* output;
  ZSTD_inBuffer* input;
  ZSTD_EndDirective endOp;
  size_t ret;
};

static void*
compressStream2_nogvl(void* arg)
{
  struct compress_stream_nogvl_t* params = arg;
  params->ret = ZSTD_compressStream2(params->ctx, params->output, params->input, params->endOp);
  return NULL;
}

static size_t
compressStream2(char nogvl, ZSTD_CCtx* ctx, ZSTD_outBuffer* output, ZSTD_inBuffer* input, ZSTD_EndDirective endOp)
{
  struct compress_stream_nogvl_t params = { ctx, output, input, endOp, 0 };
  if (nogvl) {
    rb_thread_call_without_gvl(compressStream2_nogvl, &params, NULL, NULL);
  }
  else {
    compressStream2_nogvl(&params);
  }
  return params.ret;
}

static VALUE
no_compress(struct streaming_compress_t* sc, ZSTD_EndDirective endOp)
{
  ZSTD_inBuffer input = { NULL, 0, 0 };
  const char* output_data = RSTRING_PTR(sc->buf);
  VALUE result = rb_str_new(0, 0);
  size_t ret;
  do {
    ZSTD_outBuffer output = { (void*)output_data, sc->buf_size, 0 };

    size_t const ret = compressStream2(sc->nogvl, sc->ctx, &output, &input, endOp);
    if (ZSTD_isError(ret)) {
      rb_raise(rb_eRuntimeError, "flush error error code: %s", ZSTD_getErrorName(ret));
    }
    rb_str_cat(result, output.dst, output.pos);
  } while (ret > 0);
  return result;
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
  VALUE result = rb_str_new(0, 0);
  while (input.pos < input.size) {
    ZSTD_outBuffer output = { (void*)output_data, sc->buf_size, 0 };
    size_t const ret = compressStream2(sc->nogvl, sc->ctx, &output, &input, ZSTD_e_continue);
    if (ZSTD_isError(ret)) {
      rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(ret));
    }
    rb_str_cat(result, output.dst, output.pos);
  }
  return result;
}

static VALUE
rb_streaming_compress_addstr(VALUE obj, VALUE src)
{
  StringValue(src);
  const char* input_data = RSTRING_PTR(src);
  size_t input_size = RSTRING_LEN(src);
  ZSTD_inBuffer input = { input_data, input_size, 0 };

  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  const char* output_data = RSTRING_PTR(sc->buf);

  while (input.pos < input.size) {
    ZSTD_outBuffer output = { (void*)output_data, sc->buf_size, 0 };
    size_t const result = compressStream2(sc->nogvl, sc->ctx, &output, &input, ZSTD_e_continue);
    if (ZSTD_isError(result)) {
      rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(result));
    }
  }
  return obj;
}

static VALUE
rb_streaming_compress_flush(VALUE obj)
{
  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  VALUE result = no_compress(sc, ZSTD_e_flush);
  return result;
}

static VALUE
rb_streaming_compress_finish(VALUE obj)
{
  struct streaming_compress_t* sc;
  TypedData_Get_Struct(obj, struct streaming_compress_t, &streaming_compress_type, sc);
  VALUE result = no_compress(sc, ZSTD_e_end);
  return result;
}

extern VALUE rb_mZstd, cStreamingCompress;
void
zstd_ruby_streaming_compress_init(void)
{
  VALUE cStreamingCompress = rb_define_class_under(rb_mZstd, "StreamingCompress", rb_cObject);
  rb_define_alloc_func(cStreamingCompress, rb_streaming_compress_allocate);
  rb_define_method(cStreamingCompress, "initialize", rb_streaming_compress_initialize, -1);
  rb_define_method(cStreamingCompress, "compress", rb_streaming_compress_compress, 1);
  rb_define_method(cStreamingCompress, "<<", rb_streaming_compress_addstr, 1);
  rb_define_method(cStreamingCompress, "flush", rb_streaming_compress_flush, 0);
  rb_define_method(cStreamingCompress, "finish", rb_streaming_compress_finish, 0);

  rb_define_const(cStreamingCompress, "CONTINUE", INT2FIX(ZSTD_e_continue));
  rb_define_const(cStreamingCompress, "FLUSH", INT2FIX(ZSTD_e_flush));
  rb_define_const(cStreamingCompress, "END", INT2FIX(ZSTD_e_end));
}

