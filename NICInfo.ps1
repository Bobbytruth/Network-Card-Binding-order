###############################
#hartyr Binding order to text file
#Run 'Powershell -Command "c:\temp\Bindingtxt.ps1" > c:\temp\bindingout.txt 2>&1'
# Create server list in c:\servers.txt
#output c:\temp\bindingout.txt
###############################

#region Test-Host 

function Test-Host
{
        
    <#
        .Synopsis 
            Test a host for connectivity using either WMI ping or TCP port
            
        .Description
            Allows you to test a host for connectivity before further processing
            
        .Parameter Server
            Name of the Server to Process.
            
        .Parameter TCPPort
            TCP Port to connect to. (default 135)
            
        .Parameter Timeout
            Timeout for the TCP connection (default 1 sec)
            
        .Parameter Property
            Name of the Property that contains the value to test.
            
        .Example
            cat ServerFile.txt | Test-Host | Invoke-DoSomething
            Description
            -----------
            To test a list of hosts.
            
        .Example
            cat ServerFile.txt | Test-Host -tcp 80 | Invoke-DoSomething
            Description
            -----------
            To test a list of hosts against port 80.
            
        .Example
            Get-ADComputer | Test-Host -property dnsHostname | Invoke-DoSomething
            Description
            -----------
            To test the output of Get-ADComputer using the dnshostname property
            
            
        .OUTPUTS
            System.Object
            
        .INPUTS
            System.String
            
        .Link
            Test-Port
            
        NAME:      Test-Host
        AUTHOR:    YetiCentral\bshell
        Website:   www.bsonposh.com
        LASTEDIT:  02/04/2009 18:25:15
        #Requires -Version 2.0
    #>
    
    [CmdletBinding()]
    
    Param(
    
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Mandatory=$True)]
        [string]$ComputerName,
        
        [Parameter()]
        [int]$TCPPort,
        
        [Parameter()]
        [int]$timeout=3000,
        
        [Parameter()]
        [string]$property
        
    )
    Begin 
    {
    
        function PingServer 
        {
            Param($MyHost)
            $ErrorActionPreference = "SilentlyContinue"
            Write-Verbose " [PingServer] :: Pinging [$MyHost]"
            try
            {
                $pingresult = Get-WmiObject win32_pingstatus -f "address='$MyHost'"
                $ResultCode = $pingresult.statuscode
                Write-Verbose " [PingServer] :: Ping returned $ResultCode"
                if($ResultCode -eq 0) {$true} else {$false}
            }
            catch
            {
                Write-Verbose " [PingServer] :: Ping Failed with Error: ${error[0]}"
                $false
            }
        }
    
    }
    
    Process 
    {
    
        Write-Verbose " [Test-Host] :: Begin Process"
        if($ComputerName -match "(.*)(\$)$")
        {
            $ComputerName = $ComputerName -replace "(.*)(\$)$",'$1'
        }
        Write-Verbose " [Test-Host] :: ComputerName   : $ComputerName"
        if($TCPPort)
        {
            Write-Verbose " [Test-Host] :: Timeout  : $timeout"
            Write-Verbose " [Test-Host] :: Port     : $TCPPort"
            if($property)
            {
                Write-Verbose " [Test-Host] :: Property : $Property"
                $Result = Test-Port $_.$property -tcp $TCPPort -timeout $timeout
                if($Result)
                {
                    if($_){ $_ }else{ $ComputerName }
                }
            }
            else
            {
                Write-Verbose " [Test-Host] :: Running - 'Test-Port $ComputerName -tcp $TCPPort -timeout $timeout'"
                $Result = Test-Port $ComputerName -tcp $TCPPort -timeout $timeout
                if($Result)
                {
                    if($_){ $_ }else{ $ComputerName }
                } 
            }
        }
        else
        {
            if($property)
            {
                Write-Verbose " [Test-Host] :: Property : $Property"
                try
                {
                    if(PingServer $_.$property)
                    {
                        if($_){ $_ }else{ $ComputerName }
                    } 
                }
                catch
                {
                    Write-Verbose " [Test-Host] :: $($_.$property) Failed Ping"
                }
            }
            else
            {
                Write-Verbose " [Test-Host] :: Simple Ping"
                try
                {
                    if(PingServer $ComputerName){$ComputerName}
                }
                catch
                {
                    Write-Verbose " [Test-Host] :: $ComputerName Failed Ping"
                }
            }
        }
        Write-Verbose " [Test-Host] :: End Process"
    
    }
    
}
    
#endregion 
cls
$DhcpEN = 0
$servers = Get-Content "c:\temp\servers.txt" 
$NICcount = 0

#start-transcript "c:\temp\transcript.txt" 

foreach($server in $servers){
	$objReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server) 
	$objRegKey = $objReg.OpenSubKey("SYSTEM\\Currentcontrolset\\Services\\TCPIP\\Linkage" ) 
	$arrItem = $objRegKey.GetValue("Bind") 
 
	Write-Host "" 
	Write-Host "HostName : " $server.ToUpper() -ForegroundColor DarkRed


	foreach ($item in $arrItem) {  
    	$item = $item -replace "\\device\\", "" 
    	$objRegKey = $objReg.OpenSubKey("SYSTEM\\Currentcontrolset\\Control\Network\\{4D36E972-E325-11CE-BFC1-08002be10318}\\" + $item + "\\Connection")
		$objRegKeyIP = $objReg.OpenSubKey("SYSTEM\\Currentcontrolset\\Services\\TCPIP\\Parameters\\Interfaces\\" + $item )
		
		
		
    	if (!$objRegKey){
			$strBind = " "
		}else{
			$strBind = $objRegKey.GetValue("Name")
			$arrItemIP = $objRegKeyIP.GetValue("IPAddress")
			$NICdsbld = $objRegKeyIP.GetValue
		}
		If ($strBind -like "Local*"){
			#Write-Host "Not Labelled" -ForegroundColor Red 
    		Write-Host "NIC      : " $strBind + "Not Labelled" -ForegroundColor red 
			$WngBnd = 1
    	}elseif($strBind -eq " "){}
		elseif( ($strBind -like "Pro*") -or ($strBind -like "Team*")){
			Write-Host $NICcount "NIC      : " $strBind 
			$NICcount++
			$WngBnd = 1
		}elseif(($strBind -like "Bac*") -or ($strBind -like "Netb*")-and ($arrItemIP -ne "0.0.0.0")) {
			if ($WngBnd -eq 0) {Write-Host $NICcount "NIC      : " $strBind + "WRONG BINDING ORDER" -ForegroundColor Red}
			else   {Write-Host $NICcount "NIC      : " $strBind}
			$NICcount++
			$WngBnd = 0
		}elseif (($strBind -like "Heart*") -or ($strBind -like "HB*")-and ($arrItemIP -ne "0.0.0.0")){
			
			Write-Host $NICcount "NIC      : " $strBind
			$NICcount++
			$WngBnd = 2
		}elseif (($strBind -like "Wom*") -or ($strBind -like "Non*")-and ($arrItemIP -ne "0.0.0.0")){
			Write-Host $NICcount "NIC      : " $strBind
			$NICcount++
			#$WngBnd = 0
		}
		if(!$objRegKeyIP){
			#Write-Host "NULL" 
			$itemIP =$null
		}
		else{
			$arrItemIP = $objRegKeyIP.GetValue("IPAddress")
			$DhcpEN = $objRegKeyIP.GetValue("EnableDHCP")
			$DchpSrv = $objRegKeyIP.GetValue("DHCPServer")
	
			if ($arrItemIP -eq "0.0.0.0" -and $DhcpEN -eq 1 -and $DchpSrv -eq "10.117.76.5"-or $DchpSrv -eq "10.113.48.3"){
				$arrItemIP = $objRegKeyIP.GetValue("DhcpIPAddress")
				$DhcpEN = 1
    			}else {$DhcpEN = 0
				}
	
    			foreach ($itemIP in $arrItemIP) { 
        			If (($itemIP -eq "0.0.0.0") -or !$itemIP -and ($strBind -like "Local*")){ 
          			# Write-Host "IP       :  NOT ASSIGNED"  
        			}Elseif (($itemIP -eq "0.0.0.0") -or !$itemIP -and ($strBind -like "HB*" -or ($strBind -like "Heart*"))){
					}
					Elseif (($itemIP -eq "0.0.0.0") -or !$itemIP -and ($strBind -like "Netb*" -or ($strBind -like "Back*"))){
					}
        			Elseif ($DhcpEN -eq 1) {
		         		Write-Host "DHCPIP     : " $itemIP -ForegroundColor Red   
						$DhcpEN  = 0 
        			} else {
					Write-Host  "IP         : "  $itemIP
					}
	    		} 
		$DhcpEN  = 0
    	}
	} 
	$NICcount = 0
	$WngBnd = 0
}
#stop-transcript 

