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
  VALUE kwargs;
  rb_scan_args(argc, argv, "10:", &input_value, &kwargs);

  StringValue(input_value);

  ZSTD_CCtx* const ctx = ZSTD_createCCtx();
  if (ctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCCtx error");
  }

  set_compress_params(ctx, kwargs);

  char* input_data = RSTRING_PTR(input_value);
  size_t input_size = RSTRING_LEN(input_value);

  size_t max_compressed_size = ZSTD_compressBound(input_size);
  VALUE output = rb_str_new(NULL, max_compressed_size);
  char* output_data = RSTRING_PTR(output);

  size_t const ret = zstd_compress(ctx, output_data, max_compressed_size, input_data, input_size, false);
  ZSTD_freeCCtx(ctx);
  if (ZSTD_isError(ret)) {
    rb_raise(rb_eRuntimeError, "compress error error code: %s", ZSTD_getErrorName(ret));
  }
  rb_str_resize(output, ret);

  return output;
}

static VALUE decode_one_frame(ZSTD_DCtx* dctx, const unsigned char* src, size_t size, VALUE kwargs) {
  VALUE out = rb_str_buf_new(0);
  size_t cap = ZSTD_DStreamOutSize();
  char *buf = ALLOC_N(char, cap);
  ZSTD_inBuffer in = (ZSTD_inBuffer){ src, size, 0 };

  ZSTD_DCtx_reset(dctx, ZSTD_reset_session_only);
  set_decompress_params(dctx, kwargs);

  for (;;) {
    ZSTD_outBuffer o = (ZSTD_outBuffer){ buf, cap, 0 };
    size_t ret = ZSTD_decompressStream(dctx, &o, &in);
    if (ZSTD_isError(ret)) {
      xfree(buf);
      rb_raise(rb_eRuntimeError, "ZSTD_decompressStream failed: %s", ZSTD_getErrorName(ret));
    }
    if (o.pos) {
      rb_str_cat(out, buf, o.pos);
    }
    if (ret == 0) {
      break;
    }
  }
  xfree(buf);
  return out;
}

static VALUE decompress_buffered(ZSTD_DCtx* dctx, const char* data, size_t len) {
  return decode_one_frame(dctx, (const unsigned char*)data, len, Qnil);
}

static VALUE rb_decompress(int argc, VALUE *argv, VALUE self)
{
  VALUE input_value, kwargs;
  rb_scan_args(argc, argv, "10:", &input_value, &kwargs);
  StringValue(input_value);

  size_t in_size = RSTRING_LEN(input_value);
  const unsigned char *in_r = (const unsigned char *)RSTRING_PTR(input_value);
  unsigned char *in = ALLOC_N(unsigned char, in_size);
  memcpy(in, in_r, in_size);

  size_t off = 0;
  const uint32_t ZSTD_MAGIC = 0xFD2FB528U;
  const uint32_t SKIP_LO    = 0x184D2A50U; /* ...5F */

  while (off + 4 <= in_size) {
    uint32_t magic = (uint32_t)in[off]
                   | ((uint32_t)in[off+1] << 8)
                   | ((uint32_t)in[off+2] << 16)
                   | ((uint32_t)in[off+3] << 24);

    if ((magic & 0xFFFFFFF0U) == (SKIP_LO & 0xFFFFFFF0U)) {
      if (off + 8 > in_size) break;
      uint32_t skipLen = (uint32_t)in[off+4]
                       | ((uint32_t)in[off+5] << 8)
                       | ((uint32_t)in[off+6] << 16)
                       | ((uint32_t)in[off+7] << 24);
      size_t adv = (size_t)8 + (size_t)skipLen;
      if (off + adv > in_size) break;
      off += adv;
      continue;
    }

    if (magic == ZSTD_MAGIC) {
      ZSTD_DCtx *dctx = ZSTD_createDCtx();
      if (!dctx) {
        xfree(in);
        rb_raise(rb_eRuntimeError, "ZSTD_createDCtx failed");
      }

      VALUE out = decode_one_frame(dctx, in + off, in_size - off, kwargs);

      ZSTD_freeDCtx(dctx);
      xfree(in);
      RB_GC_GUARD(input_value);
      return out;
    }

    off += 1;
  }

  xfree(in);
  RB_GC_GUARD(input_value);
  rb_raise(rb_eRuntimeError, "not a zstd frame (magic not found)");
}

static void free_cdict(void *dict)
{
  ZSTD_freeCDict(dict);
}

static size_t sizeof_cdict(const void *dict)
{
  return ZSTD_sizeof_CDict(dict);
}

static void free_ddict(void *dict)
{
  ZSTD_freeDDict(dict);
}

static size_t sizeof_ddict(const void *dict)
{
  return ZSTD_sizeof_DDict(dict);
}

static const rb_data_type_t cdict_type = {
  "Zstd::CDict",
  {0, free_cdict, sizeof_cdict,},
  0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static const rb_data_type_t ddict_type = {
  "Zstd::DDict",
  {0, free_ddict, sizeof_ddict,},
  0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE rb_cdict_alloc(VALUE self)
{
  ZSTD_CDict* cdict = NULL;
  return TypedData_Wrap_Struct(self, &cdict_type, cdict);
}

static VALUE rb_cdict_initialize(int argc, VALUE *argv, VALUE self)
{
  VALUE dict;
  VALUE compression_level_value;
  rb_scan_args(argc, argv, "11", &dict, &compression_level_value);
  int compression_level = convert_compression_level(NULL, compression_level_value);

  StringValue(dict);
  char* dict_buffer = RSTRING_PTR(dict);
  size_t dict_size = RSTRING_LEN(dict);

  ZSTD_CDict* const cdict = ZSTD_createCDict(dict_buffer, dict_size, compression_level);
  if (cdict == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCDict failed");
  }

  DATA_PTR(self) = cdict;
  return self;
}

static VALUE rb_ddict_alloc(VALUE self)
{
  ZSTD_CDict* ddict = NULL;
  return TypedData_Wrap_Struct(self, &ddict_type, ddict);
}

static VALUE rb_ddict_initialize(VALUE self, VALUE dict)
{
  StringValue(dict);
  char* dict_buffer = RSTRING_PTR(dict);
  size_t dict_size = RSTRING_LEN(dict);

  ZSTD_DDict* const ddict = ZSTD_createDDict(dict_buffer, dict_size);
  if (ddict == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDDict failed");
  }

  DATA_PTR(self) = ddict;
  return self;
}

static VALUE rb_prohibit_copy(VALUE self, VALUE obj)
{
  rb_raise(rb_eRuntimeError, "CDict cannot be duplicated");
}

void
zstd_ruby_init(void)
{
  rb_define_module_function(rb_mZstd, "zstd_version", zstdVersion, 0);
  rb_define_module_function(rb_mZstd, "compress", rb_compress, -1);
  rb_define_module_function(rb_mZstd, "decompress", rb_decompress, -1);

  rb_define_alloc_func(rb_cCDict, rb_cdict_alloc);
  rb_define_private_method(rb_cCDict, "initialize", rb_cdict_initialize, -1);
  rb_define_method(rb_cCDict, "initialize_copy", rb_prohibit_copy, 1);

  rb_define_alloc_func(rb_cDDict, rb_ddict_alloc);
  rb_define_private_method(rb_cDDict, "initialize", rb_ddict_initialize, 1);
  rb_define_method(rb_cDDict, "initialize_copy", rb_prohibit_copy, 1);
}
