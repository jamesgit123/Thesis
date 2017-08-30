import std.stdio;
import std.string;

void main()
{
	foreach(ln; stdin.byLine(KeepTerminator.no))
	{
		// checksum ln
		//write ln + checksum to f
		uint checksum;
		foreach(c; ln)
		{
			checksum += c;
			checksum &= 0xFF;
		}
		stdout.writef("$%s#%02X", ln, checksum);
	}
}