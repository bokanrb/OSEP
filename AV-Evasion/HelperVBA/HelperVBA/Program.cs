using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Runtime.InteropServices;


namespace HelperVBA
{
    internal class Program
    {

        public static byte[] DecryptXOR(byte[] data, byte[] key)
        {
            byte[] decrypted = new byte[data.Length];
            for (int i = 0; i < data.Length; i++) decrypted[i] = (byte)(data[i] ^ key[i % key.Length]);
            return decrypted;
        }

        static void Main(string[] args)
        {
            byte[] encryptedData = Properties.Resources.shellcode_enc;
            byte[] key = Encoding.ASCII.GetBytes("HFDG*febMXL@uX8YkkPhJof*");
            byte[] buf = DecryptXOR(encryptedData, key);

            uint counter = 0;
            StringBuilder hex = new StringBuilder(buf.Length * 2);
            foreach (byte b in buf)
            {
                hex.AppendFormat("{0:D}, ", b);
                counter++;
                if (counter % 50 == 0)
                {
                    hex.AppendFormat("_{0}", Environment.NewLine);
                }
            }  
            Console.WriteLine(hex.ToString());

        }
    }
}
