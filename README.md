This is my simple pinger script for notifying when a host becomes unreachable.

It uses SQLite to track fping results for throttling the sendmail and syslog events

## crontab
```
*/5 * * * *     ~/bin/pinger.tcl
```
