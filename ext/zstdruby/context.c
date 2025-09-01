#include "common.h"

extern VALUE rb_mZstd;

typedef struct {
  ZSTD_CCtx* cctx;
  ZSTD_CDict* cdict;
  int compression_level;
  int needs_reset;
  VALUE dictionary;
} zstd_ccontext_t;

typedef struct {
  ZSTD_DCtx* dctx;
  ZSTD_DDict* ddict;
  int needs_reset;
  VALUE dictionary;
} zstd_dcontext_t;

static VALUE rb_cZstdCContext;
static VALUE rb_cZstdDContext;

// Forward declaration of decompress_buffered from zstdruby.c
extern VALUE decompress_buffered(ZSTD_DCtx* dctx, const char* input_data, size_t input_size, bool free_ctx);

// CContext (compression-only) implementation
static void zstd_ccontext_mark(void *ptr)
{
  zstd_ccontext_t *ctx = (zstd_ccontext_t*)ptr;
  if (ctx) {
    rb_gc_mark(ctx->dictionary);
  }
}

static void zstd_ccontext_free(void *ptr)
{
  zstd_ccontext_t *ctx = (zstd_ccontext_t*)ptr;
  if (ctx) {
    if (ctx->cctx) {
      ZSTD_freeCCtx(ctx->cctx);
    }
    if (ctx->cdict) {
      ZSTD_freeCDict(ctx->cdict);
    }
    xfree(ctx);
  }
}

static const rb_data_type_t zstd_ccontext_type = {
  "ZstdCContext",
  {zstd_ccontext_mark, zstd_ccontext_free, 0},
  0, 0,
  RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE zstd_ccontext_alloc(VALUE klass)
{
  zstd_ccontext_t *ctx = ALLOC(zstd_ccontext_t);

  ctx->cctx = NULL;
  ctx->cdict = NULL;
  ctx->compression_level = ZSTD_CLEVEL_DEFAULT;
  ctx->needs_reset = 0;
  ctx->dictionary = Qnil;

  return TypedData_Wrap_Struct(klass, &zstd_ccontext_type, ctx);
}

static VALUE zstd_ccontext_initialize(int argc, VALUE *argv, VALUE self)
{
  VALUE level_value = Qnil;
  VALUE dictionary_value = Qnil;
  VALUE options = Qnil;

  if (argc == 1) {
    if (RB_TYPE_P(argv[0], T_HASH)) {
      options = argv[0];
      level_value = rb_hash_aref(options, ID2SYM(rb_intern("level")));
      dictionary_value = rb_hash_aref(options, ID2SYM(rb_intern("dict")));
    } else {
      level_value = argv[0];
    }
  } else if (argc == 2) {
    level_value = argv[0];
    dictionary_value = argv[1];
  } else if (argc > 2) {
    rb_raise(rb_eArgError, "wrong number of arguments (given %d, expected 0..2)", argc);
  }

  zstd_ccontext_t *ctx;
  TypedData_Get_Struct(self, zstd_ccontext_t, &zstd_ccontext_type, ctx);

  ctx->compression_level = convert_compression_level(level_value);
  ctx->dictionary = dictionary_value;

  ctx->cctx = ZSTD_createCCtx();
  if (!ctx->cctx) {
    rb_raise(rb_eRuntimeError, "Failed to create compression context");
  }

  // Create dictionary if provided
  if (!NIL_P(dictionary_value)) {
    StringValue(dictionary_value);
    char* dict_data = RSTRING_PTR(dictionary_value);
    size_t dict_size = RSTRING_LEN(dictionary_value);

    ctx->cdict = ZSTD_createCDict(dict_data, dict_size, ctx->compression_level);
    if (!ctx->cdict) {
      ZSTD_freeCCtx(ctx->cctx);
      ctx->cctx = NULL;
      rb_raise(rb_eRuntimeError, "Failed to create compression dictionary");
    }
  }

  return self;
}

static VALUE zstd_ccontext_compress(VALUE self, VALUE input_value)
{
  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);

  zstd_ccontext_t *ctx;
  TypedData_Get_Struct(self, zstd_ccontext_t, &zstd_ccontext_type, ctx);

  if (!ctx->cctx) {
    rb_raise(rb_eRuntimeError, "Compression context not initialized");
  }

  if (ctx->needs_reset) {
    size_t reset_result = ZSTD_CCtx_reset(ctx->cctx, ZSTD_reset_session_only);
    if (ZSTD_isError(reset_result)) {
      rb_raise(rb_eRuntimeError, "Failed to reset compression context: %s", ZSTD_getErrorName(reset_result));
    }
    ctx->needs_reset = 0;
  }

  size_t max_compressed_size = ZSTD_compressBound(input_size);
  VALUE output = rb_str_new(NULL, max_compressed_size);
  char* output_data = RSTRING_PTR(output);

  size_t compressed_size;

  // Use dictionary if available
  if (ctx->cdict) {
    compressed_size = ZSTD_compress_usingCDict(ctx->cctx,
                                              (void*)output_data, max_compressed_size,
                                              (void*)input_data, input_size,
                                              ctx->cdict);
  } else {
    compressed_size = ZSTD_compressCCtx(ctx->cctx,
                                       (void*)output_data, max_compressed_size,
                                       (void*)input_data, input_size,
                                       ctx->compression_level);
  }

  if (ZSTD_isError(compressed_size)) {
    rb_raise(rb_eRuntimeError, "Compress failed: %s", ZSTD_getErrorName(compressed_size));
  }

  ctx->needs_reset = 1;
  rb_str_resize(output, compressed_size);
  return output;
}

// DContext (decompression-only) implementation
static void zstd_dcontext_mark(void *ptr)
{
  zstd_dcontext_t *ctx = (zstd_dcontext_t*)ptr;
  if (ctx) {
    rb_gc_mark(ctx->dictionary);
  }
}

static void zstd_dcontext_free(void *ptr)
{
  zstd_dcontext_t *ctx = (zstd_dcontext_t*)ptr;
  if (ctx) {
    if (ctx->dctx) {
      ZSTD_freeDCtx(ctx->dctx);
    }
    if (ctx->ddict) {
      ZSTD_freeDDict(ctx->ddict);
    }
    xfree(ctx);
  }
}

static const rb_data_type_t zstd_dcontext_type = {
  "ZstdDContext",
  {zstd_dcontext_mark, zstd_dcontext_free, 0},
  0, 0,
  RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE zstd_dcontext_alloc(VALUE klass)
{
  zstd_dcontext_t *ctx = ALLOC(zstd_dcontext_t);

  ctx->dctx = NULL;
  ctx->ddict = NULL;
  ctx->needs_reset = 0;
  ctx->dictionary = Qnil;

  return TypedData_Wrap_Struct(klass, &zstd_dcontext_type, ctx);
}

static VALUE zstd_dcontext_initialize(int argc, VALUE *argv, VALUE self)
{
  VALUE dictionary_value = Qnil;
  VALUE options = Qnil;

  if (argc == 1) {
    if (RB_TYPE_P(argv[0], T_HASH)) {
      options = argv[0];
      dictionary_value = rb_hash_aref(options, ID2SYM(rb_intern("dict")));
    } else {
      dictionary_value = argv[0];
    }
  } else if (argc > 1) {
    rb_raise(rb_eArgError, "wrong number of arguments (given %d, expected 0..1)", argc);
  }

  zstd_dcontext_t *ctx;
  TypedData_Get_Struct(self, zstd_dcontext_t, &zstd_dcontext_type, ctx);

  ctx->dictionary = dictionary_value;

  ctx->dctx = ZSTD_createDCtx();
  if (!ctx->dctx) {
    rb_raise(rb_eRuntimeError, "Failed to create decompression context");
  }

  // Create dictionary if provided
  if (!NIL_P(dictionary_value)) {
    StringValue(dictionary_value);
    char* dict_data = RSTRING_PTR(dictionary_value);
    size_t dict_size = RSTRING_LEN(dictionary_value);

    ctx->ddict = ZSTD_createDDict(dict_data, dict_size);
    if (!ctx->ddict) {
      ZSTD_freeDCtx(ctx->dctx);
      ctx->dctx = NULL;
      rb_raise(rb_eRuntimeError, "Failed to create decompression dictionary");
    }
  }

  return self;
}

static VALUE zstd_dcontext_decompress(VALUE self, VALUE input_value)
{
  StringValue(input_value);
  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);

  zstd_dcontext_t *ctx;
  TypedData_Get_Struct(self, zstd_dcontext_t, &zstd_dcontext_type, ctx);

  if (!ctx->dctx) {
    rb_raise(rb_eRuntimeError, "Decompression context not initialized");
  }

  if (ctx->needs_reset) {
    size_t reset_result = ZSTD_DCtx_reset(ctx->dctx, ZSTD_reset_session_only);
    if (ZSTD_isError(reset_result)) {
      rb_raise(rb_eRuntimeError, "Failed to reset decompression context: %s", ZSTD_getErrorName(reset_result));
    }
    ctx->needs_reset = 0;
  }

  unsigned long long const uncompressed_size = ZSTD_getFrameContentSize(input_data, input_size);
  if (uncompressed_size == ZSTD_CONTENTSIZE_ERROR) {
    rb_raise(rb_eRuntimeError, "Not compressed by zstd: %s", ZSTD_getErrorName(uncompressed_size));
  }

   if (uncompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
     ctx->needs_reset = 1;
     return decompress_buffered(ctx->dctx, input_data, input_size, false);
   }

  VALUE output = rb_str_new(NULL, uncompressed_size);
  char* output_data = RSTRING_PTR(output);

  size_t decompress_size;

  // Use dictionary if available
  if (ctx->ddict) {
    decompress_size = ZSTD_decompress_usingDDict(ctx->dctx,
                                                 (void*)output_data, uncompressed_size,
                                                 (void*)input_data, input_size,
                                                 ctx->ddict);
  } else {
    decompress_size = ZSTD_decompressDCtx(ctx->dctx,
                                         (void*)output_data, uncompressed_size,
                                         (void*)input_data, input_size);
  }

  if (ZSTD_isError(decompress_size)) {
    rb_raise(rb_eRuntimeError, "Decompress error: %s", ZSTD_getErrorName(decompress_size));
  }

  ctx->needs_reset = 1;
  return output;
}

void
zstd_ruby_context_init(void)
{
  rb_cZstdCContext = rb_define_class_under(rb_mZstd, "CContext", rb_cObject);
  rb_define_alloc_func(rb_cZstdCContext, zstd_ccontext_alloc);
  rb_define_method(rb_cZstdCContext, "initialize", zstd_ccontext_initialize, -1);
  rb_define_method(rb_cZstdCContext, "compress", zstd_ccontext_compress, 1);

  rb_cZstdDContext = rb_define_class_under(rb_mZstd, "DContext", rb_cObject);
  rb_define_alloc_func(rb_cZstdDContext, zstd_dcontext_alloc);
  rb_define_method(rb_cZstdDContext, "initialize", zstd_dcontext_initialize, -1);
  rb_define_method(rb_cZstdDContext, "decompress", zstd_dcontext_decompress, 1);
}