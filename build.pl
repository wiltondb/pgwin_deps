# Copyright 2023 alex@staticlibs.net
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Copy::Recursive qw(fcopy dircopy);
use File::Path qw(make_path remove_tree);
use File::Slurp qw(edit_file read_file);
use File::Spec::Functions qw(abs2rel catfile);
use JSON qw(decode_json);

my $root_dir = dirname(abs_path(__FILE__));

sub read_config {
  my $config_file = catfile($root_dir, "config.json");
  if (! -f $config_file) {
    $config_file = catfile($root_dir, "config-default.json");
  }
  my $config_json = read_file($config_file);
  my $config = decode_json($config_json);
  return $config;
}

sub checkout_tag {
  my $dir = shift;
  my $url = shift;
  my $tag = shift;
  if (! -d $dir) {
    print("Cloning git repo, url: [$url], directory: [$dir] ...\n");
    my $parent_dir = dirname($dir);
    if (! -d $parent_dir) {
      make_path($parent_dir) or die("$!");
    }
    chdir($parent_dir);
    my $dir_name = basename($dir);
    0 == system("git clone $url $dir_name") or die("$!");
    chdir($root_dir);
  }
  chdir($dir);
  print("Cleaning up repo, directory: [$dir] ...\n");
  0 == system("git reset --hard HEAD") or die("$!");
  0 == system("git clean -dxf") or die("$!");
  print("Checking out tag: [$tag] ...\n");
  0 == system("git -c advice.detachedHead=false checkout $tag") or die("$!");
  0 == system("git status") or die("$!");
  chdir($root_dir);
}

sub ensure_dir_empty {
  my $dir = shift;
  if (-d $dir) {
    remove_tree($dir) or die("$!");
  }
  make_path($dir) or die("$!");
}

sub debug_enabled {
  my $config = shift;
  my $depname = shift;
  my $cf = $config->{$depname};
  if (exists $cf->{debug}) {
    return $cf->{debug};
  }
  return $config->{debug};
}

sub build_zlib {
  my $config = shift;
  my $depname = "zlib";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [zlib]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $src_dir_rel = abs2rel($src_dir, $build_dir);
  my $cmake_cmd = "cmake $src_dir_rel";
  #$cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  my $dist_lib = catfile($dist_dir, "lib");
  my $dist_bin = catfile($dist_dir, "bin");
  my $build_bin = catfile($build_dir, $cmake_build_type);
  if ($debug) {
    fcopy(catfile($dist_lib, "zlibd.lib"), catfile($dist_lib, "zdll.lib")) or die("$!");
    fcopy(catfile($build_bin, "zlibd.pdb"), catfile($dist_bin, "zlibd.pdb")) or die("$!");
    fcopy(catfile($build_bin, "zlibstaticd.pdb"), catfile($dist_lib, "zlibstaticd.pdb")) or die("$!");
  } else {
    fcopy(catfile($dist_lib, "zlib.lib"), catfile($dist_lib, "zdll.lib")) or die("$!");
    fcopy(catfile($build_bin, "zlib.pdb"), catfile($dist_bin, "zlib.pdb")) or die("$!");
    fcopy(catfile($build_bin, "zlibstatic.pdb"), catfile($dist_lib, "zlibstatic.pdb")) or die("$!");
  }
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_lz4 {
  my $config = shift;
  my $depname = "lz4";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_lists_dir = catfile($src_dir, "build", "cmake");
  my $cmake_lists_dir_rel = abs2rel($cmake_lists_dir, $build_dir);
  my $cmake_cmd = "cmake $cmake_lists_dir_rel";
  #$cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  $cmake_cmd .= " -DLZ4_BUILD_CLI=OFF";
  $cmake_cmd .= " -DLZ4_BUILD_LEGACY_LZ4C=OFF";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  my $dist_lib = catfile($dist_dir, "lib");
  my $dist_bin = catfile($dist_dir, "bin");
  fcopy(catfile($dist_lib, "lz4.lib"), catfile($dist_lib, "liblz4.lib")) or die("$!");
  my $build_bin = catfile($build_dir, $cmake_build_type);
  fcopy(catfile($build_bin, "lz4.pdb"), catfile($dist_bin, "lz4.pdb")) or die("$!");
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_zstd {
  my $config = shift;
  my $depname = "zstd";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_lists_dir = catfile($src_dir, "build", "cmake");
  my $cmake_lists_dir_rel = abs2rel($cmake_lists_dir, $build_dir);
  my $cmake_cmd = "cmake $cmake_lists_dir_rel";
  $cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  $cmake_cmd .= " -DZSTD_BUILD_PROGRAMS=OFF";
  $cmake_cmd .= " -DZSTD_MULTITHREAD_SUPPORT=OFF";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  my $dist_lib = catfile($dist_dir, "lib");
  my $dist_bin = catfile($dist_dir, "bin");
  fcopy(catfile($dist_lib, "zstd.lib"), catfile($dist_lib, "libzstd.lib")) or die("$!");
  my $build_bin = catfile($build_dir, "lib", $cmake_build_type);
  fcopy(catfile($build_bin, "zstd.pdb"), catfile($dist_bin, "zstd.pdb")) or die("$!");
  fcopy(catfile($build_bin, "zstd_static.pdb"), catfile($dist_lib, "zstd_static.pdb")) or die("$!");
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_icu {
  my $config = shift;
  my $depname = "icu";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # make
  my $build_type = "Release";
  if ($debug) {
    $build_type = "Debug";
  }
  chdir($src_dir);
  my $allinone_sln = catfile($src_dir, "icu4c", "source", "allinone");
  my $build_cmd = "msbuild $allinone_sln";
  $build_cmd .= " /p:Configuration=$build_type";
  $build_cmd .= " /p:Platform=x64";
  $build_cmd .= " /p:SkipUWP=true";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  chdir($root_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  dircopy(catfile($src_dir, "icu4c", "bin64"), catfile($dist_dir, "bin64")) or die("$!");
  dircopy(catfile($src_dir, "icu4c", "include"), catfile($dist_dir, "include")) or die("$!");
  dircopy(catfile($src_dir, "icu4c", "lib64"), catfile($dist_dir, "lib64")) or die("$!");
  fcopy(catfile($src_dir, "icu4c", "LICENSE"), catfile($dist_dir, "LICENSE")) or die("$!");
  if ($debug) {
    my $dist_lib64 = catfile($dist_dir, "lib64");
    fcopy(catfile($dist_lib64, "icuind.lib"), catfile($dist_lib64, "icuin.lib")) or die("$!");
    fcopy(catfile($dist_lib64, "icuucd.lib"), catfile($dist_lib64, "icuuc.lib")) or die("$!");
  }
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_libxml {
  my $config = shift;
  my $depname = "libxml2";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  chdir($src_dir);
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $icu_dist_dir = catfile($root_dir, "dist", "icu");
  my $zlib_dist_dir = catfile($root_dir, "dist", "zlib");
  my $cmake_cmd = "cmake $src_dir";
  $cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  $cmake_cmd .= " -DLIBXML2_WITH_ICONV=OFF";
  $cmake_cmd .= " -DLIBXML2_WITH_ICU=ON";
  $cmake_cmd .= " -DICU_ROOT=$icu_dist_dir";
  $cmake_cmd .= " -DLIBXML2_WITH_LZMA=OFF";
  $cmake_cmd .= " -DLIBXML2_WITH_PROGRAMS=OFF";
  $cmake_cmd .= " -DLIBXML2_WITH_PYTHON=OFF";
  $cmake_cmd .= " -DLIBXML2_WITH_ZLIB=ON";
  $cmake_cmd .= " -DZLIB_ROOT=$zlib_dist_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  if ($debug) {
    my $dist_lib = catfile($dist_dir, "lib");
    fcopy(catfile($dist_lib, "libxml2d.lib"), catfile($dist_lib, "libxml2.lib")) or die("$!");
  }
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_libxslt {
  my $config = shift;
  my $depname = "libxslt";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  chdir($src_dir);
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $libxml_dist_dir = catfile($root_dir, "dist", "xml");
  my $cmake_cmd = "cmake $src_dir";
  #$cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  $cmake_cmd .= " -DLIBXSLT_WITH_PYTHON=OFF";
  $cmake_cmd .= " -DLibXml2_ROOT=$libxml_dist_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  if ($debug) {
    my $dist_lib = catfile($dist_dir, "lib");
    fcopy(catfile($dist_lib, "libxsltd.lib"), catfile($dist_lib, "libxslt.lib")) or die("$!");
  }
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_uuid {
  my $config = shift;
  my $depname = "uuid_win";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_cmd = "cmake $src_dir";
  #$cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  my $dist_lib = catfile($dist_dir, "lib");
  fcopy(catfile($dist_lib, "uuid_win.lib"), catfile($dist_lib, "uuid.lib")) or die("$!");
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_int128 {
  my $config = shift;
  my $depname = "int128_win";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_cmd = "cmake $src_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  chdir($root_dir);
  # install
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  fcopy(catfile($src_dir, "int128_win.h"), catfile($dist_dir, "int128_win.h")) or die("$!");
  fcopy(catfile($src_dir, "uint128_win.h"), catfile($dist_dir, "uint128_win.h")) or die("$!");
  fcopy(catfile($src_dir, "LICENSE.txt"), catfile($dist_dir, "LICENSE.txt")) or die("$!");
  fcopy(catfile($src_dir, "README.md"), catfile($dist_dir, "README.md")) or die("$!");
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_utf8cpp {
  my $config = shift;
  my $depname = "utfcpp";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  chdir($src_dir);
  0 == system("git submodule update --init extern/ftest") or die("$!");
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_cmd = "cmake $src_dir";
  # $cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_antlr {
  my $config = shift;
  my $depname = "antlr4";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # patch
  my $runtime_cmake_lists = catfile($src_dir, "runtime", "Cpp", "CMakeLists.txt");
  print("Enabling utf8cpp use in cmake file: [$runtime_cmake_lists]\n");
  my $utf8_line_from = '^# set\(CMAKE_CXX_FLAGS "\$\{CMAKE_CXX_FLAGS\} -DUSE_UTF8_INSTEAD_OF_CODECVT"\)$';
  my $utf8_line_to = 'set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DUSE_UTF8_INSTEAD_OF_CODECVT")';
  edit_file(sub { s/$utf8_line_from/$utf8_line_to/m }, $runtime_cmake_lists);
  my $vocabulary_cpp = catfile($src_dir, "runtime", "Cpp", "runtime", "src", "Vocabulary.cpp");
  print("Fixing 'std::upper' call, file: [$vocabulary_cpp]\n");
  my $locale_line_from = '^#include "Vocabulary.h"$';
  my $locale_line_to = "#include \"Vocabulary.h\"\n\n#include <locale>";
  edit_file(sub { s/$locale_line_from/$locale_line_to/m }, $vocabulary_cpp);
  my $antlr4_common_h = catfile($src_dir, "runtime", "Cpp", "runtime", "src", "antlr4-common.h");
  print("Fixing 'std::u32string' call, file: [$antlr4_common_h]\n");
  my $msc_line_from = '^\s*#if _MSC_VER >= 1900 && _MSC_VER < 2000$';
  my $msc_line_to = "  #if 0 // _MSC_VER >= 1900 && _MSC_VER < 2000";
  edit_file(sub { s/$msc_line_from/$msc_line_to/m }, $antlr4_common_h);
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_lists_dir = catfile($src_dir, "runtime", "Cpp");
  my $cmake_lists_dir_rel = abs2rel($cmake_lists_dir, $build_dir);
  my $utf8cpp_include_dir = catfile($root_dir, "dist", "utf8cpp", "include", "utf8cpp");
  my $cmake_cmd = "cmake $cmake_lists_dir_rel";
  $cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX=$dist_dir";
  $cmake_cmd .= " -DWITH_STATIC_CRT=OFF";
  $cmake_cmd .= " -DCMAKE_CXX_STANDARD=14";
  $cmake_cmd .= " -Dutf8cpp_HEADER=$utf8cpp_include_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  my $install_cmd = "cmake --build .";
  $install_cmd .= " --config $cmake_build_type";
  $install_cmd .= " --target install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  my $build_bin = catfile($src_dir, "runtime", "Cpp", "dist", $cmake_build_type);
  my $dist_lib = catfile($dist_dir, "lib");
  fcopy(catfile($build_bin, "antlr4-runtime.pdb"), catfile($dist_lib, "antlr4-runtime.pdb")) or die("$!");
  fcopy(catfile($build_bin, "antlr4-runtime-static.pdb"), catfile($dist_lib, "antlr4-runtime-static.pdb")) or die("$!");
  chdir($root_dir);
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_openssl {
  my $config = shift;
  my $depname = "openssl";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  chdir($src_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $dist_dir_forward = $dist_dir =~ s/\\/\//gr;
  my $conf_cmd = "perl Configure VC-WIN64A";
  my $ossl_dir = catfile($dist_dir, "ssl");
  my $ossl_dir_forward = $ossl_dir =~ s/\\/\//gr;
  $conf_cmd .= " --prefix=$dist_dir_forward";
  $conf_cmd .= " --openssldir=$ossl_dir_forward";
  if ($debug) {
    $conf_cmd .= " --debug";
  }
  print("$conf_cmd\n");
  0 == system($conf_cmd) or die("$!");
  0 == system("perl configdata.pm --dump") or die("$!");
  # make
  0 == system("nmake") or die("$!");
  if ($cf->{test}) {
    # check
    0 == system("nmake test") or die("$!");
  }
  # install
  0 == system("nmake install") or die("$!");
  my $html_dir = catfile($dist_dir, "html");
  remove_tree($html_dir) or die("$!");
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_iconv {
  my $config = shift;
  my $depname = "iconv";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # configure
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_cmd = "cmake $src_dir";
  $cmake_cmd .= " -DBUILD_STATIC=off";
  $cmake_cmd .= " -DBUILD_SHARED=on";
  $cmake_cmd .= " -DBUILD_EXECUTABLE=off";
  $cmake_cmd .= " -DBUILD_TEST=on";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "cmake --build .";
  $build_cmd .= " --config $cmake_build_type";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # check
  if ($cf->{test}) {
    0 == system("ctest") or die("$!");
  }
  chdir($root_dir);
  # install
  my $target_dir = catfile($build_dir, $cmake_build_type);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $include_dir = catfile($dist_dir, "include");
  ensure_dir_empty($include_dir);
  my $bin_dir = catfile($dist_dir, "bin");
  ensure_dir_empty($bin_dir);
  my $lib_dir = catfile($dist_dir, "lib");
  ensure_dir_empty($lib_dir);
  fcopy(catfile($src_dir, "iconv.h"), catfile($include_dir, "iconv.h")) or die("$!");
  fcopy(catfile($target_dir, "iconv.dll"), catfile($bin_dir, "iconv.dll")) or die("$!");
  fcopy(catfile($target_dir, "iconv.pdb"), catfile($bin_dir, "iconv.pdb")) or die("$!");
  fcopy(catfile($target_dir, "iconv.lib"), catfile($lib_dir, "iconv.lib")) or die("$!");
  fcopy(catfile($target_dir, "iconv.exp"), catfile($lib_dir, "iconv.exp")) or die("$!");
  fcopy(catfile($src_dir, "readme.txt"), catfile($dist_dir, "readme.txt")) or die("$!");
  fcopy(catfile($src_dir, "ChangeLog"), catfile($dist_dir, "ChangeLog")) or die("$!");
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_freetds {
  my $config = shift;
  my $depname = "freetds";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # deps
  my $openssl_dir = catfile($root_dir, "dist", "openssl");
  my $iconv_dir = catfile($root_dir, "dist", "iconv");
  dircopy($iconv_dir, catfile($src_dir, "iconv")) or die("$!");
  # configure
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  my $build_dir = catfile($root_dir, "build", $depname);
  ensure_dir_empty($build_dir);
  chdir($build_dir);
  my $cmake_build_type = "RelWithDebInfo";
  if ($debug) {
    $cmake_build_type = "Debug";
  }
  my $cmake_cmd = "cmake $src_dir";
  $cmake_cmd .= " -G \"NMake Makefiles\"";
  $cmake_cmd .= " -DCMAKE_BUILD_TYPE=$cmake_build_type";
  $cmake_cmd .= " -DENABLE_MSDBLIB=on";
  $cmake_cmd .= " -DCMAKE_INSTALL_PREFIX:PATH=$dist_dir";
  $cmake_cmd .= " -DOPENSSL_ROOT_DIR=$openssl_dir";
  print("$cmake_cmd\n");
  0 == system($cmake_cmd) or die("$!");
  # make
  my $build_cmd = "nmake";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  my $install_cmd = "nmake install";
  print("$install_cmd\n");
  0 == system($install_cmd) or die("$!");
  chdir($root_dir);
  my $bin_dir = catfile($dist_dir, "bin");
  fcopy(catfile($build_dir, "src", "ctlib", "ct.pdb"), catfile($bin_dir, "ct.pdb")) or die("$!");
  fcopy(catfile($build_dir, "src", "dblib", "sybdb.pdb"), catfile($bin_dir, "sybdb.pdb")) or die("$!");
  fcopy(catfile($build_dir, "src", "odbc", "tdsodbc.pdb"), catfile($bin_dir, "tdsodbc.pdb")) or die("$!");
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_mimalloc {
  my $config = shift;
  my $depname = "mimalloc";
  my $debug = debug_enabled($config, $depname);
  my $cf = $config->{$depname};
  if (!${cf}->{build}) {
    return;
  }
  print("Building dependency: [$depname]\n");
  # checkout
  my $src_dir = catfile($root_dir, "src", $depname);
  checkout_tag($src_dir, $cf->{git}{url}, $cf->{git}{tag});
  # make
  my $build_type = "Release";
  if ($debug) {
    $build_type = "Debug";
  }
  chdir($src_dir);
  my $sln = catfile($src_dir, "ide", "vs2022", "mimalloc.sln");
  my $build_cmd = "msbuild $sln";
  $build_cmd .= " /p:Configuration=$build_type";
  $build_cmd .= " /p:Platform=x64";
  print("$build_cmd\n");
  0 == system($build_cmd) or die("$!");
  # install
  chdir($root_dir);
  my $dist_dir = catfile($root_dir, "dist", $cf->{dirname});
  ensure_dir_empty($dist_dir);
  dircopy(catfile($src_dir, "include"), catfile($dist_dir, "include")) or die("$!");
  my $bin_dir = catfile($dist_dir, "bin");
  ensure_dir_empty($bin_dir);
  my $target_dir = catfile($src_dir, "out", "msvc-x64", $build_type);
  fcopy(catfile($target_dir, "mimalloc-static.lib"), catfile($bin_dir, "mimalloc-static.lib")) or die("$!");
  fcopy(catfile($target_dir, "mimalloc-static.pdb"), catfile($bin_dir, "mimalloc-static.pdb")) or die("$!");
  fcopy(catfile($src_dir, "LICENSE"), catfile($dist_dir, "LICENSE")) or die("$!");
  print("Dependency: [$depname] installed to: [$dist_dir]\n");
}

sub build_all {
  my $config = shift;
  build_zlib($config);
  build_lz4($config);
  build_zstd($config);
  build_icu($config);
  build_libxml($config);
  build_libxslt($config);
  build_uuid($config);
  build_int128($config);
  build_utf8cpp($config);
  build_antlr($config);
  build_openssl($config);
  build_iconv($config);
  build_freetds($config);
  build_mimalloc($config);
}

my $config = read_config();
my $dist_dir = catfile($root_dir, "dist");
my $out_dir = catfile($root_dir, "out");
ensure_dir_empty($out_dir);

# release
$config->{debug} = 0;
build_all($config);
rename($dist_dir, catfile($out_dir, "release")) or die("$!");

# debug
$config->{debug} = 1;
build_all($config);
rename($dist_dir, catfile($out_dir, "debug")) or die("$!");
