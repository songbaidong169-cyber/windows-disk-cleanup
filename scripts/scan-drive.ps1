# scan-drive.ps1 - single-pass directory size aggregator for one volume
# Output TSV: FullPath <TAB> TotalBytesIncludingSubdirs <TAB> FileCount
# Skips reparse points (junctions/symlinks) so linked data is not double counted.
#
# Requirements: Windows PowerShell 5.1+ / PowerShell 7+
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scan-drive.ps1 -Root "C:\" -OutFile "C:\temp\scan-c.tsv"
#   powershell -NoProfile -ExecutionPolicy Bypass -File scan-drive.ps1 -Root "D:\" -OutFile "D:\scan-d.tsv" -ShowTop 15
#
# IMPORTANT: total volume size = the row whose Path equals the root. Never sum all rows.

param(
    [string]$Root = 'C:\',
    [string]$OutFile = "$env:TEMP\scan.tsv",
    [int]$ShowTop = 10
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public class DiskAggScan
{
    public static string Run(string root, string outFile)
    {
        var size = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        var cnt  = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
        var stack = new Stack<string>();
        stack.Push(root);
        long totalFiles = 0;

        while (stack.Count > 0)
        {
            string d = stack.Pop();
            long s = 0, c = 0;
            try
            {
                foreach (string f in Directory.EnumerateFiles(d))
                {
                    try { s += new FileInfo(f).Length; c++; } catch { }
                }
            }
            catch { }
            size[d] = s; cnt[d] = c; totalFiles += c;

            try
            {
                foreach (string sub in Directory.EnumerateDirectories(d))
                {
                    try
                    {
                        var di = new DirectoryInfo(sub);
                        if ((di.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push(sub);
                    }
                    catch { }
                }
            }
            catch { }
        }

        var keys = new List<string>(size.Keys);
        keys.Sort(delegate(string a, string b) { return b.Length.CompareTo(a.Length); });
        foreach (string k in keys)
        {
            if (string.Equals(k, root, StringComparison.OrdinalIgnoreCase)) continue;
            string p = Path.GetDirectoryName(k);
            if (p != null && size.ContainsKey(p)) { size[p] += size[k]; cnt[p] += cnt[k]; }
        }

        using (var w = new StreamWriter(outFile, false, new UTF8Encoding(false)))
        {
            foreach (var kv in size)
                w.WriteLine(kv.Key + "\t" + kv.Value + "\t" + cnt[kv.Key]);
        }
        return "dirs=" + size.Count + " files=" + totalFiles + " rootBytes=" + size[root];
    }
}
'@

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$result = [DiskAggScan]::Run($Root, $OutFile)
$elapsed = $sw.Elapsed.TotalSeconds

$rows = foreach ($line in [System.IO.File]::ReadLines($OutFile)) {
    $p = $line.Split("`t")
    [pscustomobject]@{ Path = $p[0]; Bytes = [long]$p[1]; Files = [long]$p[2] }
}

$rootRow = $rows | Where-Object { $_.Path -eq $Root }
$totalGB = if ($rootRow) { [math]::Round($rootRow.Bytes / 1GB, 2) } else { 0 }

Write-Output ("SCAN RESULT: total {0:N2} GB, {1} files, elapsed {2:N1}s" -f $totalGB, $result.Split(' ')[1].Split('=')[1], $elapsed)
Write-Output ("OUTPUT: {0}" -f $OutFile)
Write-Output ""
Write-Output ("TOP {0} DIRECTORIES (depth 1):" -f $ShowTop)

$prefixLen = $Root.TrimEnd('\').Length + 1
$depth1 = $rows | Where-Object {
    $_.Path -ne $Root -and $_.Path.Length -gt $prefixLen -and
    ($_.Path.Substring($prefixLen).Split('\').Count -eq 1)
}
$depth1 | Sort-Object Bytes -Descending | Select-Object -First $ShowTop |
    ForEach-Object {
        Write-Output ("{0,10:N2} GB  {1,8} files  {2}" -f ($_.Bytes / 1GB), $_.Files, $_.Path)
    }
