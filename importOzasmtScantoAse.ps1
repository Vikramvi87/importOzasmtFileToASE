param ($ozasmtFile,$scanName)
$aseHostname='xxxxxxxxxxxxxxxxx'
$aseApiKeyId='xxxxxxxxxxxxxxxxx'
$aseApiKeySecret='xxxxxxxxxxxxxxxxx'

# Load Ozasmt file in a variable and get the applicationname
[XML]$ozasmt = Get-Content $ozasmtFile;
$aseAppName=$ozasmt.assessmentrun.assessmentconfig.application.name
write-host "The application name is $aseAppName"
# ASE authentication
$sessionId=$(Invoke-WebRequest -Method "POST" -Headers @{"Accept"="application/json"} -ContentType 'application/json' -Body "{`"keyId`": `"$aseApiKeyId`",`"keySecret`": `"$aseApiKeySecret`"}" -Uri "https://$aseHostname`:9443/ase/api/keylogin/apikeylogin" -SkipCertificateCheck | Select-Object -Expand Content | ConvertFrom-Json | select -ExpandProperty sessionId);
# Looking for $aseAppName into ASE
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
$aseAppId=$(Invoke-WebRequest -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -Uri "https://$aseHostname`:9443/ase/api/applications/search?searchTerm=$aseAppName" -SkipCertificateCheck | ConvertFrom-Json).id;
# If $aseAppName is Null create the application into ASE else just get the aseAppId
if ([string]::IsNullOrWhitespace($aseAppId)){
	$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
	$session.Cookies.Add((New-Object System.Net.Cookie("asc_session_id", "$sessionId", "/", "$aseHostname")));
	$aseAppId=$(Invoke-WebRequest -Method POST -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId"} -ContentType "application/json" -Body "{`"name`":`"$aseAppName`" }" -Uri "https://$aseHostname`:9443/ase/api/applications" -SkipCertificateCheck | ConvertFrom-Json).id;
	echo "$aseAppId" > aseAppId.txt
	write-host "Application $aseAppName registered with id $aseAppId"
    }
else{
	write-host "There is a registered application."
	}

sleep 2	
Invoke-WebRequest -Method Post -Form @{"scanName"="$scanName";"uploadedfile"="$ozasmtFile"} -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId";"X-Requested-With"="XMLHttpRequest"}  -Uri "https://$aseHostname`:9443/ase/api/issueimport/$aseAppId/3/" -SkipCertificateCheck | Out-Null;

$ozasmtFile=$ozasmtFile.replace('.\','')
Rename-Item -Path "$ozasmtFile" -NewName "imported-$ozasmtFile"
write-host "$ozasmtFile file with scanName $scanName imported in Application $aseAppName";

Invoke-WebRequest -Method GET -WebSession $session -Headers @{"Asc_xsrf_token"="$sessionId";"X-Requested-With"="XMLHttpRequest"}  -Uri "https://$aseHostname`:9443/ase/api/logout" -SkipCertificateCheck | Out-Null;
