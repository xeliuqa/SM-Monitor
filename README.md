# SM-Monitor
Simple monitor for Spacemesh nodes<br>

This is the work of 4 people<br>
Sakki - PLainLazy - Jonh - Stizerg
<br>
<img src="https://github.com/xeliuqa/SM-Monitor/blob/main/sm-monitor.png" height="300px" width="500px"/>

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

Please note that to access Nodes remotely you need to change config to<br>
"grpc-private-listener": "0.0.0.0:9083",<br><br>

Monitor will refresh every 5 minutes.<br>
Since each layer lasts 5 minutes i don't see the need for faster refresh<br>
However time can be edited at line 94, using seconds x 5<br>
Current 60 seconds x 5s delay = 300 seconds = 5 minutes

