#!/bin/sh
#Leap Size
param1=11
param2=1.2
param3=.75
#LeapSize
for i in 14 15 16
do
#Epsilon
		for j in $(seq .8 .1 $param2);
		do
			#Beta
			for k in $(seq .65 .01 $param3);
			do
				echo $i,$j,$k
				qsub param_test.sh  -v "LeapSize=$i,Epsilon=$j,Beta=$k"
			done
		done
done
