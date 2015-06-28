---
title: Using stunnel/socat to Easily Monitor HTTPS/SSL
tags: [tcpmon, stunnel, socat, ssl, https, tunnel]
---

So this is the setup. We want to know what's an application that only accepts secure connection doing:


<img src="{{ site.url }}/assets/img/stunnel/stunnel.png" alt="Tunnel Setup" class="postimg"/>

So first create a fake certificate and install in into the system:

{% highlight bash %}
openssl req -new -x509 -days 365 -nodes -out st.pem -keyout st.pem
{% endhighlight %} 

This is the config of client stunnel (_client.conf_):

{% highlight bash %}
{% include stunnel/client.conf %}
{% endhighlight %} 

then run it:

{% highlight bash %}
stunnel client.conf
{% endhighlight %} 

And second stunnel (listener.conf) is as follows:

{% highlight bash %}
{% include stunnel/listener.conf %}
{% endhighlight %} 

then run it:

{% highlight bash %}
stunnel listener.conf
{% endhighlight %} 

So in between listener and client stunnel instances, we run socat to monitor the traffic:

{% highlight bash %}
socat -v tcp-listen:1080,reuseaddr,fork,keepalive tcp:localhost:1081
{% endhighlight %} 

That's it folks. try accessing localhost:1443 over HTTPS and you can see the plain traffic in the socat terminal.

{% highlight bash %}
wget -O - --no-check-certificate https://localhost:1443/
{% endhighlight %} 

### Notes ###

Q1: where to get stunnel for OS X? don't brew it. try [prebuilt packages](http://rudix.org/packages/stunnel.html). 

Q2: but I get '''HTTP 404''' all the time? try adding hostname to /etc/hosts. Server name in HTTP header should match

{% highlight bash %}
echo "127.0.0.1 www.twitter.com" >> /etc/hosts
echo "127.0.0.1 www.google.com.au" >> /etc/hosts
{% endhighlight %} 

PS. similar work done [here in ruby](https://www.fishnetsecurity.com/6labs/blog/ssl-relay-proxy-creative-solution-complex-issue) 
and [here in python](https://github.com/iSECPartners/tcpprox).
