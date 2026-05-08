#Requires -Version 5.1
<#
.SYNOPSIS
    Smart Shop App - Complete Development Environment Setup Script
    
.DESCRIPTION
    Automates installation of Flutter, Android Studio, Java, and Git for Windows.
    Configures environment variables and sets up the complete development environment.
    
.PARAMETER SkipRestart
    If specified, script will not prompt for restart reminder.
    
.NOTES
    Run as Administrator: Right-click PowerShell -> Run as Administrator
    Then execute: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Then run: .\smart_shop_setup.ps1
    
    Compatible with Windows PowerShell 5.1+ and PowerShell 7+
    
.EXAMPLE
    .\smart_shop_setup.ps1
#>

param(
    [switch]$SkipRestart
)

# ============================================================================
# CONFIGURATION SECTION - All URLs and paths defined here
# ============================================================================

$config = @{
    # Download URLs
    JavaJdkUrl = "https://download.oracle.com/java/17/latest/jdk-17_windows-x64_bin.exe"
    FlutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.2-stable.zip"
    GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.45.0.windows.1/Git-2.45.0-64-bit.exe"
    
    # Installation paths
    FlutterPath = "C:\src\flutter"
    JavaPath = "C:\Program Files\Eclipse Adoptium\jdk-17"
    AndroidSdkPath = "$env:LOCALAPPDATA\Android\Sdk"
    TempDir = "$env:TEMP\SmartShopSetup"
    
    # Timeouts (in milliseconds)
    DownloadTimeout = 300000  # 5 minutes
    DownloadRetries = 3
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Red
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Yellow
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Cyan
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-InternetConnection {
    try {
        $testUrl = "https://www.google.com"
        $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 5 -Method Head -ErrorAction Stop
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    
    while ($retryCount -lt $MaxRetries) {
        try {
            Write-LogInfo "Downloading from: $Url"
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            Write-LogSuccess "Download completed: $OutputPath"
            return $true
        }
        catch {
            $retryCount++
            Write-LogWarning "Download failed (Attempt $retryCount/$MaxRetries): $($_.Exception.Message)"
            
            if ($retryCount -lt $MaxRetries) {
                Write-LogInfo "Waiting 5 seconds before retry..."
                Start-Sleep -Seconds 5
            }
        }
    }
    
    Write-LogError "Failed to download after $MaxRetries attempts"
    return $false
}

function Add-ToEnvironmentPath {
    param(
        [string]$PathToAdd,
        [string]$Scope = "User"
    )
    
    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", $Scope)
        
        if ($currentPath -notlike "*$PathToAdd*") {
            $newPath = "$currentPath;$PathToAdd"
            
            # Verify path doesn't exceed max length (260 for User, 32767 for System)
            if ($newPath.Length -gt 32767) {
                Write-LogError "PATH would exceed maximum length. Cannot add: $PathToAdd"
                return $false
            }
            
            [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)
            
            # Also update current session
            $env:Path += ";$PathToAdd"
            
            Write-LogSuccess "Added to PATH ($Scope): $PathToAdd"
            return $true
        }
        else {
            Write-LogInfo "Path already exists in PATH: $PathToAdd"
            return $true
        }
    }
    catch {
        Write-LogError "Failed to add to PATH: $($_.Exception.Message)"
        return $false
    }
}

function Set-EnvironmentVariable {
    param(
        [string]$VarName,
        [string]$VarValue,
        [string]$Scope = "User"
    )
    
    try {
        [Environment]::SetEnvironmentVariable($VarName, $VarValue, $Scope)
        # Update current process environment
        [Environment]::SetEnvironmentVariable($VarName, $VarValue, "Process")
        Write-LogSuccess "Set $VarName = $VarValue ($Scope)"
        return $true
    }
    catch {
        Write-LogError "Failed to set $VarName : $($_.Exception.Message)"
        return $false
    }
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        $null = Invoke-Expression "cmd /c where $Command" -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

Clear-Host

Write-LogInfo "=========================================================================="
Write-LogInfo "   Smart Shop App - Complete Development Environment Setup"
Write-LogInfo "=========================================================================="
Write-Host ""

# Step 1: Verify Administrator Privileges
Write-LogInfo "Step 1: Checking Administrator Privileges..."

if (-not (Test-AdminPrivileges)) {
    Write-LogError "This script must be run as Administrator!"
    Write-LogWarning "Please:"
    Write-Host "  1. Right-click PowerShell"
    Write-Host "  2. Select 'Run as Administrator'"
    Write-Host "  3. Navigate to script location"
    Write-Host "  4. Run: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"
    Write-Host "  5. Run: .\smart_shop_setup.ps1"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-LogSuccess "Running as Administrator"
Write-Host ""

# Step 2: Check Internet Connection
Write-LogInfo "Step 2: Checking Internet Connection..."

if (-not (Test-InternetConnection)) {
    Write-LogError "No internet connection detected!"
    Write-LogWarning "This script requires internet to download tools."
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-LogSuccess "Internet connection verified"
Write-Host ""

# Step 3: Create Temporary Directory
Write-LogInfo "Step 3: Creating Temporary Directory..."

try {
    if (-not (Test-Path $config.TempDir)) {
        New-Item -ItemType Directory -Path $config.TempDir -Force | Out-Null
        Write-LogSuccess "Created: $($config.TempDir)"
    }
    else {
        Write-LogInfo "Temporary directory already exists"
    }
}
catch {
    Write-LogError "Failed to create temporary directory: $($_.Exception.Message)"
    exit 1
}

Write-Host ""

# Step 4: Check and Install Java JDK 17
Write-LogInfo "Step 4: Java JDK 17 Installation Check..."

if (Test-CommandExists "java") {
    try {
        $javaVersion = java -version 2>&1
        if ($javaVersion -like "*17*") {
            Write-LogSuccess "Java 17 is already installed"
        }
        else {
            Write-LogWarning "Java is installed but version may not be 17. Current output:"
            Write-Host $javaVersion
        }
    }
    catch {
        Write-LogWarning "Could not verify Java version"
    }
}
else {
    Write-LogWarning "Java 17 not found. Manual installation required."
    Write-LogInfo "Please download and install from: $($config.JavaJdkUrl)"
    Write-LogInfo "After installation, restart this script."
    Write-Host ""
}

Write-Host ""

# Step 5: Check and Install Git
Write-LogInfo "Step 5: Git Installation Check..."

if (Test-CommandExists "git") {
    try {
        $gitVersion = git --version
        Write-LogSuccess "Git is already installed: $gitVersion"
    }
    catch {
        Write-LogWarning "Could not verify Git version"
    }
}
else {
    Write-LogWarning "Git not found. Manual installation required."
    Write-LogInfo "Please download and install from: $($config.GitUrl)"
    Write-LogInfo "After installation, restart this script."
    Write-Host ""
}

Write-Host ""

# Step 6: Setup Flutter SDK
Write-LogInfo "Step 6: Flutter SDK Setup..."

if (Test-Path $config.FlutterPath) {
    Write-LogSuccess "Flutter SDK already exists at: $($config.FlutterPath)"
    
    if (Test-Path "$($config.FlutterPath)\bin\flutter.bat") {
        Write-LogSuccess "Flutter binary found"
    }
    else {
        Write-LogWarning "Flutter binary not found. Installation may be incomplete."
    }
}
else {
    Write-LogInfo "Flutter SDK not found. Downloading..."
    
    try {
        # Create src directory
        if (-not (Test-Path "C:\src")) {
            New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
            Write-LogSuccess "Created C:\src directory"
        }
        
        $flutterZip = Join-Path $config.TempDir "flutter.zip"
        
        if (Download-File -Url $config.FlutterUrl -OutputPath $flutterZip) {
            Write-LogInfo "Extracting Flutter SDK..."
            
            try {
                Expand-Archive -Path $flutterZip -DestinationPath "C:\src" -Force -ErrorAction Stop
                Remove-Item $flutterZip -Force
                Write-LogSuccess "Flutter SDK extracted successfully"
            }
            catch {
                Write-LogError "Failed to extract Flutter: $($_.Exception.Message)"
            }
        }
        else {
            Write-LogError "Failed to download Flutter SDK"
        }
    }
    catch {
        Write-LogError "Error during Flutter setup: $($_.Exception.Message)"
    }
}

Write-Host ""

# Step 7: Configure Environment Variables
Write-LogInfo "Step 7: Configuring Environment Variables..."

# Set JAVA_HOME
Set-EnvironmentVariable -VarName "JAVA_HOME" -VarValue $config.JavaPath -Scope "User"

# Set ANDROID_HOME
Set-EnvironmentVariable -VarName "ANDROID_HOME" -VarValue $config.AndroidSdkPath -Scope "User"

# Add paths to PATH
$pathsToAdd = @(
    "$($config.FlutterPath)\bin",
    "$($config.AndroidSdkPath)\platform-tools",
    "$($config.AndroidSdkPath)\tools",
    "C:\Program Files\Git\cmd"
)

foreach ($path in $pathsToAdd) {
    Add-ToEnvironmentPath -PathToAdd $path -Scope "User"
}

Write-Host ""

# Step 8: Verify Flutter Installation
Write-LogInfo "Step 8: Verifying Flutter Installation..."

if (Test-CommandExists "flutter") {
    try {
        $flutterVersion = flutter --version 2>&1
        Write-LogSuccess "Flutter version info:"
        Write-Host $flutterVersion
    }
    catch {
        Write-LogWarning "Could not verify Flutter version"
        Write-LogInfo "Please restart PowerShell and try again after computer restart"
    }
}
else {
    Write-LogWarning "Flutter command not found in current session"
    Write-LogInfo "This is normal. Please restart PowerShell after computer restart"
}

Write-Host ""

# Step 9: Run Flutter Doctor
Write-LogInfo "Step 9: Running Flutter Doctor Check..."

if (Test-CommandExists "flutter") {
    try {
        Write-LogInfo "This may take a minute..."
        & flutter doctor
    }
    catch {
        Write-LogWarning "Flutter doctor encountered an issue: $($_.Exception.Message)"
        Write-LogInfo "Please run 'flutter doctor' manually after restart"
    }
}
else {
    Write-LogWarning "Flutter not available in current session"
    Write-LogInfo "Please run 'flutter doctor' after restart"
}

Write-Host ""

# Step 10: Summary and Next Steps
Write-LogSuccess "=========================================================================="
Write-LogSuccess "Setup Process Completed!"
Write-LogSuccess "=========================================================================="
Write-Host ""

Write-LogInfo "INSTALLATION SUMMARY:"
Write-Host "  [+] Environment variables configured"
Write-Host "  [+] Flutter SDK downloaded and extracted"
Write-Host "  [+] PATH variables updated"
Write-Host ""

Write-LogWarning "IMPORTANT - NEXT STEPS:"
Write-Host ""
Write-Host "1. RESTART YOUR COMPUTER"
Write-Host "   - This allows environment variables to take effect"
Write-Host "   - Command: shutdown /r /t 60 (restarts in 60 seconds)"
Write-Host ""
Write-Host "2. INSTALL JAVA JDK 17 (if not already installed)"
Write-Host "   - Download: $($config.JavaUrl)"
Write-Host "   - Run installer and follow setup wizard"
Write-Host ""
Write-Host "3. INSTALL GIT (if not already installed)"
Write-Host "   - Download: $($config.GitUrl)"
Write-Host "   - Run installer with default settings"
Write-Host ""
Write-Host "4. INSTALL ANDROID STUDIO"
Write-Host "   - Visit: https://developer.android.com/studio"
Write-Host "   - Download and install"
Write-Host "   - During setup, install Android SDK and Android Emulator"
Write-Host ""
Write-Host "5. CREATE ANDROID VIRTUAL DEVICE"
Write-Host "   - Open Android Studio"
Write-Host "   - Go to: Tools > Device Manager"
Write-Host "   - Create a device (e.g., Pixel 5 with Android 13)"
Write-Host ""
Write-Host "6. VERIFY SETUP"
Write-Host "   - Open PowerShell and run:"
Write-Host "   - flutter doctor"
Write-Host "   - All items should have checkmarks"
Write-Host ""
Write-Host "7. CREATE YOUR FIRST PROJECT"
Write-Host "   - Command: flutter create smart_shop_app"
Write-Host "   - Command: cd smart_shop_app"
Write-Host "   - Command: flutter run"
Write-Host ""
Write-Host "8. FOLLOW FIREBASE SETUP"
Write-Host "   - See: FIREBASE_SETUP.md in your project folder"
Write-Host ""

Write-LogInfo "For more help, see SETUP_GUIDE.md and QUICK_REFERENCE.md"
Write-Host ""

if (-not $SkipRestart) {
    Write-LogWarning "=========================================================================="
    Write-LogWarning "COMPUTER RESTART REQUIRED"
    Write-LogWarning "=========================================================================="
    Write-Host ""
    
    $response = Read-Host "Would you like to restart your computer now? (y/n)"
    
    if ($response -eq "y" -or $response -eq "Y") {
        Write-LogInfo "Restarting in 60 seconds..."
        shutdown /r /t 60
    }
    else {
        Write-LogWarning "Please restart your computer manually to apply all changes"
        Read-Host "Press Enter to exit"
    }
}
else {
    Read-Host "Press Enter to exit"
}

exit 0
