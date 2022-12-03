This is my simple pinger script for notifying when a host becomes unreachable.

It uses SQLite to track fping results for throttling the sendmail and syslog events

## crontab
```
#icmp alert pinger
*/5 * * * *     ~/bin/fping-alert/pinger.tcl > /dev/null 2>&1
```
