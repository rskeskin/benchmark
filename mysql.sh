#!/bin/bash
# Author: Resul Serkan Kesin

#### VARS ####
TARGET="10.214.0.159"
PORT=3306
USER="root"
PASSWD="password"
DB="sbtest"
TESTNAME="mysql-4vcpu"
TSIZE=100000
TCOUNT=4
DBTEST="oltp_read_write"
DURATION=60
TPOLL=5
SNMPCOUNT=$(( DURATION / TPOLL ))
RUNCOUNT=5
CLIENTCOUNT=256
CLIENTSTEP=32
CORES=`snmpwalk -v2c -cpublic ${TARGET} 1.3.6.1.2.1.25.3.3.1.2 | wc -l`
snmpwalk -v2c -cpublic -Oq ${TARGET} .1.3.6.1.4.1.2021.13.15.1.1.2
read -p 'Specify block number : ' DISKNUM
snmpwalk -v2c -cpublic -Oq ${TARGET} .1.3.6.1.2.1.31.1.1.1.1
read -p 'Specify interface number : ' IFNUM
mkdir -p -- "${TESTNAME}"

#### PREPARE SYSBENCH ####
sysbench --db-driver=mysql --mysql-host=${TARGET} --mysql-port=${PORT} --mysql-user=${USER} --mysql-password=${PASSWD} --mysql-db=${DB} /usr/share/sysbench/${DBTEST}.lua --table-size=${TSIZE} --tables=${TCOUNT} prepare >>${TESTNAME}/results.txt 2>&1

#### FOR X'TH RUN ####
RUNID=1
while [ ${RUNID} -le ${RUNCOUNT} ]
do
    sleep 10
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/results.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-cpui.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-ramf.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-disr.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-disw.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-neti.txt 2>&1
    echo "################ RUN: $RUNID ################" >>${TESTNAME}/usage-neto.txt 2>&1
    #### FOR X CLIENTS ####
    CLIENT=${CLIENTSTEP}
    while [ ${CLIENT} -le ${CLIENTCOUNT} ]
    do
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/results.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-cpui.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-ramf.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-disr.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-disw.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-neti.txt 2>&1
        echo "######## CLIENTS: $CLIENT ########" >>${TESTNAME}/usage-neto.txt 2>&1
        #### SNMPGET ( DURATION / POLL ) TIMES ####
        X=1

        a=($(snmpget -v2c -cpublic -r1 -t2 -OqUv ${TARGET} \
        .1.3.6.1.4.1.2021.11.53.0 \
        .1.3.6.1.4.1.2021.4.6.0 \
        .1.3.6.1.4.1.2021.13.15.1.1.12.${DISKNUM} \
        .1.3.6.1.4.1.2021.13.15.1.1.13.${DISKNUM} \
        .1.3.6.1.2.1.31.1.1.1.6.${IFNUM} \
        .1.3.6.1.2.1.31.1.1.1.10.${IFNUM}))        
        while [ ${X} -le ${SNMPCOUNT} ]
        do
            sleep ${TPOLL}
            b=($(snmpget -v2c -cpublic -r1 -t2 -OqUv ${TARGET} \
            .1.3.6.1.4.1.2021.11.53.0 \
            .1.3.6.1.4.1.2021.4.6.0 \
            .1.3.6.1.4.1.2021.13.15.1.1.12.${DISKNUM} \
            .1.3.6.1.4.1.2021.13.15.1.1.13.${DISKNUM} \
            .1.3.6.1.2.1.31.1.1.1.6.${IFNUM} \
            .1.3.6.1.2.1.31.1.1.1.10.${IFNUM}))
	    echo "${b[@]}" >>snmpdump.txt
            echo "cpu util"    `echo "scale=2; 100 - ((${b[0]} - ${a[0]}) / ($CORES * $TPOLL))" | bc` "%"                                  >>${TESTNAME}/usage-cpui.txt 2>&1
            echo "ram free" ${b[1]} "kB"                                                                                                   >>${TESTNAME}/usage-ramf.txt 2>&1
            echo "disk read"   `echo "x = (${b[2]} - ${a[2]}); if ( x < 0) (18446744073709551616 + x)/$TPOLL else (x)/$TPOLL" | bc` "B/s"  >>${TESTNAME}/usage-disr.txt 2>&1
            echo "disk write"  `echo "x = (${b[3]} - ${a[3]}); if ( x < 0) (18446744073709551616 + x)/$TPOLL else (x)/$TPOLL" | bc` "B/s"  >>${TESTNAME}/usage-disw.txt 2>&1
            echo "network in"  `echo "x = (${b[4]} - ${a[4]}); if ( x < 0) (18446744073709551616 + x)/$TPOLL else (x)/$TPOLL" | bc` "B/s"  >>${TESTNAME}/usage-neti.txt 2>&1
            echo "network out" `echo "x = (${b[5]} - ${a[5]}); if ( x < 0) (18446744073709551616 + x)/$TPOLL else (x)/$TPOLL" | bc` "B/s"  >>${TESTNAME}/usage-neto.txt 2>&1
            a=("${b[@]}")
            X=$(( X + 1 ))
        done &

        #### RUN SYSBENCH ####
        sysbench --db-driver=mysql --mysql-host=${TARGET} --mysql-port=${PORT} --mysql-user=${USER} --mysql-password=${PASSWD} --mysql-db=${DB} /usr/share/sysbench/${DBTEST}.lua --table-size=${TSIZE} --tables=${TCOUNT} --time=${DURATION} --threads=${CLIENT} run >>${TESTNAME}/results.txt 2>&1
        wait
        CLIENT=$(( CLIENT + CLIENTSTEP ))
    done
    RUNID=$(( RUNID + 1 ))
done
#### CLEANUP SYSBENCH ####
sysbench --db-driver=mysql --mysql-host=${TARGET} --mysql-port=${PORT} --mysql-user=${USER} --mysql-password=${PASSWD} --mysql-db=${DB} /usr/share/sysbench/${DBTEST}.lua --table-size=${TSIZE} --tables=${TCOUNT} cleanup >>${TESTNAME}/results.txt 2>&1

