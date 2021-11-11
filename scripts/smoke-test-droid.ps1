Set-Variable -Name "ApkFileName" -Value "app.apk"

Set-Variable -Name "AdbPath" -Value ($Env:ANDROID_HOME + "/platform-tools")

# Debug env variables
gci env:* | sort-object name


# Filter device List
$RawAdbDeviceList = ."$AdbPath/adb.exe" devices
$deviceList = @()
foreach ($device in $RawAdbDeviceList)
{
    if ($device.EndsWith("device"))
    {
        $deviceList += $device.Replace("device", '').Trim()
    }
}
$deviceCount = $deviceList.Count

if ($deviceCount -eq 0)
{
    Write-Error "It seems like no devices were found $RawAdbDeviceList"
    exit(-1)
}
else
{
    Write-Output "Found $deviceCount devices, they are $deviceList"
}

###test
foreach ($device in $deviceList)
{
    Write-Output "Installing Apk on $device."

    $stdout = ."$AdbPath/adb.exe" -s $device install -r $ApkFileName
    if($stdout -notcontains "Success")
    {
        Write-Error "Failed to Install APK: $stdout."
        exit(-1)
    }

    Write-Output "Clearing logcat from $device."

    ."$AdbPath/adb.exe" -s $device logcat -c

    Write-Output "Starting Test..."

    ."$AdbPath/adb.exe" -s $device shell am start -n io.sentry.samples.unityofbugs/com.unity3d.player.UnityPlayerActivity -e test smoke

    Start-Sleep -Seconds 2

    for ($i = 30; $i -gt 0; $i--) {
        $smokeTestId = (& "$AdbPath/adb.exe" '-s', $device, 'shell', 'pidof', 'io.sentry.samples.unityofbugs'  2>&1)
        if ( $smokeTestId -eq $null)
        {
            $i = -2;
        }
        else
        {
            Write-Output "Proccess $smokeTestId still running on $device, waiting $i seconds"
            Start-Sleep -Seconds 1
        }
    }

    if ( $i -eq -2)
    {
        Write-Error "Test Timeout"
        exit(-1)
    }

    $stdout = ."$AdbPath/adb.exe"  -s $device logcat -d  | findstr SMOKE
    if ( $stdout -ne $null)
    {
        Write-Output "$stdout"
    }
    else
    {
        Write-Error "Smoke Test Failed, printing logcat..."
        ."$AdbPath/adb.exe" -s $device logcat -d  | findstr "Unity unity sentry Sentry SMOKE"
        exit(-1)
    }
}

Write-Output "Test completed."
exit(0)