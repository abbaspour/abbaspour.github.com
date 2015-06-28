---
title: Setup Graphite in Mac OS X with Pkgin
tags: [graphite, mac-os-x, pkgin, pkgsrc, carbon, launchctl]
excerpt: "Graphite + Pkgsrc"
---

[Graphite](http://graphite.wikidot.com/) is cool and scalable. I always keep in running in the background and easily connect ad hoc system, application and DTrace reports.

### Install Python
Runtime platform
{% highlight bash %}
sudo pkgin in python2.7
sudo pkgin in py27-pip
sudo pkgin in py27-sqlite3
{% endhighlight %}

### Install Cairo
Graphic engine
{% highlight bash %}
sudo pkgin in cairo
sudo pkgin in py27-cairo
{% endhighlight %}

### Install Django
Web engine
{% highlight bash %}
sudo pip install Django==1.4.5
{% endhighlight %}

### Install Carbon, Whisper and Ceres
RRD Database engines and daemon
{% highlight bash %}
sudo pip install carbon
sudo pip install whisper
git clone https://github.com/graphite-project/ceres.git
cd ceres
sudo python setup.py install
{% endhighlight %}

### Install Graphite Web and Dependencies
Graphite-web itself is a routine Django web application.

{% highlight bash %}
git clone https://github.com/graphite-project/graphite-web.git
cd graphite-web
./check-dependencies.py
sudo pip install pytz
sudo easy_install-2.7 http://cheeseshop.python.org/packages/source/p/pyparsing/pyparsing-1.5.5.tar.gz
sudo python setup.py install
{% endhighlight %}

### Setup Web App
{% highlight bash %}
sudo chown -R amin:staff /opt/graphite
cd /opt/graphite/webapp/graphite
cp local_settings.py.example local_settings.py
cp /opt/graphite/conf/carbon.conf{.example,}
cp /opt/graphite/conf/storage-schemas.conf{.example,}
{% endhighlight %}

Change old fashion Django setting into 1.4 compatiable format:

{% highlight python %}
vi settings.py
##Initialize database settings - Old style (pre 1.2)
#DATABASE_ENGINE = 'django.db.backends.sqlite3'	# 'postgresql', 'mysql', 'sqlite3' or 'ado_mssql'.
#DATABASE_NAME = ''				# Or path to database file if using sqlite3.
#DATABASE_USER = ''				# Not used with sqlite3.
#DATABASE_PASSWORD = ''				# Not used with sqlite3.
#DATABASE_HOST = ''				# Set to empty string for localhost. Not used with sqlite3.
#DATABASE_PORT = ''				# Set to empty string for default. Not used with sqlite3.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(STORAGE_DIR, 'graphite.db'),
    },
}
{% endhighlight %}

### Startup

#### Carbon 
{% highlight bash %}

python /opt/graphite/bin/carbon-cache.py --debug start
{% endhighlight %}

#### Web Console
{% highlight bash %}
cd /opt/graphite/bin
python /opt/graphite/bin/run-graphite-devel-server.py /opt/graphite
{% endhighlight %}

Visit http://localhost:8080 for graphite web console.

### Sample Client
This is a sample client that sends system Load Average to Carbon:


{% highlight bash %}
cat uptime.sh
#!/bin/sh

while [ true ]; do
    uptime | awk '{print $(NF-2),$(NF-1),$NF}'
    sleep 1
done
{% endhighlight %}

And TCP/IP Perl client:

{% highlight perl %}
#!/usr/pkg/bin/perl
# graphite-asistant.pl idea from http://cuddletech.com/blog/?p=617

use IO::Socket;

## Default Values:
my $GRAPHITE_SERVER = "localhost";
my $GRAPHITE_PORT   = 2003;

my $HOSTNAME = `hostname`;
chomp($HOSTNAME);

## Prep the socket
my $sock = IO::Socket::INET->new(
    Proto    => 'tcp',
    PeerPort => $GRAPHITE_PORT,
    PeerAddr => $GRAPHITE_SERVER,
) or die "Could not create socket: $!\n";

while(<>) {
  chomp($_);
  $_ =~ s/^\s+//; # Trim any leading whitespace
  my ($la1m,$la5m,$la15m) = split(/\s+/, $_);

  ### Sanity check on the input data
  if ($OTHER) {
        print("I got some other crap here: $OTHER (Input: $_)\n");
        next;
  }

  $DATE = time();
  my $KEY_VALUE = "${HOSTNAME}.load_avg.1min $la1m $DATE\n";
  $KEY_VALUE .= "${HOSTNAME}.load_avg.5min $la5m $DATE\n";
  $KEY_VALUE .= "${HOSTNAME}.load_avg.15min $la15m $DATE\n";

  $sock->send("$KEY_VALUE") or die "Send error: $!\n";

}
{% endhighlight %}

Run via names piped or direct pipes:

{% highlight bash %}
./uptime.sh | ./graphite-asistant.pl
{% endhighlight %}

### Running Carbon as a Daemon
Sample Plist file ''/Library/LaunchDaemons/org.bitbucket.amin.carbon.plist''. Change UserName/GroupName accordingly. 

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
    	<string>org.bitbucket.amin.carbon</string>
	<key>ProgramArguments</key>
	<array>
		<string>/opt/graphite/bin/carbon-cache.py</string>
		<string>--debug</string>
		<string>start</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
    	<key>Debug</key>
    	<true/>
	<key>StartInterval</key>
	<integer>600</integer>
    	<key>StandardOutPath</key>
    	<string>/opt/graphite/log/launchctl-carbon.stdout</string>
    	<key>StandardErrorPath</key>
    	<string>/opt/graphite/log/launchctl-carbon.stderr</string>
	<key>UserName</key>
	<string>amin</string>
	<key>GroupName</key>
	<string>staff</string>
</dict>
</plist>
{% endhighlight %}

Load it:
{% highlight bash %}
mkdir /opt/graphite/log
sudo launchctl load -w /Library/LaunchDaemons/org.bitbucket.amin.carbon.plist
tail -f /opt/graphite/log/launchctl-carbon.std*
{% endhighlight %}

Render by accessing simple and elegent graphite REST API:

{% highlight text %}
http://127.0.0.1:8080/render/?&from=-1hours&target=*.local.load_avg.*&width=500&height=300
{% endhighlight %}

Results in:

   <img src="{{ site.url }}/assets/img/graphite/graphite-localhost-la.png" alt="load-avg-last-hour" class="postimg"/>


