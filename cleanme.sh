#!/bin/bash
for i in $(s9s cluster --list --long | sed -e '1,1d' -e'$d' | awk '{print $1}'); do s9s cluster --drop --cluster-id=$i; done
for i in $(bin/govc ls /Datacenter/vm/databases); do bin/govc vm.destroy $i & done
for i in $(s9s jobs --list | sed -e '1,1d' -e'$d' | awk '{print $1}'); do s9s jobs --delete --job-id=$i; done
