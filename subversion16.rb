require 'formula'

def build_java?;   build.include? "java";   end
def build_perl?;   build.include? "perl";   end
def build_python?; build.include? "python"; end
def build_ruby?;   build.include? "ruby";   end
def with_unicode_path?; build.include? "unicode-path"; end

class Subversion16 < Formula
  homepage 'http://subversion.apache.org/'
  url 'http://subversion.tigris.org/downloads/subversion-1.6.23.tar.bz2'
  sha1 '578c0ec69227db041e67ade40ac4cf2ebe2cf54a'

  option :universal
  option 'java', 'Build Java bindings'
  option 'perl', 'Build Perl bindings'
  option 'python', 'Build Python bindings'
  option 'ruby', 'Build Ruby bindings'
  option 'unicode-path', 'Include support for OS X UTF-8-MAC filename'

  resource 'serf' do
    url 'http://serf.googlecode.com/files/serf-1.3.2.tar.bz2'
    sha1 '90478cd60d4349c07326cb9c5b720438cf9a1b5d'
  end

  depends_on 'pkg-config' => :build

  # Always build against Homebrew versions instead of system versions for consistency.
  depends_on 'neon'
  depends_on 'sqlite'

  # Building Ruby bindings requires libtool
  depends_on :libtool if build_ruby?

  # For Serf
  depends_on 'scons' => :build
  depends_on 'openssl' if build.with? 'brewed-openssl'

  def patches
    ps = []

    # Patch for Subversion handling of OS X UTF-8-MAC filename.
    if with_unicode_path?
      ps << "https://raw.github.com/jiangxin/homebrew-tap/11c36125787fc8417df5c0459377aeb09952dd17/0003-patch-path.c.diff"
    end

    # Patch to find Java headers
    if build_java?
      ps << "https://raw.github.com/jiangxin/homebrew-tap/11c36125787fc8417df5c0459377aeb09952dd17/0002-swig-java.diff"
    end

    # Patch to prevent '-arch ppc' from being pulled in from Perl's $Config{ccflags}
    #if build_perl?
    #  ps << "https://raw.github.com/jiangxin/homebrew-tap/11c36125787fc8417df5c0459377aeb09952dd17/0001-swig-perl.diff"
    #end

    ps << "https://raw.github.com/jiangxin/homebrew-tap/da8df59cdb2eac3c211ae7a86429e84d318dc570/0004-hook-output-to-utf8-tolerant.diff"

    unless ps.empty?
      { :p1 => ps }
    end
  end

  # When building Perl, Python or Ruby bindings, need to use a compiler that
  # recognizes GCC-style switches, since that's what the system languages
  # were compiled against.
  fails_with :clang do
    build 318
    cause "core.c:1: error: bad value (native) for -march= switch"
  end if build_perl? or build_python? or build_ruby?

  def apr_bin
    Superenv.bin or "/usr/bin"
  end

  def install
    # We had weird issues with "make" apparently hanging on first run:
    # https://github.com/mxcl/homebrew/issues/13226
    ENV.deparallelize

    serf_prefix = libexec+'serf'

    resource('serf').stage do
      # SConstruct merges in gssapi linkflags using scons's MergeFlags,
      # but that discards duplicate values - including the duplicate
      # values we want, like multiple -arch values for a universal build.
      # Passing 0 as the `unique` kwarg turns this behaviour off.
      inreplace 'SConstruct', 'unique=1', 'unique=0'

      ENV.universal_binary if build.universal?
      # scons ignores our compiler and flags unless explicitly passed
      args = %W[PREFIX=#{serf_prefix} GSSAPI=/usr CC=#{ENV.cc}
                CFLAGS=#{ENV.cflags} LINKFLAGS=#{ENV.ldflags}]
      args << "OPENSSL=#{Formula.factory('openssl').opt_prefix}" if build.with? 'brewed-openssl'
      system "scons", *args
      system "scons install"
    end

    if build_java?
      unless build.universal?
        opoo "A non-Universal Java build was requested."
        puts "To use Java bindings with various Java IDEs, you might need a universal build:"
        puts "  brew install subversion --universal --java"
      end

      unless (ENV["JAVA_HOME"] or "").empty?
        opoo "JAVA_HOME is set. Try unsetting it if JNI headers cannot be found."
      end
    end

    ENV.universal_binary if build.universal?

    # Use existing system zlib
    # Use dep-provided other libraries
    # Don't mess with Apache modules (since we're not sudo)
    args = ["--disable-debug",
            "--prefix=#{prefix}",
            "--with-apr=#{apr_bin}",
            "--with-ssl",
            "--with-zlib=/usr",
            "--with-sqlite=#{Formula.factory('sqlite').opt_prefix}",
            "--with-serf=#{serf_prefix}",
            # use our neon, not OS X's
            "--disable-neon-version-check",
            "--disable-mod-activation",
            "--without-apache-libexecdir",
            "--without-berkeley-db"]

    args << "--enable-javahl" << "--without-jikes" if build_java?

    if build_ruby?
      args << "--with-ruby-sitedir=#{lib}/ruby"
      # Peg to system Ruby
      args << "RUBY=/usr/bin/ruby"
    end

    # The system Python is built with llvm-gcc, so we override this
    # variable to prevent failures due to incompatible CFLAGS
    ENV['ac_cv_python_compile'] = ENV.cc

    system "./configure", *args
    system "make"
    system "make install"
    (prefix+'etc/bash_completion.d').install 'tools/client-side/bash_completion' => 'subversion'

    system "make tools"
    system "make install-tools"

    if build_python?
      system "make swig-py"
      system "make install-swig-py"
    end

    if build_perl?
      # Remove hard-coded ppc target, add appropriate ones
      if build.universal?
        arches = "-arch x86_64 -arch i386"
      elsif MacOS.version == :leopard
        arches = "-arch i386"
      else
        arches = "-arch x86_64"
      end

      perl_core = Pathname.new(`perl -MConfig -e 'print $Config{archlib}'`)+'CORE'
      unless perl_core.exist?
        onoe "perl CORE directory does not exist in '#{perl_core}'"
      end

      inreplace "Makefile" do |s|
        s.change_make_var! "SWIG_PL_INCLUDES",
          "$(SWIG_INCLUDES) #{arches} -g -pipe -fno-common -DPERL_DARWIN -fno-strict-aliasing -I/usr/local/include -I#{perl_core}"
      end
      system "make swig-pl"
      system "make", "install-swig-pl", "DESTDIR=#{prefix}"
    end

    if build_java?
      system "make javahl"
      system "make install-javahl"
    end

    if build_ruby?
      # Peg to system Ruby
      system "make swig-rb EXTRA_SWIG_LDFLAGS=-L/usr/lib"
      system "make install-swig-rb"
    end
  end

  def caveats
    s = ""

    if build_python?
      s += <<-EOS.undent
        You may need to add the Python bindings to your PYTHONPATH from:
          #{HOMEBREW_PREFIX}/lib/svn-python

      EOS
    end

    if build_perl?
      s += <<-EOS.undent
        The perl bindings are located in various subdirectories of:
          #{prefix}/Library/Perl

      EOS
    end

    if build_ruby?
      s += <<-EOS.undent
        You may need to add the Ruby bindings to your RUBYLIB from:
          #{HOMEBREW_PREFIX}/lib/ruby

      EOS
    end

    if build_java?
      s += <<-EOS.undent
        You may need to link the Java bindings into the Java Extensions folder:
          sudo mkdir -p /Library/Java/Extensions
          sudo ln -s #{HOMEBREW_PREFIX}/lib/libsvnjavahl-1.dylib /Library/Java/Extensions/libsvnjavahl-1.dylib

      EOS
    end

    if with_unicode_path?
      s += <<-EOS.undent
        This unicode-path version implements a hack to deal with composed/decomposed
        unicode handling on Mac OS X which is different from linux and windows.
        It is an implementation of solution 1 from
        http://svn.collab.net/repos/svn/trunk/notes/unicode-composition-for-filenames
        which _WILL_ break some setups. Please be sure you understand what you
        are asking for when you install this version.

      EOS
    end

    return s.empty? ? nil : s
  end
end
