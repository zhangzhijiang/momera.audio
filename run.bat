taskkill /f /im adb.exe /fi "status eq running"
taskkill /f /im java.exe /fi "status eq running"
call flutter clean
call flutter pub get
call flutter run