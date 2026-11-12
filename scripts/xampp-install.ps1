<#
.SYNOPSIS
  Install the Silkaura WooCommerce store into XAMPP on Windows.

.DESCRIPTION
  Start Apache and MySQL in the XAMPP Control Panel first, then from the repo folder run:

    powershell -ExecutionPolicy Bypass -File scripts\xampp-install.ps1

  Safe to re-run. Optional parameters, e.g.:
    ... -File scripts\xampp-install.ps1 -AdminPassword "MySecret" -Site shop -Port 8080
#>
param(
  [string]$XamppDir      = "C:\xampp",
  [string]$Site          = "silkaura",
  [string]$DbName        = "silkaura",
  [string]$DbUser        = "root",
  [string]$DbPassword    = "",
  [string]$DbHost        = "127.0.0.1",
  [int]   $Port          = 80,
  [string]$AdminUser     = "admin",
  [string]$AdminPassword = "admin123",
  [string]$AdminEmail    = "admin@example.com",
  [string]$Country       = "US:CA",
  [string]$Currency      = "USD"
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # makes Invoke-WebRequest much faster on PS 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo    = Split-Path -Parent $PSScriptRoot
$Php     = Join-Path $XamppDir "php\php.exe"
$Mysql   = Join-Path $XamppDir "mysql\bin\mysql.exe"
$DocRoot = Join-Path $XamppDir "htdocs\$Site"
$Tools   = Join-Path $Repo ".tools"
$WpCli   = Join-Path $Tools "wp-cli.phar"
$HostName = if ($Port -eq 80) { "localhost" } else { "localhost:$Port" }
$Url     = "http://$HostName/$Site"
$env:WC_COUNTRY  = $Country
$env:WC_CURRENCY = $Currency

function Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

function Wp {
  & $Php -d memory_limit=512M $WpCli "--path=$DocRoot" @args
  if ($LASTEXITCODE -ne 0) { Fail "wp $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

# Run a native command quietly and return its exit code. Windows PowerShell 5.1 turns
# redirected stderr into terminating errors when ErrorActionPreference is Stop.
function Quiet-Exit([scriptblock]$cmd) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { & $cmd *> $null; return $LASTEXITCODE } finally { $ErrorActionPreference = $old }
}

function MysqlArgs {
  $a = @("-h", $DbHost, "-u", $DbUser)
  if ($DbPassword) { $a += "-p$DbPassword" }
  return $a
}

function Link-Dir($target, $link) {
  if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      $item.Delete()                      # removes the link, not the repo files
    } else {
      Rename-Item $link "$link.bak.$(Get-Date -Format yyyyMMddHHmmss)"
    }
  }
  # A junction needs no admin rights or Developer Mode, unlike a symlink.
  New-Item -ItemType Junction -Path $link -Target $target | Out-Null
  Write-Host "$link -> $target"
}

Step "Checking XAMPP at $XamppDir"
if (-not (Test-Path $Php))   { Fail "PHP not found at $Php. Pass -XamppDir if XAMPP is elsewhere." }
if (-not (Test-Path $Mysql)) { Fail "MySQL client not found at $Mysql." }
# Compare the version here, not inside php -r: Windows PowerShell 5.1 strips double
# quotes from arguments passed to programs, which breaks PHP code that contains them.
# -n skips php.ini so startup warnings (e.g. a missing extension DLL) can't mix into the output.
$phpVersion = (& $Php -n -r 'echo PHP_VERSION;' | Out-String).Trim()
if (-not $phpVersion) {
  Fail "$Php did not run. Open the XAMPP Control Panel, click Shell, and run 'php -v' to see the error."
}
if ([version]($phpVersion -replace '[^0-9.].*$', '') -lt [version]'7.4') {
  Fail "PHP 7.4+ is required, but $Php is PHP $phpVersion. Install a newer XAMPP (PHP 8.x) from apachefriends.org."
}
$ma = MysqlArgs
if ((Quiet-Exit { & $Mysql @ma -e "SELECT 1" }) -ne 0) { Fail "Can't connect to MySQL. Click Start next to MySQL in the XAMPP Control Panel." }
Write-Host "PHP $phpVersion ($Php), MySQL OK"

Step "Getting WP-CLI"
New-Item -ItemType Directory -Force -Path $Tools | Out-Null
if (-not (Test-Path $WpCli)) {
  Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" -OutFile $WpCli
}
Wp --version

Step "Downloading WordPress into $DocRoot"
if (-not (Test-Path (Join-Path $DocRoot "wp-load.php"))) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("silkaura-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  Invoke-WebRequest -UseBasicParsing -Uri "https://downloads.wordpress.org/release/wordpress-latest.zip" -OutFile "$tmp\wp.zip"
  Expand-Archive -Path "$tmp\wp.zip" -DestinationPath $tmp
  New-Item -ItemType Directory -Force -Path $DocRoot | Out-Null
  Copy-Item -Path "$tmp\wordpress\*" -Destination $DocRoot -Recurse -Force
  Remove-Item $tmp -Recurse -Force
} else {
  Write-Host "Already present"
}

Step "Creating database '$DbName'"
$sql = 'CREATE DATABASE IF NOT EXISTS `' + $DbName + '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
& $Mysql @ma -e $sql
if ($LASTEXITCODE -ne 0) { Fail "Could not create database $DbName" }

Step "Configuring WordPress"
if (-not (Test-Path (Join-Path $DocRoot "wp-config.php"))) {
  Wp config create "--dbname=$DbName" "--dbuser=$DbUser" "--dbpass=$DbPassword" "--dbhost=$DbHost" --skip-check
  Wp config set WP_ENVIRONMENT_TYPE local
  Wp config set WP_DEBUG true --raw
  Wp config set WP_DEBUG_LOG true --raw
  Wp config set WP_DEBUG_DISPLAY false --raw
  Wp config set FS_METHOD direct
}
$htaccess = @"
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /$Site/
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /$Site/index.php [L]
</IfModule>
# END WordPress
"@
# Write without a byte-order mark: Apache rejects .htaccess files that start with one.
[IO.File]::WriteAllText((Join-Path $DocRoot ".htaccess"), $htaccess.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))

Step "Installing WordPress"
if ((Quiet-Exit { & $Php $WpCli "--path=$DocRoot" core is-installed }) -ne 0) {
  Wp core install "--url=$Url" "--title=Silkaura" "--admin_user=$AdminUser" "--admin_password=$AdminPassword" "--admin_email=$AdminEmail" --skip-email
}

Step "Linking Silkaura theme and mu-plugins from the repo"
Link-Dir (Join-Path $Repo "wp-content\themes\silkaura") (Join-Path $DocRoot "wp-content\themes\silkaura")
Link-Dir (Join-Path $Repo "wp-content\mu-plugins")      (Join-Path $DocRoot "wp-content\mu-plugins")

Step "Installing WooCommerce + Storefront and setting up the store"
Wp eval-file (Join-Path $Repo "scripts\provision.php")

Write-Host ""
Write-Host "Silkaura is running in XAMPP" -ForegroundColor Green
Write-Host "  Store:  $Url"
Write-Host "  Admin:  $Url/wp-admin   (user: $AdminUser, password: $AdminPassword)"
