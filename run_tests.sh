#!/bin/sh

cd tests

for i in *.boa
do
	echo -n "$i ... "
	if [ ! -f "$i.out" ]
	then
		echo -en "\E[33m"
		echo "creating test results"
		echo -en "\E[0m"
		../boa "$i" > "$i.out"
	else
		a=$(../boa "$i")
		b=$(cat "$i.out")
		if [ "$a" == "$b" ]
		then
			echo -en "\E[32m"
			echo "ok"
			echo -en "\E[0m"
		else
			echo -en "\E[31m"
			echo "fail"
			echo -en "\E[0m"
			echo "output:"
			echo -en "\E[31m"
			echo "$a"
			echo -en "\E[0m"
			echo "expected:"
			echo -en "\E[32m"
			echo "$b"
			echo -en "\E[0m"
		fi
	fi
done
