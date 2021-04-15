for i in $(s9s node --list --long | grep poM | awk '{print $5}') 
    do 
        ssh $i "
	    > ~/database_results.txt
            pgbench -i -d postgres >> ~/database_results.txt	
	    echo '* * * * * date --rfc-3339=seconds >> ~/database_results.txt && \
            pgbench -j2 -c1 -t 5000 -d postgres -P1 >> ~/database_results.txt 2> /dev/null' \
	    | crontab -
        " &
    done
