param([switch]$Elevated)
function Test-Admin {
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())

$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Test-Admin) -eq $false)
{
if ($elevated) {
# tried to elevate, did not work, aborting
} else {
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}
Exit
}
'running with full privileges'
### edits
Add-Type -TypeDefinition '
using System;
using System.IO;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace KeyLogger {
  public static class Program {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;

    private static HookProc hookProc = HookCallback;
    private static IntPtr hookId = IntPtr.Zero;
    private static int keyCode = 0;

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    public static int WaitForKey() {
      hookId = SetHook(hookProc);
      Application.Run();
      UnhookWindowsHookEx(hookId);
      return keyCode;
    }

    private static IntPtr SetHook(HookProc hookProc) {
      IntPtr moduleHandle = GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName);
      return SetWindowsHookEx(WH_KEYBOARD_LL, hookProc, moduleHandle, 0);
    }

    private delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
      if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
        keyCode = Marshal.ReadInt32(lParam);
        Application.Exit();
      }
      return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
  }
}
' -ReferencedAssemblies System.Windows.Forms

write-host "--------"
$dumploc = "$Env:TEMP\obsdump.dmp"
write-host "--------"
if (test-path $dumploc) {
    write-host "The script does NOT overwrite existing dumps, make sure it dosent exist already" -ForegroundColor Yellow
    write-host "There already exists a dump file! Please remove it first" -ForegroundColor Red
    write-host "delete this: $dumploc"
    write-host "--------"
    write-host "Dont proceed without removing the file, dump will fail"
    pause
}

write-host "Ready to dump. Hit F12" -ForegroundColor Green

while ($true) {
    $key = [System.Windows.Forms.Keys][KeyLogger.Program]::WaitForKey()
    if ($key -eq "F12") {
        $obs = Get-Process obs64
        write-host "OBS proc id:"
        Write-host $obs.id
        Write-Host "Trying to dump"
        write-host "--------"
        rundll32 C:\Windows\System32\comsvcs.dll, MiniDump $obs.id $dumploc full
        explorer $Env:TEMP
    }
}