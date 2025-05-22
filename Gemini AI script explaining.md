Okay, let's analyze the win\_split\_routing.cmd batch script. It automates the process described in the README file for managing simultaneous LAN and Wi-Fi connections.

Here's a breakdown of its functionality:

1. **Configuration Section:**  
   * **Network List:** The script starts with a list of network addresses (like 10.0.0.0/8, 172.16.0.0/12, etc.) marked with a leading colon :. These are the private or specific networks intended to be routed through the LAN interface. This list ends with :STOP. You are meant to edit this section to include the specific networks relevant to your LAN environment.  
   * **Interface Indexes:** You must manually set the INTERNET\_IF\_IDX (e.g., for Wi-Fi) and LAN\_IF\_IDX variables to the correct index numbers for your network adapters. The script comments suggest using netsh interface ipv4 show interface to find these indexes.  
2. **Administrative Privilege Check:**  
   * The script uses fsutil dirty query %systemdrive% \> nul to check if it's running with administrator rights.  
   * If not elevated, it prints a message explaining the need for "Run as administrator" and exits.  
3. **Interface Information Gathering:**  
   * It uses netsh interface ipv4 show interface to find the current metric and descriptive name for the specified LAN\_IF\_IDX and the name for the INTERNET\_IF\_IDX.  
   * It includes basic error checking to exit if the LAN interface metric is too low (\<= 5\) or if the interfaces cannot be found based on the provided indexes.  
4. **LAN Gateway Discovery:**  
   * It parses the output of netsh interface ipv4 show route to find the default gateway (0.0.0.0/0) associated specifically with the LAN\_IF\_IDX.  
   * It stores this gateway IP address in the DEFGATEWAY variable.  
   * If the gateway for the LAN interface isn't found, the script prints an error and exits.  
5. **Setting Internet Interface Metric:**  
   * It calculates a new metric for the INTERNET\_IF\_IDX by subtracting 5 from the LAN interface's current metric (set /A metric-=5).  
   * It applies this new, lower metric using netsh interface ipv4 set interface interface=%INTERNET\_IF\_IDX% metric=%metric%. This prioritizes the internet interface for default traffic.  
6. **Adding Permanent Routes:**  
   * The script iterates through the network list defined at the beginning.  
   * For each network address found between the start and the :STOP line, it executes the command route \-p add \<network\> %DEFGATEWAY%.  
   * The \-p flag makes these routes persistent, meaning they will survive reboots. These routes force traffic destined for the specified networks through the LAN's gateway (%DEFGATEWAY%). Error output from the route command (e.g., if a route already exists) is suppressed (2\> nul).  
7. **Displaying Routes:**  
   * After adding the routes, the script uses route \-4 print and filters its output to show the section containing the persistent IPv4 routes, allowing you to verify the changes.  
8. **Completion:**  
   * The script pauses (pause) so you can review the output before the console window closes.

In summary, the script automates setting a lower metric for your primary internet interface (like Wi-Fi) and adding persistent static routes for specific private networks via your LAN interface, effectively implementing the split routing configuration described in the README. It requires initial manual configuration of network lists and interface indexes.