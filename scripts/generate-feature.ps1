param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$FeatureName
)

$Pascal = $FeatureName.Substring(0,1).ToUpper() + $FeatureName.Substring(1)
$Lower = $FeatureName.ToLower()
$Plural = $Lower + "s"

$rootDir = Split-Path -Parent $PSScriptRoot
if (!(Test-Path "$rootDir\lib")) {
    $rootDir = "C:\Go\FlutterProjectStructure"
}

$tplDir = "$PSScriptRoot\templates"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

Write-Host "⚡ Scaffolding Flutter feature: $Pascal..." -ForegroundColor Cyan

$featDir = "$rootDir\lib\features\$Lower"
New-Item -ItemType Directory -Path "$featDir\models" -Force | Out-Null
New-Item -ItemType Directory -Path "$featDir\repositories" -Force | Out-Null
New-Item -ItemType Directory -Path "$featDir\controllers" -Force | Out-Null
New-Item -ItemType Directory -Path "$featDir\screens" -Force | Out-Null

function Process-Template($tplName, $targetPath) {
    $content = [System.IO.File]::ReadAllText("$tplDir\$tplName")
    $content = $content.Replace("__PASCAL__", $Pascal).Replace("__LOWER__", $Lower).Replace("__PLURAL__", $Plural)
    [System.IO.File]::WriteAllText($targetPath, $content, $utf8NoBom)
}

# 1. Model
$modelFile = "$featDir\models\${Lower}_model.dart"
Process-Template "model.dart.tpl" $modelFile
Write-Host "  [+] Created Model: $modelFile" -ForegroundColor Green

# 2. Repository
$repoFile = "$featDir\repositories\${Lower}_repository.dart"
Process-Template "repository.dart.tpl" $repoFile
Write-Host "  [+] Created Repository: $repoFile" -ForegroundColor Green

# 3. Controller
$ctrlFile = "$featDir\controllers\${Lower}_controller.dart"
Process-Template "controller.dart.tpl" $ctrlFile
Write-Host "  [+] Created Controller: $ctrlFile" -ForegroundColor Green

# 4. Screen
$screenFile = "$featDir\screens\${Lower}_list_screen.dart"
Process-Template "screen.dart.tpl" $screenFile
Write-Host "  [+] Created Screen: $screenFile" -ForegroundColor Green

Write-Host ""
Write-Host "🚀 Feature $Pascal created successfully!" -ForegroundColor Green
Write-Host "👉 To wire it in lib/main.dart, add to MultiProvider:" -ForegroundColor Yellow
Write-Host "    ChangeNotifierProvider(create: (_) => ${Pascal}Controller())," -ForegroundColor Cyan
Write-Host "👉 Navigate to it from anywhere:" -ForegroundColor Yellow
Write-Host "    Navigator.push(context, MaterialPageRoute(builder: (_) => const ${Pascal}ListScreen()));" -ForegroundColor Cyan
