﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject[]]$Devices
)

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"
$Path = ".\Bin\$($Name)\TT-Miner.exe"
$HashSHA256 = "C9EEF74B3EDC10C3A32709824C069D4307CCAC6D2F602EBF50229A3FD3F8788D"
$Uri = "https://tradeproject.de/download/Miner/TT-Miner-3.0.5.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"

$Miner_BaseName = $Name -split '-' | Select-Object -Index 0
$Miner_Version = $Name -split '-' | Select-Object -Index 1
$Miner_Config = $Config.MinersLegacy.$Miner_BaseName.$Miner_Version
if (-not $Miner_Config) {$Miner_Config = $Config.MinersLegacy.$Miner_BaseName."*"}

$Devices = @($Devices | Where-Object Type -EQ "GPU" | Where-Object Vendor -EQ "NVIDIA Corporation")

# Miner requires CUDA 9.2.148 or higher
$CUDAVersion = ($Devices.OpenCL.Platform.Version | Select-Object -Unique) -replace ".*CUDA ",""
$RequiredCUDAVersion = "9.2.148"
if ($CUDAVersion -and [System.Version]$CUDAVersion -lt [System.Version]$RequiredCUDAVersion) {
    Write-Log -Level Warn "Miner ($($Name)) requires CUDA version $($RequiredCUDAVersion) or above (installed version is $($CUDAVersion)). Please update your Nvidia drivers. "
    return
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{Algorithm = "ETHASH2gb";   MinMemGB = 2; Command = " -A ETHASH"} #Ethash2GB
    [PSCustomObject]@{Algorithm = "ETHASH3gb";   MinMemGB = 3; Command = " -A ETHASH"} #Ethash3GB
    [PSCustomObject]@{Algorithm = "ETHASH";      MinMemGB = 4; Command = " -A ETHASH"} #Ethash
    [PSCustomObject]@{Algorithm = "LYRA2V3";     MinMemGB = 2; Command = " -A LYRA2V3"} #LYRA2V3
#        [PSCustomObject]@{Algorithm = "MTP";         MinMemGB = 6; Command = " -A MTP"} #MTP, CcminerTrex-v0.12.2b is 20% faster
#        [PSCustomObject]@{Algorithm = "MTPNICEHASH"; MinMemGB = 6; Command = " -A MTP"} #MTP; TempFix: NiceHash only, CcminerTrex-v0.12.2b is 20% faster
#        [PSCustomObject]@{Algorithm = "MYRGR";       MinMemGB = 2; Command = " -A MYRGR"} #Myriad-Groestl, never profitable
    [PSCustomObject]@{Algorithm = "UBQHASH";     MinMemGB = 2; Command = " -A UBQHASH"} #Ubqhash
    [PSCustomObject]@{Algorithm = "PROGPOW2gb";  MinMemGB = 2; Command = " -A PROGPOW"} #ProgPoW2gb
    [PSCustomObject]@{Algorithm = "PROGPOW3gb";  MinMemGB = 3; Command = " -A PROGPOW"} #ProgPoW3gb
    [PSCustomObject]@{Algorithm = "PROGPOW";     MinMemGB = 4; Command = " -A PROGPOW"} #ProgPoW
    [PSCustomObject]@{Algorithm = "PROGPOW092";  MinMemGB = 4; Command = " -A PROGPOW092"} #ProgPoW092 (Hydnora)
    [PSCustomObject]@{Algorithm = "PROGPOWZ";    MinMemGB = 4; Command = " -A PROGPOWZ"} #ProgPoWZ
    [PSCustomObject]@{Algorithm = "TETHASHV1";   MinMemGB = 4; Command = " -A TETHASHV1"} #TETHASHV1 (Teo)
)
#Commands from config file take precedence
if ($Miner_Config.Commands) {$Miner_Config.Commands | ForEach-Object {$Algorithm = $_.Algorithm; $Commands = $Commands | Where-Object {$_.Algorithm -ne $Algorithm}; $Commands += $_}}

#CommonCommands from config file take precedence
if ($Miner_Config.CommonCommands) {$CommonCommands = $Miner_Config.CommonCommands}
else {$CommonCommands = " -RH -luck -ccd"}

$Devices | Select-Object Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Model -EQ $_.Model)
    $Miner_Port = $Config.APIPort + ($Device | Select-Object -First 1 -ExpandProperty Index) + 1

    $Commands | ForEach-Object {$Algorithm_Norm = Get-Algorithm $_.Algorithm; $_} | Where-Object {$Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {([math]::Round((10 * $_.OpenCL.GlobalMemSize / 1GB), 0) / 10) -ge $MinMemGB})) {
            $Miner_Name = (@($Name) + @($Miner_Device.Model_Norm | Sort-Object -unique | ForEach-Object {$Model_Norm = $_; "$(@($Miner_Device | Where-Object Model_Norm -eq $Model_Norm).Count)x$Model_Norm"}) | Select-Object) -join '-'

            #Get commands for active miner devices
            $Command = Get-CommandPerDevice -Command $_.Command -ExcludeParameters @("a", "algo") -DeviceIDs $Miner_Device.Type_Vendor_Index

            if ($Algorithm_Norm -eq "Progpow92") {
                #define --coin for Progpow92
                $CoinPers = "$(Get-AlgoCoinPers -Algorithm $Algorithm_Norm -CoinName $Pools.$Algorithm_Norm.CoinName -Default '')"
                if ($CoinPers) {$CoinPers = " --coin $CoinPers"}
            }                

            [PSCustomObject]@{
                Name       = $Miner_Name
                BaseName   = $Miner_BaseName
                Version    = $Miner_Version
                DeviceName = $Miner_Device.Name
                Path       = $Path
                HashSHA256 = $HashSHA256
                Arguments  = ("$command$CommonCommands --api-bind 127.0.0.1:$($Miner_Port)$CoinPers -P $($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$($Commands.$_)$CommonCommands -d $(($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' ')" -replace "\s+", " ").trim()
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Claymore"
                Port       = $Miner_Port
                URI        = $Uri
                Fees       = [PSCustomObject]@{$Algorithm_Norm = 1 / 100}
            }
        }
    }
}
