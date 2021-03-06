#!/bin/tcsh -f


echo "###################"
if (! ${?CADC_ROOT} ) then
	set CADC_ROOT = "/usr/cadc/local"
endif
echo "using CADC_ROOT = $CADC_ROOT"

if (! ${?VOSPACE_WEBSERVICE} ) then
	echo "VOSPACE_WEBSERVICE env variable not set, use default WebService URL"
else
	echo "WebService URL (VOSPACE_WEBSERVICE env variable): $VOSPACE_WEBSERVICE"
endif

if (! ${?CADC_PYTHON_TEST_TARGETS} ) then
    set CADC_PYTHON_TEST_TARGETS = 'python2.6 python2.7'
endif
echo "Testing for targets $CADC_PYTHON_TEST_TARGETS. Set CADC_PYTHON_TEST_TARGETS to change this."

echo "###################"

foreach pythonVersion ($CADC_PYTHON_TEST_TARGETS)
    echo "*************** test with $pythonVersion ************************"

    set LSCMD = "$pythonVersion $CADC_ROOT/scripts/vls"
    set MKDIRCMD = "$pythonVersion $CADC_ROOT/scripts/vmkdir"
    set RMCMD = "$pythonVersion $CADC_ROOT/scripts/vrm"
    set CPCMD = "$pythonVersion $CADC_ROOT/scripts/vcp"
    set RMDIRCMD = "$pythonVersion $CADC_ROOT/scripts/vrmdir"
    set MVCMD = "$pythonVersion $CADC_ROOT/scripts/vmv"
    set CHMODCMD = "$pythonVersion $CADC_ROOT/scripts/vchmod"


    set CERT = "--cert=$A/test-certificates/x509_CADCRegtest1.pem"
    set CERT1 = "--cert=$A/test-certificates/x509_CADCAuthtest1.pem"
    set CERT2 = "--cert=$A/test-certificates/x509_CADCAuthtest2.pem"

    #set CRED_CLIENT="java ${LOCAL} -jar ${CADC_ROOT}/lib/cred_wsPubClient.jar"

    #echo "cred client:         " $CRED_CLIENT

    # group 3000 aka CADC_TEST1-Staff has members: CADCAuthtest1
    set GROUP1 = "ivo://cadc.nrc.ca/gms#CADC_TEST1-Staff"

    # group 3100 aka CADC_TEST2-Staff has members: CADCAuthtest1, CADCAuthtest2
    set GROUP2 = "ivo://cadc.nrc.ca/gms#CADC_TEST2-Staff"

    # using a test dir makes it easier to cleanup a bunch of old/failed tests
    set VOHOME = "vos:CADCRegtest1"
    set BASE = "$VOHOME/atest"

    set TIMESTAMP=`date +%Y-%m-%dT%H-%M-%S`
    set CONTAINER = $BASE/$TIMESTAMP

    echo -n "** checking base URI"
    $LSCMD $CERT $BASE > /dev/null
    if ( $status == 0) then
        echo " [OK]"
    else
        echo -n ", creating base URI"
            $MKDIRCMD $CERT $BASE || echo " [FAIL]" && exit -1
        echo " [OK]"
    endif

    echo -n "** setting home and base to public"
    $CHMODCMD $CERT o+r $VOHOME || echo " [FAIL]" && exit -1
    $CHMODCMD $CERT o+r $BASE || echo " [FAIL]" && exit -1
    echo " [OK]"
    echo

    echo "*** starting test sequence ***"
    echo
    echo "** test container: ${CONTAINER}"
    echo

    echo -n "setup: create container "
    $MKDIRCMD $CERT $CONTAINER ||  echo " [FAIL]" && exit -1
    $CHMODCMD $CERT o-r $CONTAINER ||  echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: create container/a read-write to group 2" 
    $MKDIRCMD $CERT $CONTAINER/a || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: create container/a/aa read-write to group 1"
    $MKDIRCMD $CERT $CONTAINER/a/aa || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a/aa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: upload data node aaa to container/a/aa "
    $CPCMD $CERT something.png $CONTAINER/a/aa/aaa || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a/aa/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: upload data node b to container "
    $CPCMD $CERT something.png $CONTAINER/b || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/b > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: upload data node c to container read-write to group 2"
    $MKDIRCMD $CERT $CONTAINER/c || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/c > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: create container/d read-write to group 2"
    $MKDIRCMD $CERT $CONTAINER/d || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/d > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: create container/d read-write to group 1"
    $MKDIRCMD $CERT $CONTAINER/e || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/e > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "check no write permission on source data node (fail)"
    $MVCMD $CERT2 $CONTAINER/b $CONTAINER/d >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/b > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "check no recursive write permission on source container node (fail)"
    $MVCMD $CERT2 $CONTAINER/a $CONTAINER/d >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "check no write permission on dest (fail)"
    $MVCMD $CERT2 $CONTAINER/c $CONTAINER/e >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/c > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test dest a data node (fail)"
    $MVCMD $CERT $CONTAINER/a $CONTAINER/b >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test circular move (fail)"
    $MVCMD $CERT $CONTAINER/a $CONTAINER/a/aa >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test root move (fail)"
    $MVCMD $CERT $BASE $CONTAINER/d >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $BASE > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test move container into container (pass)"
    $RMDIRCMD $CERT $CONTAINER/d/a >& /dev/null
    $MVCMD $CERT $CONTAINER/a $CONTAINER/d >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/d/a > /dev/null || echo " [FAIL]" && exit -1
    $LSCMD $CERT $CONTAINER/d/a/aa > /dev/null || echo " [FAIL]" && exit -1
    $LSCMD $CERT $CONTAINER/d/a/aa/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: move container back"
    $MVCMD $CERT $CONTAINER/d/a $CONTAINER >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test move container with new name (pass)"
    $MVCMD $CERT $CONTAINER/a $CONTAINER/d/x >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/d/x > /dev/null || echo " [FAIL]" && exit -1
    $LSCMD $CERT $CONTAINER/d/x/aa > /dev/null || echo " [FAIL]" && exit -1
    $LSCMD $CERT $CONTAINER/d/x/aa/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "setup: move container back"
    $MVCMD $CERT $CONTAINER/d/x $CONTAINER/a >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test move file into container (pass)"
    $MVCMD $CERT $CONTAINER/a/aa/aaa $CONTAINER/d >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/d/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test move file with new name"
    $MVCMD $CERT $CONTAINER/d/aaa $CONTAINER/a/aa/bbb >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a/aa/bbb > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "test rename file"
    $MVCMD $CERT $CONTAINER/a/aa/bbb $CONTAINER/a/aa/aaa >& /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a/aa/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    echo -n "move a vos container to local file system (fail)"
    $MVCMD $CERT $CONTAINER/a notused.txt >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a > /dev/null || echo " [FAIL]" && exit -1
    echo " [OK]"

    #TODO not supported in vmv
    echo -n "move a vos data node to local file system (pass)"
    #echo "$MVCMD $CERT $CONTAINER/a/aa/aaa something2.png > /dev/null"
    #$MVCMD $CERT $CONTAINER/a/aa/aaa something2.png > /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    #$LSCMD $CERT $CONTAINER/a/aa/aaa > /dev/null && echo " [FAIL]" && exit -1
    echo " [TODO]"

    echo -n "move a local directory to vos (fail)"
    mkdir testdir
    $MVCMD $CERT testdir $CONTAINER/a >& /dev/null && echo " [FAIL]" && exit -1
    echo -n " verify "
    $LSCMD $CERT $CONTAINER/a/testdir >& /dev/null && echo " [FAIL]" && exit -1
    rmdir testdir
    echo " [OK]"

    #TODO not supported in vmv
    echo -n "move a file to vos (success)"
    #$MVCMD $CERT something2.png $CONTAINER/a/aa/aaa> /dev/null || echo " [FAIL]" && exit -1
    echo -n " verify "
    #$LSCMD $CERT $CONTAINER/a/aa/aaa > /dev/null || echo " [FAIL]" && exit -1
    echo " [TODO]"

    echo -n "do a local file system move (fail--unsupported)"
    cp -f something.png something2.png
    $MVCMD $CERT something2.png something3.png >& /dev/null && echo " [FAIL]" && exit -1
    rm something2.png
    echo " [OK]"
end

echo
echo "*** test sequence passed ***"

date
