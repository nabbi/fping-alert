#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

# https://github.com/nabbi/fping-alert

package require sqlite3
set debug 0
set trace 0

set path [file dirname [file normalize [info script]]]
if { [catch { source $path/config.tcl }] } {
    puts "config.tcl does not exist, please create it from config.tcl.example"
    exit 1
}

proc mymail {from to subject body} {
    set msg "From: $from"
    append msg \n "To: $to"
    append msg \n $subject
    append msg $body

    exec sendmail -oi -t -f $from << $msg
}


## check if database exists, create new if not
if { [file exists $database] } {
    sqlite3 db $database
} else {
    #create and populate
    sqlite3 db $database
    db eval {CREATE TABLE fping(time int, status text)}
}


## fping the node list, wrap around a catch for it will throw errors if unreachable or dns not resolved
catch {exec /usr/sbin/fping -r 5 {*}$nodes} cmd
set fping [split $cmd "\n"]

set now [clock seconds]

## check the fping output for alertable events
foreach line $fping {
    if { $trace } { puts "line: $line" }

    if { ([string match "*is unreachable" $line]) || ([string match "*Name or service not known" $line])  } {
        if { [db exists {SELECT 1 FROM fping WHERE status=:line ORDER BY time DESC}] } {
            set time [db eval {SELECT time FROM fping WHERE status=:line ORDER BY time DESC}]
            
            if { [expr {$now-$time}]  > 3600 } {
                ## alert - aged out
                db eval {UPDATE fping SET time=:now WHERE status=:line}
                exec logger -t pinger -p info $line
                lappend down $line
            }

        } else {
            ## alert - new
            db eval {INSERT INTO fping VALUES(:now,:line)}
            exec logger -t pinger -p info $line
            lappend down $line

        }
    }
}

db close

if { [info exists down] } {

    # email body
    append email \n\n "[info hostname] detected issues with these nodes:\n"
    append sms "\n"
    foreach d $down {
        puts "$d"
        append email "\t$d\n"
        append sms "[lindex $d 0]\n"
    }

    # subject
    if { [llength $down] > 1 } {
        set subject "multiple nodes are unreachable - $site"
    } else {
        set subject "node unreachable - $site"
    }

    ## call the mail processor
    if { [info exists to_email] } {
        mymail $from_email $to_email "Subject: $subject" $email
    }

    if { [info exists to_sms] } {
        mymail $from_email $to_sms $subject $sms
    }

    exit 2
}

exit 0
