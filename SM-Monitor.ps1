# basedOn: https://discord.com/channels/623195163510046732/691261331382337586/1142174063293370498
#and also: https://github.com/PlainLazy/crypto/blob/main/sm_watcher.ps1
# thanksTo: --== S A K K I ==-- and PlainLazy
# get grpcurl here: https://github.com/fullstorydev/grpcurl/releases
$host.ui.RawUI.WindowTitle = $MyInvocation.MyCommand.Name
function main {

    $grpcurl = ".\grpcurl.exe"

    $list = @(
        #@{ info = "Node 1"; host = "localhost";  port = 9012; port2 = 9013; }
        #@{ info = "Node 2"; host = "localhost";  port = 9022; port2 = 9023; }
        #@{ info = "Node 3"; host = "localhost";  port = 9032; port2 = 9033; }
        #@{ info = "Node 4"; host = "localhost";  port = 9042; port2 = 9043; }
        #@{ info = "Node 5"; host = "localhost";  port = 9052; port2 = 9053; }
        @{ info = "Node 6"; host = "192.168.1.14";  port = 9062; port2 = 9063; }
        @{ info = "Node 7"; host = "localhost";  port = 9082; port2 = 9083; }
        @{ info = "smapp"; host = "localhost";  port = 9092; port2 = 9093; }
   )

    # Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow

    $columnRules = @(
        @{ Column = "Info"; Value = "*"; ForegroundColor = "Cyan"; BackgroundColor = "Black" },
        @{ Column = "SmesherID"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "Host"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Port";  ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Peers"; Value = "*"; ForegroundColor = "DarkCyan"; BackgroundColor = "Black" },
        @{ Column = "Peers"; Value = "0"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "Size-TB"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "Layer Top Verified"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Version"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Version"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" }
        @{ Column = "Smeshing"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" }
        @{ Column = "Smeshing"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" }
        
    )

    while (1) {

        Clear-Host		
        $object=@()

        $node = $list[0]
        $resultsNodeHighestATX = ((Invoke-Expression (
            "$($grpcurl) --plaintext -max-time 10 $($node.host):$($node.port) spacemesh.v1.ActivationService.Highest"
        )) | ConvertFrom-Json).atx 2>$null
        
        $epoch = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.MeshService.CurrentEpoch"
            )) | ConvertFrom-Json).epochnum 2>$null

        foreach ($node in $list) {
            Write-Host "Loading $($node.info) Ports ..."
            $currentDate = Get-Date -Format HH:mm:ss
            $status = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Status"
            )) | ConvertFrom-Json).status  2>$null

            $version = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Version"
            )) | ConvertFrom-Json).versionString.value  2>$null

			if (($node.host -eq "localhost") -Or ($node.host -ne "localhost" -And $node.port2)){
                $smeshing = ((Invoke-Expression (
                    "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.IsSmeshing"
                )) | ConvertFrom-Json) 2>$null
    
                $publicKey = $null
                $publicKey = ((Invoke-Expression (
                    "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.SmesherID"
                )) | ConvertFrom-Json).publicKey 2>$null

                $state = ((Invoke-Expression (
                "$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.PostSetupStatus"
                )) | ConvertFrom-Json).status 2>$null
        
                #Convert SmesherID to HEX
                if ($null -ne $publicKey) {
                $publicKey2 = (B64_to_Hex -id2convert $publicKey)
                #Extract last 5 digits from SmesherID
                $node.key = $publicKey2.substring($publicKey2.length -5, 5)
                }
                
                if ($null -eq $smeshing.isSmeshing){
                    $smeshing = "False"} else {$smeshing = "True"}
                
                if ($null -eq $status.isSynced){
                    $node.synced = "False"} else {$node.synced = "True"}

                if ($null -eq $status.connectedPeers){
                    ($version = "Offline"), ($smeshing = "Offline"), ($node.synced = "Offline")
                        }          

            }
    
            $o = [PSCustomObject]@{
                Info = $node.info
                SmesherID = $node.key
                Host = $node.host
                Port = $node.port
                Peers = $status.connectedPeers
                SizeTB = $state.opts.numUnits * 64000 / 1000000 
                Synced = $node.synced
                Layer= $status.syncedLayer.number
                Top = $status.topLayer.number
                Verified = $status.verifiedLayer.number
                Version = $version
                Smeshing = $smeshing
            } 
            $object += $o
        }

        $object | ColorizeMyObject -ColumnRules $columnRules # You must "select" your columns/properties.  Otherwise, hidden properties will corrupt your view.

        Clear-Host
        $object | Select-Object Info, SmesherID, Host, Port, Peers, SizeTB, Synced, Layer, Top, Verified, Version, Smeshing | ColorizeMyObject -ColumnRules $columnRules
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
