param (
    $sourceCodeContainerName = "avautomationsource",
    $sourceCodeStorageAccountName = "avautomationsource",
    $targetStorageAccountName = "clocksharkfiles",
    $targetResourceGroup = "Shared-Storage-EastUS",
    $subscriptionID = "388cca1e-ba7d-4132-8bad-086fd38d8282",
    $deploymentResourceGroupName = "AVAutomation-clocksharkfiles",
    $deploymentResourceGroupLocation = "eastus",
    $vmUserName = "jasondonnell",
    $vmPassword = "Goshark1!",
    $ArmTemplateFile = "$PSScriptRoot/../ARM_template/AntivirusAutomationForStorageTemplate.json"
)

$vmPassword = ConvertTo-SecureString $vmPassword -AsPlainText -Force

$ScanHttpServerRoot = "$PSScriptRoot\..\ScanHttpServer"
$ScanHttpServerZipPath = "$ScanHttpServerRoot\ScanHttpServer.Zip"

$VMInitScriptPath = "$ScanHttpServerRoot\VMInit.ps1"

$ScanUploadedBlobRoot = "$PSScriptRoot\..\ScanUploadedBlobFunction"
$ScanUploadedBlobZipPath = "$ScanUploadedBlobRoot\ScanUploadedBlobFunction.zip"

az login
az account set --subscription $subscriptionID

#Build and Zip ScanHttpServer code 
Write-Host Build ScanHttpServer
dotnet publish $ScanHttpServerRoot\ScanHttpServer.csproj -c Release -o $ScanHttpServerRoot/out

Write-Host Zip ScanHttpServer
$compress = @{
    Path            = "$ScanHttpServerRoot\out\*", "$ScanHttpServerRoot\runLoop.ps1"
    DestinationPath = $ScanHttpServerZipPath
}
Compress-Archive @compress -Update
Write-Host ScanHttpServer zipped successfully

# Build and Zip ScanUploadedBlob Function
Write-Host Build ScanUploadedBlob
dotnet publish $ScanUploadedBlobRoot\ScanUploadedBlobFunction.csproj -c Release -o $ScanUploadedBlobRoot\out

Write-Host Zip ScanUploadedBlob code
Compress-Archive -Path $ScanUploadedBlobRoot\out\* -DestinationPath $ScanUploadedBlobZipPath -Update
Write-Host ScanUploadedBlob zipped successfully

# Uploading ScanHttpServer code 
Write-Host Uploading Files
Write-Host Creating container if not exists
az storage container create `
    --name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `
    --public-access blob

$ScanHttpServerBlobName = "ScanHttpServer.zip"
az storage blob upload `
    --file $ScanHttpServerZipPath `
    --name $ScanHttpServerBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID

$ScanHttpServerUrl = az storage blob url `
    --name $ScanHttpServerBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `

$ScanUploadedBlobFubctionBlobName = "ScanUploadedBlobFunction.zip"
az storage blob upload `
    --file $ScanUploadedBlobZipPath `
    --name $ScanUploadedBlobFubctionBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `

$ScanUploadedBlobFubctionUrl = az storage blob url `
    --name $ScanUploadedBlobFubctionBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `

$VMInitScriptBlobName = "VMInit.ps1"
az storage blob upload `
    --file $VMInitScriptPath `
    --name $VMInitScriptBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `
    
$VMInitScriptUrl = az storage blob url `
    --name $VMInitScriptBlobName `
    --container-name $sourceCodeContainerName `
    --account-name $sourceCodeStorageAccountName `
    --subscription $subscriptionID `

Write-Host $ScanHttpServerUrl
Write-Host $ScanUploadedBlobFubctionUrl
Write-Host $VMInitScriptUrl

az group create `
    --location $deploymentResourceGroupLocation `
    --name $deploymentResourceGroupName `
    --subscription $subscriptionID

az deployment group create `
    --subscription $subscriptionID `
    --name "AntivirusAutomationForStorageTemplate" `
    --resource-group $deploymentResourceGroupName `
    --template-file $ArmTemplateFile `
    --parameters ScanHttpServerZipURL=$ScanHttpServerUrl `
    --parameters ScanUploadedBlobFunctionZipURL=$ScanUploadedBlobFubctionUrl `
    --parameters VMInitScriptURL=$VMInitScriptUrl `
    --parameters NameOfTargetStorageAccount=$targetStorageAccountName `
    --parameters NameOfTheResourceGroupTheTargetStorageAccountBelongsTo=$targetResourceGroup `
    --parameters SubscriptionIDOfTheTargetStorageAccount=$subscriptionID `
    --parameters VMAdminUsername=$vmUserName `
    --parameters VMAdminPassword=$vmPassword