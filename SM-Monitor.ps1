# basedOn: https://discord.com/channels/623195163510046732/691261331382337586/1142174063293370498
#and also: https://github.com/PlainLazy/crypto/blob/main/sm_watcher.ps1
# thanksTo: --== S A K K I ==-- and PlainLazy
# get grpcurl here: https://github.com/fullstorydev/grpcurl/releases
$host.ui.RawUI.WindowTitle = $MyInvocation.MyCommand.Name


function main {
	

    $grpcurl = ".\grpcurl.exe"
    $cooldown = 120
	

    $list = @(
        @{ info = "Node 1"; host = "localhost";  port = 9012; port2 = 9013; }
        #@{ info = "Node 2"; host = "localhost";  port = 9022; port2 = 9023; }
        #@{ info = "Node 3"; host = "localhost";  port = 9032; port2 = 9033; }
        #@{ info = "Node 4"; host = "localhost";  port = 9042; port2 = 9043; }
        #@{ info = "Node 5"; host = "localhost";  port = 9052; port2 = 9053; }
        #@{ info = "Node 6"; host = "localhost";  port = 9062; port2 = 9063; }
        @{ info = "Node 7"; host = "localhost";  port = 9072; port2 = 9073; }
    )

    while (1) {

        cls		
        $object=@()

        $node = $list[0]
		$resultsNodeHighestATX = ((Invoke-Expression (
            "$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port) spacemesh.v1.ActivationService.Highest"
        )) | ConvertFrom-Json).atx

        foreach ($node in $list) {
            Write-Host "Loading $($node.info) Ports ..."
			$currentDate = Get-Date -DisplayHint Date
            $status = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Status"
            )) | ConvertFrom-Json).status 

            $version = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Version"
            )) | ConvertFrom-Json).versionString.value 

			$smeshing = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.IsSmeshing"
            )) | ConvertFrom-Json)	
			
			$state = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.PostSetupStatus"
            )) | ConvertFrom-Json).status
			
			$epoch = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.MeshService.CurrentEpoch"
            )) | ConvertFrom-Json).epochnum

            $o = [PSCustomObject]@{
				
                Info = $node.info
                Host = $node.host
                Port = $node.port
                Peers = $status.connectedPeers
                Synced = $status.isSynced 
                "Layer Top Verified" = "$($status.syncedLayer.number) $($status.topLayer.number) $($status.verifiedLayer.number)"
                Ver = $version 
				Smeshing = $smeshing.isSmeshing
				State = $state.state
            }
            $object += $o
        }

        cls
        $object | ft
		Write-Host "Last refresh: " -ForegroundColor Yellow -nonewline; Write-Host "$currentDate" -ForegroundColor Green;
		Write-Host `n
		Write-Host  "---------------------------------Netwotk Info:----------------------------------" -ForegroundColor Yellow
		Write-Host  "Current Epoch: " $epoch.number -ForegroundColor Green
        #Write-Host "     Address: " $($resultsNodeHighestATX.coinbase.address) -ForegroundColor Green
		Write-Host  " Highest ATX : " (B64_to_Hex -id2convert $resultsNodeHighestATX.id.id) -ForegroundColor Green
        Write-Host  "ATX Base64_ID: " $resultsNodeHighestATX.id.id -ForegroundColor Green
        #Write-Host "       Layer: " $resultsNodeHighestATX.layer.number -ForegroundColor Green
        #Write-Host "    NumUnits: " $resultsNodeHighestATX.numUnits -ForegroundColor Green
        #Write-Host "     PrevATX: " $resultsNodeHighestATX.prevAtx.id -ForegroundColor Green
        #Write-Host "   SmesherID: " $resultsNodeHighestATX.smesherId.id -ForegroundColor Green
        Write-Host  "--------------------------------------------------------------------------------" -ForegroundColor Yellow
	
		
		
		Start-Sleep -Seconds $cooldown
    }
}
	function B64_to_Hex{
		param (
			[Parameter(Position =0, Mandatory = $true)]
			[string]$id2convert
			)
		[System.BitConverter]::ToString([System.Convert]::FromBase64String($id2convert)).Replace("-","")
	}
	function Hex_to_B64{
		param (
			[Parameter(Position =0, Mandatory = $true)]
			[string]$id2convert
		)
    $NODE_ID_BYTES = for ($i = 0; $i -lt $id2convert.Length; $i += 2) { [Convert]::ToByte($id2convert.Substring($i, 2), 16) }
    [System.Convert]::ToBase64String($NODE_ID_BYTES)
}

main
