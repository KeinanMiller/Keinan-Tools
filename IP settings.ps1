#used for setting IP of laptop to predetrimed IP

# Set the IP address, subnet mask, and default gateway
$IPAddress = "192.168.1.49"
$SubnetMask = "255.255.255.0"
$Gateway = "192.168.1.1"
$InterfaceAlias = "Ethernet"  # Replace with your actual interface name if it's different

# Set the IP address
New-NetIPAddress -IPAddress $IPAddress -PrefixLength 24 -InterfaceAlias $InterfaceAlias -DefaultGateway $Gateway

# Set the DNS server
$DnsServer = "192.168.1.1"
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServer
