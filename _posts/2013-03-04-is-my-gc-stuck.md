---
title: Is My Garbage Collector Stuck?
tags: [prstat, java, gc, solaris, pstack]
---
Not all Java systems are lucky enough to enjoy Java6. We still run heaps of systems on Java5.

Not sure if it's an application or JDK issue but every now and then experience GC issues in Java5 on SPARC T2.

Running CMS GC the overall LA creeps up slowly and if we don't force a full-gc, it eventually kills the system.

I think it's something to do with CMS GC. Usually a full GC signal cleans up all garbage out of heap and
things go back to normal.

{% highlight bash %}
$ prstat 
   PID USERNAME  SIZE   RSS STATE  PRI NICE      TIME  CPU PROCESS/LWPID      
 26330 webservd 1575M 1209M cpu23    0    0 300:37:03 1.8% java/8
  4437 webservd 1636M 1162M sleep   59    0 166:41:05 1.1% java/305

$ prstat -Lm
   PID USERNAME USR SYS TRP TFL DFL LCK SLP LAT VCX ICX SCL SIG PROCESS/LWPID 
 26330 webservd  81 0.0 0.0 0.0 0.0  16 0.0 2.5  12 126  18   0 java/8
{% endhighlight %}

It's always thread 8, running parallel mark-swap GC:

{% highlight bash %}
$ pstack 26330/8
26330:	/usr/jdk/instances/jdk1.5.0/bin/java -Dcom.sun.aas.instanceRoot=/var/o
-----------------  lwp# 8 / thread# 8  --------------------
 fec5174c __1cRPushOrMarkClosureGdo_oop6MppnHoopDesc__v_ (a84ff9b4, c4a76528, c4a76568, fec5510c, d82a08f8, bc00) + c
 feea2700 __1cNobjArrayKlassRoop_oop_iterate_v6MpnHoopDesc_pnKOopClosure__i_ (e, c4a76528, a84ff9b4, fec51740, e, c4a7654c) + c0
 fec514b8 __1cUMarkFromRootsClosureNscanOopsInOop6MpnIHeapWord__v_ (a84ffb30, 0, ff065798, ff06579c, ff068e4c, 0) + 17c
 fec08c04 __1cGBitMapHiterate6MpnNBitMapClosure_II_v_ (e000000, 5d6823a, 2eb411, a84ffb30, cd2c0, 700000) + 80
 fec4a86c __1cMCMSCollectorRmarkFromRootsWork6Mi_i_ (cd248, 0, a84ffb30, 1, cd270, cd27c) + 168
 fec4a5ac __1cMCMSCollectorNmarkFromRoots6Mi_i_ (1, 97bc, cd248, fef8e07d, 9400, cd2c8) + 134
 fec47da0 __1cMCMSCollectorVcollect_in_background6Mi_v_ (1, cd248, 10, b7bc8, 4, 4) + 2d0
 fec55848 __1cZConcurrentMarkSweepThreadDrun6M_v_ (0, 7d0, ff068b90, a9848, 1, ff073bec) + 4fc
 feeab648 __1cG_start6Fpv_0_ (a9848, 66da, ff01c000, 0, 7530, 7400) + 208
 ff2c57f8 _lwp_start (0, 0, 0, 0, 0, 0)
{% endhighlight %}


Solution! while LA is high, try this:
{% highlight bash %}
$ kill -SIGQUIT <PID>
$ w -u
{% endhighlight %}

