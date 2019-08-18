﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\BMiner.exe"
$HashSHA256 = "817DADDC04FB8782725743F7FF778DC071A6610C9A4EE414C3D9F83DA27B542B"
$Uri = "https://www.bminercontent.com/releases/bminer-lite-v15.7.6-f585663-amd64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=2519271.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = $Devices | Where-Object Type -EQ "GPU"

# Miner requires CUDA 9.2.00 or higher
$CUDAVersion = (($Devices | Where-Object Vendor -EQ "NVIDIA Corporation").OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.00"
if ($Devices.Vendor -contains "NVIDIA Corporation" -and $CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    $Devices = $Devices | Where-Object Vendor -NE "NVIDIA Corporation"
}

#Commands from config file take precedence
if ($Miner_Config.Commands) {$Commands = $Miner_Config.Commands}
else {
    $Commands = [PSCustomObject[]]@(
        #Single algo mining
       [PSCustomObject]@{MainAlgorithm = "beam";         Protocol = "beam";         SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("AMD", "NVIDIA"); Params = ""} #EquihashR15050, new in 11.3.0
       [PSCustomObject]@{MainAlgorithm = "cuckarood29";  Protocol = "cuckaroo29";   SecondaryAlgorithm = "";          ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = " --fast"} #Cuckarood29, new in 15.7.1
       [PSCustomObject]@{MainAlgorithm = "cuckatoo31";   Protocol = "cuckatoo31";   SecondaryAlgorithm = "";          ; MinMemGB = 8; Vendor = @("NVIDIA"); Params = ""} #Cuckatoo31, new in 14.2.0, requires GTX 1080Ti or RTX 2080Ti
       [PSCustomObject]@{MainAlgorithm = "aeternity";    Protocol = "aeternity";    SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = " --fast"} #Aeternity, new in 11.1.0
       [PSCustomObject]@{MainAlgorithm = "equihash";     Protocol = "stratum";      SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Equihash
       #[PSCustomObject]@{MainAlgorithm = "equihash1445"; Protocol = "equihash1445"; SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Equihash1445, AMD_NVIDIA-Gminer_v1.52 is faster
       [PSCustomObject]@{MainAlgorithm = "ethash";       Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash
       [PSCustomObject]@{MainAlgorithm = "ethash2gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2GB
       [PSCustomObject]@{MainAlgorithm = "ethash3gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3GB
       [PSCustomObject]@{MainAlgorithm = "ethash2gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2GB & Blake14r dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash3gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3GB & Blake14r dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash";       Protocol = "ethstratum";   SecondaryAlgorithm = "blake14r";  ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake14r dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash2gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2GB & Blake2s dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash3gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3GB & Blake2s dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash";       Protocol = "ethstratum";   SecondaryAlgorithm = "blake2s";   ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Blake2s dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash2gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2GB & Bytom dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash3gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3GB & Bytom dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash";       Protocol = "ethstratum";   SecondaryAlgorithm = "tensority"; ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Bytom dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash2gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Ethash2GB & Vbk dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash3gb";    Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 3; Vendor = @("NVIDIA"); Params = ""} #Ethash3GB & Vbk dual mining
       [PSCustomObject]@{MainAlgorithm = "ethash";       Protocol = "ethstratum";   SecondaryAlgorithm = "vbk";       ; MinMemGB = 4; Vendor = @("NVIDIA"); Params = ""} #Ethash & Vbk dual mining
       [PSCustomObject]@{MainAlgorithm = "tensority";    Protocol = "ethstratum";   SecondaryAlgorithm = "";          ; MinMemGB = 2; Vendor = @("NVIDIA"); Params = ""} #Bytom
    )
}

$SecondaryAlgoIntensities = [PSCustomObject]@{
    "blake14r"  = @(0) # 0 = Auto-Intensity
    "blake2s"   = @(20, 40, 60) # 0 = Auto-Intensity not working with blake2s
    "tensority" = @(0) # 0 = Auto-Intensity
    "vbk"       = @(0) # 0 = Auto-Intensity
}
#Intensities from config file take precedence
$Miner_Config.SecondaryAlgoIntensities.PSObject.Properties.Name | Select-Object | ForEach-Object {
    $SecondaryAlgoIntensities | Add-Member $_ $Miner_Config.SecondaryAlgoIntensities.$_ -Force
}

$Commands | ForEach-Object {
    if ($_.SecondaryAlgorithm) {
        $Command = $_
        $SecondaryAlgoIntensities.$($_.SecondaryAlgorithm) | Select-Object | ForEach-Object {
            if ($null -ne $Command.SecondaryAlgoIntensity) {
                $Command = ($Command | ConvertTo-Json | ConvertFrom-Json)
                $Command | Add-Member SecondaryAlgoIntensity ([String] $_) -Force
                $Commands += $Command
            }
            else {$Command | Add-Member SecondaryAlgoIntensity $_}
        }
    }
}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonParameters) {$CommonParameters = $Miner_Config.CommonParameters}
else {$CommonParameters = " -watchdog=false"}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Main_Algorithm_Norm = Get-Algorithm $_.MainAlgorithm; $_} | Where-Object {$_.Vendor -contains ($Device.Vendor_ShortName | Select-Object -Unique) -and $Pools.$Main_Algorithm_Norm.Host} | ForEach-Object {
        $Arguments_Secondary = ""
        $IntervalMultiplier = 1
        $Main_Algorithm = $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB
        $Parameters = $_.Parameters
        $Protocol = $_.Protocol
        if ($Pools.$Main_Algorithm_Norm.SSL) {$Protocol = "$($Protocol)+ssl"}
        $Vendor = $_.Vendor
        $WarmupTime = $null
        
        #Cuckatoo31 on windows 10 requires 3.5 GB extra
        if ($Main_Algorithm -eq "Cuckatoo31" -and ([System.Version]$PSVersionTable.BuildVersion -ge "10.0.0.0")) {$MinMemGB += 3.5}

        if ($Miner_Device = @($Device | Where-Object {$Vendor -contains $_.Vendor_ShortName -and ([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            #Get parameters for active miner devices
            if ($Miner_Config.Parameters.$Algorithm_Norm) {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters.$($Main_Algorithm_Norm, $Secondary_Algorithm_Norm -join '') $Miner_Device.Type_Vendor_Index
            }
            elseif ($Miner_Config.Parameters."*") {
                $Parameters = Get-ParameterPerDevice $Miner_Config.Parameters."*" $Miner_Device.Type_Vendor_Index
            }
            else {
                $Parameters = Get-ParameterPerDevice $Parameters $Miner_Device.Type_Vendor_Index
            }

            if ($Main_Algorithm_Norm -eq "Equihash1445") {
                #define -pers for equihash1445
                $AlgoPers = " -pers $(Get-AlgoCoinPers  -Algorithm $Main_Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default 'auto')"
            }
            else {$AlgoPers = ""}

            if ($null -ne $_.SecondaryAlgoIntensity) {
                $Secondary_Algorithm = $_.SecondaryAlgorithm
                $Secondary_Algorithm_Norm = Get-Algorithm $Secondary_Algorithm

                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) + @("$Main_Algorithm_Norm$Secondary_Algorithm_Norm") + @($_.SecondaryAlgoIntensity) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week; $Secondary_Algorithm_Norm = $Stats."$($Miner_Name)_$($Secondary_Algorithm_Norm)_HashRate".Week}

                $Arguments_Secondary = " -uri2 $($Secondary_Algorithm)$(if ($Pools.$Secondary_Algorithm_Norm.SSL) {'+ssl'})://$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Secondary_Algorithm_Norm.Pass))@$($Pools.$Secondary_Algorithm_Norm.Host):$($Pools.$Secondary_Algorithm_Norm.Port)$(if($_.SecondaryAlgoIntensity -ge 0){" -dual-intensity $($_.SecondaryAlgoIntensity)"})"
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 1.3 / 100; $Secondary_Algorithm_Norm = 0 / 100} # Fixed at 1.3%, secondary algo no fee

                $IntervalMultiplier = 2
                $WarmupTime = 120
            }
            else {
                $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'
                $Miner_HashRates = [PSCustomObject]@{$Main_Algorithm_Norm = $Stats."$($Miner_Name)_$($Main_Algorithm_Norm)_HashRate".Week}
                $WarmupTime = 120

                if ($Main_Algorithm_Norm -like "Ethash*") {$MinerFeeInPercent = 0.65} # Ethash fee fixed at 0.65%
                else {$MinerFeeInPercent = 2} # Other algos fee fixed at 2%

                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = $MinerFeeInPercent / 100}
            }

            #Optionally disable dev fee mining
            if ($null -eq $Miner_Config) {$Miner_Config = [PSCustomObject]@{DisableDevFeeMining = $Config.DisableDevFeeMining}}
            if ($Miner_Config.DisableDevFeeMining) {
                $NoFee = " -nofee"
                $Miner_Fees = [PSCustomObject]@{$Main_Algorithm_Norm = 0 / 100}
                if ($Secondary_Algorithm_Norm) {$Miner_Fees | Add-Member $Secondary_Algorithm_Norm (0 / 100)}
            }
            else {$NoFee = ""}

            [PSCustomObject]@{
                Name               = $Miner_Name
                BaseName           = $Miner_BaseName
                Version            = $Miner_Version
                DeviceName         = $Miner_Device.Name
                Path               = $Path
                HashSHA256         = $HashSHA256
                Arguments          = ("-api 127.0.0.1:$($Miner_Port)$AlgoPers -uri $($Protocol)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Main_Algorithm_Norm.Pass))@$($Pools.$Main_Algorithm_Norm.Host):$($Pools.$Main_Algorithm_Norm.Port)$Arguments_Secondary$Parameters$CommonParameters$NoFee -devices $(if ($Miner_Device.Vendor -EQ "Advanced Micro Devices, Inc.") {"amd:"})$(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',')" -replace "\s+", " ").trim()
                HashRates          = $Miner_HashRates
                API                = "Bminer"
                Port               = $Miner_Port
                URI                = $URI
                Fees               = $Miner_Fees
                IntervalMultiplier = $IntervalMultiplier
                WarmupTime         = $WarmupTime #seconds
            }
        }
    }
}