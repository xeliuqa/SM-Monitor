#Requires -Version 7.0
<#  -----------------------------------------------------------------------------------------------
<#PSScriptInfo    
.VERSION 4.02
.GUID 98d4b6b6-00e1-4632-a836-33767fe196cd
.AUTHOR
.PROJECTURI https://github.com/xeliuqa/SM-Monitor

SM-Monitor: https://github.com/xeliuqa/SM-Monitor
Based on: https://discord.com/channels/623195163510046732/691261331382337586/1142174063293370498
	  and also: https://github.com/PlainLazy/crypto/blob/main/sm_watcher.ps1
	
With Thanks To: == S A K K I == Stizerg == PlainLazy == Shanyaa == Miguell
	for the various contributions in making this script awesome

Get grpcurl here: https://github.com/fullstorydev/grpcurl/releases
	-------------------------------------------------------------------------------------------- #>
$version = "4.02"
$host.ui.RawUI.WindowTitle = $MyInvocation.MyCommand.Name

function main {
    # Import Configs
    $settingsFile = ".\sm-configs.ps1"
    if (Test-Path $settingsFile) {
        . $settingsFile
    }
    else {
        Write-Host "Error: sm-configs.ps1 not found." -ForegroundColor Red
        Write-Host "Press any key to continue ..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    # Import NodeList
    $nodeListFile = ".\sm-nodeList.txt"
    if (Test-Path $nodeListFile) {
        $nodeListContent = Get-Content $nodeListFile
        $nodeList = @()
        foreach ($line in $nodeListContent) {
            if ($line.Trim() -ne "" -and $line[0] -ne "#") {
                $nodeInfo = $line -split ","
                $node = @{
                    name  = $nodeInfo[0].Trim()
                    host  = if ($nodeInfo.Count -ge 2) {$nodeInfo[1].Trim()} else {"localhost"}
                    port  = if ($nodeInfo.Count -ge 3 -and [int32]::TryParse($nodeInfo[2].Trim(), [ref]$null)) {[int]$nodeInfo[2].Trim()} else {9092}
                    port2 = if ($nodeInfo.Count -ge 4 -and [int32]::TryParse($nodeInfo[3].Trim(), [ref]$null)) {[int]$nodeInfo[3].Trim()} else {9093}
                    port3 = if ($nodeInfo.Count -ge 5 -and [int32]::TryParse($nodeInfo[4].Trim(), [ref]$null)) {[int]$nodeInfo[4].Trim()} else {9094}
                    su    = if ($nodeInfo.Count -ge 6 -and [int32]::TryParse($nodeInfo[5].Trim(), [ref]$null)) {[int]$nodeInfo[5].Trim()} else {0}
                }
                $nodeList += $node
            }
        }
    }
    else {
        Write-Host "Error: sm-nodeList.txt not found." -ForegroundColor Red
        Write-Host "Press any key to continue ..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }

    $syncNodes = [System.Collections.Hashtable]::Synchronized(@{})
    [System.Console]::CursorVisible = $false
    [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    $ErrorActionPreference = 'SilentlyContinue' # 'Inquire', 'SilentlyContinue'
    $OneHourTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $tableRefreshTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $stage = 2 # 0 to ignore stages or 2 for initial stages

    printSMMonitorLogo
    
    $gitVersion = Get-gitNewVersion
	$gitNewMonitorVersion = Get-gitNewMonitorVersion
    
    if (Test-Path ".\RewardsTrackApp.tmp") {
        Clear-Content ".\RewardsTrackApp.tmp"
    }
    
    $nodeList | ForEach-Object { $syncNodes[$_.name] = $_ }
    
    while ($true) {

        $object = @()
        $epoch = $null
        $totalLayers = $null
        $rewardsTrackApp = @()
    
        $syncNodes.Values | ForEach-Object -ThrottleLimit 16 -Parallel {
            $node = $_
            $grpcurl = $using:grpcurl
            $syncNodesCopy = $using:syncNodes

            if (($using:stage -ne 1) -and ($using:stage -ne 4) -and ($node.port -ne 0) -and ($node.port2 -ne 0)) {
                $status = $null
                $status = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 10 $($node.host):$($node.port) spacemesh.v1.NodeService.Status")) | ConvertFrom-Json).status  2>$null
    
                if ($status) {
                    $node.online = "True"
					$node.status = "Online"
                    $node.connectedPeers = $status.connectedPeers
                    $node.syncedLayer = $status.syncedLayer.number
                    $node.topLayer = $status.topLayer.number
                    $node.verifiedLayer = $status.verifiedLayer.number
                    $publicKeys = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port2) spacemesh.v1.SmesherService.SmesherIDs")) | ConvertFrom-Json) 2>$null
					if ($publicKeys.publicKeys.Count -eq 1) {
					$publicKey = $publicKeys.publicKeys[0]
					}
                    if (!$publicKeys) {
                        $publicKey = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port2) spacemesh.v1.SmesherService.SmesherID")) | ConvertFrom-Json).publicKey 2>$null
                    }
                    if ($publicKey) {
                        $node.publicKey = $publicKey
                    }
                    if ($status.isSynced) {
                        $node.synced = "True"
                        $node.emailsent = ""
                    }
                    else { $node.synced = "False" }
                }
                else {
                    $node.online = ""
                    $node.status = "Offline"
                    $node.synced = $null
                    $node.numUnits = $null
                    $node.connectedPeers = $null
                    $node.syncedLayer = $null
                    $node.topLayer = $null
                    $node.verifiedLayer = $null
                    $node.version = $null
                    $node.rewards = $null
                    $node.atx = $null
                    $node.ban = $null
                }
            }
    
            if ($node.online -and ($using:stage -ne 2) -and ($using:stage -ne 4) -and ($node.port -ne 0) -and ($node.port2 -ne 0)) {
    
                $node.epoch = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port) spacemesh.v1.MeshService.CurrentEpoch")) | ConvertFrom-Json).epochnum 2>$null
    
                $version = $null
                $version = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port) spacemesh.v1.NodeService.Version")) | ConvertFrom-Json).versionString.value  2>$null
    
                if ($null -ne $version) {
                    $node.version = $version
                }    

                $eventstream = (Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port2) spacemesh.v1.AdminService.EventsStream")) 2>$null
				if ($eventstream){
					$eventstream = $eventstream -split "`n" | Where-Object { $_ }
					$eligibilities = @()
					$atxPublished = @()
					$jsonObject = @()
					$poetWaitProof = @()
					foreach ($line in $eventstream) {
						if (($line -notmatch "^\s+") -and ($line -match "{")) {
							$jsonObject = @()
						}
						$jsonObject += $line
						if (($line -notmatch "^\s+") -and ($line -match "}")) {
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
				}

                $layers = @{}
                foreach ($eligibility in $eligibilities) {
                    if ($eligibility.epoch -eq $node.epoch.number) {
						$smesher = $eligibility.smesher
                        $layers[$smesher] = $eligibility.eligibilities
                    }
					if ($layers) {
						$node.layers = $layers
					}
				}
                 #foreach ($aPublished in $atxPublished) {
                   #  if ($aPublished.epoch -eq $node.epoch.number) {
                         
                     #}
                 #}
                $atxTarget = $atxPublished.target
                $poetWait = $poetWaitProof.target
                if ($atxTarget) {
                    $node.atx = $atxTarget
                }
                elseif ($poetWait ) {
                    #-and ($null -eq $layers)
                    $node.atx = $poetWait
                }
                else {
                    $node.atx = " -"
                }

                $smeshing = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port2) spacemesh.v1.SmesherService.IsSmeshing")) | ConvertFrom-Json)    2>$null
                if ($null -ne $smeshing.isSmeshing) { 
					if ($smeshing.isSmeshing -eq "true") {
						$node.status = "Smeshing" } 
					else { 
						$node.status = $smeshing.isSmeshing 
					}
				}
                
            }
            
            if ($node.online -and ($using:stage -ne 1) -and ($using:stage -ne 4) -and ($node.port -ne 0) -and ($node.port2 -ne 0)) {
                $state = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port2) spacemesh.v1.SmesherService.PostSetupStatus")) | ConvertFrom-Json).status 2>$null
    
                if ($state) {
                    $node.numUnits = $state.opts.numUnits
    
                    if ($state.state -eq "STATE_IN_PROGRESS") {
                        $percent = [math]::round(($state.numLabelsWritten / 1024 / 1024 / 1024 * 16) / ($state.opts.numUnits * 64) * 100, 2)
                        $node.status = "$($percent)%"
                    }
                }
            }

            if (($using:checkIfBanned -eq "True") -and ($using:stage -ne 2) -and ($using:stage -ne 4) -and ($node.port -ne 0) -and ($node.port2 -ne 0)) {
                if ($node.publicKey) {
                    $publicKeylow = [System.BitConverter]::ToString([System.Convert]::FromBase64String($node.publicKey)).Replace("-", "").ToLower()
                    $response = (Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port) spacemesh.v1.MeshService.MalfeasanceStream")) 2>$null
                    if ($response -match "MALFEASANCE_HARE") {
                        if ($response -match $publicKeylow) {
                            if ($using:utf8 -eq "False") { $node.ban = " X" } else { $node.ban = "`u{1F480}" } #"yes"
                        }
                        else {
                            if ($using:utf8 -eq "False") { $node.ban = " OK" } else { $node.ban = "`u{1f197}" } #"no"
                        }
                    }
                    else { $node.ban = "" }
                }
                else { $node.ban = " -" }
            }
			
			if (($node.port -ne 0) -and ($node.port2 -ne 0) -and ($node.port3 -ne 0)) {
				$node.post = @{}
                $states = ((Invoke-Expression ("$($grpcurl) --plaintext -max-time 5 $($node.host):$($node.port3) spacemesh.v1.PostInfoService.PostStates")) | ConvertFrom-Json).states 2>$null
				if ($states) {
					foreach ($post in $states){
						$postName = ($post.name).Replace(".key", "")
						$node.post[$postName] = @{
						"state" = $post.state
						"id" = $post.id
						"node" = $node.name
						}
					}
				}
			}
			
			if (($using:stage -ne 2) -and ($node.port -eq 0) -and ($node.port2 -eq 0) -and ($node.port3 -ne 0)) {
				$postStatus = Invoke-Expression ("curl http://$($node.host):$($node.port3)/status") 2>$null
				if ($postStatus) {
                    if ($postStatus -match '^{.*}$') {
                        $postStatus = $postStatus | ConvertFrom-Json
                        if ($postStatus.PSObject.Properties.Name -contains "Proving") {
                            $provingPosition = $postStatus.Proving.position
                            $percent = [math]::round((($provingPosition / ($node.su * 68719476736)) * 100), 0)
                            $node.status = "Proving $($percent)%"
                        }
                    }
                    else {
                        $node.status = $postStatus.Replace("`"", "")
                    }
				}
				else {
					$node.status = "Offline"
				}
			}
			
            $syncNodesCopy[$_.name] = $node
        }
		
$postServices = @{}
$layers = @{}
foreach ($node in $syncNodes.Values) {
	if (($node.port -ne 0) -and ($node.port2 -ne 0)) {
        foreach ($name in $node.post.Keys) {
			if ($node.post[$name]){
            $postServices[$name] = $node.post[$name]
			}
        }
		if ($node.layers) {
			$layers +=  $node.layers
			$node.layers = $null
		}
	}
}

        $nodeList | ForEach-Object {
            $node = $syncNodes[$_.name]

            if ($epoch -lt $node.epoch.number) {
                $epoch = $node.epoch.number
            }
			
			foreach ($name in $postServices.Keys) {
				$post = $postServices[$name]
				if ($name -eq $node.name){
					$node.publicKey = $post.id
				}
			}

			foreach ($key in $layers.Keys) {
				$layer = $layers[$name].layers
				if ($key -eq $node.publicKey){
					$node.rewards = $layers[$key].count
					$node.layers = $layers[$key]
				}
			}
			
			if (($node.su) -and (!$node.numUnits) -and ($node.port -eq 0)) {
				$node.numUnits = $node.su
			}
    
            if ($node.publicKey -and !$node.shortKey) {
                $node.fullkey = (B64_to_Hex -id2convert $node.publicKey)
                # Extract last 5 digits from SmesherID
                $node.shortKey = $node.fullkey.substring($node.fullkey.length - 5, 5)
            }
    
            $totalLayers = $totalLayers + $node.rewards
            if ($node.layers) {
                if ($fileFormat -eq 1) {
                    $rewardsTrackApp = @(@{$node.fullkey = $node.layers })
                    Write-Output $rewardsTrackApp | ConvertTo-Json -depth 100 | Out-File -FilePath RewardsTrackApp.tmp -Append
                }
                elseif ($fileFormat -eq 2) {
                    $nodeData = [ordered]@{
                        "nodeName"      = $node.name;
                        "nodeID"        = $node.fullkey;
                        "eligibilities" = $node.layers
                    }
                    $rewardsTrackApp += $nodeData
                }
                elseif ($fileFormat -eq 3) {
                    $nodelayers = $node.layers | ForEach-Object { $_.layer }
                    $nodelayers = $nodelayers | Sort-Object
                    $layersString = $nodelayers -join ','
                    $nodeData = [ordered]@{
                        "nodeName"      = $node.name;
                        "eligibilities" = $layersString
                    }
                    $rewardsTrackApp += $nodeData
                }
            }
            
            if ($node.topLayer -gt $topLayer) {
                $topLayer = $node.topLayer
            }
    
            $o = [PSCustomObject]@{
                Name     = $node.name
                NodeID   = $node.shortKey
                Host     = $node.host
                Port     = $node.port
                Port2    = $node.port2
                Port3    = $node.port3
                Peers    = $node.connectedPeers
                SU       = $node.numUnits
                SizeTiB  = if ($null -eq $node.numUnits -or $node.numUnits -eq 0) { $null } else { [Math]::Round($node.numUnits * 64 * 0.0009765625, 3) }
                Synced   = $node.synced
                Layer    = $node.syncedLayer
                Top      = $node.topLayer
                Verified = $node.verifiedLayer
                Version  = $node.version
                Status = $node.status
                RWD      = $node.rewards
                ELG      = $node.atx
                BAN      = $node.ban
            }
	
            $object += $o
        }
		
        if ($rewardsTrackApp -and ($fileFormat -ne 0)) {
            $files = Get-ChildItem -Path .\ -Filter "RewardsTrackApp_*.json"
            foreach ($file in $files) {
                Remove-Item $file.FullName
            }
            $timestamp = Get-Date -Format "HHmm"
            if ($fileFormat -eq 1) {
                $data = (Get-Content RewardsTrackApp.tmp -Raw) -replace '(?m)}\s+{', ',' | ConvertFrom-Json
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
    
        if (($showWalletBalance -eq "True") -and ($stage -lt 2)) {
            # Find all private nodes, then select the first in the list.  Once we have this, we know that we have a good Online Local Private Node
            $filterObjects = $object | Where-Object { $_.Synced -match "True"} # -and $_.Host -match "localhost" -and $_.status -match "True"
            if ($filterObjects) {
                $privateOnlineNodes = $filterObjects[0]
            }
            else {
                $privateOnlineNodes = $null
            }
    
            # If private nodes are found, determine the PS version and execute corresponding grpcurl if statement. Else skip.
            if ($privateOnlineNodes.name.count -gt 0) {
                $coinbase = (Invoke-Expression "$grpcurl --plaintext -max-time 10 $($privateOnlineNodes.Host):$($privateOnlineNodes.Port2) spacemesh.v1.SmesherService.Coinbase" | ConvertFrom-Json).accountId.address
                $jsonPayload = "{ `"filter`": { `"account_id`": { `"address`": `"$coinbase`" }, `"account_data_flags`": 4 } }"
                $balance = (Invoke-Expression "$grpcurl -plaintext -d '$jsonPayload' $($privateOnlineNodes.Host):$($privateOnlineNodes.Port) spacemesh.v1.GlobalStateService.AccountDataQuery" | ConvertFrom-Json).accountItem.accountWrapper.stateCurrent.balance.value
                $balanceSMH = [string]([math]::Round($balance / 1000000000, 3)) + " SMH"
                $coinbase = "($coinbase)"
                if ($fakeCoins -ne 0) { [string]$balanceSMH = "$($fakeCoins) SMH" }
                if ($coinbaseAddressVisibility -eq "partial") {
                    $coinbase = '(' + $($coinbase).Substring($($coinbase).IndexOf(")") - 4, 4) + ')'
                }
                elseif ($coinbaseAddressVisibility -eq "hidden") {
                    $coinbase = "(----)"
                }
            }
            else {
                $coinbase = ""
                $balanceSMH = "Unable to retrieve the balance at the moment"
            }
        }
    
        $columnRules = applyColumnRules
    
        Clear-Host
        $object | ForEach-Object {
            $props = 'Name', 'Host'
            if ($ShowPorts -eq "True") { $props += 'Port', 'Port2','Port3' }
            $props += 'Peers', 'Synced', 'Layer', 'Verified', 'Version', 'Status', 'NodeID', 'SU', 'SizeTiB', 'RWD'
            #if ($showELG -eq "True") { $props += 'ELG' }
            #if ($checkIfBanned -eq "True") { $props += 'BAN' }
            $_ | Select-Object $props
        } | ColorizeMyObject -ColumnRules $columnRules
        #$object | Select-Object Name, NodeID, Host, Port, Peers, SU, SizeTiB, Synced, Top, Verified, Version, status, RWD, ELG, BAN | ColorizeMyObject -ColumnRules $columnRules
            
        $tableRefreshTimer.Restart()
    
        if (($queryHighestAtx -eq "True") -and ($null -eq $highestAtxJob) -and ($null -eq $highestAtx)) {
            $syncedNode = $syncNodes.Values | Where-Object { $_.synced -eq "True" } | Select-Object -First 1
            if ($syncedNode) {
                $highestAtxJob = Start-Job -ScriptBlock {
                    param($syncedNode, $grpcurl)
                    $result = & $grpcurl --plaintext "$($syncedNode.host):$($syncedNode.port)" spacemesh.v1.ActivationService.Highest
                    return $result
                } -ArgumentList $syncedNode, $grpcurl
            }
        }
        if ($highestAtxJob.State -eq "Completed") {
            #$highestAtxJob | Wait-Job -Timeout 30 | Out-Null
            $jobResult = $highestAtxJob | Receive-Job
            $highestAtx = ($jobResult | ConvertFrom-Json).atx
            $highestAtxJob = $null
        }
    
        Write-Host `n
    
        Write-Host "-------------------------------------- Info: -----------------------------------" -ForegroundColor Yellow
        if ($epoch) {
            Write-Host "Current Epoch: " -ForegroundColor Cyan -nonewline; Write-Host $epoch -ForegroundColor Green
        }
        if ($topLayer) {
            Write-Host "Current Layer:" -ForegroundColor Cyan -nonewline; Write-Host $topLayer -ForegroundColor Green
        }
        if ($totalLayers) {
            Write-Host "Total Layers: " -ForegroundColor Cyan -nonewline; Write-Host ($totalLayers) -ForegroundColor Yellow -nonewline; Write-Host " Layers"
        }
        if ($showWalletBalance -eq "True") {
            Write-Host "Balance: " -ForegroundColor Cyan -NoNewline; Write-Host "$balanceSMH" -ForegroundColor White -NoNewline; Write-Host " $($coinbase)" -ForegroundColor Cyan
        }
        if ($highestAtx) {
            Write-Host "Highest ATX: " -ForegroundColor Cyan -nonewline; Write-Host (B64_to_Hex -id2convert $highestAtx.id.id) -ForegroundColor Green
        }
        else {
            if ($highestAtxJob) {
                Write-Host "Highest ATX: " -ForegroundColor Cyan -nonewline; Write-Host "updating ... " -ForegroundColor DarkGray
            }
        }
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow
        #Write-Host "ELG - The number of Epoch when the node will be eligible for rewards. " -ForegroundColor DarkGray
        Write-Host `n
		
        #SM-Monitor Version Check
        if (($gitNewMonitorVersion) -and ($stage -ne 2)) {
            $taglist = ($gitNewMonitorVersion -split "-")[0] -replace "[^.0-9]"
            if ([version]$version -lt [version]$taglist) {
                Write-Host "Info:" -ForegroundColor White -nonewline; Write-Host " --> New sm-monitor update avaiable! $($taglist)" -ForegroundColor DarkYellow
				Write-Host `n
            }       
        }
    
        #Version Check
        if (($gitVersion) -and ($stage -ne 2)) {
            $currentVersion = ($gitVersion -split "-")[0] -replace "[^.0-9]"
            foreach ($node in ($object | Where-Object { (($_.status -notmatch "Offline") -and ($_.status)) })) {
                $node.version = ($node.version -split "-")[0] -replace "[^.0-9]"
                if ([version]$node.version -lt [version]$currentVersion) {
                    Write-Host "Github Go-Spacemesh version: $($gitVersion)" -ForegroundColor Green
                    Write-Host "Info:" -ForegroundColor White -nonewline; Write-Host " --> Some of your nodes are Outdated!" -ForegroundColor DarkYellow
					Write-Host `n
                    break
                }
            }
        }
		
		$newline = "`r`n"
        $nodesOffline = $null
		foreach ($node in $object| Where-Object { (($_.status -match "Offline") -and ($_.port -ne 0)  -and ($stage -ne 2)) }) {
			$nodesOffline = $true
            break
		}
        if ($nodesOffline) {
            Write-Host "Info:" -ForegroundColor White -nonewline; Write-Host " --> Some of your nodes are Offline!" -ForegroundColor DarkYellow
			Write-Host `n
            if ($emailEnable -eq "True" -And (isValidEmail($myEmail))) {
                $Body = "Warning, some nodes are offline!"
    
                foreach ($node in $syncNodes.Values) {
                    if (!$node.online) {
                        $Body = $body + $newLine + $node.name + " " + $node.Host + " " + $node.status
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
						Write-Host `n
                    }
                    Finally {
                        Write-Host "Email sent..." -ForegroundColor DarkYellow
                        Write-Host `n
                        $OKtoSend = ""
                    }
                }
            }
        }
    
        if ($stage -ne 2) {
            $currentDate = Get-Date -Format HH:mm:ss
            # Refresh
            Write-Host "Press SPACE to refresh" -ForegroundColor DarkGray
            Write-Host "Last refresh:  " -ForegroundColor Yellow -nonewline; Write-Host "$currentDate" -ForegroundColor Green 
        }
            
        # Get original position of cursor
        $originalPosition = $host.UI.RawUI.CursorPosition
        $relativeCursorPosition = New-Object System.Management.Automation.Host.Coordinates
    
        $clearmsg = " " * ([System.Console]::WindowWidth - 1)
        if ($utf8 -eq "False") {
            $frames = @("|", "/", "-", "\") 
        }
        else {
            $frames = @(
                "⢀⠀", "⡀⠀", "⠄⠀", "⢂⠀", "⡂⠀", "⠅⠀", "⢃⠀", "⡃⠀", "⠍⠀", "⢋⠀",
                "⡋⠀", "⠍⠁", "⢋⠁", "⡋⠁", "⠍⠉", "⠋⠉", "⠋⠉", "⠉⠙", "⠉⠙", "⠉⠩",
                "⠈⢙", "⠈⡙", "⢈⠩", "⡀⢙", "⠄⡙", "⢂⠩", "⡂⢘", "⠅⡘", "⢃⠨", "⡃⢐",
                "⠍⡐", "⢋⠠", "⡋⢀", "⠍⡁", "⢋⠁", "⡋⠁", "⠍⠉", "⠋⠉", "⠋⠉", "⠉⠙",
                "⠉⠙", "⠉⠩", "⠈⢙", "⠈⡙", "⠈⠩", "⠀⢙", "⠀⡙", "⠀⠩", "⠀⢘", "⠀⡘",
                "⠀⠨", "⠀⢐", "⠀⡐", "⠀⠠", "⠀⢀", "⠀⡀"
            )
        }
        $frameCount = $frames.Count
        if ($stage -eq 4) {
            $stage = 0
        }
        if ($stage -gt 0) {
            $stage = $stage - 1
        }

        :waitloop
        while ($stage -eq 0) {
            for ($i = 0; $i -lt $frames.Count; $i++) {
                $tableRefreshTimeElapsed = $tableRefreshTimer.Elapsed.TotalSeconds + 4
                if ($tableRefreshTimeElapsed -ge $tableRefreshTime) {
                    break waitloop
                }
                if ($highestAtxJob.State -eq "Completed") {
                    $stage = 4
                    break waitloop
                }
                if ([System.Console]::KeyAvailable) {
                    $key = [System.Console]::ReadKey($true)
                    if ($key.Key -eq "Spacebar") { break waitloop }
                    if ($key.Key -eq "R") {
                        main
                        return
                    }
                }
                $secondsLeft = ($tableRefreshTime - $tableRefreshTimeElapsed) -as [int]
                $frame = $frames[$i % $frameCount]
                $bufferHeight = $host.UI.RawUI.BufferSize.Height
                $relativeCursorPosition.Y = $originalPosition.Y - $host.UI.RawUI.WindowPosition.Y
                if ($bufferHeight -gt $relativeCursorPosition.Y) {
                    [Console]::SetCursorPosition(0, $relativeCursorPosition.Y)
                    [Console]::Write($clearmsg)
                    [Console]::SetCursorPosition(0, $relativeCursorPosition.Y)
                    Write-Host "Next refresh in: " -nonewline -ForegroundColor Yellow; Write-Host "$($secondsLeft.ToString().PadLeft(3, ' ')) $frame" -nonewline
                }
                Start-Sleep -Milliseconds 100
            }
        }
        $relativeCursorPosition.Y = $originalPosition.Y - $host.UI.RawUI.WindowPosition.Y
        [Console]::SetCursorPosition(0, $relativeCursorPosition.Y)
        [Console]::Write($clearmsg)
        [Console]::SetCursorPosition(0, $relativeCursorPosition.Y)
        Write-Host "Updating..." -NoNewline -ForegroundColor Yellow

        # Reset some variables every hour
        $OneHoursElapsed = $OneHourTimer.Elapsed.TotalHours
        if ($OneHoursElapsed -ge 1) {
            $gitNewVersion = Get-gitNewVersion
            if ($gitNewVersion) {
                $gitVersion = $gitNewVersion
            }
			$gitNewMonitorVersion = Get-gitNewMonitorVersion
            $highestAtx = $null
            $OneHourTimer.Restart()
        }
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
    
function Get-gitNewVersion {
    .{
        $gitNewVersion = Invoke-RestMethod -Method 'GET' -uri "https://api.github.com/repos/spacemeshos/go-spacemesh/releases/latest" 2>$null
        if ($gitNewVersion) {
            $gitNewVersion = $gitNewVersion.tag_name
        }
    } | Out-Null
    return $gitNewVersion
}

function Get-gitNewMonitorVersion {
    .{
        $tagList = Invoke-RestMethod -Method 'GET' -uri "https://api.github.com/repos/xeliuqa/SM-Monitor/releases/latest" 2>$null
        if ($tagList) {
            $tagList = $tagList.tag_name
        }
    } | Out-Null
    return $tagList
}
    
function printSMMonitorLogo {
    Clear-Host
    $foregroundColor = "Green"
    $highlightColor = "Yellow"
    $charDelay = 0  # milliseconds
    $colDelay = 0  # milliseconds
    $logoWidth = 86  # Any time you change the logo, all rows have to be the exact width.  Then assign to this var.
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
    # Start-Sleep $logoDelay
    # Clear-Host
}

function applyColumnRules {
    # Colors: Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow
    return  @(
        @{ Column = "Name"; Value = "*"; ForegroundColor = "Cyan"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "SmesherID"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Host"; Value = "*"; ForegroundColor = "White"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Port"; ForegroundColor = "White"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Peers"; Value = "*"; ForegroundColor = "DarkCyan"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Peers"; Value = "0"; ForegroundColor = "DarkGray"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "SU"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "SizeTiB"; Value = "*"; ForegroundColor = "White"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Synced"; Value = "True"; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Synced"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Synced"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Layer Top Verified"; Value = "*"; ForegroundColor = "White"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Version"; Value = "*"; ForegroundColor = "Red"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Version"; Value = $gitVersion; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Version"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Online"; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Idle"; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Idle*"; ForegroundColor = "Red"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Proving"; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Smeshing"; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "False"; ForegroundColor = "DarkRed"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "Status"; Value = "Offline"; ForegroundColor = "DarkGray"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "RWD"; Value = "*"; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "ELG"; Value = "*"; ForegroundColor = "Green"; BackgroundColor = $DefaultBackgroundColor },
        @{ Column = "ELG"; Value = "-"; ForegroundColor = "White"; BackgroundColor = $DefaultBackgroundColor }
        @{ Column = "ELG"; Value = $poetWait; ForegroundColor = "Yellow"; BackgroundColor = $DefaultBackgroundColor }
    )
}

main
