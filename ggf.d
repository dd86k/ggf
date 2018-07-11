import core.sys.windows.windows;
import core.stdc.stdio : printf, puts, fputs, stdout;

extern (C)
int putchar(int c);

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

enum
	PROJECT_VER  = "0.1.0",
	PCNULL = cast(char*)0,	/// Character Pointer NULL constant
	PINULL = cast(uint*)0;	/// Integer Pointer NULL constant

extern (C)
void help() {
    puts(
`Get disk(s) information.
  Usage: ggf [OPTIONS]
         ggf {-h|-v|/?}`
	);
}

extern (C)
void version_() {
	printf(
`ggf v` ~ PROJECT_VER~ `  (` ~ __TIMESTAMP__ ~ `)
MIT License: Copyright (c) 2017-2018 dd86k
Project page: <https://github.com/dd86k/ggf>
Compiled `~__FILE__~` with `~__VENDOR__~" v%d\n",
		__VERSION__);
}

__gshared byte base10; /// Use base10 notation

enum : ubyte {
	FEATURE_DEFAULT, // sizes/usage
	FEATURE_POURCENTAGE, // usage%
	FEATURE_FEATURES, // features
	FEATURE_MISC, // serial+max path
}

enum
	FILE_SUPPORTS_EXTENDED_ATTRIBUTES = 0x00800000,
	FILE_DAX_VOLUME = 0x20000000;

enum
	POURCENTAGE_INNER_WIDTH = 40;

extern (C)
private int main(int argc, char** argv) {
	ubyte feature; // FEATURE_DEFAULT

	while (--argc >= 1) {
		if (argv[argc][0] == '-') {
			char* a = argv[argc];
			while (*++a != '\0') {
				switch (*a) {
				case 'h': help; return 0;
				case 'v': version_; return 0;
				case 'b': ++base10; break;
				case 'F': feature = FEATURE_FEATURES; break;
				case 'P': feature = FEATURE_POURCENTAGE; break;
				case 'M': feature = FEATURE_MISC; break;
				default:
					printf("ERROR: Unknown parameter: %c\n", *a);
					return 1;
				}
			}
		}
	}

	// Empty optical drives in XP shows a windows when an error occurs
	SetErrorMode(SEM_FAILCRITICALERRORS);
	const DWORD drives = GetLogicalDrives;

	if (drives == 0) {
		puts("ERROR: No drives found.");
		return 2;
	}

	switch (feature) {
	case FEATURE_MISC:
		puts("DRIVE  SERIAL     MAX PATH");
		break;
	case FEATURE_FEATURES:
		puts("DRIVE  FEATURES");
		break;
	case FEATURE_POURCENTAGE:
		puts("DRIVE  USAGE");
		break;
	default:
		puts("DRIVE  TYPE           USED      FREE     TOTAL  TYPE    NAME");
	}

	char[3] cdp = ` :\`; /// buffer
	for (uint d = 1; d <= drives; d <<= 1) {
		const uint n = drives & d;

		if (n == 0) continue;

		const char cd = getDrive(n);
		printf("%c:     ", cd);
		cdp[0] = cd;

		switch (feature) {
		case FEATURE_MISC:
			ushort[2] serial = void;
			DWORD maxcomp = void;
			if (GetVolumeInformationA(cast(char*)cdp, PCNULL, 0,
				cast(uint*)&serial, &maxcomp, PINULL, PCNULL, 0)) {
				printf("%04X-%04X  %8d  \n", serial[1], serial[0], maxcomp);
			} else printf("\n");
			break;
		case FEATURE_FEATURES:
			DWORD flags = void;
			if (GetVolumeInformationA(cast(char*)cdp, PCNULL, PINULL, PINULL, PINULL,
				&flags, PCNULL, 0)) {
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
				if (flags & FILE_SUPPORTS_EXTENDED_ATTRIBUTES)
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
				if (flags & FILE_DAX_VOLUME) // Added in Windows 10
					printf(", DAX");
			}
			printf("\n");
			break;
		case FEATURE_POURCENTAGE:
			ubyte p_fb = void, p_tb = void;
			ULARGE_INTEGER fb = void, total = void, free = void;
			if (GetDiskFreeSpaceExA(cast(char*)cdp, &fb, &total, &free)) {
				ulong used = total.QuadPart - free.QuadPart;
				p_tb = cast(ubyte) // used
					((used * POURCENTAGE_INNER_WIDTH) / total.QuadPart);
				p_fb = cast(ubyte) // free
					(((free.QuadPart * POURCENTAGE_INNER_WIDTH) / total.QuadPart) + 1);
				putchar('[');
				while (--p_tb) { putchar('='); }
				while (--p_fb) { putchar(' '); }
				printf("] %d%%\n", cast(uint)((used * 100) / total.QuadPart));
			} else printf("\n");
			break;
		default:
			switch (GetDriveTypeA(cast(char*)cdp)) { // Lazy alert
			default:	puts("UNKNOWN  "); continue; // 0+1
			case 2:	printf("Removable"); break;
			case 3:	printf("Fixed    "); break;
			case 4:	printf("Network  "); break;
			case 5:	printf("Optical  "); break;
			case 6:	printf("RAM      "); break;
			}

			ULARGE_INTEGER dfb = void, dtotal = void, dfree = void;
			if (GetDiskFreeSpaceExA(cast(char*)cdp, &dfb, &dtotal, &dfree)) {
				_printfd(dtotal.QuadPart - dfree.QuadPart);
				_printfd(dfree.QuadPart);
				_printfd(dtotal.QuadPart);
			}

			ubyte[128] vol, fs; // inits to 0, char inits to 0xFF
			if (GetVolumeInformationA(
				cast(char*)cdp, cast(char*)vol, vol.sizeof,
				NULL, NULL, NULL, cast(char*)fs, fs.sizeof)) {
				printf("  %-7s %s\n", cast(char*)fs, cast(char*)vol);
			} else printf("\n");
		}

	} // for

	return 0;
}

enum : float { // for _printfd function
	KB = 1024,
	MB = KB * 1024,
	GB = MB * 1024,
	TB = GB * 1024,
	KiB = 1000,
	MiB = KiB * 1000,
	GiB = MiB * 1000,
	TiB = GiB * 1000,
}

// lazy formatter with spacing
extern (C)
private void _printfd(ulong l) {
	const float f = l;
	if (base10) {
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

/**
 * Cheapest way to get a drive letter by computed mask
 * Params: mask = Drive mask (Windows)
 * Returns: Windows drive letter
 */
extern (C)
char getDrive(uint mask) pure { // This entire thing is lazy
	switch (mask) {
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
	default: return '?';
	}
}