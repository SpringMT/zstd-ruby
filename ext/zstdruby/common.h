#ifndef ZSTD_RUBY_H
#define ZSTD_RUBY_H 1

#include <stdbool.h>
#include <ruby.h>
#ifdef HAVE_RUBY_THREAD_H
#include <ruby/thread.h>
#endif
#include "./libzstd/zstd.h"

extern VALUE rb_cCDict, rb_cDDict;

static int convert_compression_level(VALUE compression_level_value)
{
  if (NIL_P(compression_level_value)) {
    return ZSTD_CLEVEL_DEFAULT;
  }
  return NUM2INT(compression_level_value);
}

static void set_compress_params(ZSTD_CCtx* const ctx, VALUE level_from_args, VALUE kwargs)
{
  ID kwargs_keys[2];
  kwargs_keys[0] = rb_intern("level");
  kwargs_keys[1] = rb_intern("dict");
  VALUE kwargs_values[2];
  rb_get_kwargs(kwargs, kwargs_keys, 0, 2, kwargs_values);

  int compression_level = ZSTD_CLEVEL_DEFAULT;
  if (kwargs_values[0] != Qundef && kwargs_values[0] != Qnil) {
    compression_level = convert_compression_level(kwargs_values[0]);
  } else if (!NIL_P(level_from_args)) {
    rb_warn("`level` in args is deprecated; use keyword args `level:` instead.");
    compression_level = convert_compression_level(level_from_args);
  }
  ZSTD_CCtx_setParameter(ctx, ZSTD_c_compressionLevel, compression_level);

  if (kwargs_values[1] != Qundef && kwargs_values[1] != Qnil) {
    if (CLASS_OF(kwargs_values[1]) == rb_cCDict) {
      ZSTD_CDict* cdict = DATA_PTR(kwargs_values[1]);
      size_t ref_dict_ret = ZSTD_CCtx_refCDict(ctx, cdict);
      if (ZSTD_isError(ref_dict_ret)) {
        ZSTD_freeCCtx(ctx);
        rb_raise(rb_eRuntimeError, "%s", "ZSTD_CCtx_refCDict failed");
      }
    } else if (TYPE(kwargs_values[1]) == T_STRING) {
      char* dict_buffer = RSTRING_PTR(kwargs_values[1]);
      size_t dict_size = RSTRING_LEN(kwargs_values[1]);
      size_t load_dict_ret = ZSTD_CCtx_loadDictionary(ctx, dict_buffer, dict_size);
      if (ZSTD_isError(load_dict_ret)) {
        ZSTD_freeCCtx(ctx);
        rb_raise(rb_eRuntimeError, "%s", "ZSTD_CCtx_loadDictionary failed");
      }
    } else {
      ZSTD_freeCCtx(ctx);
      rb_raise(rb_eArgError, "`dict:` must be a Zstd::CDict or a String");
    }
  }
}

struct stream_compress_params {
  ZSTD_CCtx* ctx;
  ZSTD_outBuffer* output;
  ZSTD_inBuffer* input;
  ZSTD_EndDirective endOp;
  size_t ret;
};

static void* stream_compress_wrapper(void* args)
{
    struct stream_compress_params* params = args;
    params->ret = ZSTD_compressStream2(params->ctx, params->output, params->input, params->endOp);
    return NULL;
}

static size_t zstd_stream_compress(ZSTD_CCtx* const ctx, ZSTD_outBuffer* output, ZSTD_inBuffer* input, ZSTD_EndDirective endOp, bool gvl)
{
#ifdef HAVE_RUBY_THREAD_H
    if (gvl) {
      return ZSTD_compressStream2(ctx, output, input, endOp);
    } else {
      struct stream_compress_params params = { ctx, output, input, endOp };
      rb_thread_call_without_gvl(stream_compress_wrapper, &params, NULL, NULL);
      return params.ret;
    }
#else
    return ZSTD_compressStream2(ctx, output, input, endOp);
#endif
}

struct compress_params {
  ZSTD_CCtx* ctx;
  char* output_data;
  size_t output_size;
  char* input_data;
  size_t input_size;
  size_t ret;
};

static void* compress_wrapper(void* args)
{
    struct compress_params* params = args;
    params->ret = ZSTD_compress2(params->ctx ,params->output_data, params->output_size, params->input_data, params->input_size);
    return NULL;
}

static size_t zstd_compress(ZSTD_CCtx* const ctx, char* output_data, size_t output_size, char* input_data, size_t input_size, bool gvl)
{
#ifdef HAVE_RUBY_THREAD_H
    if (gvl) {
      return ZSTD_compress2(ctx , output_data, output_size, input_data, input_size);
    } else {
      struct compress_params params = { ctx, output_data, output_size, input_data, input_size };
      rb_thread_call_without_gvl(compress_wrapper, &params, NULL, NULL);
      return params.ret;
    }
#else
    return ZSTD_compress2(ctx , output_data, output_size, input_data, input_size);
#endif
}

static void set_decompress_params(ZSTD_DCtx* const dctx, VALUE kwargs)
{
  ID kwargs_keys[1];
  kwargs_keys[0] = rb_intern("dict");
  VALUE kwargs_values[1];
  rb_get_kwargs(kwargs, kwargs_keys, 0, 1, kwargs_values);

  if (kwargs_values[0] != Qundef && kwargs_values[0] != Qnil) {
    if (CLASS_OF(kwargs_values[0]) == rb_cDDict) {
      ZSTD_DDict* ddict = DATA_PTR(kwargs_values[0]);
      size_t ref_dict_ret = ZSTD_DCtx_refDDict(dctx, ddict);
      if (ZSTD_isError(ref_dict_ret)) {
        ZSTD_freeDCtx(dctx);
        rb_raise(rb_eRuntimeError, "%s", "ZSTD_DCtx_refDDict failed");
      }
    } else if (TYPE(kwargs_values[0]) == T_STRING) {
      char* dict_buffer = RSTRING_PTR(kwargs_values[0]);
      size_t dict_size = RSTRING_LEN(kwargs_values[0]);
      size_t load_dict_ret = ZSTD_DCtx_loadDictionary(dctx, dict_buffer, dict_size);
      if (ZSTD_isError(load_dict_ret)) {
        ZSTD_freeDCtx(dctx);
        rb_raise(rb_eRuntimeError, "%s", "ZSTD_CCtx_loadDictionary failed");
      }
    } else {
      ZSTD_freeDCtx(dctx);
      rb_raise(rb_eArgError, "`dict:` must be a Zstd::DDict or a String");
    }
  }
}

struct stream_decompress_params {
  ZSTD_DCtx* dctx;
  ZSTD_outBuffer* output;
  ZSTD_inBuffer* input;
  size_t ret;
};

static void* stream_decompress_wrapper(void* args)
{
    struct stream_decompress_params* params = args;
    params->ret = ZSTD_decompressStream(params->dctx, params->output, params->input);
    return NULL;
}

static size_t zstd_stream_decompress(ZSTD_DCtx* const dctx, ZSTD_outBuffer* output, ZSTD_inBuffer* input, bool gvl)
{
#ifdef HAVE_RUBY_THREAD_H
    if (gvl) {
      return ZSTD_decompressStream(dctx, output, input);
    } else {
      struct stream_decompress_params params = { dctx, output, input };
      rb_thread_call_without_gvl(stream_decompress_wrapper, &params, NULL, NULL);
      return params.ret;
    }
#else
    return ZSTD_decompressStream(dctx, output, input);
#endif
}

struct decompress_params {
  ZSTD_DCtx* dctx;
  char* output_data;
  size_t output_size;
  char* input_data;
  size_t input_size;
  size_t ret;
};

static void* decompress_wrapper(void* args)
{
    struct decompress_params* params = args;
    params->ret = ZSTD_decompressDCtx(params->dctx, params->output_data, params->output_size, params->input_data, params->input_size);
    return NULL;
}

static size_t zstd_decompress(ZSTD_DCtx* const dctx, char* output_data, size_t output_size, char* input_data, size_t input_size, bool gvl)
{
#ifdef HAVE_RUBY_THREAD_H
    if (gvl) {
      return ZSTD_decompressDCtx(dctx, output_data, output_size, input_data, input_size);
    } else {
      struct decompress_params params = { dctx, output_data, output_size, input_data, input_size };
      rb_thread_call_without_gvl(decompress_wrapper, &params, NULL, NULL);
      return params.ret;
    }
#else
    return ZSTD_decompressDCtx(dctx, output_data, output_size, input_data, input_size);
#endif
}

#endif /* ZSTD_RUBY_H */
