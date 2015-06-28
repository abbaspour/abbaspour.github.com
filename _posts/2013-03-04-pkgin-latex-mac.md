---
title: LaTeX in Mac OS X
tags: [mac-os-x, latex, pkgin]
---
A lot of my docs are in LaTeX format. Here are two ways to install a minimal TeX:

## tlmgr
- install [BasicTeX](http://mirror.ctan.org/systems/mac/mactex/mactex-basic.pkg)
- use the tlmgr to install TexLive packages

{% highlight bash %}
$ tlmgr install collection-fontsrecommended
{% endhighlight %}

## pkgin
- install [pkgin](http://amin.bitbucket.org/posts/pkgsrc-in-mac-os-x.html)
- use pkgin to install LaTeX and its packages
{% highlight bash %}
$ pkgin in tex-latex-bin-2010 tex-psnfss-9.2anb4 tex-a4wide-2010nb1
{% endhighlight %}


