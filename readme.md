# parrallel ssh db benchmark
pssh -t0 -i -h current-masters "pgbench -c2 -t 100000 -d postgres -P1 2> /dev/null"

# Deploy agents to all clusters
for i in $(s9s cluster --list --long | sed -e '1,1d' -e'$d' | awk '{print $1}'); do s9s cluster --deploy-agents --cluster-id=$i; done

# find masters
s9s node --list --long | grep poM | awk '{print $5}' > current-masters
