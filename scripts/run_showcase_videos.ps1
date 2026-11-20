param(
    [string]$PythonExe = "python",
    [string]$FFmpegExe = "C:\Program Files\TRCCCAP\ffmpeg.exe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputDir = Join-Path $repoRoot "results\demo\generated\showcase"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$iverilogCommand = Get-Command iverilog.exe -ErrorAction SilentlyContinue
$vvpCommand = Get-Command vvp.exe -ErrorAction SilentlyContinue
$iverilog = if ($iverilogCommand) { $iverilogCommand.Source } else { "C:\iverilog\bin\iverilog.exe" }
$vvp = if ($vvpCommand) { $vvpCommand.Source } else { "C:\iverilog\bin\vvp.exe" }
if (-not (Test-Path -LiteralPath $FFmpegExe)) {
    $ffmpegCommand = Get-Command ffmpeg.exe,ffmpeg -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ffmpegCommand) { throw "FFmpeg was not found. Pass its path with -FFmpegExe." }
    $FFmpegExe = $ffmpegCommand.Source
}

$simulation = Join-Path $outputDir "graphics_accelerator_showcase.vvp"
$scenes = @("satellite", "sunset", "orbit")
Push-Location $repoRoot
try {
    & $PythonExe scripts/generate_showcase_scenes.py
    if ($LASTEXITCODE -ne 0) { throw "Scene generation failed with exit $LASTEXITCODE." }

    & $iverilog -g2012 -s graphics_accelerator_showcase_tb -o $simulation `
        rtl/triangle_setup/triangle_setup_beta.sv `
        rtl/rasterizer/rasterizer.sv `
        rtl/interpolation/fragment_interpolator.sv `
        rtl/depth/depth_test.sv `
        rtl/graphics_accelerator/graphics_accelerator_beta.sv `
        tb/rtl/graphics_accelerator_showcase_tb.sv
    $compileExit = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $simulation)) {
        throw "Icarus did not produce the showcase simulation (exit $compileExit)."
    }
    if ($compileExit -ne 0) {
        Write-Warning "Icarus returned exit $compileExit after producing the simulation file; running it."
    }

    & $vvp $simulation
    if ($LASTEXITCODE -ne 0) { throw "RTL simulation failed with exit $LASTEXITCODE." }

    & $PythonExe scripts/render_showcase_videos.py
    if ($LASTEXITCODE -ne 0) { throw "Frame reconstruction failed with exit $LASTEXITCODE." }

    foreach ($scene in $scenes) {
        $pattern = Join-Path $outputDir "frames\$scene\frame_%03d.png"
        $video = Join-Path $outputDir "$scene.mp4"
        & $FFmpegExe -hide_banner -loglevel error -y -framerate 10 -i $pattern `
            -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart $video
        if ($LASTEXITCODE -ne 0) { throw "Encoding $scene.mp4 failed with exit $LASTEXITCODE." }
    }

    $clips = $scenes | ForEach-Object { Join-Path $outputDir "$_.mp4" }
    $reel = Join-Path $outputDir "rtl_demo_reel.mp4"
    & $FFmpegExe -hide_banner -loglevel error -y `
        -i $clips[0] -i $clips[1] -i $clips[2] `
        -filter_complex "[0:v][1:v][2:v]concat=n=3:v=1:a=0[outv]" -map "[outv]" `
        -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart $reel
    if ($LASTEXITCODE -ne 0) { throw "Encoding the combined reel failed with exit $LASTEXITCODE." }

    Get-Item -LiteralPath (Join-Path $outputDir "satellite.mp4"),
        (Join-Path $outputDir "sunset.mp4"),
        (Join-Path $outputDir "orbit.mp4"), $reel |
        Select-Object Name, Length
}
finally {
    Pop-Location
}
