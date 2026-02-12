#!/bin/bash

#
# When the BMC is reset the watchdog device use state is changed from "SMS/OS" to "reserved".
# This script is to check the timer use state and restart the watchdog service.
#

#variables
Date=$(/usr/bin/date)
log_file=/var/crash/watchdog_repair.log
KEYWORD="AMD-Vi: Completion-Wait loop timed out" 


#Functions Date, get_use, func_test, func_repair
function func_Date {
    Date=$(date +"%Y-%m-%d %r")
}

function get_use {
    use=$(timeout 2 ipmitool mc watchdog get | head -1 | sed -e 's/\:     /:/' -e 's/ /:/g'| cut -d : -f4)
    return $?
}

function check_dmesg {
    if dmesg | grep -q "$KEYWORD"; then
	 return 0
    else 
	 return 1
    fi
}

function func_test {
    #Check dmesg for AMD-vi issue
    check_dmesg
    dmesg_status=$?
    if [ $dmesg_status -eq 0 ]; then
	func_Date
	echo "${Date} : test-repair script : test : DMESG Contains '$KEYWORD'" >> ${log_file}
	exit 20
    fi

    get_use
    tool_status=$?

    if [ $tool_status -ne 0 ]; then
        func_Date
        echo "${Date} | test-repair script : test | Timer device is not accessable | ipmitool exitcode : $tool_status" >> ${log_file}
        exit 0   
    fi

    if [ "${use}" == "Reserved" ] && [ $tool_status -eq 0 ] ; then 
	func_Date
        echo "${Date} : test-repair script : test : Watchdog Timer Use : $use" >> ${log_file}
        exit 10
    fi    


    exit 0
}

function func_repair {
    if [ $1 -eq 20 ]; then
	func_Date
   	logger -p user.err -t "AMD-Vi: Completion-Wait loop" "The server was rebooted by watchdog"
	sync
	sleep 0.5
	echo c > /proc/sysrq-trigger
    fi

    get_use

    if [ "${use}" == "Reserved" ] && [ $1 -eq 10 ] ; then 
       func_Date
       echo "${Date} : test-repair script : repair : Watchdog Timer Use: $use" >> ${log_file}
       echo "${Date} : test-repair script : repair : update the timeout value of ipmi_watchdog module"  >> ${log_file}
       echo 60 >  /sys/module/ipmi_watchdog/parameters/timeout
       echo "$(date; systemctl status watchdog; ipmitool mc watchdog get )" >> ${log_file}
       echo "---------------------------------------------------------------------------------" >> ${log_file}
    fi

    exit 0
}


## script starts here

if [ "$1" == "test" ]; then
    func_test
fi

if [ "$1" == "repair" ]; then 
    func_repair $2	
fi
