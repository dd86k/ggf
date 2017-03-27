import std.stdio;
import std.string : toStringz;
import core.sys.windows.windows;

/*
 * MSDN
 * GetVolumeInformation
 * https://msdn.microsoft.com/en-us/library/windows/desktop/aa364993(v=vs.85).aspx
 */

/* SWITCHES
	-b : Use base 10 sizes
	-f : Features page (flags)
	-s : Serial, max component length
*/

enum {
	PROJECT_NAME = "ggf",
	PROJECT_VER  = "0.0.0"
}

/// Character Pointer NULL constant
enum PCNULL = cast(char*)0;

void PrintHelp()
{
    writeln("Determine the file type by its content.");
    writeln("  Usage: ", PROJECT_NAME, " [-f] [-b]");
    writeln("         ", PROJECT_NAME, " {--help|--version|/?}");
}

void PrintVersion()
{
debug
    writeln(PROJECT_NAME, " ", PROJECT_VER, "-debug (", __TIMESTAMP__, ")");
else
    writeln(PROJECT_NAME, " ", PROJECT_VER, " (", __TIMESTAMP__, ")");
    writeln("MIT License: Copyright (c) 2016-2017 dd86k");
    writeln("Project page: <https://github.com/dd86k/dfile>");
    writeln("Compiled ", __FILE__, " with ", __VENDOR__, " v", __VERSION__);
}

void main(string[] args)
{
	bool base10, features;

	foreach (arg; args)
	{
		switch (arg)
		{
			case "-b": base10 = true; break;
			case "-f": features = true; break;

			case "--help", "/?": PrintHelp; return;
			case "--version": PrintVersion; return;
			default: break;
		}
	}

	// Floppy drives and CDs in XP shows an error when empty.
	SetErrorMode(SEM_FAILCRITICALERRORS); 
	DWORD drives = GetLogicalDrives();

	if (features)
		writeln("DRIVE  SERIAL     MAX PATH  FEATURES");
	else
		writeln("DRIVE  TYPE           USED      FREE     TOTAL  TYPE    NAME");
	for (uint d = 1; d <= drives; d <<= 1)
	{
		uint n = drives & d;
		if (n)
		{
			char cd = getDrive(n);
			writef("%c:     ", cd);

			const char* cdp = toStringz(cd ~ `:\`);

			if (features)
			{
				DWORD serial, maxcomp, flags;
				if (GetVolumeInformationA(cdp, PCNULL, 0,
					&serial, &maxcomp, &flags, PCNULL, 0))
				{
					ushort* sp = cast(ushort*)&serial;
					writef("%04X-%04X  %8d  ", sp[1], sp[0], maxcomp);

					if (flags & FILE_CASE_SENSITIVE_SEARCH)
						write(", CASE_SENSITIVE_SEARCH");
					if (flags & FILE_CASE_PRESERVED_NAMES)
						write(", CASE_PRESERVED_NAMES");
					if (flags & FILE_PERSISTENT_ACLS)
						write(", PERSISTENT_ACLS");
					if (flags & FILE_READ_ONLY_VOLUME)
						write(", READ_ONLY");
					if (flags & FILE_NAMED_STREAMS)
						write(", NAMED_STREAMS");
					if (flags & FILE_SEQUENTIAL_WRITE_ONCE)
						write(", SEQ_WRITE_ONCE");
					if (flags & 0x00800000) // FILE_SUPPORTS_EXTENDED_ATTRIBUTES
						write(", EXTENDED_ATTRIBUTES");
					if (flags & FILE_SUPPORTS_ENCRYPTION)
						write(", ENCRYPTION");
					if (flags & 0x00400000) // FILE_SUPPORTS_HARD_LINKS
						write(", HARD_LINKS");
					if (flags & FILE_SUPPORTS_OBJECT_IDS)
						write(", OBJECT_ID");
					if (flags & 0x01000000) // FILE_SUPPORTS_OPEN_BY_FILE_ID
						write(", OPEN_BY_FILE_ID");
					if (flags & FILE_SUPPORTS_REPARSE_POINTS)
						write(", REPARSE_POINTS");
					if (flags & FILE_SUPPORTS_SPARSE_FILES)
						write(", SPARSE_FILES");
					if (flags & FILE_SUPPORTS_TRANSACTIONS)
						write(", TRANSACTIONS");
					if (flags & 0x02000000) // FILE_SUPPORTS_USN_JOURNAL
						write(", USN_JOURNAL");
					if (flags & FILE_UNICODE_ON_DISK)
						write(", UNICODE");
					if (flags & FILE_FILE_COMPRESSION) {
						if (flags & FILE_VOLUME_IS_COMPRESSED)
							write(", COMPRESSED");
						else
							write(", COMPRESSION");
					}
					if (flags & FILE_VOLUME_QUOTAS)
						write(", QUOTAS");
					if (flags & 0x20000000) // FILE_DAX_VOLUME, added in Windows 10
						write(", DAX");
				}
			}
			else // NO FEATURES, PRINT SIZES
			{
				switch (GetDriveTypeA(cdp))
				{ // Lazy alert
					default:write("UNKNOWN  "); break; // 1+2
					case 2: write("Removable"); break;
					case 3: write("Fixed    "); break;
					case 4: write("Network  "); break;
					case 5: write("Optical  "); break;
					case 6: write("RAM      "); break;
				}

				ULARGE_INTEGER fb, tb, tfb;
				if (GetDiskFreeSpaceExA(cdp, &fb, &tb, &tfb))
				{
					writef("%10s", formatsize(tb.QuadPart - tfb.QuadPart, base10));
					writef("%10s", formatsize(tfb.QuadPart, base10));
					writef("%10s", formatsize(tb.QuadPart, base10));
				}

				char[128] vol, fs;
				if (GetVolumeInformationA(cdp, &vol[0], vol.length,
					NULL, NULL, NULL, &fs[0], fs.length))
				{
					writef("  %-7s %s",
						fs[0 .. dstrlen(fs)], vol[0 .. dstrlen(vol)]);
				}
			}

			writeln();
		}
	}
}

int dstrlen(char[] str)
{
	int i;
	foreach(c; str)
		if (c == 0xFF) return i - 1; else ++i;
	return i;
}

/// Get a formatted size.
string formatsize(long size, bool b10 = false)
{
    import std.format : format;

    enum : long {
        KB = 1024,
        MB = KB * 1024,
        GB = MB * 1024,
        TB = GB * 1024,
        KiB = 1000,
        MiB = KiB * 1000,
        GiB = MiB * 1000,
        TiB = GiB * 1000
    }

	const float s = size;

	if (b10)
	{
		if (size > TiB)
			if (size > 10 * TiB)
				return format("%d TiB", size / TiB);
			else
				return format("%0.2f TiB", s / TiB);
		else if (size > GiB)
			if (size > 10 * GiB)
				return format("%d GiB", size / GiB);
			else
				return format("%0.2f GiB", s / GiB);
		else if (size > MiB)
			if (size > 10 * MiB)
				return format("%d MiB", size / MiB);
			else
				return format("%0.2f MiB", s / MiB);
		else if (size > KiB)
			if (size > 10 * KiB)
				return format("%d KiB", size / KiB);
			else
				return format("%0.2f KiB", s / KiB);
		else
			return format("%d B", size);
	}
	else
	{
		if (size > TB)
			if (size > 10 * TB)
				return format("%d TB", size / TB);
			else
				return format("%0.2f TB", s / TB);
		else if (size > GB)
			if (size > 10 * GB)
				return format("%d GB", size / GB);
			else
				return format("%0.2f GB", s / GB);
		else if (size > MB)
			if (size > 10 * MB)
				return format("%d MB", size / MB);
			else
				return format("%0.2f MB", s / MB);
		else if (size > KB)
			if (size > 10 * KB)
				return format("%d KB", size / KB);
			else
				return format("%0.2f KB", s / KB);
		else
			return format("%d B", size);
	}
}

char getDrive(uint mask) pure
{
	final switch (mask)
	{
		case 1: return 'A';
		case 2: return 'B';
		case 4: return 'C';
		case 8: return 'D';
		case 16: return 'E';
		case 32: return 'F';
		case 64: return 'G';
		case 128: return 'H';
		case 256: return 'I';
		case 512: return 'J';
		case 1024: return 'K';
		case 2048: return 'L';
		case 4096: return 'M';
		case 8192: return 'N';
		case 16384: return 'O';
		case 32768: return 'P';
		case 65536: return 'Q';
		case 131072: return 'R';
		case 262144: return 'S';
		case 524288: return 'T';
		case 1048576: return 'U';
		case 2097152: return 'V';
		case 4194304: return 'W';
		case 8388608: return 'X';
		case 16777216: return 'Y';
		case 33554432: return 'Z';
	}
}