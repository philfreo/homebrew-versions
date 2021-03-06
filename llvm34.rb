require 'formula'

class Llvm34 < Formula
  homepage  'http://llvm.org/'

  stable do
    url 'http://llvm.org/releases/3.4.2/llvm-3.4.2.src.tar.gz'
    sha1 'c5287384d0b95ecb0fd7f024be2cdfb60cd94bc9'

    resource 'clang' do
      url 'http://llvm.org/releases/3.4.2/cfe-3.4.2.src.tar.gz'
      sha1 'add5420b10c3c3a38c4dc2322f8b64ba0a5def97'
    end

    resource 'clang-tools-extra' do
      url 'http://llvm.org/releases/3.4/clang-tools-extra-3.4.src.tar.gz'
      sha1 '56afa36c2ddd11a53f1e199152b04dfb9347d93a'
    end

    resource 'compiler-rt' do
      url 'http://llvm.org/releases/3.4/compiler-rt-3.4.src.tar.gz'
      sha1 'd644b1e4f306f7ad35df0a134d14a1123cd9f082'
    end

    resource 'polly' do
      url 'http://llvm.org/releases/3.4/polly-3.4.src.tar.gz'
      sha1 '90891113f687018e6d0c0ad484afc3b221b89a8f'
    end

    resource 'libcxx' do
      url 'http://llvm.org/releases/3.4.2/libcxx-3.4.2.src.tar.gz'
      sha1 '7daa55bd1e9d87c3657d08d14d6f83566e6a1c04'
    end
  end

  bottle do
    root_url "https://downloads.sf.net/project/machomebrew/Bottles/versions"
    sha1 "386b378901302197496bcca9f24dedb4be92ea88" => :yosemite
    sha1 "ff1d1f028eaa8ce95c2fd44d149a00ab96f6b4a3" => :mavericks
    sha1 "17482b8f991b72eec819896185be797f9aa1bb64" => :mountain_lion
  end

  head do
    url 'http://llvm.org/git/llvm.git', :branch => 'release_34'

    resource 'clang' do
      url 'http://llvm.org/git/clang.git', :branch => 'release_34'
    end

    resource 'clang-tools-extra' do
      url 'http://llvm.org/git/clang-tools-extra.git', :branch => 'release_34'
    end

    resource 'compiler-rt' do
      url 'http://llvm.org/git/compiler-rt.git', :branch => 'release_34'
    end

    resource 'polly' do
      url 'http://llvm.org/git/polly.git', :branch => 'release_34'
    end

    resource 'libcxx' do
      url 'http://llvm.org/git/libcxx.git', :branch => 'release_34'
    end
  end

  resource 'libcxxabi' do
    url 'http://llvm.org/git/libcxxabi.git', :branch => 'release_32'
  end if MacOS.version <= :snow_leopard

  option :universal
  option 'with-asan', 'Include support for -faddress-sanitizer (from compiler-rt)'
  option 'disable-shared', "Don't build LLVM as a shared library"
  option 'all-targets', 'Build all target backends'
  option 'disable-assertions', 'Speeds up LLVM, but provides less debug information'

  depends_on :python => :recommended
  depends_on 'gmp'
  depends_on 'isl'
  depends_on 'cloog'
  depends_on 'libffi' => :recommended

  def ver; '3.4'; end # version suffix

  # LLVM installs its own standard library which confuses stdlib checking.
  cxxstdlib_check :skip

  def install
    if build.with? "python" and build.include? 'disable-shared'
      raise 'The Python bindings need the shared library.'
    end

    clang_buildpath = buildpath/"tools/clang"
    libcxx_buildpath = buildpath/"projects/libcxx"
    libcxxabi_buildpath = buildpath/"libcxxabi" # build failure if put in projects due to no Makefile

    clang_buildpath.install resource("clang")
    libcxx_buildpath.install resource("libcxx")
    (buildpath/"tools/polly").install resource("polly")
    (buildpath/"tools/clang/tools/extra").install resource("clang-tools-extra")
    (buildpath/"projects/compiler-rt").install resource("compiler-rt") if build.with? "asan"

    if build.universal?
      ENV.permit_arch_flags
      ENV['UNIVERSAL'] = '1'
      ENV['UNIVERSAL_ARCH'] = Hardware::CPU.universal_archs.join(' ')
    end

    ENV['REQUIRES_RTTI'] = '1'

    install_prefix = lib/"llvm-#{ver}"

    args = [
      "--prefix=#{install_prefix}",
      "--enable-optimized",
      "--disable-bindings",
      "--with-gmp=#{Formula["gmp"].opt_prefix}",
      "--with-isl=#{Formula["isl"].opt_prefix}",
      "--with-cloog=#{Formula["cloog"].opt_prefix}"
    ]

    if build.include? 'all-targets'
      args << '--enable-targets=all'
    else
      args << '--enable-targets=host'
    end

    args << "--enable-shared" unless build.include? 'disable-shared'

    args << "--disable-assertions" if build.include? 'disable-assertions'

    args << "--enable-libffi" if build.with? 'libffi'

    system './configure', *args
    system 'make', 'VERBOSE=1'
    system 'make', 'VERBOSE=1', 'install'

    if MacOS.version <= :snow_leopard
      libcxxabi_buildpath.install resource("libcxxabi")

      cd libcxxabi_buildpath/'lib' do
        # Set rpath to save user from setting DYLD_LIBRARY_PATH
        inreplace "buildit", "-install_name /usr/lib/libc++abi.dylib", "-install_name #{install_prefix}/usr/lib/libc++abi.dylib"

        ENV['CC'] = "#{install_prefix}/bin/clang"
        ENV['CXX'] = "#{install_prefix}/bin/clang++"
        ENV['TRIPLE'] = "*-apple-*"
        system "./buildit"
        (install_prefix/"usr/lib").install "libc++abi.dylib"
        cp libcxxabi_buildpath/"include/cxxabi.h", install_prefix/"lib/c++/v1"
      end

      # Snow Leopard make rules hardcode libc++ and libc++abi path.
      # Change to Cellar path here.
      inreplace "#{libcxx_buildpath}/lib/buildit" do |s|
        s.gsub! "-install_name /usr/lib/libc++.1.dylib", "-install_name #{install_prefix}/usr/lib/libc++.1.dylib"
        s.gsub! "-Wl,-reexport_library,/usr/lib/libc++abi.dylib", "-Wl,-reexport_library,#{install_prefix}/usr/lib/libc++abi.dylib"
      end

      # On Snow Leopard and older system libc++abi is not shipped but
      # needed here. It is hard to tweak environment settings to change
      # include path as libc++ uses a custom build script, so just
      # symlink the needed header here.
      ln_s libcxxabi_buildpath/"include/cxxabi.h", libcxx_buildpath/"include"
    end

    # Putting libcxx in projects only ensures that headers are installed.
    # Manually "make install" to actually install the shared libs.
    libcxx_make_args = [
      # Use the built clang for building
      "CC=#{install_prefix}/bin/clang",
      "CXX=#{install_prefix}/bin/clang++",
      # Properly set deployment target, which is needed for Snow Leopard
      "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}",
      # The following flags are needed so it can be installed correctly.
      "DSTROOT=#{install_prefix}",
      "SYMROOT=#{libcxx_buildpath}"
    ]

    system "make", "-C", libcxx_buildpath, "install", *libcxx_make_args

    (share/"clang-#{ver}/tools").install Dir["tools/clang/tools/scan-{build,view}"]

    if build.with? "python"
      (lib/"python2.7/site-packages").install "bindings/python/llvm" => "llvm-#{ver}", clang_buildpath/"bindings/python/clang" => "clang-#{ver}"
    end

    Dir.glob(install_prefix/'bin/*') do |exec_path|
      basename = File.basename(exec_path)
      bin.install_symlink exec_path => "#{basename}-#{ver}"
    end

    Dir.glob(install_prefix/'share/man/man1/*') do |manpage|
      basename = File.basename(manpage, ".1")
      man1.install_symlink manpage => "#{basename}-#{ver}.1"
    end
  end

  test do
    system "#{bin}/llvm-config-#{ver}", "--version"
  end

  def caveats; <<-EOS.undent
    Extra tools are installed in #{opt_share}/clang-#{ver}

    To link to libc++, something like the following is required:
      CXX="clang++-#{ver} -stdlib=libc++"
      CXXFLAGS="$CXXFLAGS -nostdinc++ -I#{opt_lib}/llvm-#{ver}/include/c++/v1"
      LDFLAGS="$LDFLAGS -L#{opt_lib}/llvm-#{ver}/usr/lib"
    EOS
  end
end
