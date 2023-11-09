@echo off
setlocal enabledelayedexpansion

rem BAT script that creates the binaries for Carla (carla.org).
rem Run it through a cmd with the x64 Visual C++ Toolset enabled.

set LOCAL_PATH=%~dp0
set FILE_N=-[%~n0]:

rem Print batch params (debug purpose)
echo %FILE_N% [Batch params]: %*

rem ============================================================================
rem -- Parse arguments ---------------------------------------------------------
rem ============================================================================

set BUILD_UE4_EDITOR=false
set LAUNCH_UE4_EDITOR=false
set REMOVE_INTERMEDIATE=false
set USE_CARSIM=false
set USE_CHRONO=false
set USE_UNITY=true
set CARSIM_STATE="CarSim OFF"
set CHRONO_STATE="Chrono OFF"
set UNITY_STATE="Unity ON"
set AT_LEAST_WRITE_OPTIONALMODULES=false
set EDITOR_FLAGS=""
set USE_ROS2=false
set ROS2_STATE="Ros2 OFF"

:arg-parse
echo %1
if not "%1"=="" (
    if "%1"=="--editor-flags" (
        set EDITOR_FLAGS=%2
        shift
    )
    if "%1"=="--build" (
        set BUILD_UE4_EDITOR=true
    )
    if "%1"=="--launch" (
        set LAUNCH_UE4_EDITOR=true
    )
    if "%1"=="--clean" (
        set REMOVE_INTERMEDIATE=true
    )
    if "%1"=="--carsim" (
        set USE_CARSIM=true
    )
    if "%1"=="--chrono" (
        set USE_CHRONO=true
    )
    if "%1"=="--ros2" (
        set USE_ROS2=true
    )
    if "%1"=="--no-unity" (
        set USE_UNITY=false
    )
    if "%1"=="--at-least-write-optionalmodules" (
        set AT_LEAST_WRITE_OPTIONALMODULES=true
    )
    if "%1"=="-h" (
        goto help
    )
    if "%1"=="--help" (
        goto help
    )
    shift
    goto arg-parse
)
rem remove quotes from arguments
set EDITOR_FLAGS=%EDITOR_FLAGS:"=%

if %REMOVE_INTERMEDIATE% == false (
    if %LAUNCH_UE4_EDITOR% == false (
        if %BUILD_UE4_EDITOR% == false (
            if %AT_LEAST_WRITE_OPTIONALMODULES% == false (
                goto help
            )
        )
    )
)

rem Get Unreal Engine root path
if not defined UE4_ROOT (
    set KEY_NAME="HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine"
    set VALUE_NAME=InstalledDirectory
    for /f "usebackq tokens=1,2,*" %%A in (`reg query !KEY_NAME! /s /reg:64`) do (
        if "%%A" == "!VALUE_NAME!" (
            set UE4_ROOT=%%C
        )
    )
    if not defined UE4_ROOT goto error_unreal_no_found
)
if not "%UE4_ROOT:~-1%"=="\" set UE4_ROOT=%UE4_ROOT%\

rem Set the visual studio solution directory
rem
set UE4_PROJECT_FOLDER=%ROOT_PATH:/=\%Unreal\CarlaUE4\
pushd "%UE4_PROJECT_FOLDER%"

rem Clear binaries and intermediates generated by the build system
rem
if %REMOVE_INTERMEDIATE% == true (
    rem Remove directories
    for %%G in (
        "%UE4_PROJECT_FOLDER%Binaries",
        "%UE4_PROJECT_FOLDER%Build",
        "%UE4_PROJECT_FOLDER%Saved",
        "%UE4_PROJECT_FOLDER%Intermediate",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Binaries",
        "%UE4_PROJECT_FOLDER%Plugins\Carla\Intermediate",
        "%UE4_PROJECT_FOLDER%.vs"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            rmdir /s/q %%G
        )
    )

    rem Remove files
    for %%G in (
        "%UE4_PROJECT_FOLDER%CarlaUE4.sln"
    ) do (
        if exist %%G (
            echo %FILE_N% Cleaning %%G
            del %%G
        )
    )
)

rem Download Houdini Plugin

set HOUDINI_PLUGIN_REPO=https://github.com/sideeffects/HoudiniEngineForUnreal.git
set HOUDINI_PLUGIN_PATH=Plugins/HoudiniEngine
set HOUDINI_PLUGIN_COMMIT=55b6a16cdf274389687fce3019b33e3b6e92a914
set HOUDINI_PATCH=${CARLA_UTIL_FOLDER}/Patches/houdini_patch.txt
if not exist "%HOUDINI_PLUGIN_PATH%" (
  call git clone %HOUDINI_PLUGIN_REPO% %HOUDINI_PLUGIN_PATH%
  cd %HOUDINI_PLUGIN_PATH%
  call git checkout %HOUDINI_PLUGIN_COMMIT%
  cd ../..
)

rem Build Carla Editor
rem
set OMNIVERSE_PATCH_FOLDER=%ROOT_PATH%Util\Patches\omniverse_4.26\
set OMNIVERSE_PLUGIN_FOLDER=%UE4_ROOT%Engine\Plugins\Marketplace\NVIDIA\Omniverse\
if exist %OMNIVERSE_PLUGIN_FOLDER% (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse ON"
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.h" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Public\" > NUL
    xcopy /Y /S /I "%OMNIVERSE_PATCH_FOLDER%USDCARLAInterface.cpp" "%OMNIVERSE_PLUGIN_FOLDER%Source\OmniverseUSD\Private\" > NUL
) else (
    set OMNIVERSE_PLUGIN_INSTALLED="Omniverse OFF"
)

if %USE_CARSIM% == true (
    py -3 %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject" -e
    set CARSIM_STATE="CarSim ON"
) else (
    py -3 %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    set CARSIM_STATE="CarSim OFF"
)
if %USE_CHRONO% == true (
    set CHRONO_STATE="Chrono ON"
) else (
    set CHRONO_STATE="Chrono OFF"
)
if %USE_ROS2% == true (
    set ROS2_STATE="Ros2 ON"
) else (
    set ROS2_STATE="Ros2 OFF"
)
if %USE_UNITY% == true (
    set UNITY_STATE="Unity ON"
) else (
    set UNITY_STATE="Unity OFF"
)
set OPTIONAL_MODULES_TEXT=%CARSIM_STATE% %CHRONO_STATE% %ROS2_STATE% %OMNIVERSE_PLUGIN_INSTALLED% %UNITY_STATE%
echo %OPTIONAL_MODULES_TEXT% > "%ROOT_PATH%Unreal/CarlaUE4/Config/OptionalModules.ini"


if %BUILD_UE4_EDITOR% == true (
    echo %FILE_N% Building Unreal Editor...

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4Editor^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit

    call "%UE4_ROOT%Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto bad_exit
)

rem Launch Carla Editor
rem
if %LAUNCH_UE4_EDITOR% == true (
    echo %FILE_N% Launching Unreal Editor...
    call "%UE4_ROOT%\Engine\Binaries\Win64\UE4Editor.exe"^
        "%UE4_PROJECT_FOLDER%CarlaUE4.uproject" %EDITOR_FLAGS%
    if %errorlevel% neq 0 goto error_build
)

goto good_exit

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:help
    echo Build LibCarla.
    echo "Usage: %FILE_N% [-h^|--help] [--build] [--launch] [--clean]"
    goto good_exit

:error_build
    echo.
    echo %FILE_N% [ERROR] There was a problem building CarlaUE4.
    echo %FILE_N%         Please go to "Carla\Unreal\CarlaUE4", right click on
    echo %FILE_N%         "CarlaUE4.uproject" and select:
    echo %FILE_N%         "Generate Visual Studio project files"
    echo %FILE_N%         Open de generated "CarlaUE4.sln" and try to manually compile it
    echo %FILE_N%         and check what is causing the error.
    goto bad_exit

:good_exit
    endlocal
    exit /b 0

:bad_exit
    endlocal
    exit /b %errorlevel%

:error_unreal_no_found
    echo.
    echo %FILE_N% [ERROR] Unreal Engine not detected
    goto bad_exit
