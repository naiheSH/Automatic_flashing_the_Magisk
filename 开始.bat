@echo off

set adb-tools=.\source\platform-tools
set boot_origin=.\boot
set boot_Magiskpatched=.\boot
set Magisk_source=.\source\Magisk_flies
set aria=.\source\aria2
set payload=.\source\payload
set 7z=.\source\7zip

:start
CLS
rd /s /q %Magisk_source%\Magisk
del /q %Magisk_source%\magisk_lib.zip
del /q %Magisk_source%\Magisk.apk

set /p payload_file=请输入您的payload.bin路径(如为boot请直接回车，并检查boot文件夹内是否有名为“boot.img”的原boot文件):
if "%payload_file%"=="" (
    choice /c YN /m "是否使用链接获取boot/init_boot？"
    if errorlevel 2 (
        echo.
        echo.用户拒绝填写链接
        echo.
        goto start
    ) else if errorlevel 1 (
        set /p payload_URL=请输入您的payload.bin的URL:
    ) else (
        echo 无效的选择
        goto title
    )
)

:title
title 全自动刷入magisk_V2---by badnng
echo.
echo.          全自动刷入magisk_V2
echo.                               by badnng
echo.按A键开始进行内核版本小于5.15版本的boot全自动刷入~
echo.按B键开始进行内核版本大于或等于5.15版本的init_boot全自动刷入~

:Nopatch_flies
echo.
echo.获取最新文件
%aria%\aria2c.exe -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" -x 2 -c --file-allocation=none -o magisk_lib.zip -d %Magisk_source% https://ghp.miaostay.com/https://github.com/badnng/Tools_library_download/releases/download/test/magisk_lib.zip
%aria%\aria2c.exe -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" -x 2 -c --file-allocation=none -o Magisk.apk -d %Magisk_source% https://ghp.miaostay.com/https://github.com/badnng/Tools_library_download/releases/download/test/Magisk.apk
echo.按“A”键开始进行内核版本小于5.15版本的boot全自动刷入~
echo.按“B”键开始进行内核版本大于或等于5.15版本的init_boot全自动刷入~
echo.请输入选项:
if exist %Magisk_source%\magisk_lib.zip (
    choice /C AB /N /M ""
    goto flash_boot
    if errorlevel 2 goto flash_initboot
) else (
    goto Nopatch_flies
)

:flash_boot
CLS
echo. 正在检测USB调试授权
%adb-tools%\adb get-state
if %errorlevel%==0 (
    CLS
    goto next_boot
) else (
    CLS
    echo 请检查您的手机是否打开USB调试，且授权了此已经安装驱动的电脑，
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
    goto flash_boot
)

:next_boot
CLS
echo. 提取boot
if "%payload_file%"=="" (
    %payload%\payload_dumper.exe --partitions boot "%payload_URL%" --workers 4 --out %boot_origin%
    goto install_MagiskManager
) 
if "%payload_URL%"=="" (
    %payload%\payload_dumper.exe --partitions boot "%payload_file%" --workers 4 --out %boot_origin%
    goto install_MagiskManager
)
else (
    goto install_MagiskManager
)

:install_MagiskManager
echo. 安装Magisk Manager
%adb-tools%\adb install %Magisk_source%\Magisk.apk

if %errorlevel%==0 (
    CLS
    goto final_boot
) else (
    CLS
    echo 安装Magisk，如安装失败，请确保是否给电脑授权usb安装或系统管家拦截（如MIUI，HyperOS）
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
    goto install_MagiskManager
)

:final_boot
echo. 解压所需文件
.\source\7zip\7z x .\source\Magisk_flies\magisk_lib.zip -o.\source\Magisk_flies && REM 解压magisk-lib文件

echo. 修补boot
%adb-tools%\adb shell rm -r /data/local/tmp/Magisk
%adb-tools%\adb push .\source\Magisk_flies\Magisk\ /data/local/tmp && REM 推送脚本
%adb-tools%\adb push %boot_origin%\boot.img /data/local/tmp/Magisk && REM 推送boot
%adb-tools%\adb shell chmod +x /data/local/tmp/Magisk/* && REM 给权限
%adb-tools%\adb shell /data/local/tmp/Magisk/boot_patch.sh boot.img && REM 执行脚本
%adb-tools%\adb pull /data/local/tmp/Magisk/new-boot.img %boot_Magiskpatched%\boot.img && REM 拉取镜像
%adb-tools%\adb shell rm -r /data/local/tmp/Magisk/

echo. 刷入boot
echo. 设备将在10秒内重启进入fastboot，在此期间请不要拔出数据线!
timeout /t 10 >nul

echo. 重启进入fastboot
%adb-tools%\adb reboot bootloader

echo. 等待开机刷入boot
%adb-tools%\fastboot flash boot %boot_Magiskpatched%\boot.img
if %errorlevel%==0 (
    CLS
    %adb-tools%\fastboot reboot
    echo. 重启进入开机状态
    goto end
) else (
    CLS
    echo 请检查您的手机进入了fastboot，且是否安装了fastboot驱动
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
)

REM 这里是刷入init_boot的部分
:flash_initboot
CLS
echo. 正在检测USB调试授权
%adb-tools%\adb get-state
if %errorlevel%==0 (
    CLS
    goto next_initboot
) else (
    CLS
    echo 请检查您的手机是否打开USB调试，且授权了此电脑
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
    goto flash_initboot
)

:next_initboot
echo. 提取init_boot
if "%payload_file%"=="" (
    %payload%\payload_dumper.exe --partitions init_boot "%payload_URL%" --workers 4 --out %boot_origin%
    goto install_MagiskManager
) 
if "%payload_URL%"=="" (
    %payload%\payload_dumper.exe --partitions init_boot "%payload_file%" --workers 4 --out %boot_origin%
    goto install_MagiskManager
)
else (
    goto install_MagiskManager
)

:install_MagiskManager_init
echo. 安装Magisk Manager，
%adb-tools%\adb install %Magisk_flies%/Magisk.apk
if %errorlevel%==0 (
    CLS
    goto final_initboot
) else (
    CLS
    echo 安装Magisk，如安装失败，请确保是否给电脑授权usb安装或系统管家拦截（如MIUI，HyperOS）
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
    goto next_initboot
)

:final_initboot
echo. 解压所需文件
.\source\7zip\7z x .\source\Magisk_flies\magisk_lib.zip -o.\source\Magisk_flies && REM 解压magisk-lib文件

echo. 修补init_boot
%adb-tools%\adb push .\source\Magisk_flies\Magisk\ /data/local/tmp && REM 推送脚本
%adb-tools%\adb push %boot_origin%\init_boot.img /data/local/tmp/Magisk && REM 推送boot
%adb-tools%\adb shell chmod +x /data/local/tmp/Magisk/* && REM 给权限
%adb-tools%\adb shell /data/local/tmp/Magisk/boot_patch.sh init_boot.img && REM 执行脚本
%adb-tools%\adb pull /data/local/tmp/Magisk/new-boot.img %boot_Magiskpatched%\init_boot.img && REM 拉取镜像
%adb-tools%\adb shell rm -r /data/local/tmp/Magisk/

echo. 刷入init_boot
echo. 设备将在10秒内重启进入fastboot，在此期间请不要拔出数据线!
timeout /t 10 >nul

echo. 重启进入fastboot
%adb-tools%\adb reboot bootloader

echo. 等待开机刷入init_boot(AB通刷，支持K60U，Note13Pro+等机型)
%adb-tools%\fastboot flash init_boot_ab %boot_Magiskpatched%\boot.img
if %errorlevel%==0 (
    CLS
    %adb-tools%\fastboot reboot
    echo. 重启进入开机状态
    goto end
) else (
    CLS
    echo 请检查您的手机进入了fastboot，且是否安装了fastboot驱动
    echo 检测将会在10秒后继续检测
    timeout /t 10 >nul
)

echo. 重启进入设备
%adb-tools%\fastboot reboot
goto end

:end
CLS
echo.    是否删除payload.bin文件？(Y删除/N不删)
choice /c YN

if errorlevel 2 (
    echo 正在删除残留文件
	del /s /q %boot_origin%\boot.img
	del /s /q %boot_origin%\init_boot.img
) else (
    echo 删除文件
    del /s /q %payload_file%
	del /s /q %boot_origin%\boot.img
	del /s /q %boot_origin%\init_boot.img
)
echo.    执行完毕，希望大大用的开心呀
echo.    有能力的话关注一下我的b站呗，或者去酷安搜索badnng关注我，如果大佬能请我喝瓶矿泉水的话，我会加倍感谢你的！
start .\source\QRCode\cd85617e1d34b8ebe63db88c22abd09.png
taskkill -f -im adb.exe
echo.    本窗口将在6秒钟关闭~
timeout /t 6 >nul
explorer "https://space.bilibili.com/355631279?spm_id_from=333.1007.0.0"
