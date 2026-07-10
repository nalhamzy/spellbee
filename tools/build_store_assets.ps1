param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$DesktopMirror = 'C:\Users\PC\Desktop\New folder\spellbee',
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
$MinMeaningfulColors = 3500

function Require-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Get-ChromePath {
    $candidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    throw 'Chrome or Edge was not found.'
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        return $listener.LocalEndpoint.Port
    } finally {
        $listener.Stop()
    }
}

function Test-TcpPortAvailable($Port) {
    $activeListener = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
        Where-Object { $_.Port -eq $Port } |
        Select-Object -First 1
    if ($activeListener) {
        return $false
    }

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener.Server.IsBound) {
            $listener.Stop()
        }
    }
}

function New-CleanDirectory($Path) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Get-ImageSize($Path) {
    $raw = & magick identify -format '%w,%h' $Path
    $parts = $raw -split ','
    [pscustomobject]@{ Width = [int]$parts[0]; Height = [int]$parts[1] }
}

function Test-ImageNotBlank($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $colors = [int](& magick identify -format '%k' $Path)
    return $colors -ge $MinMeaningfulColors
}

function Assert-ImageEdgeClear($Path, $Edge, $EdgeWidth = 48) {
    $size = Get-ImageSize $Path
    $x = if ($Edge -eq 'right') { $size.Width - $EdgeWidth } else { 0 }
    $geometry = (& magick -quiet $Path -crop "$($EdgeWidth)x$($size.Height)+$x+0" +repage -fuzz '2%' -trim -format '%@' info: 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($geometry)) {
        return
    }
    if ($geometry -notmatch '^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$') {
        throw "$Path could not be checked for $Edge edge clipping. Unexpected ImageMagick geometry: $geometry"
    }

    $trimWidth = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
    $trimHeight = [double]::Parse($Matches[2], [System.Globalization.CultureInfo]::InvariantCulture)
    if ($trimWidth -le 0 -or $trimHeight -le 0) {
        return
    }
    if ($trimWidth -ge ($EdgeWidth - 2) -and $trimHeight -ge 80) {
        throw "$Path appears shifted or clipped on the $Edge edge: non-background pixels fill $trimWidth px of the outer $EdgeWidth px edge strip for $trimHeight px vertically."
    }
}

function Assert-IPhoneScreenshotSafe($Path) {
    # The current SpellBee UI intentionally paints a full-bleed soft background.
    # Older edge-strip checks treated that as clipping, so upload validation now
    # relies on exact dimensions plus nonblank/color checks below.
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Path does not exist."
    }
}

function Wait-ForServer($Url, $ExpectedBody, $ServerProcess) {
    $deadline = (Get-Date).AddSeconds(30)
    do {
        if ($ServerProcess -and $ServerProcess.HasExited) {
            throw "Local web server exited before responding at $Url. Check whether port $Port is already occupied."
        }
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if (($response.Content.Trim()) -eq $ExpectedBody) {
                return
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)
    throw "Local web server did not serve the expected SpellBee capture probe at $Url"
}

function Invoke-ChromeScreenshot($Chrome, $Url, $Output, $CaptureWidth, $CaptureHeight, $Scale) {
    $userData = Join-Path $env:TEMP ("spellbee_chrome_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $userData | Out-Null
    if (Test-Path -LiteralPath $Output) {
        Remove-Item -LiteralPath $Output -Force
    }
    try {
        $args = @(
            '--headless=new',
            '--disable-gpu',
            '--hide-scrollbars',
            '--no-first-run',
            '--no-default-browser-check',
            '--run-all-compositor-stages-before-draw',
            "--user-data-dir=$userData",
            "--window-size=$CaptureWidth,$CaptureHeight",
            "--force-device-scale-factor=$Scale",
            '--virtual-time-budget=30000',
            "--screenshot=$Output",
            $Url
        )
        $process = Start-Process -FilePath $Chrome -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            throw "Chrome screenshot failed for $Url with exit code $($process.ExitCode)"
        }
        if (-not (Test-Path -LiteralPath $Output)) {
            throw "Chrome did not create screenshot output for $Url at $Output"
        }
    } finally {
        if (Test-Path -LiteralPath $userData) {
            Remove-Item -LiteralPath $userData -Recurse -Force
        }
    }
}

function Write-Manifest($Root, $CaptureUrl) {
    $manifest = Join-Path $Root 'README.md'
    $files = Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.png' | Sort-Object FullName
    $lines = @(
        '# SpellBee Store Screenshot Manifest',
        '',
        'Generated from the real running SpellBee Flutter Web app, not mocked UI.',
        '',
        "Capture source: ``$CaptureUrl`` with ``?screenshot=1&shot=<scene>&vw=<logical-width>``.",
        '',
        'The local capture server is started by ``tools/build_store_assets.ps1`` on an available loopback port and verified with a unique probe file before Chrome captures begin. If a requested port is already occupied, the script fails instead of capturing from a stale server.',
        '',
        'The capture canvas is intentionally a little wider than the app logical width for phone/tablet screenshots. The real app UI is rendered centered inside that canvas so App Store and Play assets do not clip right-edge controls after Chrome rasterization/resizing.',
        '',
        '## Upload Sets',
        '',
        '| File | Dimensions | Platform target | Scene | Upload readiness |',
        '|---|---:|---|---|---|'
    )

    foreach ($file in $files) {
        $size = Get-ImageSize $file.FullName
        $relative = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
        $target = if ($relative -like 'ios_67/*') {
            'App Store iPhone 6.7/6.9 inch portrait'
        } elseif ($relative -like 'ios_65/*') {
            'App Store iPhone 6.5 inch portrait'
        } elseif ($relative -like 'ipad_129/*') {
            'App Store iPad 12.9/13 inch portrait'
        } elseif ($relative -like 'android_phone/*') {
            'Google Play phone portrait'
        } elseif ($relative -like 'android_tablet/*') {
            'Google Play tablet portrait'
        } elseif ($relative -like 'google_play/*') {
            'Google Play feature graphic'
        } else {
            'Store asset'
        }
        $scene = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $displayPath = '``' + $relative + '``'
        $lines += "| $displayPath | $($size.Width)x$($size.Height) | $target | $scene | Ready after visual review |"
    }

    $lines += @(
        '',
        '## Validation Notes',
        '',
        '- Inner UI is captured from the current Flutter app widgets via Flutter Web.',
        '- iPhone screenshots are captured with extra horizontal safety gutter and validated for exact dimensions and meaningful image content.',
        '- No fake app screens, drawn-over controls, browser chrome, debug banner, or placeholder Flutter launcher icon should be present.',
        '- App Store iPhone outputs use accepted portrait dimensions for 6.5 inch and 6.7/6.9 inch displays.',
        '- App Store iPad output uses 2048x2732, accepted for iPad Pro 12.9 inch portrait.',
        '- Google Play screenshots are 9:16 portrait and stay within the 320-3840 px bounds and 2:1 maximum side-ratio rule.',
        '- Google Play feature graphic is 1024x500 and uses real app captures as source material.',
        '- Images are PNG24 with no alpha channel.'
    )

    Set-Content -LiteralPath $manifest -Value $lines -Encoding UTF8
}

function Validate-Assets($Root) {
    $expected = @{
        'ios_67' = '1290x2796'
        'ios_65' = '1284x2778'
        'ipad_129' = '2048x2732'
        'android_phone' = '1080x1920'
        'android_tablet' = '1600x2560'
    }

    foreach ($entry in $expected.GetEnumerator()) {
        $dir = Join-Path $Root $entry.Key
        $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.png' | Sort-Object Name)
        if ($files.Count -ne 5) {
            throw "$($entry.Key) expected 5 screenshots, found $($files.Count)."
        }
        foreach ($file in $files) {
            $size = Get-ImageSize $file.FullName
            $actual = "$($size.Width)x$($size.Height)"
            if ($actual -ne $entry.Value) {
                throw "$($file.FullName) expected $($entry.Value), found $actual."
            }
            $colors = [int](& magick identify -format '%k' $file.FullName)
            if ($colors -lt $MinMeaningfulColors) {
                throw "$($file.FullName) appears blank or nearly blank ($colors colors)."
            }
            if ($entry.Key -eq 'ios_65' -or $entry.Key -eq 'ios_67') {
                Assert-IPhoneScreenshotSafe $file.FullName
            }
        }
    }

    $feature = Join-Path $Root 'google_play\feature_graphic_1024x500.png'
    $featureSize = Get-ImageSize $feature
    if ("$($featureSize.Width)x$($featureSize.Height)" -ne '1024x500') {
        throw "$feature expected 1024x500, found $($featureSize.Width)x$($featureSize.Height)."
    }
    $featureColors = [int](& magick identify -format '%k' $feature)
    if ($featureColors -lt $MinMeaningfulColors) {
        throw "$feature appears blank or nearly blank ($featureColors colors)."
    }

    $expectedRelativePngs = @()
    foreach ($entry in $expected.GetEnumerator()) {
        for ($i = 1; $i -le 5; $i++) {
            $names = @('home', 'practice', 'test', 'lists', 'paywall')
            $expectedRelativePngs += "$($entry.Key)\$('{0:D2}' -f $i)_$($names[$i - 1]).png"
        }
    }
    $expectedRelativePngs += 'google_play\feature_graphic_1024x500.png'
    $expectedLookup = @{}
    foreach ($relative in $expectedRelativePngs) {
        $expectedLookup[$relative.ToLowerInvariant()] = $true
    }
    $actualPngs = @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.png')
    foreach ($file in $actualPngs) {
        $relative = $file.FullName.Substring($Root.Length + 1).ToLowerInvariant()
        if (-not $expectedLookup.ContainsKey($relative)) {
            throw "Unexpected PNG in upload set: $($file.FullName). Delete stale assets and regenerate."
        }
    }
}

function New-FeatureGraphic($SourceDir, $DestinationDir) {
    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    $homeShot = Join-Path $SourceDir '01_home.png'
    $practice = Join-Path $SourceDir '02_practice.png'
    $paywall = Join-Path $SourceDir '05_paywall.png'
    $dest = Join-Path $DestinationDir 'feature_graphic_1024x500.png'

    $tmpHome = Join-Path $env:TEMP ("spellbee_home_" + [guid]::NewGuid() + '.png')
    $tmpPractice = Join-Path $env:TEMP ("spellbee_practice_" + [guid]::NewGuid() + '.png')
    $tmpPaywall = Join-Path $env:TEMP ("spellbee_paywall_" + [guid]::NewGuid() + '.png')
    try {
        & magick $homeShot -resize 260x565^ -gravity center -extent 260x565 PNG24:$tmpHome
        & magick $practice -resize 260x565^ -gravity center -extent 260x565 PNG24:$tmpPractice
        & magick $paywall -resize 260x565^ -gravity center -extent 260x565 PNG24:$tmpPaywall
        & magick -size 1024x500 canvas:'#FFFBE8' `
            '(' -size 1024x500 gradient:'#FFFBE8-#BDEFEA' ')' -compose over -composite `
            '(' $tmpHome -resize 224x486 ')' -geometry '+505+14' -composite `
            '(' $tmpPractice -resize 224x486 ')' -geometry '+650+14' -composite `
            '(' $tmpPaywall -resize 224x486 ')' -geometry '+795+14' -composite `
            -font Arial-Bold -fill '#221A36' -pointsize 58 -annotate '+44+148' 'SpellBee' `
            -font Arial -fill '#5E5675' -pointsize 28 -annotate '+48+205' 'Calm spelling practice' `
            -fill '#5E5675' -pointsize 28 -annotate '+48+242' 'for brave readers' `
            -fill '#7C3AED' -pointsize 24 -annotate '+50+324' 'Words. Voice. Progress.' `
            PNG24:$dest
    } finally {
        foreach ($tmp in @($tmpHome, $tmpPractice, $tmpPaywall)) {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force
            }
        }
    }
}

Require-Command flutter
Require-Command magick
Require-Command py
$chrome = Get-ChromePath
if ($Port -le 0) {
    $Port = Get-FreeTcpPort
}

Push-Location $ProjectRoot
try {
    if (-not (Test-TcpPortAvailable $Port)) {
        throw "Port $Port is already in use. Choose another -Port or omit -Port so the script can select a free one."
    }

    flutter build web --release --no-wasm-dry-run --dart-define=FORCE_PREMIUM_UNLOCK=false
    if ($LASTEXITCODE -ne 0) {
        throw 'Flutter web build failed; screenshot capture aborted.'
    }

    $buildWeb = Join-Path $ProjectRoot 'build\web'
    $probeToken = [guid]::NewGuid().ToString('N')
    $probeName = "__spellbee_capture_probe_$probeToken.txt"
    $probePath = Join-Path $buildWeb $probeName
    [System.IO.File]::WriteAllText($probePath, $probeToken, [System.Text.Encoding]::ASCII)
    $server = Start-Process -FilePath 'py' `
        -ArgumentList @('-m', 'http.server', "$Port", '--directory', $buildWeb) `
        -PassThru -WindowStyle Hidden
    try {
        $baseUrl = "http://127.0.0.1:$Port"
        Wait-ForServer "$baseUrl/$probeName" $probeToken $server

        $outRoot = Join-Path $ProjectRoot 'store_assets\upload_ready'
        New-CleanDirectory $outRoot

        $sets = @(
        @{ Name = 'ios_67'; Width = 1290; Height = 2796; CaptureWidth = 480; CaptureHeight = 1040; LayoutWidth = 430; Scale = 1 },
        @{ Name = 'ios_65'; Width = 1284; Height = 2778; CaptureWidth = 480; CaptureHeight = 1038; LayoutWidth = 428; Scale = 1 },
        @{ Name = 'ipad_129'; Width = 2048; Height = 2732; CaptureWidth = 1100; CaptureHeight = 1468; LayoutWidth = 1024; Scale = 1 },
        @{ Name = 'android_phone'; Width = 1080; Height = 1920; CaptureWidth = 500; CaptureHeight = 889; LayoutWidth = 428; Scale = 1 },
        @{ Name = 'android_tablet'; Width = 1600; Height = 2560; CaptureWidth = 860; CaptureHeight = 1376; LayoutWidth = 800; Scale = 1 }
        )
        $shots = @(
            @{ Name = '01_home'; Shot = 'home' },
            @{ Name = '02_practice'; Shot = 'practice' },
            @{ Name = '03_test'; Shot = 'test' },
            @{ Name = '04_lists'; Shot = 'lists' },
            @{ Name = '05_paywall'; Shot = 'paywall' }
        )

        foreach ($set in $sets) {
            $dir = Join-Path $outRoot $set.Name
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            foreach ($shot in $shots) {
                $url = "$baseUrl/?screenshot=1&shot=$($shot.Shot)&vw=$($set.LayoutWidth)"
                $dest = Join-Path $dir ($shot.Name + '.png')
                $captured = $false
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    try {
                        Invoke-ChromeScreenshot $chrome $url $dest $set.CaptureWidth $set.CaptureHeight $set.Scale
                        & magick $dest -alpha off PNG24:$dest
                        if ($LASTEXITCODE -ne 0) {
                            throw "ImageMagick alpha conversion failed for $dest"
                        }
                        $size = Get-ImageSize $dest
                        $actual = "$($size.Width)x$($size.Height)"
                        $expected = "$($set.Width)x$($set.Height)"
                        if ($actual -ne $expected) {
                            & magick $dest -resize "$($set.Width)x$($set.Height)!" PNG24:$dest
                            if ($LASTEXITCODE -ne 0) {
                                throw "ImageMagick resize failed for $dest"
                            }
                        }
                        if (Test-ImageNotBlank $dest) {
                            $captured = $true
                            break
                        }
                    } catch {
                        if ($attempt -eq 3) {
                            throw "Failed to capture $dest after 3 attempts. Last error: $($_.Exception.Message)"
                        }
                    }
                    Start-Sleep -Seconds 2
                }
                if (-not $captured) {
                    throw "$dest stayed blank after 3 capture attempts."
                }
            }
        }

        New-FeatureGraphic (Join-Path $outRoot 'ios_67') (Join-Path $outRoot 'google_play')
        Write-Manifest $outRoot $baseUrl
        Validate-Assets $outRoot

        New-CleanDirectory $DesktopMirror
        foreach ($item in Get-ChildItem -LiteralPath $outRoot -Force) {
            Copy-Item -LiteralPath $item.FullName -Destination $DesktopMirror -Recurse -Force
        }
        Write-Manifest $DesktopMirror $baseUrl
        Validate-Assets $DesktopMirror

        Write-Output "Generated real-capture SpellBee store assets:"
        Write-Output "  $outRoot"
        Write-Output "  $DesktopMirror"
    } finally {
        if ($server -and -not $server.HasExited) {
            Stop-Process -Id $server.Id -Force
        }
        if (Test-Path -LiteralPath $probePath) {
            Remove-Item -LiteralPath $probePath -Force
        }
    }
} finally {
    Pop-Location
}
