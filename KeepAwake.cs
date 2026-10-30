using System.Diagnostics;
using System.Runtime.InteropServices;

namespace Web2Comic;

/// <summary>
/// Impedisce al computer di andare in sospensione finché l'oggetto non viene rilasciato
/// (lo schermo può comunque spegnersi). Windows: SetThreadExecutionState; macOS: caffeinate.
/// </summary>
public sealed class KeepAwake : IDisposable
{
    private const uint EsContinuous = 0x80000000, EsSystemRequired = 0x00000001;
    private readonly Process? _caffeinate;
    private bool _disposed;

    [DllImport("kernel32.dll")]
    private static extern uint SetThreadExecutionState(uint flags);

    private KeepAwake()
    {
        if (OperatingSystem.IsWindows())
            SetThreadExecutionState(EsContinuous | EsSystemRequired);
        else if (OperatingSystem.IsMacOS())
        {
            // -i: niente sospensione per inattività; -w: si chiude da solo se l'app si chiude
            try { _caffeinate = Process.Start(new ProcessStartInfo("caffeinate", $"-i -w {Environment.ProcessId}") { UseShellExecute = false }); }
            catch (System.ComponentModel.Win32Exception) { }
        }
    }

    /// <summary>Da chiamare e rilasciare sullo stesso thread (su Windows l'impostazione vale per il thread).</summary>
    public static KeepAwake Start() => new();

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        if (OperatingSystem.IsWindows())
            SetThreadExecutionState(EsContinuous);
        else if (_caffeinate is { HasExited: false })
        {
            try { _caffeinate.Kill(); } catch (InvalidOperationException) { }
        }
        _caffeinate?.Dispose();
    }
}
