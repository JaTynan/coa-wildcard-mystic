<#
One-time setup on the VM (run as administrator): serves the friends' download site with Windows' own web
server (IIS) on port 8088, for the Cloudflare tunnel to publish as https://wildcard.jtlab.cc.

  /           F:\wildcard-site  (page, launcher, launcher.json, manifest.json)
  /client/    F:\CoAClient      (the client files the launcher updates from; personal folders blocked)

The firewall rule only lets the Docker VM (the tunnel) reach the port.
#>
param(
    [string] $Site = 'F:\wildcard-site',
    [string] $Client = 'F:\CoAClient',
    [int] $Port = 8088,
    [string] $TunnelHost = '10.59.20.0/24'
)
$ErrorActionPreference = 'Stop'

foreach ($feature in 'IIS-WebServerRole', 'IIS-WebServer', 'IIS-StaticContent', 'IIS-RequestFiltering', 'IIS-ManagementConsole') {
    if ((Get-WindowsOptionalFeature -Online -FeatureName $feature).State -ne 'Enabled') {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart | Out-Null
    }
}
Import-Module WebAdministration
New-Item -ItemType Directory -Force -Path $Site | Out-Null

if (Get-Website -Name 'Wildcard' -ErrorAction SilentlyContinue) { Remove-Website -Name 'Wildcard' }
New-Website -Name 'Wildcard' -Port $Port -PhysicalPath $Site -Force | Out-Null
New-WebVirtualDirectory -Site 'Wildcard' -Name 'client' -PhysicalPath $Client -Force | Out-Null

$psPath = 'IIS:\Sites\Wildcard'
# Serve every file type (client files have extensions IIS does not know), and allow names with + and spaces.
Add-WebConfigurationProperty -PSPath $psPath -Filter 'system.webServer/staticContent' -Name '.' -Value @{ fileExtension = '.*'; mimeType = 'application/octet-stream' } -ErrorAction SilentlyContinue
Set-WebConfigurationProperty -PSPath $psPath -Filter 'system.webServer/security/requestFiltering' -Name 'allowDoubleEscaping' -Value $true
Set-WebConfigurationProperty -PSPath $psPath -Filter 'system.webServer/security/requestFiltering/requestLimits' -Name 'maxAllowedContentLength' -Value 4294967295
Set-WebConfigurationProperty -PSPath $psPath -Filter 'system.webServer/directoryBrowse' -Name 'enabled' -Value $false
foreach ($blocked in 'WTF', 'Cache', 'Logs', 'Errors', 'Screenshots') {
    Add-WebConfigurationProperty -PSPath "$psPath/client" -Filter 'system.webServer/security/requestFiltering/hiddenSegments' -Name '.' -Value @{ segment = $blocked } -ErrorAction SilentlyContinue
}
# IIS needs read access to both folders.
foreach ($folder in $Site, $Client) {
    $acl = Get-Acl $folder
    $rule = New-Object Security.AccessControl.FileSystemAccessRule('IIS_IUSRS', 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule); Set-Acl $folder $acl
}

Get-NetFirewallRule -DisplayName 'Wildcard site' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'Wildcard site' -Direction Inbound -Protocol TCP -LocalPort $Port -RemoteAddress $TunnelHost -Action Allow | Out-Null

Start-Website -Name 'Wildcard'
"The Wildcard site is served on port $Port. Publish it with Publish-WildcardSite.ps1, then add the tunnel route."
