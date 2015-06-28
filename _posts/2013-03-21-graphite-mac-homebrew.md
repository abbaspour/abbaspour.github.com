---
title: Setup Graphite in Mac OS X with Homebrew
tags: [graphite, mac-os-x, pkgin, pkgsrc, carbon, launchctl]
excerpt: "Setup Graphite in Mac OS X with Homebrew"
---

My [last post](http://amin.bitbucket.org/posts/graphite-mac-pkgin.html) 
explained how to setup graphite with pkgin package manager. This is similar steps with homebrew package manager.

### Install homebrew
package manager
{% highlight bash %}
ruby -e "$(curl -fsSkL raw.github.com/mxcl/homebrew/go)"
sudo chown -R $(whoami) /usr/local
brew doctor
brew --config 
{% endhighlight %}

Ensure the XCode and CLI version are almost the same. i.e. not XCode 4.6 and CLI 4.5. Upgrade if necessary.
Open the default paths config (/etc/paths) and place /usr/local/bin and /usr/local/sbin in the top

{% highlight bash %}
sudo vim /etc/paths
{% endhighlight %}


### Install Python
Runtime platform
{% highlight bash %}
brew install python --framework

cd /System/Library/Frameworks/Python.framework/Versions
sudo rm Current
sudo ln -s /usr/local/Cellar/python/2.7.3/Frameworks/Python.framework/Versions/Current

mkdir ~/Applications
brew linkapps

pip install --upgrade distribute
pip install --upgrade pip
pip install ipython
pip install virtualenv
{% endhighlight %}

### Install Cairo
Graphic engine
{% highlight bash %}
brew install cairo # depends on glib 
brew install py2cairo
{% endhighlight %}

### Install Django
Web engine
{% highlight bash %}
pip install Django==1.4.5
{% endhighlight %}

### Install Carbon, Whisper and Ceres
RRD Database engines and daemon


PIP version:
{% highlight bash %}
pip install carbon # depends on zope.interface, twisted, txamqp 
pip install whisper
{% endhighlight %}


Ceres not in pypy yet
{% highlight bash %}
git clone https://github.com/graphite-project/ceres.git
cd ceres
python setup.py install
{% endhighlight %}

Alternatively, checkout the code and build whisper and carbon

{% highlight bash %}
mkdir ~/build
cd ~/build
mkdir graphite-project
cd graphite-project
{% endhighlight %}

Now checkout to all components and install. The install <em>prefix</em> folder is in <em>setup.cfg</em> 
which is <em>/opt/graphite</em> by default. You may change it or alternatively change <em>PYTHON_PATH</em> to include
new library folders or even copy them across once installed.

{% highlight bash %}
git clone https://github.com/graphite-project/carbon.git
cd carbon
python setup.py install # setup.cfg prefix is /opt/graphite, we copy to local
cp -r /opt/graphite/lib/carbon* /usr/local/lib/python2.7/site-packages/
cp  /opt/graphite/lib/twisted/plugins/* \
    /usr/local/lib/python2.7/site-packages/twisted/plugins
mkdir /usr/local/share/conf
cp /opt/graphite/conf/carbon.conf.example \
   /usr/local/share/conf/carbon.conf
cp /opt/graphite/conf/storage-schemas.conf.example \
   /usr/local/share/conf/storage-schemas.conf
cp /opt/graphite/conf/storage-aggregation.conf.example \
   /usr/local/share/conf/storage-schemas.conf
vi /usr/local/share/conf/carbon.conf # set STORAGE_DIR to /opt/graphite/storage
{% endhighlight %}


### Install Graphite Web and Dependencies
Graphite-web itself is a routine Django web application.

{% highlight bash %}
cd ~/build/graphite-project
git clone https://github.com/graphite-project/graphite-web.git
cd graphite-web
./check-dependencies.py
pip install pytz
pip install django-tagging
pip install pyparsing==1.5.5
python setup.py install
{% endhighlight %}

### Setup Web App
Change old fashion Django setting into 1.4 compatible format:

{% highlight python %}
vi settings.py
##Initialize database settings - Old style (pre 1.2)
#DATABASE_ENGINE = 'django.db.backends.sqlite3'	
#DATABASE_NAME = ''		# Or path to database file if using sqlite3.
#DATABASE_USER = ''		# Not used with sqlite3.
#DATABASE_PASSWORD = '' # Not used with sqlite3.
#DATABASE_HOST = ''		# Set to empty string for localhost. Not used with sqlite3.
#DATABASE_PORT = ''		# Set to empty string for default. Not used with sqlite3.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(STORAGE_DIR, 'graphite.db'),
    },
}
{% endhighlight %}

{% highlight python %}
#if 'sqlite3' in DATABASE_ENGINE \
#    and not DATABASE_NAME:
#  DATABASE_NAME = join(STORAGE_DIR, 'graphite.db')
{% endhighlight %}

### Startup

#### Carbon 
{% highlight bash %}
/usr/local/share/python/carbon-cache.py --debug start
{% endhighlight %}

#### Web Console
{% highlight bash %}
/usr/local/share/python/run-graphite-devel-server.py /opt/graphite
{% endhighlight %}

Visit <em>http://localhost:8080</em> for graphite web console. Ensure both graphite-web (local_settings.py) and carbon (carbon.conf) point to 
same storage folder.

### Sample Client
This is a sample client that sends system Load Average to Carbon. I made awk script portable:


{% highlight bash %}
cat uptime.sh
#!/bin/sh

while [ true ]; do
    uptime | awk 'BEGIN{OFS=" ";FS="[,:]"}{print $(NF-2),$(NF-1),$NF}'
    sleep 1
done
{% endhighlight %}

For a TCP/IP Perl client (./graphite-asistant.pl) check previous post.

{% highlight bash %}
./uptime.sh | ./graphite-asistant.pl
{% endhighlight %}

### Running Carbon as a Daemon
Change UserName/GroupName accordingly. 

{% highlight bash %}
vim /Library/LaunchDaemons/org.bitbucket.amin.carbon.plist
{% endhighlight %}

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
		<string>/usr/local/share/python/carbon-cache.py</string>
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

### Running Graphite Web as a Daemon
{% highlight bash %}
pip install gunicorn
vim ~/Library/LaunchAgents/org.bitbucket.amin.gunicorn.graphite.plist
{% endhighlight %}

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>org.bitbucket.amin.gunicorn.graphite.plist</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>UserName</key>
    <string>amin</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/share/python/gunicorn_django</string>
        <string>-w 1</string>
        <string>-b 0.0.0.0:8000</string>
        <string>/opt/graphite/webapp/graphite</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/usr/local</string>
  </dict>
</plist>
{% endhighlight %}

Render by accessing simple and elegent graphite REST API:

{% highlight text %}
http://127.0.0.1:8000/render/?&from=-1h&target=*.local.load_avg.*&width=500&height=300
{% endhighlight %}

Results:

![Graphite Load Average](/assets/img/graphite/graphite-localhost-la.png){: .aligncenter}


