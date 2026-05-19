@echo off
echo === Step 1/4: Synthesising with yosys ===
yosys -ql stopwatch.yslog -p "synth_ice40 -top top -json stopwatch.json" stopwatch.v
if errorlevel 1 goto :error

echo.
echo === Step 2/4: Place and route with nextpnr ===
nextpnr-ice40 -ql stopwatch.nplog --up5k --package sg48 --freq 12 --asc stopwatch.asc --pcf icebreaker.pcf --json stopwatch.json
if errorlevel 1 goto :error

echo.
echo === Step 3/4: Packing bitstream ===
icepack stopwatch.asc stopwatch.bin
if errorlevel 1 goto :error

echo.
echo === Step 4/4: Uploading to iCEBreaker ===
iceprog stopwatch.bin
if errorlevel 1 goto :error

echo.
echo === Build complete! ===
exit /b 0

:error
echo.
echo *** Build failed at the step above. Fix the error and re-run. ***
exit /b 1