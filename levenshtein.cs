using System;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public class Levenshtein {
    [SqlFunction(IsDetermininistic = true, IsPrecise = true)]
    public static SqlInt32 LevenshteinDistance(SqlString string1, SqlString string2) {
        if (string1.IsNull || string2.IsNull)
            return 0;

        string s1 = string1;
        string s2 = string2;

        int m = s1.Length;
        int n = s2.Length;

        if (m == 0)
            return n;
        if (n == 0)
            return m;

        int[] v0 = new int[n + 1];
        int[] v1 = new int[n + 1];

        for (int i = 0; i <= n; i++)
            v0[i] = i;

        for (int i = 0; i < m; i++) {
            v1[0] = i + 1;
            for (int j = 0; j < n; j++) {
                int cost = (s1[i] == s2[j]) ? 0 : 1;
                v1[j + 1] = Math.Min(v0[j + 1] + 1, v1[j] + 1, v0[j] + cost);
            }
            v0 = v1;
        }
    }
}