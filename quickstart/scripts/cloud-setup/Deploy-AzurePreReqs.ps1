Using module ../modules/Azure.psm1
Using module ../modules/RepoOperations.psm1
Using module ../modules/Validation.psm1
Using module ../modules/Logging.psm1

[cmdletbinding()]
param(
    [Parameter(Mandatory)] $ConfigurationFile
)

Write-Host "Cloud setup starting..."

BeginScope -Scope "Config file validation"

[string]$schemaFilePath = "./quickstart/schemas/cloud-setup/config.schema.1.0.0.json"

[bool]$validConfigFile = IsValidConfigurationFile -ConfigurationFile $ConfigurationFile -SchemaFile $schemaFilePath -Verbose:$VerbosePreference

if (! $validConfigFile)
{
    EndScope
    throw "Invalid properties on the '$ConfigurationFile' configuration file."
    exit 1
}

[hashtable]$config = LoadConfigurationFile -ConfigurationFile $ConfigurationFile -Verbose:$VerbosePreference
[bool]$validConfigFileProperties = IsValidConfigurationFileProperties -Configuration $config -Verbose:$VerbosePreference

if (! $validConfigFileProperties)
{
    EndScope
    throw "The '$ConfigurationFile' config file has invalid properties."
    exit 1
}

EndScope

# Extract service principal details from the configuration for each environment
$servicePrincipals = @{}
foreach ($env in $config.environments.Keys) {
    $envConfig = $config.environments[$env]
    $servicePrincipals[$env] = @{
        clientId     = $envConfig.clientId
        clientSecret = $envConfig.clientSecret
        tenantId     = $envConfig.tenantId
    }
}

# Check if service principal credentials are provided; skip creation if they exist
if ($servicePrincipals["dev"].clientId -and $servicePrincipals["dev"].clientSecret -and $servicePrincipals["dev"].tenantId) {
    Write-Host "Service principal credentials provided, skipping creation step."
} else {
    # Setup service principals if credentials are not provided
    $servicePrincipals = SetupServicePrincipals -Configuration $config -Verbose:$VerbosePreference
}

# Setup environments
SetupEnvironments -Configuration $config -ServicePrincipals $servicePrincipals -Verbose:$VerbosePreference

# Save the service principal secret in the output HOL file
$ServicePrincipalSecret = $servicePrincipals["dev"].clientSecret  # Assuming "dev" environment secret is to be saved

PublishOutputs -Configuration $config -ServicePrincipalSecret $ServicePrincipalSecret -Verbose:$VerbosePreference

Write-Host "Done!"
