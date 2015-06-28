---
title: RedHat Enterprise Packages in a Local VM
tags: [yum, rhui, socat, ssl, https, tunnel]
---

We have couple of paid RedHat instances in the cloud and they use RHUI infrastructure 
to host a copy of the RHEL repositories in the provider cloud.

For some reason I wanted a local VM (in my VMWare Fusion) to be running they same RedHat instance 
but I had difficulty using the repository. so had to some trick to get in working:

So this is the setup. We want to know what's an application that only accepts secure connection doing:

## Setup Tunnel ##
Run a tunnel from my local box to cloud provider:

{% highlight bash %}
ssh -L 0.0.0.0:1443:rhua-rcd.some.cloud.provider.com:443 mybox.in.the.cloud
sudo socat  tcp-listen:443,reuseaddr,fork,keepalive tcp:localhost:1443
{% endhighlight %}

## Change Hosts File in VM instance ##
Inside VMWare Fusion instance of the Redhat VM:

/etc/hosts

{% highlight text %}
 192.168.126.1  rhua-rcd.some.cloud.provider.com
{% endhighlight %}

## Disable sslverify check for YUM Repository ##

{% highlight bash %}
vi /etc/yum.conf.d/rh-cloud.repo
{% endhighlight %}

changed all **sslverify** from 1 to 0

