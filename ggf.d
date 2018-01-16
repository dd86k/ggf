import std.stdio;
import std.string : toStringz;
import core.sys.windows.windows;
import core.stdc.stdio;

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
	PROJECT_VER  = cast(char*)"0.0.1",
	PCNULL = cast(char*)0	/// Character Pointer NULL constant
}

extern (C)
void help() {
    puts(
`Get disk information.
  Usage: ggf [OPTIONS]");
         ggf {--help|--version|/?}`
	);
}

extern (C)
void version_() {
	printf(
`ggf v%s  (%s)
MIT License: Copyright (c) 2017-2018 dd86k
Project page: <https://github.com/dd86k/ggf>
Compiled %s with %s v%d
`,
		PROJECT_VER, cast(char*)__TIMESTAMP__,
		cast(char*)__FILE__, cast(char*)__VENDOR__, __VERSION__
	);
}

__gshared bool base10;

extern (C)
int main(int argc, char** argv) {
	bool features;

	while (--argc >= 1) {
		if (argv[argc][0] == '-') {
			char* a = argv[argc];
			while (*++a != '\0') {
				switch (*a) {
				case 'h': help; return 0;
				case 'v': version_; return 0;
				case 'f': features = 1; break;
				case 'b': base10 = 1; break;
				default:
					printf("Unknown parameter: %c\n", *a);
					return 1;
				}
			}
		}
	}

	// FDDs/CDs in XP shows a windows when an error occurs
	SetErrorMode(SEM_FAILCRITICALERRORS);
	const DWORD drives = GetLogicalDrives;

	if (drives) {
		if (features)
			puts("DRIVE  SERIAL     MAX PATH  FEATURES");
		else
			puts("DRIVE  TYPE           USED      FREE     TOTAL  TYPE    NAME");
	}

	char[3] cdp = ` :\`; /// buffer
	for (uint d = 1; d <= drives; d <<= 1) {
		uint n = drives & d;
		if (n) {
			const char cd = getDrive(n);
			printf("%c:     ", cd);
			cdp[0] = cd;

			if (features) {
				DWORD serial, maxcomp, flags;
				if (GetVolumeInformationA(cast(char*)cdp, PCNULL, 0,
					&serial, &maxcomp, &flags, PCNULL, 0)) {
					ushort* sp = cast(ushort*)&serial;
					printf("%04X-%04X  %8d  ", sp[1], sp[0], maxcomp);

					if (flags & FILE_CASE_SENSITIVE_SEARCH)
						printf(", CASE_SENSITIVE_SEARCH");
					if (flags & FILE_CASE_PRESERVED_NAMES)
						printf(", CASE_PRESERVED_NAMES");
					if (flags & FILE_PERSISTENT_ACLS)
						printf(", PERSISTENT_ACLS");
					if (flags & FILE_READ_ONLY_VOLUME)
						printf(", READ_ONLY");
					if (flags & FILE_NAMED_STREAMS)
						printf(", NAMED_STREAMS");
					if (flags & FILE_SEQUENTIAL_WRITE_ONCE)
						printf(", SEQ_WRITE_ONCE");
					if (flags & 0x00800000) // FILE_SUPPORTS_EXTENDED_ATTRIBUTES
						printf(", EXTENDED_ATTRIBUTES");
					if (flags & FILE_SUPPORTS_ENCRYPTION)
						printf(", ENCRYPTION");
					if (flags & 0x00400000) // FILE_SUPPORTS_HARD_LINKS
						printf(", HARD_LINKS");
					if (flags & FILE_SUPPORTS_OBJECT_IDS)
						printf(", OBJECT_ID");
					if (flags & 0x01000000) // FILE_SUPPORTS_OPEN_BY_FILE_ID
						printf(", OPEN_BY_FILE_ID");
					if (flags & FILE_SUPPORTS_REPARSE_POINTS)
						printf(", REPARSE_POINTS");
					if (flags & FILE_SUPPORTS_SPARSE_FILES)
						printf(", SPARSE_FILES");
					if (flags & FILE_SUPPORTS_TRANSACTIONS)
						printf(", TRANSACTIONS");
					if (flags & 0x02000000) // FILE_SUPPORTS_USN_JOURNAL
						printf(", USN_JOURNAL");
					if (flags & FILE_UNICODE_ON_DISK)
						printf(", UNICODE");
					if (flags & FILE_FILE_COMPRESSION) {
						if (flags & FILE_VOLUME_IS_COMPRESSED)
							printf(", COMPRESSED");
						else
							printf(", COMPRESSION");
					}
					if (flags & FILE_VOLUME_QUOTAS)
						printf(", QUOTAS");
					if (flags & 0x20000000) // FILE_DAX_VOLUME, added in Windows 10
						printf(", DAX");
				}
			} else { // NO FEATURES, PRINT SIZES
				switch (GetDriveTypeA(cast(char*)cdp)) { // Lazy alert
				default: printf("UNKNOWN  "); break; // 0+1
				case 2:  printf("Removable"); break;
				case 3:  printf("Fixed    "); break;
				case 4:  printf("Network  "); break;
				case 5:  printf("Optical  "); break;
				case 6:  printf("RAM      "); break;
				}

				ULARGE_INTEGER fb, tb, tfb;
				if (GetDiskFreeSpaceExA(cast(char*)cdp, &fb, &tb, &tfb)) {
					_printfd(tb.QuadPart - tfb.QuadPart);
					_printfd(tfb.QuadPart);
					_printfd(tb.QuadPart);
				}

				char[128] vol, fs;
				if (GetVolumeInformationA(cast(char*)cdp, cast(char*)vol, vol.length,
					NULL, NULL, NULL, cast(char*)fs, fs.length)) {
					printf("  %-7s %s", cast(char*)fs, cast(char*)vol);
				}
			}

			puts("");
		}
	}

	return 0;
}

enum : float {
	KB = 1024,
	MB = KB * 1024,
	GB = MB * 1024,
	TB = GB * 1024,
	KiB = 1000,
	MiB = KiB * 1000,
	GiB = MiB * 1000,
	TiB = GiB * 1000,
}

extern (C)
void _printfd(ulong l) {
	float f = l;
	// Lazy code, sorry
	if (base10) { // ya ya idc
		if (l >= TiB) {
			printf("%8.2fTi", f / TiB);
		} else if (l >= GiB) {
			printf("%8.2fGi", f / GiB);
		} else if (l >= MiB) {
			printf("%8.2fMi", f / MiB);
		} else if (l >= KiB) {
			printf("%8.2fKi", f / KiB);
		} else
			printf("%9llB", l);
	} else {
		if (l >= TB) {
			printf("%9.2fT", f / TB);
		} else if (l >= GB) {
			printf("%9.2fG", f / GB);
		} else if (l >= MB) {
			printf("%9.2fM", f / MB);
		} else if (l >= KB) {
			printf("%9.2fK", f / KB);
		} else
			printf("%9llB", l);
	}
}

extern (C)
char getDrive(uint mask) pure {
	final switch (mask) {
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