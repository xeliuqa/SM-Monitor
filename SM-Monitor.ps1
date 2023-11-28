<#  ------------------------------------------------------------------------------------------------
    SM-Monitor: https://github.com/xeliuqa/SM-Monitor
      Based on: https://discord.com/channels/623195163510046732/691261331382337586/1142174063293370498
      and also: https://github.com/PlainLazy/crypto/blob/main/sm_watcher.ps1
    
    With Thanks To: == S A K K I == Stizerg == PlainLazy == Shanyaa
    for the various contributions in making this script awesome

    Get grpcurl here: https://github.com/fullstorydev/grpcurl/releases
    --------------------------------------------------------------------------------------------- #>

    $host.ui.RawUI.WindowTitle = $MyInvocation.MyCommand.Name

    ############## General Settings  ##############
    $coinbaseAddressVisibility = "partial" # "partial", "full", "hidden"
    $smhCoinsVisibility = $true # $true or $false.
    $fakeCoins = 0 # For screenshot purposes.  Set to 0 to pull real coins.  FAKE 'EM OUT!  (Example: 2352.24)
    $tableRefreshTimeSeconds = 60 # Time in seconds that the refresh happens.  Lower value = more grpc entries in logs.
    $logoDelay = 3
    $host.UI.RawUI.BackgroundColor = "Black" # Set the entire background to specific color
    $emailEnable = "False" #True to enable email notification, False to disable
    $myEmail = "my@email.com" #Set your Email for notifications
    $grpcurl = ".\grpcurl.exe" #Set GRPCurl path if not in same folder
    
    $nodeList = @(
        @{ info = "Node_01"; host = "192.168.1.xx"; port = 11001; port2 = 11002 },
        @{ info = "Node_02"; host = "192.168.1.xx"; port = 12001; port2 = 12002 },
        @{ info = "Node_03"; host = "192.168.1.xx"; port = 13001; port2 = 13002 },
        @{ info = "Node_04"; host = "192.168.1.xx"; port = 14001; port2 = 14002 },
        @{ info = "SMAPP_Server"; host = "192.168.1.xx"; port = 9092; port2 = 9093 },
        @{ info = "SMAPP_Home"; host = "localhost"; port = 9092; port2 = 9093 }
    )
    ################ Settings Finish ###############

function main {
    [System.Console]::CursorVisible = $false
    printSMMonitorLogo
    Write-Host "Querying nodes..." -NoNewline -ForegroundColor Cyan       
    $gitVersion = Invoke-RestMethod -Method 'GET' -uri "https://api.github.com/repos/spacemeshos/go-spacemesh/releases/latest" 2>$null

    if ($null -ne $gitVersion) {
        $gitVersion = $gitVersion.tag_name
    }
        
    # Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow
    $columnRules = @(
        @{ Column = "Name"; Value = "*"; ForegroundColor = "Cyan"; BackgroundColor = "Black" },
        @{ Column = "SmesherID"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "Host"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Port"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Peers"; Value = "*"; ForegroundColor = "DarkCyan"; BackgroundColor = "Black" },
        @{ Column = "Peers"; Value = "0"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "SU"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "SizeTiB"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" },
        @{ Column = "Synced"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "Layer Top Verified"; Value = "*"; ForegroundColor = "White"; BackgroundColor = "Black" },
        @{ Column = "Version"; Value = "*"; ForegroundColor = "Red"; BackgroundColor = "Black" },
        @{ Column = "Version"; Value = $gitVersion; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Version"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = "Black" },
        @{ Column = "Smeshing"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = "Black" },
        @{ Column = "RWD"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = "Black" },
        @{ Column = "ATX"; Value = "*"; ForegroundColor = "Green"; BackgroundColor = "Black" },
        @{ Column = "ATX"; Value = "-"; ForegroundColor = "White"; BackgroundColor = "Black" }
        
    )
                
    if ($null -eq $gitVersion) {
        foreach ($rule in $ColumnRules) {
            if (($rule.Column -eq "Version") -and ($rule.Value -eq "*")) {
                $rule.ForegroundColor = "White"
                break
            }
        }
    }

    if (Test-Path ".\RewardsTrackApp.tmp") {
		Clear-Content ".\RewardsTrackApp.tmp"
	}
	
    while ($true) {
        
        $object = @()
        $resultsNodeHighestATX = $null
        $epoch = $null
        $totalLayers = $null
        $rewardsTrackApp = @()
        
        foreach ($node in $nodeList) {

  			if ($null -eq $node.name) {
				$node.name = $node.info	
			}
            Write-Host  " $($node.name)" -NoNewline -ForegroundColor Cyan
                        
            $status = $null
            $status = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Status")) | ConvertFrom-Json).status  2>$null
            Write-Host -NoNewline "." -ForegroundColor Cyan
        
            if ($status) {
                $node.online = "True"
                if ($status.isSynced) {
                    $node.synced = "True"
                    $node.emailsent = ""
                }
                else { $node.synced = "False" }
                $node.connectedPeers = $status.connectedPeers
                $node.syncedLayer = $status.syncedLayer.number
                $node.topLayer = $status.topLayer.number
                $node.verifiedLayer = $status.verifiedLayer.number
            }
            else {
                $node.online = ""
                $node.smeshing = "Offline"
                $node.synced = "Offline"
            }
        
            if ($node.online) {
				if ($null -eq $resultsNodeHighestATX) {
                	$resultsNodeHighestATX = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 10 $($node.host):$($node.port) spacemesh.v1.ActivationService.Highest")) | ConvertFrom-Json).atx 2>$null
            	}
            	if ($null -eq $epoch) {
                	$epoch = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.MeshService.CurrentEpoch")) | ConvertFrom-Json).epochnum 2>$null
            	}
			
                $version = $null
                $version = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port) spacemesh.v1.NodeService.Version")) | ConvertFrom-Json).versionString.value  2>$null
                Write-Host -NoNewline "." -ForegroundColor Cyan
                if ($null -ne $version) {
                    $node.version = $version
                }

                $eventstream = (Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.AdminService.EventsStream")) 2>$null
                $eventstream = $eventstream -split "`n" | Where-Object { $_ }
                $eligibilities = @()
				$atxPublished =@()
                $jsonObject = @()
                $poetWaitProof = @()
                foreach ($line in $eventstream) {
                    if ($line -eq "{") {
                        $jsonObject = @()
                    }
                    $jsonObject += $line
                    if ($line -eq "}") {
                        Try {
                            $json = $jsonObject -join "`n" | ConvertFrom-Json
                            if ($json.eligibilities) {
                                $eligibilities += $json.eligibilities
                            }
							if ($json.atxPublished) {
								$atxPublished += $json.atxPublished
							}
                            if ($json.poetWaitProof) {
								$poetWaitProof += $json.poetWaitProof
							}
                        }
                        Catch {
                            # Ignore the error and continue
                            continue
                        }
                    }
                }
                $atxTarget = $atxPublished.target
                $poetWait = $poetWaitProof.target
                $layers = $null
                foreach ($eligibility in $eligibilities) {
                    if ($eligibility.epoch -eq $epoch.number) {
                        $rewardsCount = ($eligibility.eligibilities | Measure-Object).count
                        $layers = $eligibility.eligibilities
                    }
                }
                if (($rewardsCount) -and ($layers)) {
                    $node.rewards = $rewardsCount
                    $node.layers = $layers
                }
                if ($null -eq $atxTarget) {
                    $node.atx = $poetWait
                }
                else {
                    $node.atx = $atxTarget
                }
                if (($null -eq $atxTarget) -and ($null -eq $poetWait)){
                    $node.atx = "-"
                }

                
                
                #Uncomment next line if your Smapp using standard configuration -- 1 of 2
                #if (($node.host -eq "localhost") -Or ($node.host -ne "localhost" -And $node.port2 -ne 9093)){ 
                $smeshing = $null
                $smeshing = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.IsSmeshing")) | ConvertFrom-Json)	2>$null
        
                if ($smeshing)
                { $node.smeshing = "True" } else { $node.smeshing = "False" }
        
                $state = $null
                $state = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.PostSetupStatus")) | ConvertFrom-Json).status 2>$null
                Write-Host -NoNewline "." -ForegroundColor Cyan
                
                if ($state) {
                    $node.numUnits = $state.opts.numUnits
                            
                    if ($state.state -eq "STATE_IN_PROGRESS") {
                        $percent = [math]::round(($state.numLabelsWritten / 1024 / 1024 / 1024 * 16) / ($state.opts.numUnits * 64) * 100, 1)
                        $node.smeshing = "$($percent)%"
                    }
                }
                
                $publicKey = $null
                $publicKey = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 3 $($node.host):$($node.port2) spacemesh.v1.SmesherService.SmesherID")) | ConvertFrom-Json).publicKey 2>$null
                
                
                #Convert SmesherID to HEX
                if ($publicKey) {
                    $publicKey2 = (B64_to_Hex -id2convert $publicKey)
                    #Extract last 5 digits from SmesherID
                    $node.key = $publicKey2.substring($publicKey2.length - 5, 5)
                    $node.keyFull = $publicKey2
                }

                #Uncomment next line if your Smapp using standard configuration -- 2 of 2
                #}  
            }
                               
            $o = [PSCustomObject]@{
                Name        = $node.name
                SmesherID   = $node.key
                Host        = $node.host
                Port        = $node.port
                PortPrivate = $node.port2
                Peers       = $node.connectedPeers
                SU          = $node.numUnits
                SizeTiB     = $node.numUnits * 64 * 0.001
                Synced      = $node.synced
                Layer       = $node.syncedLayer
                Top         = $node.topLayer
                Verified    = $node.verifiedLayer
                Version     = $node.version
                Smeshing    = $node.smeshing
                RWD         = $node.rewards
                ATX         = $node.atx
                
            } 
            $object += $o
            $totalLayers = $totalLayers + $node.rewards
            if ($node.layers) {
                if ($fileFormat -eq 1) {
					$rewardsTrackApp = @(@{$node.keyFull = $node.layers })
					Write-Output $rewardsTrackApp | ConvertTo-Json -depth 100 | Out-File -FilePath RewardsTrackApp.tmp -Append
                }
                elseif ($fileFormat -eq 2) {
                    $nodeData = [ordered]@{
                        "nodeName"      = $node.name; 
                        "nodeID"        = $node.keyFull; 
                        "eligibilities" = $layers
                    }
                    $rewardsTrackApp += $nodeData
                }
                elseif ($fileFormat -eq 3) {
                    $layers = $eligibility.eligibilities | ForEach-Object { $_.layer }
                    $layers = $layers | Sort-Object
                    $layersString = $layers -join ','
                    $nodeData = [ordered]@{
                        "nodeName"      = $node.name;
                        "eligibilities" = $layersString
                    }
                    $rewardsTrackApp += $nodeData
                }
            }
        }
        if ($rewardsTrackApp -and ($fileFormat -ne 0)) {
			$files = Get-ChildItem -Path .\ -Filter "RewardsTrackApp_*.json"
			foreach ($file in $files) {
				Remove-Item $file.FullName
			}
   			$timestamp = Get-Date -Format "HHmm"
            if ($fileFormat -eq 1) {
                $data = (Get-Content RewardsTrackApp.tmp -Raw) -replace '(?m)}\s+{', ',' |ConvertFrom-Json
				$data | ConvertTo-Json -Depth 99 | Set-Content "RewardsTrackApp_$timestamp.json"
				Remove-Item ".\RewardsTrackApp.tmp"
            }
            elseif ($fileFormat -eq 2) {
                $rewardsTrackApp | ConvertTo-Json -Depth 99 | Set-Content "RewardsTrackApp_$timestamp.json"
            }
			elseif (($fileFormat -eq 3)) {
				$rewardsTrackApp | ConvertTo-Json -Depth 99 | Set-Content "SM-Layers.json"
			}
        }
			
        # Find all private nodes, then select the first in the list.  Once we have this, we know that we have a good Online Local Private Node
        $filterObjects = $object | Where-Object { $_.Synced -match "True" -and $_.Smeshing -match "True" } # -and $_.Host -match "localhost" 
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $filterObjects = $filterObjects | Where-Object { $_.Host -match "localhost" -or $_.Host -match "127.0.0.1" }
        }
        if ($filterObjects) {
            $privateOnlineNodes = $filterObjects[0]
        }
        else {
            $privateOnlineNodes = $null
        }
        
        # If private nodes are found, determine the PS version and execute corresponding grpcurl if statement. Else skip.
        if ($privateOnlineNodes.name.count -gt 0) {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $coinbase = (Invoke-Expression "$grpcurl --plaintext -max-time 10 $($privateOnlineNodes.Host):$($privateOnlineNodes.PortPrivate) spacemesh.v1.SmesherService.Coinbase" | ConvertFrom-Json).accountId.address
                $jsonPayload = "{ `"filter`": { `"account_id`": { `"address`": `"$coinbase`" }, `"account_data_flags`": 4 } }"
                $balance = (Invoke-Expression "$grpcurl -plaintext -d '$jsonPayload' $($privateOnlineNodes.Host):$($privateOnlineNodes.Port) spacemesh.v1.GlobalStateService.AccountDataQuery" | ConvertFrom-Json).accountItem.accountWrapper.stateCurrent.balance.value
                $balanceSMH = [string]([math]::Round($balance / 1000000000, 3)) + " SMH"
                $coinbase = "($coinbase)" 
                if ($fakeCoins -ne 0) { [string]$balanceSMH = "$($fakeCoins) SMH" }
            }
            elseif ($PSVersionTable.PSVersion.Major -eq 5) {
                $coinbase = (Invoke-Expression "$grpcurl --plaintext -max-time 10 $($privateOnlineNodes.Host):$($privateOnlineNodes.PortPrivate) spacemesh.v1.SmesherService.Coinbase" | ConvertFrom-Json).accountId.address
                $command = { & $grpcurl -d '{\"filter\":{\"account_id\":{\"address\":\"$coinbase\"},\"account_data_flags\":4}}' -plaintext localhost:$($privateOnlineNodes.Port) spacemesh.v1.GlobalStateService.AccountDataQuery }
                $command = $command -replace '\$coinbase', $coinbase
                $balance = (Invoke-Expression $command | ConvertFrom-Json).accountItem.accountWrapper.stateCurrent.balance.value
                $balanceSMH = [string]([math]::Round($balance / 1000000000, 3)) + " SMH"
                $coinbase = "($coinbase)" 
                if ($fakeCoins -ne 0) { [string]$balanceSMH = "$($fakeCoins) SMH" }
            }
            if ($coinbaseAddressVisibility -eq "partial") {
                $coinbase = '(' + $($coinbase).Substring($($coinbase).IndexOf(")") - 4, 4) + ')'
            }
            elseif ($coinbaseAddressVisibility -eq "hidden") {
                $coinbase = "(----)"
            }
        }
        else {
            $coinbase = ""
            $balanceSMH = "You must have at least one synced 'localhost' node defined...or Install PowerShell 7"
        }
        
        if ($smhCoinsVisibility -eq $false) {
            $balanceSMH = "----.--- SMH"
        }
        
        Clear-Host
        $object | Select-Object Name, SmesherID, Host, Port, Peers, SU, SizeTiB, Synced, Layer, Top, Verified, Version, Smeshing, RWD, ATX | ColorizeMyObject -ColumnRules $columnRules
        Write-Host `n
        Write-Host "-------------------------------------- Info: -----------------------------------" -ForegroundColor Yellow
        Write-Host "Current Epoch: " -ForegroundColor Cyan -nonewline; Write-Host $epoch.number -ForegroundColor Green
        if ($null -ne $resultsNodeHighestATX) {
            Write-Host "  Highest ATX: " -ForegroundColor Cyan -nonewline; Write-Host (B64_to_Hex -id2convert $resultsNodeHighestATX.id.id) -ForegroundColor Green
        }
        Write-Host "ATX Base64_ID: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.id.id -ForegroundColor Green
        Write-Host " Total Layers: " -ForegroundColor Cyan -nonewline; Write-Host ($totalLayers) -ForegroundColor Yellow -nonewline; Write-Host " Layers"
        Write-Host "      Balance: " -ForegroundColor Cyan -NoNewline; Write-Host "$balanceSMH" -ForegroundColor White -NoNewline; Write-Host " $($coinbase)" -ForegroundColor Cyan
        #Write-Host "        Layer: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.layer.number -ForegroundColor Green
        #Write-Host "     NumUnits: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.numUnits -ForegroundColor Green
        #Write-Host "      PrevATX: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.prevAtx.id -ForegroundColor Green
        #Write-Host "    SmesherID: " -ForegroundColor Cyan -nonewline; Write-Host $resultsNodeHighestATX.smesherId.id -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow

        Write-Host `n
        $newline = "`r`n"
            
        #Version Check
        if ($null -ne $gitVersion) {
            $currentVersion = $gitVersion -replace "[^.0-9]"
            Write-Host "Github Go-Spacemesh version: $($gitVersion)" -ForegroundColor Green
            foreach ($node in ($object | Where-Object { $_.synced -notmatch "Offline" })) {
                $node.version = $node.version -replace "[^.0-9]"
                if ([version]$node.version -lt [version]$currentVersion) {
                    Write-Host "Info:" -ForegroundColor White -nonewline; Write-Host " --> Some of your nodes are Outdated!" -ForegroundColor DarkYellow
                    break
                }
            }
        }		
                
        if ("Offline" -in $object.synced) {
            Write-Host "Info:" -ForegroundColor White -nonewline; Write-Host " --> Some of your nodes are Offline!" -ForegroundColor DarkYellow
            if ($emailEnable -eq "True" -And (isValidEmail($myEmail))) {
                $Body = "Warning, some nodes are offline!"
        
                foreach ($node in $nodeList) {
                    if (!$node.online) {
                        $Body = $body + $newLine + $node.name + " " + $node.Host + " " + $node.Smeshing 
                        if (!$node.emailsent) {
                            $OKtoSend = "True"
                            $node.emailsent = "True"
                        }
                    }
                }
                        
                if ($OKtoSend) {
                    $From = "001smmonitor@gmail.com"
                    $To = $myEmail
                    $Subject = "Your Spacemesh node is offline"
                    
                    # Define the SMTP server details
                    $SMTPServer = "smtp.gmail.com"
                    $SMTPPort = 587
                    $SMTPUsername = "001smmonitor@gmail.com"
                    $SMTPPassword = "uehd zqix qrbh gejb"
        
                    # Create a new email object
                    $Email = New-Object System.Net.Mail.MailMessage
                    $Email.From = $From
                    $Email.To.Add($To)
                    $Email.Subject = $Subject
                    $Email.Body = $Body
                    # Uncomment below to send HTML formatted email
                    #$Email.IsBodyHTML = $true
        
                    # Create an SMTP client object and send the email
                    $SMTPClient = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
                    $SMTPClient.EnableSsl = $true
                    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUsername, $SMTPPassword)
                    
                    Try {
                        $SMTPClient.Send($Email)
                    }
                    Catch {
                        Write-Host "oops! SMTP error, please check your settings." -ForegroundColor DarkRed
                    }
                    Finally {
                        Write-Host "Email sent..." -ForegroundColor DarkYellow
                        $OKtoSend = ""
                    }
                }
            }
        }
        
        $currentDate = Get-Date -Format HH:mm:ss
        # Refresh
        Write-Host `n                
        Write-Host "Last refresh: " -ForegroundColor Yellow -nonewline; Write-Host "$currentDate" -ForegroundColor Green;
        
        # Get original position of cursor
        $originalPosition = $host.UI.RawUI.CursorPosition
        
        # Refresh Timeout
        $iterations = [math]::Ceiling($tableRefreshTimeSeconds / 5)       
        for ($i = 0; $i -lt $iterations; $i++) {
            Write-Host -NoNewline "." -ForegroundColor Cyan
            Start-Sleep 5
        }
        $clearmsg = " " * ([System.Console]::WindowWidth - 1)  
        [Console]::SetCursorPosition($originalPosition.X, $originalPosition.Y)
        [System.Console]::Write($clearmsg) 
        [Console]::SetCursorPosition($originalPosition.X, $originalPosition.Y)
        Write-Host "Updating..." -NoNewline -ForegroundColor Cyan
    }
}
        
function IsValidEmail { 
    param([string]$Email)
    $Regex = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$'
        
    try {
        $obj = [mailaddress]$Email
        if ($obj.Address -match $Regex) {
            return $True
        }
        return $False
    }
    catch {
        return $False
    } 
}
        
function B64_to_Hex {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$id2convert
    )
    [System.BitConverter]::ToString([System.Convert]::FromBase64String($id2convert)).Replace("-", "")
}
function Hex_to_B64 {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
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
                            #break
                        }
                    }
                }
        
                $paddedValue = $propertyValue.PadRight($maxWidths[$header])
        
                if ($foregroundColor -or $backgroundColor) {
                    if ($backgroundColor) {
                        Write-Host $paddedValue -NoNewline -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
                    }
                    else {
                        Write-Host $paddedValue -NoNewline -ForegroundColor $foregroundColor
                    }
                }
                else {
                    Write-Host $paddedValue -NoNewline
                }
        
                Write-Host "  " -NoNewline
            }
            Write-Host ""
        }
    }
}
        
function printSMMonitorLogo {
    Clear-Host
    $foregroundColor = "Green"
    $highlightColor = "Yellow"
    $charDelay = 0  # milliseconds
    $colDelay = 0  # milliseconds
    $logoWidth = 91  # Any time you change the logo, all rows have to be the exact width.  Then assign to this var.
    $logoHeight = 9  # Any time you change the logo, recount the rows and assign to this var.
        
    $screenWidth = $host.UI.RawUI.WindowSize.Width
    $screenHeight = $host.UI.RawUI.WindowSize.Height
    $horizontalOffset = [Math]::Max(0, [Math]::Ceiling(($screenWidth - $logoWidth) / 2))
    $verticalOffset = [Math]::Max(0, [Math]::Ceiling(($screenHeight - $logoHeight) / 2))
        
    $asciiArt = @"
              _________   _____               _____                 __  __                    
        /\   /   _____/  /     \             /     \   ____   ____ |__|/  |_  ___________   /\
        \/   \_____  \  /  \ /  \   ______  /  \ /  \ /  _ \ /    \|  \   __\/  _ \_  __ \  \/
        /\   /        \/    Y    \ /_____/ /    Y    (  <_> )   |  \  ||  | (  <_> )  | \/  /\
        \/  /_______  /\____|__  /         \____|__  /\____/|___|  /__||__|  \____/|__|     \/
                \/         \/                  \/            \/                               
                    _____________________________________________________________________     
                   /_____/_____/_____/_____/_____/  https://github.com/xeliuqa/SM-Monitor     
                                                                 https://www.spacemesh.io     
"@
    
    $lines = $asciiArt -split "`n"
                                                         
    for ($col = 1; $col -le $lines[0].Length; $col++) {
        for ($row = 1; $row -le $lines.Length; $row++) {
            $char = if ($col - 1 -lt $lines[$row - 1].Length) { $lines[$row - 1][$col - 1] } else { ' ' }
            $CursorPosition = [System.Management.Automation.Host.Coordinates]::new($col + $horizontalOffset, $row + $verticalOffset)
            $host.UI.RawUI.CursorPosition = $CursorPosition
            if ($char -eq ' ') {
                Write-Host $char -NoNewline
            }
            else {
                Write-Host $char -NoNewline -ForegroundColor $highlightColor
            }
            Start-Sleep -Milliseconds $charDelay
        }
        for ($row = 1; $row -le $lines.Length; $row++) {
            $char = if ($col - 1 -lt $lines[$row - 1].Length) { $lines[$row - 1][$col - 1] } else { ' ' }
            $CursorPosition = [System.Management.Automation.Host.Coordinates]::new($col + $horizontalOffset, $row + $verticalOffset)
            $host.UI.RawUI.CursorPosition = $CursorPosition
            if ($char -eq ' ') {
                Write-Host $char -NoNewline
            }
            else {
                Write-Host $char -NoNewline -ForegroundColor $foregroundColor
            }
        }
        Start-Sleep -Milliseconds $colDelay
    }
                                                         
    $CursorPosition = [System.Management.Automation.Host.Coordinates]::new(0, $lines.Length + $verticalOffset + 1)
    $host.UI.RawUI.CursorPosition = $CursorPosition
    Start-Sleep $logoDelay
    Clear-Host
}
                                                         
main