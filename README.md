PostgreSQL Windows dependencies
===============================

GitHub Actions build setup for dependency libraries [used by PostgreSQL on Windows](https://github.com/postgres/postgres/blob/60ce452729239f10ebbd0803a0ecc460f7f9238a/src/tools/msvc/config_default.pl#L8):

 - [ICU](https://icu.unicode.org/#h.i33fakvpjb7o)
 - [OpenSSL](https://www.openssl.org/)
 - [libxml2](https://gitlab.gnome.org/GNOME/libxml2/-/wikis/home) and [libxslt](http://www.xmlsoft.org/libxslt/index.html)
 - compression libraries: [zlib](https://www.zlib.net/), [LZ4](https://github.com/lz4/lz4) and [Zstandard](https://github.com/facebook/zstd)
 - libraries required by [Babelfish extensions](https://babelfishpg.org/): [ANTLR C++ runtime](https://www.antlr.org/), [uuid_win](https://github.com/wiltondb/uuid_win) and [int128_win](https://github.com/wiltondb/int128_win).

All dependencies are built from upstream source repos using [MSVC](https://en.wikipedia.org/wiki/Microsoft_Visual_C%2B%2B) toolchain, see exact versions used in a [config file](https://github.com/wiltondb/pgwin_deps/blob/master/config-default.json).


License information
-------------------

All binaries built in this project are released under permissive OSS licenses, the same ones that are used by the corresponding upstream projects.

Build scripts are released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).