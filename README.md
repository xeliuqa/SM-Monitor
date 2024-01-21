# SM-Monitor
Simple monitor for Spacemesh nodes<br>

With Thanks To: == S A K K I == Stizerg == PlainLazy == Shanyaa<br>
for the various contributions in making this script awesome
<br>
[![IMAGE ALT TEXT HERE](https://github.com/xeliuqa/SM-Monitor/blob/main/SM-Monitor.jpg)]
<br>

To use this monitor you need to download GRPCurl<br> 
https://github.com/fullstorydev/grpcurl<br><br>
Put downloaded file to the same folder with SM-Monitor<br>

You need Powershell 7 to use this script.<br>
If you don't have it yet please download it from <br>
https://github.com/PowerShell/PowerShell
<br>
Use any text file editor.<br>
Edit $ports for each node. You can find this in your node config files.<br>
node-config.json for smapp<br>
config-mainnet.json for go-spacemesh<br><br>

Script supports as many nodes as you want.<br>
In "General Settings" of the script change to "True" for options you want to see or "False" otherwise<br><br>

Please note that to access Nodes remotely you need to change address in your node's config<br>
`grpc-private-listener": "0.0.0.0:9093`<br><br>

