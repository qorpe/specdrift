using System.Text.RegularExpressions;
using Xunit;

namespace SpecDrift.Tests;

public class CliTests : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("specdrift-cli").FullName;

    public void Dispose() => Directory.Delete(_dir, recursive: true);

    private string Write(string name, string content)
    {
        var path = Path.Combine(_dir, name);
        File.WriteAllText(path, content);
        return path;
    }

    private static (int Code, string Out, string Err) Run(params string[] args)
    {
        var stdout = new StringWriter();
        var stderr = new StringWriter();
        var code = Cli.Run(args, stdout, stderr);
        return (code, stdout.ToString(), stderr.ToString());
    }

    private const string Schema = """{ "type": "object", "required": ["version"] }""";

    [Fact]
    public void Exit_codes_are_the_contract()
    {
        var schema = Write("schema.json", Schema);
        var good = Write("good.yaml", "version: 1");
        var bad = Write("bad.yaml", "name: no-version-here");

        Assert.Equal(0, Run("validate", good, "--schema", schema).Code);
        Assert.Equal(1, Run("validate", bad, "--schema", schema).Code);
        Assert.Equal(2, Run().Code);                                     // no args → usage
        Assert.Equal(2, Run("frobnicate").Code);                         // unknown verb
        Assert.Equal(1, Run("validate", good).Code);                     // no --schema -> the EMBEDDED goldpath schema; this manifest is not one
        Assert.Equal(2, Run("validate", good, "--schema", schema, "--format", "xml").Code);
        Assert.Equal(2, Run("validate", Path.Combine(_dir, "absent.yaml"), "--schema", schema).Code);
    }

    [Fact]
    public void Json_format_emits_machine_readable_findings()
    {
        var schema = Write("schema.json", Schema);
        var bad = Write("bad.yaml", "name: x");

        var (code, output, _) = Run("validate", bad, "--schema", schema, "--format", "json");
        Assert.Equal(1, code);
        Assert.Contains("\"ruleId\": \"SPEC0001\"", output);
        Assert.Contains("\"severity\": \"error\"", output);
    }

    [Fact]
    public void Help_prints_usage_and_succeeds()
    {
        var (code, output, _) = Run("--help");
        Assert.Equal(0, code);
        Assert.Contains("specdrift validate", output);
    }

    /// <summary>
    /// Every verb the CLI dispatches has to appear in the usage list, and the list has to be
    /// a LIST: three contiguous lines under "usage:". A verb parked below the explanatory
    /// prose reads as a footnote to the paragraph above it rather than a third way to run
    /// the tool, so a reader scanning for "what can this do" never sees it.
    /// </summary>
    [Fact]
    public void Help_lists_every_verb_together_under_usage()
    {
        var (_, output, _) = Run("--help");
        var lines = output.Replace("\r\n", "\n").Split('\n');

        var verbLines = new List<int>();
        for (var i = 0; i < lines.Length; i++)
        {
            if (Regex.IsMatch(lines[i], @"^\s+specdrift (validate|drift|mcp)\b"))
            {
                verbLines.Add(i);
            }
        }

        Assert.Equal(3, verbLines.Count);
        Assert.Equal(
            Enumerable.Range(verbLines[0], 3),
            verbLines);
    }
}
