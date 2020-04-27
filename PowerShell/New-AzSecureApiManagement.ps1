function  New-AzSecureApiManagement {
    <#
    .SYNOPSIS
        Creates a new secure API Management behind an Application Gateway with Web Application Firewall enabled.
    .DESCRIPTION
        This function creates the following components:
        - Resource Group (Optional, you can use your existing resource group)
        - Virtual network with three subnets
        - Network Security Group for each of the subnets, configured with the proper rules to allow typical traffic patterns
        - Key Vault for storing certificates used in the environment
        - API Management (either Internal or External), connected to the APIM Subnet, and with Custom Domain configuration and certificates saved in Key Vault
        - Public IP Address to recieve traffic from the internet
        - Application Gateway with Web Application Firewall component. The Application Gateway is configured to proxy traffic listened for on the Public IP Address with the specified hostnames to the API Management backend
        - Application Gateway User Managed Identity, to allow the Application Gateway to grab certificates from Key Vault
    .EXAMPLE
        Creates a new environment using self-signed certificates, these are created and signed by Key Vault. This is not recommended for a production environment.

        New-AzSecureApiManagement -ResourceGroupName "MyResouceGroup" -Location "WestEurope" -EnvironmentName "MyNewEnvironment" -VirtualNetworkCidr "10.0.1.0/23" -BackendSubnetCidr "10.0.1.0/24" -FrontendSubnetCidr "10.0.2.0/26" -ApimSubnetCidr "10.0.2.64/26" -ApimOrganizationName "MyOrganization" -ApimOrganizationEmail "myorg@email.com" -ApimSku "Developer" -ApimVpnType "Internal" -UseSelfSignedCertificates -ApimGatewayHostname "api.contoso.net" -ApimPortalHostname "portal.contoso.net" -IsWellKnownCA
    .EXAMPLE
        Creates a new environment using custom certificates purchased from a well-know CA (i.e. Thawte or Digicert or any other well-known CA).

        New-AzSecureApiManagement -ResourceGroupName "MyResouceGroup" -Location "WestEurope" -EnvironmentName "MyNewEnvironment" -VirtualNetworkCidr "10.0.1.0/23" -BackendSubnetCidr "10.0.1.0/24" -FrontendSubnetCidr "10.0.2.0/26" -ApimSubnetCidr "10.0.2.64/26" -ApimOrganizationName "MyOrganization" -ApimOrganizationEmail "myorg@email.com" -ApimSku "Developer" -ApimVpnType "External" -ApimGatewayHostname "api.contoso.net" -ApimPortalHostname "portal.contoso.net" -IsWellKnownCA -GatewayCertificate "gatewaycertificate.pfx" -GatewayCertificatePassword (ConvertTo-SecureString -AsPlainText -String "certpassword") -PortalCertificate "portalcertificate.pfx" -PortalCertificatePassword (ConvertTo-SecureString -AsPlainText -String "certpassword")
    .EXAMPLE
        Creates a new environment using custom certificates purchased a privately owned CA.
        
        New-AzSecureApiManagement -ResourceGroupName "MyResouceGroup" -Location "WestEurope" -EnvironmentName "MyNewEnvironment" -VirtualNetworkCidr "10.0.1.0/23" -BackendSubnetCidr "10.0.1.0/24" -FrontendSubnetCidr "10.0.2.0/26" -ApimSubnetCidr "10.0.2.64/26" -ApimOrganizationName "MyOrganization" -ApimOrganizationEmail "myorg@email.com" -ApimSku "Developer" -ApimVpnType "Internal" -ApimGatewayHostname "api.contoso.net" -ApimPortalHostname "portal.contoso.net" -CACertificate "cacert.cer" -GatewayCertificate "gatewaycertificate.pfx" -GatewayCertificatePassword (ConvertTo-SecureString -AsPlainText -String "certpassword") -PortalCertificate "portalcertificate.pfx" -PortalCertificatePassword (ConvertTo-SecureString -AsPlainText -String "certpassword")
    .LINK
        https://github.com/helshabini/New-AzSecureApiManagement
    #>
    param(
        [Parameter(Position=0,
        Mandatory=$true, 
        ValueFromPipeline=$False)]
        [String]$ResourceGroupName,

        [Parameter(Position=1,
        Mandatory=$true, 
        ValueFromPipeline=$False)]
        [String]$Location,

        [Parameter(Position=2,
        Mandatory=$true, 
        ValueFromPipeline=$False)]
        [ValidateLength(1,30)]
        [String]$EnvironmentName,

        [Parameter(Position=3,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String[]]$VirtualNetworkCidr,

        [Parameter(Position=4,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$BackendSubnetCidr,

        [Parameter(Position=5,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$FrontendSubnetCidr,

        [Parameter(Position=6,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$ApimSubnetCidr,

        [Parameter(Position=7,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$ApimOrganizationName,

        [Parameter(Position=8,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$ApimOrganizationEmail,

        [Parameter(Position=9,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$ApimSku="Developer",

        [Parameter(Position=10,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$ApimVpnType="External",

        [Parameter(Position=11,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [Switch]$UseSelfSignedCertificates=$False,

        [Parameter(Position=12,
        Mandatory=$True, 
        ValueFromPipeline=$False)]
        [String]$ApimGatewayHostname,

        [Parameter(Position=13,
        Mandatory=$True, 
        ValueFromPipeline=$False)]
        [String]$ApimPortalHostname,

        [Parameter(Position=14,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [Switch]$IsWellKnownCA=$False,

        [Parameter(Position=15,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$CACertificate,

        [Parameter(Position=16,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$GatewayCertificate,
        
        [Parameter(Position=17,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [String]$PortalCertificate,

        [Parameter(Position=18,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [SecureString]$GatewayCertificatePassword,

        [Parameter(Position=19,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [SecureString]$PortalCertificatePassword,

        [Parameter(Position=20,
        Mandatory=$False, 
        ValueFromPipeline=$False)]
        [Int]$ApplicationGatewayCapacity=2
    )
    begin {
        if ($UseSelfSignedCertificates -eq $False) {
            if (-not (Test-Path -Path $GatewayCertificate -PathType Leaf -Include "*.pfx")) {
                Write-Error "Gateway certificate must be a valid .pfx file."
            }
            if (-not (Test-Path -Path $PortalCertificate -PathType Leaf -Include "*.pfx")) {
                Write-Error "Portal certificate must be a valid .pfx file."
            }
            if ([string]::IsNullOrEmpty($GatewayCertificatePassword)) {
                Write-Error "Gateway certificate password must be provided."
            }
            if ([string]::IsNullOrEmpty($PortalCertificatePassword)) {
                Write-Error "Portal certificate password must be provided."
            }
            if (-not $IsWellKnownCA -and -not (Test-Path -Path $CACertificate -PathType Leaf -Include "*.cer")) {
                Write-Error "CA certificate must be a valid .cer file. If you are using certificates from a well known CA, use the -IsWellKnownCA switch."
            }
        }
        
        Install-Module -Name Az.ManagedServiceIdentity -Force
    }
    process {
        #Resource names
        $Random = Get-Random -Maximum 9999
        $vnetname = "vnet-" + $EnvironmentName + $Random
        $apimname = "apim-" + $EnvironmentName + $Random
        $keyvaultname = "kv-" + $EnvironmentName + $Random
        $appgwname = "agw-" + $EnvironmentName + $Random
        $appgwpublicipname = "pip-" + $EnvironmentName + $Random
        $backendsubnetnsgname = "nsg-BackendSubnet-" + $EnvironmentName + $Random
        $apimsubnetnsgname = "nsg-APIMSubnet-" + $EnvironmentName + $Random
        $frontendsubnetnsgname = "nsg-FrontendSubnet-" + $EnvironmentName + $Random

        #Network related inputs
        $vnetcidr = "10.1.12.0/23" #optional if vnet already exists
        $backendsubnetname = "BackendSubnet" #name of the subnet where the AKS will be deployed, subnet must be empty
        $backendsubnetcidr = "10.1.12.0/24" #optional if vnet already exists
        $apimsubnetname = "APIMSubnet" #name of the subnet where APIM will be deployed
        $apimsubnetcidr = "10.1.13.144/28" #optional if vnet already exists
        $frontendsubnetname = "FrontendSubnet" #name of the subnet where the Application Gateway will be deployed
        $frontendsubnetcidr = "10.1.13.224/28" #optional if vnet already exists

        #Key Vault related inputs
        $gatewaycertname = $EnvironmentName + $Random + "GatewayCert"
        $portalcertname = $EnvironmentName + $Random + "PortalCert"

        #Application Gateway related inputs
        $appgwipconfigname = "ipconfig-agw-" + $EnvironmentName + $Random
        $appgwfrontendportname = "feport-agw-" + $EnvironmentName + $Random
        $appgwfrontendipconfigname = "feipconfig-agw-" + $EnvironmentName + $Random
        $appgwgatewaylistenername = "apimgatewaylistener"
        $appgwportallistenername = "apimportallistener"
        $appgwapimgatewayprobename = "apimgatewayprobe"
        $appgwapimportalprobename = "apimportalprobe"
        $appgwapimwhitelistcertname = "apimwhitelistcert"
        $appgwapimbackendpoolname = "apimbackend"
        $appgwapimgatewaysettingname = "apimgatewaybackendsetting"
        $appgwapimportalsettingname = "apimportalbackendsetting"
        $appgwapimgatewayrulename = "apimgatewayrule"
        $appgwapimportalrulename = "apimportalrule"

        ############################################################################################
        ################## Creating Resource Groups and Networking Resources
        ############################################################################################

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-Not $rg) { 
            #Create resource group in specified region if it doesn't exit.
            $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        }

        Start-Sleep 3

        New-AzVirtualNetwork `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Name $vnetname `
            -AddressPrefix $vnetcidr

        Start-Sleep 3

        $clustervnet = Get-AzVirtualNetwork `
            -ResourceGroupName $ResourceGroupName `
            -Name $vnetname

        $clusternsg = New-AzNetworkSecurityGroup `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Name $backendsubnetnsgname

        Start-Sleep 3

        Add-AzVirtualNetworkSubnetConfig `
            -Name $backendsubnetname `
            -AddressPrefix $backendsubnetcidr `
            -VirtualNetwork $clustervnet `
            -NetworkSecurityGroup $clusternsg

        Start-Sleep 3

        $apimnsgrules = @()
        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowExternal" `
            -Description "Client communication to API Management." `
            -Priority 400 `
            -SourceAddressPrefix Internet `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange 80,443 `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowManagement" `
            -Description "Management endpoint for Azure portal and Powershell." `
            -Priority 410 `
            -SourceAddressPrefix ApiManagement `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange 3443 `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureStorage" `
            -Description "Dependency on Azure Storage." `
            -Priority 420 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix Storage `
            -SourcePortRange * `
            -DestinationPortRange 443 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureAD" `
            -Description "Dependency on Azure Active Directory." `
            -Priority 430 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix AzureActiveDirectory `
            -SourcePortRange * `
            -DestinationPortRange 443 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureSQL" `
            -Description "Dependency on Azure SQL." `
            -Priority 440 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix SQL `
            -SourcePortRange * `
            -DestinationPortRange 1433 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureEventHub" `
            -Description "Dependency for Log to Event Hub policy and monitoring agent." `
            -Priority 450 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix EventHub `
            -SourcePortRange * `
            -DestinationPortRange 5671,5672,443 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureFileShare" `
            -Description "Dependency on Azure File Share for GIT." `
            -Priority 460 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix Storage `
            -SourcePortRange * `
            -DestinationPortRange 445 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureHealth" `
            -Description "Needed to publish Health status to Resource Health." `
            -Priority 470 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix AzureCloud `
            -SourcePortRange * `
            -DestinationPortRange 1886 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowAzureMonitor" `
            -Description "Publish Diagnostics Logs and Metrics." `
            -Priority 480 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix AzureMonitor `
            -SourcePortRange * `
            -DestinationPortRange 443 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowSMTP" `
            -Description "Connect to SMTP Relay for sending e-mails." `
            -Priority 490 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix Internet `
            -SourcePortRange * `
            -DestinationPortRange 25,587,25028 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowRedisInbound" `
            -Description "Access Redis Service for Rate Limit policies between machines." `
            -Priority 500 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange 6381-6383 `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowRedisOutbound" `
            -Description "Access Redis Service for Rate Limit policies between machines." `
            -Priority 510 `
            -SourceAddressPrefix VirtualNetwork `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange 6381-6383 `
            -Protocol TCP `
            -Direction Outbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowLoadBalancer" `
            -Description "Azure Infrastructure Load Balancer." `
            -Priority 520 `
            -SourceAddressPrefix AzureLoadBalancer `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange * `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        $apimnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowGatewayManager" `
            -Description "Management traffic for deployments dedicated to Azure VPN Gateway and Application Gateway." `
            -Priority 530 `
            -SourceAddressPrefix GatewayManager `
            -DestinationAddressPrefix VirtualNetwork `
            -SourcePortRange * `
            -DestinationPortRange 80,443 `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        Start-Sleep 3

        $apimnsg = New-AzNetworkSecurityGroup `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Name $apimsubnetnsgname `
            -SecurityRules $apimnsgrules

        Start-Sleep 3

        Add-AzVirtualNetworkSubnetConfig `
            -Name $apimsubnetname `
            -AddressPrefix $apimsubnetcidr `
            -VirtualNetwork $clustervnet `
            -NetworkSecurityGroup $apimnsg

        Start-Sleep 3

        $frontendnsgrules = @()
        $frontendnsgrules += New-AzNetworkSecurityRuleConfig `
            -Name "AllowHTTPHTTPS" `
            -Description "Incoming HTTP/S traffic" `
            -Priority 400 `
            -SourceAddressPrefix Internet `
            -DestinationAddressPrefix GatewayManager `
            -SourcePortRange * `
            -DestinationPortRange 80,443 `
            -Protocol TCP `
            -Direction Inbound `
            -Access Allow

        Start-Sleep 3

        $frontendnsg = New-AzNetworkSecurityGroup `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Name $frontendsubnetnsgname `
            -SecurityRules $frontendnsgrules

        Start-Sleep 3

        Add-AzVirtualNetworkSubnetConfig `
            -Name $frontendsubnetname `
            -AddressPrefix $frontendsubnetcidr `
            -VirtualNetwork $clustervnet `
            -NetworkSecurityGroup $frontendnsg

        Start-Sleep 3

        $clustervnet | Set-AzVirtualNetwork

        $clustervnet = Get-AzVirtualNetwork `
            -ResourceGroupName $ResourceGroupName `
            -Name $vnetname

        Start-Sleep 10

        ############################################################################################
        ################## Creating Key Vault for Certificates
        ############################################################################################

        #Creating a new Key Vault
        New-AzKeyVault `
            -Name $keyvaultname `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -EnableSoftDelete

        Start-Sleep 3

        #Creating certificates for gateway and portal
        $gatewaypolicy = New-AzKeyVaultCertificatePolicy `
            -ValidityInMonths 12 `
            -SubjectName "CN="$ApimGatewayHostname -IssuerName self `
            -RenewAtNumberOfDaysBeforeExpiry 30
        $portalpolicy = New-AzKeyVaultCertificatePolicy `
            -ValidityInMonths 12 `
            -SubjectName "CN="$ApimPortalHostname -IssuerName self `
            -RenewAtNumberOfDaysBeforeExpiry 30
    
        Start-Sleep 3

        #Adding certificates to Key Vault
        $gatewaycert = Add-AzKeyVaultCertificate -VaultName $keyvaultname -Name $gatewaycertname  -CertificatePolicy $gatewaypolicy
        $portalcert = Add-AzKeyVaultCertificate -VaultName $keyvaultname -Name $portalcertname -CertificatePolicy $portalpolicy

        Start-Sleep 60

        #Getting reference to Key Vault certificates
        $gatewaycert = Get-AzKeyVaultCertificate -VaultName $keyvaultname -Name $gatewaycertname
        $portalcert = Get-AzKeyVaultCertificate -VaultName $keyvaultname -Name $portalcertname

        Start-Sleep 3

        #Getting Secret Id for certificate access
        $gatewaycertsecretid = $gatewaycert.SecretId.Replace($portalcert.Version, "")
        $portalcertsecretid = $portalcert.SecretId.Replace($portalcert.Version, "")

        Start-Sleep 10

        ############################################################################################
        ################## Creating API Management
        ############################################################################################

        $apimsubnet = $clustervnet.Subnets | Where-Object { $_.Name -eq $apimsubnetname }

        #Choosing the API Management network
        $apimnetwork = New-AzApiManagementVirtualNetwork `
            -SubnetResourceId $apimsubnet.Id

        Start-Sleep 3

        #Creating the API Management instance
        $apim = New-AzApiManagement `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Name $apimname `
            -Organization $ApimOrganizationName `
            -AdminEmail $ApimOrganizationEmail `
            -VirtualNetwork $apimnetwork `
            -Sku $ApimSku `
            -VpnType $ApimVpnType `
            -AssignIdentity

        Start-Sleep 10

        #Assinging key vault access policy for APIM System Assigned Managed Identity
        Set-AzKeyVaultAccessPolicy `
            -VaultName $keyvaultname `
            -PermissionsToSecrets get `
            -PermissionsToCertificates get,create,list `
            -ObjectId $apim.Identity.PrincipalId

        Start-Sleep 3

        #Creating hostname configuration for the gateway and portal
        $apimgatewayostnameconfig = New-AzApiManagementCustomHostnameConfiguration `
            -Hostname $ApimGatewayHostname `
            -HostnameType Proxy `
            -KeyVaultId $gatewaycertsecretid
        $apimportalhostnameconfig = New-AzApiManagementCustomHostnameConfiguration `
            -Hostname $ApimPortalHostname `
            -HostnameType DeveloperPortal `
            -KeyVaultId $portalcertsecretid

        Start-Sleep 3

        #Setting hostname configuration on the APIM
        $apim.ProxyCustomHostnameConfiguration = $apimgatewayostnameconfig
        $apim.PortalCustomHostnameConfiguration = $apimportalhostnameconfig

        #Applying configuration for APIM
        Set-AzApiManagement -InputObject $apim

        $apim = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $apimname

        Start-Sleep 10

        ############################################################################################
        ################## Creating Application Gateway
        ############################################################################################

        #Creating User Assigned Managed Identity for key vault
        $appgwuseridentity = New-AzUserAssignedIdentity `
            -Name $appgwname"identity" `
            -Location $Location `
            -ResourceGroupName $ResourceGroupName

        Start-Sleep 3

        #Assigning key vault access policy for App GW User Assigned Managed Identity
        Set-AzKeyVaultAccessPolicy -VaultName $keyvaultname `
            -PermissionsToSecrets get `
            -PermissionsToCertificates get,create,list `
            -ObjectId $appgwuseridentity.PrincipalId

        Start-Sleep 3

        $appgwidentity = New-AzApplicationGatewayIdentity `
            -UserAssignedIdentityId $appgwuseridentity.Id

        $appgwpublicip = New-AzPublicIpAddress `
            -ResourceGroupName $ResourceGroupName `
            -name $appgwpublicipname `
            -Location $Location `
            -AlLocationMethod Static `
            -Sku Standard

        Start-Sleep 3

        $frontendsubnet = $clustervnet.Subnets | Where-Object { $_.Name -eq $frontendsubnetname }

        $appgwipconfig = New-AzApplicationGatewayIPConfiguration `
            -Name $appgwipconfigname `
            -Subnet $frontendsubnet

        Start-Sleep 3

        $appgwfrontendport = New-AzApplicationGatewayFrontendPort `
            -Name $appgwfrontendportname `
            -Port 443

        Start-Sleep 3

        $appgwfrontendipconfig = New-AzApplicationGatewayFrontendIPConfig `
            -Name $appgwfrontendipconfigname `
            -PublicIPAddress $appgwpublicip

        Start-Sleep 3

        $appgwgatewaysslcert = New-AzApplicationGatewaySslCertificate `
            -Name $gatewaycertname `
            -KeyVaultSecretId $gatewaycertsecretid

        Start-Sleep 3

        $appgwportalsslcert = New-AzApplicationGatewaySslCertificate `
            -Name $portalcertname `
            -KeyVaultSecretId $portalcertsecretid

        Start-Sleep 3

        $appgwgatewaylistener = New-AzApplicationGatewayHttpListener `
            -Name $appgwgatewaylistenername `
            -Protocol "Https" `
            -FrontendIPConfiguration $appgwfrontendipconfig `
            -FrontendPort $appgwfrontendport `
            -SslCertificate $appgwgatewaysslcert `
            -HostName $ApimGatewayHostname `
            -RequireServerNameIndication true

        Start-Sleep 3

        $appgwportallistener = New-AzApplicationGatewayHttpListener `
            -Name $appgwportallistenername `
            -Protocol "Https" `
            -FrontendIPConfiguration $appgwfrontendipconfig `
            -FrontendPort $appgwfrontendport `
            -SslCertificate $appgwportalsslcert `
            -HostName $ApimPortalHostname `
            -RequireServerNameIndication true

        Start-Sleep 3

        $appgwapimgatewayprobe = New-AzApplicationGatewayProbeConfig `
            -Name $appgwapimgatewayprobename `
            -Protocol "Https" `
            -HostName $ApimGatewayHostname `
            -Path "/status-0123456789abcdef" `
            -Interval 30 `
            -Timeout 120 `
            -UnhealthyThreshold 8

        Start-Sleep 3

        $appgwapimportalprobe = New-AzApplicationGatewayProbeConfig `
            -Name $appgwapimportalprobename `
            -Protocol "Https" `
            -HostName $ApimPortalHostname `
            -Path "/signin" `
            -Interval 60 `
            -Timeout 300 `
            -UnhealthyThreshold 8

        if ($IsWellKnownCA) {
            Start-Sleep 3

            $appgwapimgatewaysetting = New-AzApplicationGatewayBackendHttpSettings `
                -Name $appgwapimgatewaysettingname `
                -Port 443 `
                -Protocol "Https" `
                -CookieBasedAffinity "Disabled" `
                -Probe $appgwapimgatewayprobe `
                -RequestTimeout 180

            $appgwapimportalsetting = New-AzApplicationGatewayBackendHttpSettings `
                -Name $appgwapimportalsettingname `
                -Port 443 `
                -Protocol "Https" `
                -CookieBasedAffinity "Disabled" `
                -Probe $appgwapimportalprobe `
                -RequestTimeout 180
        }
        else {
            Start-Sleep 3

            $appgwapimauthcert = New-AzApplicationGatewayAuthenticationCertificate -Name $appgwapimwhitelistcertname -CertificateFile $CACertificate
        
            Start-Sleep 3  

            $appgwapimgatewaysetting = New-AzApplicationGatewayBackendHttpSettings `
                -Name $appgwapimgatewaysettingname `
                -Port 443 `
                -Protocol "Https" `
                -CookieBasedAffinity "Disabled" `
                -Probe $appgwapimgatewayprobe `
                -RequestTimeout 180 `
                -AuthenticationCertificates $appgwapimauthcert

            $appgwapimportalsetting = New-AzApplicationGatewayBackendHttpSettings `
                -Name $appgwapimportalsettingname `
                -Port 443 `
                -Protocol "Https" `
                -CookieBasedAffinity "Disabled" `
                -Probe $appgwapimportalprobe `
                -RequestTimeout 180 `
                -AuthenticationCertificates $appgwapimauthcert
        }

        Start-Sleep 3

        if ($ApimVpnType -eq "Internal") {
            $appgwapimbackendpool = New-AzApplicationGatewayBackendAddressPool `
                -Name $appgwapimbackendpoolname `
                -BackendIPAddresses $apim.PrivateIPAddresses[0]
        }

        if ($ApimVpnType -eq "External") {
            $appgwapimbackendpool = New-AzApplicationGatewayBackendAddressPool `
                -Name $appgwapimproxybackendpoolname `
                -BackendIPAddresses $apim.PublicIPAddresses[0]
        }

        Start-Sleep 3

        $appgwapimgatewayrule = New-AzApplicationGatewayRequestRoutingRule `
            -Name $appgwapimgatewayrulename `
            -RuleType Basic `
            -HttpListener $appgwgatewaylistener `
            -BackendAddressPool $appgwapimproxybackendpool `
            -BackendHttpSettings $appgwapimgatewaysetting

        Start-Sleep 3

        $appgwapimportalrule = New-AzApplicationGatewayRequestRoutingRule `
            -Name $appgwapimportalrulename `
            -RuleType Basic `
            -HttpListener $appgwportallistener `
            -BackendAddressPool $appgwapimproxybackendpool `
            -BackendHttpSettings $appgwapimportalsetting

        Start-Sleep 3

        $appgwsku = New-AzApplicationGatewaySku `
            -Name "WAF_v2" `
            -Tier "WAF_v2" `
            -Capacity $ApplicationGatewayCapacity

        Start-Sleep 3

        $appgwwafconfig = New-AzApplicationGatewayWebApplicationFirewallConfiguration `
            -Enabled $true `
            -FirewallMode "Prevention"

        Start-Sleep 3

        if ($IsWellKnownCA) {
            $appgw = New-AzApplicationGateway `
                -Name $appgwname `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -Identity $appgwidentity `
                -BackendAddressPools $appgwapimbackendpool `
                -BackendHttpSettingsCollection $appgwapimgatewaysetting, $appgwapimportalsetting  `
                -FrontendIpConfigurations $appgwfrontendipconfig `
                -GatewayIpConfigurations $appgwipconfig `
                -FrontendPorts $appgwfrontendport `
                -HttpListeners $appgwgatewaylistener, $appgwportallistener `
                -RequestRoutingRules $appgwapimgatewayrule, $appgwapimportalrule `
                -Sku $appgwsku `
                -WebApplicationFirewallConfig $appgwwafconfig `
                -SslCertificates $appgwgatewaysslcert, $appgwportalsslcert `
                -Probes $appgwapimgatewayprobe, $appgwapimportalprobe
        }
        else {
            $appgw = New-AzApplicationGateway `
                -Name $appgwname `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -Identity $appgwidentity `
                -BackendAddressPools $appgwapimbackendpool `
                -BackendHttpSettingsCollection $appgwapimgatewaysetting, $appgwapimportalsetting  `
                -FrontendIpConfigurations $appgwfrontendipconfig `
                -GatewayIpConfigurations $appgwipconfig `
                -FrontendPorts $appgwfrontendport `
                -HttpListeners $appgwgatewaylistener, $appgwportallistener `
                -RequestRoutingRules $appgwapimgatewayrule, $appgwapimportalrule `
                -Sku $appgwsku `
                -WebApplicationFirewallConfig $appgwwafconfig `
                -SslCertificates $appgwgatewaysslcert, $appgwportalsslcert `
                -Probes $appgwapimgatewayprobe, $appgwapimportalprobe `
                -AuthenticationCertificates $appgwapimauthcert
        }
        
        $appgw
    }
}