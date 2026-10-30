param([string]$Exe = "$PSScriptRoot\..\bin\Release\net10.0\Web2Comic.exe")
# Rigenera gli screenshot del README (docs/screenshot-it|en|es.png) con dati di esempio.
# Uso (dopo dotnet build -c Release): powershell -File docs\readme-shots.ps1
# Va salvato con BOM UTF-8: PowerShell 5 altrimenti rovina le lettere accentate.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class Dwm { [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
"@
$data = @{
  It = @{ Site = "https://esempio.it/manga/la-mia-serie"; List = "lista-capitoli"; Chapter = "capitolo"; Series = "La mia serie"
          Author = "Nome Autore"; Genre = "Avventura, Fantasia"; Folder = "D:\Fumetti\La mia serie"; Lang = "it" }
  En = @{ Site = "https://example.com/manga/my-series"; List = "chapter-list"; Chapter = "chapter"; Series = "My series"
          Author = "Author Name"; Genre = "Adventure, Fantasy"; Folder = "D:\Comics\My series"; Lang = "en" }
  Es = @{ Site = "https://ejemplo.es/manga/mi-serie"; List = "lista-capitulos"; Chapter = "capitulo"; Series = "Mi serie"
          Author = "Nombre del Autor"; Genre = "Aventura, Fantasía"; Folder = "D:\Comics\Mi serie"; Lang = "es" }
}
foreach ($code in "It", "En", "Es") {
  $d = $data[$code]
  $p = Start-Process $Exe -PassThru
  Start-Sleep 6
  $p.Refresh()
  $w = [Windows.Automation.AutomationElement]::FromHandle($p.MainWindowHandle)
  function El($id) { $w.FindFirst([Windows.Automation.TreeScope]::Descendants, (New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::AutomationIdProperty, $id))) }
  function SetText($id, $v) { (El $id).GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue($v) }
  function Check($id) { $t = (El $id).GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern); if ($t.Current.ToggleState -ne "On") { $t.Toggle() }; Start-Sleep -Milliseconds 300 }
  (El "btnLang$code").GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
  Start-Sleep 1
  SetText "txtListUrl" "$($d.Site)/$($d.List)"
  SetText "txtFrom" "1"
  SetText "txtTo" "10"
  SetText "txtUrls" ((1..3 | ForEach-Object { "$($d.Site)/$($d.Chapter)-{0:D3}" -f $_ }) -join "`r`n")
  SetText "txtFolder" $d.Folder
  Check "chkParallel"; Check "chkVolume"; Check "chkSplit"; Check "chkEpub"
  SetText "txtSeries" $d.Series
  SetText "txtWriter" $d.Author
  SetText "txtGenre" $d.Genre
  SetText "txtLanguage" $d.Lang
  Check "chkRtl"; Check "chkKobo"
  SetText "txtVolume" "1"
  # Il fuoco in cima: la parte scorrevole della finestra torna all'inizio
  (El "txtListUrl").SetFocus()
  [Dwm]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep 1
  $r = New-Object Dwm+RECT
  [Dwm]::DwmGetWindowAttribute($p.MainWindowHandle, 9, [ref]$r, 16) | Out-Null
  $bmp = New-Object Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $png = Join-Path $PSScriptRoot "screenshot-$($code.ToLower()).png"
  $bmp.Save($png)
  "$png ($($bmp.Width)x$($bmp.Height))"
  $p.CloseMainWindow() | Out-Null
  Start-Sleep 2
}
