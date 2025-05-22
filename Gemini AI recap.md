### **Problem Addressed**

The project addresses a common issue on Windows when a computer is connected to both a wired LAN (Ethernet) and a Wi-Fi network simultaneously. Windows assigns a metric to each network interface, and traffic defaults to the interface with the lowest metric.

* If Wi-Fi has the lower metric, internet access works, but you might not be able to reach private subnets accessible only via the LAN connection (beyond the directly connected subnet).  
* If the LAN has the lower metric, you can reach private subnets, but internet access might fail if the LAN doesn't provide it (common in enterprise environments).

### **Solution Overview**

The solution involves manually configuring the network interfaces to prioritize Wi-Fi for general internet traffic while ensuring specific private network traffic goes through the LAN:

1. **Prioritize Wi-Fi:** Assign a fixed, low metric to the Wi-Fi interface, lower than the LAN interface's metric. This makes Wi-Fi the default route for most traffic, ensuring internet connectivity. The README provides manual steps to set this via the Network Connections properties.  
2. **Route Private Subnets via LAN:** Add specific, persistent static routes for the private subnets you need to access. These routes direct traffic for those specific destinations through the LAN interface's gateway, overriding the default Wi-Fi route because specific routes have priority over default routes.

### **How the win\_split\_routing.cmd Script Works**

The script automates parts of this configuration:

1. **Configuration:** You need to edit the script first to list the private subnets reachable via LAN and specify the interface indexes (Idx) for your Wi-Fi (INTERNET\_IF\_IDX) and LAN (LAN\_IF\_IDX) interfaces. You can find these indexes using the netsh interface ipv4 show interface command.  
2. **Execution:** When run, the script performs the following:  
   * Finds the current metric and name of the LAN interface and the name of the internet (Wi-Fi) interface.  
   * Finds the default gateway IP address for the LAN interface.  
   * Sets the metric of the internet (Wi-Fi) interface to be 5 less than the LAN interface's metric, making it the preferred default route.  
   * Adds permanent static routes for each private subnet listed in the script's configuration section. These routes direct traffic for those subnets through the LAN interface's gateway. Permanent routes remain active even after rebooting.

In essence, the win\_split\_routing.cmd script helps users configure their Windows machine to use Wi-Fi for general internet access while simultaneously maintaining access to specific private networks via a wired LAN connection by managing interface metrics and static routes.