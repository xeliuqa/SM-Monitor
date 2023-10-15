# basedOn: https://discord.com/channels/623195163510046732/691261331382337586/1142174063293370498
#and also: https://github.com/PlainLazy/crypto/blob/main/sm_watcher.ps1
# thanksTo: --== S A K K I ==-- and Samovar and Stizerg
# get grpcurl here: https://github.com/fullstorydev/grpcurl/releases
$host.ui.RawUI.WindowTitle = $MyInvocation.MyCommand.Name
function main {
	$currentDate = Get-Date -Format HH:mm:ss
    $grpcurl = ".\grpcurl.exe"

    $list = @(
        #@{ info = "Node 1"; host = "localhost";  port = 9012; port2 = 9013; }
        #@{ info = "Node 2"; host = "localhost";  port = 9022; port2 = 9023; }
        #@{ info = "Node 3"; host = "localhost";  port = 9032; port2 = 9033; }
        #@{ info = "Node 4"; host = "localhost";  port = 9042; port2 = 9043; }
        #@{ info = "Node 5"; host = "localhost";  port = 9052; port2 = 9053; }
        @{ info = "Node 6"; host = "192.168.1.14";  port = 9062; port2 = 9063; }
        @{ info = "Test"; host = "localhost";  port = 9082; port2 = 9083; }
        @{ info = "Smapp"; host = "localhost";  port = 9092; port2 = 9093; }
    )
    # Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow

    $columnRules = @(
        @{ Column = "Info"; Value = "*"; ForegroundColor = "Cyan"; BackgroundColor = "Black" },
        @{ Column = "SmesherID"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "Host"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Port";  ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Peers"; Value = "*"; ForegroundColor = "DarkCyan"; BackgroundColor = "Black" },
		@{ Column = "Peers"; Value = "0"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "SU"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "SizeTiB"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" },
		@{ Column = "Synced"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "Layer Top Verified"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Ver"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" }
        
    )

Clear-Host	
    while (1) {

		
        $object=@()
	$resultsNodeHighestATX = $null
	$epoch = $null

 	Write-Host `n
	Write-Host -NoNewline "Loading ..."
        foreach ($node in $list) {
		Write-Host  -NoNewline " $($node.info) "

		if ($resultsNodeHighestATX -eq $null){
			$resultsNodeHighestATX = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port) spacemesh.v1.ActivationService.Highest")) | ConvertFrom-Json).atx 2>$null
		}
		if ($epoch -eq $null){
			$epoch = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.MeshService.CurrentEpoch")) | ConvertFrom-Json).epochnum 2>$null
		}
			
			$status = $null
            $status = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Status")) | ConvertFrom-Json).status  2>$null

                if ($status -ne $null){
				$node.online = "True"
					if ($status.isSynced){
				$node.synced = "True"} else {$node.synced = "False"}
				$node.connectedPeers = $status.connectedPeers
				$node.syncedLayer = $status.syncedLayer.number
				$node.topLayer = $status.topLayer.number
				$node.verifiedLayer = $status.verifiedLayer.number
				}else {
					$node.online = "False"
					$node.smeshing = "Offline"
					$node.synced = "Offline"}

				if ($node.online -eq "True"){
			$version = $null
            $version = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Version")) | ConvertFrom-Json).versionString.value  2>$null
			if ($version -ne $null){
			$node.version = $version}
			
	#if (($node.host -eq "localhost") -Or ($node.host -ne "localhost" -And $node.port2 -ne 9093)){
			$smeshing = $null
			$smeshing = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.IsSmeshing")) | ConvertFrom-Json)	2>$null
			
			if ($smeshing -ne $null)
					{$node.smeshing = "True"} else {$node.smeshing = "False"}


			$state = $null
			$state = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.PostSetupStatus")) | ConvertFrom-Json).status 2>$null
			
		if ($state -ne $null) {
			$node.numUnits = $state.opts.numUnits}

			$publicKey = $null
            $publicKey = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.SmesherID")) | ConvertFrom-Json).publicKey 2>$null
	

            #Convert SmesherID to HEX
			if ($publicKey -ne $null) {
            $publicKey2 = (B64_to_Hex -id2convert $publicKey)
            #Extract last 5 digits from SmesherID
            $node.key = $publicKey2.substring($publicKey2.length -5, 5)
			}
	#}
		}

            $o = [PSCustomObject]@{
                Info = $node.info
                SmesherID = $node.key
                Host = $node.host
                Port = $node.port
                Peers = $node.connectedPeers
		SU = $node.numUnits
                "SizeTiB" = $node.numUnits * 64 * 0.001
                Synced = $node.synced
                Layer= $node.syncedLayer
                Top = $node.topLayer
                Verified = $node.verifiedLayer
                Ver = $node.version
				Smeshing = $node.smeshing
            } 
            $object += $o
        }

        Clear-Host
        $object | Select-Object Info, SmesherID, Host, Port, Peers, SizeTB, Synced, Layer, Top, Verified, Ver, Smeshing | ColorizeMyObject -ColumnRules $columnRules
        Write-Host `n
		Write-Host "-------------------------------- Netwotk Info: ---------------------------------" -ForegroundColor Yellow
		Write-Host "Current Epoch: " -ForegroundColor Cyan -nonewline; Write-Host $epoch.number -ForegroundColor Green
		Write-Host "  Highest ATX: " -ForegroundColor Cyan -nonewline; Write-Host (B64_to_Hex -id2convert $resultsNodeHighestATX.id.id) -ForegroundColor Green
        Write-Host "ATX Base64_ID: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.id.id -ForegroundColor Green
        #Write-Host "        Layer: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.layer.number -ForegroundColor Green
        #Write-Host "     NumUnits: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.numUnits -ForegroundColor Green
        #Write-Host "      PrevATX: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.prevAtx.id -ForegroundColor Green
        #Write-Host "    SmesherID: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.smesherId.id -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow
		Write-Host `n
		Write-Host "Last refresh: " -ForegroundColor Yellow -nonewline; Write-Host "$currentDate" -ForegroundColor Green;
		Write-host -NoNewline " "

        #Loading
        for ($s=0;$s -le 60; $s++) {
            Write-Host -NoNewline "." -ForegroundColor Cyan
           
            Start-Sleep 5
            }	
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
function ColorizeMyObject {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$ColumnRules
    )

    begin {
        $dataBuffer = @()
    }

    process {
        $dataBuffer += $InputObject
    }

    end {
        $headers = $dataBuffer[0].PSObject.Properties.Name

        $maxWidths = @{}
        foreach ($header in $headers) {
            $headerLength = "$header".Length
            $dataMaxLength = ($dataBuffer | ForEach-Object { "$($_.$header)".Length } | Measure-Object -Maximum).Maximum
            $maxWidths[$header] = [Math]::Max($headerLength, $dataMaxLength)
        }
        
        $headers | ForEach-Object { 
            $paddedHeader = $_.PadRight($maxWidths[$_])
            Write-Host $paddedHeader -NoNewline; 
            Write-Host "  " -NoNewline 
        }
        Write-Host ""

        $headers | ForEach-Object {
            $dashes = '-' * $maxWidths[$_]
            Write-Host $dashes -NoNewline
            Write-Host "  " -NoNewline
        }
        Write-Host ""
        
        foreach ($row in $dataBuffer) {
            foreach ($header in $headers) {
                $propertyValue = "$($row.$header)"
                $foregroundColor = $null
                $backgroundColor = $null

                foreach ($rule in $ColumnRules) {
                    if ($header -eq $rule.Column) {
                        if ($propertyValue -like $rule.Value) {
                            $foregroundColor = $rule.ForegroundColor
                            if ($rule.BackgroundColor) {
                                $backgroundColor = $rule.BackgroundColor
                            }
                            break
                        }
                    }
                }

                $paddedValue = $propertyValue.PadRight($maxWidths[$header])

                if ($foregroundColor -or $backgroundColor) {
                    if ($backgroundColor) {
                        Write-Host $paddedValue -NoNewline -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
                    } else {
                        Write-Host $paddedValue -NoNewline -ForegroundColor $foregroundColor
                    }
                } else {
                    Write-Host $paddedValue -NoNewline
                }

                Write-Host "  " -NoNewline
            }
            Write-Host ""
        }
    }
}


main
