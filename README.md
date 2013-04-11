jiangxin/homebrew-tap
=====================

Homebrew is a package manager for Mac OS X.

> Homebrew installs the stuff you need that Apple didn’t.

Homebrew always maintains the newest release of a package, and leave alone
other maintenance releases. One workaround is to create a new formula for
each maintenace release of every package. I use this repository to maintain
my favorite packages.

Install
-------

1. If you have already installed homebrew, goto step 2, or install
   homebrew from the following address:

   <http://brew.sh/>

2. Run the following command to install this tap:

        $ brew tap jiangxin/homebrew-tap

Build subversion
-----------------

This tap introduces 2 new formulae for brew.

* subversion16

  Which will install subversion 1.6.x maintenance release.

* subversion17

  Almost the same with brew builtin subversion formula, if upstream takes
  this pull request:
  
  - <https://github.com/mxcl/homebrew/pull/19100>

Step to install subversion16

1. Unlink already exist subversion links. Because these 3 formulae,
   subversion, subversion16 and subversion17 all have the same binaries,
   so before install we must unlink all possible links of these formulae.

        $ brew unlink subversion subversion16 subversion17

2. Show all intallation options before we start to install. e.g. subversion16

        $ brew options subversion16
        --java
                Build Java bindings
        --perl
                Build Perl bindings
        --python
                Build Python bindings
        --ruby
                Build Ruby bindings
        --unicode-path
                Include support for OS X UTF-8-MAC filename
        --universal
                Build a universal binary
        --without-tools
                Do not build svn tools

3. Start to install.

        $ brew install --verbose --java --perl --python --ruby subversion16

You may also install previous release of subversion16, if you homebrew have
this patch:

* <https://github.com/mxcl/homebrew/pull/19069>

Then you can do like that:

1. Show version of formula: subversion16.

        $ brew versions subversion16
        1.6.21   git checkout f8f9eb7 /usr/local/Library/Taps/jiangxin-tap/subversion16.rb
        1.6.20   git checkout 2fd7759 /usr/local/Library/Taps/jiangxin-tap/subversion16.rb
        1.6.19   git checkout ff097fb /usr/local/Library/Taps/jiangxin-tap/subversion16.rb
        1.6.18   git checkout f8704fe /usr/local/Library/Taps/jiangxin-tap/subversion16.rb
        1.6.17   git checkout 1607037 /usr/local/Library/Taps/jiangxin-tap/subversion16.rb
        1.6.16   git checkout 911a212 /usr/local/Library/Taps/jiangxin-tap/subversion16.rb

2. If you want to install subversion 1.6.16, then:

        $ cd /usr/local/Library/Taps/jiangxin-tap/
        $ git checkout 911a212 -- subversion16.rb
        $ brew unlink subversion subversion16 subversion17
        $ brew install --verbose --java --perl --python --ruby subversion16

Build git 
---------

Homebrew builtin git formula does not know how to compile with gettext,
so translations of Git can not be installed anyway. Until upstream takes
this hack:

* <https://github.com/mxcl/homebrew/pull/19097>

You can install like this:

    $ brew unlink git git18
    $ brew install --with-gettext git18
