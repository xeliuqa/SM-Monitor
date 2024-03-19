Please note, 
Latest version of Sm-monitor requires PowerShell 7+ to run.
You can get it at
https://github.com/PowerShell/PowerShell/releases/tag/v7.4.1


# SM-Monitor
Simple monitor for Spacemesh nodes<br>

With Thanks To: == S A K K I == Stizerg == PlainLazy == Shanyaa<br>
for the various contributions in making this script awesome
<br>
`Click for video`<br>
[![IMAGE ALT TEXT HERE](https://github.com/xeliuqa/SM-Monitor/blob/main/SM-Monitor.gif)](https://youtu.be/tahubRoLjb8)
<br>

To use this monitor you need GRPCurl
Simply use with any GRPCurl software. <br> 
Put in same folder and open with terminal<br>
https://github.com/fullstorydev/grpcurl<br><br>

Use any text file editor but i recommend Visual Studio Code for best visualization<br>
Edit $ports for each node. You can find this in your node config files.<br>
node-config.json for smapp<br>
config-mainnet.json for go-spacemesh<br><br>

Script supports as many nodes as you want.<br>
Use "#" to comment out the options you don't need<br><br>

Please note that to access Nodes remotely you need to change config.mainnet.json to<br>
`grpc-private-listener": "0.0.0.0:9093`<br><br>

Disable Powershell Remote security.<br>
-Open Powershell in admin and insert code<br>
  Set-ExecutionPolicy RemoteSigned

