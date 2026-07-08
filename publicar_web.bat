@echo off
setlocal enabledelayedexpansion

:: =============================================================
:: CONFIGURACOES
:: =============================================================
set SKETCH=esp32_controle_v2
set NOVA_VERSAO=2.0.0
set FQBN=esp32:esp32:esp32c3
set ARDUINO_CLI=arduino-cli
set PASTA_REPO=%~dp0
set BUILD_DIR=%TEMP%\esp32_build
set ARDUINO15=%LOCALAPPDATA%\Arduino15
:: =============================================================

echo.
echo =============================================
echo   COMPILADOR E PUBLICADOR DE FIRMWARE
echo =============================================
echo.

:: ---- Verifica dependencias ----
%ARDUINO_CLI% version >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Arduino CLI nao encontrado.
    echo        Instale com: winget install ArduinoSA.CLI
    pause & exit /b 1
)

git --version >nul 2>&1
if errorlevel 1 (
    echo [ERRO] Git nao encontrado. Instale em https://git-scm.com
    pause & exit /b 1
)

if not exist "%PASTA_REPO%%SKETCH%\%SKETCH%.ino" (
    echo [ERRO] Sketch nao encontrado: %PASTA_REPO%%SKETCH%\%SKETCH%.ino
    pause & exit /b 1
)

echo Versao : %NOVA_VERSAO%
echo Sketch : %SKETCH%
echo Repo   : %PASTA_REPO%
echo.

:: ---- Passo 1: Compilar ----
echo [1/4] Compilando firmware...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

%ARDUINO_CLI% compile --fqbn %FQBN% --output-dir "%BUILD_DIR%" "%PASTA_REPO%%SKETCH%"
if errorlevel 1 ( echo [ERRO] Compilacao falhou. & pause & exit /b 1 )
echo [OK] Compilacao concluida.

:: ---- Passo 2: Localiza esptool (busca direta na pasta de versao) ----
echo.
echo [2/4] Localizando ferramentas...

set ESPTOOL_DIR=
for /d %%v in ("%ARDUINO15%\packages\esp32\tools\esptool_py\*") do (
    if exist "%%v\esptool.exe" set ESPTOOL_DIR=%%v
)

if "%ESPTOOL_DIR%"=="" (
    echo [ERRO] esptool.exe nao encontrado em:
    echo        %ARDUINO15%\packages\esp32\tools\esptool_py\
    echo        Execute: arduino-cli core install esp32:esp32
    pause & exit /b 1
)
echo [OK] esptool : %ESPTOOL_DIR%

:: Localiza boot_app0.bin (busca direta em hardware\esp32\{versao}\tools\partitions)
set BOOT_APP0=
for /d %%v in ("%ARDUINO15%\packages\esp32\hardware\esp32\*") do (
    if exist "%%v\tools\partitions\boot_app0.bin" (
        set BOOT_APP0=%%v\tools\partitions\boot_app0.bin
    )
)

if "%BOOT_APP0%"=="" (
    echo [ERRO] boot_app0.bin nao encontrado em:
    echo        %ARDUINO15%\packages\esp32\hardware\esp32\*\tools\partitions\
    pause & exit /b 1
)
echo [OK] boot_app0: %BOOT_APP0%

:: ---- Passo 3: Gerar firmware merged ----
echo.
echo [3/4] Gerando firmware_merged.bin...

set BL=%BUILD_DIR%\%SKETCH%.ino.bootloader.bin
set PT=%BUILD_DIR%\%SKETCH%.ino.partitions.bin
set APP=%BUILD_DIR%\%SKETCH%.ino.bin
set OUT=%PASTA_REPO%firmware_merged.bin

pushd "%ESPTOOL_DIR%"
esptool.exe --chip esp32c3 merge-bin --output "%OUT%" --flash-mode dio --flash-freq 80m --flash-size 4MB 0x0 "%BL%" 0x8000 "%PT%" 0xe000 "%BOOT_APP0%" 0x10000 "%APP%"
set MERGE_ERR=%errorlevel%
popd

if %MERGE_ERR% neq 0 ( echo [ERRO] Falha ao gerar firmware merged. & pause & exit /b 1 )
echo [OK] firmware_merged.bin gerado em: %OUT%

:: ---- Atualiza versao no manifest.json ----
powershell -Command "(Get-Content '%PASTA_REPO%manifest.json') -replace '\"version\": \"[^\"]+\"', '\"version\": \"%NOVA_VERSAO%\"' | Set-Content '%PASTA_REPO%manifest.json'"
echo [OK] manifest.json atualizado para v%NOVA_VERSAO%

:: ---- Passo 4: Git push ----
echo.
echo [4/4] Publicando no GitHub...

cd /d "%PASTA_REPO%"
git add firmware_merged.bin manifest.json
git commit -m "Firmware v%NOVA_VERSAO%"
git push

if errorlevel 1 (
    echo [ERRO] Falha no git push. Verifique sua conexao e credenciais.
    pause & exit /b 1
)

echo.
echo =============================================
echo   PUBLICADO COM SUCESSO!
echo   Versao: %NOVA_VERSAO%
echo   Link: https://cassiofm.github.io/placanova/
echo =============================================
echo.

rmdir /s /q "%BUILD_DIR%" 2>nul
pause
exit /b 0
