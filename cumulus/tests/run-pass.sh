#!/bin/bash

cd ..
source env.sh
cd -

mv ~/.s3cfg ~/.s3cfg.cumulus.test

cumulus_host=localhost
cumulus_port=9898

export CUMULUS_TEST_HOST=$cumulus_host
export CUMULUS_TEST_PORT=$cumulus_port

https_opt=" --https "
sec="True"
if [ "X${CUMULUS_TEST_HTTPS}" == "X" ]; then
    sec="False"
    https_opt=""
fi


$CUMULUS_HOME/bin/cumulus -p $cumulus_port $https_opt &
cumulus_pid=$!
echo $cumulus_pid
trap "kill $cumulus_pid; mv ~/.s3cfg.cumulus.test ~/.s3cfg; $CUMULUS_HOME/bin/cumulus-remove-user tests3cmd1@nimbus.test" EXIT
sleep 2
log_file=`mktemp`
echo "Logging output to $log_file" 
x=`$CUMULUS_HOME/bin/cumulus-add-user -b  -r ID,password tests3cmd1@nimbus.test`
echo $x
id=`echo $x | awk -F , '{ print $1 }'`
pw=`echo $x | awk -F, '{ print $2 }'`

echo $id
echo $pw

sed -e "s/@@SEC@@/$sec/g" -e "s^@@HOST_PORT@@^$cumulus_host:$cumulus_port^g" -e "s^@@ID@@^$id^" -e "s^@@KEY@@^$pw^" $CUMULUS_HOME/etc/dot_s3cfg.in > ~/.s3cfg

cd s3cmd
./run-em.sh
if [ "X$?" != "X0" ]; then
    echo "FAILED : s3 tests failed"
    exit 1
fi
cd ..

cd authz
nosetests *.py
if [ "X$?" != "X0" ]; then
    echo "FAILED : authz tests failed"
    exit 1
fi
cd ..

cd client
nosetests *.py
if [ "X$?" != "X0" ]; then
    echo "FAILED : boto tests failed"
    exit 1
fi

echo "Success : $cnt tests passed"
