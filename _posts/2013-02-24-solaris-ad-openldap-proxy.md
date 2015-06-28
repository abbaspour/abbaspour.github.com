---
title: Active Directory to Solaris via OpenLDAP Proxy
tags: [solaris, active-directory, ldap, openldap, pam, nss, ldapclient]
---

Like many others, here in Telstra we have an organization wide Active Directory. It's designed for Windows workstations, 
as a result a handful of POSIX attributes are missing for most of users. Besides there is no direct connectivity from UAT and production environments to AD servers.

What I did was to setup a replicated OpenLDAP servers and proxy/rwm user/groups DIT from Solaris client to 
AD. Then add my own set of attributes for netgroups and Solaris RBAC. 

The thing about Solaris native [ldapclient(1M)](http://docs.oracle.com/cd/E19963-01/html/821-1462/ldapclient-1m.html)
and LDAP NSS/PAM module is its limited configuration set. They are designed for
environment where LDAP server has all POSIX attributes. Well, that's not always the case.

I tested couple of other approaches but finally stayed with OpenLDAP [slapo-rwm](http://linux.die.net/man/5/slapo-rwm) and ldapclient(1M). 


# Design

## Deployment Model

   <img src="{{ site.url }}/assets/img/ldap/central-auth-logical-diagram.png" alt="central auth logical diagram" class="postimg"/>

## Tree Structure
{% highlight text %}
 |
 ou=eProfile,DC=core,DC=dir,DC=company,DC=com (Root)
 |
 |- ou=People,ou=eProfile,.... (subordinare)
 |   |
 |   \- (proxied users)
 |
 |- ou=Groups,ou=eProfile,.... (subordinare)
 |   |
 |   \- (proxied groups)
 |
 \- ou=Netgroup,ou=eProfile,... 
     |
     \- (local HDB, replicated)

{% endhighlight %}

# Server Side

## OpenLDAP Schema
For my OpenLDAP boxes, I first had to make minor modifications to schemas and put it under <em>schema/</em> folder.

### Active Directory Schema
Added a minimalistic <em>ad.schema</em> and included it in my <em>slapd.conf</em>

{% highlight bash %}
$ cat ad.schema
{% include ldap/ad.schema %}
{% endhighlight %}

### NIS Schema
Modified <em>nis.schema</em> so I can modify single entries of <em>nisNetgroupTriple</em> in each Netgroup and not as a whole.
Also alias unixHomeDirectory (from AD) to NIS homeDirectory.
{% highlight bash %}
$ cat nis_schema.sed
{% include ldap/nis_schema.sed %}
{% endhighlight %}

To make the change:
{% highlight console %}
sed -i -f nis_schema.sed nis.schema
{% endhighlight %}

### Solaris Schema
Added a minimalistic [solaris.schema]({{ site.url }}/assets/img/ldap/solaris.schema) and included it in my slapd.conf

## rwm Overlay
[slapo-rwm]() is good and it helps shifting of attribute mapping from NIS profile/ldapclient to a central locaion in the servers and it 
works great with ldap backend but it's not that helpfull to create dynamic/virtual attributes.
I wanted to create virutal attributes such as <em>auto_mount</em>, <em>loginShell</em> and <em>homeDirectory</em> but rwm can only do mapping.
To overcome this, I override them in <em>/etc/passwd</em>. We'll get to that later. Here is <em>slapd.conf</em>. Slaves have syncrepl enabled
and master has overlay syncprov.

{% highlight text %}
{% include ldap/slapd-rwm.conf %}
{% endhighlight %}

## Testing Setup
Before looking at client side, let's test our server side proxy configuration:

### Testing LDAP(S) to Backend AD Servers
{% highlight bash %}
$ ldapsearch -h ldapnsw1.core.dir.company.com -p 389 \
           -b ou=People,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -D CN=aduser,CN=Users,DC=core,DC=dir,DC=company,DC=com \
           -w ***** -s sub -z 1 -LLL cn=amin

$ cat /etc/openldap/ldap.conf
TLS_REQCERT never
TLS_CACERT  /etc/openldap/proxy/company/Company-Test-Root-CA.cer # x509

$ ldapsearch -H ldaps://ldapnsw1.core.dir.company.com:636 \
           -b ou=People,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -D CN=aduser,CN=Users,DC=core,DC=dir,DC=company,DC=com \
           -w ***** -s sub -z 1 -LLL cn=amin
{% endhighlight %}

### Testing from Proxy
Same as above but replace address. You should see mapped attributes.

### Testing from Solaris Client
For Solaris 10, need to convert x509 certificates into cert7 database formats. 
[ldapsearch(1)](http://docs.oracle.com/cd/E23823_01/html/816-5165/ldapsearch-1.html) works with cer8 but ldapclient cache-manager still requires Solaris 9 
cert7 format.

#### Creating Cert DB in Solaris
{% highlight bash %}
$ certutil -A -d /var/ldap -t CT,, -n TLS_CA -i cacert.pem
$ certutil -A -d /var/ldap -t CT,, -n TLS_CERT -i cert.pem
{% endhighlight %}

#### Searching Proxy

{% highlight bash %}
$ ldapsearch -h ldapnsw1.core.dir.company.com -p 389 \
           -b ou=People,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -D uid=user,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -w ***** -s sub -z 1 -LLL cn=amin

$ ldapsearch -h ldapnsw1.core.dir.company.com -p 636 \
           -b ou=People,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -D uid=user,ou=eProfile,DC=core,DC=dir,DC=company,DC=com \
           -w ***** -s sub -z 1 -LLL -Z -P /var/ldap cn=amin
{% endhighlight %}

# Client Side

## What's NSS and PAM?
So we have two concepts. First need to find/resolve entries (NSS) and then describe how user entries (i.e. users) authenticate (PAM).
We can skip both or have one and the other. For example you can have your users/groups created locally (in /etc/passwd) but still
use LDAP PAM to authenticate them against their password stored in LDAP. 
Here we setup both, meaning that neither of user/group/netgroup entries are defined locally and are both fetched from LDAP (NSS)
and authenticated against it (PAM) as well.
The libraries that provide NSS and PAM sit of different folders. 
NSS libraries are normally here:

{% highlight bash %}
$ ls /usr/lib/nss_*
{% endhighlight %}

And PAM libraries are here:

{% highlight bash %}
$ ls /usr/security/lib/pam_*
{% endhighlight %}

It's normal to have helper services in the background to speed up looking up entries from remote data-sources such as ldap.
For exmaple Solaris native ldapclient(1M) that supports both NSS abd PAM, starts up <em>network/client/ldap</em> service
that has a live connection to LDAP all the time.

{% highlight bash %}
$ svcs -a | grep ldap
{% endhighlight %}

In a vanilla Solaris, these packages are provided by <em>SUNWcsl</em> package:

{% highlight bash %}
$ pkgchk -lp /usr/lib/nss_ldap.so.1
$ pkgchk -lp /usr/security/lib/pam_ldap.so.1
{% endhighlight %}

## Joining LDAP
ldapclient(1M) is quite handy. Other than starting up <em>ldap/client</em> service, it restarts other related
services such as nscd.

ldapclient init can be manual If you've done attribute mapping correctly, there is no much need attributeMap mappings, but they are always there to help.

{% highlight bash %}
{% include ldap/client.sh %}
{% endhighlight %}
or via a pre-defined DUAConfigProfile Profile. 

{% highlight bash %}
{% include ldap/client-profile.sh %}
{% endhighlight %}

To Profile mode, need a profile added to local proxy DB:

{% highlight text %}
{% include ldap/profiles.ldif %}
{% endhighlight %}

## Configuration

### NSS 
Before switching to full PAM via LDAP, first test NSS.
Simply add ldap to reqired entries to <em>/etc/nsswitch.conf</em>

{% highlight text %}
passwd:   files ldap
group:    files ldap
netgroup: ldap
{% endhighlight %}
#### Debugging NSS
Set <em>debug_eng_loop</em> variable to see how NSS works:

{% highlight bash %}
$ export NSS_OPTIONS='debug_eng_loop=2'
$ touch /etc/nsswitch.conf
$ getent passwd <uid>
$ getent group <gid>
{% endhighlight %}

In Solaris 10 global zones export is enough. In local zones, you have to touch <em>/etc/nsswitch</em> to get it working!

To query the LDAP like the NSS modole, use the <em>ldaplist</em> command:
{% highlight bash %}
$ ldaplist -l 
$ ldaplist -l passwd <uid> 
{% endhighlight %}

### PAM
If all user details are correct (uid, uidNumber, gidNumber), it's time to test PAM.
This is a sed script to modify pam.conf. The idea is add pam_ldap to auth:

{% highlight bash %}
{% include ldap/pam.sed %}
{% endhighlight %}

To apply it:
{% highlight bash %}
$ sed -f pam.sed < /etc/pam.conf.files > /etc/pam.conf
{% endhighlight %}

#### Debugging PAM
PAM/NSS modules can use syslog for debug details. If want to debug all PAM (recommanded) create an empty <em>/etc/pam_debug</em>
file. To debug only a subset, simply add debug to each PAM line in <em>/etc/pam.conf</em>

Configure [syslog.conf(4)](http://docs.oracle.com/cd/E19963-01/html/821-1473/syslog.conf-4.html) 
to send debug messages to a file such as <em>/var/log/debug.log</em>.

{% highlight bash %}
$ echo "*.debug             /var/log/debug.log" >> /etc/syslog.conf
$ svcadm restart system-log
$ touch /etc/pam_debug
$ tail -f /var/log/debug.log
{% endhighlight %}

That might be a little bit tricky. Use tabs in [syslog.conf(4)](http://docs.oracle.com/cd/E19963-01/html/821-1473/syslog.conf-4.html) 
and check SMF logs (/var/svc/log) to ensure syslog is able to parse its config file.
Now try to ssh to the box. Hopefully everything will work fine and can login to the system. Keep <em>nscd</em> running for better performance. 

### Netgroup
To limit users to particular netgroups, add them to <em>/etc/passwd</em> file.

{% highlight bash %}
$ echo +@netgroup_name >> /etc/passwd
$ pwconv
{% endhighlight %}

And update <em>/etc/nsswitch.conf</em> to accept compat (-/+) mode as well:

{% highlight text %}
$ grep compat /etc/nsswitch.conf
passwd: compat
passwd_compat: files ldap
{% endhighlight %}

### Custom homeDirectory and loginShell
Entries in <em>/etc/passwd</em> can override the attribues from NIS, LDAP.
you may want to assign a default home or shell to a netgroup or single user.

{% highlight text %}
+amin:x::::/data/home/amin:/usr/bin/zsh
+@oes_l4:x:::::/bin/bash
{% endhighlight %}

# Handy Scripts

## Nergroup admin
{% highlight bash %}
$ cat netgrpadm
{% include ldap/netgrpadm %}
{% endhighlight %}

## User admin
{% highlight bash %}
$ cat useradm
{% include ldap/useradm %}
{% endhighlight %}


# Other Approached

## translucent overlay
The first thing I did was to setup a translucent proxy so that I can add missing POSIX attributes to the entities.
While is the natural choice, I soon realized that slapo-translucent lacks stability at 2.4.33.

OpenLDAP crashed several time running translucent with rwm/syncrepl and decided to skip it for and look at other
candidates. One of my goals was to minimise the amount of local data I keep and pass through request to
upstream AD as much as possible. By skipping translucent, I only keep netgroup details locally which is the minimum 
possible.

This is a possible setup if translucent was stable:
{% highlight text %}
{% include ldap/slapd-translucent.conf %}
{% endhighlight %}

### PADL nss_ldap and pam_ldap
[PADL](http://www.padl.com/) has done a nice job of more configurable [NSS](https://github.com/PADL/nss_ldap) and 
[PAM](https://github.com/PADL/pam_ldap) modules. And they work with OpenSSL x509 formats as well. But if you wanna use it, also have a look at nss-pam-ldapd.

### nss-pam-ldapd
Arthur de Jong [nss-pam-ldapd](http://arthurdejong.org/nss-pam-ldapd/) is a [fork](https://github.com/arthurdejong/nss-pam-ldapd/) 
of PADL nss_ldap with even more configuration options and a backgroup nslcd process.

Almost straightforward build under Solaris (except for ldaps support). 

To run it smothly in Solaris under a contract, I created these SVC SMF files as well:
#### nslcd SMF Manifest
{% highlight bash %}
$ cat nslcd.xml
$ svccfg import nslcd.xml
{% endhighlight %}

{% highlight xml %}
{% include ldap/nslcd.xml %}
{% endhighlight %}

#### nslcd SMF Method
{% highlight bash %}
$ cat /lib/svc/method/nslcd-method
{% include ldap/nslcd-method %}
{% endhighlight %}

### nssov Overlay
It [exists](http://www.openldap.org/devel/cvsweb.cgi/contrib/slapd-modules/nssov/) as a contrib overlay for OpenLDAP but I haven't look at it.

# Useful Links
* [OpenLDAP Pass Through to Active Directory](http://doc36.controltier.org/wiki/User:Juddmaltin/OpenLDAP_Pass_Through_to_Active_Directory)
* [OpenLDAP Password Protection, security and Authentication](http://www.yolinux.com/TUTORIALS/LinuxTutorialLDAP-BindPW.html)
* [LDAP Client setup](http://www.datadisk.co.uk/html_docs/ldap/ldap_client_setup.htm)
* [How to configure Solaris to Authentication against a Sun Java System Access Manager LDAP Server](http://jeffnester.com/howtos/solaris/howToSolarisLDAPAuth.html)

