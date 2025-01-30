#commandline ping a range of IPs
for /L %i in (208,1,222) do ping 172.31.10.%i 

