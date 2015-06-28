---
title: Building pkgsrc in Mac OS X
tags: [pkgsrc, mac-os-x, pkgin]
---
<!--
I'm a big fan of [pkgsrc](http://www.pkgsrc.org/)/[pkgin](http://pkgin.net/). It creates a portable packaging for heaps of operating systems.
In Mac OS X, I personally prefer it to [homebrew](http://mxcl.github.com/homebrew/) and [MacPorts](http://www.macports.org/).
-->

If you want to install binary packages, [Jonathan Perkin's page](http://www.perkin.org.uk/posts/7000-packages-for-osx-lion.html) 
is the best guide around and works perfect. Thanks Jonathan.

But sometimes need to build from the source. Here is how I do it:

## Build a disk for pkgsrc
{% highlight bash %}
$ sudo hdiutil create -fs "Case-sensitive HFS+" -volname pkgsrc -type SPARSE \
                      -stretch 4g -size 3g /usr/pkgsrc
$ sudo hdiutil attach -readwrite /usr/pkgsrc.sparseimage
$ ls /Volumes/pkgsrc
$ cd /Volumes/pkgsrc
$ mkdir pkg pkgsrc
{% endhighlight %}

## Checkout pkgsrc

### CVS
Choose a geographically close repo.
{% highlight bash %}
$ cd /Volumes/pkgsrc
$ export CVS_RSH=ssh
$ export CVSROOT=anoncvs@anoncvs3.de.netbsd.org:/cvsroot
$ cvs co -PA pkgsrc
{% endhighlight %}

### Git
Automatically updated conversion of the "pkgsrc" module from anoncvs.netbsd.org 
{% highlight bash %}
$ cd /Volumes/pkgsrc
$ git clone https://github.com/jsonn/pkgsrc.git
{% endhighlight %}


## XCode Command Line Tools
Install [Command Line Tools for XCode](https://developer.apple.com/downloads/index.action).

## Build it

### Bootstrap
Don't use bmake from binary packages. If doing so, will get this error message:

{% highlight bash %}
amin@Amins-MacBook-Air:/Volumes/pkgsrc/pkgsrc/databases/openldap-doc$ bmake
bmake:Unclosed variable specification (expecting '}') for "" (value "") modifier U
bmake:"../mk/../mk/bsd.prefs.mk" line 53:warning:Missing closing parenthesis for exists()
bmake:"../mk/../mk/bsd.prefs.mk" line 53:Malformed conditional (exists(${:U)
{% endhighlight %}


Instead build the bootstrap package first. use <em>clang</em> compiler and ABI 64. 
Also use <em>/Volumes/pkgsrc</em> prefix to prevent conflict/overlapping with binary pkgin packages.

{% highlight bash %}
$ cd /Volumes/pkgsrc/pkgsrc/bootstrap
$ ./bootstrap --prefix=/Volumes/pkgsrc/pkg --pkgdbdir=/Volumes/pkgsrc/pkg/db \
              --abi=64 --compiler=clang
{% endhighlight %}

I found this <em>compile.csh</em> script [on the web](http://comments.gmane.org/gmane.os.netbsd.devel.pkgsrc.user/15022) 
that includes all you need for an optimal successfull bootstrap in Mac OS X.

{% highlight bash %}
$ cat compile.csh
{% include pkgsrc/compile.csh %}
{% endhighlight %}


### Packaging
Once the bootstrap is in place, use its <em>bmake</em> to build rest of packages.
{% highlight bash %}
$ cd /Volumes/pkgsrc/pkgsrc/databases/openldap-server
$ ../../bootstrap/work/bin/bmake install
{% endhighlight %}
