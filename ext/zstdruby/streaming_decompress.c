#include <common.h>
#include <ruby/thread.h>

struct streaming_decompress_t {
  ZSTD_DCtx* ctx;
  VALUE buf;
  size_t buf_size;
  char nogvl;
};

static void
streaming_decompress_mark(void *p)
{
  struct streaming_decompress_t *sd = p;
  rb_gc_mark(sd->buf);
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
rb_streaming_decompress_initialize(int argc, VALUE *argv, VALUE obj)
{
  VALUE kwargs;
  rb_scan_args(argc, argv, "00:", &kwargs);

  ID kwargs_keys[2];
  kwargs_keys[0] = rb_intern("no_gvl");
  kwargs_keys[1] = rb_intern("dict");
  VALUE kwargs_values[2];
  rb_get_kwargs(kwargs, kwargs_keys, 0, 2, kwargs_values);

  struct streaming_decompress_t* sd;
  TypedData_Get_Struct(obj, struct streaming_decompress_t, &streaming_decompress_type, sd);
  sd->nogvl = kwargs_values[0] != Qundef && RTEST(kwargs_values[0]);
  size_t const buffOutSize = ZSTD_DStreamOutSize();

  ZSTD_DCtx* ctx = ZSTD_createDCtx();
  if (ctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDCtx error");
  }
  if (kwargs_values[1] != Qundef && kwargs_values[1] != Qnil) {
    char* dict_buffer = RSTRING_PTR(kwargs_values[1]);
    size_t dict_size = RSTRING_LEN(kwargs_values[1]);
    size_t load_dict_ret = ZSTD_DCtx_loadDictionary(ctx, dict_buffer, dict_size);
    if (ZSTD_isError(load_dict_ret)) {
      rb_raise(rb_eRuntimeError, "%s", "ZSTD_DCtx_loadDictionary failed");
    }
  }
  sd->ctx = ctx;
  sd->buf = rb_str_new(NULL, buffOutSize);
  sd->buf_size = buffOutSize;

  return obj;
}

struct decompress_stream_nogvl_t {
  ZSTD_DCtx* ctx;
  ZSTD_outBuffer* output;
  ZSTD_inBuffer* input;
  size_t ret;
};

static void*
decompressStream_nogvl(void* args)
{
  struct decompress_stream_nogvl_t* params = args;
  params->ret = ZSTD_decompressStream(params->ctx, params->output, params->input);
  return NULL;
}

static size_t
decompressStream(char nogvl, ZSTD_DCtx* ctx, ZSTD_outBuffer* output, ZSTD_inBuffer* input)
{
  struct decompress_stream_nogvl_t params = { ctx, output, input, 0 };
  if (nogvl) {
    rb_thread_call_without_gvl(decompressStream_nogvl, &params, NULL, NULL);
  }
  else {
    decompressStream_nogvl(&params);
  }
  return params.ret;
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
    size_t const ret = decompressStream(sd->nogvl, sd->ctx, &output, &input);
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
    size_t const result = decompressStream(sd->nogvl, sd->ctx, &output, &input);
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
  rb_define_method(cStreamingDecompress, "initialize", rb_streaming_decompress_initialize, -1);
  rb_define_method(cStreamingDecompress, "decompress", rb_streaming_decompress_decompress, 1);
  rb_define_method(cStreamingDecompress, "<<", rb_streaming_decompress_addstr, 1);
}

